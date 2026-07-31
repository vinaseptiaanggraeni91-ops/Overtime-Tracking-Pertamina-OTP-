// lib/features/my_team/member_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/my_team_service.dart';
import '../../widgets/my_team/team_helpers.dart';
import '../../widgets/bottom_nav/app_bottom_nav.dart';

class MemberDetailScreen extends StatelessWidget {
  final TeamMember member;
  final String userRole;

  const MemberDetailScreen({
    super.key,
    required this.member,
    required this.userRole,
  });

  // 🔥 PERBAIKAN: Cek status online berdasarkan last_active
  bool _isMemberOnline(TeamMember member) {
    if (member.lastLogin != null) {
      final diff = DateTime.now().difference(member.lastLogin!);
      if (diff.inMinutes < 10) {
        return true;
      }
    }
    return false;
  }

  // Format last active
  String _formatLastActive(DateTime? time) {
    if (time == null) return 'Offline';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}m lalu';
    return '${(diff.inDays / 30).floor()}bl lalu';
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _isMemberOnline(member);
    final statusColor = isOnline ? const Color(0xFF00C853) : Colors.grey;
    final statusText = isOnline ? 'Online' : _formatLastActive(member.lastLogin);
    final isActive = member.isActive; // Tetap pakai isActive untuk status akun

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ========== HEADER ==========
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0D47A1),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Avatar Besar dengan status dot
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isOnline
                                  ? [const Color(0xFF1976D2), const Color(0xFF42A5F5)]
                                  : [Colors.grey.shade400, Colors.grey.shade500],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: isOnline
                                    ? const Color(0xFF1976D2).withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              member.inisial,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ),
                        ),
                        // 🔥 Status dot di pojok avatar
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFF00C853) : Colors.grey.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                if (isOnline)
                                  BoxShadow(
                                    color: const Color(0xFF00C853).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Nama
                    Text(
                      member.namaLengkap,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        TeamHelpers.getRoleLabel(member.role),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Tombol Back
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // ========== CONTENT ==========
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  _buildStatusCard(isOnline, statusText, statusColor, isActive),
                  const SizedBox(height: 20),
                  
                  // Informasi Kontak
                  _buildSectionTitle('Informasi Kontak'),
                  const SizedBox(height: 12),
                  _buildContactCard(),
                  const SizedBox(height: 20),
                  
                  // Informasi Akun
                  _buildSectionTitle('Informasi Akun'),
                  const SizedBox(height: 12),
                  _buildAccountCard(),
                  const SizedBox(height: 20),
                  
                  // Aktivitas
                  _buildSectionTitle('Aktivitas'),
                  const SizedBox(height: 12),
                  _buildActivityCard(),
                  const SizedBox(height: 30),
                  
                  // 🔥 HAPUS TOMBOL ACTION - tidak ada tombol Kirim Pesan & Telepon
                  // _buildActionButtons(context),  // ❌ DIHAPUS
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      
      bottomNavigationBar: AppBottomNav(
        userRole: userRole,
        currentIndex: 0,
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1A2B4C),
      ),
    );
  }

  // =========================================================
  // STATUS CARD
  // =========================================================
  
  Widget _buildStatusCard(bool isOnline, String statusText, Color statusColor, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: statusColor,
              size: 28,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Status Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Kehadiran',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOnline 
                      ? 'Sedang aktif di aplikasi'
                      : 'Terakhir aktif: $statusText',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isOnline ? Colors.grey.shade600 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [
                      if (isOnline)
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
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
  // CONTACT CARD
  // =========================================================
  
  Widget _buildContactCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.email_rounded,
            iconColor: const Color(0xFF1976D2),
            label: 'Email',
            value: member.email,
          ),
          const Divider(height: 1, indent: 60),
          _buildInfoTile(
            icon: Icons.phone_rounded,
            iconColor: const Color(0xFF059669),
            label: 'Telepon',
            value: member.phone.isNotEmpty ? member.phone : '-',
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ACCOUNT CARD
  // =========================================================
  
  Widget _buildAccountCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.badge_rounded,
            iconColor: const Color(0xFF7C3AED),
            label: 'Role',
            value: TeamHelpers.getRoleLabel(member.role),
          ),
          const Divider(height: 1, indent: 60),
          _buildInfoTile(
            icon: Icons.work_rounded,
            iconColor: const Color(0xFFF59E0B),
            label: 'Fungsi',
            value: TeamHelpers.getFungsiLabel(
              member.fungsi.isNotEmpty ? member.fungsi : 'operation',
            ),
          ),
          const Divider(height: 1, indent: 60),
          _buildInfoTile(
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF6366F1),
            label: 'Bergabung Sejak',
            value: DateFormat('dd MMMM yyyy', 'id_ID').format(member.createdAt),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // INFO TILE (Reusable)
  // =========================================================
  
  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A2B4C),
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
  // ACTIVITY CARD
  // =========================================================
  
  Widget _buildActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildActivityItem(
            icon: Icons.login_rounded,
            label: 'Login Terakhir',
            value: member.lastLoginFormatted,
            color: const Color(0xFF1976D2),
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            icon: Icons.access_time_rounded,
            label: 'Status Akun',
            value: member.isActive ? 'Aktif' : 'Nonaktif',
            color: member.isActive ? const Color(0xFF00C853) : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2B4C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}