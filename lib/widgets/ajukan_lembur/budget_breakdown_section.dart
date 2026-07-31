// lib/widgets/ajukan_lembur/budget_breakdown_section.dart
import 'package:flutter/material.dart';
import 'section_card.dart';

class BudgetBreakdownSection extends StatelessWidget {
  final double totalJam;
  final int validMirasCount;
  final double biayaLemburPerMitra;
  final double totalBiayaLembur;
  final String Function(double) formatRupiah;
  final bool isMultiDay;       // 🔥 BARU
  final bool isOvernight;      // 🔥 BARU

  const BudgetBreakdownSection({
    super.key,
    required this.totalJam,
    required this.validMirasCount,
    required this.biayaLemburPerMitra,
    required this.totalBiayaLembur,
    required this.formatRupiah,
    this.isMultiDay = false,   // 🔥 BARU
    this.isOvernight = false,  // 🔥 BARU
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return SectionCard(
      title: 'Rincian Biaya Lembur',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF6A1B9A),
      children: [
        // 🔥 BADGE MULTI-DAY / OVERNIGHT
        if (isMultiDay || isOvernight) ...[
          _buildSpecialBadge(isSmallScreen),
          const SizedBox(height: 12),
        ],
        _buildHeaderInfo(isSmallScreen),
        const SizedBox(height: 12),
        _buildRateInfo(isSmallScreen),
        const SizedBox(height: 12),
        _buildBudgetItem(
          icon: Icons.person_rounded,
          title: 'Biaya per Mitra',
          detail: '${totalJam.toStringAsFixed(1)} jam × tarif lembur${isMultiDay ? ' (multi-hari)' : ''}',
          amount: formatRupiah(biayaLemburPerMitra),
          color: const Color(0xFF1976D2),
          isSmallScreen: isSmallScreen,
        ),
        const Divider(height: 20),
        _buildBudgetItem(
          icon: Icons.people_rounded,
          title: 'Total Biaya Lembur',
          detail: '$validMirasCount mitra × ${formatRupiah(biayaLemburPerMitra)}',
          amount: formatRupiah(totalBiayaLembur),
          color: const Color(0xFF00897B),
          isTotal: true,
          isSmallScreen: isSmallScreen,
        ),
        const SizedBox(height: 12),
        _buildGrandTotal(isSmallScreen),
        const SizedBox(height: 10),
        _buildFooterNote(isSmallScreen),
      ],
    );
  }

