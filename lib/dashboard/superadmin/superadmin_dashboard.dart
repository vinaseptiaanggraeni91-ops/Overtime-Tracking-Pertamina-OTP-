import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/services/superadmin_service.dart';
import '../../core/services/unified_stats_service.dart'; // 🔥 NEW
import '../../widgets/superadmin/stats_grid.dart'; // Keep for backward compatibility
import '../../widgets/universal_stats_card.dart'; // 🔥 NEW
import '../../widgets/superadmin/analytics_section.dart';
import '../../widgets/superadmin/user_distribution.dart';
import '../../widgets/superadmin/quick_actions.dart';
import '../../widgets/menu/superadmin_menu.dart';
import '../../widgets/superadmin/location_monitoring.dart';
import '../../widgets/superadmin/recent_activities.dart';
import '../../widgets/bottom_nav/superadmin_bottom_nav.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ChangeNotifierProvider(
      create: (_) => SuperAdminProvider(),
      child: _SuperAdminBody(user: user, currentIndex: _currentIndex),
    );
  }
}

class _SuperAdminBody extends StatefulWidget {
  final User? user;
  final int currentIndex;
  const _SuperAdminBody({required this.user, required this.currentIndex});

  @override
  State<_SuperAdminBody> createState() => _SuperAdminBodyState();
}

