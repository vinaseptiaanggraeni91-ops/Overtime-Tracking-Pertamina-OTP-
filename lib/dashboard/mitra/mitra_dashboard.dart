import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/mitra_service.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/live_location_service.dart';
import '/widgets/menu/mitra_menu.dart';
import '/widgets/absensi/absensi_dialog.dart';
import '/widgets/bottom_nav/mitra_bottom_nav.dart';
import '/widgets/mitra/mitra_attendance_overtime_card.dart';
import 'notification_list_screen.dart';

// ═══════════════════════════════════════════════════════
// 🎨 PREMIUM COLOR SYSTEM
// ═══════════════════════════════════════════════════════
class AppColors {
  // Primary
  static const Color primaryColor = Color(0xFF1B6EF3);
  static const Color primaryDark = Color(0xFF0A3D91);
  static const Color primaryLight = Color(0xFF4D8FF7);
  static const Color accentColor = Color(0xFF5BA0F9);
  
  // Status Colors
  static const Color successColor = Color(0xFF10B981);
  static const Color dangerColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF3B82F6);
  
  // Background
  static const Color bgPrimary = Color(0xFFF8FAFC);
  static const Color bgSecondary = Color(0xFFF1F5F9);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  
  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  
  // Border
  static const Color borderLight = Color(0xFFE2E8F0);
  
  // Premium Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0A3D91), Color(0xFF1B6EF3), Color(0xFF4D8FF7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient successGradient = const LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient warningGradient = const LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient dangerGradient = const LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient infoGradient = const LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient purpleGradient = const LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient oceanGradient = const LinearGradient(
    colors: [Color(0xFF0C4A6E), Color(0xFF0369A1), Color(0xFF38BDF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 🔥🔥🔥 GREEN PREMIUM GRADIENT untuk Pendapatan
  static LinearGradient greenPremiumGradient = const LinearGradient(
    colors: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF00897B), Color(0xFF26A69A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient greenEmeraldGradient = const LinearGradient(
    colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF059669), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient warmGradient = const LinearGradient(
    colors: [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFB923C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> mediumShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

// ═══════════════════════════════════════════════════════
// 📱 MAIN DASHBOARD
// ═══════════════════════════════════════════════════════
class MitraDashboard extends StatefulWidget {
  const MitraDashboard({super.key});

  @override
  State<MitraDashboard> createState() => _MitraDashboardState();
}

class _MitraDashboardState extends State<MitraDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ChangeNotifierProvider(
      create: (_) => MitraDashboardProvider(),
      child: _MitraDashboardBody(user: user, currentIndex: _currentIndex),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 🏗️ DASHBOARD BODY
// ═══════════════════════════════════════════════════════
class _MitraDashboardBody extends StatefulWidget {
  final User? user;
  final int currentIndex;
  
  const _MitraDashboardBody({required this.user, required this.currentIndex});

  @override
  State<_MitraDashboardBody> createState() => _MitraDashboardBodyState();
}

class _MitraDashboardBodyState extends State<_MitraDashboardBody>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  final _mitraService = MitraService();
  final _scrollController = ScrollController();
  
  late AnimationController _animationController;
  late AnimationController _motivationAnimController;
  
  String _userName = '';
  String _userRole = '';
  String? _userPhotoUrl;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  int _unreadNotificationCount = 0;
  String _greeting = 'Selamat Datang';
  String _motivationQuote = '';
  int _currentMotivationIndex = 0;
  
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _recentOvertimeHistory = [];
  Map<String, dynamic>? _attendanceToday;
  Map<String, dynamic>? _todayOvertime;
  bool _isCheckedIn = false;
  bool _isCheckedOut = false;
  
  Timer? _autoRefreshTimer;
  Timer? _motivationTimer;
  
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0,
  );
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
  final DateFormat _timeFormat = DateFormat('HH:mm', 'id_ID');
  final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'id_ID');

  // 🔥🔥🔥 KOLEKSI MOTIVASI KERJA
  final List<Map<String, String>> _motivations = [
    {'quote': 'Kerja keras hari ini, sukses esok hari! 💪', 'author': 'Semangat Pagi'},
    {'quote': 'Setiap tetes keringat adalah investasi masa depan ✨', 'author': 'Motivasi Kerja'},
    {'quote': 'Jadikan lelahmu sebagai ladang pahala 🌟', 'author': 'Penyemangat'},
    {'quote': 'Kerja adalah ibadah, lakukan dengan sepenuh hati ❤️', 'author': 'Inspirasi'},
    {'quote': 'Hari ini lebih baik dari kemarin, esok lebih baik dari hari ini 🚀', 'author': 'Kata Bijak'},
    {'quote': 'Kesuksesan berawal dari keberanian untuk memulai 🔥', 'author': 'Pagi Semangat'},
    {'quote': 'Tidak ada hasil tanpa usaha, tidak ada usaha tanpa doa 🙏', 'author': 'Renungan'},
    {'quote': 'Anda lebih kuat dari yang Anda kira, teruslah melangkah! ⚡', 'author': 'Motivasi'},
    {'quote': 'Setiap pekerjaan besar dimulai dari langkah kecil 🎯', 'author': 'Bijak'},
    {'quote': 'Lelah itu biasa, menyerah itu pilihan. Pilih untuk terus berjuang! 💎', 'author': 'Semangat'},
  ];

  List<Map<String, dynamic>> get _validHistory {
    return _recentOvertimeHistory.where((item) {
      final status = (item['status']?.toString() ?? '').toLowerCase();
      return status != 'dibatalkan';
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _motivationAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeDashboard());
    
    _autoRefreshTimer = Timer.periodic(
      const Duration(minutes: 5), (_) => _silentRefresh(),
    );
    
    _pickRandomMotivation();
    _motivationTimer = Timer.periodic(
      const Duration(seconds: 5), (_) => _changeMotivation(),
    );
  }

  void _pickRandomMotivation() {
    final random = Random();
    final newIndex = random.nextInt(_motivations.length);
    setState(() {
      _currentMotivationIndex = newIndex;
      _motivationQuote = _motivations[newIndex]['quote']!;
    });
  }

  void _changeMotivation() {
    _motivationAnimController.reverse().then((_) {
      _pickRandomMotivation();
      _motivationAnimController.forward();
    });
  }

  Future<void> _initializeDashboard() async {
    _animationController.forward();
    _motivationAnimController.forward();
    await Future.wait([
      _loadUserProfile(),
      _loadDashboardData(),
      _loadAdditionalData(),
      _loadNotifications(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _silentRefresh() async {
    try {
      await Future.wait([
        _loadDashboardData(),
        _loadAdditionalData(),
        _loadNotifications(),
      ]);
    } catch (e) {
      debugPrint('Silent refresh error: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _mitraService.getUserProfile();
      if (mounted && profile.isNotEmpty) {
        setState(() {
          _userName = profile['nama_lengkap']?.toString() ?? widget.user?.displayName ?? 'Mitra';
          _userRole = profile['role']?.toString() ?? 'mitra';
          _userPhotoUrl = profile['photo_url']?.toString();
          _greeting = _mitraService.getGreeting();
        });
      }
    } catch (e) {
      debugPrint('Load profile error: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final provider = context.read<MitraDashboardProvider>();
      await provider.loadData();
      if (mounted && provider.data != null) {
        final data = provider.data!;
        setState(() {
          _todayOvertime = data.todayOvertime;
          _isCheckedIn = data.isLemburCheckedIn;
          _isCheckedOut = data.isLemburCheckedOut;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Gagal memuat data dashboard');
    }
  }

  Future<void> _loadAdditionalData() async {
    try {
      final results = await Future.wait([
        _mitraService.getUpcomingSchedules(),
        _mitraService.getRecentOvertimeHistory(limit: 10),
        _mitraService.getTodayAttendance(),
      ]);
      if (mounted) {
        setState(() {
          _schedules = results[0] as List<Map<String, dynamic>>;
          _recentOvertimeHistory = results[1] as List<Map<String, dynamic>>;
          _attendanceToday = results[2] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      debugPrint('Load additional data error: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notifs = await _mitraService.getNotifications();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = notifs.where((n) => n['isRead'] == false).length;
        });
      }
    } catch (e) {
      debugPrint('Load notifications error: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final provider = context.read<MitraDashboardProvider>();
      provider.clearCache();
      await Future.wait([
        provider.loadData(), _loadUserProfile(),
        _loadAdditionalData(), _loadNotifications(),
      ]);
      _animationController.reset();
      _animationController.forward();
      if (mounted) _showSnackBar('✅ Data berhasil diperbarui', AppColors.successColor);
    } catch (e) {
      if (mounted) _showSnackBar('❌ Gagal memperbarui data', AppColors.dangerColor);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).size.height * 0.08),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleCheckIn() async {
    if (_todayOvertime == null) {
      _showSnackBar('Tidak ada jadwal lembur hari ini', AppColors.infoColor);
      return;
    }
    try {
      final overtimeId = _todayOvertime!['id']?.toString();
      if (overtimeId == null) throw Exception('ID lembur tidak valid');
      final overtimeItem = await OvertimeHistoryService().getOvertimeById(overtimeId);
      if (overtimeItem == null) throw Exception('Data lembur tidak ditemukan');
      if (overtimeItem.status == 'dibatalkan') {
        _showSnackBar('Lembur ini sudah dibatalkan', AppColors.dangerColor);
        return;
      }
      final absensiSuccess = await AbsensiDialog.show(context, overtimeItem);
      if (absensiSuccess != true || !mounted) return;
      await _mitraService.checkInLembur(overtimeId, _userName);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          await LiveLocationService().startTracking(
            userId: currentUser.uid, userName: _userName,
            overtimeId: overtimeId, lemburId: overtimeId,
          );
        } catch (e) { debugPrint('Failed to start live tracking: $e'); }
      }
      await _refreshData();
      _showSnackBar('✅ Check-in berhasil!', AppColors.successColor);
    } catch (e) {
      _showSnackBar('Gagal check-in: $e', AppColors.dangerColor);
    }
  }

  Future<void> _handleCheckOut() async {
    if (_todayOvertime == null) {
      _showSnackBar('Tidak ada data lembur aktif', AppColors.infoColor);
      return;
    }
    try {
      final overtimeId = _todayOvertime!['id']?.toString();
      if (overtimeId == null) throw Exception('ID lembur tidak valid');
      final overtimeItem = await OvertimeHistoryService().getOvertimeById(overtimeId);
      if (overtimeItem == null) throw Exception('Data lembur tidak ditemukan');
      if (overtimeItem.status == 'dibatalkan') {
        _showSnackBar('Lembur ini sudah dibatalkan', AppColors.dangerColor);
        return;
      }
      final absensiSuccess = await AbsensiDialog.show(context, overtimeItem);
      if (absensiSuccess != true || !mounted) return;
      await LiveLocationService().stopTracking();
      final provider = context.read<MitraDashboardProvider>();
      final income = await _mitraService.checkOutLembur(overtimeId, _userName, provider.data?.overtimeSettings ?? {});
      await _refreshData();
      _showSnackBar('✅ Check-out berhasil! Pendapatan: ${_mitraService.formatCurrency(income)}', AppColors.successColor);
    } catch (e) {
      _showSnackBar('Gagal check-out: $e', AppColors.dangerColor);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ MAIN BUILD - MOBILE OPTIMIZED
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MitraDashboardProvider>();
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    if (_isLoading || provider.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        bottomNavigationBar: MitraBottomNav(currentIndex: widget.currentIndex),
        body: _buildLoadingScreen(),
      );
    }
    
    if (provider.data == null && _errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        bottomNavigationBar: MitraBottomNav(currentIndex: widget.currentIndex),
        body: _buildErrorScreen(),
      );
    }
    
    final data = provider.data!;
    final currentMonthYear = _monthYearFormat.format(DateTime.now());
    
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      bottomNavigationBar: MitraBottomNav(currentIndex: widget.currentIndex),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primaryColor,
        backgroundColor: Colors.white,
        displacement: statusBarHeight + 60,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(statusBarHeight)),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 100 + bottomPadding),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildAnimatedItem(child: _buildMotivationBanner(), delay: 0),
                  const SizedBox(height: 12),
                  _buildAnimatedItem(child: _buildWelcomeCard(), delay: 50),
                  const SizedBox(height: 16),
                  if (_attendanceToday != null || data.hasTodayOvertime || _schedules.isNotEmpty) ...[
                    _buildAnimatedItem(
                      child: MitraAttendanceOvertimeCard(
                        attendanceData: _attendanceToday,
                        overtime: data.hasTodayOvertime && data.todayOvertime != null
                            ? Map<String, dynamic>.from(data.todayOvertime!)
                            : null,
                        upcomingSchedules: _schedules.isNotEmpty ? _schedules : null,
                        isCheckedIn: data.isLemburCheckedIn,
                        isCheckedOut: data.isLemburCheckedOut,
                        canCheckIn: data.hasTodayOvertime,
                        formattedCheckInTime: data.hasTodayOvertime 
                            ? _formatCheckInTime(data.todayOvertime!['jam_mulai']?.toString() ?? '19:00')
                            : '--:--',
                        userName: _userName,
                        overtimeSettings: data.overtimeSettings,
                        onCheckIn: _handleCheckIn,
                        onCheckOut: _handleCheckOut,
                        onViewAllSchedules: () => context.push('/jadwal-lembur'),
                      ),
                      delay: 100,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildAnimatedItem(
                    child: _buildRingkasanLemburCards(data, currentMonthYear),
                    delay: 200,
                  ),
                  const SizedBox(height: 16),
                  _buildAnimatedItem(
                    child: _buildTotalJamKuotaCard(data, currentMonthYear),
                    delay: 300,
                  ),
                  const SizedBox(height: 16),
                  _buildAnimatedItem(
                    child: _buildPendapatanCard(data, currentMonthYear),
                    delay: 400,
                  ),
                  const SizedBox(height: 20),
                  _buildAnimatedItem(
                    child: MitraMenu(data: data, service: _mitraService),
                    delay: 500,
                  ),
                  const SizedBox(height: 20),
                  if (_validHistory.isNotEmpty) ...[
                    _buildAnimatedItem(
                      child: _buildRecentHistorySection(),
                      delay: 600,
                    ),
                    const SizedBox(height: 16),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥🔥🔥 MOTIVATION BANNER
  // ═══════════════════════════════════════════════════════════
  Widget _buildMotivationBanner() {
    final motiv = _motivations[_currentMotivationIndex];
    return AnimatedBuilder(
      animation: _motivationAnimController,
      builder: (context, child) {
        return Opacity(
          opacity: _motivationAnimController.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - _motivationAnimController.value)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.warningColor.withValues(alpha: 0.15), AppColors.warningColor.withValues(alpha: 0.05), Colors.white],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.warningColor.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.warmGradient, borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: AppColors.warningColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(motiv['quote']!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.4)),
                    const SizedBox(height: 2),
                    Text('— ${motiv['author']}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.warningColor, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 HEADER MODERN
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader(double statusBarHeight) {
    return Container(
      padding: EdgeInsets.only(top: statusBarHeight + 8, left: 16, right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.engineering_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Dashboard Mitra', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
            Text(_userRole.isNotEmpty ? _userRole.toUpperCase() : 'MITRA', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryColor, letterSpacing: 1.5)),
          ]),
        ),
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationListScreen()),
            );
            _loadNotifications();
          },
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12)),
            child: Stack(clipBehavior: Clip.none, children: [
              const Center(child: Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 22)),
              if (_unreadNotificationCount > 0)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: AppColors.dangerColor,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 WELCOME CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2.5),
              image: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                  ? DecorationImage(image: NetworkImage(_userPhotoUrl!), fit: BoxFit.cover) : null,
            ),
            child: (_userPhotoUrl == null || _userPhotoUrl!.isEmpty)
                ? Center(child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'M', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_greeting,', style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(_userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _buildMiniBadge(Icons.calendar_today_rounded, _dateFormat.format(DateTime.now())),
          const SizedBox(width: 8),
          _buildMiniBadge(Icons.access_time_rounded, _timeFormat.format(DateTime.now())),
        ]),
      ]),
    );
  }

  Widget _buildMiniBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 12),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥🔥🔥 RINGKASAN LEMBUR - 3 CARD FIXED SEJAJAR
  // ═══════════════════════════════════════════════════════════
  Widget _buildRingkasanLemburCards(MitraDashboardData data, String monthYear) {
    final isMitraOnly = _userRole.toLowerCase() == 'mitra';
    final disetujui = data.bulanStats.disetujui;
    final ditolak = data.bulanStats.ditolak;
    final selesai = data.bulanStats.selesai;
    final pending = data.bulanStats.pending;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionTitle('Ringkasan Lembur', Icons.analytics_rounded, monthYear),
      const SizedBox(height: 12),
      if (isMitraOnly) ...[
        Row(children: [
          Expanded(child: _buildStatusCard(title: 'Disetujui', value: '$disetujui', icon: Icons.check_circle_rounded, gradient: AppColors.successGradient)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatusCard(title: 'Selesai', value: '$selesai', icon: Icons.task_alt_rounded, gradient: AppColors.infoGradient)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatusCard(title: 'Ditolak', value: '$ditolak', icon: Icons.cancel_rounded, gradient: AppColors.dangerGradient)),
        ]),
      ] else ...[
        Row(children: [
          Expanded(child: _buildStatusCard(title: 'Pending', value: '$pending', icon: Icons.pending_rounded, gradient: AppColors.warningGradient)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatusCard(title: 'Disetujui', value: '$disetujui', icon: Icons.check_circle_rounded, gradient: AppColors.successGradient)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildStatusCard(title: 'Ditolak', value: '$ditolak', icon: Icons.cancel_rounded, gradient: AppColors.dangerGradient)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatusCard(title: 'Selesai', value: '$selesai', icon: Icons.task_alt_rounded, gradient: AppColors.purpleGradient)),
        ]),
      ],
    ]);
  }

  Widget _buildStatusCard({required String title, required String value, required IconData icon, required LinearGradient gradient}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        gradient: gradient, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: gradient.colors.first.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 18)),
        ]),
        const SizedBox(height: 16),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1, height: 1))),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥🔥🔥 TOTAL JAM & KUOTA - CARD PREMIUM (AKURAT)
  // ═══════════════════════════════════════════════════════════
  Widget _buildTotalJamKuotaCard(MitraDashboardData data, String monthYear) {
    // 🔥 Data akurat dari service
    final totalJam = data.bulanStats.totalJam;
    final sisaKuota = data.bulanStats.sisaKuota;
    final maxKuota = 60.0;
    final persentase = maxKuota > 0 ? (totalJam / maxKuota * 100).clamp(0.0, 100.0) : 0.0;
    
    // 🔥 Format tampilan: tampilkan 1 desimal jika ada pecahan, integer jika bulat
    final totalJamDisplay = totalJam == totalJam.roundToDouble() 
        ? '${totalJam.toInt()}' 
        : totalJam.toStringAsFixed(1);
    final sisaKuotaDisplay = sisaKuota == sisaKuota.roundToDouble() 
        ? '${sisaKuota.toInt()}' 
        : sisaKuota.toStringAsFixed(1);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.oceanGradient, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF0C4A6E).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total Jam & Kuota', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(monthYear, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: Text('${persentase.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: persentase / 100), duration: const Duration(milliseconds: 1200), curve: Curves.easeOutCubic,
              builder: (context, value, child) => LinearProgressIndicator(value: value.clamp(0.0, 1.0), backgroundColor: Colors.transparent, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildKuotaDetail('Total Jam', totalJamDisplay, 'Jam', Icons.hourglass_bottom)),
          Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.3)),
          Expanded(child: _buildKuotaDetail('Sisa Kuota', sisaKuotaDisplay, 'Jam', Icons.pie_chart_rounded)),
        ]),
      ]),
    );
  }

  Widget _buildKuotaDetail(String label, String value, String unit, IconData icon) {
    return Column(children: [
      Icon(icon, color: Colors.white70, size: 16),
      const SizedBox(height: 4),
      RichText(text: TextSpan(children: [
        TextSpan(text: value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        TextSpan(text: ' $unit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.7))),
      ])),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥🔥🔥 TOTAL PENDAPATAN - GREEN PREMIUM (AKURAT)
  // ═══════════════════════════════════════════════════════════
  Widget _buildPendapatanCard(MitraDashboardData data, String monthYear) {
    // 🔥 Data dari service yang SUDAH BENAR
    final totalIncome = data.bulanStats.totalIncome;
    final totalJam = data.bulanStats.totalJam;
    
    // 🔥 Rate/Jam
    final ratePerJam = totalJam > 0 ? totalIncome / totalJam : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.greenEmeraldGradient, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF064E3B).withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10))],
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]), child: const Icon(Icons.payments_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total Pendapatan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(monthYear, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
          ])),
          if (data.trendIncome != 0)
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(data.trendIncome >= 0 ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text('${data.trendIncome.abs().toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ])),
        ]),
        const SizedBox(height: 20),
        FittedBox(fit: BoxFit.scaleDown, child: Text(_currencyFormat.format(totalIncome), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1, shadows: [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))]))),
        const SizedBox(height: 18),
        Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.0), Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.0)]))),
        const SizedBox(height: 14),
        Row(children: [
          _buildPendapatanDetail(Icons.timer_rounded, 'Total Jam', '${totalJam.toStringAsFixed(1)}h'),
          const SizedBox(width: 10),
          _buildPendapatanDetail(Icons.monetization_on_rounded, 'Rate/Jam', _mitraService.formatRupiahCompact(ratePerJam)),
        ]),
      ]),
    );
  }
  
  Widget _buildPendapatanDetail(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1)),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 18), const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 9, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 RIWAYAT TERBARU
  // ═══════════════════════════════════════════════════════════
  Widget _buildRecentHistorySection() {
    final validItems = _validHistory;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionTitle('Riwayat Terbaru', Icons.history_rounded, null), const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: AppColors.softShadow),
        child: Column(children: [
          ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.all(12), itemCount: validItems.length.clamp(0, 5), itemBuilder: (context, index) => _buildHistoryItem(validItems[index], index)),
          InkWell(
            onTap: () => context.push('/overtime-data'), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Lihat Semua Riwayat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ])),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, int index) {
    final status = item['status']?.toString() ?? 'pending';
    final statusColor = _mitraService.getStatusColor(status);
    final date = item['date']?.toString() ?? '-';
    final durasi = item['durasi']?.toString() ?? '-';
    final income = item['income'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 3, height: 40, decoration: BoxDecoration(gradient: LinearGradient(colors: [statusColor, statusColor.withValues(alpha: 0.4)]), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
          const SizedBox(height: 4), Text(durasi, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        if (income > 0) Text(_mitraService.formatRupiahCompact(income.toDouble()), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.successColor)),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5))),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // UTILITY WIDGETS
  // ═══════════════════════════════════════════════════════════
  Widget _buildAnimatedItem({required Widget child, required int delay}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0), duration: Duration(milliseconds: 500 + delay), curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(opacity: value.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, 24 * (1 - value)), child: child)),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, String? subtitle) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]), child: Icon(icon, color: Colors.white, size: 15)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ])),
    ]);
  }

  Widget _buildLoadingScreen() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 100, height: 100, decoration: BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.3), blurRadius: 30)]), child: const Icon(Icons.engineering_rounded, size: 48, color: Colors.white)),
      const SizedBox(height: 24), const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
      const SizedBox(height: 16), const Text('Memuat Dashboard...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
    ]));
  }

  Widget _buildErrorScreen() {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 100, height: 100, decoration: BoxDecoration(color: AppColors.dangerColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.dangerColor)),
      const SizedBox(height: 20), const Text('Gagal Memuat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 8), Text(_errorMessage ?? 'Terjadi kesalahan.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _initializeDashboard, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.w700))),
    ])));
  }

  String _formatCheckInTime(String jamMulai) {
    final parts = jamMulai.split(':');
    if (parts.length != 2) return jamMulai;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final checkInFrom = DateTime(2024, 1, 1, hour, minute).subtract(const Duration(hours: 1));
    return '${checkInFrom.hour.toString().padLeft(2, '0')}:${checkInFrom.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _motivationAnimController.dispose();
    _scrollController.dispose();
    _autoRefreshTimer?.cancel();
    _motivationTimer?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════
// 📦 PROVIDER
// ═══════════════════════════════════════════════════════
class MitraDashboardProvider extends ChangeNotifier {
  final _service = MitraService();
  bool isLoading = true;
  MitraDashboardData? data;
  String? errorMessage;

  Future<void> loadData() async {
    isLoading = true; errorMessage = null; notifyListeners();
    try { data = await _service.loadDashboardData(); } catch (e) { errorMessage = e.toString(); }
    isLoading = false; notifyListeners();
  }

  void clearCache() { data = null; errorMessage = null; notifyListeners(); }
}