// lib/widgets/pengawas/pengawas_stats_grid.dart
import 'package:flutter/material.dart';
import '/core/services/pengawas_service.dart';

/// Premium Pengawas Stats Grid
/// 🎨 Desain khusus Pengawas - Fokus pada Tim & Lembur
class PengawasStatsGrid extends StatelessWidget {
  final PengawasDashboardData data;
  final VoidCallback? onRefresh;

  const PengawasStatsGrid({
    super.key,
    required this.data,
    this.onRefresh,
  });

  // ==================== 🎨 COLOR CONSTANTS ====================
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFF97316);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF10B981);
  static const Color neutralGray = Color(0xFF64748B);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color surfaceLight = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 420;
    
    // ✅ Responsive sizing
    final headerIconSize = isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 18.0);
    final headerTitleSize = isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 15.0);
    final headerSubtitleSize = isSmallScreen ? 9.0 : (isMediumScreen ? 10.0 : 11.0);
    final gridSpacing = isSmallScreen ? 8.0 : (isMediumScreen ? 10.0 : 12.0);
    final cardAspectRatio = isSmallScreen ? 1.0 : (isMediumScreen ? 1.05 : 1.15);
    final headerPadding = isSmallScreen ? 8.0 : (isMediumScreen ? 10.0 : 12.0);

    // ✅ Data dari service
    final totalLemburMonth = data.totalLemburMonth;
    final pendingApproval = data.pendingApproval;
    final todayApproved = data.todayApproved; // 🔥 Disetujui hari ini
    final rejected = data.rejected; // 🔥 Ditolak
    
    // Build stat items
    final items = _buildStatItems(
      totalLemburBulan: totalLemburMonth,
      pending: pendingApproval,
      disetujuiHariIni: todayApproved,
      ditolak: rejected,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        /// 🎯 HEADER SECTION
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              _buildHeaderIcon(isSmallScreen, headerPadding, headerIconSize),
              SizedBox(width: isSmallScreen ? 8 : 10),
              _buildHeaderText(isSmallScreen, headerTitleSize, headerSubtitleSize),
              if (onRefresh != null)
                _buildRefreshButton(isSmallScreen, headerPadding, headerIconSize),
            ],
          ),
        ),

        SizedBox(height: isSmallScreen ? 8 : 12),

        /// 📊 MAIN STATS GRID - 2×2 layout
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: gridSpacing,
            mainAxisSpacing: gridSpacing,
            childAspectRatio: cardAspectRatio,
          ),
          itemBuilder: (context, index) => _buildCard(items[index], isSmallScreen),
        ),
        
        SizedBox(height: isSmallScreen ? 4 : 6),
      ],
    );
  }

  // ==================== 🎨 HEADER COMPONENTS ====================
  
  Widget _buildHeaderIcon(bool isSmallScreen, double headerPadding, double iconSize) {
    return Container(
      padding: EdgeInsets.all(headerPadding * 0.8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.2),
            blurRadius: isSmallScreen ? 6 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(Icons.analytics_rounded, color: Colors.white, size: iconSize),
    );
  }

  Widget _buildHeaderText(bool isSmallScreen, double titleSize, double subtitleSize) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ringkasan Lembur',
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isSmallScreen ? 1 : 2),
          Text(
            'Status pengajuan lembur bulan ini',
            style: TextStyle(
              fontSize: subtitleSize,
              color: textSecondary,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton(bool isSmallScreen, double headerPadding, double iconSize) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
        onTap: onRefresh,
        child: Container(
          padding: EdgeInsets.all(headerPadding * 0.7),
          decoration: BoxDecoration(
            color: surfaceLight,
            borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
            border: Border.all(color: borderLight, width: 0.8),
          ),
          child: Icon(Icons.refresh_rounded, size: iconSize, color: textSecondary),
        ),
      ),
    );
  }

  // ==================== 🃏 CARD BUILDER ====================
  
  Widget _buildCard(_StatItem item, bool isSmallScreen) {
    final iconSize = isSmallScreen ? 16.0 : 20.0;
    final valueSize = isSmallScreen ? 22.0 : 28.0;
    final titleSize = isSmallScreen ? 10.0 : 12.0;
    final subtitleSize = isSmallScreen ? 8.0 : 10.0;
    final padding = isSmallScreen ? 10.0 : 14.0;
    final spacing = isSmallScreen ? 3.0 : 4.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: item.gradientColors.first.withOpacity(0.25),
            blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -15,
            right: -15,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ICON + BADGE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 5 : 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, size: iconSize, color: Colors.white),
                    ),
                    if (item.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: spacing),

                // VALUE
                Text(
                  item.value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: valueSize,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                ),

                SizedBox(height: spacing),

                // TITLE
                Text(
                  item.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                ),

                // SUBTITLE
                if (item.subtitle.isNotEmpty) ...[
                  SizedBox(height: 1),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: subtitleSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                // TREND
                if (item.trend != null) ...[
                  SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.trend!,
                      style: TextStyle(
                        color: item.trendColor ?? Colors.white,
                        fontSize: isSmallScreen ? 7 : 9,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 📊 STAT ITEMS BUILDER ====================
  
  List<_StatItem> _buildStatItems({
    required int totalLemburBulan,
    required int pending,
    required int disetujuiHariIni,
    required int ditolak,
  }) {
    return [
      // 🔥 Card 1: Total Lembur Bulan Ini
      _StatItem(
        title: 'Total Lembur',
        value: '$totalLemburBulan',
        icon: Icons.calendar_month_rounded,
        subtitle: 'Bulan ini',
        gradientColors: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        badge: totalLemburBulan > 0 ? '📋' : null,
        trend: totalLemburBulan > 0 
            ? '📊 $totalLemburBulan pengajuan' 
            : 'Belum ada pengajuan',
        trendColor: totalLemburBulan > 0 ? Colors.white : Colors.white70,
      ),
      
      // 🔥 Card 2: Pending
      _StatItem(
        title: 'Pending',
        value: '$pending',
        icon: Icons.hourglass_empty_rounded,
        subtitle: pending > 0 
            ? 'Menunggu persetujuan'
            : 'Tidak ada pending',
        gradientColors: pending > 5 
            ? [dangerRed, const Color(0xFFDC2626)]
            : pending > 0 
                ? [warningOrange, const Color(0xFFEA580C)]
                : [neutralGray, const Color(0xFF475569)],
        badge: pending > 5 ? '⚠️' : (pending > 0 ? '⏳' : '✅'),
        trend: pending > 0 
            ? '📌 $pending perlu ditinjau'
            : '✅ Semua clear',
        trendColor: pending > 0 ? Colors.amberAccent : Colors.greenAccent,
      ),
      
      // 🔥 Card 3: Disetujui Hari Ini
      _StatItem(
        title: 'Disetujui',
        value: '$disetujuiHariIni',
        icon: Icons.check_circle_rounded,
        subtitle: 'Hari ini',
        gradientColors: disetujuiHariIni > 0
            ? [successGreen, const Color(0xFF059669)]
            : [infoBlue, const Color(0xFF0284C7)],
        badge: disetujuiHariIni > 0 ? '✅' : '📅',
        trend: disetujuiHariIni > 0 
            ? '🎉 $disetujuiHariIni disetujui' 
            : 'Belum ada hari ini',
        trendColor: disetujuiHariIni > 0 ? Colors.greenAccent : Colors.white70,
      ),
      
      // 🔥 Card 4: Ditolak
      _StatItem(
        title: 'Ditolak',
        value: '$ditolak',
        icon: Icons.cancel_rounded,
        subtitle: ditolak > 0 
            ? 'Perlu direvisi'
            : 'Tidak ada penolakan',
        gradientColors: ditolak > 3
            ? [dangerRed, const Color(0xFFDC2626)]
            : ditolak > 0
                ? [const Color(0xFFF43F5E), const Color(0xFFE11D48)]
                : [neutralGray, const Color(0xFF475569)],
        badge: ditolak > 3 ? '🚫' : (ditolak > 0 ? '❌' : '✅'),
        trend: ditolak > 0 
            ? '⚠️ $ditolak ditolak'
            : '✅ Tidak ada',
        trendColor: ditolak > 0 ? Colors.redAccent : Colors.greenAccent,
      ),
    ];
  }
}

// ==================== 📦 STAT ITEM DATA CLASS ====================

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final String subtitle;
  final List<Color> gradientColors;
  final String? badge;
  final String? trend;
  final Color? trendColor;

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    required this.gradientColors,
    this.badge,
    this.trend,
    this.trendColor,
  });
}