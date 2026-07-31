// lib/features/overtime_history/overtime_history_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';
import '/widgets/overtime_history/overtime_stats_card.dart';
import '/widgets/overtime_history/overtime_filter_chips.dart';
import '/widgets/overtime_history/overtime_list_view.dart';
import '/widgets/overtime_history/month_picker_sheet.dart';
import '/widgets/bottom_nav/app_bottom_nav.dart';

/// ============================================================================
class OvertimeHistoryScreen extends StatefulWidget {
  const OvertimeHistoryScreen({super.key});

  @override
  State<OvertimeHistoryScreen> createState() => _OvertimeHistoryScreenState();
}

class _OvertimeHistoryScreenState extends State<OvertimeHistoryScreen> {
  // ─────────────────────────────────────────────────────────────────────────
  // SERVICES & DATA
  // ─────────────────────────────────────────────────────────────────────────
  final OvertimeHistoryService _historyService = OvertimeHistoryService();
  final OvertimeRateService _rateService = OvertimeRateService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  String? _userRole;
  String? _userFungsi;
  String? _userId;
  String? _userName;

  // ─────────────────────────────────────────────────────────────────────────
  // FILTERS
  // ─────────────────────────────────────────────────────────────────────────
  String _selectedBulan = 'semua';
  String _selectedStatus = 'semua';
  bool _showAllMonths = true;

  // ─────────────────────────────────────────────────────────────────────────
  // HSSE MODE (untuk HSSE Staff & HSSE Manager)
  // ─────────────────────────────────────────────────────────────────────────
  HSSEViewMode _hsseViewMode = HSSEViewMode.all;

  // ─────────────────────────────────────────────────────────────────────────
  // LOADING
  // ─────────────────────────────────────────────────────────────────────────
  bool _isLoading = true;

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────
  
  /// Cek apakah user adalah Manager HSSE
  bool get _isHSSEManager => _userRole == 'manager' && _userFungsi == 'hsse';
  
  /// Cek apakah user adalah HSSE (Staff atau Manager)
  bool get _isHSSE => _userFungsi == 'hsse';
  
