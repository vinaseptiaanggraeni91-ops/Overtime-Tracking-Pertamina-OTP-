import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '/core/services/absensi_history_service.dart';
import '/core/services/overtime_history_service.dart';
import '/widgets/bottom_nav/app_bottom_nav.dart';

// ============================================================================
class AbsensiHistoryScreen extends StatefulWidget {
  const AbsensiHistoryScreen({super.key});

  @override
  State<AbsensiHistoryScreen> createState() => _AbsensiHistoryScreenState();
}

class _AbsensiHistoryScreenState extends State<AbsensiHistoryScreen> {
  // ─── SERVICES ───
  final AbsensiHistoryService _absensiService = AbsensiHistoryService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── USER DATA ───
  String? _userId;
  String? _userName;
  String? _userRole;
  String? _userFungsi;
  bool _isLoading = true;

  // 🔥 ROLE DETECTION
  bool get _isMitra => _userRole == 'mitra';
  bool get _isPengawas => _userRole == 'pengawas';
  bool get _isManager => _userRole == 'manager';
  bool get _isHSSE => _userFungsi == 'hsse';
  bool get _isSuperadmin => _userRole == 'superadmin';
  bool get _canSeeAll => _isSuperadmin || (_isManager && !_isHSSE);
  bool get _isHSSEManager => _userRole == 'manager' && _userFungsi == 'hsse';

  // ─── FILTERS ───
  String _selectedBulan = 'semua';
  bool _showAllMonths = true;
  String _selectedStatus = 'semua';
  String _selectedPembayaran = 'semua';

  // ─── SUMMARY DATA ───
  AbsensiHistorySummary? _summary;
  bool _isSummaryLoading = false;

  // ═══════════════════════════════════════════════════════════════
  // 🔥🔥🔥 CONSTANT: HANYA STATUS YANG DISETUJUI
  // ═══════════════════════════════════════════════════════════════
  static const List<String> _approvedStatuses = [
    'disetujui',
    'approved',
    'selesai',
    'completed',
  ];

