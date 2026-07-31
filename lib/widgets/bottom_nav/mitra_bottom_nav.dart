// lib/widgets/mitra_bottom_nav.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MitraBottomNav extends StatelessWidget {
  final int currentIndex;

  const MitraBottomNav({
    super.key,
    required this.currentIndex,
  });

  // ═══════════════════════════════════════════════════════
  // 🔵 COLOR PALETTE - PERTAMINA BRANDING
  // ═══════════════════════════════════════════════════════
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color darkNavy = Color(0xFF0D47A1);
  static const Color royalBlue = Color(0xFF1E3C72);
  static const Color accentBlue = Color(0xFF42A5F5);
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color inactiveColor = Color(0xFFB0BEC5);

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/mitra-dashboard');
        break;
      case 1:
        context.go('/mitra-absensi');
        break;
      case 2:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
      ),
      _NavItem(
        icon: Icons.fingerprint_rounded,
        label: 'Absensi',
      ),
      _NavItem(
        icon: Icons.person_rounded,
        label: 'Profil',
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 10,
              sigmaY: 10,
            ),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [royalBlue, Color(0xFF2A5298)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: royalBlue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = currentIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTabTapped(context, index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          // 🔥 BACKGROUND AKTIF LEBIH KONTRAS
                          color: isSelected
                              ? Colors.white.withOpacity(0.2)
                              : Colors.transparent,
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white.withOpacity(0.35),
                                  width: 1.2,
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 🔥 GARIS INDIKATOR DI ATAS ICON
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              width: isSelected ? 24 : 0,
                              height: 3,
                              margin: EdgeInsets.only(
                                bottom: isSelected ? 6 : 0,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [accentBlue, Color(0xFF64B5F6)],
                                ),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: accentBlue.withOpacity(0.5),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),

                            // Icon
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: EdgeInsets.all(isSelected ? 7 : 5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? Colors.white.withOpacity(0.15)
                                    : Colors.transparent,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: accentBlue.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                item.icon,
                                // 🔥 ICON LEBIH BESAR SAAT AKTIF
                                size: isSelected ? 22 : 19,
                                color: isSelected
                                    ? whiteColor
                                    : inactiveColor.withOpacity(0.8),
                              ),
                            ),

                            const SizedBox(height: 2),

                            // Label
                            Flexible(
                              child: Text(
                                item.label,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  color: isSelected
                                      ? whiteColor
                                      : inactiveColor.withOpacity(0.8),
                                  fontSize: isSelected ? 10.5 : 9.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  _NavItem({
    required this.icon,
    required this.label,
  });
}