import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

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
// PRIVATE CONTENT WIDGET
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

  bool _isLoading = false;
  String _loadingMessage = '';

  List<OvertimeHistory> _mitraList = [];
  bool _loadingMitra = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.isMultiple == true) {
      _loadMitraList();
    }
  }

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
  // 🔥 SPKL STATUS CHECK - SIMPLIFIED
  // ===========================================================================
  
  /// Cek apakah SPKL bisa diakses
  /// SPKL bisa diakses jika:
  /// 1. Status disetujui, ATAU
  /// 2. Data SPKL tersedia (apapun statusnya)
  bool get _spklAccessible {
    // Status disetujui
    if (widget.item.status.toLowerCase() == 'disetujui') return true;
    
    // Ada data SPKL (sudah pernah digenerate)
    if (widget.item.spklGenerated == true) return true;
    
    // Ada nomor SPKL
    if (widget.item.spklNomor != null && widget.item.spklNomor!.isNotEmpty) return true;
    
    // Ada group_id (bisa generate SPKL)
    final groupId = _safeString(widget.item.groupId, '');
    if (groupId.isNotEmpty) return true;
    
    return false;
  }

  // ===========================================================================
  // SAFE HELPERS
  // ===========================================================================

  String _safeString(dynamic val, [String fallback = '-']) {
    if (val == null) return fallback;
    final text = val.toString().trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _safeDateLong(dynamic date) {
    if (date == null) return '-';
    if (date is DateTime) {
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    }
    if (date is int || date is double) {
      final ms = date.toInt();
      if (ms > 0) {
        return DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
            .format(DateTime.fromMillisecondsSinceEpoch(ms));
      }
    }
    return '-';
  }

  String _safeDate(dynamic date) {
    if (date == null) return '-';
    if (date is DateTime) {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
    }
    return '-';
  }

  String _formatRupiah(dynamic amount) {
    double value = 0;
    if (amount is double) value = amount;
    else if (amount is int) value = amount.toDouble();
    else if (amount is String) value = double.tryParse(amount) ?? 0;
    return widget.rateService.formatRupiah(value);
  }

  Map<String, dynamic> get _lokasi {
    return widget.item.lokasi;
  }

  // ===========================================================================
  // 🔥🔥🔥 SPKL ACTION — LIHAT SPKL (MENGIKUTI POLA APPROVAL DETAIL)
  // ===========================================================================

  Future<void> _viewSpkl() async {
    if (_isLoading) return;
    if (!mounted) return;
    
    try {
      setState(() { 
        _isLoading = true; 
        _loadingMessage = '⏳ Memproses SPKL...';
      });

      // 🔥 LANGKAH 1: Siapkan data lembur untuk generate SPKL
      // Konversi OvertimeHistory ke Map seperti di approval detail
      final overtimeData = _buildOvertimeDataMap();
      
      setState(() => _loadingMessage = '📄 Menyiapkan dokumen PDF...');
      
      // 🔥 LANGKAH 2: Generate SPKL dari data lembur (seperti approval detail)
      final filePath = await _spklGenerator.generateSpklFromOvertimeData(overtimeData);
      
      if (filePath.isNotEmpty) {
        setState(() => _loadingMessage = '📱 Membuka SPKL...');
        
        final result = await OpenFilex.open(filePath);
        
        if (result.type == ResultType.done) {
          // ✅ Berhasil dibuka
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('✅ SPKL berhasil dibuka', 
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.white))),
                ]),
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
                content: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('⚠️ Tidak ada aplikasi PDF reader.\nInstall PDF reader terlebih dahulu.',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.white))),
                ]),
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
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(
                'Gagal membuka SPKL. Silakan coba lagi.\n\n'
                '💡 SPKL dapat diakses di menu Riwayat Lembur',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white))),
            ]),
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
      data['_mitra_list'] = _mitraList.map((mitra) => {
        'nama_mitra': mitra.namaMitra ?? '',
        'fungsi_mitra': mitra.fungsiMitra ?? '',
        'estimasi_biaya_per_mitra': mitra.estimasiBiayaPerMitra ?? 0,
      }).toList();
    } else if (widget.item.isMultiple == true) {
      // Jika mitra list belum load, buat dummy list dengan data yang ada
      data['_mitra_list'] = [{
        'nama_mitra': widget.item.namaMitra ?? 'Mitra 1',
        'fungsi_mitra': widget.item.fungsiMitra ?? '',
        'estimasi_biaya_per_mitra': widget.item.estimasiBiayaPerMitra ?? 0,
      }];
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
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final spklAccessible = _spklAccessible;
    final status = widget.item.status.toLowerCase();
    
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            children: [
              _buildHandle(),
              const SizedBox(height: 16),
              _buildHeader(spklAccessible),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: widget.scrollController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildStatusSection(),
                    const SizedBox(height: 14),
                    _buildTimeSection(),
                    const SizedBox(height: 14),
                    _buildLokasiSection(),
                    const SizedBox(height: 14),
                    _buildPersonnelSection(),
                    const SizedBox(height: 14),
                    _buildCostSection(),
                    const SizedBox(height: 14),
                    // 🔥 SPKL Section - Selalu tampilkan
                    _buildSpklSection(spklAccessible),
                    const SizedBox(height: 14),
                    _buildTimestampSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- HANDLE ----------
  Widget _buildHandle() => Center(
        child: Container(
          width: 50, height: 5,
          decoration: BoxDecoration(
            color: Colors.grey.shade300, 
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );

  // ---------- HEADER ----------
  Widget _buildHeader(bool spklAccessible) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Detail Lembur', 
            style: GoogleFonts.poppins(
              fontSize: 20, 
              fontWeight: FontWeight.bold, 
              color: Colors.black87,
            ),
          ),
        ),
        // 🔥 Tombol SPKL selalu tampil di header
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _viewSpkl,
          icon: _isLoading 
            ? const SizedBox(
                width: 16, height: 16, 
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ) 
            : const Icon(Icons.picture_as_pdf, size: 18),
          label: Text(
            _isLoading ? '...' : 'SPKL', 
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700, 
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  // ---------- SECTIONS ----------

  Widget _buildStatusSection() {
    final color = OvertimeHelpers.getStatusColor(widget.item.status);
    final statusText = OvertimeHelpers.getStatusText(widget.item.status);
    return _card(title: 'Status', icon: Icons.flag, child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12), 
          borderRadius: BorderRadius.circular(14), 
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(statusText, 
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
      ),
      if (widget.item.spklNomor != null && widget.item.spklNomor!.isNotEmpty) ...[
        const SizedBox(width: 12),
        Expanded(child: Text('No: ${widget.item.spklNomor}', 
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]), 
          overflow: TextOverflow.ellipsis)),
      ],
    ]));
  }

  Widget _buildTimeSection() {
    return _card(title: 'Waktu', icon: Icons.access_time, child: Column(children: [
      _detailRow('Tanggal', _safeDateLong(widget.item.tanggal)),
      _detailRow('Jam', '${_safeString(widget.item.jamMulai)} - ${_safeString(widget.item.jamSelesai)}'),
      _detailRow('Durasi', '${widget.item.totalJam.toStringAsFixed(1)} jam'),
    ]));
  }

  Widget _buildLokasiSection() {
    final alamat = _lokasi['alamat'] ?? '';
    final rt = _lokasi['rt'] ?? '';
    final rw = _lokasi['rw'] ?? '';
    String alamatLengkap = alamat;
    if (rt.toString().isNotEmpty) alamatLengkap += ' RT $rt';
    if (rw.toString().isNotEmpty) alamatLengkap += ' RW $rw';
    final lat = _lokasi['latitude'];
    final lng = _lokasi['longitude'];
    final bool hasCoordinates = lat != null && lng != null;

    return _card(
      title: 'Lokasi',
      icon: Icons.location_on,
      child: Column(children: [
        _detailRow('Alamat', alamatLengkap.isNotEmpty ? alamatLengkap : 'Tidak diketahui'),
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
                  onTap: () => _showLokasiOptions(
                    context,
                    (lat).toDouble(),
                    (lng).toDouble(),
                    alamatLengkap,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      ),
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
      ]),
    );
  }

  Widget _buildPersonnelSection() {
    final namaPengaju = widget.item.namaPengaju;
    return _card(title: 'Personil', icon: Icons.people, child: Column(children: [
      _detailRow('Pengawas', _safeString(namaPengaju)),
      if (widget.item.isMultiple == true) ...[
        _detailRow('Mitra', '${widget.item.totalMitra} Orang'),
        const SizedBox(height: 8),
        if (_loadingMitra)
          const Center(child: Padding(
            padding: EdgeInsets.all(8), 
            child: SizedBox(width: 16, height: 16, 
              child: CircularProgressIndicator(strokeWidth: 2)),
          ))
        else if (_mitraList.isNotEmpty)
          _buildMitraTable(_mitraList)
        else
          Text('Daftar mitra tidak tersedia', 
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
      ] else ...[
        _detailRow('Nama Mitra', _safeString(widget.item.namaMitra)),
      ],
    ]));
  }

  Widget _buildMitraTable(List<OvertimeHistory> mitraList) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
      columnWidths: const {
        0: FlexColumnWidth(3), 
        1: FlexColumnWidth(2), 
        2: FlexColumnWidth(2),
      },
      children: [
        TableRow(decoration: BoxDecoration(color: Colors.grey[100]), children: [
          _tableCellHeader('Nama'), _tableCellHeader('Fungsi'), _tableCellHeader('Biaya'),
        ]),
        ...mitraList.map((m) {
          final biaya = m.estimasiBiayaPerMitra;
          return TableRow(children: [
            _tableCell(m.namaMitra ?? '-'),
            _tableCell(m.fungsiMitra ?? '-'),
            _tableCell(_formatRupiah(biaya), bold: true),
          ]);
        }),
      ],
    );
  }

  Widget _tableCellHeader(String text) => Padding(
    padding: const EdgeInsets.all(6),
    child: Text(text, 
      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
  );

  Widget _tableCell(String text, {bool bold = false}) => Padding(
    padding: const EdgeInsets.all(6),
    child: Text(text, 
      style: GoogleFonts.poppins(
        fontSize: 11, 
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal, 
        color: Colors.black87,
      )),
  );

  Widget _buildCostSection() {
    final isMitraDoc = widget.item.isMitraDocument;
    final perMitra = widget.item.estimasiBiayaPerMitra;
    final total = widget.item.estimasiBiayaTotal;
    return _card(title: 'Estimasi Biaya', icon: Icons.payments, child: Column(children: [
      if (isMitraDoc)
        _detailRow('Biaya', _formatRupiah(perMitra))
      else ...[
        if (widget.item.isMultiple == true) _detailRow('Per Mitra', _formatRupiah(perMitra)),
        _detailRow('Total', _formatRupiah(total)),
      ],
    ]));
  }

  // 🔥🔥🔥 SPKL SECTION - SELALU TAMPIL (MENGIKUTI POLA APPROVAL DETAIL)
  Widget _buildSpklSection(bool spklAccessible) {
    final spklNomor = widget.item.spklNomor ?? '';
    final hasSpklNomor = spklNomor.isNotEmpty;
    final status = widget.item.status.toLowerCase();
    final isApproved = status == 'disetujui';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), 
            blurRadius: 8, 
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
                  color: spklAccessible 
                    ? Colors.green.withValues(alpha: 0.1) 
                    : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: spklAccessible ? Colors.green : Colors.blue,
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
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasSpklNomor ? spklNomor : 'No. SPKL: Auto-Generate',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: spklAccessible 
                    ? Colors.green.withValues(alpha: 0.1) 
                    : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: spklAccessible 
                      ? Colors.green.withValues(alpha: 0.3) 
                      : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  spklAccessible ? 'TERSEDIA' : 'BELUM',
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: spklAccessible ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          // Loading indicator
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
                    width: 16, height: 16, 
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
            // 🔥 Tombol Lihat SPKL - Selalu aktif
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _viewSpkl,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(
                  spklAccessible ? 'Lihat SPKL' : 'Generate & Lihat SPKL',
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
            
            // Info note
            if (spklAccessible && isApproved)
              _buildSpklInfoNote(
                icon: Icons.check_circle_outline, 
                color: Colors.green, 
                text: 'SPKL tersedia. Tap untuk melihat dokumen.',
              )
            else if (spklAccessible)
              _buildSpklInfoNote(
                icon: Icons.info_outline, 
                color: Colors.blue, 
                text: 'SPKL dapat digenerate. Tap tombol di atas.',
              )
            else
              _buildSpklInfoNote(
                icon: Icons.auto_awesome, 
                color: Colors.orange, 
                text: 'SPKL akan digenerate otomatis saat tombol ditekan.',
              ),
          ],
          
          const SizedBox(height: 8),
          
          // 🔥 Catatan: SPKL dapat diakses di menu Riwayat Lembur
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
                Text(
                  'SPKL dapat diakses di menu Riwayat Lembur',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildTimestampSection() {
    return _card(title: 'Riwayat', icon: Icons.history, child: Column(children: [
      _detailRow('Dibuat', _safeDate(widget.item.createdAt)),
      _detailRow('Diupdate', _safeDate(widget.item.updatedAt)),
    ]));
  }

  // ===========================================================================
  // REUSABLE COMPONENTS
  // ===========================================================================

  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), 
            blurRadius: 8, 
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: const Color(0xFF1976D2)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, 
            overflow: TextOverflow.ellipsis, 
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87))),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110, 
          child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        ),
        Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87))),
      ]),
    );
  }
}

// ===========================================================================
// 🔥🔥🔥 MAP DIALOG - GOOGLE MAPS TILE
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