class _SuperAdminBodyState extends State<_SuperAdminBody>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  final _service = DashboardService();
  final _scrollController = ScrollController();

  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  String _greeting = 'Selamat Datang';
  String _motivation = '';
  String _userName = '';
  String _userRole = '';
  String? _userPhotoUrl;
  bool _isGreetingLoading = true;
  bool _isRefreshing = false;
  String? _loadingMessage;
  Timer? _snackbarTimer;
  Timer? _greetingUpdateTimer;

  int _unreadNotificationCount = 0;
  List<Map<String, dynamic>> _recentActivities = [];
  int _pendingApprovals = 0;
  int _totalWorkers = 0;

  // ═══════════════════════════════════════════════════════
  // 🔵 NUANSA BIRU COLOR PALETTE
  // ═══════════════════════════════════════════════════════
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color accentColor = Color(0xFF42A5F5);
  static const Color successColor = Color(0xFF43A047);
  static const Color dangerColor = Color(0xFFEF5350);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color infoColor = Color(0xFF29B6F6);

  static const Color bgPrimary = Color(0xFFF5F9FF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color textTertiary = Color(0xFF90A4AE);
  static const Color borderLight = Color(0xFFE3E8F0);

  // 🔥 State untuk filter fungsi (optional)
  String _selectedFungsi = 'semua';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeDashboard());
    _greetingUpdateTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateGreetingAndNotifications(),
    );
  }

  void _setupAnimations() {
    try {
      _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
      _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
      _fadeAnimation = CurvedAnimation(parent: _fadeController!, curve: Curves.easeOutCubic);
      _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(parent: _slideController!, curve: Curves.easeOutCubic)
      );
    } catch (e) {
      debugPrint('❌ Gagal setup animasi: $e');
    }
  }

  void _startAnimations() {
    if (mounted) {
      _fadeController?.forward();
      _slideController?.forward();
    }
  }

  Future<void> _initializeDashboard() async {
    _startAnimations();
    await _loadGreetingAndProfile();
    await _loadDataWithMessage();
    await _loadAdditionalData();
    await _loadNotificationCount();
  }

  Future<void> _updateGreetingAndNotifications() async {
    try {
      final greeting = await _service.getGreetingWithNameAndEmoji();
      if (mounted) setState(() => _greeting = greeting);
    } catch (_) {}
    _loadNotificationCount();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final notifs = await _service.getNotifications();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = notifs.where((n) => n['isRead'] == false).length;
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat notifikasi: $e');
    }
  }

  Future<void> _loadGreetingAndProfile() async {
    try {
      final results = await Future.wait([
        _service.getGreetingWithNameAndEmoji(),
        _service.getGreetingMotivation(),
        _service.getCurrentUserProfile(),
      ]);
      if (mounted) {
        setState(() {
          _greeting = results[0] as String;
          _motivation = results[1] as String;
          _isGreetingLoading = false;
          final profile = results[2] as Map<String, dynamic>?;
          if (profile != null) {
            _userName = profile['nama_lengkap']?.toString() ?? '';
            _userRole = profile['role']?.toString() ?? 'superadmin';
            _userPhotoUrl = profile['photo_url']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final hour = DateTime.now().hour;
          String greeting;
          if (hour >= 5 && hour < 12) {
            greeting = 'Selamat Pagi';
          } else if (hour >= 12 && hour < 15) {
            greeting = 'Selamat Siang';
          } else if (hour >= 15 && hour < 18) {
            greeting = 'Selamat Sore';
          } else {
            greeting = 'Selamat Malam';
          }
          _greeting = '$greeting, ${widget.user?.displayName ?? 'Super Admin'}! 👋';
          _motivation = 'Kelola sistem dengan bijak! 🚀';
          _isGreetingLoading = false;
        });
      }
    }
  }

  Future<void> _loadDataWithMessage() async {
    setState(() => _loadingMessage = 'Mempersiapkan dashboard...');
    final provider = context.read<SuperAdminProvider>();
    await provider.loadData();
    if (mounted && provider.data != null) setState(() => _loadingMessage = null);
  }

  Future<void> _loadAdditionalData() async {
    try {
      final results = await Future.wait([
        _service.getRecentActivities(limit: 5),
        _service.getPendingApprovals(),
        _service.getTotalWorkers(),
      ]);
      if (mounted) {
        setState(() {
          _recentActivities = results[0] as List<Map<String, dynamic>>;
          _pendingApprovals = results[1] as int;
          _totalWorkers = results[2] as int;
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat data tambahan: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snackbarTimer?.cancel();
    _greetingUpdateTimer?.cancel();
    _fadeController?.dispose();
    _slideController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final provider = context.read<SuperAdminProvider>();
      provider.clearCache();
      await Future.wait([
        provider.loadData(),
        _loadGreetingAndProfile(),
        _loadAdditionalData(),
        _loadNotificationCount()
      ]);
      _fadeController?.reset();
      _slideController?.reset();
      _startAnimations();
      if (mounted) _showSnackBar('✅ Data berhasil diperbarui', icon: Icons.check_circle_rounded, backgroundColor: successColor);
    } catch (e) {
      if (mounted) _showSnackBar('❌ Gagal memperbarui data', icon: Icons.error_rounded, backgroundColor: dangerColor);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showSnackBar(String message, {required IconData icon, required Color backgroundColor}) {
    if (!mounted) return;
    _snackbarTimer?.cancel();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ]),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).size.height * 0.12,
      ),
      duration: const Duration(seconds: 3),
      elevation: 8,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ));
  }

  Future<void> _showNotifications() async {
    final notifs = await _service.getNotifications();
    if (!mounted) return;
    await _loadNotificationCount();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [surfaceColor, bgPrimary],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [primaryColor, accentColor]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [primaryColor, accentColor]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Notifikasi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (notifs.any((n) => n['isRead'] == false))
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [primaryColor, accentColor]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton.icon(
                          onPressed: () async {
                            await _service.markAllNotificationsRead();
                            if (mounted) context.read<SuperAdminProvider>().loadData();
                            await _loadNotificationCount();
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnackBar(
                              '✅ Semua notifikasi telah dibaca',
                              icon: Icons.check_circle_rounded,
                              backgroundColor: successColor,
                            );
                          },
                          icon: const Icon(Icons.done_all_rounded, size: 18, color: Colors.white),
                          label: const Text(
                            'Baca Semua',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: notifs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor.withValues(alpha: 0.1),
                                    accentColor.withValues(alpha: 0.1),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                size: 48,
                                color: textTertiary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada notifikasi',
                              style: TextStyle(
                                color: textTertiary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: notifs.length,
                        itemBuilder: (ctx, index) {
                          final n = notifs[index];
                          final isRead = n['isRead'] ?? false;
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 400 + (index * 100)),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) =>
                                Transform.translate(
                                  offset: Offset(0, 30 * (1 - value)),
                                  child: Opacity(
                                    opacity: value.clamp(0.0, 1.0),
                                    child: child,
                                  ),
                                ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isRead
                                    ? surfaceColor
                                    : primaryColor.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isRead
                                      ? borderLight
                                      : primaryColor.withValues(alpha: 0.15),
                                ),
                                boxShadow: isRead
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: primaryColor.withValues(alpha: 0.08),
                                          blurRadius: 15,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: isRead
                                          ? LinearGradient(
                                              colors: [
                                                textTertiary.withValues(alpha: 0.2),
                                                textTertiary.withValues(alpha: 0.1),
                                              ],
                                            )
                                          : const LinearGradient(
                                              colors: [primaryColor, accentColor],
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isRead
                                          ? Icons.notifications_outlined
                                          : Icons.notifications_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n['title'] ?? 'Notifikasi',
                                          style: TextStyle(
                                            fontWeight: isRead
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            fontSize: 14,
                                            color: textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          n['body'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                            height: 1.5,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _service.getTimeAgo(n['createdAt']),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: textTertiary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(top: 8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [primaryColor, accentColor],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SuperAdminProvider>();
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (provider.isLoading || _isGreetingLoading) {
      return Scaffold(
        backgroundColor: bgPrimary,
        bottomNavigationBar: SuperAdminBottomNav(currentIndex: widget.currentIndex),
        body: _buildLoadingScreen(),
      );
    }
    if (provider.data == null) {
      return Scaffold(
        backgroundColor: bgPrimary,
        bottomNavigationBar: SuperAdminBottomNav(currentIndex: widget.currentIndex),
        body: _buildErrorScreen(provider.errorMessage),
      );
    }

    final data = provider.data!;

    return Scaffold(
      backgroundColor: bgPrimary,
      bottomNavigationBar: SuperAdminBottomNav(currentIndex: widget.currentIndex),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: primaryColor,
        backgroundColor: surfaceColor,
        strokeWidth: 3,
        displacement: statusBarHeight + 30,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(statusBarHeight)),
            _buildContent(data, bottomPadding),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════
  Widget _buildHeader(double statusBarHeight) {
    return Container(
      padding: EdgeInsets.only(
        top: statusBarHeight + 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.03),
            accentColor.withValues(alpha: 0.03),
            infoColor.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [primaryColor, accentColor],
              ).createShader(bounds),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [primaryColor, accentColor],
                  ).createShader(bounds),
                  child: const Text(
                    'Super Admin',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textTertiary,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          _buildQuickActionButton(
            icon: Icons.notifications_outlined,
            onTap: _showNotifications,
            badge: _unreadNotificationCount > 0
                ? _unreadNotificationCount.toString()
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Icon(icon, color: textSecondary, size: 22),
            if (badge != null)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: dangerColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // LOADING & ERROR
  // ═══════════════════════════════════════════════════════
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value.clamp(0.0, 1.5),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [primaryColor, accentColor]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Shimmer.fromColors(
            baseColor: borderLight,
            highlightColor: surfaceColor,
            child: Column(
              children: [
                Container(
                  width: 200,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 160,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                primaryColor.withValues(alpha: 0.8),
              ),
            ),
          ),
          if (_loadingMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _loadingMessage!,
              style: TextStyle(
                fontSize: 12,
                color: textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String? errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Transform.scale(
                scale: value.clamp(0.0, 1.0),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        dangerColor.withValues(alpha: 0.1),
                        warningColor.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: dangerColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [dangerColor, warningColor],
              ).createShader(bounds),
              child: const Text(
                'Gagal Memuat Data',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'Terjadi kesalahan.\nSilakan coba lagi.',
              style: const TextStyle(
                color: textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [primaryColor, accentColor]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<SuperAdminProvider>().clearCache();
                  context.read<SuperAdminProvider>().loadData();
                  _loadGreetingAndProfile();
                  _loadAdditionalData();
                },
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Coba Lagi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // MAIN CONTENT
  // ═══════════════════════════════════════════════════════
  Widget _buildContent(DashboardData data, double bottomPadding) {
    final slide = _slideAnimation ?? const AlwaysStoppedAnimation(Offset.zero);
    final fade = _fadeAnimation ?? const AlwaysStoppedAnimation(1.0);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 80 + bottomPadding),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // WELCOME CARD
          SlideTransition(
            position: slide,
            child: FadeTransition(opacity: fade, child: _buildWelcomeCard()),
          ),
          const SizedBox(height: 12),

          // 🔥🔥🔥 UNIVERSAL STATS CARD - MENGGANTIKAN STATS GRID LAMA
          _buildSectionHeader(
            icon: Icons.dashboard_rounded,
            title: 'Ringkasan Kinerja',
            gradient: const LinearGradient(colors: [primaryColor, accentColor]),
            trailing: _buildFungsiFilter(), // 🔥 Filter fungsi dropdown
          ),
          const SizedBox(height: 6),
          _buildAnimatedSection(
            child: UniversalStatsCard(
              cardRole: StatsCardRole.superadmin,
              statsService: UnifiedStatsService(),
              roleFilter: _selectedFungsi,
              selectedBulan: null, // null = bulan sekarang
            ),
          ),
          const SizedBox(height: 12),

          // Pending Approvals Card
          if (_pendingApprovals > 0) const SizedBox(height: 12),

          // System Analytics Section
          _buildSectionHeader(
            icon: Icons.analytics_rounded,
            title: 'Analisis Sistem',
            gradient: const LinearGradient(colors: [primaryColor, accentColor]),
          ),
          const SizedBox(height: 8),
          SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: fade,
              child: AnalyticsSection(data: data),
            ),
          ),
          const SizedBox(height: 12),

          // User Distribution
          _buildSectionHeader(
            icon: Icons.people_rounded,
            title: 'Distribusi Pengguna',
            gradient: const LinearGradient(colors: [primaryColor, infoColor]),
          ),
          const SizedBox(height: 8),
          _buildAnimatedSection(
            child: UserDistribution(
              distribution: data.roleDistribution,
              verifiedUsers: data.verifiedUsers,
              lockedAccounts: data.lockedAccounts,
              activeToday: data.activeToday,
              getRoleColor: _service.getRoleColor,
            ),
          ),
          const SizedBox(height: 12),

          // Quick Actions
          _buildSectionHeader(
            icon: Icons.flash_on_rounded,
            title: 'Aksi Cepat',
            gradient: const LinearGradient(colors: [accentColor, infoColor]),
          ),
          const SizedBox(height: 8),
          _buildAnimatedSection(
            child: const QuickActions(),
          ),
          const SizedBox(height: 12),

          // Admin Menu
          _buildSectionHeader(
            icon: Icons.grid_view_rounded,
            title: 'Menu Utama',
            gradient: const LinearGradient(colors: [primaryDark, primaryColor]),
          ),
          const SizedBox(height: 8),
          _buildAnimatedSection(
            child: AdminMenu(data: data, service: _service),
          ),
          const SizedBox(height: 12),

          // Location Monitoring
          _buildSectionHeader(
            icon: Icons.location_on_rounded,
            title: 'Pemantauan Lokasi',
            gradient: const LinearGradient(colors: [successColor, primaryColor]),
          ),
          const SizedBox(height: 8),
          _buildAnimatedSection(
            child: const LocationMonitoring(),
          ),
          const SizedBox(height: 12),

          // Recent Activities
          _buildSectionHeader(
            icon: Icons.history_rounded,
            title: 'Aktivitas Terbaru',
            gradient: const LinearGradient(colors: [infoColor, primaryColor]),
          ),
          const SizedBox(height: 8),
          _buildAnimatedSection(
            child: RecentActivities(
              activities: _recentActivities,
              service: _service,
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // 🔥 Filter fungsi untuk superadmin
  Widget _buildFungsiFilter() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.filter_list_rounded,
        color: _selectedFungsi != 'semua' ? primaryColor : textSecondary,
        size: 20,
      ),
      onSelected: (value) {
        setState(() {
          _selectedFungsi = value;
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'semua',
          child: Row(
            children: [
              Icon(
                Icons.all_inclusive_rounded,
                size: 18,
                color: _selectedFungsi == 'semua' ? primaryColor : textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                'Semua Fungsi',
                style: TextStyle(
                  fontWeight: _selectedFungsi == 'semua' ? FontWeight.w700 : FontWeight.w500,
                  color: _selectedFungsi == 'semua' ? primaryColor : textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'mekanik',
          child: Row(
            children: [
              Icon(Icons.build_rounded, size: 18, color: Color(0xFFF97316)),
              SizedBox(width: 10),
              Text('Mekanik', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'hsse',
          child: Row(
            children: [
              Icon(Icons.health_and_safety_rounded, size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Text('HSSE', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'operator',
          child: Row(
            children: [
              Icon(Icons.precision_manufacturing_rounded, size: 18, color: Color(0xFF3B82F6)),
              SizedBox(width: 10),
              Text('Operator', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // WELCOME CARD
  // ═══════════════════════════════════════════════════════
  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryDark, primaryColor, accentColor],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.25),
                      blurRadius: 22,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  backgroundImage: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                      ? NetworkImage(_userPhotoUrl!)
                      : null,
                  child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty
                      ? Text(
                          _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _motivation,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildGlassBadge(
                icon: Icons.verified_rounded,
                text: _userRole.toUpperCase(),
              ),
              _buildGlassBadge(
                icon: Icons.calendar_today_rounded,
                text: _formatDate(DateTime.now()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBadge({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════
  Widget _buildAnimatedSection({required Widget child}) {
    final slide = _slideAnimation ?? const AlwaysStoppedAnimation(Offset.zero);
    final fade = _fadeAnimation ?? const AlwaysStoppedAnimation(1.0);
    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: fade, child: child),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Gradient gradient,
    Widget? trailing,
  }) {
    Color firstColor = gradient is LinearGradient
        ? gradient.colors.first
        : primaryColor;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: firstColor.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ═══════════════════════════════════════════════════════
// SUPER ADMIN PROVIDER
// ═══════════════════════════════════════════════════════
class SuperAdminProvider extends ChangeNotifier {
  final _service = DashboardService();
  bool isLoading = true;
  DashboardData? data;
  String? errorMessage;

  Future<void> loadData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      data = await _service.loadDashboardData();
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  void clearCache() {
    _service.clearCache();
    data = null;
  }
}