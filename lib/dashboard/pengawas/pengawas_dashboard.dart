// lib/dashboard/pengawas/pengawas_dashboard.dart
// 🔥 UPDATED - UniversalStatsCard integrated

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/services/pengawas_service.dart';
import '../../core/services/unified_stats_service.dart'; // 🔥 NEW
import '/widgets/pengawas/pengawas_stats_grid.dart'; // Keep for backward compatibility
import '/widgets/universal_stats_card.dart'; // 🔥 NEW
import '/widgets/team_summary.dart';
import '/widgets/menu/pengawas_menu.dart';
import '/widgets/bottom_nav/pengawas_bottom_nav.dart';
import '/widgets/pengawas/analytics_section.dart';
import '/widgets/superadmin/location_monitoring.dart';

class PengawasDashboard extends StatefulWidget {
  const PengawasDashboard({super.key});

  @override
  State<PengawasDashboard> createState() => _PengawasDashboardState();
}

class _PengawasDashboardState extends State<PengawasDashboard>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return ChangeNotifierProvider(
      create: (_) => PengawasProvider(),
      child: _PengawasBody(
        user: user,
        currentIndex: _currentIndex,
        pulseAnimation: _pulseAnimation,
      ),
    );
  }
}

class _PengawasBody extends StatefulWidget {
  final User? user;
  final int currentIndex;
  final Animation<double> pulseAnimation;

  const _PengawasBody({
    required this.user,
    required this.currentIndex,
    required this.pulseAnimation,
  });

  @override
  State<_PengawasBody> createState() => _PengawasBodyState();
}

