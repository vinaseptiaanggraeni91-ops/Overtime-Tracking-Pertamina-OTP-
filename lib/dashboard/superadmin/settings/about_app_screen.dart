// ============================================================
// FILE : lib/dashboard/superadmin/settings/about_app_screen.dart
// TENTANG APLIKASI - PT PERTAMINA GEOTHERMAL ENERGY KAMOJANG
// DENGAN BOTTOM NAVIGATION BAR
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '/widgets/bottom_nav/superadmin_bottom_nav.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      
      // ==================== BOTTOM NAVIGATION ====================
      bottomNavigationBar: const SuperAdminBottomNav(
        currentIndex: 2, // Settings tab active
      ),
      
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1E3C72),
              size: 22,
            ),
          ),
        ),
        title: Text(
          'Tentang Aplikasi',
          style: GoogleFonts.poppins(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          children: [
            const SizedBox(height: 10),
            
            // ==================== LOGO & NAMA APLIKASI ====================
            _buildAppHeader(),
            
            const SizedBox(height: 32),
            
            // ==================== INFORMASI APLIKASI ====================
            _buildSectionTitle('Informasi Aplikasi'),
            const SizedBox(height: 12),
            _buildInfoCard([
              _InfoItem(
                icon: Icons.info_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Nama Aplikasi',
                subtitle: 'OTP - Overtime Tracking Pertamina',
              ),
              _InfoItem(
                icon: Icons.verified_rounded,
                iconColor: const Color(0xFF22C55E),
                title: 'Versi Aplikasi',
                subtitle: 'v1.2.0 (Build 2026.07)', // ✅ UPDATE VERSI
              ),
              _InfoItem(
                icon: Icons.update_rounded,
                iconColor: const Color(0xFFF97316),
                title: 'Terakhir Diperbarui',
                subtitle: '23 Juli 2026', // ✅ UPDATE TANGGAL KE 2026
              ),
              _InfoItem(
                icon: Icons.category_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Jenis Aplikasi',
                subtitle: 'Human Resource Information System',
              ),
              _InfoItem(
                icon: Icons.business_rounded,
                iconColor: const Color(0xFF06B6D4),
                title: 'Unit Kerja',
                subtitle: 'PT Pertamina Geothermal Energy Tbk',
              ),
            ]),
            
            const SizedBox(height: 28),
            
            // ==================== TEKNOLOGI ====================
            _buildSectionTitle('Teknologi'),
            const SizedBox(height: 12),
            _buildTechStack(),
            
            const SizedBox(height: 28),
            
            // ==================== TIM PENGEMBANG ====================
            _buildSectionTitle('Tim Pengembang'),
            const SizedBox(height: 12),
            _buildDeveloperCard(),
            
            const SizedBox(height: 28),
            
            // ==================== FITUR UTAMA ====================
            _buildSectionTitle('Fitur Utama'),
            const SizedBox(height: 12),
            _buildFeaturesList(),
            
            const SizedBox(height: 28),
            
            // ==================== KONTAK & DUKUNGAN ====================
            _buildSectionTitle('Kontak & Dukungan'),
            const SizedBox(height: 12),
            _buildContactCard(context),
            
            const SizedBox(height: 28),
            
            // ==================== LISENSI ====================
            _buildLicenseCard(),
            
            const SizedBox(height: 32),
            
          ],
        ),
      ),
    );
  }

  // =========================================================
  // APP HEADER
  // =========================================================

  Widget _buildAppHeader() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3C72),
            Color(0xFF2A5298),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo Container dengan ikon geothermal
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.thermostat_rounded, // Ikon geothermal
              size: 52,
              color: Color(0xFF1E3C72),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Text(
            'OTP',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ),
          
          const SizedBox(height: 6),
          
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Text(
              'Overtime Tracking Pertamina',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Sistem manajemen lembur terintegrasi untuk monitoring, approval, dan pelaporan lembur karyawan secara real-time di PT Pertamina Geothermal Energy Area Kamojang.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white60,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _buildSectionTitle(String title) {
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
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // INFO CARD
  // =========================================================

  Widget _buildInfoCard(List<_InfoItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;
          
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: item.iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.iconColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: const Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 74,
                  endIndent: 18,
                  color: Colors.grey[200],
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // =========================================================
  // TECH STACK
  // =========================================================

  Widget _buildTechStack() {
    final technologies = [
      _TechItem(
        name: 'Flutter',
        version: '3.27+', // ✅ UPDATE VERSI FLUTTER TERBARU
        icon: Icons.flutter_dash_rounded,
        color: const Color(0xFF02569B),
        description: 'Framework pengembangan aplikasi mobile cross-platform',
      ),
      _TechItem(
        name: 'Firebase',
        version: 'Firestore & Auth',
        icon: Icons.cloud_done_rounded,
        color: const Color(0xFFFFA000),
        description: 'Layanan backend, database real-time, dan autentikasi',
      ),
      _TechItem(
        name: 'Google Fonts',
        version: 'Poppins',
        icon: Icons.text_fields_rounded,
        color: const Color(0xFF4285F4),
        description: 'Sistem tipografi modern untuk tampilan profesional',
      ),
      _TechItem(
        name: 'Go Router',
        version: 'Navigasi Deklaratif',
        icon: Icons.alt_route_rounded,
        color: const Color(0xFF7C4DFF),
        description: 'Sistem navigasi dan routing yang efisien',
      ),
      _TechItem(
        name: 'Intl',
        version: 'Format & Lokalisasi',
        icon: Icons.language_rounded,
        color: const Color(0xFF0D9488),
        description: 'Format tanggal, mata uang, dan lokalisasi bahasa Indonesia',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: technologies.map((tech) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: tech.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    tech.icon,
                    color: tech.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tech.name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: tech.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tech.version,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: tech.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tech.description,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================================================
  // DEVELOPER CARD
  // =========================================================

  Widget _buildDeveloperCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E3C72),
                      Color(0xFF2A5298),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3C72).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.developer_mode_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IT Development Team',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PT Pertamina Geothermal Energy Tbk',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Area Kamojang',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.energy_savings_leaf_rounded,
                  size: 18,
                  color: Color(0xFF2E7D32),
                ),
                SizedBox(width: 8),
                Text(
                  'Energi Panas Bumi untuk Indonesia',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FEATURES LIST
  // =========================================================

  Widget _buildFeaturesList() {
    final features = [
      _FeatureItem(
        icon: Icons.access_time_rounded,
        color: const Color(0xFF3B82F6),
        title: 'Manajemen Lembur',
        description: 'Pengajuan, approval, dan tracking lembur karyawan secara digital dan real-time',
      ),
      _FeatureItem(
        icon: Icons.account_tree_rounded,
        color: const Color(0xFF22C55E),
        title: 'Multi-level Approval',
        description: 'Approval berjenjang dari Supervisor, Manager, HRD, hingga Superadmin',
      ),
      _FeatureItem(
        icon: Icons.calculate_rounded,
        color: const Color(0xFFF97316),
        title: 'Kalkulasi Otomatis',
        description: 'Perhitungan jam lembur, tarif, dan estimasi biaya secara otomatis',
      ),
      _FeatureItem(
        icon: Icons.description_rounded,
        color: const Color(0xFF8B5CF6),
        title: 'Laporan & Export',
        description: 'Generate laporan lembur dalam format PDF dan Excel untuk keperluan dokumentasi',
      ),
      _FeatureItem(
        icon: Icons.notifications_active_rounded,
        color: const Color(0xFFEF4444),
        title: 'Notifikasi Real-time',
        description: 'Pemberitahuan instan untuk setiap status approval dan pengajuan lembur',
      ),
      _FeatureItem(
        icon: Icons.admin_panel_settings_rounded,
        color: const Color(0xFF06B6D4),
        title: 'Role-based Access Control',
        description: 'Keamanan data dan akses sistem berdasarkan peran dan fungsi pengguna',
      ),
      _FeatureItem(
        icon: Icons.track_changes_rounded,
        color: const Color(0xFF6366F1),
        title: 'Tracking Status',
        description: 'Pantau status pengajuan lembur dari submit hingga selesai secara transparan',
      ),
      _FeatureItem(
        icon: Icons.history_rounded,
        color: const Color(0xFFF43F5E),
        title: 'Riwayat Lengkap',
        description: 'Arsip dan riwayat seluruh pengajuan lembur yang pernah dilakukan',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: features.asMap().entries.map((entry) {
          final index = entry.key;
          final feature = entry.value;
          final isLast = index == features.length - 1;
          
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: feature.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        feature.icon,
                        color: feature.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.title,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            feature.description,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 58,
                  endIndent: 18,
                  color: Colors.grey[200],
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // =========================================================
  // CONTACT CARD
  // =========================================================

  Widget _buildContactCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildContactItem(
            icon: Icons.email_rounded,
            color: const Color(0xFFEF4444),
            title: 'Email Support',
            subtitle: 'it.kamojang@pertamina.com',
            onTap: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: 'it.kamojang@pertamina.com',
                query: 'subject=Bantuan Aplikasi OTP',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          Divider(height: 1, indent: 74, endIndent: 18, color: Colors.grey[200]),
          _buildContactItem(
            icon: Icons.phone_rounded,
            color: const Color(0xFF22C55E),
            title: 'Telepon',
            subtitle: '(0264) 123456 / Ext. 1234',
            onTap: () async {
              final uri = Uri(
                scheme: 'tel',
                path: '+62264123456',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          Divider(height: 1, indent: 74, endIndent: 18, color: Colors.grey[200]),
          _buildContactItem(
            icon: Icons.location_on_rounded,
            color: const Color(0xFF3B82F6),
            title: 'Lokasi',
            subtitle: 'Jl. Raya Kamojang, Desa Laksana, Kec. Ibun, Kab. Bandung, Jawa Barat 40384',
            onTap: () async {
              final uri = Uri.parse(
                'https://maps.google.com/?q=PT+Pertamina+Geothermal+Energy+Kamojang',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          Divider(height: 1, indent: 74, endIndent: 18, color: Colors.grey[200]),
          _buildContactItem(
            icon: Icons.language_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'Website',
            subtitle: 'www.pertamina.com/pge',
            onTap: () async {
              final uri = Uri.parse('https://www.pertamina.com/pge');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          Divider(height: 1, indent: 74, endIndent: 18, color: Colors.grey[200]),
          _buildContactItem(
            icon: Icons.support_agent_rounded,
            color: const Color(0xFFF97316),
            title: 'Helpdesk IT',
            subtitle: 'Buka jam kerja: 08.00 - 16.00 WIB',
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // LICENSE CARD
  // =========================================================

  Widget _buildLicenseCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF1E3C72).withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.shield_rounded,
            size: 40,
            color: const Color(0xFF1E3C72).withOpacity(0.6),
          ),
          const SizedBox(height: 14),
          Text(
            'Hak Cipta © 2026', // ✅ UPDATE TAHUN COPYRIGHT
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'PT Pertamina Geothermal Energy Tbk',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Area Kamojang',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 16,
                  color: Color(0xFFF59E0B),
                ),
                SizedBox(width: 8),
                Text(
                  'Internal Use Only',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aplikasi ini hanya untuk penggunaan internal\nPT Pertamina Geothermal Energy Tbk.\nDilarang mendistribusikan tanpa izin tertulis.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[500],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HELPER MODELS
// ============================================================

class _InfoItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  _InfoItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
}

class _TechItem {
  final String name;
  final String version;
  final IconData icon;
  final Color color;
  final String description;

  _TechItem({
    required this.name,
    required this.version,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class _FeatureItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  _FeatureItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}