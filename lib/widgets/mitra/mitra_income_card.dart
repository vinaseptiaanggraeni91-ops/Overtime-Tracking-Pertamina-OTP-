// lib/widgets/mitra/mitra_income_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MitraIncomeCard extends StatelessWidget {
  final double totalIncome;
  final String periodLabel;
  final double? totalJam;
  final int? totalLembur;

  const MitraIncomeCard({
    super.key,
    required this.totalIncome,
    this.periodLabel = 'Bulan Ini',
    this.totalJam,
    this.totalLembur,
  });

  // ═══════════════════════════════════════════════════════
  // 🔵 PREMIUM NAVY BLUE PALETTE
  // ═══════════════════════════════════════════════════════
  static const Color darkNavy = Color(0xFF0F2448);
  static const Color navy = Color(0xFF1E3C72);
  static const Color royal = Color(0xFF2A5298);
  static const Color medium = Color(0xFF3B6CB4);
  static const Color accent = Color(0xFF5B8DEF);
  static const Color soft = Color(0xFF8DB3FF);
  static const Color gold = Color(0xFFFFAB40);
  static const Color cyan = Color(0xFF4FC3F7);

  // Gradient background - navy premium
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkNavy, navy, royal, medium],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final formattedIncome = NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0,
    ).format(totalIncome);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            // Deep shadow
            BoxShadow(
              color: darkNavy.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 12),
              spreadRadius: 2,
            ),
            // Top highlight
            BoxShadow(
              color: accent.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            // --- Decorative Elements ---

            // Large glow circle top-right
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withOpacity(0.25),
                      royal.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Small glow circle bottom-left
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      soft.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Decorative coin/icon pattern
            Positioned(
              top: 20,
              right: 20,
              child: Opacity(
                opacity: 0.05,
                child: Icon(
                  Icons.payments_rounded,
                  size: 120,
                  color: Colors.white,
                ),
              ),
            ),

            // Dot pattern bottom-right
            Positioned(
              bottom: 20,
              right: 20,
              child: Opacity(
                opacity: 0.08,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (i) => Padding(
                      padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          3,
                          (j) => Padding(
                            padding: EdgeInsets.only(top: j > 0 ? 8 : 0),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- Main Content ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wallet Icon with glow
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Amount
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge Period
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accent,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent,
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Estimasi $periodLabel',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Income Amount with shimmer effect
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                soft,
                                Colors.white,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              formattedIncome,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Divider with gradient
                Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Stats Row (optional)
                if (totalJam != null || totalLembur != null)
                  Row(
                    children: [
                      if (totalLembur != null)
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.work_history_rounded,
                            label: 'Total Lembur',
                            value: '${totalLembur}x',
                            color: gold,
                          ),
                        ),
                      if (totalLembur != null && totalJam != null)
                        Container(
                          width: 1.5,
                          height: 45,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0),
                                Colors.white.withOpacity(0.2),
                                Colors.white.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                      if (totalJam != null)
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.timer_rounded,
                            label: 'Total Jam',
                            value: _formatJam(totalJam!),
                            color: cyan,
                          ),
                        ),
                    ],
                  ),

                // Disclaimer if no stats
                if (totalJam == null && totalLembur == null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Estimasi berdasarkan tarif lembur per jam. Nominal final ditentukan bagian keuangan.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // STAT ITEM
  // ═══════════════════════════════════════════════════════
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animValue)),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container with glow
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          // Value
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          // Label
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // FORMATTER
  // ═══════════════════════════════════════════════════════
  String _formatJam(double hours) {
    if (hours == 0) return '0 jam';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '$m mnt';
    if (m == 0) return '$h jam';
    return '$h jam $m mnt';
  }
}