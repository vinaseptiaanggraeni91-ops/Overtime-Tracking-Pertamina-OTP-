// lib/widgets/bottom_nav/pengawas_bottom_nav.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PengawasBottomNav extends StatelessWidget {
  final int currentIndex;

  const PengawasBottomNav({
    super.key,
    required this.currentIndex,
  });

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/pengawas-dashboard');
        break;
      case 1:
        context.push('/ajukan-lembur');
        break;
      case 2:
        context.push('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(
        icon: Icons.dashboard_rounded,
        activeIcon: Icons.dashboard_customize_rounded,
        label: 'Dashboard',
      ),
      _NavItem(
        icon: Icons.add_alert_outlined,
        activeIcon: Icons.add_alert_rounded,
        label: 'Pengajuan', // 🔥 DIPER PENDEK (sebelumnya: 'Pengajuan Lembur')
      ),
      _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
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
                  colors: [
                    Color(0xFF1E3C72),
                    Color(0xFF2A5298),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white24,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3C72).withOpacity(0.25),
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
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _onTabTapped(context, index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: isSelected
                              ? Colors.white.withOpacity(0.15)
                              : Colors.transparent,
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white24,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.15)
                                      : Colors.transparent,
                                ),
                                child: Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  size: isSelected ? 22 : 20,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Flexible(
                                child: Text(
                                  item.label,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSelected ? 11 : 10,
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
  final IconData activeIcon;
  final String label;

  _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}