class _PengawasBodyState extends State<_PengawasBody>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _service = PengawasService();
  final _scrollController = ScrollController();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  String _greeting = 'Selamat Datang';
  String _motivation = '';
  String _userName = '';
  String _userRole = '';
  String? _userPhotoUrl;
  bool _isGreetingLoading = true;
  bool _isRefreshing = false;
  Timer? _snackbarTimer;
  Timer? _greetingUpdateTimer;

  // 🔔 NOTIFICATION STATE
  int _unreadNotificationCount = 0;

  // Premium Color Palette
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

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
      _startAnimations();
    });

    _greetingUpdateTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateGreetingAndNotifications(),
    );
  }

  void _startAnimations() {
    if (mounted) {
      _fadeController.forward();
      _slideController.forward();
      _scaleController.forward();
    }
  }

  Future<void> _initializeDashboard() async {
    await _loadGreetingAndProfile();
    await _loadDashboardData();
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
          _unreadNotificationCount =
              notifs.where((n) => n['isRead'] == false).length;
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

      final greeting = results[0] as String;
      final motivation = results[1] as String;
      final profile = results[2] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _greeting = greeting;
          _motivation = motivation;
          _isGreetingLoading = false;
          if (profile != null) {
            _userName = profile['nama_lengkap']?.toString() ?? '';
            _userRole = profile['role']?.toString() ?? 'pengawas';
            _userPhotoUrl = profile['photo_url']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _greeting =
              '${_service.getGreeting()}, ${widget.user?.displayName ?? 'Pengawas'}! 👋';
          _motivation = 'Semoga harimu produktif! 💪';
          _isGreetingLoading = false;
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    final provider = context.read<PengawasProvider>();
    await provider.loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snackbarTimer?.cancel();
    _greetingUpdateTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing || !mounted) return;
    setState(() => _isRefreshing = true);

    try {
      final provider = context.read<PengawasProvider>();
      provider.clearCache();
      await provider.loadData();
      await _loadGreetingAndProfile();
      await _loadNotificationCount();

      if (mounted) {
        _fadeController.reset();
        _slideController.reset();
        _scaleController.reset();
        _fadeController.forward();
        _slideController.forward();
        _scaleController.forward();
      }

      if (mounted) {
        _showPremiumSnackBar(
          '✅ Data berhasil diperbarui',
          icon: Icons.check_circle_rounded,
          backgroundColor: successColor,
        );
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnackBar(
          '❌ Gagal memperbarui data',
          icon: Icons.error_rounded,
          backgroundColor: dangerColor,
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showPremiumSnackBar(
    String message, {
    required IconData icon,
    required Color backgroundColor,
  }) {
    if (!mounted) return;
    _snackbarTimer?.cancel();
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
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
            ],
          ),
        ),
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
      ),
    );
  }

  // 🔔 SHOW NOTIFICATIONS
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
                  gradient: const LinearGradient(
                    colors: [primaryColor, accentColor],
                  ),
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
                        gradient: const LinearGradient(
                          colors: [primaryColor, accentColor],
                        ),
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
                          gradient: const LinearGradient(
                            colors: [primaryColor, accentColor],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton.icon(
                          onPressed: () async {
                            await _service.markAllNotificationsRead();
                            if (mounted) {
                              context.read<PengawasProvider>().loadData();
                            }
                            await _loadNotificationCount();
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showPremiumSnackBar(
                              '✅ Semua notifikasi telah dibaca',
                              icon: Icons.check_circle_rounded,
                              backgroundColor: successColor,
                            );
                          },
                          icon: const Icon(
                            Icons.done_all_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Baca Semua',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
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
                          final notification = notifs[index];
                          final isRead = notification['isRead'] ?? false;

                          return TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: 1.0,
                            ),
                            duration: Duration(
                              milliseconds: 400 + (index * 100),
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 30 * (1 - value)),
                                child: Opacity(
                                  opacity: value,
                                  child: child,
                                ),
                              );
                            },
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
                                          color: primaryColor
                                              .withValues(alpha: 0.08),
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
                                                textTertiary
                                                    .withValues(alpha: 0.2),
                                                textTertiary
                                                    .withValues(alpha: 0.1),
                                              ],
                                            )
                                          : const LinearGradient(
                                              colors: [
                                                primaryColor,
                                                accentColor
                                              ],
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notification['title'] ?? 'Notifikasi',
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
                                          notification['body'] ?? '',
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
                                          _service.getTimeAgo(
                                              notification['createdAt']),
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
                                            color: primaryColor
                                                .withValues(alpha: 0.3),
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
    final provider = context.watch<PengawasProvider>();
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (provider.isLoading || _isGreetingLoading) {
      return Scaffold(
        backgroundColor: bgPrimary,
        bottomNavigationBar:
            PengawasBottomNav(currentIndex: widget.currentIndex),
        body: _buildPremiumLoadingScreen(statusBarHeight),
      );
    }

    if (provider.data == null) {
      return Scaffold(
        backgroundColor: bgPrimary,
        bottomNavigationBar:
            PengawasBottomNav(currentIndex: widget.currentIndex),
        body:
            _buildPremiumErrorScreen(provider.errorMessage, statusBarHeight),
      );
    }

    final data = provider.data!;

    return Scaffold(
      backgroundColor: bgPrimary,
      bottomNavigationBar:
          PengawasBottomNav(currentIndex: widget.currentIndex),
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
            SliverToBoxAdapter(
              child: _buildHeader(statusBarHeight),
            ),
            _buildPremiumContent(data, bottomPadding),
          ],
        ),
      ),
      floatingActionButton:
          data.isCheckedIn ? _buildPremiumFAB(data) : null,
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
                Icons.shield_rounded,
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
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  'Pengawas',
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
  // LOADING SCREEN
  // ═══════════════════════════════════════════════════════
  Widget _buildPremiumLoadingScreen(double statusBarHeight) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primaryColor, accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
                      Icons.shield_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                );
              },
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
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ERROR SCREEN
  // ═══════════════════════════════════════════════════════
  Widget _buildPremiumErrorScreen(
      String? errorMessage, double statusBarHeight) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
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
                  );
                },
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
                  gradient: const LinearGradient(
                    colors: [primaryColor, accentColor],
                  ),
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
                    final provider = context.read<PengawasProvider>();
                    provider.clearCache();
                    provider.loadData();
                    _loadGreetingAndProfile();
                    _loadNotificationCount();
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // FAB
  // ═══════════════════════════════════════════════════════
  Widget _buildPremiumFAB(PengawasDashboardData data) {
    return FloatingActionButton.extended(
      onPressed: () async {
        if (data.activeLembur?['check_in'] != null) {
          final checkIn =
              (data.activeLembur!['check_in'] as Timestamp).toDate();
          final totalJam =
              DateTime.now().difference(checkIn).inHours.toDouble();
          await _service.checkOut(data.activeLembur!['id'], totalJam);
          if (mounted) {
            context.read<PengawasProvider>().loadData();
            await _loadNotificationCount();
            _showPremiumSnackBar(
              '✅ Check-out berhasil! Total: ${totalJam.toStringAsFixed(1)} jam',
              icon: Icons.check_circle_rounded,
              backgroundColor: successColor,
            );
          }
        }
      },
      backgroundColor: dangerColor,
      foregroundColor: Colors.white,
      elevation: 8,
      icon: const Icon(Icons.logout_rounded, size: 20),
      label: const Text(
        'Check-out',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // MAIN CONTENT
  // ═══════════════════════════════════════════════════════
  Widget _buildPremiumContent(
      PengawasDashboardData data, double bottomPadding) {
    final slide = _slideAnimation;
    final fade = _fadeAnimation;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 100 + bottomPadding),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // 1️⃣ Welcome Card
          SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: fade,
              child: _buildPremiumWelcomeCard(),
            ),
          ),
          const SizedBox(height: 16),

          // 🔥🔥🔥 2️⃣ UNIVERSAL STATS CARD (GANTI PengawasStatsGrid)
          _buildPremiumSectionHeader(
            icon: Icons.dashboard_rounded,
            title: 'Ringkasan Lembur',
            gradient: const LinearGradient(
              colors: [primaryColor, accentColor],
            ),
          ),
          const SizedBox(height: 6),
          _buildAnimatedSection(
            child: UniversalStatsCard(
              cardRole: StatsCardRole.pengawas,
              statsService: UnifiedStatsService(),
              userId: widget.user?.uid,
              selectedBulan: null,
            ),
          ),
          const SizedBox(height: 20),

          // 3️⃣ Analytics Section
          _buildPremiumSectionHeader(
            icon: Icons.trending_up_rounded,
            title: 'Analisis Lembur',
            gradient: const LinearGradient(
              colors: [primaryColor, infoColor],
            ),
          ),
          const SizedBox(height: 12),
          SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: fade,
              child: AnalyticsSection(data: data),
            ),
          ),
          const SizedBox(height: 24),

          // 4️⃣ Menu Utama
          _buildPremiumSectionHeader(
            icon: Icons.grid_view_rounded,
            title: 'Menu Utama',
            gradient: const LinearGradient(
              colors: [accentColor, infoColor],
            ),
          ),
          const SizedBox(height: 12),
          PengawasMenu(data: data, service: _service),
          const SizedBox(height: 24),

          // 5️⃣ Monitoring Lokasi
          _buildPremiumSectionHeader(
            icon: Icons.location_on_rounded,
            title: 'Pemantauan',
            gradient: const LinearGradient(
              colors: [Colors.deepOrange, Colors.orange],
            ),
          ),
          const SizedBox(height: 12),
          SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: fade,
              child: const LocationMonitoring(
                userRole: 'pengawas',
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 6️⃣ Ringkasan Tim
          _buildPremiumSectionHeader(
            icon: Icons.people_rounded,
            title: 'Ringkasan Tim',
            gradient: const LinearGradient(
              colors: [successColor, infoColor],
            ),
          ),
          const SizedBox(height: 12),
          TeamSummary(
            teamMembers: data.teamMembers,
            totalMembers: data.totalTeamMembers,
            onlineMembers: data.onlineMembers,
            getRoleColor: (role) => _service.getRoleColor(role),
            accentColor: primaryColor,
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // WELCOME CARD
  // ═══════════════════════════════════════════════════════
  Widget _buildPremiumWelcomeCard() {
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
                  backgroundImage: _userPhotoUrl != null &&
                          _userPhotoUrl!.isNotEmpty
                      ? NetworkImage(_userPhotoUrl!)
                      : null,
                  child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty
                      ? Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'P',
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

  Widget _buildGlassBadge({
    required IconData icon,
    required String text,
  }) {
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
  // SECTION HEADER
  // ═══════════════════════════════════════════════════════
  Widget _buildPremiumSectionHeader({
    required IconData icon,
    required String title,
    required Gradient gradient,
    Widget? trailing,
  }) {
    Color firstColor = gradient.colors.first;
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

  // ═══════════════════════════════════════════════════════
  // ANIMATED SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildAnimatedSection({required Widget child}) {
    final slide = _slideAnimation;
    final fade = _fadeAnimation;
    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: fade, child: child),
    );
  }

  // ═══════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ═══════════════════════════════════════════════════════
// PENGAWAS PROVIDER
// ═══════════════════════════════════════════════════════
class PengawasProvider extends ChangeNotifier {
  final _service = PengawasService();
  bool isLoading = true;
  PengawasDashboardData? data;
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
    data = null;
  }
}