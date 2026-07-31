// ============================================================
// FILE : lib/dashboard/superadmin/settings/settings_screen.dart
// ENHANCED VERSION - PROFESSIONAL SETTINGS UI + GO ROUTER + BOTTOM NAV
// MOBILE PERFECTED LAYOUT - 2026
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '/widgets/bottom_nav/superadmin_bottom_nav.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = true;
  bool hasError = false;

  int totalUsers = 0;
  int totalLogs = 0;
  int activeSessions = 0;

  List<SettingMenu> settingsMenus = [];
  List<SettingMenu> accountMenus = [];

  @override
  void initState() {
    super.initState();
    _initializeMenus();
    _loadSystemData();
  }

  // =========================================================
  // INITIAL MENU - DIPISAH PER KATEGORI
  // =========================================================

  void _initializeMenus() {
    // Menu Pengaturan Sistem
    settingsMenus = [
      SettingMenu(
        title: 'Tarif Lembur',
        subtitle: 'Atur tarif lembur, shift malam, dan insentif khusus',
        icon: Icons.payments_rounded,
        color: const Color(0xFF22C55E),
        route: '/settings/overtime-rates',
        badge: 'Aktif',
      ),
      SettingMenu(
        title: 'Log Sistem',
        subtitle: 'Monitoring aktivitas, login, approval, dan error logs',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFF97316),
        route: '/system-logs',
      ),
      SettingMenu(
        title: 'Notifikasi & Alert',
        subtitle: 'Konfigurasi push, email, dan pengingat approval',
        icon: Icons.notifications_active_rounded,
        color: const Color(0xFFEF4444),
        route: '/settings/notifications',
      ),
    ];

    // Menu Akun & Profil
    accountMenus = [
      SettingMenu(
        title: 'Akun & Profil',
        subtitle: 'Kelola profil, password, email, dan data akun',
        icon: Icons.person_rounded,
        color: const Color(0xFF3B82F6),
        route: '/profile',
      ),
      SettingMenu(
        title: 'Tentang Aplikasi',
        subtitle: 'Informasi, versi, teknologi, dan tim pengembang',
        icon: Icons.info_rounded,
        color: const Color(0xFF8B5CF6),
        route: '/settings/about-app',
      ),
    ];
  }

  // =========================================================
  // LOAD FIREBASE DATA
  // =========================================================

  Future<void> _loadSystemData() async {
    int usersCount = 0;
    int logsCount = 0;
    int sessionsCount = 0;
    final List<String> failedCollections = [];

    Future<int> safeCount(String collection) async {
      try {
        final snap = await _firestore.collection(collection).get();
        return snap.docs.length;
      } catch (e) {
        debugPrint('Error loading "$collection": $e');
        failedCollections.add(collection);
        return 0;
      }
    }

    final results = await Future.wait([
      safeCount('users'),
      safeCount('system_logs'),
      safeCount('active_sessions'),
    ]);

    usersCount = results[0];
    logsCount = results[1];
    sessionsCount = results[2];

    if (mounted) {
      setState(() {
        totalUsers = usersCount;
        totalLogs = logsCount;
        activeSessions = sessionsCount;
        isLoading = false;
        hasError = failedCollections.length == 3;
      });

      if (failedCollections.isNotEmpty && failedCollections.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sebagian data gagal dimuat: ${failedCollections.join(', ')}',
            ),
            backgroundColor: const Color(0xFFF97316),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // =========================================================
  // REFRESH DATA
  // =========================================================

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await _loadSystemData();
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      bottomNavigationBar: const SuperAdminBottomNav(
        currentIndex: 2,
      ),

      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF1E3C72),
        displacement: 20,
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF1E3C72),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Memuat data...',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : hasError
                ? _buildErrorState()
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // App Bar yang ringkas
                      SliverToBoxAdapter(
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Profile
                                _buildProfileHeader(user),

                                const SizedBox(height: 24),

                                // System Overview
                                _buildSectionLabel('Ringkasan Sistem'),
                                const SizedBox(height: 14),
                                _buildSystemOverview(),

                                const SizedBox(height: 28),

                                // Sistem Settings
                                _buildSectionLabel('Pengaturan Sistem'),
                                const SizedBox(height: 14),
                                ...settingsMenus.map(
                                  (menu) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildMenuCard(menu),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // Account Settings
                                _buildSectionLabel('Akun & Lainnya'),
                                const SizedBox(height: 14),
                                ...accountMenus.map(
                                  (menu) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildMenuCard(menu),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Footer Status
                                _buildFooter(),

                                // Extra bottom padding untuk bottom nav
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // =========================================================
  // ERROR STATE
  // =========================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Gagal Memuat Data',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Terjadi kesalahan saat mengambil data sistem.\nSilakan coba lagi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3C72),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // PROFILE HEADER - MOBILE OPTIMIZED
  // =========================================================

  Widget _buildProfileHeader(User? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Baris Utama: Avatar + Info + Badge
          Row(
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Text(
                    user?.email?.substring(0, 1).toUpperCase() ?? 'S',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF1E3C72),
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Nama & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan Sistem',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'superadmin@app.com',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Badge Superadmin
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Superadmin',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Info Grid (Versi, Update, Status)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderInfo(
                  icon: Icons.verified_rounded,
                  label: 'Versi',
                  value: 'v2.0.0',
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withOpacity(0.15),
                ),
                _buildHeaderInfo(
                  icon: Icons.update_rounded,
                  label: 'Update',
                  value: '2026',
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withOpacity(0.15),
                ),
                _buildHeaderInfo(
                  icon: Icons.gpp_good_rounded,
                  label: 'Status',
                  value: 'Aktif',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white54,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // SECTION LABEL
  // =========================================================

  Widget _buildSectionLabel(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3C72),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // SYSTEM OVERVIEW - 3 CARDS MOBILE FRIENDLY
  // =========================================================

  Widget _buildSystemOverview() {
    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            title: 'Pengguna',
            value: totalUsers.toString(),
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF3B82F6),
            subtitle: 'Akun aktif',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildOverviewCard(
            title: 'Log Sistem',
            value: totalLogs.toString(),
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFF97316),
            subtitle: 'Aktivitas',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildOverviewCard(
            title: 'Sesi Aktif',
            value: activeSessions.toString(),
            icon: Icons.online_prediction_rounded,
            color: const Color(0xFF22C55E),
            subtitle: 'Online',
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MENU CARD - MOBILE PERFECTED
  // =========================================================

  Widget _buildMenuCard(SettingMenu menu) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(menu.route),
        splashColor: menu.color.withOpacity(0.1),
        highlightColor: menu.color.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.grey[100]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon Container - Lebih kecil untuk mobile
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: menu.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: menu.color.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        menu.icon,
                        color: menu.color,
                        size: 24,
                      ),
                    ),
                    if (menu.badge != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            menu.title,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (menu.badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              menu.badge!,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      menu.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Arrow
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: menu.color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: menu.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // FOOTER - ENHANCED & MOBILE PERFECT
  // =========================================================

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF16A34A),
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sistem Berjalan Normal',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Terakhir diperbarui ${DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(DateTime.now())} WIB',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'PT Pertamina Geothermal Energy Tbk\nArea Kamojang © 2026',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[400],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MODEL - DITAMBAHKAN BADGE
// ============================================================

class SettingMenu {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final String? badge;

  SettingMenu({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.badge,
  });
}