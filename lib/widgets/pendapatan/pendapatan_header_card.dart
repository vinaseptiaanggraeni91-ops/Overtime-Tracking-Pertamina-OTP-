import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PendapatanHeaderCard extends StatefulWidget {
  final double totalPendapatan;
  final int totalLembur;
  final double totalJam;
  final String bulan;
  final int tepatWaktu;
  final int terlambat;

  const PendapatanHeaderCard({
    super.key,
    required this.totalPendapatan,
    required this.totalLembur,
    required this.totalJam,
    required this.bulan,
    required this.tepatWaktu,
    required this.terlambat,
  });

  @override
  State<PendapatanHeaderCard> createState() => _PendapatanHeaderCardState();
}

class _PendapatanHeaderCardState extends State<PendapatanHeaderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            // Shadow utama
            BoxShadow(
              color: const Color(0xFF1B5E20).withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            // Shadow sekunder (glow)
            BoxShadow(
              color: const Color(0xFF2E7D32).withOpacity(0.2),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              //═══════════════════════════════════════════
              // BACKGROUND GRADIENT
              //═══════════════════════════════════════════
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0D3B0F), // Darker green
                      Color(0xFF1B5E20),
                      Color(0xFF2E7D32),
                      Color(0xFF388E3C), // Lighter green
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              //═══════════════════════════════════════════
              // DECORATIVE CIRCLES (Background pattern)
              //═══════════════════════════════════════════
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.03),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                left: -40,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),

              //═══════════════════════════════════════════
              // DOTS PATTERN
              //═══════════════════════════════════════════
              ...List.generate(12, (index) {
                final random = math.Random(index * 7);
                return Positioned(
                  top: random.nextDouble() * 160,
                  right: random.nextDouble() * 80,
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                );
              }),

              //═══════════════════════════════════════════
              // CONTENT
              //═══════════════════════════════════════════
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    // ─── LABEL ────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Estimasi Pendapatan',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ─── TOTAL PENDAPATAN ──────────────────
                    // Animated counter feel (static number with shadow)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        _formatRupiah(widget.totalPendapatan),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: widget.totalPendapatan >= 10000000 ? 28 : 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.2,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ─── BULAN BADGE ──────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatBulan(widget.bulan),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── DIVIDER ──────────────────────────
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ─── STATS GRID ───────────────────────
                    Row(
                      children: [
                        _buildStatItem(
                          icon: Icons.work_history_rounded,
                          value: '${widget.totalLembur}',
                          label: 'Total\nLembur',
                          color: const Color(0xFFFFD54F),
                        ),
                        _buildStatDivider(),
                        _buildStatItem(
                          icon: Icons.timer_rounded,
                          value: _formatJamCompact(widget.totalJam),
                          label: 'Total\nJam',
                          color: const Color(0xFF81D4FA),
                        ),
                        _buildStatDivider(),
                        _buildStatItem(
                          icon: Icons.check_circle_rounded,
                          value: '${widget.tepatWaktu}',
                          label: 'Tepat\nWaktu',
                          color: const Color(0xFFA5D6A7),
                        ),
                        _buildStatDivider(),
                        _buildStatItem(
                          icon: Icons.warning_amber_rounded,
                          value: '${widget.terlambat}',
                          label: 'Terlambat',
                          color: widget.terlambat > 0
                              ? const Color(0xFFFFAB91)
                              : Colors.white38,
                          blink: widget.terlambat > 0,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

 
  // STAT ITEM
 
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    bool blink = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          // Icon container
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(height: 8),
          // Value
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              color: Colors.white.withOpacity(0.65),
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
    );
  }

 
  // FORMATTING HELPERS
 
  String _formatRupiah(double amount) {
    if (amount == 0) return 'Rp 0';
    
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatBulan(String bulan) {
    try {
      final date = DateTime.parse('$bulan-01');
      return DateFormat('MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return bulan;
    }
  }

  String _formatJamCompact(double hours) {
    if (hours == 0) return '0';
    if (hours >= 10) {
      return '${hours.toStringAsFixed(0)}';
    }
    return hours.toStringAsFixed(1);
  }
}