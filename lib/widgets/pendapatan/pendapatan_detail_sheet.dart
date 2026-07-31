// lib/widgets/pendapatan/pendapatan_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '/core/services/pendapatan_service.dart';

class PendapatanDetailSheet extends StatelessWidget {
  final PendapatanItem item;

  const PendapatanDetailSheet({super.key, required this.item});

  /// Show bottom sheet
  static void show(BuildContext context, PendapatanItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => PendapatanDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Stack(
        children: [
          //═══════════════════════════════════════════
          // MAIN CONTENT
          //═══════════════════════════════════════════
          Column(
            children: [
              // ─── DRAG HANDLE ──────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // ─── TITLE ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 20,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Detail Pendapatan',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    // Close button
                    Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 20),

              // ─── SCROLLABLE CONTENT ──────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      //═══════════════════════════
                      // TOTAL PENDAPATAN CARD (GRADIENT)
                      //═══════════════════════════
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0D3B0F),
                              Color(0xFF1B5E20),
                              Color(0xFF2E7D32),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1B5E20).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.payments_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Estimasi Pendapatan',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.formattedPendapatan,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Status badges row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildMiniBadge(
                                  label: item.absensiStatusLabel,
                                  color: item.absensiStatusColor,
                                ),
                                if (item.statusLembur != null &&
                                    item.statusLembur!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  _buildMiniBadge(
                                    label: item.statusLemburLabel,
                                    color: _getStatusLemburColor(
                                        item.statusLembur ?? ''),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      //═══════════════════════════
                      // INFO DETAIL SECTIONS
                      //═══════════════════════════
                      _buildSectionCard(
                        title: 'Informasi Lembur',
                        icon: Icons.info_outline_rounded,
                        children: [
                          _buildDetailRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Tanggal',
                            value: DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                                .format(item.tanggal),
                          ),
                          _buildDetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Jam Lembur',
                            value:
                                '${item.jamMulai ?? "-"} - ${item.jamSelesai ?? "-"}',
                          ),
                          _buildDetailRow(
                            icon: Icons.hourglass_bottom_rounded,
                            label: 'Total Jam',
                            value: _formatJam(item.totalJam),
                            valueColor: const Color(0xFF7B1FA2),
                          ),
                          _buildDetailRow(
                            icon: item.jenisLembur == 'hari_libur'
                                ? Icons.beach_access_rounded
                                : Icons.work_outline_rounded,
                            label: 'Jenis Lembur',
                            value: item.jenisLembur == 'hari_libur'
                                ? 'Hari Libur (Multiplier 2x)'
                                : 'Hari Kerja (Standar)',
                            valueColor: item.jenisLembur == 'hari_libur'
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      //═══════════════════════════
                      // ABSENSI SECTION
                      //═══════════════════════════
                      _buildSectionCard(
                        title: 'Detail Absensi',
                        icon: Icons.fingerprint_rounded,
                        children: [
                          _buildDetailRow(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Status Absensi',
                            value: item.absensiStatusLabel,
                            valueColor: item.absensiStatusColor,
                          ),
                          _buildDetailRow(
                            icon: Icons.login_rounded,
                            label: 'Check-in',
                            value: item.absensiWaktu != null
                                ? DateFormat('HH:mm', 'id_ID')
                                    .format(item.absensiWaktu!)
                                : '-',
                          ),
                          _buildDetailRow(
                            icon: Icons.logout_rounded,
                            label: 'Check-out',
                            value: item.completedAt != null
                                ? DateFormat('HH:mm', 'id_ID')
                                    .format(item.completedAt!)
                                : '-',
                          ),
                          _buildDetailRow(
                            icon: Icons.timelapse_rounded,
                            label: 'Durasi Absensi',
                            value: item.completedAt != null
                                ? item.formattedDurasiAbsensi
                                : (item.absensiWaktu != null
                                    ? 'Baru check-in'
                                    : 'Belum absen'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      //═══════════════════════════
                      // TAMBAHAN SECTION
                      //═══════════════════════════
                      _buildSectionCard(
                        title: 'Informasi Tambahan',
                        icon: Icons.more_horiz_rounded,
                        children: [
                          _buildDetailRow(
                            icon: Icons.location_on_outlined,
                            label: 'Lokasi',
                            value: (item.lokasi != null &&
                                    item.lokasi!.isNotEmpty)
                                ? item.lokasi!
                                : 'Tidak tersedia',
                          ),
                          _buildDetailRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Pengawas',
                            value: (item.namaPengawas != null &&
                                    item.namaPengawas!.isNotEmpty &&
                                    item.namaPengawas != '-')
                                ? item.namaPengawas!
                                : 'Tidak tersedia',
                          ),
                          _buildDetailRow(
                            icon: Icons.photo_outlined,
                            label: 'Foto Absensi',
                            value:
                                item.fotoUrl != null ? 'Tersedia 📸' : 'Tidak ada',
                            valueColor: item.fotoUrl != null
                                ? const Color(0xFF1B5E20)
                                : Colors.grey,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      //═══════════════════════════
                      // PERHITUNGAN SECTION
                      //═══════════════════════════
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1B5E20).withOpacity(0.04),
                              const Color(0xFF1B5E20).withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF1B5E20).withOpacity(0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B5E20)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.calculate_rounded,
                                    size: 16,
                                    color: Color(0xFF1B5E20),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Rumus Perhitungan',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Formula steps
                            _buildFormulaStep(
                              step: '1',
                              text:
                                  '${_formatJam(item.totalJam)} × ${_formatRupiah(item.tarifPerJam)}/jam',
                            ),
                            const SizedBox(height: 6),
                            _buildFormulaStep(
                              step: '2',
                              text:
                                  '= ${_formatRupiah(item.totalJam * item.tarifPerJam)}',
                              isResult: true,
                            ),
                            const SizedBox(height: 6),
                            if (item.jenisLembur == 'hari_libur') ...[
                              _buildFormulaStep(
                                step: '🏖',
                                text: 'Termasuk multiplier Hari Libur (2x)',
                                isNote: true,
                              ),
                              const SizedBox(height: 6),
                            ],
                            _buildFormulaStep(
                              step: '📌',
                              text:
                                  'Ini hanya ESTIMASI. Nominal final ditentukan oleh bagian keuangan.',
                              isNote: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      //═══════════════════════════
                      // DISCLAIMER
                      //═══════════════════════════
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.shade100.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Penting!',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pendapatan ini hanya ESTIMASI berdasarkan tarif lembur per jam. '
                                    'Nominal final dapat berbeda dan akan diinformasikan '
                                    'oleh bagian keuangan saat penggajian.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.orange.shade800,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      //═══════════════════════════
                      // CLOSE BUTTON
                      //═══════════════════════════
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Tutup',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      // Bottom safe area
                      SizedBox(height: bottomPadding + 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SECTION CARD
  // ═══════════════════════════════════════════════════════

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Divider tipis
          Container(
            height: 1,
            color: Colors.grey.shade100,
          ),
          const SizedBox(height: 12),
          // Children
          ...children,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // DETAIL ROW
  // ═══════════════════════════════════════════════════════

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Icon(
            icon,
            size: 15,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 10),
          // Label
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          // Value
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // MINI BADGE
  // ═══════════════════════════════════════════════════════

  Widget _buildMiniBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // FORMULA STEP
  // ═══════════════════════════════════════════════════════

  Widget _buildFormulaStep({
    required String step,
    required String text,
    bool isResult = false,
    bool isNote = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step number
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isResult
                ? const Color(0xFF1B5E20)
                : isNote
                    ? Colors.transparent
                    : const Color(0xFF1B5E20).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              step,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isResult
                    ? Colors.white
                    : isNote
                        ? Colors.orange.shade700
                        : const Color(0xFF1B5E20),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: isNote ? 10.5 : 12,
              fontWeight: isResult ? FontWeight.w700 : FontWeight.w500,
              color: isNote
                  ? Colors.orange.shade800
                  : isResult
                      ? const Color(0xFF1B5E20)
                      : Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
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

  String _formatRupiah(double amount) {
    if (amount == 0) return 'Rp 0';
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
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