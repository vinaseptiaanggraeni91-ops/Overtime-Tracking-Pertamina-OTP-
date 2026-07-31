// lib/features/superadmin/widgets/user_stats_header.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/user_helpers.dart';

class UserStatsHeader extends StatelessWidget {
  final int totalUsers;
  final int activeCount;
  final int inactiveCount;
  final int blockedCount;

  const UserStatsHeader({
    super.key,
    required this.totalUsers,
    required this.activeCount,
    required this.inactiveCount,
    required this.blockedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan ringkasan singkat
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Ringkasan Pengguna',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: UserHelpers.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                // Total users badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF3B82F6).withOpacity(0.1),
                        const Color(0xFF1E40AF).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        size: 14,
                        color: const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$totalUsers Total',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Stat cards dalam row - HANYA 3 KOLOM (Total, Active, Inactive)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _StatCardCompact(
                  label: 'Total',
                  count: totalUsers,
                  icon: Icons.group_rounded,
                  color: const Color(0xFF3B82F6),
                  gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _StatCardCompact(
                  label: 'Active',
                  count: activeCount,
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                  gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _StatCardCompact(
                  label: 'Inactive',
                  count: inactiveCount,
                  icon: Icons.pause_circle_rounded,
                  color: const Color(0xFFF59E0B),
                  gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
              ),
            ],
          ),
          // Progress bar untuk visualisasi rasio
          const SizedBox(height: 12),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = totalUsers > 0 ? totalUsers : 1;
    final activeRatio = activeCount / total;
    final inactiveRatio = inactiveCount / total;
    final blockedRatio = blockedCount / total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (activeRatio > 0)
                    Flexible(
                      flex: (activeRatio * 100).round().clamp(1, 100),
                      child: Container(
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  if (inactiveRatio > 0)
                    Flexible(
                      flex: (inactiveRatio * 100).round().clamp(1, 100),
                      child: Container(
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  if (blockedRatio > 0)
                    Flexible(
                      flex: (blockedRatio * 100).round().clamp(1, 100),
                      child: Container(
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            children: [
              _legendDot(const Color(0xFF10B981), 'Active'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFF59E0B), 'Inactive'),
              if (blockedCount > 0) ...[
                const SizedBox(width: 16),
                _legendDot(const Color(0xFFEF4444), 'Blocked'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: UserHelpers.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StatCardCompact extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _StatCardCompact({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: UserHelpers.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon dengan gradient background
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(height: 10),
          // Count dengan animasi implicit
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: count),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Text(
                value.toString(),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: UserHelpers.textPrimary,
                  letterSpacing: -0.5,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          // Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}