import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import '/core/services/overtime_rate_service.dart';
import '/core/services/spkl_generator_service.dart';

class ApprovalDetailBottomSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> mitraList;
  final bool isDarkMode;
  final String userRole;
  final String userName;
  final bool isManager;
  final bool isSuperadmin;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onPreviewSpkl;

  const ApprovalDetailBottomSheet({
    super.key,
    required this.data,
    required this.mitraList,
    required this.isDarkMode,
    required this.userRole,
    required this.userName,
    required this.isManager,
    required this.isSuperadmin,
    required this.onApprove,
    required this.onReject,
    this.onPreviewSpkl,
  });

  @override
  State<ApprovalDetailBottomSheet> createState() =>
      _ApprovalDetailBottomSheetState();
}

class _ApprovalDetailBottomSheetState extends State<ApprovalDetailBottomSheet> {
  static final _rateService = OvertimeRateService();
  static final Map<String, String> _fungsiLabelCache = {};

  // 🔥 SPKL Generator Service instance
  final SpklGeneratorService _spklGenerator = SpklGeneratorService();

  Map<String, dynamic>? _pengawasData;
  bool _isLoadingPengawas = true;
  bool _isLoadingSpkl = false;
  String _loadingSpklMessage = '';

  // ✅ STATUS YANG DIANGGAP DIBATALKAN
  static const List<String> _canceledStatuses = [
    'dibatalkan',
    'canceled',
  ];

  // ✅ STATUS YANG SUDAH DISETUJUI (BOLEH AKSES SPKL)
  static const List<String> _approvedStatuses = [
    'disetujui',
    'approved',
    'selesai',
    'completed',
  ];

  // ✅ GETTER ROLE LABEL
  String get _roleLabel {
    if (widget.isSuperadmin) return 'Superadmin';
    if (widget.isManager) return 'Manager';
    return widget.userRole;
  }

  // ✅ GETTER: Apakah SPKL boleh diakses?
  bool get _canAccessSpkl {
    final status = widget.data['status']?.toString().toLowerCase() ?? '';
    return _approvedStatuses.contains(status);
  }

  @override
  void initState() {
    super.initState();
    _loadPengawasData();

    // 🔍 DEBUG
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('🔍 DETAIL BOTTOM SHEET INIT:');
    debugPrint('  📌 Role: ${widget.userRole}, isSuperadmin: ${widget.isSuperadmin}');
    debugPrint('  📌 Status: ${widget.data['status']}');
    debugPrint('  📌 Can Access SPKL: $_canAccessSpkl');
    debugPrint('  📌 Group ID: ${widget.data['group_id']}');
    debugPrint('═══════════════════════════════════════════════');
  }

