// lib/widgets/overtime_history/overtime_stats_card.dart
// 🔥 FINAL VERSION - PERBAIKAN LENGKAP
// 🔥 DITOLAK ≠ DIBATALKAN (terpisah)
// 🔥 Biaya ASLI (tanpa pembulatan) dari completedTotalBiaya
// 🔥 Total Jam ASLI dari completedTotalJam

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';

class OvertimeStatsCard extends StatelessWidget {
  final OvertimeHistoryService historyService;
  final String userRole;
  final String? userFungsi;
  final String? userId;
  final String? selectedBulan;

  const OvertimeStatsCard({
    super.key,
    required this.historyService,
    required this.userRole,
    this.userFungsi,
    this.userId,
    this.selectedBulan,
  });

  // ─── ROLE HELPERS ───
  bool get isHSSE => userFungsi == 'hsse';
  bool get isHSSEManager => userRole == 'manager' && isHSSE;

  @override
  Widget build(BuildContext context) {
    final bulanParam = (selectedBulan != null && selectedBulan!.isNotEmpty)
        ? selectedBulan
        : null;

    final statsFuture = historyService.getOvertimeStats(
      userRole: userRole,
      userFungsi: userFungsi,
      userId: userId,
      bulan: bulanParam,
    );

    final hsseStatsFuture =
        isHSSE ? historyService.getHSSEStats(bulan: bulanParam) : null;

    return FutureBuilder<Map<String, dynamic>>(
      future: statsFuture,
      builder: (context, statsSnapshot) {
        if (statsSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (!statsSnapshot.hasData) {
          return _buildEmptyCard();
        }

        final stats = statsSnapshot.data!;

        if (isHSSE && hsseStatsFuture != null) {
          return FutureBuilder<Map<String, dynamic>>(
            future: hsseStatsFuture,
            builder: (context, hsseSnapshot) {
              if (hsseSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard();
              }
              final hsseStats = hsseSnapshot.data ?? {};
              return _buildStatsCard(context, stats, hsseStats: hsseStats);
            },
          );
        }

        return _buildStatsCard(context, stats);
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 LOADING
  // ═══════════════════════════════════════════════════════

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 EMPTY
  // ═══════════════════════════════════════════════════════

  Widget _buildEmptyCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHSSE ? Icons.health_and_safety : Icons.inbox_outlined,
              color: Colors.white54,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Belum ada data lembur',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 MAIN CARD
  // ═══════════════════════════════════════════════════════

  Widget _buildStatsCard(
    BuildContext context,
    Map<String, dynamic> stats, {
    Map<String, dynamic>? hsseStats,
  }) {
    final rateService = OvertimeRateService();

    // ─── BASIC STATS ───
    final total = stats['total'] as int? ?? 0;
    final pending = stats['pending'] as int? ?? 0;
    final approved = stats['approved'] as int? ?? 0;
    final completed = stats['completed'] as int? ?? 0;
    final rejected = stats['rejected'] as int? ?? 0;
    final cancelled = stats['cancelled'] as int? ?? 0;
    final needAbsensi = stats['needAbsensi'] as int? ?? 0;
    
    // 🔥🔥🔥 PERBAIKAN: Pakai completedTotalJam & completedTotalBiaya
    final totalJam = (stats['completedTotalJam'] as num? ?? 0).toDouble();
    final totalBiaya = (stats['completedTotalBiaya'] as num? ?? 0).toDouble();
    
    final riskyCount = stats['riskyCount'] as int? ?? 0;
    final totalMitra = stats['totalMitra'] as int? ?? 0;

    // ─── HSSE STATS ───
    final hssApproved = hsseStats?['approvedHSSE'] as int? ?? 0;
    final hssRejected = hsseStats?['rejectedHSSE'] as int? ?? 0;
    final hssPending = hsseStats?['pendingHSSE'] as int? ?? 0;
    final hssRevisi = hsseStats?['perluRevisi'] as int? ?? 0;

    // 🔥 Kalo total 0, tampilkan empty
    if (total == 0) return _buildEmptyCard();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ═══════════════════════════════════════════
          // 🔥 ROW 1: 4 COUNTER UTAMA
          // Total | Pending | Disetujui | Ditolak
          // ═══════════════════════════════════════════
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                label: 'Total',
                value: total,
                icon: Icons.article_outlined,
                color: Colors.white,
              ),
              _StatItem(
                label: _getPendingLabel(),
                value: pending,
                icon: Icons.hourglass_empty,
                color: const Color(0xFFFFCC80),
              ),
              _StatItem(
                label: _getApprovedLabel(),
                value: approved + completed,
                icon: Icons.check_circle_outline,
                color: const Color(0xFFA5D6A7),
              ),
              // 🔥 HANYA rejected (TIDAK termasuk cancelled)
              _StatItem(
                label: _getRejectedLabel(),
                value: rejected,
                icon: Icons.cancel_outlined,
                color: const Color(0xFFEF9A9A),
              ),
            ],
          ),

          // ═══════════════════════════════════════════
          // 🔥 ROW 2: EXTRA (jika ada)
          // Dibatalkan muncul di sini sebagai item terpisah
          // ═══════════════════════════════════════════
          if (_hasExtra(hssPending, hssApproved, hssRejected, hssRevisi,
              needAbsensi, riskyCount, cancelled)) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _buildExtraRow(
                hssPending,
                hssApproved,
                hssRejected,
                hssRevisi,
                needAbsensi,
                riskyCount,
                cancelled,
              ),
            ),
          ],

