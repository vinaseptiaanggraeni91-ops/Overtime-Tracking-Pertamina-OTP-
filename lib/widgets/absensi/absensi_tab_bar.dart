// lib/screens/absensi/widgets/absensi_tab_bar.dart

import 'package:flutter/material.dart';

class AbsensiTabBar extends StatelessWidget {
  final int currentTabIndex;
  final int lateOvertimeCount;
  final Function(int) onTabChanged;

  const AbsensiTabBar({
    super.key,
    required this.currentTabIndex,
    required this.lateOvertimeCount,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: Row(
        children: [
          _TabItem(
            title: 'Absensi Normal',
            icon: Icons.today,
            isSelected: currentTabIndex == 0,
            color: const Color(0xFF1A237E),
            onTap: () => onTabChanged(0),
          ),
          _TabItem(
            title: 'Lembur Terlambat',
            icon: Icons.warning_amber_rounded,
            isSelected: currentTabIndex == 1,
            color: Colors.orange,
            badge: lateOvertimeCount > 0 ? '$lateOvertimeCount' : null,
            onTap: () => onTabChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _TabItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? color : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}