  // ═══════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ═══════════════════════════════════════════════════════════════
  // LOAD USER DATA
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadUserData() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    _userId = user.uid;
    _userName = user.displayName ?? user.email?.split('@').first ?? 'User';

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        setState(() {
          _userRole = data?['role']?.toString().toLowerCase() ?? 'mitra';
          _userFungsi = data?['fungsi']?.toString().toLowerCase();
        });
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }

    if (mounted) {
      await _loadSummary();
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER: Cek apakah dokumen dibatalkan
  // ═══════════════════════════════════════════════════════════════

  bool _isDibatalkan(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    return status == 'dibatalkan';
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER: Cek apakah absensi sudah SELESAI
  // ═══════════════════════════════════════════════════════════════

  bool _isAbsensiSelesai(String? absensiStatus) {
    return absensiStatus == 'selesai' || absensiStatus == 'selesai_terlambat';
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 HELPER: Deteksi tipe tampilan absensi
  // ═══════════════════════════════════════════════════════════════
  bool _isTidakLembur(String? absensiStatus) => absensiStatus == 'tidak_lembur';
  bool _isTerlambat(String? absensiStatus) => absensiStatus == 'selesai_terlambat';
  bool _isSelesaiNormal(String? absensiStatus) => absensiStatus == 'selesai';

  // ═══════════════════════════════════════════════════════════════
  // LOAD SUMMARY - ROLE-BASED + EXCLUDE DIBATALKAN
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadSummary() async {
    if (_userId == null) return;

    setState(() => _isSummaryLoading = true);

    try {
      AbsensiHistorySummary summary;

      if (_canSeeAll || _isSuperadmin || _isManager) {
        summary = await _loadGlobalSummary();
      } else {
        summary = await _absensiService.getSummary(
          userId: _userId!,
          bulan: _showAllMonths ? null : _selectedBulan,
        );
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _isSummaryLoading = false;
        });
      }

      debugPrint('✅ Summary loaded: Total=${summary.totalLembur}, '
          'Hadir=${summary.totalHadir}, Jam=${summary.totalJam.toStringAsFixed(1)}, '
          'Pendapatan=${summary.totalPendapatanFormatted}, '
          'Dibayar=${summary.totalDibayar}, Belum=${summary.totalBelumDibayar}');
    } catch (e) {
      debugPrint('❌ Error loading summary: $e');
      if (mounted) {
        setState(() => _isSummaryLoading = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥🔥🔥 SUMMARY GLOBAL - HANYA YANG DISETUJUI
  // TOTAL JAM & PENDAPATAN HANYA UNTUK SELESAI
  // ═══════════════════════════════════════════════════════════════

  Future<AbsensiHistorySummary> _loadGlobalSummary() async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('lembur_mitra');

      // 🔥🔥🔥 PERBAIKAN: HANYA STATUS YANG DISETUJUI
      query = query.where('status', whereIn: _approvedStatuses);

      if (!_showAllMonths && _selectedBulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: _selectedBulan);
      }

      if (_isManager && !_isHSSE && _userFungsi != null && _userFungsi!.isNotEmpty) {
        query = query.where('pengawas_fungsi', isEqualTo: _userFungsi);
      }

      final snapshot = await query.get();

      // ─── COUNTERS ───
      int totalLembur = 0;
      int totalHadir = 0;
      int totalTerlambat = 0;
      int totalTidakHadir = 0;
      int totalBelum = 0;
      int totalCheckIn = 0;

      // 🔥 TOTAL JAM & PENDAPATAN - HANYA UNTUK SELESAI
      double totalJam = 0;
      double totalPendapatan = 0;
      double totalDibayar = 0;
      double totalBelumDibayar = 0;
      int totalPaid = 0;
      int totalUnpaid = 0;
      double maxJam = 0;
      double minJam = double.infinity;
      int jamCount = 0;

      // ─── DISTRIBUTIONS ───
      DateTime? earliestTanggal;
      DateTime? latestTanggal;
      Map<String, int> statusDistribution = {};
      Map<String, int> dailyDistribution = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Skip dibatalkan (filter client-side sebagai pengaman)
        if (_isDibatalkan(data)) continue;

        totalLembur++;

        // ─── ABSENSI STATUS ───
        final absensiStatus = data['absensi_status']?.toString() ?? 'belum_absen';
        statusDistribution[absensiStatus] = (statusDistribution[absensiStatus] ?? 0) + 1;

        switch (absensiStatus) {
          case 'selesai':
            totalHadir++;
            break;
          case 'selesai_terlambat':
            totalHadir++;
            totalTerlambat++;
            break;
          case 'check_in':
          case 'sudah_absen':
            totalCheckIn++;
            break;
          case 'tidak_lembur':
            totalTidakHadir++;
            break;
          default:
            totalBelum++;
        }

        // ═══════════════════════════════════════════════
        // TOTAL JAM & PENDAPATAN HANYA JIKA SELESAI
        // ═══════════════════════════════════════════════
        final bool isSelesai = _isAbsensiSelesai(absensiStatus);

        // ─── TOTAL JAM (HANYA JIKA SELESAI) ───
        if (isSelesai) {
          double jam = 0;
          final jamValue = data['total_jam_desimal'] ??
              data['total_jam_real'] ??
              data['actual_total_jam'] ??
              0;
          if (jamValue is double) {
            jam = jamValue;
          } else if (jamValue is int) {
            jam = jamValue.toDouble();
          } else if (jamValue is String) {
            jam = double.tryParse(jamValue) ?? 0;
          }

          if (jam > 0) {
            totalJam += jam;
            if (jam > maxJam) maxJam = jam;
            if (jam < minJam) minJam = jam;
            jamCount++;
          }
        }

        // ─── PENDAPATAN (HANYA JIKA SELESAI) ───
        double pendapatan = 0;
        if (isSelesai) {
          final pValue = data['actual_income'] ??
              data['income'] ??
              data['income_amount'] ??
              data['pendapatan_actual'] ??
              data['estimasi_biaya_per_mitra'] ??
              data['estimasi_biaya'] ??
              0;
          if (pValue is double) {
            pendapatan = pValue;
          } else if (pValue is int) {
            pendapatan = pValue.toDouble();
          } else if (pValue is String) {
            pendapatan = double.tryParse(pValue) ?? 0;
          }
        }
        totalPendapatan += pendapatan;

        // ─── PEMBAYARAN (HANYA JIKA SELESAI) ───
        bool isPaid = false;
        if (isSelesai) {
          isPaid = _checkIsPaid(data);
        }

        if (isPaid) {
          totalPaid++;
          totalDibayar += pendapatan;
        } else if (isSelesai && pendapatan > 0) {
          totalUnpaid++;
          totalBelumDibayar += pendapatan;
        }

        // ─── TANGGAL ───
        final tgl = data['tanggal'] ?? data['tanggal_lembur'];
        if (tgl is Timestamp) {
          final date = tgl.toDate();
          if (earliestTanggal == null || date.isBefore(earliestTanggal)) {
            earliestTanggal = date;
          }
          if (latestTanggal == null || date.isAfter(latestTanggal)) {
            latestTanggal = date;
          }
          final dayKey = DateFormat('EEEE', 'id_ID').format(date);
          dailyDistribution[dayKey] = (dailyDistribution[dayKey] ?? 0) + 1;
        }
      }

      // ─── KALKULASI FINAL ───
      final double avgJam = jamCount > 0 ? totalJam / jamCount : 0;
      final double avgPendapatan =
          totalLembur > 0 ? totalPendapatan / totalLembur : 0;
      final double persentaseHadir =
          totalLembur > 0 ? (totalHadir / totalLembur) * 100 : 0;
      final double persentaseTerlambat =
          totalHadir > 0 ? (totalTerlambat / totalHadir) * 100 : 0;
      final double persentasePaid =
          totalLembur > 0 ? (totalPaid / totalLembur) * 100 : 0;

      return AbsensiHistorySummary(
        totalLembur: totalLembur,
        totalHadir: totalHadir,
        totalTerlambat: totalTerlambat,
        totalTidakHadir: totalTidakHadir,
        totalExpired: 0,
        totalBelum: totalBelum,
        totalCheckIn: totalCheckIn,
        totalSudahAbsen: 0,
        totalJam: totalJam,
        totalPendapatan: totalPendapatan,
        totalDibayar: totalDibayar,
        totalBelumDibayar: totalBelumDibayar,
        totalPaid: totalPaid,
        totalUnpaid: totalUnpaid,
        avgJam: avgJam,
        maxJam: maxJam < double.infinity ? maxJam : 0,
        minJam: minJam < double.infinity ? minJam : 0,
        avgPendapatan: avgPendapatan,
        persentaseHadir: persentaseHadir,
        persentaseTerlambat: persentaseTerlambat,
        persentasePaid: persentasePaid,
        earliestTanggal: earliestTanggal,
        latestTanggal: latestTanggal,
        statusDistribution: statusDistribution,
        dailyDistribution: dailyDistribution,
        hourlyDistribution: {},
        totalDays: dailyDistribution.length,
        totalHours: 0,
      );
    } catch (e) {
      debugPrint('❌ Error _loadGlobalSummary: $e');
      return AbsensiHistorySummary.empty();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F9FF),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1976D2)),
        ),
      );
    }

    final primaryColor =
        _isHSSE ? const Color(0xFFB71C1C) : const Color(0xFF1E3C72);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: _buildAppBar(primaryColor),
      bottomNavigationBar: _userRole != null
          ? AppBottomNav(
              userRole: _userRole!,
              currentIndex: 2,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadSummary();
          setState(() {});
        },
        color: primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildBulanIndicator()),
            if (_canSeeAll || _isHSSE)
              SliverToBoxAdapter(child: _buildRoleBanner()),
            SliverToBoxAdapter(child: _buildStatsCard()),
            if (_summary != null && _summary!.totalLembur > 0)
              SliverToBoxAdapter(child: _buildSubStatsRow()),
            SliverToBoxAdapter(child: _buildFilterChips()),
            if (_canSeeAll || _isSuperadmin)
              SliverToBoxAdapter(child: _buildPembayaranChips()),
            SliverFillRemaining(
              hasScrollBody: true,
              child: _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD LIST - ROLE-BASED ROUTING
  // ═══════════════════════════════════════════════════════════════

  Widget _buildList() {
    if (_userId == null) return const SizedBox.shrink();

    if (_isMitra || _isPengawas) {
      return _buildUserHistoryStream();
    } else {
      return _buildAdminHistoryStream();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STREAM: USER (Mitra / Pengawas)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildUserHistoryStream() {
    return StreamBuilder<List<AbsensiHistoryItem>>(
      stream: _absensiService.streamHistory(
        userId: _userId!,
        bulan: _showAllMonths ? null : _selectedBulan,
        statusFilter: _selectedStatus != 'semua' ? _selectedStatus : null,
        limit: 50,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: CircularProgressIndicator(color: Color(0xFF1976D2)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildAbsensiCard(items[index]),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥🔥🔥 STREAM ADMIN - HANYA YANG DISETUJUI
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAdminHistoryStream() {
    Query<Map<String, dynamic>> query = _firestore.collection('lembur_mitra');

    // 🔥🔥🔥 PERBAIKAN: HANYA STATUS YANG DISETUJUI
    query = query.where('status', whereIn: _approvedStatuses);

    if (!_showAllMonths && _selectedBulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: _selectedBulan);
    }

    if (_selectedStatus != 'semua') {
      query = query.where('absensi_status', isEqualTo: _selectedStatus);
    }

    if (_isManager && !_isHSSE && _userFungsi != null && _userFungsi!.isNotEmpty) {
      query = query.where('pengawas_fungsi', isEqualTo: _userFungsi);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.orderBy('tanggal', descending: true).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: CircularProgressIndicator(color: Color(0xFF1976D2)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final docs = snapshot.data?.docs ?? [];

        // 🔥 Filter dibatalkan di client-side (pengaman)
        var filteredDocs =
            docs.where((doc) => !_isDibatalkan(doc.data())).toList();

        // Filter pembayaran (client-side)
        if (_selectedPembayaran == 'dibayar') {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data();
            return _checkIsPaid(data);
          }).toList();
        } else if (_selectedPembayaran == 'belum_dibayar') {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data();
            return !_checkIsPaid(data);
          }).toList();
        }

        if (filteredDocs.isEmpty) return _buildEmptyState();

        final items = filteredDocs.map((doc) {
          final rawData = doc.data();
          final overtimeHistory = OvertimeHistory.fromFirestore(doc);
          return AbsensiHistoryItem.fromOvertimeHistory(
            overtimeHistory,
            rawData: rawData,
          );
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildAbsensiCard(items[index]),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER: Deteksi status pembayaran
  // ═══════════════════════════════════════════════════════════════

  bool _checkIsPaid(Map<String, dynamic> data) {
    if (data['is_paid'] == true) return true;

    final statusBayar = data['status_bayar']?.toString().toLowerCase();
    if (statusBayar == 'dibayar' ||
        statusBayar == 'sudah_dibayar' ||
        statusBayar == 'lunas' ||
        statusBayar == 'paid') {
      return true;
    }

    final statusPembayaran =
        data['status_pembayaran']?.toString().toLowerCase();
    if (statusPembayaran == 'lunas' ||
        statusPembayaran == 'dibayar' ||
        statusPembayaran == 'sudah_dibayar' ||
        statusPembayaran == 'paid') {
      return true;
    }

    final paymentStatus =
        data['payment_status']?.toString().toLowerCase();
    if (paymentStatus == 'paid' ||
        paymentStatus == 'completed' ||
        paymentStatus == 'lunas' ||
        paymentStatus == 'dibayar') {
      return true;
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar([Color? color]) {
    final primaryColor = color ?? const Color(0xFF1E3C72);

    return AppBar(
      title: Text(
        _getAppBarTitle(),
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: () => _loadSummary(),
          tooltip: 'Refresh Data',
        ),
        IconButton(
          icon: Icon(
            _showAllMonths ? Icons.filter_list_off : Icons.filter_list,
            size: 20,
          ),
          onPressed: _toggleBulanFilter,
          tooltip: _showAllMonths ? 'Filter per Bulan' : 'Tampilkan Semua',
        ),
        if (!_showAllMonths)
          IconButton(
            icon: const Icon(Icons.calendar_month, size: 20),
            onPressed: () => _showMonthPicker(),
            tooltip: 'Pilih Bulan',
          ),
      ],
    );
  }

  String _getAppBarTitle() {
    if (_isHSSEManager) return 'Absensi Berisiko';
    if (_isHSSE) return 'Absensi Lembur';
    if (_isSuperadmin) return 'Riwayat Absensi';
    if (_isManager) return 'Absensi Tim';
    if (_isPengawas) return 'Absensi Mitra Saya';
    return 'Riwayat Absensi';
  }

  // ═══════════════════════════════════════════════════════════════
  // ROLE BANNER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRoleBanner() {
    String message;
    Color bgColor;
    Color textColor;
    IconData icon;

    if (_isSuperadmin) {
      message = '👑 Melihat semua data absensi (disetujui)';
      bgColor = Colors.purple[50]!;
      textColor = Colors.purple[800]!;
      icon = Icons.admin_panel_settings;
    } else if (_isHSSEManager) {
      message = '🛡️ Melihat absensi berisiko tinggi (disetujui)';
      bgColor = Colors.red[50]!;
      textColor = Colors.red[800]!;
      icon = Icons.health_and_safety;
    } else if (_isManager) {
      message =
          '📋 Melihat absensi tim fungsi ${_userFungsi?.toUpperCase() ?? ""} (disetujui)';
      bgColor = Colors.blue[50]!;
      textColor = Colors.blue[800]!;
      icon = Icons.group;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BULAN INDICATOR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBulanIndicator() {
    final statusColor =
        _isHSSE ? const Color(0xFFB71C1C) : const Color(0xFF1E3C72);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 16,
            color: _showAllMonths ? Colors.green[700] : statusColor,
          ),
          const SizedBox(width: 8),
          Text(
            _showAllMonths
                ? 'Menampilkan: Semua Bulan'
                : 'Bulan: ${_getBulanLabel(_selectedBulan)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _showAllMonths ? Colors.green[700] : statusColor,
            ),
          ),
          const Spacer(),
          if (!_showAllMonths)
            TextButton(
              onPressed: _resetBulanFilter,
              child: Text(
                'Lihat Semua',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: statusColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥🔥🔥 STATS CARD - ENHANCED DENGAN KETERANGAN
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStatsCard() {
    if (_isSummaryLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        height: 140,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_summary == null || _summary!.totalLembur == 0) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isHSSE
                ? [const Color(0xFFB71C1C), const Color(0xFFD32F2F)]
                : [const Color(0xFF1E3C72), const Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, color: Colors.white70, size: 40),
            const SizedBox(height: 8),
            Text(
              'Belum ada data lembur yang disetujui',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Data akan muncul setelah lembur disetujui',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    final summary = _summary!;
    final formatRupiah =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isHSSE
              ? [const Color(0xFFB71C1C), const Color(0xFFD32F2F)]
              : [const Color(0xFF1E3C72), const Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isHSSE
                    ? const Color(0xFFB71C1C)
                    : const Color(0xFF1E3C72))
                .withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem(
                  icon: Icons.work_history,
                  label: 'Total Lembur',
                  value: '${summary.totalLembur}',
                  color: Colors.white),
              _buildStatItem(
                  icon: Icons.check_circle,
                  label: 'Hadir',
                  value: '${summary.totalHadir}',
                  color: Colors.green[300]!),
              _buildStatItem(
                  icon: Icons.warning_amber,
                  label: 'Terlambat',
                  value: '${summary.totalTerlambat}',
                  color: Colors.orange[300]!),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem(
                  icon: Icons.timer,
                  label: 'Total Jam*',
                  value: summary.totalJamFormatted,
                  color: Colors.blue[200]!),
              _buildStatItem(
                  icon: Icons.payments,
                  label: 'Pendapatan*',
                  value: formatRupiah.format(summary.totalPendapatan),
                  color: Colors.amber[300]!),
              _buildStatItem(
                  icon: Icons.percent,
                  label: 'Kehadiran',
                  value: '${summary.persentaseHadir.toStringAsFixed(0)}%',
                  color: Colors.teal[200]!),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '* Total jam & pendapatan hanya dari lembur yang sudah selesai',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.white.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SUB-STATS ROW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSubStatsRow() {
    if (_summary == null) return const SizedBox.shrink();
    final summary = _summary!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          _buildMiniStat(
              icon: Icons.trending_up,
              label: 'Rata² Jam*',
              value: summary.avgJamFormatted,
              color: Colors.blue[700]!),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          _buildMiniStat(
              icon: Icons.monetization_on_outlined,
              label: 'Rata² Pendapatan*',
              value: summary.avgPendapatanFormatted,
              color: Colors.green[700]!),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          _buildMiniStat(
              icon: Icons.date_range,
              label: 'Hari Aktif',
              value: '${summary.totalDays} hari',
              color: Colors.orange[700]!),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      {required IconData icon,
      required String label,
      required String value,
      required Color color}) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 9, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      {required IconData icon,
      required String label,
      required String value,
      required Color color}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: Colors.white.withOpacity(0.8))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FILTER CHIPS - STATUS ABSENSI
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFilterChips() {
    final statusOptions = AbsensiHistoryItem.getStatusOptions();

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: statusOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = statusOptions[index];
          final isSelected = _selectedStatus == option['value'];
          final color = option['color'] as Color;

          return FilterChip(
            selected: isSelected,
            label: Text(option['label'] as String,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : Colors.grey[700])),
            selectedColor: color,
            checkmarkColor: Colors.white,
            backgroundColor: Colors.white,
            side: BorderSide(color: isSelected ? color : Colors.grey[300]!),
            onSelected: (selected) {
              setState(() {
                _selectedStatus =
                    selected ? option['value'] as String : 'semua';
              });
            },
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FILTER CHIPS - PEMBAYARAN (ADMIN ONLY)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPembayaranChips() {
    final options = AbsensiHistoryItem.getStatusBayarOptions();

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = _selectedPembayaran == option['value'];

          return FilterChip(
            selected: isSelected,
            label: Text(option['label'] as String,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : Colors.grey[600])),
            selectedColor: isSelected ? Colors.green : null,
            checkmarkColor: Colors.white,
            backgroundColor: Colors.white,
            side:
                BorderSide(color: isSelected ? Colors.green : Colors.grey[300]!),
            onSelected: (selected) {
              setState(() {
                _selectedPembayaran =
                    selected ? option['value'] as String : 'semua';
              });
            },
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥🔥🔥 ABSENSI CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAbsensiCard(AbsensiHistoryItem item) {
    final bool isSelesai = _isSelesaiNormal(item.absensiStatus);
    final bool isTerlambat = _isTerlambat(item.absensiStatus);
    final bool isTidakLembur = _isTidakLembur(item.absensiStatus);
    final bool showDurasiPendapatan = isSelesai || isTerlambat;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetailSheet(item),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_canSeeAll && item.mitraNama != null)
                            Text(item.mitraNama!,
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          Text(item.tanggalFormatted,
                              style: GoogleFonts.poppins(
                                  fontSize: _canSeeAll ? 11 : 14,
                                  fontWeight: _canSeeAll
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                  color: _canSeeAll
                                      ? Colors.grey[600]
                                      : Colors.grey[800])),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: item.statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: item.statusColor.withOpacity(0.5))),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isTerlambat) ...[
                                  const Icon(Icons.warning_amber,
                                      size: 10, color: Colors.orange),
                                  const SizedBox(width: 3),
                                ],
                                if (isTidakLembur) ...[
                                  const Icon(Icons.cancel,
                                      size: 10, color: Colors.red),
                                  const SizedBox(width: 3),
                                ],
                                Text(item.absensiLabel,
                                    style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: item.statusColor)),
                              ],
                            )),
                        if (_canSeeAll) ...[
                          const SizedBox(height: 4),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color:
                                      item.statusBayarColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: item.statusBayarColor
                                          .withOpacity(0.5))),
                              child: Text(item.statusBayarLabel,
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: item.statusBayarColor))),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Jadwal: ${item.jamFormatted}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[600])),
                    if (item.lokasi != null && item.lokasi!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                          child: Text(item.lokasi!,
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: Colors.grey[500]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ],
                ),
                if (isTidakLembur) ...[
                  const SizedBox(height: 8),
                  _buildTidakLemburCardSection(item),
                ] else if (isTerlambat) ...[
                  const SizedBox(height: 8),
                  _buildTerlambatCardSection(item),
                ] else ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                          child: Row(children: [
                        Icon(Icons.login,
                            size: 16,
                            color: item.hasCheckIn
                                ? Colors.green
                                : Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                            item.hasCheckIn
                                ? item.checkInFormatted
                                : '--:--',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: item.hasCheckIn
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: item.hasCheckIn
                                    ? Colors.green[700]
                                    : Colors.grey[400])),
                      ])),
                      Icon(Icons.arrow_forward,
                          size: 16, color: Colors.grey[400]),
                      Expanded(
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                        Text(
                            item.hasCheckOut
                                ? item.checkOutFormatted
                                : '--:--',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: item.hasCheckOut
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: item.hasCheckOut
                                    ? Colors.red[700]
                                    : Colors.grey[400])),
                        const SizedBox(width: 4),
                        Icon(Icons.logout,
                            size: 16,
                            color: item.hasCheckOut
                                ? Colors.red
                                : Colors.grey[400]),
                      ])),
                    ],
                  ),
                ],
                if (showDurasiPendapatan && item.totalJam > 0) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Durasi: ${item.durasiRealFormatted}',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500)),
                  ]),
                ],
                if (showDurasiPendapatan && item.pendapatan > 0) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.payments, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(item.pendapatanFormatted,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500)),
                  ]),
                ],
                if (!isTidakLembur &&
                    ((item.checkInFotoUrl != null &&
                            item.checkInFotoUrl!.isNotEmpty) ||
                        (item.checkOutFotoUrl != null &&
                            item.checkOutFotoUrl!.isNotEmpty)))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      if (item.checkInFotoUrl != null &&
                          item.checkInFotoUrl!.isNotEmpty)
                        _buildFotoThumbnail(
                            url: item.checkInFotoUrl!,
                            label: isTerlambat ? 'Dokumentasi' : 'Check-in'),
                      if (item.checkInFotoUrl != null &&
                          item.checkInFotoUrl!.isNotEmpty &&
                          item.checkOutFotoUrl != null &&
                          item.checkOutFotoUrl!.isNotEmpty &&
                          !isTerlambat)
                        const SizedBox(width: 8),
                      if (item.checkOutFotoUrl != null &&
                          item.checkOutFotoUrl!.isNotEmpty &&
                          !isTerlambat)
                        _buildFotoThumbnail(
                            url: item.checkOutFotoUrl!, label: 'Check-out'),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTidakLemburCardSection(AbsensiHistoryItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_rounded, size: 14, color: Colors.red),
              const SizedBox(width: 6),
              Text(
                'Tidak Melakukan Lembur',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.access_time, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Dikonfirmasi: ${item.confirmedAtFormatted ?? '-'}',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.description_outlined,
                  size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Alasan: ${item.alasanTidakLembur ?? item.catatan ?? '-'}',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTerlambatCardSection(AbsensiHistoryItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 14, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                'Lembur Terlambat',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700),
              ),
              const Spacer(),
              Text(
                'Tanpa check-in/out',
                style: GoogleFonts.poppins(
                    fontSize: 8,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (item.keterlambatanAlasan.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.description_outlined,
                    size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Alasan: ${item.keterlambatanAlasan}',
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFotoThumbnail({required String url, required String label}) {
    return GestureDetector(
      onTap: () => _showFullImage(url, label),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                      color: Colors.grey[200],
                      child: const Icon(
                          Icons.image, size: 20, color: Colors.grey)),
                  errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image,
                          size: 20, color: Colors.grey))),
              Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      color: Colors.black54,
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 7, color: Colors.white)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String title, subtitle;
    IconData icon;

    if (_canSeeAll) {
      title = 'Belum ada data absensi yang disetujui';
      subtitle =
          'Data absensi lembur akan muncul di sini\nsetelah lembur disetujui dan mitra melakukan check-in';
      icon = Icons.people_outline;
    } else {
      title = 'Belum ada riwayat absensi';
      subtitle =
          'Riwayat absensi lembur akan muncul di sini\nsetelah lembur disetujui dan kamu melakukan check-in';
      icon = Icons.history;
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.grey[100], shape: BoxShape.circle),
                  child: Icon(icon, size: 60, color: Colors.grey[400])),
              const SizedBox(height: 16),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text('Gagal memuat data',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(error,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey[500]),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: () {
                  _loadSummary();
                  setState(() {});
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final months = <Map<String, String>>[];
        final now = DateTime.now();
        for (int i = 0; i < 12; i++) {
          final date = DateTime(now.year, now.month - i, 1);
          months.add({
            'value': DateFormat('yyyy-MM').format(date),
            'label': DateFormat('MMMM yyyy', 'id_ID').format(date)
          });
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pilih Bulan',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: months.map((m) {
                  final isSelected = _selectedBulan == m['value'];
                  return ChoiceChip(
                    selected: isSelected,
                    label: Text(m['label']!,
                        style: GoogleFonts.poppins(fontSize: 12)),
                    selectedColor: Colors.blue[100],
                    onSelected: (selected) {
                      setState(() {
                        _selectedBulan =
                            selected ? m['value']! : 'semua';
                        _showAllMonths = !selected;
                      });
                      Navigator.pop(ctx);
                      _loadSummary();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showDetailSheet(AbsensiHistoryItem item) {
    final bool showDurasiPendapatan =
        item.absensiStatus == 'selesai' || item.absensiStatus == 'selesai_terlambat';
    final bool isTerlambat = _isTerlambat(item.absensiStatus);
    final bool isTidakLembur = _isTidakLembur(item.absensiStatus);
    final bool isSelesaiNormal = _isSelesaiNormal(item.absensiStatus);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),

                  // Nama Mitra (untuk admin)
                  if (_canSeeAll && item.mitraNama != null) ...[
                    Text(item.mitraNama!,
                        style: GoogleFonts.poppins(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                  ],

                  // Tanggal
                  Text(item.tanggalFormatted,
                      style: GoogleFonts.poppins(
                          fontSize: _canSeeAll ? 16 : 18,
                          fontWeight:
                              _canSeeAll ? FontWeight.w500 : FontWeight.w700)),
                  const SizedBox(height: 16),

                  // Status Absensi
                  _buildDetailRow(
                      'Status', item.absensiLabel, item.statusColor),
                  const SizedBox(height: 12),

                  // 🔥🔥🔥 TIDAK LEMBUR SECTION
                  if (isTidakLembur) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cancel_rounded,
                                  size: 16, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                'Tidak Melakukan Lembur',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                              'Dikonfirmasi',
                              item.confirmedAtFormatted ?? '-',
                              Colors.grey.shade700),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                              'Alasan',
                              item.alasanTidakLembur ??
                                  item.catatan ??
                                  '-',
                              Colors.grey.shade800),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 🔥🔥🔥 TERLAMBAT SECTION - TANPA CHECK-IN/OUT
                  if (isTerlambat) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lembur Terlambat',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange.shade700),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'Tanpa check-in/out',
                                  style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Alasan Keterlambatan
                          if (item.keterlambatanAlasan.isNotEmpty) ...[
                            _buildDetailRow(
                                'Alasan Keterlambatan',
                                item.keterlambatanAlasan,
                                Colors.orange.shade800),
                            const SizedBox(height: 8),
                          ],

                          // Melakukan Lembur?
                          _buildDetailRow(
                              'Melakukan Lembur',
                              item.keterlambatanMelakukanLembur
                                  ? 'Ya, tetap lembur'
                                  : 'Tidak',
                              item.keterlambatanMelakukanLembur
                                  ? Colors.green
                                  : Colors.red),
                          const SizedBox(height: 8),

                          // Waktu Konfirmasi
                          if (item.confirmedAtFormatted != null &&
                              item.confirmedAtFormatted!.isNotEmpty)
                            _buildDetailRow(
                                'Dikonfirmasi Pada',
                                item.confirmedAtFormatted!,
                                Colors.grey.shade600),

                          // Dokumentasi (jika ada)
                          if (item.checkInFotoUrl != null &&
                              item.checkInFotoUrl!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              '📸 Dokumentasi Kerja:',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _showFullImage(
                                  item.checkInFotoUrl!, 'Dokumentasi Kerja'),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: item.checkInFotoUrl!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                      height: 200,
                                      color: Colors.grey[200],
                                      child: const Center(
                                          child:
                                              CircularProgressIndicator())),
                                  errorWidget: (_, __, ___) => Container(
                                      height: 200,
                                      color: Colors.grey[200],
                                      child: const Center(
                                          child: Icon(Icons.broken_image,
                                              size: 48))),
                                ),
                              ),
                            ),
                          ],

                          // Catatan tambahan
                          if (item.catatan != null &&
                              item.catatan!.isNotEmpty &&
                              item.catatan != item.keterlambatanAlasan) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow(
                                'Catatan', item.catatan!, Colors.grey[600]!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Status Lembur
                  if (item.statusLembur != null)
                    _buildDetailRow('Status Lembur', item.statusLembur!,
                        Colors.blueGrey),
                  const SizedBox(height: 12),

                  // Jadwal Lembur
                  _buildDetailRow(
                      'Jadwal Lembur', item.jamFormatted, Colors.blue),
                  const SizedBox(height: 12),

                  // Lokasi
                  if (item.lokasi != null && item.lokasi!.isNotEmpty)
                    _buildDetailRow(
                        'Lokasi', item.lokasi!, Colors.grey[700]!),
                  const SizedBox(height: 12),

                  // 🔥🔥🔥 CHECK-IN & CHECK-OUT - HANYA UNTUK SELESAI NORMAL
                  // Tidak ditampilkan untuk lembur terlambat dan tidak lembur
                  if (isSelesaiNormal) ...[
                    // Check In
                    _buildDetailRow(
                        'Check In',
                        item.hasCheckIn
                            ? item.checkInTanggalFormatted
                            : 'Belum Check-in',
                        item.hasCheckIn ? Colors.green : Colors.grey),
                    if (item.checkInFotoUrl != null &&
                        item.checkInFotoUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        child: GestureDetector(
                          onTap: () => _showFullImage(
                              item.checkInFotoUrl!, 'Foto Check-in'),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                  imageUrl: item.checkInFotoUrl!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                      height: 200,
                                      color: Colors.grey[200],
                                      child: const Center(
                                          child:
                                              CircularProgressIndicator())),
                                  errorWidget: (_, __, ___) => Container(
                                      height: 200,
                                      color: Colors.grey[200],
                                      child: const Center(
                                          child: Icon(Icons.broken_image,
                                              size: 48))))),
                        ),
                      ),

                    // Check Out
                    _buildDetailRow(
                        'Check Out',
                        item.hasCheckOut
                            ? item.checkOutTanggalFormatted
                            : 'Belum Check-out',
                        item.hasCheckOut ? Colors.red : Colors.grey),
                    if (item.checkOutFotoUrl != null &&
                        item.checkOutFotoUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        child: GestureDetector(
                          onTap: () => _showFullImage(
                              item.checkOutFotoUrl!, 'Foto Check-out'),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                  imageUrl: item.checkOutFotoUrl!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                      height: 200,
                                      color: Colors.grey[200],
                                      child: const Center(
                                          child:
                                              CircularProgressIndicator())),
                                  errorWidget: (_, __, ___) => Container(
                                      height: 200,
                                      color: Colors.grey[200],
                                      child: const Center(
                                          child: Icon(Icons.broken_image,
                                              size: 48))))),
                        ),
                      ),
                  ],

                  const Divider(height: 24),

                  // 🔥🔥🔥 DURASI & PENDAPATAN - HANYA UNTUK SELESAI & TERLAMBAT
                  if (showDurasiPendapatan && item.totalJam > 0) ...[
                    // Total Durasi
                    _buildDetailRow('Total Durasi',
                        item.durasiRealFormatted, Colors.blue[700]!),
                    const SizedBox(height: 12),

                    // Pendapatan
                    if (item.pendapatan > 0)
                      _buildDetailRow('Pendapatan',
                          item.pendapatanFormatted, Colors.green[700]!),
                    const SizedBox(height: 12),
                  ],

                  // Status Pembayaran
                  _buildDetailRow('Pembayaran', item.statusBayarLabel,
                      item.statusBayarColor),

                  // 🔥🔥🔥 INFO TERLAMBAT TAMBAHAN (DITAMPILKAN TERPISAH)
                  if (isTerlambat) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lembur terlambat tidak menggunakan sistem '
                              'check-in/check-out. Data durasi dan pendapatan '
                              'berdasarkan konfirmasi pengawas.',
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.orange.shade800,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 110,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey[600]))),
        Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color))),
      ],
    );
  }

  void _showFullImage(String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white)),
                      errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image,
                              size: 48, color: Colors.white)))),
              Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(title,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)))),
              Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx))),
            ],
          ),
        );
      },
    );
  }

  void _toggleBulanFilter() {
    setState(() {
      _showAllMonths = !_showAllMonths;
      _selectedBulan = _showAllMonths
          ? 'semua'
          : DateFormat('yyyy-MM').format(DateTime.now());
    });
    _loadSummary();
  }

  void _resetBulanFilter() {
    setState(() {
      _showAllMonths = true;
      _selectedBulan = 'semua';
    });
    _loadSummary();
  }

  String _getBulanLabel(String yyyyMM) {
    try {
      return DateFormat('MMMM yyyy', 'id_ID')
          .format(DateFormat('yyyy-MM').parse(yyyyMM));
    } catch (_) {
      return yyyyMM;
    }
  }
}