          // ═══════════════════════════════════════════
          // 🔥 HSSE INFO BAR
          // ═══════════════════════════════════════════
          if (isHSSEManager && (riskyCount > 0 || hssPending > 0)) ...[
            const SizedBox(height: 8),
            _buildHSSEInfoBar(riskyCount, hssPending),
          ],

          // ═══════════════════════════════════════════
          // 🔥 ROW 3: JAM, BIAYA ASLI, MITRA (compact)
          // ═══════════════════════════════════════════
          if (totalJam > 0 || totalBiaya > 0 || totalMitra > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (totalJam > 0)
                    _CompactInfo(
                      icon: Icons.timer_outlined,
                      value: '${totalJam.toStringAsFixed(1)}j',
                      label: 'Jam Selesai*',
                    ),
                  if (totalBiaya > 0)
                    _CompactInfo(
                      icon: Icons.payments_outlined,
                      // 🔥🔥🔥 PAKAI BIAYA ASLI (tanpa pembulatan)
                      value: OvertimeRateService.formatRupiahAsli(totalBiaya),
                      label: 'Pendapatan',
                    ),
                  if (totalMitra > 0)
                    _CompactInfo(
                      icon: Icons.people_outlined,
                      value: '$totalMitra',
                      label: 'Mitra',
                    ),
                ],
              ),
            ),
            // 🔥 Keterangan
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '* Total jam & biaya dari lembur yang sudah selesai (biaya asli tanpa pembulatan)',
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  color: Colors.white.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 HELPERS
  // ═══════════════════════════════════════════════════════

  String _getPendingLabel() => isHSSE ? 'HSSE Pending' : 'Pending';
  String _getApprovedLabel() => isHSSE ? 'Approved' : 'Disetujui';
  String _getRejectedLabel() => isHSSE ? 'Rejected' : 'Ditolak';

  bool _hasExtra(
    int hssPending,
    int hssApproved,
    int hssRejected,
    int hssRevisi,
    int needAbsensi,
    int riskyCount,
    int cancelled,
  ) {
    if (isHSSE) {
      return hssPending > 0 ||
          hssApproved > 0 ||
          hssRejected > 0 ||
          hssRevisi > 0 ||
          needAbsensi > 0;
    }
    // 🔥 Non-HSSE: tampilkan extra jika ada berisiko, dibatalkan, atau perlu absensi
    return needAbsensi > 0 || riskyCount > 0 || cancelled > 0;
  }

  List<Widget> _buildExtraRow(
    int hssPending,
    int hssApproved,
    int hssRejected,
    int hssRevisi,
    int needAbsensi,
    int riskyCount,
    int cancelled,
  ) {
    final items = <Widget>[];

    if (isHSSE) {
      if (hssPending > 0) {
        items.add(_StatItem(
          label: 'Menunggu',
          value: hssPending,
          icon: Icons.schedule,
          color: const Color(0xFFFFCC80),
        ));
      }
      if (hssApproved > 0) {
        items.add(_StatItem(
          label: 'HSSE OK',
          value: hssApproved,
          icon: Icons.verified,
          color: const Color(0xFFA5D6A7),
        ));
      }
      if (hssRejected > 0) {
        items.add(_StatItem(
          label: 'Ditolak',
          value: hssRejected,
          icon: Icons.cancel,
          color: const Color(0xFFEF9A9A),
        ));
      }
      if (hssRevisi > 0) {
        items.add(_StatItem(
          label: 'Revisi',
          value: hssRevisi,
          icon: Icons.edit_note,
          color: const Color(0xFFFFF176),
        ));
      }
      if (needAbsensi > 0) {
        items.add(_StatItem(
          label: 'Absensi',
          value: needAbsensi,
          icon: Icons.camera_alt_outlined,
          color: const Color(0xFF90CAF9),
        ));
      }
    } else {
      // 🔥 Non-HSSE — Dibatalkan muncul terpisah
      if (riskyCount > 0) {
        items.add(_StatItem(
          label: 'Berisiko',
          value: riskyCount,
          icon: Icons.warning_amber_outlined,
          color: const Color(0xFFFFF176),
        ));
      }
      // 🔥 Dibatalkan sebagai item terpisah (bukan gabungan dengan Ditolak)
      if (cancelled > 0) {
        items.add(_StatItem(
          label: 'Dibatalkan',
          value: cancelled,
          icon: Icons.remove_circle_outline,
          color: const Color(0xFFEF9A9A),
        ));
      }
      if (needAbsensi > 0) {
        items.add(_StatItem(
          label: 'Absensi',
          value: needAbsensi,
          icon: Icons.camera_alt_outlined,
          color: const Color(0xFF90CAF9),
        ));
      }
    }
    return items;
  }

  Widget _buildHSSEInfoBar(int riskyCount, int hssPending) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hssPending > 0 ? Icons.warning_amber : Icons.check_circle,
            color: hssPending > 0 ? Colors.amber : Colors.green,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            hssPending > 0
                ? '$hssPending menunggu validasi HSSE'
                : 'Semua tervalidasi ✅',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔥 COMPACT STAT ITEM
// ═══════════════════════════════════════════════════════════

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: c.withOpacity(0.85), size: 16),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: GoogleFonts.poppins(
            color: c,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            height: 1.1,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: c.withOpacity(0.7),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔥 COMPACT INFO ITEM (JAM, BIAYA ASLI, MITRA)
// ═══════════════════════════════════════════════════════════

class _CompactInfo extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _CompactInfo({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 5),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.2,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 9,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}