  // ==================== SPECIAL BADGE (MULTI-DAY / OVERNIGHT) ====================
  Widget _buildSpecialBadge(bool isSmallScreen) {
    final Color badgeColor = isMultiDay ? Colors.purple : const Color(0xFF7B1FA2);
    final IconData badgeIcon = isMultiDay ? Icons.date_range_rounded : Icons.nights_stay_rounded;
    final String badgeTitle = isMultiDay ? 'Lembur Multi-Hari' : 'Lembur Lintas Malam';
    final String badgeDesc = isMultiDay 
        ? 'Biaya dihitung per hari kalender (rate weekday/weekend)'
        : 'Durasi lembur melewati tengah malam';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            badgeColor.withValues(alpha: 0.08),
            badgeColor.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(badgeIcon, size: isSmallScreen ? 16 : 20, color: badgeColor),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badgeTitle,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  badgeDesc,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 11,
                    color: badgeColor.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HEADER INFO ====================
  Widget _buildHeaderInfo(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6A1B9A).withValues(alpha: 0.05),
            const Color(0xFF6A1B9A).withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6A1B9A).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calculate_rounded,
              color: const Color(0xFF6A1B9A),
              size: isSmallScreen ? 16 : 20,
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perhitungan Biaya Lembur',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6A1B9A),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 4 : 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildInfoChip(
                      icon: Icons.people_outline,
                      label: '$validMirasCount mitra',
                      isSmallScreen: isSmallScreen,
                    ),
                    _buildInfoChip(
                      icon: Icons.timer_outlined,
                      label: '${totalJam.toStringAsFixed(1)} jam',
                      isSmallScreen: isSmallScreen,
                    ),
                    // 🔥 Multi-day chip
                    if (isMultiDay)
                      _buildInfoChip(
                        icon: Icons.date_range_rounded,
                        label: 'Multi-hari',
                        isSmallScreen: isSmallScreen,
                        customColor: Colors.purple,
                      ),
                    // 🔥 Overnight chip
                    if (isOvernight)
                      _buildInfoChip(
                        icon: Icons.nights_stay_rounded,
                        label: 'Lintas malam',
                        isSmallScreen: isSmallScreen,
                        customColor: const Color(0xFF7B1FA2),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== INFO CHIP ====================
  Widget _buildInfoChip({
    required IconData icon, 
    required String label,
    required bool isSmallScreen,
    Color? customColor,
  }) {
    final chipColor = customColor ?? const Color(0xFF6A1B9A);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 8, 
        vertical: isSmallScreen ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isSmallScreen ? 10 : 12, color: chipColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 9 : 11,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== RATE INFO ====================
  Widget _buildRateInfo(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: isSmallScreen ? 14 : 18,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMultiDay 
                  ? 'Biaya lembur dihitung per hari kalender dengan tarif weekday/weekend yang berlaku'
                  : 'Biaya lembur dihitung berdasarkan tarif per jam yang berlaku',
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 12,
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUDGET ITEM ====================
  Widget _buildBudgetItem({
    required IconData icon,
    required String title,
    required String detail,
    required String amount,
    required Color color,
    bool isTotal = false,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        color: isTotal ? color.withValues(alpha: 0.03) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isTotal
            ? Border.all(color: color.withValues(alpha: 0.2), width: 1.5)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon container
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 6 : (isTotal ? 10 : 8)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon, 
              size: isSmallScreen ? 14 : (isTotal ? 20 : 18), 
              color: color,
            ),
          ),
          SizedBox(width: isSmallScreen ? 6 : 10),
          
          // Title & Detail
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
                    fontSize: isSmallScreen 
                        ? (isTotal ? 11 : 10) 
                        : (isTotal ? 13 : 12),
                    color: isTotal ? color : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isSmallScreen ? 1 : 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 8 : 10,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: isSmallScreen ? 4 : 8),
          
          // Amount
          Flexible(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 6 : 10, 
                vertical: isSmallScreen ? 3 : 5,
              ),
              decoration: BoxDecoration(
                color: isTotal 
                    ? color.withValues(alpha: 0.1) 
                    : color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: isTotal
                    ? Border.all(color: color.withValues(alpha: 0.3))
                    : null,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amount,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen 
                        ? (isTotal ? 12 : 11) 
                        : (isTotal ? 14 : 13),
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== GRAND TOTAL ====================
  Widget _buildGrandTotal(bool isSmallScreen) {
    // 🔥 Warna gradien berubah untuk multi-day
    final List<Color> gradientColors = isMultiDay || isOvernight
        ? [const Color(0xFF7B1FA2), const Color(0xFF4A148C)]
        : [const Color(0xFF6A1B9A), const Color(0xFF4A148C)];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label TOTAL BIAYA LEMBUR
          Text(
            'TOTAL BIAYA LEMBUR',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isSmallScreen ? 9 : 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 10),
          
          // Nominal Total
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupiah(totalBiayaLembur),
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 20 : 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          
          // Info chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTotalInfoChip(
                icon: Icons.people_outline,
                label: '$validMirasCount mitra',
                isSmallScreen: isSmallScreen,
              ),
              _buildTotalInfoChip(
                icon: Icons.timer_outlined,
                label: '${totalJam.toStringAsFixed(1)} jam',
                isSmallScreen: isSmallScreen,
              ),
              if (isMultiDay)
                _buildTotalInfoChip(
                  icon: Icons.date_range_rounded,
                  label: 'Multi-hari',
                  isSmallScreen: isSmallScreen,
                ),
              if (isOvernight)
                _buildTotalInfoChip(
                  icon: Icons.nights_stay_rounded,
                  label: 'Lintas malam',
                  isSmallScreen: isSmallScreen,
                ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          
          // Badge estimasi
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 10 : 14, 
              vertical: isSmallScreen ? 5 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: isSmallScreen ? 10 : 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                SizedBox(width: isSmallScreen ? 4 : 6),
                Flexible(
                  child: Text(
                    isMultiDay 
                        ? 'Estimasi berdasarkan tarif multi-hari' 
                        : 'Estimasi berdasarkan tarif yang berlaku',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: isSmallScreen ? 8 : 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalInfoChip({
    required IconData icon, 
    required String label,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 3 : 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 9 : 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: isSmallScreen ? 9 : 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FOOTER NOTE ====================
  Widget _buildFooterNote(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline, 
            size: isSmallScreen ? 14 : 18, 
            color: Colors.amber.shade600,
          ),
          SizedBox(width: isSmallScreen ? 6 : 10),
          Expanded(
            child: Text(
              isMultiDay
                  ? 'Perhitungan biaya lembur multi-hari berdasarkan tarif per jam yang berlaku untuk setiap hari kalender (weekday/weekend). '
                    'Biaya final dapat disesuaikan setelah persetujuan.'
                  : 'Perhitungan biaya lembur berdasarkan tarif per jam yang berlaku. '
                    'Biaya final dapat disesuaikan setelah persetujuan.',
              style: TextStyle(
                fontSize: isSmallScreen ? 9 : 11,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}