  /// Cek apakah user adalah Pengawas (satu-satunya yang boleh membatalkan)
  bool get _isPengawas => _userRole == 'pengawas';

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOAD USER DATA
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    _userId = user.uid;
    _userName = user.displayName ?? user.email?.split('@').first ?? 'User';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        setState(() {
          _userRole = data?['role'] ?? 'mitra';
          _userFungsi = data?['fungsi']?.toString().toLowerCase();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BATALKAN PENGAJUAN (HANYA PENGAWAS)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _batalkanPengajuan(String documentId) async {
    // Validasi: Hanya pengawas yang boleh membatalkan
    if (!_isPengawas) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hanya pengawas yang dapat membatalkan pengajuan',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Batalkan Pengajuan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Apakah Anda yakin ingin membatalkan pengajuan lembur ini?\n\n'
          'Pengajuan yang dibatalkan tidak dapat dikembalikan.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Tidak',
                style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Ya, Batalkan',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final result = await _historyService.batalkanPengajuan(
      documentId: documentId,
      userId: _userId!,
    );

    if (mounted) Navigator.of(context).pop();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result['success'] == true
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result['message'] ?? 'Berhasil',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor:
            result['success'] == true ? Colors.green[600] : Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );

    if (result['success'] == true) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F9FF),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3C72),
          title: Text('Riwayat Lembur',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF1976D2))),
      );
    }

    final primaryColor = _isHSSE
        ? const Color(0xFFB71C1C)
        : const Color(0xFF1E3C72);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: _buildAppBar(primaryColor),
      bottomNavigationBar: _userRole != null
          ? AppBottomNav(userRole: _userRole!, currentIndex: _getNavIndex())
          : null,
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        color: primaryColor,
        child: _buildBody(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(Color primaryColor) {
    return AppBar(
      title: Text(
        _getTitle(),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17),
      ),
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      actions: [
        // HSSE Mode Selector (untuk HSSE Staff & HSSE Manager)
        if (_isHSSE) _buildHSSEModeSelector(),

        // Filter Bulan
        IconButton(
          icon: Icon(
            _showAllMonths ? Icons.filter_list_off : Icons.filter_list,
            size: 20,
          ),
          onPressed: _toggleBulanFilter,
          tooltip: _showAllMonths ? 'Filter per Bulan' : 'Tampilkan Semua',
        ),

        // Month Picker
        if (!_showAllMonths)
          IconButton(
            icon: const Icon(Icons.calendar_month, size: 20),
            onPressed: () => MonthPickerSheet.show(
              context,
              selectedMonth: _selectedBulan,
              onMonthSelected: (month) =>
                  setState(() => _selectedBulan = month),
            ),
            tooltip: 'Pilih Bulan',
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HSSE MODE SELECTOR (PopupMenu) - UNTUK HSSE STAFF & HSSE MANAGER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHSSEModeSelector() {
    return PopupMenuButton<HSSEViewMode>(
      icon: Icon(_getHSSEIcon(), color: Colors.white, size: 22),
      tooltip: 'Filter Tampilan HSSE',
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (mode) => setState(() {
        _hsseViewMode = mode;
        _selectedStatus = 'semua';
      }),
      itemBuilder: (ctx) => [
        _buildHSSEMenuItem(
          HSSEViewMode.all,
          Icons.list_alt,
          Colors.blue,
          'Semua Pengajuan Berisiko',
          'Rekapan semua pengajuan berisiko',
        ),
        const PopupMenuDivider(height: 1),
        _buildHSSEMenuItem(
          HSSEViewMode.needApproval,
          Icons.warning_amber_rounded,
          Colors.orange,
          'Menunggu Persetujuan',
          'Pengajuan yang belum diproses',
        ),
        const PopupMenuDivider(height: 1),
        _buildHSSEMenuItem(
          HSSEViewMode.myHistory,
          Icons.history,
          Colors.green,
          'Riwayat Persetujuan Saya',
          'Rekapan yang sudah Anda setujui/tolak',
        ),
      ],
    );
  }

  PopupMenuItem<HSSEViewMode> _buildHSSEMenuItem(
    HSSEViewMode mode,
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) {
    final isSelected = _hsseViewMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.black87 : Colors.grey[800],
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(Icons.check_circle, size: 18, color: color),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BODY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Indikator Bulan
        SliverToBoxAdapter(child: _buildBulanIndicator()),

        // HSSE Mode Banner
        if (_isHSSE) SliverToBoxAdapter(child: _buildHSSEModeBanner()),

        // Stats Card
        SliverToBoxAdapter(
          child: OvertimeStatsCard(
            historyService: _historyService,
            userRole: _userRole ?? 'mitra',
            userFungsi: _userFungsi,
            userId: _userId,
            selectedBulan: _showAllMonths ? '' : _selectedBulan,
          ),
        ),

        // Pending Info Banner (HSSE)
        if (_isHSSE && _hsseViewMode == HSSEViewMode.needApproval)
          SliverToBoxAdapter(child: _buildPendingInfoBanner()),

        // Filter Chips
        SliverToBoxAdapter(
          child: OvertimeFilterChips(
            selectedStatus: _selectedStatus,
            onStatusChanged: (status) =>
                setState(() => _selectedStatus = status),
          ),
        ),

        // List Content
        SliverFillRemaining(
          hasScrollBody: true,
          child: _buildList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD LIST (berdasarkan role & mode) - FINAL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildList() {
    // Helper: fungsi batalkan hanya tersedia untuk pengawas
    final batalkanCallback = _isPengawas ? _batalkanPengajuan : null;

    // ── KHUSUS HSSE MANAGER ──
    if (_isHSSEManager) {
      // Mode 1: Semua Pengajuan Berisiko
      if (_hsseViewMode == HSSEViewMode.all) {
        return OvertimeListView(
          historyService: _historyService,
          rateService: _rateService,
          userRole: _userRole!,
          userFungsi: _userFungsi,
          userId: _userId,
          userName: _userName,
          selectedBulan: _showAllMonths ? '' : _selectedBulan,
          selectedStatus: _selectedStatus,
          onBatalkanPengajuan: null, // HSSE tidak membatalkan
          showRiskyOnly: true,
          showHSSEStatus: true,
          showApprovalActions: false,
        );
      }
      
      // Mode 2: Menunggu Persetujuan
      if (_hsseViewMode == HSSEViewMode.needApproval) {
        return OvertimeListView(
          historyService: _historyService,
          rateService: _rateService,
          userRole: _userRole!,
          userFungsi: _userFungsi,
          userId: _userId,
          userName: _userName,
          selectedBulan: _showAllMonths ? '' : _selectedBulan,
          selectedStatus: _selectedStatus,
          onBatalkanPengajuan: null, // HSSE tidak membatalkan
          showRiskyOnly: true,
          showHSSEStatus: true,
          showApprovalActions: false,
          selectedHSSEStatus: 'pending',
        );
      }
      
      // Mode 3: Riwayat Persetujuan Saya
      if (_hsseViewMode == HSSEViewMode.myHistory) {
        return _buildStreamList(
          stream: _historyService.getHSSEApprovedByMeStream(
            hsseUserId: _userId!,
            bulan: _showAllMonths ? null : _selectedBulan,
            statusFilter: _selectedStatus != 'semua' ? _selectedStatus : null,
          ),
          emptyIcon: Icons.history,
          emptyTitle: 'Belum ada riwayat persetujuan',
          emptySubtitle: 'Pengajuan berisiko yang Anda setujui/tolak akan muncul di sini\nsebagai rekapan beban kerja Anda',
          showRekapCard: true,
        );
      }
    }

    // ── HSSE Staff Mode 3: Riwayat Persetujuan Saya ──
    if (_isHSSE && _hsseViewMode == HSSEViewMode.myHistory) {
      return _buildStreamList(
        stream: _historyService.getHSSEApprovalHistoryStream(
          hsseUserId: _userId!,
          bulan: _showAllMonths ? null : _selectedBulan,
          hsseStatus: _selectedStatus != 'semua' ? _selectedStatus : null,
        ),
        emptyIcon: Icons.history,
        emptyTitle: 'Belum ada riwayat persetujuan',
        emptySubtitle:
            'Pengajuan yang Anda setujui/tolak akan muncul di sini\nsebagai rekapan beban kerja Anda',
        showRekapCard: true,
      );
    }

    // ── HSSE Staff Mode 2: Menunggu Persetujuan ──
    if (_isHSSE && _hsseViewMode == HSSEViewMode.needApproval) {
      return _buildStreamList(
        stream: _historyService.getHSSERiskyOvertimeStream(
          bulan: _showAllMonths ? null : _selectedBulan,
          statusFilter: _selectedStatus != 'semua' ? _selectedStatus : null,
          hsseStatus: 'pending',
        ),
        emptyIcon: Icons.check_circle_outline,
        emptyTitle: 'Tidak ada pengajuan menunggu',
        emptySubtitle:
            'Semua pengajuan berisiko sudah diproses.\nGunakan menu Approval untuk melihat detail.',
      );
    }

    // ── HSSE Staff Mode 1: Semua Pengajuan Berisiko ──
    if (_isHSSE && _hsseViewMode == HSSEViewMode.all) {
      return _buildStreamList(
        stream: _historyService.getHSSERiskyOvertimeStream(
          bulan: _showAllMonths ? null : _selectedBulan,
          statusFilter: _selectedStatus != 'semua' ? _selectedStatus : null,
          hsseUserId: _userId,
        ),
        emptyIcon: Icons.inbox_outlined,
        emptyTitle: 'Tidak ada pengajuan berisiko',
        emptySubtitle: '',
      );
    }

    // ── Non-HSSE: Tampilan Normal (Mitra, Pengawas, Manager, Superadmin) ──
    return OvertimeListView(
      historyService: _historyService,
      rateService: _rateService,
      userRole: _userRole!,
      userFungsi: _userFungsi,
      userId: _userId,
      userName: _userName,
      selectedBulan: _showAllMonths ? '' : _selectedBulan,
      selectedStatus: _selectedStatus,
      onBatalkanPengajuan: batalkanCallback, // null jika bukan pengawas
      showRiskyOnly: false,
    );
  }

  /// Widget builder untuk StreamBuilder list (menghindari duplikasi kode)
  Widget _buildStreamList({
    required Stream<List<OvertimeHistory>> stream,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    bool showRekapCard = false,
  }) {
    return StreamBuilder<List<OvertimeHistory>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Gagal memuat data',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.red[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${snapshot.error}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? [];

        if (data.isEmpty) {
          return _buildEmptyState(emptyIcon, emptyTitle, emptySubtitle);
        }

        // Rekap Card (untuk mode myHistory)
        if (showRekapCard) {
          final approved =
              data.where((i) => i.hsseStatus == 'disetujui').length;
          final rejected =
              data.where((i) => i.hsseStatus == 'ditolak').length;
          final revisi = data
              .where((i) =>
                  i.hsseStatus == 'perlu_revisi' ||
                  i.hsseStatus == 'dalam_review')
              .length;

          return Column(
            children: [
              _buildHSSERekapCard(
                approved: approved,
                rejected: rejected,
                revisi: revisi,
                total: data.length,
              ),
              Expanded(
                child: OvertimeListView(
                  historyService: _historyService,
                  rateService: _rateService,
                  userRole: _userRole!,
                  userFungsi: _userFungsi,
                  userId: _userId,
                  userName: _userName,
                  selectedBulan: _showAllMonths ? '' : _selectedBulan,
                  selectedStatus: _selectedStatus,
                  onBatalkanPengajuan: null, // HSSE myHistory tidak membatalkan
                  showRiskyOnly: true,
                  hssData: data,
                  showHSSEStatus: true,
                  showApprovalActions: false,
                ),
              ),
            ],
          );
        }

        return OvertimeListView(
          historyService: _historyService,
          rateService: _rateService,
          userRole: _userRole!,
          userFungsi: _userFungsi,
          userId: _userId,
          userName: _userName,
          selectedBulan: _showAllMonths ? '' : _selectedBulan,
          selectedStatus: _selectedStatus,
          onBatalkanPengajuan: null, // HSSE mode tidak membatalkan
          showRiskyOnly: true,
          hssData: data,
          showHSSEStatus: true,
          showApprovalActions: false,
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: EMPTY STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: HSSE REKAP CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHSSERekapCard({
    required int approved,
    required int rejected,
    required int revisi,
    required int total,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRekapItem('Disetujui', approved, Colors.green, Icons.check_circle),
          _buildDivider(),
          _buildRekapItem('Ditolak', rejected, Colors.red, Icons.cancel),
          _buildDivider(),
          _buildRekapItem('Revisi', revisi, Colors.orange, Icons.edit_note),
          _buildDivider(),
          _buildRekapItem('Total', total, Colors.blue, Icons.list_alt),
        ],
      ),
    );
  }

  Widget _buildRekapItem(
      String label, int count, Color color, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: Colors.grey[200]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: BULAN INDICATOR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBulanIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            color: _showAllMonths ? Colors.green[700] : Colors.blue[700],
          ),
          const SizedBox(width: 8),
          Text(
            _showAllMonths
                ? 'Menampilkan: Semua Bulan'
                : 'Bulan: ${_getBulanLabel(_selectedBulan)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _showAllMonths ? Colors.green[700] : Colors.blue[700],
            ),
          ),
          const Spacer(),
          if (!_showAllMonths)
            TextButton(
              onPressed: _resetBulanFilter,
              child: Text(
                'Lihat Semua',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.blue[700]),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: HSSE MODE BANNER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHSSEModeBanner() {
    final config = _getHSSEModeConfig();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: config.bg,
      child: Row(
        children: [
          Icon(config.icon, color: config.ic, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  config.title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: config.tc,
                  ),
                ),
                Text(
                  config.subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: config.tc.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: PENDING INFO BANNER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPendingInfoBanner() {
    return StreamBuilder<List<OvertimeHistory>>(
      stream:
          _historyService.getHSSERiskyOvertimeStream(hsseStatus: 'pending'),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final count = snap.data!.length;
        final kritis =
            snap.data!.where((i) => i.risikoLevel == 'kritis').length;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kritis > 0
                ? const Color(0xFFFFEBEE)
                : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: kritis > 0 ? Colors.red[300]! : Colors.orange[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: kritis > 0 ? Colors.red : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '📌 Terdapat $count pengajuan menunggu persetujuan'
                  '${kritis > 0 ? ' (termasuk $kritis kritis!)' : ''}. '
                  'Buka menu Approval untuk memproses.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: kritis > 0 ? Colors.red[900] : Colors.orange[900],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleBulanFilter() {
    setState(() {
      _showAllMonths = !_showAllMonths;
      _selectedBulan = _showAllMonths
          ? 'semua'
          : DateFormat('yyyy-MM').format(DateTime.now());
    });
  }

  void _resetBulanFilter() {
    setState(() {
      _showAllMonths = true;
      _selectedBulan = 'semua';
    });
  }

  IconData _getHSSEIcon() {
    switch (_hsseViewMode) {
      case HSSEViewMode.all:
        return Icons.list_alt;
      case HSSEViewMode.needApproval:
        return Icons.warning_amber_rounded;
      case HSSEViewMode.myHistory:
        return Icons.history;
    }
  }

  _HSSEModeConfig _getHSSEModeConfig() {
    switch (_hsseViewMode) {
      case HSSEViewMode.all:
        return _HSSEModeConfig(
          title: '📋 Rekap Semua Pengajuan Berisiko',
          subtitle: 'Melihat rekapan pengajuan lembur berisiko',
          icon: Icons.list_alt,
          bg: const Color(0xFFE3F2FD),
          tc: const Color(0xFF1565C0),
          ic: const Color(0xFF1976D2),
        );
      case HSSEViewMode.needApproval:
        return _HSSEModeConfig(
          title: '⏳ Menunggu Persetujuan',
          subtitle:
              'Pengajuan yang belum diproses (buka menu Approval untuk menyetujui)',
          icon: Icons.warning_amber_rounded,
          bg: const Color(0xFFFFF3E0),
          tc: const Color(0xFFE65100),
          ic: Colors.orange,
        );
      case HSSEViewMode.myHistory:
        return _HSSEModeConfig(
          title: '📝 Riwayat Persetujuan Saya',
          subtitle: 'Rekapan pengajuan yang sudah Anda proses',
          icon: Icons.history,
          bg: const Color(0xFFE8F5E9),
          tc: const Color(0xFF2E7D32),
          ic: Colors.green,
        );
    }
  }

  int _getNavIndex() {
    return 1;
  }

  String _getTitle() {
    if (_isHSSEManager) {
      switch (_hsseViewMode) {
        case HSSEViewMode.all:
          return '📋 Rekap Pengajuan Berisiko';
        case HSSEViewMode.needApproval:
          return '⏳ Menunggu Persetujuan';
        case HSSEViewMode.myHistory:
          return '📝 Riwayat Persetujuan Saya';
      }
    }
    
    if (_isHSSE) {
      switch (_hsseViewMode) {
        case HSSEViewMode.all:
          return 'Rekap Pengajuan Berisiko';
        case HSSEViewMode.needApproval:
          return 'Menunggu Persetujuan';
        case HSSEViewMode.myHistory:
          return 'Riwayat Persetujuan Saya';
      }
    }
    switch (_userRole) {
      case 'superadmin':
      case 'manager':
        return 'Riwayat Lembur';
      case 'pengawas':
        return 'Pengajuan Saya';
      case 'mitra':
        return 'Lembur Saya';
      default:
        return 'Riwayat Lembur';
    }
  }

  String _getBulanLabel(String tb) {
    try {
      return DateFormat('MMMM yyyy', 'id_ID')
          .format(DateFormat('yyyy-MM').parse(tb));
    } catch (_) {
      return tb;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER CLASS: Konfigurasi banner HSSE
// ─────────────────────────────────────────────────────────────────────────────
class _HSSEModeConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bg;
  final Color tc;
  final Color ic;

  const _HSSEModeConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bg,
    required this.tc,
    required this.ic,
  });
}