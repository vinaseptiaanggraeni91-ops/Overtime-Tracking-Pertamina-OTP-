// lib/features/manager/widgets/manager_menu.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/manager_service.dart';

class ManagerMenu extends StatelessWidget {
  final ManagerDashboardData data;
  final ManagerService service;

  const ManagerMenu({super.key, required this.data, required this.service});

  static const Color textLight = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final sf = (screenWidth / 400).clamp(0.85, 1.1);

    final menus = [
      {
        'icon': Icons.history_rounded,
        'title': 'Riwayat\nLembur',
        'subtitle': 'Histori lembur',
        'route': '/overtime-data',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3C72), Color(0xFF4A6FB5)],
        ),
        'iconBgColor': const Color(0x30FFFFFF),
        'subtextColor': const Color(0xFFB8C9E8),
        'shadowColor': const Color(0xFF1E3C72),
        'isHighlighted': true,
      },
      {
        'icon': Icons.people_rounded,
        'title': 'Tim',
        'subtitle': 'Kelola tim',
        'route': '/my-team',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C3C9E), Color(0xFF9B59B6)],
        ),
        'iconBgColor': const Color(0x30FFFFFF),
        'subtextColor': const Color(0xFFD4C1E8),
        'shadowColor': const Color(0xFF6C3C9E),
        'isHighlighted': false,
      },
      {
        'icon': Icons.location_on_rounded,
        'title': 'Monitoring\nLokasi',
        'subtitle': 'Lacak tim',
        'route': '/location-monitoring',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00838F), Color(0xFF00ACC1)],
        ),
        'iconBgColor': const Color(0x30FFFFFF),
        'subtextColor': const Color(0xFFB2DFEE),
        'shadowColor': const Color(0xFF00838F),
        'isHighlighted': false,
      },
      {
        'icon': Icons.assessment_rounded,
        'title': 'Laporan\nLembur',
        'subtitle': 'Rekap laporan',
        'route': '/reports',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
        ),
        'iconBgColor': const Color(0x30FFFFFF),
        'subtextColor': const Color(0xFFFFD8B8),
        'shadowColor': const Color(0xFFE65100),
        'isHighlighted': false,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12 * sf,
        mainAxisSpacing: 12 * sf,
        childAspectRatio: 1.0,
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final menu = menus[index];
        return _buildMenuItem(
          context: context,
          icon: menu['icon'] as IconData,
          title: menu['title'] as String,
          subtitle: menu['subtitle'] as String,
          route: menu['route'] as String,
          gradient: menu['gradient'] as LinearGradient,
          iconBgColor: menu['iconBgColor'] as Color,
          subtextColor: menu['subtextColor'] as Color,
          shadowColor: menu['shadowColor'] as Color,
          isHighlighted: menu['isHighlighted'] as bool,
          index: index,
          isSmallScreen: isSmallScreen,
          sf: sf,
        );
      },
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    required LinearGradient gradient,
    required Color iconBgColor,
    required Color subtextColor,
    required Color shadowColor,
    required bool isHighlighted,
    required int index,
    required bool isSmallScreen,
    required double sf,
  }) {
    final iconSize = (isSmallScreen ? 22 : 26) * sf;
    final iconContainerSize = (isSmallScreen ? 44 : 52) * sf;
    final iconRadius = (isSmallScreen ? 14 : 18) * sf;
    final titleSize = (isSmallScreen ? 13 : 15) * sf;
    final subtitleSize = (isSmallScreen ? 9 : 10) * sf;
    final padding = (isSmallScreen ? 14 : 18) * sf;
    final spacing = (isSmallScreen ? 4 : 6) * sf;
    final borderRadius = (isSmallScreen ? 18 : 22) * sf;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final clampedOpacity = value.clamp(0.0, 1.0);
        final clampedScale = (0.85 + (0.15 * value)).clamp(0.0, 1.15);
        return Opacity(
          opacity: clampedOpacity,
          child: Transform.scale(scale: clampedScale, child: child),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: isHighlighted
                  ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.0)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withValues(alpha: isHighlighted ? 0.45 : 0.25),
                  blurRadius: isHighlighted ? 18 : 12,
                  offset: const Offset(0, 6),
                  spreadRadius: isHighlighted ? 2 : 1,
                ),
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative circle top right
                Positioned(
                  top: -25, right: -25,
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.white.withValues(alpha: 0.12), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // Decorative circle bottom left
                Positioned(
                  bottom: -20, left: -20,
                  child: Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.white.withValues(alpha: 0.07), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Icon + Arrow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: iconContainerSize,
                            height: iconContainerSize,
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(iconRadius),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                              boxShadow: isHighlighted
                                  ? [BoxShadow(color: Colors.white.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))]
                                  : null,
                            ),
                            child: Icon(icon, color: textLight, size: iconSize),
                          ),
                          // Arrow
                          Container(
                            width: (isSmallScreen ? 26 : 30) * sf,
                            height: (isSmallScreen ? 26 : 30) * sf,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular((isSmallScreen ? 8 : 10) * sf),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                            ),
                            child: Icon(Icons.arrow_forward_rounded, size: (isSmallScreen ? 13 : 15) * sf, color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Title & Subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w800, color: textLight, letterSpacing: -0.3, height: 1.25),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: spacing),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: subtitleSize, fontWeight: FontWeight.w400, color: subtextColor, letterSpacing: 0.1, height: 1.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Top accent line
                Positioned(
                  top: 0, left: 25, right: 25,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1.5),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.3),
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}