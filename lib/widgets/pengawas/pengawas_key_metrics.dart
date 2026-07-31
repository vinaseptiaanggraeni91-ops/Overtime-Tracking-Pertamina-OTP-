// lib/widgets/pengawas/pengawas_key_metrics.dart
import 'package:flutter/material.dart';

class PengawasKeyMetrics extends StatelessWidget {
  final int totalLemburWeek;
  final int pendingApprovals;
  final int totalTeamMembers;
  final int onlineMembers;
  final String Function(int) formatNumber;

  const PengawasKeyMetrics({
    super.key,
    required this.totalLemburWeek,
    required this.pendingApprovals,
    required this.totalTeamMembers,
    required this.onlineMembers,
    required this.formatNumber,
  });

  // ═══════════════════════════════════════════════════════
  // 🔵 PREMIUM NAVY BLUE PALETTE
  // ═══════════════════════════════════════════════════════
  static const Color primaryNavy = Color(0xFF1E3C72);
  static const Color darkNavy = Color(0xFF0F2448);
  static const Color royalBlue = Color(0xFF2A5298);
  static const Color accentBlue = Color(0xFF5B8DEF);
  
  static const Color warningGold = Color(0xFFF5AF19);
  static const Color tealGreen = Color(0xFF00B09B);
  static const Color purpleViolet = Color(0xFF834D9B);
  
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color bgPrimary = Color(0xFFF0F4FC);

  // Premium Gradients
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkNavy, primaryNavy, royalBlue],
  );
  
  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5AF19), Color(0xFFFFC107)],
  );

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            // Primary deep shadow
            BoxShadow(
              color: primaryNavy.withOpacity(0.12),
              blurRadius: 25,
              offset: const Offset(0, 10),
              spreadRadius: 2,
            ),
            // Secondary lighter shadow
            BoxShadow(
              color: accentBlue.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, -3),
              spreadRadius: 1,
            ),
            // Inner shadow effect
            BoxShadow(
              color: primaryNavy.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
              spreadRadius: -2,
            ),
          ],
          border: Border.all(
            color: primaryNavy.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: premiumGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryNavy.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Metrik Penting',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: darkNavy,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Ringkasan performa tim',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge total
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: premiumGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryNavy.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${formatNumber(totalTeamMembers)} Anggota',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Row 1: Lembur & Pending
            Row(
              children: [
                Expanded(
                  child: _buildPremiumMetricItem(
                    icon: Icons.work_history_rounded,
                    label: 'Lembur Minggu Ini',
                    value: formatNumber(totalLemburWeek),
                    color: primaryNavy,
                    gradient: premiumGradient,
                    subtitle: 'Total pengajuan',
                    trend: '+8%',
                    trendUp: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPremiumMetricItem(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pending',
                    value: formatNumber(pendingApprovals),
                    color: warningGold,
                    gradient: warningGradient,
                    subtitle: pendingApprovals > 0 ? 'Perlu persetujuan' : 'Tidak ada',
                    trend: pendingApprovals > 0 ? 'Aksi' : null,
                    trendUp: false,
                    isWarning: pendingApprovals > 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Row 2: Anggota & Online
            Row(
              children: [
                Expanded(
                  child: _buildPremiumMetricItem(
                    icon: Icons.people_rounded,
                    label: 'Anggota Tim',
                    value: formatNumber(totalTeamMembers),
                    color: tealGreen,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [tealGreen, tealGreen.withOpacity(0.8)],
                    ),
                    subtitle: 'Total terdaftar',
                    trend: '+2',
                    trendUp: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPremiumMetricItem(
                    icon: Icons.online_prediction_rounded,
                    label: 'Online Sekarang',
                    value: formatNumber(onlineMembers),
                    color: purpleViolet,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [purpleViolet, purpleViolet.withOpacity(0.8)],
                    ),
                    subtitle: onlineMembers > 0 ? 'Sedang aktif' : 'Tidak ada',
                    trend: onlineMembers > 0 ? 'Aktif' : null,
                    trendUp: true,
                    isOnline: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // PREMIUM METRIC ITEM
  // ═══════════════════════════════════════════════════════
  Widget _buildPremiumMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Gradient gradient,
    String? subtitle,
    String? trend,
    bool trendUp = true,
    bool isWarning = false,
    bool isOnline = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isWarning 
              ? warningGold.withOpacity(0.4)
              : color.withOpacity(0.15),
          width: isWarning ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with gradient
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Online indicator
              if (isOnline && onlineMembers > 0)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tealGreen,
                    boxShadow: [
                      BoxShadow(
                        color: tealGreen.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Value with premium typography
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: darkNavy,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: primaryNavy.withOpacity(0.7),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          // Subtitle or Trend
          if (subtitle != null || trend != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (subtitle != null)
                  Expanded(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: color.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (trend != null) ...[
                  if (subtitle != null) const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isWarning
                          ? warningGold.withOpacity(0.15)
                          : (trendUp ? tealGreen.withOpacity(0.15) : Colors.red.withOpacity(0.15)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isWarning
                            ? warningGold.withOpacity(0.3)
                            : (trendUp ? tealGreen.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isWarning
                              ? Icons.warning_amber_rounded
                              : (trendUp ? Icons.arrow_upward : Icons.arrow_downward),
                          size: 10,
                          color: isWarning
                              ? warningGold
                              : (trendUp ? tealGreen : Colors.red),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          trend,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isWarning
                                ? warningGold
                                : (trendUp ? tealGreen : Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}