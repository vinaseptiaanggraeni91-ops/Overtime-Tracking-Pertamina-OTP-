// lib/widgets/overtime_history/month_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class MonthPickerSheet {
  static void show(
    BuildContext context, {
    required String selectedMonth,
    required ValueChanged<String> onMonthSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthPickerContent(
        selectedMonth: selectedMonth,
        onMonthSelected: onMonthSelected,
      ),
    );
  }
}

class _MonthPickerContent extends StatefulWidget {
  final String selectedMonth;
  final ValueChanged<String> onMonthSelected;

  const _MonthPickerContent({
    required this.selectedMonth,
    required this.onMonthSelected,
  });

  @override
  State<_MonthPickerContent> createState() => _MonthPickerContentState();
}

class _MonthPickerContentState extends State<_MonthPickerContent>
    with SingleTickerProviderStateMixin {
  int _yearOffset = 0;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  static const Color primaryColor = Color(0xFF0F172A);
  static const Color secondaryColor = Color(0xFF1E293B);
  static const Color accentColor = Color(0xFF2563EB);
  static const Color backgroundColor = Color(0xFFF8FAFC);

  final List<Map<String, dynamic>> months = [
    {'name': 'Jan', 'icon': Icons.ac_unit_rounded, 'color': Color(0xFF3B82F6)},
    {'name': 'Feb', 'icon': Icons.favorite_rounded, 'color': Color(0xFFEC4899)},
    {'name': 'Mar', 'icon': Icons.eco_rounded, 'color': Color(0xFF22C55E)},
    {'name': 'Apr', 'icon': Icons.water_drop_rounded, 'color': Color(0xFF06B6D4)},
    {'name': 'Mei', 'icon': Icons.local_florist_rounded, 'color': Color(0xFF8B5CF6)},
    {'name': 'Jun', 'icon': Icons.wb_sunny_rounded, 'color': Color(0xFFF59E0B)},
    {'name': 'Jul', 'icon': Icons.beach_access_rounded, 'color': Color(0xFF0EA5E9)},
    {'name': 'Agu', 'icon': Icons.flag_rounded, 'color': Color(0xFFEF4444)},
    {'name': 'Sep', 'icon': Icons.school_rounded, 'color': Color(0xFF6366F1)},
    {'name': 'Okt', 'icon': Icons.spa_rounded, 'color': Color(0xFFF97316)},
    {'name': 'Nov', 'icon': Icons.coffee_rounded, 'color': Color(0xFF64748B)},
    {'name': 'Des', 'icon': Icons.card_giftcard_rounded, 'color': Color(0xFF14B8A6)},
  ];

  DateTime get _displayedYear => DateTime(DateTime.now().year + _yearOffset);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeYear(int value) {
    setState(() {
      _yearOffset += value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .15),
          end: Offset.zero,
        ).animate(_fadeAnimation),
        child: Container(
          height: size.height * 0.82, // 🔥 Tinggikan dari 0.76 ke 0.82
          decoration: const BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // HANDLE
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(30),
                ),
              ),

              const SizedBox(height: 20),

              // HEADER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(.15),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Bulan',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Filter histori lembur berdasarkan bulan',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        widget.onMonthSelected(currentMonth);
                        context.pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(.25),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.today_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'Sekarang',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20), // 🔥 Kurangi dari 24 ke 20

              // YEAR SELECTOR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      _yearButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => _changeYear(-1),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${_displayedYear.year}',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                      _yearButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: _yearOffset >= 2 ? null : () => _changeYear(1),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18), // 🔥 Kurangi dari 22 ke 18

              // 🔥🔥🔥 GRID - PERBAIKAN UTAMA
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12, // 🔥 Kurangi dari 14 ke 12
                    mainAxisSpacing: 12, // 🔥 Kurangi dari 14 ke 12
                    childAspectRatio: 1.15, // 🔥🔥🔥 UBAH dari 0.95 ke 1.15 (lebih tinggi)
                  ),
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final monthDate = DateTime(_displayedYear.year, month);
                    final monthStr = DateFormat('yyyy-MM').format(monthDate);
                    final bool isSelected = widget.selectedMonth == monthStr;
                    final bool isCurrentMonth = currentMonth == monthStr;
                    final data = months[index];

                    return _MonthCard(
                      month: month,
                      title: data['name'],
                      icon: data['icon'],
                      color: data['color'],
                      isSelected: isSelected,
                      isCurrentMonth: isCurrentMonth,
                      onTap: () {
                        widget.onMonthSelected(monthStr);
                        context.pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _yearButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final bool disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: disabled ? Colors.grey.shade400 : primaryColor,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔥🔥🔥 PERBAIKAN _MonthCard
// ═══════════════════════════════════════════════════════════
class _MonthCard extends StatefulWidget {
  final int month;
  final String title;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isCurrentMonth;
  final VoidCallback onTap;

  const _MonthCard({
    required this.month,
    required this.title,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isCurrentMonth,
    required this.onTap,
  });

  @override
  State<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends State<_MonthCard>
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
    _scaleAnimation = Tween<double>(begin: 1, end: .96).animate(_controller);
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
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(10), // 🔥 Kurangi padding dari 14 ke 10
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: widget.isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [widget.color, widget.color.withOpacity(.82)],
                  )
                : null,
            color: widget.isSelected ? null : Colors.white,
            border: Border.all(
              color: widget.isSelected
                  ? widget.color
                  : widget.isCurrentMonth
                      ? widget.color.withOpacity(.4)
                      : Colors.grey.shade200,
              width: widget.isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? widget.color.withOpacity(.22)
                    : Colors.black.withOpacity(.03),
                blurRadius: widget.isSelected ? 18 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // 🔥🔥🔥 GUNAKAN FittedBox atau Flexible untuk mencegah overflow
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // 🔥 Gunakan min
              children: [
                // 🔥 ICON - perkecil ukuran
                Container(
                  width: 40, // 🔥 Kurangi dari 52 ke 40
                  height: 40, // 🔥 Kurangi dari 52 ke 40
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isSelected
                        ? Colors.white.withOpacity(.18)
                        : widget.color.withOpacity(.10),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.isSelected ? Colors.white : widget.color,
                    size: 20, // 🔥 Kurangi dari 24 ke 20
                  ),
                ),

                const SizedBox(height: 8), // 🔥 Kurangi dari 14 ke 8

                // 🔥 TITLE
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 13, // 🔥 Kurangi dari 15 ke 13
                    fontWeight: FontWeight.w700,
                    color: widget.isSelected ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 2), // 🔥 Kurangi dari 3 ke 2

                // 🔥 SUBTITLE
                Text(
                  'Bulan ${widget.month}',
                  style: GoogleFonts.poppins(
                    fontSize: 10, // 🔥 Kurangi dari 11 ke 10
                    fontWeight: FontWeight.w500,
                    color: widget.isSelected ? Colors.white70 : Colors.grey.shade500,
                  ),
                ),

                // 🔥 CURRENT BADGE
                if (widget.isCurrentMonth && !widget.isSelected) ...[
                  const SizedBox(height: 4), // 🔥 Kurangi dari 8 ke 4
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // 🔥 Kurangi
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'NOW', // 🔥 Singkat dari 'CURRENT' ke 'NOW'
                      style: GoogleFonts.poppins(
                        fontSize: 8, // 🔥 Kurangi dari 9 ke 8
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}