// lib/features/superadmin/widgets/recent_activities.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/app_colors.dart';
import '../../core/services/superadmin_service.dart';

class RecentActivities extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final DashboardService service;

  const RecentActivities({
    super.key,
    required this.activities,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A5276).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 HEADER DENGAN BADGE COUNT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryBlue.withValues(alpha: 0.15),
                          AppColors.primaryBlue.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aktivitas Terbaru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Pantau aktivitas sistem terkini',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // 🔥 BADGE COUNT - FIXED: Added text and proper constraints
              if (activities.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withValues(alpha: 0.15),
                        const Color(0xFF10B981).withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${activities.length > 5 ? 5 : activities.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 20),

          // 🔥 EMPTY STATE
          if (activities.isEmpty)
            _buildEmptyState()
          else ...[
            // 🔥 ACTIVITY LIST DENGAN DIVIDER - HANYA 5 ITEM
            ...List.generate(
              activities.length > 5 ? 5 : activities.length,
              (index) => Column(
                children: [
                  _buildActivityItem(activities[index], service, index),
                  if (index < (activities.length > 5 ? 4 : activities.length - 1))
                    Padding(
                      padding: const EdgeInsets.only(left: 44),
                      child: Container(
                        height: 1,
                        color: const Color(0xFFF1F5F9),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // 🔥 "LIHAT SEMUA" BUTTON - ARAHKAN KE SYSTEM LOGS
          if (activities.length > 5) ...[
            const SizedBox(height: 12),
            Center(
              child: InkWell(
                onTap: () => context.push('/system-logs'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Semua Aktivitas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🔥 EMPTY STATE
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 40,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada aktivitas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aktivitas sistem akan muncul di sini',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[350],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 ACTIVITY ITEM - FIXED: Mengatasi overflow dengan Flexible
  Widget _buildActivityItem(Map<String, dynamic> activity, DashboardService service, int index) {
    final type = activity['type'] ?? 'info';
    final description = activity['description'] ?? 'Tidak ada deskripsi';
    final user = activity['user'] ?? 'System';
    final userRole = activity['userRole'] ?? 'system';
    final timestamp = activity['timestamp'];
    final timeAgo = service.getTimeAgo(timestamp);
    final color = _getActivityColor(type);
    final icon = _getActivityIcon(type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 ICON DENGAN GRADIENT BACKGROUND
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),

          // 🔥 CONTENT - FIXED: Mengatasi overflow dengan Expanded dan Flexible
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // User + Time - FIXED: Menggunakan Flexible untuk mencegah overflow
                Row(
                  children: [
                    // User icon
                    Icon(
                      Icons.person_rounded,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        user,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Role badge
                    if (userRole.isNotEmpty && userRole != 'system') ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: service.getRoleColor(userRole).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            userRole.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: service.getRoleColor(userRole),
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 🔥 TIME AGO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              timeAgo,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 HELPER: Activity Color
  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'login':
      case 'online':
        return const Color(0xFF10B981); // Green
      case 'logout':
      case 'offline':
        return const Color(0xFFF59E0B); // Amber
      case 'create':
      case 'add_pekerja':
      case 'user_created':
        return const Color(0xFF6366F1); // Indigo
      case 'update':
      case 'update_pekerja':
      case 'user_updated':
        return const Color(0xFF0EA5E9); // Sky
      case 'delete':
      case 'delete_pekerja':
      case 'user_deleted':
        return const Color(0xFFEF4444); // Red
      case 'backup':
        return const Color(0xFF8B5CF6); // Purple
      case 'error':
      case 'critical':
        return const Color(0xFFDC2626); // Red
      case 'warning':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  // 🔥 HELPER: Activity Icon
  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'login':
      case 'online':
        return Icons.login_rounded;
      case 'logout':
      case 'offline':
        return Icons.logout_rounded;
      case 'create':
      case 'add_pekerja':
      case 'user_created':
        return Icons.person_add_rounded;
      case 'update':
      case 'update_pekerja':
      case 'user_updated':
        return Icons.edit_rounded;
      case 'delete':
      case 'delete_pekerja':
      case 'user_deleted':
        return Icons.delete_rounded;
      case 'backup':
        return Icons.cloud_upload_rounded;
      case 'error':
      case 'critical':
        return Icons.error_rounded;
      case 'warning':
        return Icons.warning_rounded;
      default:
        return Icons.info_rounded;
    }
  }
}