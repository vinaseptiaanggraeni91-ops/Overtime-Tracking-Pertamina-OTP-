// lib/widgets/overtime_history/overtime_filter_chips.dart
// 🔥 FINAL VERSION - TAMBAH TAB DIBATALKAN

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OvertimeFilterChips extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;

  const OvertimeFilterChips({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  static const List<Map<String, dynamic>> _filters = [
    {
      'value': 'semua',
      'label': 'Semua',
      'icon': Icons.apps_rounded,
      'color': Color(0xFF64748B),
    },
    {
      'value': 'pending',
      'label': 'Pending',
      'icon': Icons.schedule_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'value': 'disetujui',
      'label': 'Disetujui',
      'icon': Icons.verified_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'value': 'ditolak',
      'label': 'Ditolak',
      'icon': Icons.cancel_rounded,
      'color': Color(0xFFEF4444),
    },
    // 🔥🔥🔥 TAB DIBATALKAN (BARU)
    {
      'value': 'dibatalkan',
      'label': 'Dibatalkan',
      'icon': Icons.remove_circle_outline_rounded,
      'color': Color(0xFFF87171),
    },
    {
      'value': 'selesai',
      'label': 'Selesai',
      'icon': Icons.task_alt_rounded,
      'color': Color(0xFF2563EB),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = _filters[index];

          final bool isSelected =
              selectedStatus == filter['value'];

          final Color color =
              filter['color'] as Color;

          return _CorporateFilterChip(
            label: filter['label'] as String,
            icon: filter['icon'] as IconData,
            color: color,
            isSelected: isSelected,
            onTap: () =>
                onStatusChanged(filter['value'] as String),
          );
        },
      ),
    );
  }
}

class _CorporateFilterChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CorporateFilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CorporateFilterChip> createState() =>
      _CorporateFilterChipState();
}

class _CorporateFilterChipState
    extends State<_CorporateFilterChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: .96,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapCancel: () => _controller.reverse(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: widget.isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.color,
                      widget.color.withOpacity(.82),
                    ],
                  )
                : null,
            color: widget.isSelected
                ? null
                : Colors.white,
            border: Border.all(
              color: widget.isSelected
                  ? widget.color
                  : const Color(0xFFE2E8F0),
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? widget.color.withOpacity(.22)
                    : Colors.black.withOpacity(.04),
                blurRadius: widget.isSelected ? 18 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected
                      ? Colors.white.withOpacity(.18)
                      : widget.color.withOpacity(.10),
                ),
                child: Icon(
                  widget.icon,
                  size: 16,
                  color: widget.isSelected
                      ? Colors.white
                      : widget.color,
                ),
              ),

              const SizedBox(width: 10),

              Text(
                widget.label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: widget.isSelected
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: widget.isSelected
                      ? Colors.white
                      : const Color(0xFF1E293B),
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}