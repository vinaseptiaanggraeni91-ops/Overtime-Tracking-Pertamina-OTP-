// lib/dashboard/manager/manager_dashboard.dart
// 🛡️ FINAL VERSION: Data dibatalkan TIDAK MUNCUL di dashboard manager
// 🔥 UPDATED: UniversalStatsCard integrated
// 🔥 FIX: Menggunakan lembur_mitra untuk data risiko, bukan pengajuan_lembur
// 🔥 FIX: Navigasi menggunakan go_router
// 🔥 FIX: Double-verify HSSE status dari Firestore langsung
// 🔥 FIX: Query ganda untuk risiko (flagged + pending_hsse)

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/manager_service.dart';
import '../../core/services/unified_stats_service.dart'; // 🔥 NEW
import '/widgets/team_summary.dart';
import '/widgets/menu/manager_menu.dart';
import '/widgets/bottom_nav/manager_bottom_nav.dart';
import '../../widgets/manager/manager_stats_grid.dart'; // Keep for backward compatibility
import '../../widgets/universal_stats_card.dart'; // 🔥 NEW
import '../../widgets/manager/manager_pending_section.dart';
import '../../widgets/manager/manager_section_helper.dart';
import '/core/services/overtime_approval_service.dart';
import '/widgets/superadmin/location_monitoring.dart' hide AnimatedBuilder;

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard>
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
      create: (_) => ManagerProvider(),
      child: _ManagerBody(
        user: user,
        currentIndex: _currentIndex,
        pulseAnimation: _pulseAnimation,
      ),
    );
  }
}

class _ManagerBody extends StatefulWidget {
  final User? user;
  final int currentIndex;
  final Animation<double> pulseAnimation;

  const _ManagerBody({
    required this.user,
    required this.currentIndex,
    required this.pulseAnimation,
  });

  @override
  State<_ManagerBody> createState() => _ManagerBodyState();
}

