// lib/widgets/overtime_history/overtime_card.dart
// 🔥 FINAL VERSION V3 - ALL ERRORS FIXED
// 🔥 Tidak Lembur: konfirmasi + alasan
// 🔥 Terlambat: dokumentasi + alasan keterlambatan
// 🔥 Normal: check-in & check-out + foto

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';
import '/widgets/overtime_history/overtime_detail_sheet.dart';
import '/widgets/overtime_history/overtime_helpers.dart';

class OvertimeCard extends StatelessWidget {
  final OvertimeHistory item;
  final OvertimeRateService rateService;
  final String? userId;
  final String? userName;
  final String? userRole;
  final bool showHSSEInfo;
  final bool useAccurateCost;

  const OvertimeCard({
    super.key,
    required this.item,
    required this.rateService,
    this.userId,
    this.userName,
    this.userRole,
    this.showHSSEInfo = false,
    this.useAccurateCost = false,
  });

  // ═══════════════════════════════════════════════════════
  // 🔥 DETEKSI TIPE TAMPILAN
  // ═══════════════════════════════════════════════════════
  bool get _isTidakLembur => item.absensiStatus == 'tidak_lembur';
  bool get _isTerlambat => item.absensiStatus == 'selesai_terlambat';
  bool get _isSelesai => item.absensiStatus == 'selesai';
  bool get _isNormal => _isSelesai && !_isTerlambat;

