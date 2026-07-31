// lib/widgets/superadmin/stats_grid.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/superadmin_service.dart';

class StatsGrid extends StatefulWidget {
  final DashboardData? data;
  final String? roleFilter;
  final bool useRealtime;
  final bool isLoading;

  const StatsGrid({
    super.key,
    this.data,
    this.roleFilter,
    this.useRealtime = true,
    this.isLoading = false,
  });

  @override
  State<StatsGrid> createState() => _StatsGridState();
}

class _StatsGridState extends State<StatsGrid> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription? _usersSubscription;
  StreamSubscription? _pendingSubscription;
  StreamSubscription? _pendingHSSESubscription;
  StreamSubscription? _overtimeSubscription;
  StreamSubscription? _onlineSubscription;

  // =========================
  // DATA
  // =========================
  int _totalUsers = 0;
  int _activeToday = 0;
  int _pendingApprovals = 0;
  int _pendingHSSEApprovals = 0;
  int _totalOvertime = 0;
  int _approvedOvertime = 0;
  int _rejectedOvertime = 0;
  int _verifiedUsers = 0;
  int _onlineNow = 0;
  int _lockedAccounts = 0;
  int _newUsersToday = 0;

  int _prevTotalUsers = 0;
  int _prevPendingApprovals = 0;
  int _prevPendingHSSEApprovals = 0;
  int _prevTotalOvertime = 0;

  bool _isLoading = true;
  String? _error;

  // =========================
  // INIT
  // =========================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.data != null) {
      _updateFromData(widget.data!);
      _isLoading = false;
    }

    if (widget.useRealtime && widget.data == null) {
      _setupRealtimeListeners();
    } else if (!widget.useRealtime && widget.data == null) {
      _loadStatsOnce();
    }
  }

  @override
  void didUpdateWidget(StatsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != null && widget.data != oldWidget.data) {
      _updateFromData(widget.data!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usersSubscription?.cancel();
    _pendingSubscription?.cancel();
    _pendingHSSESubscription?.cancel();
    _overtimeSubscription?.cancel();
    _onlineSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!widget.useRealtime && widget.data == null) {
        _loadStatsOnce();
      }
    }
  }

  // =========================
  // UPDATE FROM DATA
  // =========================
  void _updateFromData(DashboardData data) {
    setState(() {
      _totalUsers = data.totalUsers;
      _activeToday = data.activeToday;
      _pendingApprovals = data.pendingApprovals;
      _pendingHSSEApprovals = data.pendingHSSEApprovals;
      _totalOvertime = data.totalOvertimeBulanIni;
      _approvedOvertime = data.approvedOvertimeBulanIni != 0
          ? data.approvedOvertimeBulanIni
          : (data.lemburByStatusBulanIni['disetujui'] ?? 0);
      _rejectedOvertime = data.rejectedOvertimeBulanIni != 0
          ? data.rejectedOvertimeBulanIni
          : (data.lemburByStatusBulanIni['ditolak'] ?? 0);
      _verifiedUsers = data.verifiedUsers;
      _lockedAccounts = data.lockedAccounts;
      _newUsersToday = data.newUsersToday;
      _isLoading = false;
      _error = null;
    });
  }

  // =========================
  // REALTIME LISTENERS
  // =========================
  void _setupRealtimeListeners() {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    _usersSubscription = _firestore
        .collection('users')
        .orderBy('last_login', descending: true)
        .limit(500)
        .snapshots()
        .listen(
          (snapshot) => _processUsersData(snapshot.docs),
          onError: (e) {
            debugPrint('Users stream error: $e');
            if (mounted)
              setState(() {
                _error = 'Gagal memuat data users';
                _isLoading = false;
              });
          },
        );

    Query<Map<String, dynamic>> pendingQuery = _firestore
        .collection('pengajuan_lembur')
        .where('status', isEqualTo: 'pending');
    if (widget.roleFilter != null &&
        widget.roleFilter!.isNotEmpty &&
        widget.roleFilter != 'semua') {
      pendingQuery =
          pendingQuery.where('pengawas_fungsi', isEqualTo: widget.roleFilter);
    }
    _pendingSubscription = pendingQuery.snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _prevPendingApprovals = _pendingApprovals;
          _pendingApprovals = snapshot.docs.length;
        });
      },
      onError: (e) => debugPrint('Pending stream error: $e'),
    );

    Query<Map<String, dynamic>> pendingHSSEQuery = _firestore
        .collection('pengajuan_lembur')
        .where('status', isEqualTo: 'pending_hsse');
    if (widget.roleFilter != null &&
        widget.roleFilter!.isNotEmpty &&
        widget.roleFilter != 'semua') {
      pendingHSSEQuery =
          pendingHSSEQuery.where('pengawas_fungsi', isEqualTo: widget.roleFilter);
    }
    _pendingHSSESubscription = pendingHSSEQuery.snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _prevPendingHSSEApprovals = _pendingHSSEApprovals;
          _pendingHSSEApprovals = snapshot.docs.length;
        });
      },
      onError: (e) => debugPrint('Pending HSSE stream error: $e'),
    );

    _overtimeSubscription = _firestore
        .collection('lembur_mitra')
        .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        int total = 0;
        int approved = 0;
        int rejected = 0;

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().toLowerCase();
          if ([
            'disetujui',
            'approved',
            'selesai',
            'check_in',
            'check_out',
            'pending',
            'pending_hsse',
            'ditolak',
            'rejected'
          ].contains(status)) {
            total++;
          }
          if (['disetujui', 'approved'].contains(status)) {
            approved++;
          }
          if (['ditolak', 'rejected'].contains(status)) {
            rejected++;
          }
        }

        setState(() {
          _prevTotalOvertime = _totalOvertime;
          _totalOvertime = total;
          _approvedOvertime = approved;
          _rejectedOvertime = rejected;
        });
      },
      onError: (e) => debugPrint('Overtime stream error: $e'),
    );

    _onlineSubscription = _firestore
        .collection('online_users')
        .where('is_online', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        setState(() => _onlineNow = snapshot.docs.length);
      },
      onError: (e) => debugPrint('Online stream error: $e'),
    );
  }

  // =========================
  // PROCESS USERS
  // =========================
  void _processUsersData(List<QueryDocumentSnapshot> docs) {
    if (!mounted) return;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    int activeToday = 0;
    int verifiedUsers = 0;
    int lockedAccounts = 0;
    int newUsersToday = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      if (data['is_verified'] == true) verifiedUsers++;
      if (data['account_locked'] == true) lockedAccounts++;

      final lastLogin = data['last_login'];
      if (lastLogin != null) {
        DateTime loginDate;
        if (lastLogin is Timestamp) {
          loginDate = lastLogin.toDate();
        } else if (lastLogin is String) {
          loginDate = DateTime.tryParse(lastLogin) ?? DateTime(2000);
        } else {
          loginDate = DateTime(2000);
        }
        if (loginDate.isAfter(startOfDay)) activeToday++;
      }

      final createdAt = data['created_at'];
      if (createdAt != null) {
        DateTime createDate;
        if (createdAt is Timestamp) {
          createDate = createdAt.toDate();
        } else if (createdAt is String) {
          createDate = DateTime.tryParse(createdAt) ?? DateTime(2000);
        } else {
          createDate = DateTime(2000);
        }
        if (createDate.isAfter(startOfDay)) newUsersToday++;
      }
    }

    if (!mounted) return;

    setState(() {
      _prevTotalUsers = _totalUsers;
      _totalUsers = docs.length;
      _activeToday = activeToday;
      _verifiedUsers = verifiedUsers;
      _lockedAccounts = lockedAccounts;
      _newUsersToday = newUsersToday;
      _isLoading = false;
      _error = null;
    });
  }

  // =========================
  // LOAD ONCE
  // =========================
  Future<void> _loadStatsOnce() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    try {
      Query<Map<String, dynamic>> pendingQuery = _firestore
          .collection('pengajuan_lembur')
          .where('status', isEqualTo: 'pending');
      if (widget.roleFilter != null &&
          widget.roleFilter!.isNotEmpty &&
          widget.roleFilter != 'semua') {
        pendingQuery =
            pendingQuery.where('pengawas_fungsi', isEqualTo: widget.roleFilter);
      }

      Query<Map<String, dynamic>> pendingHSSEQuery = _firestore
          .collection('pengajuan_lembur')
          .where('status', isEqualTo: 'pending_hsse');
      if (widget.roleFilter != null &&
          widget.roleFilter!.isNotEmpty &&
          widget.roleFilter != 'semua') {
        pendingHSSEQuery =
            pendingHSSEQuery.where('pengawas_fungsi', isEqualTo: widget.roleFilter);
      }

      final results = await Future.wait([
        _firestore
            .collection('users')
            .orderBy('last_login', descending: true)
            .limit(500)
            .get(),
        pendingQuery.count().get(),
        pendingHSSEQuery.count().get(),
        _firestore
            .collection('lembur_mitra')
            .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .get(),
        _firestore
            .collection('online_users')
            .where('is_online', isEqualTo: true)
            .count()
            .get(),
      ]);

      final usersSnapshot = results[0] as QuerySnapshot;
      final pendingCount = (results[1] as AggregateQuerySnapshot).count;
      final pendingHSSECount = (results[2] as AggregateQuerySnapshot).count;
      final lemburSnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;
      final onlineCount = (results[4] as AggregateQuerySnapshot).count;

      _processUsersData(usersSnapshot.docs);

      int totalLembur = 0;
      int approved = 0;
      int rejected = 0;
      for (var doc in lemburSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        if ([
          'disetujui',
          'approved',
          'selesai',
          'check_in',
          'check_out',
          'pending',
          'pending_hsse',
          'ditolak',
          'rejected'
        ].contains(status)) {
          totalLembur++;
        }
        if (['disetujui', 'approved'].contains(status)) approved++;
        if (['ditolak', 'rejected'].contains(status)) rejected++;
      }

      if (!mounted) return;

      setState(() {
        _pendingApprovals = pendingCount ?? 0;
        _pendingHSSEApprovals = pendingHSSECount ?? 0;
        _totalOvertime = totalLembur;
        _approvedOvertime = approved;
        _rejectedOvertime = rejected;
        _onlineNow = onlineCount ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load stats error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat statistik';
        _isLoading = false;
      });
    }
  }

  Future<void> refreshStats() async {
    if (widget.data != null) return;
    if (widget.useRealtime) {
      _usersSubscription?.cancel();
      _pendingSubscription?.cancel();
      _pendingHSSESubscription?.cancel();
      _overtimeSubscription?.cancel();
      _onlineSubscription?.cancel();
      _setupRealtimeListeners();
    } else {
      await _loadStatsOnce();
    }
  }

  // =========================
  // HELPERS
  // =========================
  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String _calculateTrend(int current, int previous) {
    if (previous == 0) return current > 0 ? '+100%' : '0%';
    final change = ((current - previous) / previous * 100).round();
    return change >= 0 ? '+$change%' : '$change%';
  }

  bool _isTrendUp(int current, int previous) => current >= previous;

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    if (widget.isLoading || _isLoading) return _buildLoadingGrid();
    if (_error != null) return _buildErrorState();
    return _buildStatsGrid();
  }

  // =========================
  // LOADING
  // =========================
  Widget _buildLoadingGrid() {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 430;

    return Column(
      children: [
        Container(
          height: isMobile ? 80 : 90,
          margin: EdgeInsets.only(bottom: isMobile ? 4 : 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 2 : 2,
            crossAxisSpacing: isMobile ? 4 : 6,
            mainAxisSpacing: isMobile ? 4 : 6,
            childAspectRatio: isMobile ? 1.15 : 1.30,
          ),
          itemCount: isMobile ? 6 : 5, // 🔥 Mobile: 6 (2 row x 3 col akan jadi 6 placeholder)
          itemBuilder: (context, index) {
            if (isMobile && index >= 5) return const SizedBox.shrink(); // Extra placeholder
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isMobile ? 28 : 34,
                      height: isMobile ? 28 : 34,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 10),
                    Container(
                      width: isMobile ? 55 : 65,
                      height: isMobile ? 14 : 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 5),
                    Container(
                      width: isMobile ? 70 : 80,
                      height: isMobile ? 7 : 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // =========================
  // ERROR
  // =========================
  Widget _buildErrorState() {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 430;

    return Container(
      margin: EdgeInsets.all(isMobile ? 6 : 8),
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade300, size: isMobile ? 28 : 34),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            _error ?? 'Terjadi kesalahan',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.w500,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: isMobile ? 8 : 10),
          TextButton.icon(
            onPressed: () {
              if (widget.useRealtime) {
                _setupRealtimeListeners();
              } else {
                _loadStatsOnce();
              }
            },
            icon: Icon(Icons.refresh_rounded, size: isMobile ? 12 : 14),
            label: Text(
              'Coba Lagi',
              style: GoogleFonts.poppins(fontSize: isMobile ? 10 : 12),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // 🔥 GRID UTAMA (5 CARD)
  // =========================
  Widget _buildStatsGrid() {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 430;
    final isSmallMobile = width < 360;

    // 🔥 Responsive grid config
    final crossAxisCount = width >= 1200
        ? 5
        : width >= 900
            ? 4
            : width >= 600
                ? 3
                : 2; // Mobile: 2 kolom

    final childAspectRatio = isSmallMobile
        ? 1.05
        : isMobile
            ? 1.12
            : width < 600
                ? 1.22
                : 1.30;

    final spacing = isMobile ? 4.0 : 6.0;

    return Column(
      children: [
        _buildTotalUsersCard(isMobile: isMobile),
        SizedBox(height: spacing),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: 5,
          itemBuilder: (context, index) =>
              _buildSmallCard(index, isMobile: isMobile),
        ),
        if (widget.useRealtime)
          Padding(
            padding: EdgeInsets.only(top: isMobile ? 3 : 4, right: isMobile ? 2 : 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: isMobile ? 5 : 6,
                  height: isMobile ? 5 : 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: isMobile ? 3 : 4),
                Text(
                  'Realtime',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 8 : 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // =========================
  // 🔥 TOTAL USERS CARD (Responsive)
  // =========================
  Widget _buildTotalUsersCard({required bool isMobile}) {
    final isOnline = _onlineNow > 0;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(45),
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
            ),
            child: Icon(
              Icons.people_alt_rounded,
              color: Colors.white,
              size: isMobile ? 22 : 28,
            ),
          ),
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Pengguna',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: isMobile ? 1 : 2),
                Text(
                  _formatNumber(_totalUsers),
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                SizedBox(height: isMobile ? 1 : 2),
                Text(
                  '$_verifiedUsers terverifikasi | $_newUsersToday baru',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 8 : 9,
                    color: Colors.white60,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10,
                  vertical: isMobile ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFF00C853).withAlpha(40)
                      : Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isMobile ? 7 : 8,
                      height: isMobile ? 7 : 8,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF00C853)
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: isMobile ? 4 : 6),
                    Text(
                      '$_onlineNow',
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 8 : 9,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // 🔥 SMALL CARD (Responsive)
  // =========================
  Widget _buildSmallCard(int index, {required bool isMobile}) {
    final isSmallMobile = MediaQuery.of(context).size.width < 360;

    final items = [
      _SmallCardData(
        title: 'Total Lembur',
        value: _formatNumber(_totalOvertime),
        icon: Icons.work_history_rounded,
        subtitle: 'Semua fungsi',
        gradientColors: const [Color(0xFF7F00FF), Color(0xFFE100FF)],
        trend: _calculateTrend(_totalOvertime, _prevTotalOvertime),
        trendUp: _isTrendUp(_totalOvertime, _prevTotalOvertime),
      ),
      _SmallCardData(
        title: 'Pending Fungsi',
        value: _formatNumber(_pendingApprovals),
        icon: Icons.pending_actions_rounded,
        subtitle: _pendingApprovals > 0 ? 'Perlu tindakan' : 'Tidak ada',
        gradientColors: const [Color(0xFFF12711), Color(0xFFF5AF19)],
        trend: _calculateTrend(_pendingApprovals, _prevPendingApprovals),
        trendUp: _isTrendUp(_pendingApprovals, _prevPendingApprovals),
      ),
      _SmallCardData(
        title: 'Pending HSSE',
        value: _formatNumber(_pendingHSSEApprovals),
        icon: Icons.shield_rounded,
        subtitle: _pendingHSSEApprovals > 0 ? 'Review HSSE' : 'Tidak ada',
        gradientColors: const [Color(0xFFF59E0B), Color(0xFFB45309)],
        trend: _calculateTrend(
            _pendingHSSEApprovals, _prevPendingHSSEApprovals),
        trendUp:
            _isTrendUp(_pendingHSSEApprovals, _prevPendingHSSEApprovals),
      ),
      _SmallCardData(
        title: 'Disetujui',
        value: _formatNumber(_approvedOvertime),
        icon: Icons.check_circle_rounded,
        subtitle: 'Bulan ini',
        gradientColors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        trend: _approvedOvertime > 0 ? '✅ Aktif' : '0',
        trendUp: true,
      ),
      _SmallCardData(
        title: 'Ditolak',
        value: _formatNumber(_rejectedOvertime),
        icon: Icons.cancel_rounded,
        subtitle: _rejectedOvertime > 0 ? 'Perlu revisi' : 'Tidak ada',
        gradientColors: _rejectedOvertime > 3
            ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
            : _rejectedOvertime > 0
                ? [const Color(0xFFF43F5E), const Color(0xFFE11D48)]
                : [const Color(0xFF64748B), const Color(0xFF475569)],
        trend: _rejectedOvertime > 0 ? '⚠️ $_rejectedOvertime' : '✅ 0',
        trendUp: false,
      ),
    ];

    final item = items[index];

    // 🔥 Ukuran responsif
    final cardPadding = isSmallMobile ? 6.0 : (isMobile ? 8.0 : 8.0);
    final iconContainerPadding =
        isSmallMobile ? 4.0 : (isMobile ? 5.0 : 6.0);
    final iconSize = isSmallMobile ? 14.0 : (isMobile ? 16.0 : 18.0);
    final valueFontSize = isSmallMobile ? 18.0 : (isMobile ? 20.0 : 24.0);
    final titleFontSize = isSmallMobile ? 7.5 : (isMobile ? 8.0 : 9.0);
    final subtitleFontSize = isSmallMobile ? 6.0 : (isMobile ? 6.5 : 7.0);
    final trendFontSize = isSmallMobile ? 6.5 : (isMobile ? 7.0 : 8.0);
    final trendIconSize = isSmallMobile ? 7.0 : (isMobile ? 8.0 : 9.0);
    final trendPaddingH = isSmallMobile ? 4.0 : (isMobile ? 5.0 : 6.0);
    final trendPaddingV = isSmallMobile ? 2.0 : (isMobile ? 2.5 : 3.0);
    final borderRadius = isSmallMobile ? 12.0 : (isMobile ? 14.0 : 16.0);
    final iconBorderRadius = isSmallMobile ? 7.0 : (isMobile ? 8.0 : 10.0);
    final trendBorderRadius = isSmallMobile ? 7.0 : (isMobile ? 8.0 : 10.0);

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: item.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: item.gradientColors.first.withAlpha(60),
            blurRadius: isMobile ? 8 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(iconContainerPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(45),
                  borderRadius: BorderRadius.circular(iconBorderRadius),
                ),
                child: Icon(item.icon, color: Colors.white, size: iconSize),
              ),
              _buildTrendBadge(
                item.trend,
                item.trendUp,
                fontSize: trendFontSize,
                iconSize: trendIconSize,
                paddingH: trendPaddingH,
                paddingV: trendPaddingV,
                borderRadius: trendBorderRadius,
              ),
            ],
          ),
          SizedBox(height: isMobile ? 4 : 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  item.value,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 1 : 2),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: isMobile ? 0.5 : 1),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: subtitleFontSize,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // 🔥 TREND BADGE (Responsive)
  // =========================
  Widget _buildTrendBadge(
    String trend,
    bool trendUp, {
    required double fontSize,
    required double iconSize,
    required double paddingH,
    required double paddingV,
    required double borderRadius,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(45),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: Colors.white,
            size: iconSize,
          ),
          SizedBox(width: paddingH * 0.3),
          Text(
            trend,
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================
// MODEL
// =========================
class _SmallCardData {
  final String title;
  final String value;
  final IconData icon;
  final String subtitle;
  final List<Color> gradientColors;
  final String trend;
  final bool trendUp;

  _SmallCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    required this.gradientColors,
    required this.trend,
    required this.trendUp,
  });
}