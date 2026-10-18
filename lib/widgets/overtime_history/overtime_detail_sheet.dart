import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/core/services/overtime_approval_service.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';
import '/core/services/spkl_generator_service.dart';
import '/widgets/overtime_history/overtime_helpers.dart';

class OvertimeDetailSheet {
  static void show(
    BuildContext context,
    OvertimeHistory item,
    OvertimeRateService rateService,
    String? userId,
    String? userName,
  ) {
    if (!context.mounted) return;
    try {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (sheetContext) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            minChildSize: 0.50,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return _DetailSheetContent(
                item: item,
                rateService: rateService,
                scrollController: scrollController,
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('ERROR: OvertimeDetailSheet.show(): $e');
    }
  }
}

// ===========================================================================
// PRIVATE CONTENT WIDGET - MENGIKUTI POLA APPROVAL DETAIL
// ===========================================================================

class _DetailSheetContent extends StatefulWidget {
  final OvertimeHistory item;
  final OvertimeRateService rateService;
  final ScrollController scrollController;

  const _DetailSheetContent({
    required this.item,
    required this.rateService,
    required this.scrollController,
  });

  @override
  State<_DetailSheetContent> createState() => _DetailSheetContentState();
}

class _DetailSheetContentState extends State<_DetailSheetContent> {
  final SpklGeneratorService _spklGenerator = SpklGeneratorService();
  final OvertimeApprovalService _approvalService = OvertimeApprovalService();
  final OvertimeHistoryService _historyService = OvertimeHistoryService();
  static final _rateService = OvertimeRateService();
  static final Map<String, String> _fungsiLabelCache = {};

  bool _isLoading = false;
  String _loadingMessage = '';

  List<OvertimeHistory> _mitraList = [];
  bool _loadingMitra = false;

  // Data pengawas dari Firestore
  Map<String, dynamic>? _pengawasData;
  bool _isLoadingPengawas = true;

  // ✅ STATUS YANG DIANGGAP DIBATALKAN
  static const List<String> _canceledStatuses = ['dibatalkan', 'canceled'];

  // ✅ STATUS YANG SUDAH DISETUJUI (BOLEH AKSES SPKL)
  static const List<String> _approvedStatuses = ['disetujui', 'approved', 'selesai', 'completed'];

  // ✅ GETTER: Apakah SPKL boleh diakses?
  bool get _canAccessSpkl {
    final status = widget.item.status.toLowerCase();
    return _approvedStatuses.contains(status);
  }

  @override
  void initState() {
    super.initState();
    if (widget.item.isMultiple == true) {
      _loadMitraList();
    }
    _loadPengawasData();

    // 🔍 DEBUG
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('🔍 DETAIL HISTORY SHEET INIT:');
    debugPrint('  📌 Status: ${widget.item.status}');
    debugPrint('  📌 Can Access SPKL: $_canAccessSpkl');
    debugPrint('  📌 Group ID: ${widget.item.groupId}');
    debugPrint('  📌 SPKL Generated: ${widget.item.spklGenerated}');
    debugPrint('  📌 SPKL Nomor: ${widget.item.spklNomor}');
    debugPrint('═══════════════════════════════════════════════');
  }

  // ===========================================================================
  // LOAD MITRA LIST
  // ===========================================================================
  Future<void> _loadMitraList() async {
    if (_loadingMitra) return;
    setState(() => _loadingMitra = true);
    try {
      final groupId = widget.item.groupId;
      if (groupId.isNotEmpty) {
        final list = await _historyService.getOvertimeByGroupId(groupId);
        if (mounted) setState(() => _mitraList = list);
      }
    } catch (e) {
      debugPrint('Error loading mitra list: $e');
    } finally {
      if (mounted) setState(() => _loadingMitra = false);
    }
  }

