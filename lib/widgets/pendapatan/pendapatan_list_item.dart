// lib/widgets/pendapatan/pendapatan_list_item.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '/core/services/pendapatan_service.dart';

class PendapatanListItem extends StatelessWidget {
  final PendapatanItem item;
  final VoidCallback? onTap;

  const PendapatanListItem({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: const Color(0xFF1B5E20).withOpacity(0.05),
            highlightColor: const Color(0xFF1B5E20).withOpacity(0.03),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //═══════════════════════════════════════════
                  // HEADER: Tanggal + Status Badges
                  //═══════════════════════════════════════════
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon tanggal
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1B5E20).withOpacity(0.12),
                              const Color(0xFF2E7D32).withOpacity(0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Tanggal & Pengawas
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatTanggal(item.tanggal),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Nama pengawas (kalau ada)
                            if (item.namaPengawas != null &&
                                item.namaPengawas!.isNotEmpty &&
                                item.namaPengawas != '-')
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      item.namaPengawas!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Status badges (column)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Absensi status badge
                          _buildStatusBadge(
                            label: item.absensiStatusLabel,
                            color: item.absensiStatusColor,
                            icon: _getStatusIcon(item.statusAbsensi),
                          ),
                          const SizedBox(height: 4),
                          // Lembur status badge (selesai/disetujui/pending)
                          if (item.statusLembur != null &&
                              item.statusLembur!.isNotEmpty)
                            _buildStatusBadge(
                              label: item.statusLemburLabel,
                              color: _getStatusLemburColor(
                                  item.statusLembur ?? ''),
                              icon:
                                  _getLemburStatusIcon(item.statusLembur),
                              isSmall: true,
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  //═══════════════════════════════════════════
                  // DETAIL: Jam Kerja + Durasi
                  //═══════════════════════════════════════════
                  Row(
                    children: [
                      _buildDetailChip(
                        icon: Icons.access_time_rounded,
                        label:
                            '${item.jamMulai ?? "-"} - ${item.jamSelesai ?? "-"}',
                        color: const Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 8),
                      _buildDetailChip(
                        icon: Icons.hourglass_bottom_rounded,
                        label: _formatJam(item.totalJam),
                        color: const Color(0xFF7B1FA2),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  //═══════════════════════════════════════════
                  // DETAIL: Absensi + Jenis Lembur
                  //═══════════════════════════════════════════
                  Row(
                    children: [
                      _buildDetailChip(
                        icon: item.completedAt != null
                            ? Icons.check_circle_outline
                            : Icons.login_rounded,
                        label: item.completedAt != null
                            ? item.formattedDurasiAbsensi
                            : (item.absensiWaktu != null
                                ? 'Check-in: ${DateFormat('HH:mm').format(item.absensiWaktu!)}'
                                : 'Belum absen'),
                        color: item.completedAt != null
                            ? const Color(0xFF2E7D32)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      _buildDetailChip(
                        icon: item.jenisLembur == 'hari_libur'
                            ? Icons.beach_access_rounded
                            : Icons.work_outline_rounded,
                        label: item.jenisLembur == 'hari_libur'
                            ? 'Hari Libur'
                            : 'Hari Kerja',
                        color: item.jenisLembur == 'hari_libur'
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFFEF6C00),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  //═══════════════════════════════════════════
                  // FOOTER: Tarif + Pendapatan
                  //═══════════════════════════════════════════
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Tarif per jam
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tarif per jam',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatRupiah(item.tarifPerJam),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Estimasi pendapatan
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Estimasi',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1B5E20),
                                  Color(0xFF2E7D32),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1B5E20)
                                      .withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              item.formattedPendapatan,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  //═══════════════════════════════════════════
                  // LOKASI (kalau ada)
                  //═══════════════════════════════════════════
                  if (item.lokasi != null &&
                      item.lokasi!.isNotEmpty &&
                      item.lokasi != 'Kantor')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              item.lokasi!,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // STATUS BADGE
  // ═══════════════════════════════════════════════════════

  Widget _buildStatusBadge({
    required String label,
    required Color color,
    IconData? icon,
    bool isSmall = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: isSmall ? 9 : 11,
              color: color,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isSmall ? 8 : 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // DETAIL CHIP
  // ═══════════════════════════════════════════════════════

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color.withOpacity(0.8)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: color.withOpacity(0.85),
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ICON HELPERS
  // ═══════════════════════════════════════════════════════

  IconData? _getStatusIcon(String? status) {
    switch (status) {
      case 'selesai':
        return Icons.check_circle;
      case 'selesai_terlambat':
        return Icons.warning_amber_rounded;
      case 'sudah_absen':
      case 'check_in':
        return Icons.camera_alt_outlined;
      case 'belum_absen':
        return Icons.schedule;
      case 'expired':
        return Icons.cancel_outlined;
      default:
        return null;
    }
  }

  IconData? _getLemburStatusIcon(String? status) {
    switch (status) {
      case 'disetujui':
      case 'approved':
        return Icons.thumb_up_alt_outlined;
      case 'ditolak':
      case 'rejected':
        return Icons.thumb_down_alt_outlined;
      case 'pending':
        return Icons.pending_outlined;
      case 'selesai':
      case 'completed':
        return Icons.task_alt_rounded;
      case 'kadaluarsa':
      case 'expired':
        return Icons.timer_off_outlined;
      case 'dibatalkan':
      case 'cancelled':
        return Icons.block_outlined;
      default:
        return null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPER: STATUS LEMBUR COLOR (FIX)
  // ═══════════════════════════════════════════════════════

  Color _getStatusLemburColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'approved':
        return Colors.green;
      case 'ditolak':
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'selesai':
      case 'completed':
        return Colors.blue;
      case 'kadaluarsa':
      case 'expired':
        return Colors.grey;
      case 'dibatalkan':
      case 'cancelled':
        return Colors.red.shade300;
      default:
        return Colors.grey;
    }
  }

  // ═══════════════════════════════════════════════════════
  // FORMATTING HELPERS
  // ═══════════════════════════════════════════════════════

  String _formatTanggal(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateOnly).inDays;

    if (diff == 0) {
      return 'Hari Ini, ${DateFormat('dd MMM yyyy', 'id_ID').format(date)}';
    } else if (diff == 1) {
      return 'Kemarin, ${DateFormat('dd MMM yyyy', 'id_ID').format(date)}';
    } else if (diff < 7) {
      return '${DateFormat('EEEE', 'id_ID').format(date)}, ${DateFormat('dd MMM yyyy', 'id_ID').format(date)}';
    }

    return DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(date);
  }

  String _formatRupiah(double amount) {
    if (amount == 0) return 'Rp 0';
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatJam(double hours) {
    if (hours == 0) return '0 jam';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    if (h == 0 && m == 0) return '0 menit';
    if (h == 0) return '$m menit';
    if (m == 0) return '$h jam';
    return '$h jam $m menit';
  }
}