class _ManagerBodyState extends State<_ManagerBody>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _service = ManagerService();
  final _scrollController = ScrollController();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _greeting = 'Selamat Datang';
  String _motivation = '';
  String _userName = '';
  String _userRole = '';
  String? _userPhotoUrl;
  String? _userFungsi; // 🔥 Untuk UniversalStatsCard
  bool _isGreetingLoading = true;
  bool _isRefreshing = false;
  Timer? _snackbarTimer;
  Timer? _greetingUpdateTimer;

  int _unreadNotificationCount = 0;
  List<Map<String, dynamic>> _notifications = [];

  // 🔥 HSSE STATE
  bool _isHSSEManager = false;
  int _highRiskPending = 0;
  int _mediumRiskPending = 0;
  int _lowRiskPending = 0;
  int _totalRiskSubmissions = 0;
  bool _hasUrgentRisk = false;

  List<Map<String, dynamic>> _hssePendingList = [];

  StreamSubscription? _hssSubscription;
  StreamSubscription? _hssePendingSubscription;
  StreamSubscription? _notificationSubscription;
  Timer? _riskRefreshTimer;

  static const List<String> _excludedStatuses = [
    'dibatalkan', 'canceled', 'ditolak', 'rejected', 'draft'
  ];

  static const List<String> _approvedStatuses = ['disetujui', 'approved'];
  static const List<String> _rejectedStatuses = ['ditolak', 'rejected'];

  static const List<String> _pendingHSSEStatuses = [
    'pending_hsse',
    'manager_approved_pending_hsse',
    'manager_approval_pending_hsse',
  ];

  static const Color primaryColor = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color accentColor = Color(0xFF42A5F5);
  static const Color successColor = Color(0xFF43A047);
  static const Color dangerColor = Color(0xFFEF5350);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color infoColor = Color(0xFF29B6F6);
  static const Color highRiskColor = Color(0xFFFF3B3B);

  static const Color bgPrimary = Color(0xFFF5F9FF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color textTertiary = Color(0xFF90A4AE);
  static const Color borderLight = Color(0xFFE3E8F0);

  bool _isStatusExcluded(String? status) {
    if (status == null) return false;
    return _excludedStatuses.contains(status.toLowerCase().trim());
  }

  bool _isStatusFinished(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase().trim();
    return _approvedStatuses.contains(s) || _rejectedStatuses.contains(s);
  }

  bool _isPendingHSSE(String? status) {
    if (status == null) return false;
    return _pendingHSSEStatuses.contains(status.toLowerCase().trim());
  }

  void _navigateToApproval({String? filter}) {
    if (filter != null && filter.isNotEmpty) {
      context.go('/approval?filter=$filter');
    } else {
      context.go('/approval');
    }
  }

  void _navigateToRiskDetail(String id) {
    context.go('/risk-detail?id=$id');
  }

  void _navigateToMyTeam() {
    context.go('/my-team');
  }

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController, curve: Curves.easeOutCubic);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _slideController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
      _startAnimations();
      _setupNotificationListener();
    });

    _greetingUpdateTimer = Timer.periodic(
      const Duration(minutes: 1), (_) => _updateGreeting());
    _riskRefreshTimer = Timer.periodic(
      const Duration(minutes: 5), (_) => _loadHSSEData());
  }

  void _startAnimations() {
    if (mounted) {
      _fadeController.forward();
      _slideController.forward();
      _scaleController.forward();
    }
  }

  void _setupNotificationListener() {
    _notificationSubscription?.cancel();
    _notificationSubscription =
        _service.getNotificationsStream().listen((notifs) {
      if (!mounted) return;
      setState(() {
        _notifications = notifs;
        _unreadNotificationCount =
            notifs.where((n) => n['isRead'] == false).length;
      });
    });
  }

  Future<void> _initializeDashboard() async {
    debugPrint('🚀 ========== INITIALIZING MANAGER DASHBOARD ==========');
    await _loadGreetingAndProfile();
    await _verifyHSSEStatusFromFirestore();
    await _loadDashboardData();
    await _loadNotificationCount();

    if (_isHSSEManager) {
      debugPrint('🛡️ HSSE Manager detected - Loading HSSE data...');
      setState(() {
        _totalRiskSubmissions = 0;
        _highRiskPending = 0;
        _mediumRiskPending = 0;
        _lowRiskPending = 0;
        _hasUrgentRisk = false;
        _hssePendingList = [];
      });
      await _loadHSSEData();
      _setupHSSERealTimeListener();
      _setupHSSEPendingListListener();
    } else {
      debugPrint('👔 Standard Manager - No HSSE features');
    }
    debugPrint('🚀 ========== DASHBOARD INITIALIZED ==========');
  }

  Future<void> _verifyHSSEStatusFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      final role = (data['role'] ?? '').toString().toLowerCase().trim();
      final fungsi = (data['fungsi'] ?? '').toString().toLowerCase().trim();
      final jabatan = (data['jabatan'] ?? '').toString().toLowerCase().trim();
      final bidang = (data['bidang'] ?? '').toString().toLowerCase().trim();

      final isHSSE = role.contains('hsse') || role.contains('hse') ||
          role.contains('safety') || role.contains('k3') ||
          fungsi == 'hsse' || fungsi == 'hse' ||
          fungsi.contains('safety') || fungsi.contains('k3') ||
          jabatan.contains('hsse') || jabatan.contains('hse') ||
          jabatan.contains('safety') || jabatan.contains('k3') ||
          bidang.contains('hsse') || bidang.contains('hse');

      if (mounted && isHSSE != _isHSSEManager) {
        setState(() {
          _isHSSEManager = isHSSE;
        });
      }
    } catch (e) {
      debugPrint('❌ Error verifying HSSE from Firestore: $e');
    }
  }

  Future<void> _updateGreeting() async {
    try {
      final userData = await _service.getUserData();
      if (mounted) {
        setState(() {
          _userName = userData['nama_lengkap']?.toString() ?? '';
          _greeting =
              '${_service.getGreeting()}, $_userName! ${_service.getGreetingEmoji()}';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGreetingAndProfile() async {
    try {
      final userData = await _service.getUserData();
      if (mounted) {
        setState(() {
          _userName = userData['nama_lengkap']?.toString() ?? '';
          _userRole = userData['role']?.toString() ?? 'manager';
          _userPhotoUrl = userData['photo_url']?.toString();
          _greeting =
              '${_service.getGreeting()}, $_userName! ${_service.getGreetingEmoji()}';
          _motivation = _getRandomMotivation();

          _userFungsi = userData['fungsi']?.toString().toLowerCase() ?? '';
          final roleLower = _userRole.toLowerCase();

          _isHSSEManager = roleLower.contains('hsse') ||
              roleLower.contains('hse') ||
              roleLower.contains('safety') ||
              roleLower.contains('k3') ||
              _userFungsi == 'hsse' ||
              _userFungsi == 'hse' ||
              _userFungsi!.contains('safety') ||
              _userFungsi!.contains('k3');

          _isGreetingLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _greeting =
              '${_service.getGreeting()}, ${widget.user?.displayName ?? 'Manager'}! 👋';
          _motivation = _isHSSEManager
              ? 'Utamakan keselamatan kerja! 🛡️'
              : 'Pimpin tim dengan bijak! 💪';
          _isGreetingLoading = false;
        });
      }
    }
  }

  String _getRandomMotivation() {
    if (_isHSSEManager) {
      final motivations = [
        'Keselamatan adalah prioritas utama! 🛡️',
        'Setiap risiko harus dikelola dengan baik! ⚠️',
        'Ciptakan lingkungan kerja yang aman! 🏗️',
        'Zero accident adalah tujuan kita! 🎯',
        'Lindungi setiap pekerja di lapangan! 💪',
      ];
      return motivations[Random().nextInt(motivations.length)];
    }
    final motivations = [
      'Pemimpin hebat menciptakan pemimpin lainnya! 🌟',
      'Tim yang solid adalah kunci kesuksesan! 🎯',
      'Setiap keputusan Anda membentuk masa depan! 💼',
      'Bimbing tim Anda menuju keunggulan! 🚀',
      'Kepemimpinan adalah tentang memberikan contoh! ✨',
    ];
    return motivations[Random().nextInt(motivations.length)];
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    final provider = context.read<ManagerProvider>();
    await provider.loadData();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final notifs = await _service.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _unreadNotificationCount =
              notifs.where((n) => n['isRead'] == false).length;
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat notifikasi: $e');
    }
  }

  Future<void> _showNotifications() async {
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
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
                width: 40, height: 4,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryColor, accentColor]),
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
                          colors: [primaryColor, accentColor]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.notifications_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Notifikasi',
                        style: TextStyle(fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.5)),
                    ),
                    if (_notifications.any((n) => n['isRead'] == false))
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [primaryColor, accentColor]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton.icon(
                          onPressed: () async {
                            await _service.markAllNotificationsRead();
                            if (mounted) {
                              context.read<ManagerProvider>().loadData();
                            }
                            await _loadNotificationCount();
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showPremiumSnackBar(
                              '✅ Semua notifikasi telah dibaca',
                              icon: Icons.check_circle_rounded,
                              backgroundColor: successColor,
                            );
                          },
                          icon: const Icon(Icons.done_all_rounded,
                              size: 18, color: Colors.white),
                          label: const Text('Baca Semua',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  primaryColor.withValues(alpha: 0.1),
                                  accentColor.withValues(alpha: 0.1)]),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.notifications_none_rounded,
                                  size: 48, color: textTertiary),
                            ),
                            const SizedBox(height: 16),
                            Text('Belum ada notifikasi',
                              style: TextStyle(color: textTertiary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _notifications.length,
                        itemBuilder: (ctx, index) {
                          final n = _notifications[index];
                          final isRead = n['isRead'] ?? false;
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration:
                                Duration(milliseconds: 400 + (index * 100)),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 30 * (1 - value)),
                                child: Opacity(
                                  opacity: value.clamp(0.0, 1.0),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isRead ? surfaceColor
                                    : primaryColor.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isRead ? borderLight
                                      : primaryColor.withValues(alpha: 0.15)),
                                boxShadow: isRead ? null : [
                                  BoxShadow(
                                    color: primaryColor
                                        .withValues(alpha: 0.08),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4))],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: isRead
                                          ? LinearGradient(colors: [
                                              textTertiary.withValues(alpha: 0.2),
                                              textTertiary.withValues(alpha: 0.1)])
                                          : const LinearGradient(
                                              colors: [primaryColor, accentColor]),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isRead ? Icons.notifications_outlined
                                          : Icons.notifications_rounded,
                                      size: 18, color: Colors.white),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(n['title'] ?? 'Notifikasi',
                                          style: TextStyle(
                                            fontWeight: isRead
                                                ? FontWeight.w500 : FontWeight.w700,
                                            fontSize: 14, color: textPrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text(n['body'] ?? '',
                                          style: TextStyle(fontSize: 12,
                                              color: textSecondary, height: 1.5),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 8),
                                        Text(_service.getTimeAgo(n['createdAt']),
                                          style: TextStyle(fontSize: 10,
                                              color: textTertiary,
                                              fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 10, height: 10,
                                      margin: const EdgeInsets.only(top: 8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [primaryColor, accentColor]),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor
                                                .withValues(alpha: 0.3),
                                            blurRadius: 8)]),
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

  void _setupHSSEPendingListListener() {
    if (!_isHSSEManager) return;
    _hssePendingSubscription?.cancel();
    _hssePendingSubscription = FirebaseFirestore.instance
        .collection('lembur_mitra')
        .where('is_flagged_for_hsse', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final pendingList = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        final status = (data['status'] as String? ?? '').toLowerCase().trim();
        if (_isStatusExcluded(status) || _isStatusFinished(status)) continue;
        pendingList.add(data);
      }
      if (mounted) setState(() => _hssePendingList = pendingList);
    });
  }

  Future<void> _loadHSSEData() async {
    if (!_isHSSEManager) return;
    try {
      final flaggedSnapshot = await FirebaseFirestore.instance
          .collection('lembur_mitra')
          .where('is_flagged_for_hsse', isEqualTo: true)
          .get();

      final pendingHSSESnapshot = await FirebaseFirestore.instance
          .collection('lembur_mitra')
          .where('status', whereIn: _pendingHSSEStatuses)
          .get();

      final allDocs = <String, Map<String, dynamic>>{};
      for (var doc in flaggedSnapshot.docs) {
        allDocs[doc.id] = Map<String, dynamic>.from(doc.data());
      }
      for (var doc in pendingHSSESnapshot.docs) {
        if (!allDocs.containsKey(doc.id)) {
          allDocs[doc.id] = Map<String, dynamic>.from(doc.data());
        }
      }

      int highPending = 0, mediumPending = 0, lowPending = 0;

      for (var entry in allDocs.entries) {
        final data = entry.value;
        final status = (data['status'] as String? ?? '').toLowerCase().trim();
        if (_isStatusExcluded(status) || _isStatusFinished(status)) continue;

        final riskLevel = _extractRiskLevel(data);
        if (riskLevel.contains('high') || riskLevel.contains('tinggi') ||
            riskLevel.contains('critical')) {
          highPending++;
        } else if (riskLevel.contains('medium') || riskLevel.contains('sedang')) {
          mediumPending++;
        } else {
          lowPending++;
        }
      }

      final total = highPending + mediumPending + lowPending;
      if (mounted) {
        setState(() {
          _highRiskPending = highPending;
          _mediumRiskPending = mediumPending;
          _lowRiskPending = lowPending;
          _totalRiskSubmissions = total;
          _hasUrgentRisk = highPending > 0;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading HSSE data: $e');
      if (mounted) {
        setState(() {
          _totalRiskSubmissions = 0;
          _highRiskPending = 0;
          _mediumRiskPending = 0;
          _lowRiskPending = 0;
          _hasUrgentRisk = false;
        });
      }
    }
  }

  String _extractRiskLevel(Map<String, dynamic> data) {
    if (data['risk_level'] != null) {
      return data['risk_level'].toString().toLowerCase();
    }
    if (data['risk_assessment'] != null && data['risk_assessment'] is Map) {
      final riskAssess = data['risk_assessment'];
      return (riskAssess['kategori_risiko'] ?? riskAssess['risk_level'] ?? '')
          .toString().toLowerCase();
    }
    if (data['risk_category'] != null) {
      return data['risk_category'].toString().toLowerCase();
    }
    if (data['risk_rating'] != null && data['risk_rating'] is num) {
      final rating = data['risk_rating'] as num;
      if (rating >= 15) return 'high';
      if (rating >= 8) return 'medium';
      return 'low';
    }
    return 'low';
  }

  void _setupHSSERealTimeListener() {
    if (!_isHSSEManager) return;
    _hssSubscription?.cancel();
    _hssSubscription = FirebaseFirestore.instance
        .collection('lembur_mitra')
        .where('is_flagged_for_hsse', isEqualTo: true)
        .snapshots()
        .listen((_) {
      if (mounted) _loadHSSEData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snackbarTimer?.cancel();
    _greetingUpdateTimer?.cancel();
    _riskRefreshTimer?.cancel();
    _hssSubscription?.cancel();
    _hssePendingSubscription?.cancel();
    _notificationSubscription?.cancel();
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
      final provider = context.read<ManagerProvider>();
      provider.clearCache();
      await provider.loadData();
      await _loadGreetingAndProfile();
      await _verifyHSSEStatusFromFirestore();
      await _loadNotificationCount();
      if (_isHSSEManager) await _loadHSSEData();

      if (mounted) {
        _fadeController.reset(); _slideController.reset(); _scaleController.reset();
        _fadeController.forward(); _slideController.forward(); _scaleController.forward();
      }
      if (mounted) {
        _showPremiumSnackBar('✅ Data berhasil diperbarui',
          icon: Icons.check_circle_rounded, backgroundColor: successColor);
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnackBar('❌ Gagal memperbarui data',
          icon: Icons.error_rounded, backgroundColor: dangerColor);
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showPremiumSnackBar(String message,
      {required IconData icon, required Color backgroundColor}) {
    if (!mounted) return;
    _snackbarTimer?.cancel();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: Colors.white, letterSpacing: -0.2))),
      ]),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.only(left: 20, right: 20,
          bottom: MediaQuery.of(context).size.height * 0.12),
      duration: const Duration(seconds: 3),
      elevation: 8,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)));
  }

  Future<void> _approveLembur(Map<String, dynamic> item) async {
    try {
      final id = item['id']?.toString() ?? item['group_id']?.toString() ?? '';
      if (id.isEmpty) {
        _showPremiumSnackBar('❌ ID pengajuan tidak valid',
            icon: Icons.error_rounded, backgroundColor: dangerColor);
        return;
      }
      await _service.approveLemburById(id);
      if (mounted) {
        _showPremiumSnackBar('✅ Pengajuan berhasil disetujui',
            icon: Icons.check_circle_rounded, backgroundColor: successColor);
        await _refreshData();
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnackBar(_formatError(e.toString()),
            icon: Icons.error_rounded, backgroundColor: dangerColor);
      }
    }
  }

  Future<void> _rejectLembur(Map<String, dynamic> item) async {
    try {
      final id = item['id']?.toString() ?? item['group_id']?.toString() ?? '';
      if (id.isEmpty) {
        _showPremiumSnackBar('❌ ID pengajuan tidak valid',
            icon: Icons.error_rounded, backgroundColor: dangerColor);
        return;
      }
      if (mounted) {
        final reason = await _showRejectReasonDialog();
        if (reason != null) {
          await _service.rejectLemburById(id, reason: reason);
          if (mounted) {
            _showPremiumSnackBar('❌ Pengajuan berhasil ditolak',
                icon: Icons.cancel_rounded, backgroundColor: warningColor);
            await _refreshData();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnackBar(_formatError(e.toString()),
            icon: Icons.error_rounded, backgroundColor: dangerColor);
      }
    }
  }

  String _formatError(String error) {
    if (error.contains('dibatalkan') || error.contains('canceled'))
      return '❌ Pengajuan ini sudah dibatalkan oleh pengawas';
    if (error.contains('ditolak') || error.contains('rejected'))
      return '❌ Pengajuan ini sudah ditolak sebelumnya';
    if (error.contains('sudah diproses'))
      return '❌ Pengajuan ini sudah diproses sebelumnya';
    if (error.contains('tidak valid'))
      return '❌ Pengajuan sudah tidak valid untuk diproses';
    return '❌ Gagal: $error';
  }

  Future<String?> _showRejectReasonDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Alasan Penolakan'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Masukkan alasan penolakan...',
            border: OutlineInputBorder()),
          maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerColor, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
            child: const Text('Tolak')),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildGlassBadge({
    required IconData icon, required String text, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.25), width: 1.2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color ?? Colors.white, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
            style: TextStyle(color: color ?? Colors.white, fontSize: 12,
                fontWeight: FontWeight.w700, letterSpacing: 0.3),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _buildPremiumSectionHeader({
    required IconData icon, required String title,
    required Gradient gradient, Widget? trailing}) {
    Color firstColor = gradient.colors.first;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: gradient, borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: firstColor.withValues(alpha: 0.2),
                blurRadius: 15, offset: const Offset(0, 4))]),
        child: Icon(icon, color: Colors.white, size: 20)),
      const SizedBox(width: 14),
      Expanded(
        child: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
              color: textPrimary, letterSpacing: -0.3))),
      if (trailing != null) trailing,
    ]);
  }

  Widget _buildPremiumLoadingScreen(double statusBarHeight) {
    return SafeArea(
      child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value.clamp(0.0, 1.5),
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [primaryColor, accentColor]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 40, spreadRadius: 5)]),
                child: const Icon(Icons.manage_accounts_rounded,
                    size: 48, color: Colors.white)))),
          const SizedBox(height: 32),
          Shimmer.fromColors(
            baseColor: borderLight, highlightColor: surfaceColor,
            child: Column(children: [
              Container(width: 200, height: 8,
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              Container(width: 160, height: 8,
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(4)))])),
          const SizedBox(height: 24),
          SizedBox(
            width: 32, height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                  primaryColor.withValues(alpha: 0.8))))])));
  }

  Widget _buildPremiumErrorScreen(String? errorMessage, double statusBarHeight) {
    return SafeArea(
      child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Transform.scale(
              scale: value.clamp(0.0, 1.0),
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    dangerColor.withValues(alpha: 0.1),
                    warningColor.withValues(alpha: 0.1)]),
                  shape: BoxShape.circle),
                child: const Icon(Icons.wifi_off_rounded,
                    size: 48, color: dangerColor)))),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
                colors: [dangerColor, warningColor]).createShader(bounds),
            child: const Text('Gagal Memuat Data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: Colors.white))),
          const SizedBox(height: 12),
          Text(errorMessage ?? 'Terjadi kesalahan.\nSilakan coba lagi.',
            style: const TextStyle(color: textSecondary, fontSize: 14,
                height: 1.6), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [primaryColor, accentColor]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 20, offset: const Offset(0, 8))]),
            child: ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Coba Lagi',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0)))]))));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerProvider>();
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (provider.isLoading || _isGreetingLoading) {
      return Scaffold(
        backgroundColor: bgPrimary,
        bottomNavigationBar:
            ManagerBottomNav(currentIndex: widget.currentIndex),
        body: _buildPremiumLoadingScreen(statusBarHeight));
    }

    if (provider.data == null) {
      return Scaffold(
        backgroundColor: bgPrimary,
        bottomNavigationBar:
            ManagerBottomNav(currentIndex: widget.currentIndex),
        body: _buildPremiumErrorScreen(provider.errorMessage, statusBarHeight));
    }

    final data = provider.data!;

    return Scaffold(
      backgroundColor: bgPrimary,
      bottomNavigationBar:
          ManagerBottomNav(currentIndex: widget.currentIndex),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: _isHSSEManager && _hasUrgentRisk ? highRiskColor : primaryColor,
        backgroundColor: surfaceColor,
        strokeWidth: 3,
        displacement: statusBarHeight + 30,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
                child: _buildPremiumHeader(statusBarHeight)),
            _buildPremiumContent(data, bottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(double statusBarHeight) {
    return Container(
      padding: EdgeInsets.only(
          top: statusBarHeight + 16, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.03),
            accentColor.withValues(alpha: 0.03),
            infoColor.withValues(alpha: 0.03)])),
      child: Row(children: [
        AnimatedBuilder(
          animation: widget.pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _isHSSEManager && _hasUrgentRisk
                ? widget.pulseAnimation.value * 1.05
                : widget.pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surfaceColor, borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: primaryColor.withValues(alpha: 0.1),
                      blurRadius: 20, offset: const Offset(0, 4))],
                border: Border.all(
                    color: primaryColor.withValues(alpha: 0.08), width: 1)),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                    colors: [primaryColor, accentColor]).createShader(bounds),
                child: Icon(
                  _isHSSEManager
                      ? Icons.security_rounded : Icons.manage_accounts_rounded,
                  color: Colors.white, size: 24))))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                    colors: [primaryColor, accentColor]).createShader(bounds),
                child: const Text('Dashboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -0.5))),
              Row(children: [
                Text(_isHSSEManager ? 'Manager HSSE' : 'Manager',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: textTertiary, letterSpacing: 2)),
                if (_isHSSEManager && _totalRiskSubmissions > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: highRiskColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4)),
                    child: Text('⚠️ $_totalRiskSubmissions RISIKO',
                      style: const TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: highRiskColor)))]]),
            ])),
        _buildQuickActionButton(
          icon: Icons.notifications_outlined,
          onTap: _showNotifications,
          badge: _unreadNotificationCount > 0
              ? '$_unreadNotificationCount' : null)]));
  }

  Widget _buildQuickActionButton({
    required IconData icon, required VoidCallback onTap, String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surfaceColor, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderLight),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10, offset: const Offset(0, 2))]),
        child: Stack(children: [
          Icon(icon, color: textSecondary, size: 22),
          if (badge != null)
            Positioned(
              top: -2, right: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: dangerColor, shape: BoxShape.circle),
                child: Text(badge,
                  style: const TextStyle(color: Colors.white, fontSize: 8,
                      fontWeight: FontWeight.w700))))])));
  }

  Widget _buildPremiumContent(
      ManagerDashboardData data, double bottomPadding) {
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
                opacity: fade, child: _buildPremiumWelcomeCard())),
          const SizedBox(height: 16),

          // 🔥🔥🔥 2️⃣ UNIVERSAL STATS CARD (GANTI ManagerStatsGrid)
          _buildPremiumSectionHeader(
            icon: Icons.dashboard_rounded,
            title: _isHSSEManager ? 'Ringkasan Kinerja & HSSE' : 'Ringkasan Kinerja',
            gradient: const LinearGradient(colors: [primaryColor, accentColor]),
          ),
          const SizedBox(height: 6),
          _buildAnimatedSection(
            child: UniversalStatsCard(
              cardRole: _isHSSEManager ? StatsCardRole.managerHSSE : StatsCardRole.manager,
              statsService: UnifiedStatsService(),
              fungsi: _userFungsi,
              selectedBulan: null,
            ),
          ),
          const SizedBox(height: 20),

          // 3️⃣ Pending Section
          _buildPremiumSectionHeader(
            icon: _isHSSEManager
                ? Icons.security_rounded : Icons.pending_actions_rounded,
            title: _isHSSEManager
                ? 'Persetujuan & Risiko' : 'Persetujuan Lembur',
            gradient: const LinearGradient(colors: [primaryColor, accentColor]),
            trailing: _isHSSEManager && _totalRiskSubmissions > 0
                ? _buildHSSERiskBadge() : null),
          const SizedBox(height: 12),
          ManagerPendingSection(
            pendingList: data.pendingList,
            getTimeAgo: _service.getTimeAgo,
            onApprove: _approveLembur,
            onReject: _rejectLembur,
            isHSSEManager: _isHSSEManager,
            showHSSESection: _isHSSEManager,
            hssePendingList: _hssePendingList,
            showRiskIndicator: _isHSSEManager,
            enableSwipeActions: true,
            showDetailedInfo: _isHSSEManager,
            maxItemsToShow: _isHSSEManager ? 10 : 5,
            onViewAll: () {
              if (_isHSSEManager) {
                _navigateToApproval(filter: 'berisiko');
              } else {
                _navigateToApproval();
              }
            },
            onRiskTap: (item) {
              final id = item['id']?.toString() ??
                  item['group_id']?.toString() ?? '';
              if (id.isNotEmpty) _navigateToRiskDetail(id);
            },
            emptyStateMessage: _isHSSEManager
                ? '✅ Tidak ada pengajuan berisiko'
                : '✅ Tidak ada pengajuan pending'),
          const SizedBox(height: 24),

          // 4️⃣ Menu Utama
          _buildPremiumSectionHeader(
            icon: Icons.grid_view_rounded,
            title: 'Menu Utama',
            gradient: const LinearGradient(colors: [accentColor, infoColor])),
          const SizedBox(height: 12),
          ManagerMenu(data: data, service: _service),
          const SizedBox(height: 24),

          // 5️⃣ Pemantauan Lokasi Tim
          _buildPremiumSectionHeader(
            icon: Icons.location_on_rounded,
            title: 'Pemantauan',
            gradient: const LinearGradient(
                colors: [primaryColor, accentColor])),
          const SizedBox(height: 12),
          SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: fade,
              child: LocationMonitoring(
                userRole: _isHSSEManager ? 'manager_hsse' : 'manager'))),
          const SizedBox(height: 24),

          // 6️⃣ Ringkasan Tim
          _buildPremiumSectionHeader(
            icon: Icons.people_rounded,
            title: 'Ringkasan Tim',
            gradient: const LinearGradient(
                colors: [successColor, infoColor])),
          const SizedBox(height: 12),
          TeamSummary(
            teamMembers: data.teamMembers,
            totalMembers: data.totalTeamMembers,
            onlineMembers: data.onlineMembers,
            getRoleColor: _service.getRoleColor,
            accentColor: primaryColor,
            onViewAll: _navigateToMyTeam),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _buildAnimatedSection({required Widget child}) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: child));
  }

  Widget _buildHSSERiskBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highRiskColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: highRiskColor.withValues(alpha: 0.3), width: 1.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.priority_high_rounded,
            color: highRiskColor, size: 16),
        const SizedBox(width: 6),
        Text('$_totalRiskSubmissions Risiko',
          style: const TextStyle(color: highRiskColor, fontSize: 11,
              fontWeight: FontWeight.w800))]));
  }

  Widget _buildPremiumWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [primaryDark, primaryColor, accentColor]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: primaryColor.withValues(alpha: 0.4),
              blurRadius: 32, offset: const Offset(0, 12)),
          BoxShadow(color: accentColor.withValues(alpha: 0.25),
              blurRadius: 22, offset: const Offset(0, -6))],
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.18), width: 1.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35), width: 3),
                boxShadow: [
                  BoxShadow(
                      color: Colors.white.withValues(alpha: 0.25),
                      blurRadius: 22, spreadRadius: 3)]),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                backgroundImage: _userPhotoUrl != null &&
                        _userPhotoUrl!.isNotEmpty
                    ? NetworkImage(_userPhotoUrl!) : null,
                child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty
                    ? Text(
                        _userName.isNotEmpty
                            ? _userName[0].toUpperCase() : 'M',
                        style: const TextStyle(fontSize: 24,
                            fontWeight: FontWeight.w800, color: Colors.white))
                    : null)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting,
                    style: const TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800, color: Colors.white,
                        height: 1.3, letterSpacing: -0.5),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(_motivation,
                    style: TextStyle(fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500, height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis)])),
          ]),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _buildGlassBadge(
              icon: _isHSSEManager
                  ? Icons.security_rounded : Icons.verified_rounded,
              text: _userRole.toUpperCase()),
            _buildGlassBadge(
              icon: Icons.calendar_today_rounded,
              text: _formatDate(DateTime.now())),
            if (_isHSSEManager && _totalRiskSubmissions > 0)
              _buildGlassBadge(
                icon: Icons.warning_amber_rounded,
                text: '$_totalRiskSubmissions RISIKO',
                color: highRiskColor)]),
        ]));
  }
}

// ==================== PROVIDER ====================
class ManagerProvider extends ChangeNotifier {
  final _service = ManagerService();
  bool isLoading = true;
  ManagerDashboardData? data;
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