  // ===========================================================================
  // LOAD PENGAWAS DATA DARI FIRESTORE
  // ===========================================================================
  Future<void> _loadPengawasData() async {
    try {
      final pengawasId = widget.item.pengawasId ?? '';

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
  // SAFE HELPERS
  // ===========================================================================
  String _safeString(dynamic val, [String fallback = '-']) {
    if (val == null) return fallback;
    final text = val.toString().trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _formatRupiah(dynamic amount) {
    double value = 0;
    if (amount is double) value = amount;
    else if (amount is int) value = amount.toDouble();
    else if (amount is String) value = double.tryParse(amount) ?? 0;
    return widget.rateService.formatRupiah(value);
  }

  Map<String, dynamic> get _lokasi {
    final loc = widget.item.lokasi;
    if (loc is Map<String, dynamic>) return loc;
    return {};
  }

  // ===========================================================================
  // 🔥 SPKL HELPER METHODS (MENGIKUTI APPROVAL DETAIL)
  // ===========================================================================
  String _getSpklNomor() {
    final nomor = widget.item.spklNomor;
    if (nomor != null && nomor.isNotEmpty) return nomor;
    return '';
  }

  // ===========================================================================
  // 🔥🔥🔥 SPKL ACTION — LIHAT SPKL (MENGIKUTI POLA APPROVAL DETAIL)
  // ===========================================================================
  Future<void> _viewSpkl() async {
    // ✅ VALIDASI: SPKL hanya bisa diakses jika sudah disetujui
    if (!_canAccessSpkl) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '⚠️ SPKL hanya tersedia setelah pengajuan disetujui.',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (_isLoading) return;
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _loadingMessage = '⏳ Memproses SPKL...';
      });

      // 🔥 LANGKAH 1: Siapkan data lembur untuk generate SPKL
      final overtimeData = _buildOvertimeDataMap();

      setState(() => _loadingMessage = '📄 Menyiapkan dokumen PDF...');

      // 🔥 LANGKAH 2: Generate SPKL dari data lembur
      final filePath =
          await _spklGenerator.generateSpklFromOvertimeData(overtimeData);

      if (filePath.isNotEmpty) {
        setState(() => _loadingMessage = '📱 Membuka SPKL...');

        final result = await OpenFilex.open(filePath);

        if (result.type == ResultType.done) {
          // ✅ Berhasil dibuka
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '✅ SPKL berhasil dibuka',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (result.type == ResultType.noAppToOpen) {
          // ⚠️ Tidak ada PDF reader
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '⚠️ Tidak ada aplikasi PDF reader.\nInstall PDF reader terlebih dahulu.',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gagal membuka SPKL. Silakan coba lagi.\n\n'
                    '💡 SPKL dapat diakses di menu Riwayat Lembur',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
      }
    }
  }

  // 🔥 Konversi OvertimeHistory ke Map untuk SPKL Generator
  Map<String, dynamic> _buildOvertimeDataMap() {
    final data = <String, dynamic>{
      // Data utama
      'group_id': widget.item.groupId ?? '',
      'status': widget.item.status ?? 'pending',
      'tanggal': widget.item.tanggal,
      'jam_mulai': widget.item.jamMulai ?? '',
      'jam_selesai': widget.item.jamSelesai ?? '',
      'total_jam_desimal': widget.item.totalJam ?? 0,
      'alasan': widget.item.alasan ?? '',
      'urgensi': 'normal',

      // Info pengawas
      'nama_pengawas': widget.item.namaPengaju ?? '',
      'pengawas_id': widget.item.pengawasId ?? '',

      // Info mitra (single)
      'nama_mitra': widget.item.namaMitra ?? '',
      'fungsi_mitra': widget.item.fungsiMitra ?? '',

      // Biaya
      'estimasi_biaya_per_mitra': widget.item.estimasiBiayaPerMitra ?? 0,
      'estimasi_biaya_total': widget.item.estimasiBiayaTotal ?? 0,
      'total_mitra': widget.item.totalMitra ?? 1,
      'is_multiple': widget.item.isMultiple ?? false,

      // SPKL info
      'spkl_nomor': widget.item.spklNomor ?? '',
      'spkl_generated': widget.item.spklGenerated ?? false,

      // Lokasi
      'lokasi': widget.item.lokasi ?? {},

      // Created/Updated
      'created_at': widget.item.createdAt,
      'updated_at': widget.item.updatedAt,
    };

    // 🔥 Tambahkan mitra list jika multiple
    if (widget.item.isMultiple == true && _mitraList.isNotEmpty) {
      data['_mitra_list'] = _mitraList
          .map((mitra) => {
                'nama_mitra': mitra.namaMitra ?? '',
                'fungsi_mitra': mitra.fungsiMitra ?? '',
                'estimasi_biaya_per_mitra': mitra.estimasiBiayaPerMitra ?? 0,
              })
          .toList();
    } else if (widget.item.isMultiple == true) {
      data['_mitra_list'] = [
        {
          'nama_mitra': widget.item.namaMitra ?? 'Mitra 1',
          'fungsi_mitra': widget.item.fungsiMitra ?? '',
          'estimasi_biaya_per_mitra': widget.item.estimasiBiayaPerMitra ?? 0,
        }
      ];
    }

    return data;
  }

  // ===========================================================================
  // 🔥🔥🔥 PETA - MENGIKUTI POLA APPROVAL DETAIL BOTTOM SHEET
  // ===========================================================================
  void _showLokasiOptions(BuildContext context, double lat, double lng, String alamat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Lihat Lokasi',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.satellite_rounded, color: Color(0xFF6366F1)),
              ),
              title: Text('Lihat di Peta',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: Text('Tampilan satelit resolusi tinggi',
                  style: GoogleFonts.poppins(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showLokasiOnMap(context, lat, lng, alamat, isSatellite: true);
              },
            ),
            const Divider(height: 8),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.open_in_browser_rounded, color: Colors.green),
              ),
              title: Text('Buka di Google Maps',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: Text('Buka lokasi dengan aplikasi Google Maps',
                  style: GoogleFonts.poppins(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _openInGoogleMaps(lat, lng, alamat);
              },
            ),
            const SizedBox(height: 16),
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
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _showLokasiOnMap(BuildContext context, double lat, double lng, String alamat, {bool isSatellite = true}) {
    showDialog(
      context: context,
      builder: (ctx) => _MapDialog(
        lat: lat,
        lng: lng,
        alamat: alamat,
        isSatellite: isSatellite,
      ),
    );
  }

  // ===========================================================================
  // BUILD - MENGIKUTI STRUKTUR APPROVAL DETAIL
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final status = widget.item.status.toLowerCase();
    final isCanceled = _canceledStatuses.contains(status);

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
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

          // Header (mengikuti pola approval detail)
          _buildHeader(status, isCanceled),

          // Content scrollable
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informasi Pengawas
                  _buildInfoCard(
                    icon: Icons.person_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: 'Informasi Pengawas',
                    children: [
                      _buildInfoRow('Nama',
                          _pengawasData?['nama_lengkap'] ?? widget.item.namaPengaju ?? '-'),
                      _buildInfoRow('Fungsi',
                          _getFungsiLabelCached(widget.item.fungsiPengawas)),
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

                  // Waktu Lembur
                  _buildInfoCard(
                    icon: Icons.access_time_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Waktu Lembur',
                    children: [
                      _buildInfoRow(
                        'Tanggal',
                        widget.item.tanggal != null
                            ? DateFormat('EEEE, dd MMM yyyy', 'id_ID')
                                .format(_toDate(widget.item.tanggal))
                            : '-',
                      ),
                      _buildInfoRow('Jam',
                          '${_safeString(widget.item.jamMulai)} - ${_safeString(widget.item.jamSelesai)}'),
                      _buildInfoRow(
                        'Durasi',
                        '${(widget.item.totalJam ?? 0).toStringAsFixed(1)} jam',
                        isBold: true,
                        valueColor: const Color(0xFF6366F1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lokasi
                  if (_lokasi.isNotEmpty) ...[
                    _buildLokasiCard(_lokasi),
                    const SizedBox(height: 12),
                  ],

                  // Biaya
                  _buildBiayaCard(),
                  const SizedBox(height: 12),

                  // Alasan
                  _buildInfoCard(
                    icon: Icons.description_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Alasan Lembur',
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.item.alasan ?? '-',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF475569),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Mitra List
                  if (widget.item.isMultiple == true && _mitraList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildMitraCard(),
                  ],

                  // 🔥 SPKL Card (selalu tampil)
                  const SizedBox(height: 12),
                  _buildSpklCard(),

                  // Timestamp
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.history_rounded,
                    iconColor: Colors.grey,
                    title: 'Riwayat',
                    children: [
                      _buildInfoRow(
                        'Dibuat',
                        widget.item.createdAt != null
                            ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
                                .format(_toDate(widget.item.createdAt))
                            : '-',
                      ),
                      _buildInfoRow(
                        'Diupdate',
                        widget.item.updatedAt != null
                            ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
                                .format(_toDate(widget.item.updatedAt))
                            : '-',
                      ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // ✅ Canceled banner (jika dibatalkan)
          if (isCanceled) _buildCanceledBanner(),
        ],
      ),
    );
  }

  // ===========================================================================
  // HEADER - MENGIKUTI POLA APPROVAL DETAIL
  // ===========================================================================
  Widget _buildHeader(String status, bool isCanceled) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 2),
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
                      'Detail Lembur',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.tag, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${(widget.item.groupId ?? '').toString().substring(0, 10)}...',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ✅ Tombol SPKL di header
              _buildHeaderAction(
                icon: Icons.picture_as_pdf_rounded,
                color: _canAccessSpkl ? Colors.red : Colors.grey,
                onTap: _canAccessSpkl ? _viewSpkl : () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '⚠️ SPKL hanya tersedia setelah disetujui',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
              _buildHeaderAction(
                icon: Icons.refresh_rounded,
                color: Colors.green,
                onTap: () {
                  setState(() {
                    _loadPengawasData();
                    if (widget.item.isMultiple == true) _loadMitraList();
                  });
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
              ],
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
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ===========================================================================
  // CANCELED BANNER
  // ===========================================================================
  Widget _buildCanceledBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -3),
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
  // INFO CARD (MENGIKUTI POLA APPROVAL DETAIL)
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
        color: Colors.white,
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
                  color: const Color(0xFF1E293B),
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
                color: valueColor ?? const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LOKASI CARD (MENGIKUTI POLA APPROVAL DETAIL)
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
        color: Colors.white,
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
                  color: const Color(0xFF1E293B),
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
                    color: const Color(0xFF475569),
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
  // BIAYA CARD (MENGIKUTI POLA APPROVAL DETAIL)
  // ===========================================================================
  Widget _buildBiayaCard() {
    final totalMitra = widget.item.isMultiple == true
        ? (widget.item.totalMitra ?? 1)
        : 1;
    final biayaTotal = widget.item.estimasiBiayaTotal ?? 0.0;
    final biayaPerMitra = totalMitra > 0 ? biayaTotal / totalMitra : 0.0;

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
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.item.isMultiple == true)
            _buildCostRow('Per Mitra', widget.rateService.formatRupiah(biayaPerMitra)),
          if (widget.item.isMultiple == true) const SizedBox(height: 8),
          if (widget.item.isMultiple == true)
            Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          if (widget.item.isMultiple == true) const SizedBox(height: 8),
          _buildCostRow(
            widget.item.isMultiple == true ? 'Total ($totalMitra mitra)' : 'Total Biaya',
            widget.rateService.formatRupiah(biayaTotal),
            isTotal: true,
          ),
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
  // MITRA CARD (MENGIKUTI POLA APPROVAL DETAIL)
  // ===========================================================================
  Widget _buildMitraCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  color: const Color(0xFF1E293B),
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
                  '${_mitraList.length} orang',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w600,
                  ),
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
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            _tableCellHeader('Nama'),
            _tableCellHeader('Fungsi'),
            _tableCellHeader('Biaya', textAlign: TextAlign.end),
          ],
        ),
        ..._mitraList.map((mitra) {
          final biaya = (mitra.estimasiBiayaPerMitra ?? 0).toDouble();
          return TableRow(
            children: [
              _tableCell(mitra.namaMitra ?? '-', isBold: true),
              _tableCell(_getFungsiLabelCached(mitra.fungsiMitra)),
              _tableCell(
                widget.rateService.formatRupiah(biaya),
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
          color: const Color(0xFF64748B),
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
          color: textColor ?? const Color(0xFF334155),
        ),
        textAlign: textAlign,
      ),
    );
  }

  // ===========================================================================
  // 🔥 SPKL CARD - MENGIKUTI POLA APPROVAL DETAIL (2 MODE: LOCKED / AVAILABLE)
  // ===========================================================================
  Widget _buildSpklCard() {
    final spklNomor = _getSpklNomor();
    final hasSpklNomor = spklNomor.isNotEmpty;
    final bool isApproved = _canAccessSpkl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproved
              ? Colors.blue.withValues(alpha: 0.3)
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
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isApproved ? Icons.picture_as_pdf_rounded : Icons.lock_rounded,
                  color: isApproved ? Colors.blue : Colors.orange,
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
                        color: const Color(0xFF1E293B),
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
                        color: isApproved ? const Color(0xFF475569) : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isApproved
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isApproved
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isApproved ? 'TERSEDIA' : '🔒',
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: isApproved ? Colors.green : Colors.orange,
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
                          'SPKL akan otomatis dibuat setelah pengajuan ini disetujui.\n'
                          'Silakan tunggu persetujuan dari atasan.',
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
                      'SPKL hanya dapat diakses setelah pengajuan disetujui',
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
            if (_isLoading) ...[
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
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _loadingMessage.isNotEmpty ? _loadingMessage : 'Memproses...',
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
                    'Lihat SPKL',
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
              _buildSpklInfoNote(
                icon: Icons.check_circle_outline,
                color: Colors.green,
                text: 'SPKL tersedia. Tap untuk melihat dokumen.',
              ),
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

  Widget _buildSpklInfoNote({
    required IconData icon,
    required Color color,
    required String text,
  }) {
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
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 10, color: color.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_bottom_rounded;
      case 'disetujui':
        return Icons.check_circle_rounded;
      case 'ditolak':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getStatusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'disetujui':
        return const Color(0xFF10B981);
      case 'ditolak':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Menunggu';
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      default:
        return s;
    }
  }

  String _getFungsiLabelCached(String? f) {
    final key = f?.toLowerCase() ?? 'default';
    return _fungsiLabelCache[key] ??= _computeFungsiLabel(key);
  }

  String _computeFungsiLabel(String fungsi) {
    switch (fungsi) {
      case 'operation':
        return 'Operational';
      case 'maintenance':
        return 'Maintenance';
      case 'hsse':
        return 'HSSE';
      case 'gpr':
        return 'GPR';
      case 'bs':
        return 'Business Support';
      default:
        return fungsi.isNotEmpty ? fungsi : 'Unknown';
    }
  }
}

// ===========================================================================
// MAP DIALOG - MENGIKUTI POLA APPROVAL DETAIL
// ===========================================================================
class _MapDialog extends StatefulWidget {
  final double lat;
  final double lng;
  final String alamat;
  final bool isSatellite;

  const _MapDialog({
    required this.lat,
    required this.lng,
    required this.alamat,
    required this.isSatellite,
  });

  @override
  State<_MapDialog> createState() => _MapDialogState();
}

class _MapDialogState extends State<_MapDialog> {
  late bool _isSatellite;

  static const String _satelliteUrl =
      'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
  static const String _streetUrl =
      'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '📍 Lokasi Lembur',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 6,
                                  color: Colors.red.withValues(alpha: 0.8),
                                ),
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 40,
                                  shadows: [
                                    Shadow(color: Colors.black38, blurRadius: 6),
                                  ],
                                ),
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
                                border: Border.all(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                  width: 2,
                                ),
                                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Toggle buttons
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Column(
                      children: [
                        _buildToggleBtn(
                          Icons.satellite_rounded,
                          'Satelit',
                          _isSatellite,
                          () => setState(() => _isSatellite = true),
                        ),
                        const SizedBox(height: 6),
                        _buildToggleBtn(
                          Icons.map_rounded,
                          'Jalan',
                          !_isSatellite,
                          () => setState(() => _isSatellite = false),
                        ),
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? Colors.white : const Color(0xFF6366F1),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0xFF6366F1),
                ),
              ),
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
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isSatellite ? Icons.satellite_rounded : Icons.map_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lokasi Lembur',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isSatellite ? '🛰️ Satelit' : '🛣️ Jalan',
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          if (widget.alamat.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.alamat,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white70,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${widget.lat.toStringAsFixed(6)}, ${widget.lng.toStringAsFixed(6)}',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isSatellite
                  ? 'Tampilan satelit • Tap tombol untuk ganti ke peta jalan'
                  : 'Tampilan jalan • Tap tombol untuk ganti ke satelit',
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final encodedLabel = Uri.encodeComponent(widget.alamat);
                final uri = Uri.parse(
                  'https://www.google.com/maps?q=${widget.lat},${widget.lng}($encodedLabel)',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.open_in_browser_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Google Maps',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}