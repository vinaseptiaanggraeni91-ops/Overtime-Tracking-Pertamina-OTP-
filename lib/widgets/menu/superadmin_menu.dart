// lib/features/superadmin/widgets/admin_menu.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/superadmin_service.dart';

class AdminMenu extends StatelessWidget {
  final DashboardData data;
  final DashboardService service;

  const AdminMenu({
    super.key,
    required this.data,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final crossAxisCount =
        width >= 1200
            ? 5
            : width >= 900
                ? 4
                : width >= 600
                    ? 4
                    : 3;

    final childAspectRatio =
        width < 360
            ? 0.82
            : width < 430
                ? 0.88
                : 0.95;

    final menuItems = [
      _MenuItem(
        title: 'Master Data\nPekerja',
        icon: Icons.badge_rounded,
        route: '/superadmin/master-pekerja',
        color: const Color(0xFF2E7D32),
      ),
      _MenuItem(
        title: 'Persetujuan\nLembur',
        icon: Icons.approval_rounded,
        route: '/admin/approval',
        color: const Color(0xFF00B4D8),
      ),
      _MenuItem(
        title: 'Jadwal\nLembur',
        icon: Icons.schedule_rounded,
        route: '/jadwal-lembur',
        color: const Color(0xFF9B59B6),
      ),
      _MenuItem(
        title: 'Riwayat\nLembur',
        icon: Icons.work_history_rounded,
        route: '/overtime-data',
        color: const Color(0xFFFF6B35),
      ),
      _MenuItem(
        title: 'Riwayat\nAbsensi',
        icon: Icons.fact_check_rounded,
        route: '/riwayat-absensi',
        color: const Color(0xFF4A90D9),
      ),
      _MenuItem(
        title: 'Pemantauan\nLokasi',
        icon: Icons.location_on_rounded,
        route: '/location-monitoring',
        color: const Color(0xFFE74C3C),
      ),
      _MenuItem(
        title: 'Laporan\nLembur',
        icon: Icons.assessment_rounded,
        route: '/reports',
        color: const Color(0xFF7C3AED),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: menuItems.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final item = menuItems[index];

        return _AnimatedMenuCard(
          item: item,
          onTap: () => _navigateTo(
            context,
            item.title,
            item.route,
          ),
        );
      },
    );
  }

  void _navigateTo(
    BuildContext context,
    String menu,
    String route,
  ) {
    try {
      context.push(route);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Membuka $menu...'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }
}

class _AnimatedMenuCard extends StatefulWidget {
  final _MenuItem item;
  final VoidCallback onTap;

  const _AnimatedMenuCard({
    required this.item,
    required this.onTap,
  });

  @override
  State<_AnimatedMenuCard> createState() =>
      _AnimatedMenuCardState();
}

class _AnimatedMenuCardState
    extends State<_AnimatedMenuCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    setState(() => _pressed = false);
  }

  void _onTapCancel() {
    _controller.reverse();
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12), // 🔥 14 -> 12
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                item.color.withValues(alpha: 0.95),
                item.color,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20), // 🔥 22 -> 20
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: 0.22),
                blurRadius: 12, // 🔥 14 -> 12
                offset: const Offset(0, 6), // 🔥 8 -> 6
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background decoration
              Positioned(
                right: -15, // 🔥 -18 -> -15
                top: -15, // 🔥 -18 -> -15
                child: Container(
                  width: 60, // 🔥 70 -> 60
                  height: 60, // 🔥 70 -> 60
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -12, // 🔥 -15 -> -12
                bottom: -15, // 🔥 -20 -> -15
                child: Container(
                  width: 40, // 🔥 50 -> 40
                  height: 40, // 🔥 50 -> 40
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // 🔥 FIX: Main content dengan mainAxisSize: min
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // 🔥 TAMBAHKAN INI
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8), // 🔥 10 -> 8
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12), // 🔥 14 -> 12
                    ),
                    child: Icon(
                      item.icon,
                      color: Colors.white,
                      size: 20, // 🔥 24 -> 20
                    ),
                  ),
                  const SizedBox(height: 6), // 🔥 10 -> 6
                  // Title
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 10, // 🔥 12 -> 10
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2, // 🔥 1.3 -> 1.2
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4), // 🔥 6 -> 4
                  // "Open" indicator
                  Row(
                    children: [
                      Container(
                        width: 4, // 🔥 5 -> 4
                        height: 4, // 🔥 5 -> 4
                        decoration: const BoxDecoration(
                          color: Colors.white70,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4), // 🔥 5 -> 4
                      const Text(
                        'Open', // 🔥 'Open Menu' -> 'Open'
                        style: TextStyle(
                          fontSize: 8, // 🔥 9 -> 8
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final String route;
  final Color color;

  _MenuItem({
    required this.title,
    required this.icon,
    required this.route,
    required this.color,
  });
}