  @override
  Widget build(BuildContext context) {
    final statusColor = OvertimeHelpers.getStatusColor(item.status);
    final isUrgent = item.urgensi == 'kritis' || item.urgensi == 'tinggi';

    final biayaTampil = item.isMitraDocument
        ? item.estimasiBiayaPerMitra
        : item.estimasiBiayaTotal;

    final hasHSSEContent = showHSSEInfo && item.isRisky;
    final hasSpklContent = item.spklGenerated && item.status == 'disetujui';
    final hasAbsensiContent = _isTidakLembur || _isTerlambat || _isNormal;
    final hasExtraContent = hasHSSEContent || hasSpklContent || hasAbsensiContent;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUrgent ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUrgent ? Colors.red.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => OvertimeDetailSheet.show(
          context, item, rateService, userId, userName,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isUrgent
                ? LinearGradient(
                    colors: [Colors.red.withValues(alpha: 0.03), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          constraints: BoxConstraints(maxHeight: hasExtraContent ? 500 : 250),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // HEADER
                  _buildHeader(context, statusColor),
                  const SizedBox(height: 12),

                  // 🔥 HSSE INFO SECTION
                  if (hasHSSEContent) ...[
                    _buildHSSEInfoSection(),
                    const SizedBox(height: 12),
                  ],

                  // ═══════════════════════════════════════════════════
                  // 🔥🔥🔥 ABSENSI SECTION - TAMPILAN DINAMIS
                  // ═══════════════════════════════════════════════════
                  if (_isTidakLembur) ...[
                    _buildTidakLemburSection(),
                    const SizedBox(height: 12),
                  ] else if (_isTerlambat) ...[
                    _buildTerlambatSection(context),  // 🔥 Kirim context
                    const SizedBox(height: 12),
                  ] else if (_isNormal) ...[
                    _buildNormalAbsensiSection(context),  // 🔥 Kirim context
                    const SizedBox(height: 12),
                  ],

                  // INFO CHIPS
                  _buildInfoChips(isUrgent: isUrgent),
                  const SizedBox(height: 12),

                  // DIVIDER
                  Divider(color: Colors.grey.shade200, height: 1),
                  const SizedBox(height: 10),

                  // COST ROW
                  _buildCostRow(biayaTampil),

                  // SPKL INDICATOR
                  if (hasSpklContent) ...[
                    const SizedBox(height: 10),
                    _buildSpklIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 TIDAK LEMBUR: Konfirmasi + Alasan
  // ═══════════════════════════════════════════════════════
  Widget _buildTidakLemburSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_rounded, size: 16, color: Colors.red),
              const SizedBox(width: 6),
              Text('Tidak Melakukan Lembur',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('TIDAK LEMBUR',
                    style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAbsensiDetailRow(Icons.access_time, 'Dikonfirmasi',
              _formatDateTime(item.confirmedAt ?? item.checkOutTime)),
          const SizedBox(height: 4),
          _buildAbsensiDetailRow(Icons.description_outlined, 'Alasan',
              item.alasanTidakLembur ?? item.alasan ?? '-', maxLines: 3),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 TERLAMBAT: Dokumentasi Kerja + Alasan (DENGAN CONTEXT)
  // ═══════════════════════════════════════════════════════
  Widget _buildTerlambatSection(BuildContext context) {  // 🔥 Tambah parameter context
    final hasFoto = (item.checkInFotoUrl != null && item.checkInFotoUrl!.isNotEmpty) ||
                    (item.checkOutFotoUrl != null && item.checkOutFotoUrl!.isNotEmpty);
    final fotoUrl = item.checkInFotoUrl ?? item.checkOutFotoUrl;
    final alasanTerlambat = item.keterlambatanAlasan ?? item.alasan;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Text('Lembur Terlambat',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange.shade700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('TANPA CHECK-IN/OUT',
                    style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.orange.shade700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dokumentasi Kerja:',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                    if (hasFoto && fotoUrl != null)
                      GestureDetector(
                        onTap: () => _showPhotoPreview(context, fotoUrl!),  // 🔥 Kirim context + fotoUrl!
                        child: Container(
                          height: 80, width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            color: Colors.grey.shade100,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: CachedNetworkImage(
                              imageUrl: fotoUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Center(
                                child: SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange.withValues(alpha: 0.5))),
                              ),
                              errorWidget: (_, __, ___) =>
                                  Center(child: Icon(Icons.broken_image, size: 24, color: Colors.grey.shade400)),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Row(children: [
                          Icon(Icons.no_photography, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text('Tidak ada dokumentasi',
                              style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey.shade500)),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAbsensiDetailRow(Icons.description_outlined, 'Alasan Keterlambatan', alasanTerlambat ?? '-', maxLines: 3),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 NORMAL: Check-in & Check-out (DENGAN CONTEXT)
  // ═══════════════════════════════════════════════════════
  Widget _buildNormalAbsensiSection(BuildContext context) {  // 🔥 Tambah parameter context
    return Row(
      children: [
        Expanded(
          child: _buildAbsensiBox(
            context: context,  // 🔥 Kirim context
            label: 'Check-In',
            time: _formatTime(item.checkInTime),
            hasPhoto: item.checkInFotoUrl != null && item.checkInFotoUrl!.isNotEmpty,
            photoUrl: item.checkInFotoUrl,
            color: Colors.green,
            icon: Icons.login_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildAbsensiBox(
            context: context,  // 🔥 Kirim context
            label: 'Check-Out',
            time: _formatTime(item.checkOutTime),
            hasPhoto: item.checkOutFotoUrl != null && item.checkOutFotoUrl!.isNotEmpty,
            photoUrl: item.checkOutFotoUrl,
            color: Colors.red,
            icon: Icons.logout_rounded,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ABSENSI BOX (DENGAN CONTEXT)
  // ═══════════════════════════════════════════════════════
  Widget _buildAbsensiBox({
    required BuildContext context,  // 🔥 Tambah parameter context
    required String label,
    required String time,
    required bool hasPhoto,
    required String? photoUrl,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: color)),
              const Spacer(),
              if (hasPhoto && photoUrl != null)
                GestureDetector(
                  onTap: () => _showPhotoPreview(context, photoUrl),  // 🔥 Kirim context + photoUrl!
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                      color: Colors.grey.shade100,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Icon(Icons.image, size: 10, color: Colors.grey.shade400),
                        errorWidget: (_, __, ___) => Icon(Icons.broken_image, size: 10, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                )
              else
                Icon(Icons.no_photography, size: 12, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 4),
          Text(time,
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HELPER: Detail Row
  // ═══════════════════════════════════════════════════════
  Widget _buildAbsensiDetailRow(IconData icon, String label, String value, {int maxLines = 2}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
                  maxLines: maxLines, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 HSSE INFO SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildHSSEInfoSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: item.risikoLevelColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: item.risikoLevelColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(Icons.security, size: 14, color: item.risikoLevelColor),
            const SizedBox(width: 6),
            Text('HSSE Assessment', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: item.risikoLevelColor)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: item.risikoLevelColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(item.risikoLevelIcon, size: 10, color: item.risikoLevelColor),
                const SizedBox(width: 3),
                Text(item.risikoLevelLabel, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: item.risikoLevelColor)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          if (item.risikoKategori != null) ...[
            _buildHSSEDetailRow(Icons.category_outlined, 'Kategori', item.risikoKategori!),
            const SizedBox(height: 4),
          ],
          if (item.risikoDeskripsi != null && item.risikoDeskripsi!.isNotEmpty) ...[
            _buildHSSEDetailRow(Icons.description_outlined, 'Deskripsi',
                item.risikoDeskripsi!.length > 80 ? '${item.risikoDeskripsi!.substring(0, 80)}...' : item.risikoDeskripsi!),
            const SizedBox(height: 4),
          ],
          _buildHSSEDetailRow(Icons.track_changes, 'Status HSSE', item.hsseStatusLabel, valueColor: item.hsseStatusColor),
        ],
      ),
    );
  }

  Widget _buildHSSEDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 12, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Text('$label: ', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      Expanded(child: Text(value,
          style: GoogleFonts.poppins(fontSize: 10, color: valueColor ?? Colors.grey[800], fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]);
  }

  // ═══════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, Color statusColor) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_getCardTitle(), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          if (_isTerlambat) _buildMiniBadge('TERLAMBAT', Colors.orange),
          if (_isTidakLembur) _buildMiniBadge('TIDAK LEMBUR', Colors.red),
          if (item.spklGenerated && item.status == 'disetujui') _buildMiniBadge('SPKL', Colors.blue),
          if (showHSSEInfo && item.isRisky) _buildMiniBadge('HSSE', item.risikoLevelColor),
          const SizedBox(width: 4),
          _buildStatusBadge(statusColor),
        ]),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => context.push('/overtime-detail/${item.id}'),
          child: Text('${DateFormat('dd MMM yyyy', 'id_ID').format(item.tanggal)} • ${item.jamMulai} - ${item.jamSelesai}',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
        ),
      ])),
    ]);
  }

  String _getCardTitle() {
    if (item.isMultiple) return 'Lembur Grup (${item.totalMitra} mitra)';
    if (item.namaMitra != null && item.namaMitra!.isNotEmpty) return item.namaMitra!;
    if (item.namaPengawas != null && item.namaPengawas!.isNotEmpty) return item.namaPengawas!;
    return 'Unknown';
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 7, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(OvertimeHelpers.getStatusText(item.status), style: GoogleFonts.poppins(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }

  // INFO CHIPS, COST ROW, SPKL — TIDAK BERUBAH
  Widget _buildInfoChips({required bool isUrgent}) {
    final chips = <Widget>[];
    if (isUrgent) chips.add(_InfoChip(icon: Icons.warning_rounded, label: 'Urgent', color: Colors.red));
    chips.add(_InfoChip(icon: Icons.access_time, label: '${item.totalJam.toStringAsFixed(1)} jam'));
    chips.add(_InfoChip(icon: Icons.work_outline, label: _getJenisLemburLabel()));
    if (item.lokasi.isNotEmpty) chips.add(_InfoChip(icon: Icons.location_on_outlined, label: _getLokasiString(), color: Colors.blue));
    if (_isOutsideRadius()) chips.add(_InfoChip(icon: Icons.warning_amber_rounded, label: 'Luar Radius', color: Colors.orange));
    return Wrap(spacing: 6, runSpacing: 6, children: chips.take(6).toList());
  }

  String _getJenisLemburLabel() {
    switch (item.jenisLembur) {
      case 'hari_kerja': return 'Hari Kerja';
      case 'hari_libur': return 'Hari Libur';
      default: return item.jenisLembur;
    }
  }

  String _getLokasiString() {
    final lokasi = item.lokasi;
    String alamat = '';
    if (lokasi['nama_lokasi']?.toString().isNotEmpty == true) {
      alamat = lokasi['nama_lokasi'].toString();
    } else if (lokasi['alamat']?.toString().isNotEmpty == true) {
      alamat = lokasi['alamat'].toString();
    } else { return 'Tidak diketahui'; }
    return alamat.length > 25 ? '${alamat.substring(0, 25)}...' : alamat;
  }

  bool _isOutsideRadius() => item.lokasi['is_outside_radius'] == true;

  Widget _buildCostRow(double biaya) {
    final biayaFormatted = useAccurateCost ? OvertimeRateService.formatRupiahAsli(biaya) : rateService.formatRupiahCompact(biaya);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(item.isMitraDocument ? 'Biaya' : 'Total Biaya', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
      Text(biayaFormatted, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
    ]);
  }

  Widget _buildSpklIndicator() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withValues(alpha: 0.2))),
      child: Row(children: [
        const Icon(Icons.picture_as_pdf, size: 14, color: Colors.red), const SizedBox(width: 6),
        Expanded(child: Text(item.spklNomor ?? 'SPKL Tersedia', style: GoogleFonts.poppins(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 HELPER: Format & Preview (FINAL FIX)
  // ═══════════════════════════════════════════════════════
  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('HH:mm', 'id_ID').format(dt);
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
  }

  /// 🔥🔥🔥 PREVIEW FOTO — Menggunakan BuildContext langsung
  void _showPhotoPreview(BuildContext context, String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text('Foto Dokumentasi', style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════
// INFO CHIP WIDGET
// ═══════════════════════════════════════════════════════
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF1976D2);
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: chipColor), const SizedBox(width: 4),
        Flexible(child: Text(label, style: GoogleFonts.poppins(fontSize: 10, color: chipColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}