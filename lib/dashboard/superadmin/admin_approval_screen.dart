// lib/dashboard/manager/approval_lembur_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import '/core/services/overtime_approval_service.dart';
import '/core/services/overtime_rate_service.dart';

import '../../widgets/approval/approval_detail_bottom_sheet.dart';
import '../../widgets/approval/approval_dialogs.dart';
import '../../widgets/approval/approval_list_builder.dart';
import '../../widgets/approval/hsse_pending_list.dart';
import '../../widgets/approval/risk_checklist_dialog.dart';
import '../../widgets/approval/pending_approval_list.dart';
import '../../widgets/approval/risky_overtime_list.dart';
import '../../widgets/bottom_nav/manager_bottom_nav.dart';

class ApprovalLemburScreen extends StatefulWidget {
  final VoidCallback? onApprovalComplete;
  const ApprovalLemburScreen({super.key, this.onApprovalComplete});

  @override
  State<ApprovalLemburScreen> createState() =>
      _ApprovalLemburScreenState();
}

class _ApprovalLemburScreenState
    extends State<ApprovalLemburScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ==================== SERVICES ====================
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OvertimeApprovalService _approvalService = OvertimeApprovalService();
  final OvertimeRateService _rateService = OvertimeRateService(); // ignore: unused_field

  // ==================== CONTROLLERS & ANIMATIONS ====================
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ==================== STATE ====================
  bool _isLoading = true;
  String? _userId, _userRole, _userFungsi, _userName, _userEmail;
  String _searchQuery = '';
  Timer? _searchDebounce;
  String? _fungsiFilter;
  bool _isApproving = false;

  // ==================== STATISTICS ====================
  int _totalPending = 0, _totalApproved = 0, _totalRejected = 0, _totalPendingHSSE = 0;
  int _totalAllPending = 0;
  int _criticalCount = 0, _highCount = 0, _mediumCount = 0, _lowCount = 0;

  // ==================== BULK SELECTION ====================
  bool _isBulkMode = false;
  final Set<String> _selectedIds = {};
  bool _isSelectAll = false;
  List<Map<String, dynamic>> _allPendingData = [];

  // ==================== OPTIMIZATION ====================
  DateTime? _lastStatsLoad;
  StreamSubscription? _authSubscription;
  static final Map<String, Color> _fungsiColorCache = {};
  static final Map<String, String> _fungsiLabelCache = {};

  // ==================== ELEGANT THEME CONSTANTS ====================
  static const Color primaryDark = Color(0xFF0A1A3A);
  static const Color primaryMid = Color(0xFF0F2B5A);
  static const Color primaryBlue = Color(0xFF1A4F8A);
  static const Color accentBlue = Color(0xFF2D7DD2);
  static const Color lightBlue = Color(0xFF4A9BEA);
  static const Color goldAccent = Color(0xFFC9A84C);
  static const Color goldLight = Color(0xFFE8D5A3);
  static const Color hsseColor = Color(0xFF6B3FA0);
  static const Color backgroundColor = Color(0xFFF2F5F9);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color riskyColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);

  static const List<String> _hsseActionableStatuses = [
    OvertimeApprovalService.statusPendingHSSE,
    'manager_approval_pending_hsse',
    'manager_approved_pending_hsse',
  ];

  // ==================== GETTERS ====================
  bool get isSuperadmin => _userRole == 'superadmin';
  bool get isManager => _userRole == 'manager';
  bool get isHSSEManager =>
      _userRole == 'manager_hsse' ||
      (_userRole == 'manager' && _userFungsi == 'hsse');

  int get _tabCount => isHSSEManager ? 7 : 3;
  bool get isPendingTabActive => _tabController.index == (isHSSEManager ? 2 : 0);
  bool get isRiskyTabActive => isHSSEManager && _tabController.index == 0;
  bool get isHsseTabActive => isHSSEManager && _tabController.index == 1;

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initControllers();
    _listenAuthChanges();
    _initializeData();
  }

  void _initControllers() {
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _listenAuthChanges() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user == null && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _animationController.dispose();
    _pulseController.dispose();
    _searchDebounce?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadStatistics();
    }
  }

  // ==================== INITIALIZATION ====================
  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _loadUserData();
      if (_tabController.length != _tabCount) {
        _tabController.dispose();
        _tabController = TabController(length: _tabCount, vsync: this);
        _tabController.addListener(() {
          if (mounted) setState(() {});
        });
      }
      await _loadStatistics();
    } catch (e) {
      debugPrint('❌ Error initializing: $e');
      if (mounted) _showSnackbar('Gagal memuat data', isError: true);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    _userId = user.uid;
    _userEmail = user.email;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _userRole = data['role']?.toString().toLowerCase() ?? '';
        _userFungsi = data['fungsi']?.toString().toLowerCase() ?? '';
        _userName = data['nama_lengkap']?.toString() ?? user.email ?? 'User';
        debugPrint('👤 USER DATA LOADED: $_userName, role=$_userRole, fungsi=$_userFungsi');
      }
    } catch (e) {
      debugPrint('❌ Error loading user: $e');
      _userName = user.email ?? 'User';
    }
  }

  // LOAD STATISTICS
  Future<void> _loadStatistics() async {
    if (_lastStatsLoad != null &&
        DateTime.now().difference(_lastStatsLoad!) < const Duration(seconds: 2)) {
      return;
    }
    _lastStatsLoad = DateTime.now();

    try {
      Map<String, dynamic> stats;
      if (isSuperadmin) {
        stats = await _approvalService.getStatisticsForSuperadmin(
          fungsiFilter: _fungsiFilter,
        );
      } else if (isManager && _userFungsi != null) {
        stats = await _approvalService.getStatisticsForManager(_userFungsi!);
      } else if (isHSSEManager) {
        stats = await _approvalService.getStatisticsForHSSEManager(
          fungsiFilter: _fungsiFilter,
        );
      } else {
        return;
      }
      if (mounted) _updateStats(stats);
    } catch (e) {
      debugPrint('❌ Error loading statistics: $e');
    }
  }

  void _updateStats(Map<String, dynamic> stats) {
    if (!mounted) return;
    setState(() {
      _totalPending = stats['totalPending'] ?? 0;
      _totalPendingHSSE = stats['totalPendingHSSE'] ?? 0;
      _totalApproved = stats['totalApproved'] ?? 0;
      _totalRejected = stats['totalRejected'] ?? 0;
      _totalAllPending = stats['totalAllPending'] ?? (_totalPending + _totalPendingHSSE);
      if (isHSSEManager) {
        _criticalCount = stats['criticalCount'] ?? 0;
        _highCount = stats['highCount'] ?? 0;
        _mediumCount = stats['mediumCount'] ?? 0;
        _lowCount = stats['lowCount'] ?? 0;
      }
    });
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? _buildLoadingScreen()
          : Column(
              children: [
                _buildElegantHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadStatistics,
                    color: accentBlue,
                    displacement: 20,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildWelcomeCard()),
                        SliverToBoxAdapter(child: _buildStatsSummary()),
                        if (isHSSEManager && _totalAllPending > 0)
                          SliverToBoxAdapter(child: _buildHSSERiskSummaryCards()),
                        SliverToBoxAdapter(child: _buildSearchAndFilter()),
                        if (isSuperadmin || isHSSEManager)
                          SliverToBoxAdapter(child: _buildFungsiFilterRow()),
                        SliverToBoxAdapter(child: _buildElegantTabBar()),
                        if (isSuperadmin && _isBulkMode && isPendingTabActive && _selectedIds.isNotEmpty)
                          SliverToBoxAdapter(child: _buildBulkActionBar()),
                        SliverFillRemaining(
                          hasScrollBody: true,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: TabBarView(
                              controller: _tabController,
                              children: _buildTabViews(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const ManagerBottomNav(currentIndex: 1),
    );
  }

  // ELEGANT HEADER
  Widget _buildElegantHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHSSEManager
              ? [const Color(0xFF2D1B4E), const Color(0xFF4A2B7A)]
              : [primaryDark, primaryMid, primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isHSSEManager ? hsseColor : primaryDark).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ElegantHeaderPainter(
                color: Colors.white.withOpacity(0.02),
                accentColor: goldAccent.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            top: -50,
            right: -30,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentBlue.withOpacity(0.15),
                        accentBlue.withOpacity(0.03),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    goldAccent.withOpacity(0.08),
                    goldAccent.withOpacity(0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isHSSEManager ? Icons.shield_rounded : Icons.assignment_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHSSEManager ? 'Validasi K3' : 'Persetujuan Lembur',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        goldAccent.withOpacity(0.25),
                                        goldAccent.withOpacity(0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: goldAccent.withOpacity(0.3),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, color: goldAccent, size: 5),
                                      const SizedBox(width: 6),
                                      Text(
                                        isSuperadmin
                                            ? 'Superadmin'
                                            : isHSSEManager
                                                ? 'Manager HSSE'
                                                : _getFungsiLabel(_userFungsi),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: goldLight,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_totalAllPending > 0) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.3),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      '${_totalAllPending} menunggu',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange.shade200,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          _buildHeaderActionButton(
                            icon: Icons.refresh_rounded,
                            onPressed: () async {
                              await _loadStatistics();
                              _showSnackbar('Data diperbarui');
                            },
                          ),
                          if (isSuperadmin && _totalPending > 0 && !isHSSEManager) ...[
                            const SizedBox(height: 8),
                            _buildHeaderActionButton(
                              icon: _isBulkMode ? Icons.close : Icons.checklist_rtl,
                              onPressed: _toggleBulkMode,
                              isActive: _isBulkMode,
                              activeColor: Colors.orange,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
    Color activeColor = Colors.orange,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withOpacity(0.2)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? activeColor.withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? activeColor : Colors.white.withOpacity(0.7),
          size: 18,
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryDark.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: primaryDark.withOpacity(0.04), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentBlue, primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  (_userName ?? 'U').substring(0, 1).toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selamat Datang,', style: GoogleFonts.inter(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500)),
                  Text(_userName ?? 'Manager', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentBlue.withOpacity(0.1), width: 0.5),
              ),
              child: Text('Hari ini', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: accentBlue)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _buildStatCard('Disetujui', _totalApproved, Icons.check_circle_rounded, successColor),
          const SizedBox(width: 10),
          _buildStatCard('Ditolak', _totalRejected, Icons.cancel_rounded, errorColor),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.08), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                Text(label, style: GoogleFonts.inter(fontSize: 9, color: textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHSSERiskSummaryCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildRiskMiniCard('Critical', '🔴', const Color(0xFFDC2626), _criticalCount),
            _buildRiskMiniCard('High', '🟠', const Color(0xFFEF4444), _highCount),
            _buildRiskMiniCard('Medium', '🟡', const Color(0xFFF59E0B), _mediumCount),
            _buildRiskMiniCard('Low', '🟢', const Color(0xFF10B981), _lowCount),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskMiniCard(String label, String emoji, Color color, int count) {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 1),
          Text('$count', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 8, color: textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: TextField(
          onChanged: _onSearchChanged,
          style: GoogleFonts.inter(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            hintText: 'Cari pengawas, group ID...',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: textLight, fontWeight: FontWeight.w400),
            prefixIcon: Icon(Icons.search_rounded, color: textLight, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(icon: Icon(Icons.close_rounded, color: textLight, size: 18), onPressed: () => setState(() => _searchQuery = ''))
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildFungsiFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Semua', 'semua'),
            _buildFilterChip('Operation', 'operation'),
            _buildFilterChip('Maintenance', 'maintenance'),
            _buildFilterChip('HSSE', 'hsse'),
            _buildFilterChip('GPR', 'gpr'),
            _buildFilterChip('BS', 'bs'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = (_fungsiFilter == value) || (_fungsiFilter == null && value == 'semua');
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _onFungsiFilterChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? accentBlue : cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? accentBlue : Colors.grey.withOpacity(0.15), width: 0.5),
            boxShadow: isSelected
                ? [BoxShadow(color: accentBlue.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildElegantTabBar() {
    final List<_TabData> allTabs = [
      if (isHSSEManager)
        _TabData(icon: Icons.warning_rounded, label: 'Berisiko', badge: _totalAllPending > 0 ? '$_totalAllPending' : null, badgeColor: errorColor, color: errorColor),
      if (isHSSEManager)
        _TabData(icon: Icons.shield_rounded, label: 'K3', badge: _totalPendingHSSE > 0 ? '$_totalPendingHSSE' : null, badgeColor: hsseColor, color: hsseColor),
      _TabData(icon: Icons.hourglass_top_rounded, label: 'Pending', badge: _totalPending > 0 ? '$_totalPending' : null, badgeColor: warningColor, color: warningColor),
      if (isHSSEManager)
        _TabData(icon: Icons.verified_rounded, label: 'K3 Setuju', badge: null, badgeColor: successColor, color: successColor),
      if (isHSSEManager)
        _TabData(icon: Icons.gpp_bad_rounded, label: 'K3 Tolak', badge: null, badgeColor: errorColor, color: errorColor),
      _TabData(icon: Icons.check_circle_rounded, label: 'Setuju', badge: _totalApproved > 0 ? '$_totalApproved' : null, badgeColor: successColor, color: successColor),
      _TabData(icon: Icons.cancel_rounded, label: 'Tolak', badge: _totalRejected > 0 ? '$_totalRejected' : null, badgeColor: errorColor, color: errorColor),
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: primaryDark.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: [accentBlue, primaryBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: accentBlue.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: textSecondary,
        labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        padding: const EdgeInsets.all(4),
        tabs: allTabs.map((tab) {
          final isActive = allTabs.indexOf(tab) == _tabController.index;
          return Tab(
            height: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 14, color: isActive ? Colors.white : tab.color.withOpacity(0.7)),
                  const SizedBox(width: 5),
                  Text(tab.label),
                  if (tab.badge != null && !isActive) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: tab.badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(tab.badge!, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: tab.badgeColor)),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildTabViews() {
    final role = _userRole ?? 'manager';

    if (isHSSEManager) {
      return [
        RiskyOvertimeList(searchQuery: _searchQuery, fungsiFilter: _fungsiFilter, isDarkMode: false, onTap: _showDetail, onHSSEReview: (groupId) => _onHSSEReviewRequested(groupId)),
        HSSEPendingList(searchQuery: _searchQuery, fungsiFilter: _fungsiFilter, isDarkMode: false, onTap: _showDetail, onHSSEApprove: (groupId) => _onHSSEReviewRequested(groupId), onHSSEReject: (groupId) => _onHSSERejectRequested(groupId)),
        PendingApprovalList(isSuperadmin: false, fungsiFilterSuperadmin: _fungsiFilter, userFungsi: _userFungsi, userRole: _userRole, isHSSEManagerMode: true, searchQuery: _searchQuery, isBulkMode: false, selectedIds: _selectedIds, onShowDetail: _showDetail, onSelectionChanged: _onSelectionChanged, onDataLoaded: (data) => _allPendingData = data),
        ApprovalListBuilder(status: 'disetujui', userRole: role, userFungsi: null, fungsiFilter: _fungsiFilter, searchQuery: _searchQuery, isDarkMode: false, onTap: _showDetail, isHSSETab: true),
        ApprovalListBuilder(status: 'ditolak', userRole: role, userFungsi: null, fungsiFilter: _fungsiFilter, searchQuery: _searchQuery, isDarkMode: false, onTap: _showDetail, isHSSETab: true),
        ApprovalListBuilder(status: 'disetujui', userRole: role, userFungsi: null, fungsiFilter: _fungsiFilter, searchQuery: _searchQuery, isDarkMode: false, onTap: _showDetail),
        ApprovalListBuilder(status: 'ditolak', userRole: role, userFungsi: null, fungsiFilter: _fungsiFilter, searchQuery: _searchQuery, isDarkMode: false, onTap: _showDetail),
      ];
    } else {
      return [
        PendingApprovalList(isSuperadmin: isSuperadmin, fungsiFilterSuperadmin: _fungsiFilter, userFungsi: _userFungsi, userRole: _userRole, isHSSEManagerMode: false, searchQuery: _searchQuery, isBulkMode: _isBulkMode, selectedIds: _selectedIds, onShowDetail: _showDetail, onSelectionChanged: _onSelectionChanged, onDataLoaded: (data) => _allPendingData = data),
        ApprovalListBuilder(status: 'disetujui', userRole: role, userFungsi: _userFungsi, fungsiFilter: _fungsiFilter, searchQuery: _searchQuery, isDarkMode: false, onTap: _showDetail),
        ApprovalListBuilder(status: 'ditolak', userRole: role, userFungsi: _userFungsi, fungsiFilter: _fungsiFilter, searchQuery: _searchQuery, isDarkMode: false, onTap: _showDetail),
      ];
    }
  }

  // ===================================================================
  // ✅ _showDetail — DIPERBAIKI TOTAL (FIX POP-UP BERISIKO)
  // ===================================================================
  Future<void> _showDetail(String groupId) async {
    final detail = await _approvalService.getDetailPengajuan(groupId);
    if (detail == null || !mounted) return;

    final mitraList = (detail['mitra_list'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final hasSpkl = detail['spkl_pdf_path'] != null;
    final status = detail['status']?.toString() ?? '';
    final isPendingHSSE = status.contains('pending_hsse');
    final requiresHsseApproval = detail['requires_hsse_approval'] == true;
    final needHsseConfirmation = detail['need_hsse_confirmation'] == true;

    // ✅ Ambil risk level & urgensi
    final riskLevel = detail['risk_level']?.toString().toLowerCase() ?? '';
    final urgensi = detail['urgensi']?.toString().toLowerCase() ?? '';

    // ✅ PERBAIKAN #1: Hanya high, critical, tinggi yang dianggap high risk.
    // Medium TIDAK LAGI dianggap high risk.
    final isHighRisk = riskLevel == 'high' ||
        riskLevel == 'critical' ||
        riskLevel == 'tinggi';

    // ✅ Urgensi tinggi/kritis → tetap berisiko
    final isUrgensiTinggi = urgensi == 'kritis' ||
        urgensi == 'critical' ||
        urgensi == 'tinggi' ||
        urgensi == 'high';

    // ✅ PERBAIKAN #2: isHSSEApproval hanya untuk manager HSSE dengan
    // pengajuan yang memang PENDING HSSE (status atau field terkait).
    final isHSSEApproval = isHSSEManager &&
        (isPendingHSSE || requiresHsseApproval || needHsseConfirmation);

    // ✅ PERBAIKAN #3 (KUNCI): isRisky HANYA bernilai true jika statusnya
    // MASIH 'pending'. Ini mencegah field requires_hsse_approval / is_risky
    // yang belum di-cleanup memicu pop-up untuk pengajuan yang sudah final.
    final isStillPending = status == 'pending';
    final isRisky = isStillPending && (
        isHighRisk ||
        isUrgensiTinggi ||
        requiresHsseApproval ||
        detail['is_risky'] == true
    );

    // 🔍 DEBUG LOG
    debugPrint('═══════════════════════════════════');
    debugPrint('🔍 RISK DEBUG: $groupId');
    debugPrint('  Status: $status → isStillPending: $isStillPending');
    debugPrint('  RiskLevel: $riskLevel → isHighRisk: $isHighRisk');
    debugPrint('  Urgensi: $urgensi → isUrgensiTinggi: $isUrgensiTinggi');
    debugPrint('  requiresHsse: $requiresHsseApproval | is_risky: ${detail['is_risky']}');
    debugPrint('  FINAL isRisky: $isRisky');
    debugPrint('═══════════════════════════════════');

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ApprovalDetailBottomSheet(
        data: detail,
        mitraList: mitraList,
        isDarkMode: false,
        userRole: _userRole ?? 'manager',
        userName: _userName ?? 'User',
        isManager: isManager || isHSSEManager,
        isSuperadmin: isSuperadmin,
        onApprove: () {
          Navigator.pop(ctx);
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted || _isApproving) return;
            _isApproving = true;
            try {
              if (isHSSEManager) {
                // ✅ Manager HSSE → langsung proses validasi K3
                await _onHSSEReviewRequested(groupId);
              } else if (isRisky && isManager) {
                // ✅ Manager fungsi & pengajuan berisiko → munculkan pop-up konfirmasi
                _showManagerRiskyConfirmation(groupId, detail, mitraList);
              } else {
                // ✅ Pengajuan normal → approve langsung
                _showApproveDialog(groupId, detail, mitraList);
              }
            } finally {
              _isApproving = false;
            }
          });
        },
        onReject: () {
          Navigator.pop(ctx);
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted || _isApproving) return;
            _isApproving = true;
            try {
              if (isHSSEManager) {
                await _onHSSERejectRequested(groupId);
              } else {
                _showRejectDialog(groupId);
              }
            } finally {
              _isApproving = false;
            }
          });
        },
        onPreviewSpkl: hasSpkl ? () => _previewSpkl(ctx, detail['spkl_pdf_path']) : null,
      ),
    );
  }

  // ===================================================================
  // ✅ _isStillHsseActionable — DIPERBAIKI (hapus medium)
  // ===================================================================
  Future<bool> _isStillHsseActionable(String groupId) async {
  try {
    // 🛡️ Cek di lembur_mitra dulu, fallback ke pengajuan_lembur
    var doc = await _firestore.collection('lembur_mitra').doc(groupId).get();
    if (!doc.exists) {
      doc = await _firestore.collection('pengajuan_lembur').doc(groupId).get();
    }
    if (!doc.exists) {
      if (mounted) _showSnackbar('Pengajuan tidak ditemukan', isError: true);
      return false;
    }
    final data = doc.data()!;
    final status = data['status']?.toString() ?? '';
    
    // 🛡️ Skip data yang sudah dibatalkan
    if (status == 'dibatalkan' || status == 'canceled') {
      if (mounted) _showSnackbar('Pengajuan sudah dibatalkan oleh pengawas', isError: true);
      return false;
    }
    
    final requiresHsse = data['requires_hsse_approval'] == true;
    final riskLevel = data['risk_level']?.toString().toLowerCase() ?? '';

    final isHighRisk = riskLevel == 'high' || riskLevel == 'critical' || riskLevel == 'tinggi';
    final stillActionable = _hsseActionableStatuses.any((s) => status.contains(s)) || requiresHsse || isHighRisk;
    
    if (!stillActionable) {
      if (mounted) _showSnackbar('Pengajuan ini sudah diproses atau tidak lagi memerlukan validasi K3', isError: true);
      return false;
    }
    return true;
  } catch (e) {
    debugPrint('❌ Gagal cek status terbaru: $e');
    return true;
  }
}

  // ==================== SISANYA TETAP SAMA ====================

  Future<void> _onHSSEReviewRequested(String groupId) async {
    final ok = await _isStillHsseActionable(groupId);
    if (!ok) { await _loadStatistics(); return; }
    _showHSSEApproveDialog(groupId);
  }

  Future<void> _onHSSERejectRequested(String groupId) async {
    final ok = await _isStillHsseActionable(groupId);
    if (!ok) { await _loadStatistics(); return; }
    _showHSSERejectDialog(groupId);
  }

  void _showHSSEApproveDialog(String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => RiskChecklistDialog(
        onApprove: (notes) {
          Navigator.pop(ctx);
          _handleHSSEApproval(groupId, true, notes);
        },
      ),
    );
  }

  void _showHSSERejectDialog(String groupId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('Tolak Validasi HSSE', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Jelaskan alasan penolakan dari sisi K3:', style: GoogleFonts.inter(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Contoh: APD tidak lengkap, risiko tinggi...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                _showSnackbar('Alasan K3 wajib diisi', isError: true);
                return;
              }
              Navigator.pop(ctx);
              _handleHSSEApproval(groupId, false, 'Ditolak HSSE: ${controller.text.trim()}');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Tolak', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Future<void> _handleHSSEApproval(String groupId, bool isApprove, String notes) async {
    try {
      final result = await _approvalService.processApproval(
        groupId: groupId,
        isApprove: isApprove,
        notes: notes,
        userRole: 'manager_hsse',
        userFungsi: null,
        approverName: _userName ?? 'Manager HSSE',
        approverEmail: _userEmail ?? '',
        approverId: _userId ?? '',
      );
      if (mounted) {
        _showSnackbar(result.message, isError: !result.success);
        if (result.success && result.spklNomor != null) _showSpklSuccessDialog(result);
        await _loadStatistics();
        widget.onApprovalComplete?.call();
      }
    } catch (e) {
      if (mounted) _showSnackbar('Gagal memproses approval HSSE: $e', isError: true);
    }
  }

  void _showManagerRiskyConfirmation(
    String groupId,
    Map<String, dynamic> data,
    List<Map<String, dynamic>> mitraList,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Konfirmasi Risiko', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('Pekerjaan ini memiliki risiko', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoLine('Pengawas', data['nama_pengawas'] ?? '-'),
                    const SizedBox(height: 4),
                    _buildInfoLine('Fungsi', data['pengawas_fungsi'] ?? '-'),
                    const SizedBox(height: 4),
                    _buildInfoLine('Lokasi', data['lokasi']?['alamat'] ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Apakah pekerjaan ini memerlukan persetujuan K3 dari Manager HSSE?',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.2))),
                child: Column(
                  children: [
                    _buildRadioOption(
                      value: true,
                      icon: Icons.shield_rounded,
                      iconColor: hsseColor,
                      title: 'Ya, butuh persetujuan Manager HSSE',
                      subtitle: 'Diteruskan ke Manager HSSE untuk review K3',
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmNeedHSSE(groupId, true);
                      },
                    ),
                    Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                    _buildRadioOption(
                      value: false,
                      icon: Icons.thumb_up_alt,
                      iconColor: successColor,
                      title: 'Tidak, langsung setujui',
                      subtitle: 'Pekerjaan aman tanpa pengawasan K3 khusus',
                      onTap: () {
                        Navigator.pop(ctx);
                        _processApprovalDirect(groupId, true, 'Disetujui oleh Manager (tanpa validasi K3)', skipHSSE: true);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(child: TextButton.icon(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 16), label: const Text('Batal'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioOption({
    required bool value,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: iconColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12, color: textPrimary))),
      ],
    );
  }

  Future<void> _confirmNeedHSSE(String groupId, bool needHSSE) async {
  try {
    final batch = _firestore.batch();
    final updateData = {
      'need_hsse_confirmation': needHSSE,
      'need_hsse_confirmed_by': _userId,
      'need_hsse_confirmed_at': FieldValue.serverTimestamp(),
      if (needHSSE) 'status': 'pending_hsse',
      if (needHSSE) 'requires_hsse_approval': true,
    };
    
    // Update pengajuan_lembur
    batch.update(_firestore.collection('pengajuan_lembur').doc(groupId), updateData);
    
    // 🔥 Juga update lembur_mitra
    final mitraSnapshot = await _firestore
        .collection('lembur_mitra')
        .where('group_id', isEqualTo: groupId)
        .get();
    for (var doc in mitraSnapshot.docs) {
      batch.update(_firestore.collection('lembur_mitra').doc(doc.id), updateData);
    }
    
    await batch.commit();
    
    if (!mounted) return;
    if (needHSSE) _showSnackbar('Diteruskan ke Manager HSSE untuk persetujuan K3');
    await _loadStatistics();
  } catch (e) {
    if (mounted) _showSnackbar('Gagal memproses konfirmasi', isError: true);
  }
}

  void _showApproveDialog(String groupId, Map<String, dynamic> data, List<Map<String, dynamic>> mitraList) {
    showDialog(
      context: context,
      builder: (ctx) => ApprovalApproveDialog(
        data: data,
        mitraList: mitraList,
        onConfirm: (notes) {
          Navigator.pop(ctx);
          _processApproval(groupId, true, notes);
        },
      ),
    );
  }

  void _showRejectDialog(String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => ApprovalRejectDialog(
        onConfirm: (notes) {
          if (notes.isEmpty) {
            _showSnackbar('Alasan penolakan wajib diisi', isError: true);
            return;
          }
          Navigator.pop(ctx);
          _processApproval(groupId, false, notes);
        },
      ),
    );
  }

  Future<void> _processApproval(String groupId, bool isApprove, String notes) async {
    await _processApprovalDirect(groupId, isApprove, notes);
  }

  Future<void> _processApprovalDirect(String groupId, bool isApprove, String notes, {bool skipHSSE = false}) async {
    try {
      final result = await _approvalService.processApproval(
        groupId: groupId,
        isApprove: isApprove,
        notes: notes,
        userRole: _userRole ?? 'manager',
        userFungsi: _userFungsi,
        approverName: _userName ?? 'Unknown',
        approverEmail: _userEmail,
        approverId: _userId,
        skipHSSE: skipHSSE,
      );
      if (mounted) {
        _showSnackbar(result.message, isError: !result.success);
        if (result.success && result.spklNomor != null) _showSpklSuccessDialog(result);
        await _loadStatistics();
        widget.onApprovalComplete?.call();
        setState(() {
          _selectedIds.remove(groupId);
          _isSelectAll = false;
        });
      }
    } catch (e) {
      if (mounted) _showSnackbar('Gagal memproses: $e', isError: true);
    }
  }

  void _previewSpkl(BuildContext ctx, String? path) {
    Navigator.pop(ctx);
    if (path == null) return;
    OpenFilex.open(path).then((result) {
      if (result.type != ResultType.done && mounted) {
        _showSnackbar('Gagal membuka file SPKL', isError: true);
      }
    }).catchError((_) {
      if (mounted) _showSnackbar('File SPKL tidak ditemukan', isError: true);
    });
  }

  void _showSpklSuccessDialog(ApprovalResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Text('Berhasil!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(result.message, style: GoogleFonts.inter(fontSize: 13)),
            if (result.spklNomor != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Text('SPKL Otomatis Dibuat:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(result.spklNomor!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Tutup', style: GoogleFonts.inter())),
          if (result.spklPdfPath != null)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await OpenFilex.open(result.spklPdfPath!);
                } catch (_) {
                  if (mounted) _showSnackbar('Gagal membuka SPKL', isError: true);
                }
              },
              icon: const Icon(Icons.preview, size: 18),
              label: Text('Lihat SPKL', style: GoogleFonts.inter()),
              style: ElevatedButton.styleFrom(backgroundColor: accentBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
        ],
      ),
    );
  }

  Widget _buildBulkActionBar() {
    final count = _isSelectAll ? _allPendingData.length : _selectedIds.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryDark, primaryMid], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: primaryDark.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _onSelectAllToggle,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _isSelectAll ? Colors.white : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: _isSelectAll ? const Icon(Icons.check, color: primaryDark, size: 14) : null,
            ),
          ),
          const SizedBox(width: 12),
          Text('$count dipilih', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
          const Spacer(),
          _buildBulkButton('Approve', successColor, _showBulkApproveDialog),
          const SizedBox(width: 8),
          _buildBulkButton('Tolak', errorColor, _showBulkRejectDialog),
        ],
      ),
    );
  }

  Widget _buildBulkButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(0, 0),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  void _toggleBulkMode() => setState(() {
        _isBulkMode = !_isBulkMode;
        _selectedIds.clear();
        _isSelectAll = false;
      });

  void _onSelectionChanged(String groupId, bool isSelected) => setState(() {
        if (isSelected) {
          _selectedIds.add(groupId);
        } else {
          _selectedIds.remove(groupId);
          _isSelectAll = false;
        }
      });

  void _onSelectAllToggle() => setState(() {
        if (_isSelectAll) {
          _selectedIds.clear();
          _isSelectAll = false;
        } else {
          _selectedIds.addAll(_allPendingData.map((d) => d['group_id'] as String));
          _isSelectAll = true;
        }
      });

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _searchQuery = value.toLowerCase());
    });
  }

  void _onFungsiFilterChanged(String value) {
    setState(() {
      _fungsiFilter = value == 'semua' ? null : value;
      _selectedIds.clear();
      _isSelectAll = false;
    });
    _loadStatistics();
  }

  List<String> _getBulkIds() => _isSelectAll
      ? _allPendingData.map((d) => d['group_id'] as String).toList()
      : _selectedIds.toList();

  void _showBulkApproveDialog() {
    final ids = _getBulkIds();
    if (ids.isEmpty) {
      _showSnackbar('Pilih pengajuan terlebih dahulu', isError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bulk Approve', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('Setujui ${ids.length} pengajuan sekaligus?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _bulkProcess(ids, true, 'Bulk approval');
            },
            style: ElevatedButton.styleFrom(backgroundColor: successColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Setujui Semua', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  void _showBulkRejectDialog() {
    final ids = _getBulkIds();
    if (ids.isEmpty) {
      _showSnackbar('Pilih pengajuan terlebih dahulu', isError: true);
      return;
    }
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bulk Reject', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tolak ${ids.length} pengajuan sekaligus?', style: GoogleFonts.inter(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Alasan Penolakan *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                labelStyle: GoogleFonts.inter(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                _showSnackbar('Alasan penolakan wajib diisi', isError: true);
                return;
              }
              Navigator.pop(ctx);
              _bulkProcess(ids, false, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: errorColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Tolak Semua', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkProcess(List<String> groupIds, bool isApprove, String notes) async {
    if (!isSuperadmin) return;
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Memproses ${groupIds.length} pengajuan...', style: GoogleFonts.inter(fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }
    try {
      final result = await _approvalService.bulkApproval(
        groupIds: groupIds,
        isApprove: isApprove,
        notes: notes,
        approverName: _userName ?? 'Admin',
        approverEmail: _userEmail ?? '',
        approverId: _userId ?? '',
      );
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar(
          'Berhasil: ${result['totalSuccess']}, Gagal: ${result['totalFail']}',
          isError: result['totalFail'] > 0,
        );
        await _loadStatistics();
        setState(() {
          _selectedIds.clear();
          _isBulkMode = false;
          _isSelectAll = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Gagal memproses', isError: true);
      }
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: GoogleFonts.inter(fontSize: 12))),
          ],
        ),
        backgroundColor: isError ? errorColor : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accentBlue, primaryBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: accentBlue.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(accentBlue))),
          const SizedBox(height: 16),
          Text('Memuat Data...', style: GoogleFonts.inter(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getFungsiColor(String? fungsi) {
    final key = fungsi?.toLowerCase() ?? 'default';
    return _fungsiColorCache[key] ??= _computeFungsiColor(key);
  }

  Color _computeFungsiColor(String fungsi) {
    switch (fungsi) {
      case 'operation': return const Color(0xFF1976D2);
      case 'maintenance': return const Color(0xFFFF9800);
      case 'hsse': return const Color(0xFF7C3AED);
      case 'gpr': return const Color(0xFFEF4444);
      case 'bs': return const Color(0xFF795548);
      default: return const Color(0xFF757575);
    }
  }

  String _getFungsiLabel(String? fungsi) {
    final key = fungsi?.toLowerCase() ?? 'default';
    return _fungsiLabelCache[key] ??= _computeFungsiLabel(key);
  }

  String _computeFungsiLabel(String fungsi) {
    switch (fungsi) {
      case 'operation': return 'Operation';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'Business Support';
      default: return fungsi.isNotEmpty ? fungsi : 'Unknown';
    }
  }
}

class _ElegantHeaderPainter extends CustomPainter {
  final Color color;
  final Color accentColor;

  _ElegantHeaderPainter({required this.color, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final accentPaint = Paint()..color = accentColor..style = PaintingStyle.stroke..strokeWidth = 0.5;
    final random = math.Random(42);

    for (int i = 0; i < 6; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final w = 16 + random.nextDouble() * 32;
      final path = Path()
        ..moveTo(x, y - w / 2)
        ..lineTo(x + w / 2, y)
        ..lineTo(x, y + w / 2)
        ..lineTo(x - w / 2, y)
        ..close();
      canvas.drawPath(path, accentPaint);
    }

    final gridPaint = Paint()..color = color.withOpacity(0.3)..strokeWidth = 0.2;
    for (double i = 0; i < size.width; i += 50) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 50) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    for (int i = 0; i < 4; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = 6 + random.nextDouble() * 14;
      canvas.drawCircle(Offset(x, y), r, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TabData {
  final IconData icon;
  final String label;
  final String? badge;
  final Color badgeColor;
  final Color color;

  _TabData({required this.icon, required this.label, this.badge, required this.badgeColor, required this.color});
}