  // ===========================================================================
  // LOAD PENGAWAS DATA
  // ===========================================================================
  Future<void> _loadPengawasData() async {
    try {
      final pengawasId = widget.data['pengawas_id']?.toString() ?? '';

      if (pengawasId.isEmpty) {
        if (mounted) setState(() => _isLoadingPengawas = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(pengawasId)
          .get();

      if (mounted) {
        setState(() {
          if (doc.exists && doc.data() != null) {
            _pengawasData = doc.data()!;
          }
          _isLoadingPengawas = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading pengawas data: $e');
      if (mounted) setState(() => _isLoadingPengawas = false);
    }
  }

  // ===========================================================================
  // DATE HELPER
  // ===========================================================================
  DateTime _toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  // ===========================================================================
  // 🔥 SPKL HELPER METHODS
  // ===========================================================================
  String _getSpklNomor() {
    final candidates = [
      widget.data['spkl_nomor'],
      widget.data['spkl_number'],
      widget.data['no_spkl'],
      widget.data['nomor_spkl'],
      widget.data['spkl'] is Map ? (widget.data['spkl'] as Map)['nomor'] : null,
      widget.data['spkl'] is Map ? (widget.data['spkl'] as Map)['number'] : null,
    ];

    for (final c in candidates) {
      if (c != null && c.toString().isNotEmpty) return c.toString();
    }
    return '';
  }

  String _getSpklUrl() {
    final candidates = [
      widget.data['spkl_url'],
      widget.data['spkl_file_url'],
      widget.data['spkl_generated_url'],
      widget.data['spkl_download_url'],
      widget.data['spkl'] is Map ? (widget.data['spkl'] as Map)['url'] : null,
      widget.data['spkl'] is Map ? (widget.data['spkl'] as Map)['file_url'] : null,
      widget.data['spkl'] is Map ? (widget.data['spkl'] as Map)['fileUrl'] : null,
      widget.data['spkl'] is Map ? (widget.data['spkl'] as Map)['download_url'] : null,
    ];

    for (final c in candidates) {
      if (c != null && c.toString().isNotEmpty) return c.toString();
    }
    return '';
  }

  Future<void> _openSpklUrl(String url) async {
    try {
      String finalUrl = url.trim();
      if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
        finalUrl = 'https://$finalUrl';
      }

      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Tidak dapat membuka URL SPKL. Coba gunakan browser.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error opening SPKL URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().substring(0, 100)}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _viewSpkl() async {
    // ✅ VALIDASI: SPKL hanya bisa diakses jika sudah disetujui
    if (!_canAccessSpkl) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ SPKL hanya tersedia setelah pengajuan disetujui oleh $_roleLabel.\n'
              'Silakan setujui pengajuan terlebih dahulu.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (_isLoadingSpkl) return;

    try {
      setState(() {
        _isLoadingSpkl = true;
        _loadingSpklMessage = '⏳ Memeriksa SPKL...';
      });

      final spklUrl = _getSpklUrl();
      if (spklUrl.isNotEmpty) {
        setState(() => _loadingSpklMessage = '📱 Membuka URL SPKL...');
        await _openSpklUrl(spklUrl);
        return;
      }

      if (widget.onPreviewSpkl != null) {
        setState(() => _loadingSpklMessage = '📄 Membuka preview SPKL...');
        widget.onPreviewSpkl!();
        return;
      }

      setState(() => _loadingSpklMessage = '📄 Menyiapkan dokumen SPKL...');

      final dataWithMitra = Map<String, dynamic>.from(widget.data);
      dataWithMitra['_mitra_list'] = widget.mitraList;

      final filePath = await _spklGenerator.generateSpklFromOvertimeData(dataWithMitra);

      if (filePath.isNotEmpty) {
        setState(() => _loadingSpklMessage = '📱 Membuka SPKL...');

        final result = await OpenFilex.open(filePath);

        if (result.type == ResultType.done) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✅ SPKL berhasil dibuka'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (result.type == ResultType.noAppToOpen) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('⚠️ Tidak ada aplikasi PDF reader.\nInstall PDF reader terlebih dahulu.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else {
          throw Exception('Gagal membuka PDF: ${result.message}');
        }
      } else {
        throw Exception('Gagal generate SPKL dari data lembur');
      }
    } catch (e) {
      debugPrint('❌ Error viewing SPKL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SPKL belum dapat ditampilkan.\n'
              'Silakan coba lagi atau hubungi pengawas.\n\n'
              '💡 SPKL dapat diakses di menu Riwayat Lembur',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSpkl = false;
          _loadingSpklMessage = '';
        });
      }
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final status = widget.data['status']?.toString() ?? 'pending';
    final isPending = status == 'pending';
    final isCanceled = _canceledStatuses.contains(status);
    final urgensi = widget.data['urgensi']?.toString() ?? 'normal';
    final isOverride = widget.data['is_override'] == true;
    final isWeekend = widget.data['jenis_lembur'] == 'hari_libur';

    final lokasiData = widget.data['lokasi'];
    final lokasiMap = lokasiData is Map<String, dynamic> ? lokasiData : <String, dynamic>{};
    final isOutside = lokasiMap['is_outside_radius'] == true;

    final totalMitra = widget.mitraList.isNotEmpty
        ? widget.mitraList.length
        : (widget.data['total_mitra'] ?? 1);

    double biayaTotal = 0.0;
    if (widget.data['estimasi_biaya_total'] != null) {
      biayaTotal = (widget.data['estimasi_biaya_total'] is int
          ? (widget.data['estimasi_biaya_total'] as int).toDouble()
          : (widget.data['estimasi_biaya_total'] as num).toDouble());
    } else if (widget.mitraList.isNotEmpty) {
      biayaTotal = widget.mitraList.fold(0.0, (sum, mitra) {
        final biaya = mitra['estimasi_biaya_per_mitra'] ?? mitra['estimasi_biaya'] ?? 0;
        return sum + (biaya is int ? biaya.toDouble() : (biaya as num).toDouble());
      });
    }

    final biayaPerMitra = totalMitra > 0 ? biayaTotal / totalMitra : 0.0;

    // ✅ PERBAIKAN: Superadmin bisa approve/reject, exclude canceled
    final canApprove = isPending && !isCanceled && (widget.isManager || widget.isSuperadmin);
    final canReject = isPending && !isCanceled && (widget.isManager || widget.isSuperadmin);

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          _buildHeader(status, urgensi, isWeekend, isOverride, isOutside, isCanceled),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(
                    icon: Icons.person_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: 'Informasi Pengawas',
                    children: [
                      _buildInfoRow('Nama',
                          _pengawasData?['nama_lengkap'] ?? widget.data['nama_pengawas'] ?? '-'),
                      _buildInfoRow('Fungsi',
                          _getFungsiLabelCached(widget.data['pengawas_fungsi'])),
                      _buildInfoRow(
                        'Email',
                        _isLoadingPengawas ? 'Memuat...' : _pengawasData?['email'] ?? '-',
                      ),
                      if (_pengawasData?['phone'] != null &&
                          _pengawasData!['phone'].toString().isNotEmpty)
                        _buildInfoRow('No. HP', _pengawasData!['phone']),
                      if (_pengawasData?['nip'] != null &&
                          _pengawasData!['nip'].toString().isNotEmpty)
                        _buildInfoRow('NIP', _pengawasData!['nip']),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildInfoCard(
                    icon: Icons.access_time_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Waktu Lembur',
                    children: [
                      _buildInfoRow(
                        'Tanggal',
                        widget.data['tanggal'] != null
                            ? DateFormat('EEEE, dd MMM yyyy', 'id_ID')
                                .format(_toDate(widget.data['tanggal']))
                            : '-',
                      ),
                      _buildInfoRow('Jam',
                          '${widget.data['jam_mulai']} - ${widget.data['jam_selesai']}'),
                      _buildInfoRow(
                        'Durasi',
                        '${(widget.data['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam',
                        isBold: true,
                        valueColor: const Color(0xFF6366F1),
                      ),
                      _buildInfoRow('Jenis', isWeekend ? 'Hari Libur' : 'Hari Kerja'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (lokasiMap.isNotEmpty) ...[
                    _buildLokasiCard(lokasiMap),
                    const SizedBox(height: 12),
                  ],

                  _buildBiayaCard(totalMitra, biayaPerMitra, biayaTotal),
                  const SizedBox(height: 12),

                  _buildInfoCard(
                    icon: Icons.description_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Alasan Lembur',
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.data['alasan'] ?? '-',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (widget.data['catatan_tambahan'] != null &&
                      widget.data['catatan_tambahan'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.note_add_rounded,
                      iconColor: Colors.amber,
                      title: 'Catatan Tambahan',
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            widget.data['catatan_tambahan'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (widget.mitraList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildMitraCard(),
                  ],

                  const SizedBox(height: 12),
                  _buildSpklCard(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // ✅ Tampilkan action buttons ATAU canceled banner
          if (canApprove || canReject)
            _buildActionButtons()
          else if (isCanceled)
            _buildCanceledBanner(),
        ],
      ),
    );
  }

  // ===========================================================================
  // ✅ CANCELED BANNER
  // ===========================================================================
  Widget _buildCanceledBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 10),
            Text(
              'Pengajuan ini telah dibatalkan',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================
  Widget _buildHeader(String status, String urgensi, bool isWeekend,
      bool isOverride, bool isOutside, bool isCanceled) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isCanceled ? Colors.grey : _getStatusColor(status)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCanceled ? Icons.cancel_rounded : _getStatusIcon(status),
                  color: isCanceled ? Colors.grey : _getStatusColor(status),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail Pengajuan',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.tag, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${(widget.data['group_id'] ?? '').toString().substring(0, 10)}...',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ✅ Tombol SPKL di header - hanya aktif jika sudah disetujui
              _buildHeaderAction(
                icon: Icons.picture_as_pdf_rounded,
                color: _canAccessSpkl ? Colors.red : Colors.grey,
                onTap: _canAccessSpkl ? _viewSpkl : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚠️ SPKL hanya tersedia setelah disetujui oleh $_roleLabel'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildHeaderAction(
                icon: Icons.refresh_rounded,
                color: Colors.green,
                onTap: () {
                  setState(() => _loadPengawasData());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('🔄 Memuat ulang data...'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildHeaderAction(
                icon: Icons.close_rounded,
                color: Colors.grey[600]!,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (isCanceled)
                _buildStatusBadge('DIBATALKAN', Colors.grey)
              else ...[
                _buildStatusBadge(_getStatusLabel(status), _getStatusColor(status)),
                _buildStatusBadge(urgensi.toUpperCase(), _getUrgensiColor(urgensi)),
              ],
              if (isWeekend) _buildStatusBadge('HARI LIBUR', Colors.purple),
              if (isOverride) _buildStatusBadge('OVERRIDE', Colors.orange),
              if (isOutside) _buildStatusBadge('LUAR RADIUS', Colors.deepOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // ===========================================================================
  // INFO CARD
  // ===========================================================================
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                color: valueColor ?? (widget.isDarkMode ? Colors.white : const Color(0xFF334155)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LOKASI CARD
  // ===========================================================================
  Widget _buildLokasiCard(Map<String, dynamic> lokasi) {
    String alamat = lokasi['alamat'] ?? '';
    final rt = lokasi['rt'] ?? '';
    final rw = lokasi['rw'] ?? '';
    if (rt.toString().isNotEmpty) alamat += ' RT $rt';
    if (rw.toString().isNotEmpty) alamat += ' RW $rw';
    final isOutside = lokasi['is_outside_radius'] == true;
    final lat = lokasi['latitude'];
    final lng = lokasi['longitude'];
    final hasCoordinates = lat != null && lng != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, color: Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Lokasi Lembur',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              _buildRadiusBadge(isOutside),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_rounded, size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alamat.isNotEmpty ? alamat : 'Tidak diketahui',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (hasCoordinates) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.pin_drop_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${(lat as num).toDouble().toStringAsFixed(6)}, ${(lng as num).toDouble().toStringAsFixed(6)}',
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showLokasiOptions(context, lat.toDouble(), lng.toDouble(), alamat),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_rounded, size: 16, color: Color(0xFF6366F1)),
                          const SizedBox(width: 4),
                          Text(
                            'Peta',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadiusBadge(bool isOutside) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOutside ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOutside ? Colors.orange.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOutside ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            size: 12,
            color: isOutside ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            isOutside ? 'LUAR' : 'DALAM',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isOutside ? Colors.orange : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BIAYA CARD
  // ===========================================================================
  Widget _buildBiayaCard(int totalMitra, double biayaPerMitra, double biayaTotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Estimasi Biaya',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCostRow('Per Mitra', _rateService.formatRupiah(biayaPerMitra)),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 8),
          _buildCostRow('Total ($totalMitra mitra)', _rateService.formatRupiah(biayaTotal), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isTotal ? 13 : 12,
            color: Colors.white.withValues(alpha: isTotal ? 1.0 : 0.8),
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: isTotal ? 20 : 14,
            fontWeight: FontWeight.w700,
            color: isTotal ? const Color(0xFFFCD34D) : Colors.white,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MITRA CARD
  // ===========================================================================
  Widget _buildMitraCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF8B5CF6), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Daftar Mitra',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.mitraList.length} orang',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF8B5CF6), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMitraTable(),
        ],
      ),
    );
  }

  Widget _buildMitraTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            _tableCellHeader('Nama'),
            _tableCellHeader('Fungsi'),
            _tableCellHeader('Biaya', textAlign: TextAlign.end),
          ],
        ),
        ...widget.mitraList.map((mitra) {
          final biaya = (mitra['estimasi_biaya_per_mitra'] ?? mitra['estimasi_biaya'] ?? 0).toDouble();
          return TableRow(
            children: [
              _tableCell(mitra['nama_mitra'] ?? '-', isBold: true),
              _tableCell(_getFungsiLabelCached(mitra['fungsi_mitra'])),
              _tableCell(
                _rateService.formatRupiah(biaya),
                textAlign: TextAlign.end,
                isBold: true,
                textColor: const Color(0xFF10B981),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _tableCellHeader(String text, {TextAlign textAlign = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: widget.isDarkMode ? Colors.grey[300] : const Color(0xFF64748B),
        ),
        textAlign: textAlign,
      ),
    );
  }

  Widget _tableCell(String text,
      {bool isBold = false, Color? textColor, TextAlign textAlign = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          color: textColor ?? (widget.isDarkMode ? Colors.white70 : const Color(0xFF334155)),
        ),
        textAlign: textAlign,
      ),
    );
  }

  // ===========================================================================
  // 🔥 SPKL CARD - FULLY FIXED (2 MODE: LOCKED / AVAILABLE)
  // ===========================================================================
  Widget _buildSpklCard() {
    final spklNomor = _getSpklNomor();
    final spklUrl = _getSpklUrl();
    final hasSpklUrl = spklUrl.isNotEmpty;
    final hasSpklNomor = spklNomor.isNotEmpty;
    final hasPreview = widget.onPreviewSpkl != null;
    final bool spklReady = hasSpklUrl || hasPreview;
    final bool isApproved = _canAccessSpkl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproved
              ? (spklReady ? Colors.green.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3))
              : Colors.orange.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header SPKL
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isApproved
                      ? (spklReady ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1))
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isApproved ? Icons.picture_as_pdf_rounded : Icons.lock_rounded,
                  color: isApproved ? (spklReady ? Colors.green : Colors.blue) : Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPKL 📄',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isApproved
                          ? (hasSpklNomor ? spklNomor : 'No. SPKL: Auto-Generate')
                          : '🔒 Menunggu Persetujuan',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isApproved
                            ? (widget.isDarkMode ? Colors.white70 : const Color(0xFF475569))
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isApproved
                      ? (spklReady ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1))
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isApproved
                        ? (spklReady ? Colors.green.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3))
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isApproved ? (spklReady ? 'TERSEDIA' : 'SIAP') : '🔒',
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: isApproved ? (spklReady ? Colors.green : Colors.blue) : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ================================================================
          // MODE 1: BELUM DISETUJUI → Tampilkan info SPKL terkunci
          // ================================================================
          if (!isApproved) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_rounded, size: 18, color: Colors.orange[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SPKL Belum Tersedia',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SPKL akan otomatis dibuat setelah pengajuan ini disetujui oleh $_roleLabel.\n'
                          'Silakan setujui pengajuan terlebih dahulu.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.orange[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue.shade600),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Setujui pengajuan ini untuk membuat SPKL secara otomatis',
                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.blue.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ================================================================
          // MODE 2: SUDAH DISETUJUI → Tampilkan tombol SPKL
          // ================================================================
          if (isApproved) ...[
            if (_isLoadingSpkl) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _loadingSpklMessage.isNotEmpty ? _loadingSpklMessage : 'Memproses...',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _viewSpkl,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(
                    hasSpklUrl ? 'Lihat SPKL' : 'Generate & Lihat SPKL',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (hasSpklUrl)
                _buildSpklInfoNote(icon: Icons.check_circle_outline, color: Colors.green, text: 'SPKL tersedia. Tap untuk melihat dokumen.')
              else if (hasPreview)
                _buildSpklInfoNote(icon: Icons.preview, color: const Color(0xFF6366F1), text: 'SPKL dapat dipreview. Tap tombol di atas.')
              else
                _buildSpklInfoNote(icon: Icons.auto_awesome, color: Colors.blue, text: 'SPKL akan digenerate otomatis saat tombol ditekan.'),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue.shade600),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'SPKL juga dapat diakses di menu Riwayat Lembur',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpklInfoNote({required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.poppins(fontSize: 10, color: color.withValues(alpha: 0.8))),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ACTION BUTTONS (DENGAN LABEL DINAMIS)
  // ===========================================================================
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              label: 'TOLAK',
              icon: Icons.close_rounded,
              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
              foregroundColor: const Color(0xFFEF4444),
              borderColor: const Color(0xFFEF4444),
              onPressed: widget.onReject,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _buildActionButton(
              label: 'SETUJUI ($_roleLabel)',
              icon: Icons.check_rounded,
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              onPressed: widget.onApprove,
              hasShadow: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    Color? borderColor,
    required VoidCallback onPressed,
    bool hasShadow = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
            boxShadow: hasShadow
                ? [BoxShadow(color: backgroundColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: foregroundColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STATUS BADGE
  // ===========================================================================
  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
  }

  // ===========================================================================
  // LOKASI OPTIONS
  // ===========================================================================
  void _showLokasiOptions(BuildContext context, double lat, double lng, String alamat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Lihat Lokasi', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.satellite_rounded, color: Color(0xFF6366F1)),
              ),
              title: Text('Lihat di Peta', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: Text('Tampilan satelit resolusi tinggi', style: GoogleFonts.poppins(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showLokasiOnMap(context, lat, lng, alamat, isSatellite: true);
              },
            ),
            const Divider(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String label) async {
    final encodedLabel = Uri.encodeComponent(label);
    final appUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final webUri = Uri.parse('https://www.google.com/maps?q=$lat,$lng($encodedLabel)');

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ Error opening Google Maps: $e');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLokasiOnMap(BuildContext context, double lat, double lng, String alamat, {bool isSatellite = true}) {
    showDialog(
      context: context,
      builder: (ctx) => _MapDialog(lat: lat, lng: lng, alamat: alamat, isSatellite: isSatellite),
    );
  }

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.hourglass_bottom_rounded;
      case 'disetujui': return Icons.check_circle_rounded;
      case 'ditolak': return Icons.cancel_rounded;
      default: return Icons.info_rounded;
    }
  }

  Color _getStatusColor(String s) {
    switch (s) {
      case 'pending': return Colors.orange;
      case 'disetujui': return const Color(0xFF10B981);
      case 'ditolak': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String s) {
    switch (s) {
      case 'pending': return 'Menunggu';
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      default: return s;
    }
  }

  Color _getUrgensiColor(String s) {
    switch (s) {
      case 'normal': return Colors.blue;
      case 'tinggi': return Colors.orange;
      case 'kritis': return const Color(0xFFEF4444);
      default: return Colors.blue;
    }
  }

  String _getFungsiLabelCached(String? f) {
    final key = f?.toLowerCase() ?? 'default';
    return _fungsiLabelCache[key] ??= _computeFungsiLabel(key);
  }

  String _computeFungsiLabel(String fungsi) {
    switch (fungsi) {
      case 'operation': return 'Operational';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'Business Support';
      default: return fungsi.isNotEmpty ? fungsi : 'Unknown';
    }
  }
}

// ===========================================================================
// MAP DIALOG (TETAP SAMA)
// ===========================================================================
class _MapDialog extends StatefulWidget {
  final double lat;
  final double lng;
  final String alamat;
  final bool isSatellite;

  const _MapDialog({required this.lat, required this.lng, required this.alamat, required this.isSatellite});

  @override
  State<_MapDialog> createState() => _MapDialogState();
}

class _MapDialogState extends State<_MapDialog> {
  late bool _isSatellite;

  static const String _satelliteUrl = 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
  static const String _streetUrl = 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

  String get _currentTileUrl => _isSatellite ? _satelliteUrl : _streetUrl;

  @override
  void initState() {
    super.initState();
    _isSatellite = widget.isSatellite;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(8),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(widget.lat, widget.lng),
                      initialZoom: 17.0,
                      minZoom: 5.0,
                      maxZoom: 21.0,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _currentTileUrl,
                        userAgentPackageName: 'com.pge.overtimeapp',
                        maxZoom: 21,
                        maxNativeZoom: 20,
                        fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            _isSatellite ? 'Google Satellite' : 'Google Maps',
                            onTap: () => launchUrl(Uri.parse('https://maps.google.com')),
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(widget.lat, widget.lng),
                            width: 150,
                            height: 100,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                                  ),
                                  child: Text('📍 Lokasi Lembur',
                                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                                ),
                                Container(width: 2, height: 6, color: Colors.red.withValues(alpha: 0.8)),
                                const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 40, shadows: [Shadow(color: Colors.black38, blurRadius: 6)]),
                              ],
                            ),
                          ),
                          Marker(
                            point: LatLng(widget.lat, widget.lng),
                            width: 80,
                            height: 80,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 2),
                                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12, right: 12,
                    child: Column(
                      children: [
                        _buildToggleBtn(Icons.satellite_rounded, 'Satelit', _isSatellite, () => setState(() => _isSatellite = true)),
                        const SizedBox(height: 6),
                        _buildToggleBtn(Icons.map_rounded, 'Jalan', !_isSatellite, () => setState(() => _isSatellite = false)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleBtn(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6366F1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : const Color(0xFF6366F1)),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF6366F1))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_isSatellite ? Icons.satellite_rounded : Icons.map_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Lokasi Lembur', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(_isSatellite ? '🛰️ Satelit' : '🛣️ Jalan', style: GoogleFonts.poppins(fontSize: 9, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          if (widget.alamat.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.alamat, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 4),
          Text('${widget.lat.toStringAsFixed(6)}, ${widget.lng.toStringAsFixed(6)}',
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.grey[50], border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isSatellite ? 'Tampilan satelit • Tap tombol untuk ganti ke peta jalan' : 'Tampilan jalan • Tap tombol untuk ganti ke satelit',
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}