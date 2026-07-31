import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/unified_stats_service.dart';
import '/core/services/overtime_rate_service.dart';

enum StatsCardRole {
  superadmin,
  manager,
  managerHSSE,
  pengawas,
  mitra,
}

class UniversalStatsCard extends StatelessWidget {
  final StatsCardRole cardRole;
  final UnifiedStatsService statsService;
  final String? fungsi;
  final String? userId;
  final String? selectedBulan;
  final String? roleFilter;

  const UniversalStatsCard({
    super.key,
    required this.cardRole,
    required this.statsService,
    this.fungsi,
    this.userId,
    this.selectedBulan,
    this.roleFilter,
  });

  // ─── ROLE HELPERS ───
  bool get isSuperadmin => cardRole == StatsCardRole.superadmin;
  bool get isManager => cardRole == StatsCardRole.manager;
  bool get isManagerHSSE => cardRole == StatsCardRole.managerHSSE;
  bool get isHSSE => isManagerHSSE || fungsi == 'hsse';
  bool get isPengawas => cardRole == StatsCardRole.pengawas;
  bool get isMitra => cardRole == StatsCardRole.mitra;

  // ─── LOGGING HELPER ───
  void _log(String message, [dynamic data]) {
    // ignore: avoid_print
    print('📊 UniversalStatsCard: $message ${data != null ? '→ $data' : ''}');
  }

