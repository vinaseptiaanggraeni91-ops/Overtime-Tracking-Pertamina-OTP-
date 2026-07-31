// lib/widgets/team_summary.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamSummary extends StatelessWidget {
  final List<Map<String, dynamic>> teamMembers;
  final int totalMembers;
  final int onlineMembers;
  final Color Function(String) getRoleColor;
  final Color? accentColor;
  final VoidCallback? onViewAll;

  const TeamSummary({
    super.key,
    required this.teamMembers,
    required this.totalMembers,
    required this.onlineMembers,
    required this.getRoleColor,
    this.accentColor,
    this.onViewAll,
  });

  // ==================== FIELD EXTRACTORS ====================
  
  String _getMemberName(Map<String, dynamic> member) {
    return (member['nama_lengkap']?.toString() ?? '').isNotEmpty
        ? member['nama_lengkap']!.toString()
        : (member['nama']?.toString() ?? '').isNotEmpty
            ? member['nama']!.toString()
            : (member['name']?.toString() ?? '').isNotEmpty
                ? member['name']!.toString()
                : (member['email']?.toString() ?? '').isNotEmpty
                    ? member['email']!.toString().split('@')[0]
                    : 'Unknown';
  }

  String _getMemberRole(Map<String, dynamic> member) {
    return (member['role']?.toString() ?? '').isNotEmpty
        ? member['role']!.toString()
        : (member['user_role']?.toString() ?? '').isNotEmpty
            ? member['user_role']!.toString()
            : (member['jabatan']?.toString() ?? '').isNotEmpty
                ? member['jabatan']!.toString()
                : 'mitra';
  }

  String? _getMemberPhotoUrl(Map<String, dynamic> member) {
    return (member['photo_url']?.toString() ?? '').isNotEmpty
        ? member['photo_url']!.toString()
        : (member['photoUrl']?.toString() ?? '').isNotEmpty
            ? member['photoUrl']!.toString()
            : (member['avatar']?.toString() ?? '').isNotEmpty
                ? member['avatar']!.toString()
                : null;
  }

  /// 🔥 PERBAIKAN UTAMA: Prioritaskan last_active, default false
  bool _getMemberIsOnline(Map<String, dynamic> member) {
    // 🔥 STEP 1: Cek last_active dulu (ini yang paling akurat)
    final lastActive = member['last_active'] ?? member['lastActive'] ?? member['timestamp'] ?? member['last_seen'];
    
    if (lastActive != null) {
      try {
        DateTime? lastActiveTime;
        if (lastActive is DateTime) {
          lastActiveTime = lastActive;
        } else if (lastActive is Timestamp) {
          lastActiveTime = lastActive.toDate();
        }
        
        if (lastActiveTime != null) {
          final diff = DateTime.now().difference(lastActiveTime);
          // 🔥 Hanya online jika last_active dalam 10 menit terakhir
          // dan status_online juga mendukung
          if (diff.inMinutes < 10) {
            // Cek status tambahan
            final status = member['status']?.toString().toLowerCase() ?? '';
            if (status == 'offline' || status == 'inactive') {
              return false;
            }
            return true;
          }
          // 🔥 Jika last_active lebih dari 10 menit, pasti offline
          return false;
        }
      } catch (_) {}
    }

    // 🔥 STEP 2: Cek isOnline tapi hanya jika ada last_active yang mendukung
    final isOnlineField = member['isOnline'] ?? member['is_online'] ?? member['online'] ?? false;
    
    // 🔥 JANGAN PERCAYA isOnline jika nilainya true tapi tidak ada last_active
    if (isOnlineField is bool && isOnlineField == true) {
      // Cek apakah ada last_active yang mendukung
      if (lastActive == null) {
        // Tidak ada last_active, anggap offline
        return false;
      }
      return true;
    }

    // 🔥 STEP 3: Cek status field
    final status = member['status']?.toString().toLowerCase() ?? '';
    if (status == 'online' || status == 'active') {
      // Cek apakah ada last_active yang mendukung
      if (lastActive == null) {
        return false;
      }
      return true;
    }
    if (status == 'offline' || status == 'inactive') {
      return false;
    }

    // 🔥 DEFAULT: FALSE (offline)
    return false;
  }

  /// Get last active time
  DateTime? _getLastActive(Map<String, dynamic> member) {
    final lastActive = member['last_active'] ?? member['lastActive'] ?? member['timestamp'] ?? member['last_seen'];
    if (lastActive == null) return null;
    
    if (lastActive is DateTime) return lastActive;
    if (lastActive is Timestamp) return lastActive.toDate();
    return null;
  }

  /// Format waktu last active
  String _formatLastActive(DateTime? time) {
    if (time == null) return 'Offline';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Online';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}m lalu';
    return '${(diff.inDays / 30).floor()}bl lalu';
  }

  String _getInitial(String name) {
    if (name.isEmpty || name == 'Unknown') return '?';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  Color _getAvatarColor(String name) {
    if (name.isEmpty || name == 'Unknown') return Colors.grey;
    final hash = name.hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.deepOrange,
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = accentColor ?? const Color(0xFF1E3C72);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🔥 HITUNG ULANG ONLINE MEMBERS berdasarkan data sebenarnya
    final actualOnlineCount = teamMembers.where((m) => _getMemberIsOnline(m)).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(isDark ? 30 : 15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Total + Online + Lihat Semua
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Total & Online
              Row(
                children: [
                  // Total Members
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalMembers',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        'Anggota',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Online Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: actualOnlineCount > 0 
                          ? Colors.green.withAlpha(isDark ? 40 : 20)
                          : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: actualOnlineCount > 0 ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$actualOnlineCount Online',
                          style: TextStyle(
                            color: actualOnlineCount > 0 ? Colors.green : Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Right: Lihat Semua
              if (onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Semua',
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: primaryColor,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Member List
          if (teamMembers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline, 
                      size: 40, 
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada anggota tim',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[400], 
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...teamMembers.take(5).map((member) {
              final role = _getMemberRole(member);
              final roleColor = getRoleColor(role);
              final isOnline = _getMemberIsOnline(member);
              final photoUrl = _getMemberPhotoUrl(member);
              final name = _getMemberName(member);
              final initial = _getInitial(name);
              final lastActive = _getLastActive(member);
              final lastActiveText = _formatLastActive(lastActive);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: roleColor.withAlpha(isDark ? 50 : 30),
                            border: Border.all(
                              color: isOnline 
                                  ? Colors.green 
                                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: photoUrl != null && photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => 
                                        Center(
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: roleColor,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(roleColor),
                                        ),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Text(
                                      initial,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: roleColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        // 🔥 Indicator online hanya jika benar-benar online
                        if (isOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Name & Role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1A2332),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              // Role Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleColor.withAlpha(isDark ? 40 : 20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  role.isNotEmpty ? role.toUpperCase() : '-',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: roleColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // 🔥 Tampilkan last active
                              if (!isOnline && lastActive != null) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    lastActiveText,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Online Indicator
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOnline 
                                ? Colors.green 
                                : (isDark ? Colors.grey[600] : Colors.grey[300]),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 8,
                            color: isOnline 
                                ? Colors.green 
                                : (isDark ? Colors.grey[500] : Colors.grey[400]),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

          // Jika lebih dari 5, tampilkan "+X lainnya"
          if (teamMembers.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(isDark ? 30 : 10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${teamMembers.length - 5} anggota lainnya',
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

          // Quick stats
          if (teamMembers.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_rounded,
                  size: 12,
                  color: actualOnlineCount > 0 ? Colors.green.withAlpha(180) : Colors.grey.withAlpha(180),
                ),
                const SizedBox(width: 4),
                Text(
                  '${totalMembers > 0 ? ((actualOnlineCount / totalMembers) * 100).toStringAsFixed(0) : 0}% online',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Update real-time',
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}