  @override
  Widget build(BuildContext context) {
    _log('BUILD', {
      'cardRole': cardRole.name,
      'fungsi': fungsi,
      'userId': userId,
      'selectedBulan': selectedBulan,
      'roleFilter': roleFilter,
    });

    final bulanParam = (selectedBulan != null && selectedBulan!.isNotEmpty)
        ? selectedBulan
        : null;

    // 🔥 SINGLE FUTURE - gabungkan semua request dalam satu Future
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchAllStats(bulanParam),
      builder: (context, snapshot) {
        // 🔥 LOADING
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        // 🔥 ERROR HANDLING
        if (snapshot.hasError) {
          _log('❌ ERROR', snapshot.error);
          return _buildErrorCard(snapshot.error.toString());
        }

        // 🔥 NO DATA
        if (!snapshot.hasData || snapshot.data == null) {
          _log('⚠️ No data returned');
          return _buildEmptyCard();
        }

        final data = snapshot.data!;
        final stats = data['stats'] as Map<String, dynamic>?;
        final hsseStats = data['hsseStats'] as Map<String, dynamic>?;

        // 🔥 VALIDATE DATA
        if (stats == null || stats.isEmpty) {
          _log('⚠️ Stats data is null or empty');
          return _buildEmptyCard();
        }

        _log('✅ Stats loaded successfully', {
          'total': stats['total'],
          'pending': stats['pending'],
          'totalUsers': stats['totalUsers'],
        });

        return _buildStatsCard(context, stats, hsseStats: hsseStats);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 SINGLE FUTURE - GABUNG SEMUA REQUEST
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _fetchAllStats(String? bulanParam) async {
    try {
      _log('🔄 Fetching stats...');

      // 🔥 Ambil data utama
      final stats = await statsService.getStats(
        role: _getRoleString(),
        fungsi: isSuperadmin ? roleFilter : fungsi,
        userId: userId,
        bulan: bulanParam,
      );

      _log('📦 Stats received', stats);

      // 🔥 Ambil HSSE stats jika perlu
      Map<String, dynamic>? hsseStats;
      if (isHSSE || isSuperadmin) {
        try {
          hsseStats = await statsService.getHSSEStats(
            bulan: bulanParam,
            fungsi: isSuperadmin ? roleFilter : fungsi,
          );
          _log('📦 HSSE Stats received', hsseStats);
        } catch (e) {
          _log('⚠️ HSSE stats failed (non-critical)', e);
          // HSSE stats gagal, tetap lanjut dengan data utama
          hsseStats = {};
        }
      }

      // 🔥 FALLBACK: jika stats null, berikan data default
      final safeStats = stats ?? {
        'total': 0,
        'pending': 0,
        'approved': 0,
        'completed': 0,
        'rejected': 0,
        'cancelled': 0,
        'pendingHSSE': 0,
        'needAbsensi': 0,
        'riskyCount': 0,
        'perluRevisi': 0,
        'escalated': 0,
        'completedTotalJam': 0.0,
        'completedTotalBiaya': 0.0,
        'totalMitra': 0,
        'totalUsers': 0,
        'onlineNow': 0,
        'verifiedUsers': 0,
      };

      return {
        'stats': safeStats,
        'hsseStats': hsseStats ?? {},
      };
    } catch (e, stackTrace) {
      _log('❌ FETCH ERROR', {'error': e, 'stackTrace': stackTrace});
      // 🔥 Re-throw agar FutureBuilder menangani error
      rethrow;
    }
  }

  String _getRoleString() {
    switch (cardRole) {
      case StatsCardRole.superadmin:
        return 'superadmin';
      case StatsCardRole.manager:
        return 'manager';
      case StatsCardRole.managerHSSE:
        return 'manager';
      case StatsCardRole.pengawas:
        return 'pengawas';
      case StatsCardRole.mitra:
        return 'mitra';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 LOADING
  // ═══════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════
  // 🔥 ERROR CARD - BARU!
  // ═══════════════════════════════════════════════════════════

  Widget _buildErrorCard(String errorMessage) {
    // Ambil pesan error yang lebih user-friendly
    String displayMessage = 'Terjadi kesalahan';
    if (errorMessage.contains('permission') ||
        errorMessage.contains('auth') ||
        errorMessage.contains('unauthorized')) {
      displayMessage = 'Tidak memiliki akses';
    } else if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout')) {
      displayMessage = 'Koneksi bermasalah';
    } else if (errorMessage.contains('null') || errorMessage.contains('empty')) {
      displayMessage = 'Data tidak tersedia';
    }

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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                displayMessage,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 🔥 Tampilkan error detail di mode debug
            if (errorMessage.isNotEmpty)
              Padding(
                // 🔧 FIXED: EdgeInsets.symmetric tidak punya parameter 'top'
                // Ganti ke EdgeInsets.only untuk kombinasi horizontal dan top
                padding: const EdgeInsets.only(left: 16, right: 16, top: 2),
                child: Text(
                  errorMessage,
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 EMPTY
  // ═══════════════════════════════════════════════════════════

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
            Flexible(
              child: Text(
                isSuperadmin ? 'Belum ada data' : 'Belum ada data lembur',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 MAIN STATS CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildStatsCard(
    BuildContext context,
    Map<String, dynamic> stats, {
    Map<String, dynamic>? hsseStats,
  }) {
    // 🔥 SAFE EXTRACTION dengan fallback
    final total = _safeInt(stats, 'total');
    final pending = _safeInt(stats, 'pending');
    final approved = _safeInt(stats, 'approved');
    final completed = _safeInt(stats, 'completed');
    final rejected = _safeInt(stats, 'rejected');
    final cancelled = _safeInt(stats, 'cancelled');
    final pendingHSSE = _safeInt(stats, 'pendingHSSE');
    final needAbsensi = _safeInt(stats, 'needAbsensi');
    final riskyCount = _safeInt(stats, 'riskyCount');
    final perluRevisi = _safeInt(stats, 'perluRevisi');
    final escalated = _safeInt(stats, 'escalated');

    final totalJam = _safeDouble(stats, 'completedTotalJam');
    final totalBiaya = _safeDouble(stats, 'completedTotalBiaya');
    final totalMitra = _safeInt(stats, 'totalMitra');

    final hssApproved = _safeInt(hsseStats, 'approvedHSSE');
    final hssRejected = _safeInt(hsseStats, 'rejectedHSSE');
    final hssPending = _safeInt(hsseStats, 'pendingHSSE');
    final hssRevisi = _safeInt(hsseStats, 'perluRevisi');

    final totalUsers = _safeInt(stats, 'totalUsers');
    final onlineNow = _safeInt(stats, 'onlineNow');
    final verifiedUsers = _safeInt(stats, 'verifiedUsers');

    // 🔥 Cek apakah ada data valid
    if (total == 0 && totalUsers == 0 && pending == 0 && approved == 0) {
      return _buildEmptyCard();
    }

    _log('📊 Building stats card', {
      'total': total,
      'pending': pending,
      'approved': approved,
      'totalUsers': totalUsers,
    });

    final extraData = _ExtraCountersData(
      cancelled: cancelled,
      pendingHSSE: pendingHSSE,
      needAbsensi: needAbsensi,
      riskyCount: riskyCount,
      perluRevisi: perluRevisi,
      escalated: escalated,
      hssApproved: hssApproved,
      hssRejected: hssRejected,
      hssPending: hssPending,
      hssRevisi: hssRevisi,
      onlineNow: onlineNow,
      verifiedUsers: verifiedUsers,
      rejected: rejected,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
          // ═══════════════════════════════════════════
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _buildMainCounters(
              total: total,
              pending: pending,
              approved: approved,
              completed: completed,
              rejected: rejected,
              pendingHSSE: pendingHSSE,
              totalUsers: totalUsers,
            ),
          ),

          // ═══════════════════════════════════════════
          // 🔥 ROW 2: EXTRA COUNTERS (Wrap)
          // ═══════════════════════════════════════════
          if (_hasExtraCounters(extraData)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _buildExtraCounters(extraData),
            ),
          ],

          // ═══════════════════════════════════════════
          // 🔥 HSSE INFO BAR
          // ═══════════════════════════════════════════
          if ((isManagerHSSE || isHSSE) &&
              (riskyCount > 0 || hssPending > 0 || escalated > 0)) ...[
            const SizedBox(height: 8),
            _buildHSSEInfoBar(riskyCount, hssPending, escalated),
          ],

          // ═══════════════════════════════════════════
          // 🔥 ROW 3: COMPACT INFO (pakai Wrap)
          // ═══════════════════════════════════════════
          if (_showCompactInfo(
            totalJam: totalJam,
            totalBiaya: totalBiaya,
            totalMitra: totalMitra,
            totalUsers: totalUsers,
          )) ...[
            const SizedBox(height: 10),
            _buildCompactInfoRow(
              totalJam: totalJam,
              totalBiaya: totalBiaya,
              totalMitra: totalMitra,
              totalUsers: totalUsers,
              verifiedUsers: verifiedUsers,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isSuperadmin
                    ? '* Total pengguna terdaftar & mitra di sistem'
                    : '* Total jam & biaya dari lembur yang sudah selesai',
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

  // ─── SAFE EXTRACTION HELPERS ───

  int _safeInt(Map<String, dynamic>? data, String key) {
    if (data == null) return 0;
    final value = data[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  double _safeDouble(Map<String, dynamic>? data, String key) {
    if (data == null) return 0.0;
    final value = data[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 BUILD MAIN COUNTERS (ROW 1)
  // ═══════════════════════════════════════════════════════════

  List<Widget> _buildMainCounters({
    required int total,
    required int pending,
    required int approved,
    required int completed,
    required int rejected,
    required int pendingHSSE,
    required int totalUsers,
  }) {
    final counters = <Widget>[];

    if (isSuperadmin) {
      counters.addAll([
        _StatItem(
          label: 'Total Users',
          value: totalUsers,
          icon: Icons.people_alt_rounded,
          color: Colors.white,
        ),
        _StatItem(
          label: 'Total Lembur',
          value: total,
          icon: Icons.work_history_rounded,
          color: const Color(0xFFCE93D8),
        ),
        _StatItem(
          label: 'Pending',
          value: pending,
          icon: Icons.hourglass_empty,
          color: const Color(0xFFFFCC80),
        ),
        _StatItem(
          label: 'Disetujui',
          value: approved + completed,
          icon: Icons.check_circle_outline,
          color: const Color(0xFFA5D6A7),
        ),
      ]);
    } else if (isPengawas) {
      counters.addAll([
        _StatItem(
          label: 'Total',
          value: total,
          icon: Icons.article_outlined,
          color: Colors.white,
        ),
        _StatItem(
          label: 'Pending',
          value: pending,
          icon: Icons.hourglass_empty,
          color: const Color(0xFFFFCC80),
        ),
        _StatItem(
          label: 'Disetujui',
          value: approved + completed,
          icon: Icons.check_circle_outline,
          color: const Color(0xFFA5D6A7),
        ),
        _StatItem(
          label: 'Ditolak',
          value: rejected,
          icon: Icons.cancel_outlined,
          color: const Color(0xFFEF9A9A),
        ),
      ]);
    } else {
      counters.addAll([
        _StatItem(
          label: 'Total',
          value: total,
          icon: Icons.article_outlined,
          color: Colors.white,
        ),
        _StatItem(
          label: _getPendingLabel(),
          value: isHSSE ? pendingHSSE : pending,
          icon: Icons.hourglass_empty,
          color: const Color(0xFFFFCC80),
        ),
        _StatItem(
          label: _getApprovedLabel(),
          value: approved + completed,
          icon: Icons.check_circle_outline,
          color: const Color(0xFFA5D6A7),
        ),
        _StatItem(
          label: _getRejectedLabel(),
          value: rejected,
          icon: Icons.cancel_outlined,
          color: const Color(0xFFEF9A9A),
        ),
      ]);
    }

    return counters;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 BUILD EXTRA COUNTERS (ROW 2)
  // ═══════════════════════════════════════════════════════════

  bool _hasExtraCounters(_ExtraCountersData data) {
    if (isSuperadmin) {
      return data.cancelled > 0 ||
          data.rejected > 0 ||
          data.pendingHSSE > 0 ||
          data.onlineNow > 0 ||
          data.needAbsensi > 0;
    }
    if (isHSSE) {
      return data.pendingHSSE > 0 ||
          data.hssApproved > 0 ||
          data.hssRejected > 0 ||
          data.hssRevisi > 0 ||
          data.needAbsensi > 0 ||
          data.escalated > 0;
    }
    if (isPengawas) {
      return data.cancelled > 0 ||
          data.pendingHSSE > 0 ||
          data.needAbsensi > 0 ||
          data.riskyCount > 0;
    }
    return data.cancelled > 0 ||
        data.pendingHSSE > 0 ||
        data.needAbsensi > 0 ||
        data.riskyCount > 0 ||
        data.perluRevisi > 0;
  }

  List<Widget> _buildExtraCounters(_ExtraCountersData data) {
    final items = <Widget>[];

    if (isSuperadmin) {
      if (data.cancelled > 0) {
        items.add(_StatItem(
          label: 'Dibatalkan',
          value: data.cancelled,
          icon: Icons.remove_circle_outline,
          color: const Color(0xFFEF9A9A),
        ));
      }
      if (data.rejected > 0) {
        items.add(_StatItem(
          label: 'Ditolak',
          value: data.rejected,
          icon: Icons.cancel_outlined,
          color: const Color(0xFFEF9A9A),
        ));
      }
      if (data.pendingHSSE > 0) {
        items.add(_StatItem(
          label: 'Pending HSSE',
          value: data.pendingHSSE,
          icon: Icons.shield_rounded,
          color: const Color(0xFFFFF176),
        ));
      }
      if (data.onlineNow > 0) {
        items.add(_StatItem(
          label: 'Online',
          value: data.onlineNow,
          icon: Icons.wifi_rounded,
          color: const Color(0xFFA5D6A7),
        ));
      }
      if (data.needAbsensi > 0) {
        items.add(_StatItem(
          label: 'Perlu Absensi',
          value: data.needAbsensi,
          icon: Icons.camera_alt_outlined,
          color: const Color(0xFF90CAF9),
        ));
      }
    } else if (isHSSE) {
      if (data.hssPending > 0) {
        items.add(_StatItem(
          label: 'Menunggu HSSE',
          value: data.hssPending,
          icon: Icons.schedule,
          color: const Color(0xFFFFCC80),
        ));
      }
      if (data.hssApproved > 0) {
        items.add(_StatItem(
          label: 'HSSE OK',
          value: data.hssApproved,
          icon: Icons.verified,
          color: const Color(0xFFA5D6A7),
        ));
      }
      if (data.hssRejected > 0) {
        items.add(_StatItem(
          label: 'HSSE Tolak',
          value: data.hssRejected,
          icon: Icons.cancel,
          color: const Color(0xFFEF9A9A),
        ));
      }
      if (data.hssRevisi > 0) {
        items.add(_StatItem(
          label: 'Revisi',
          value: data.hssRevisi,
          icon: Icons.edit_note,
          color: const Color(0xFFFFF176),
        ));
      }
      if (data.escalated > 0) {
        items.add(_StatItem(
          label: 'Eskalasi',
          value: data.escalated,
          icon: Icons.escalator_warning,
          color: const Color(0xFFEF5350),
        ));
      }
      if (data.needAbsensi > 0) {
        items.add(_StatItem(
          label: 'Absensi',
          value: data.needAbsensi,
          icon: Icons.camera_alt_outlined,
          color: const Color(0xFF90CAF9),
        ));
      }
    } else if (isPengawas) {
      if (data.cancelled > 0) {
        items.add(_StatItem(
          label: 'Dibatalkan',
          value: data.cancelled,
          icon: Icons.remove_circle_outline,
          color: const Color(0xFFEF9A9A),
        ));
      }
      if (data.pendingHSSE > 0) {
        items.add(_StatItem(
          label: 'Pending HSSE',
          value: data.pendingHSSE,
          icon: Icons.shield_rounded,
          color: const Color(0xFFFFF176),
        ));
      }
      if (data.riskyCount > 0) {
        items.add(_StatItem(
          label: 'Berisiko',
          value: data.riskyCount,
          icon: Icons.warning_amber_outlined,
          color: const Color(0xFFFFF176),
        ));
      }
      if (data.needAbsensi > 0) {
        items.add(_StatItem(
          label: 'Absensi',
          value: data.needAbsensi,
          icon: Icons.camera_alt_outlined,
          color: const Color(0xFF90CAF9),
        ));
      }
    } else {
      if (data.cancelled > 0) {
        items.add(_StatItem(
          label: 'Dibatalkan',
          value: data.cancelled,
          icon: Icons.remove_circle_outline,
          color: const Color(0xFFEF9A9A),
        ));
      }
      if (data.pendingHSSE > 0) {
        items.add(_StatItem(
          label: 'Pending HSSE',
          value: data.pendingHSSE,
          icon: Icons.shield_rounded,
          color: const Color(0xFFFFF176),
        ));
      }
      if (data.riskyCount > 0) {
        items.add(_StatItem(
          label: 'Berisiko',
          value: data.riskyCount,
          icon: Icons.warning_amber_outlined,
          color: const Color(0xFFFFF176),
        ));
      }
      if (data.needAbsensi > 0) {
        items.add(_StatItem(
          label: 'Absensi',
          value: data.needAbsensi,
          icon: Icons.camera_alt_outlined,
          color: const Color(0xFF90CAF9),
        ));
      }
    }

    return items;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 COMPACT INFO ROW (pakai Wrap biar gak overflow)
  // ═══════════════════════════════════════════════════════════

  bool _showCompactInfo({
    required double totalJam,
    required double totalBiaya,
    required int totalMitra,
    required int totalUsers,
  }) {
    if (isSuperadmin) return totalUsers > 0 || totalMitra > 0;
    return totalJam > 0 || totalBiaya > 0 || totalMitra > 0;
  }

  Widget _buildCompactInfoRow({
    required double totalJam,
    required double totalBiaya,
    required int totalMitra,
    required int totalUsers,
    required int verifiedUsers,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          if (isSuperadmin && totalUsers > 0)
            _CompactInfo(
              icon: Icons.verified_user_rounded,
              value: '$verifiedUsers',
              label: 'Verified',
            ),
          if (totalJam > 0)
            _CompactInfo(
              icon: Icons.timer_outlined,
              value: '${totalJam.toStringAsFixed(1)}j',
              label: 'Jam',
            ),
          if (totalBiaya > 0)
            _CompactInfo(
              icon: Icons.payments_outlined,
              value: OvertimeRateService.formatRupiahAsli(totalBiaya),
              label: isSuperadmin ? 'Biaya' : 'Pendapatan',
            ),
          if (totalMitra > 0)
            _CompactInfo(
              icon: Icons.people_outlined,
              value: '$totalMitra',
              label: 'Mitra',
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 HSSE INFO BAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildHSSEInfoBar(int riskyCount, int hssPending, int escalated) {
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
            escalated > 0
                ? Icons.escalator_warning
                : hssPending > 0
                    ? Icons.warning_amber
                    : Icons.check_circle,
            color: escalated > 0
                ? Colors.red
                : hssPending > 0
                    ? Colors.amber
                    : Colors.green,
            size: 14,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              escalated > 0
                  ? '$escalated eskalasi | $hssPending HSSE'
                  : hssPending > 0
                      ? '$hssPending menunggu HSSE'
                      : 'Semua tervalidasi ✅',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 LABEL HELPERS
  // ═══════════════════════════════════════════════════════════

  String _getPendingLabel() {
    if (isHSSE) return 'HSSE Pending';
    return 'Pending';
  }

  String _getApprovedLabel() {
    if (isHSSE) return 'Approved';
    return 'Disetujui';
  }

  String _getRejectedLabel() {
    if (isHSSE) return 'Rejected';
    return 'Ditolak';
  }
}

// ═══════════════════════════════════════════════════════════
// 🔥 DATA CLASS: EXTRA COUNTERS
// ═══════════════════════════════════════════════════════════

class _ExtraCountersData {
  final int cancelled;
  final int pendingHSSE;
  final int needAbsensi;
  final int riskyCount;
  final int perluRevisi;
  final int escalated;
  final int hssApproved;
  final int hssRejected;
  final int hssPending;
  final int hssRevisi;
  final int onlineNow;
  final int verifiedUsers;
  final int rejected;

  const _ExtraCountersData({
    required this.cancelled,
    required this.pendingHSSE,
    required this.needAbsensi,
    required this.riskyCount,
    required this.perluRevisi,
    required this.escalated,
    required this.hssApproved,
    required this.hssRejected,
    required this.hssPending,
    required this.hssRevisi,
    required this.onlineNow,
    required this.verifiedUsers,
    required this.rejected,
  });
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
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c.withOpacity(0.85), size: 16),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.toString(),
              style: GoogleFonts.poppins(
                color: c,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                height: 1.1,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: c.withOpacity(0.7),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔥 COMPACT INFO ITEM
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
        Icon(icon, color: Colors.white70, size: 13),
        const SizedBox(width: 4),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 8,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}