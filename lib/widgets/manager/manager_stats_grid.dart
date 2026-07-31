// lib/widgets/manager/manager_stats_grid.dart
import 'package:flutter/material.dart';
import 'manager_stat_card.dart';

/// Premium Manager Stats Grid dengan dukungan HSSE Risk Monitoring
/// ✅ Selalu tampil PASS untuk semua fungsi manager
/// 🎨 Palette: Biru Navy (aman) → Orange (warning) → Merah (urgent)
class ManagerStatsGrid extends StatelessWidget {
  // Standard Properties
  final int totalTeamMembers;
  final int onlineMembers;
  final int totalPending;
  final int totalApproved;
  final double totalHoursThisMonth;
  final VoidCallback? onRefresh;
  final Function(String type)? onCardTap;

  // ✅ HSSE Risk Properties (SIMPLIFIED - Only Total)
  final bool isHSSEManager;
  final int totalRiskSubmissions;
  final bool hasUrgentRisk;
  final VoidCallback? onRiskCardTap;
  final VoidCallback? onViewAllRisk;

  // ✅ Display Options
  final bool showRiskSection;
  final bool showInsightBanner;
  final bool compactMode;
  final String? customTitle;
  final String? customSubtitle;

  // ✅ NEW: Overtime notification properties
  final bool hasOvertimeSubmission;
  final int overtimeCount;
  final String? overtimeMessage;
  final VoidCallback? onOvertimeTap;

  const ManagerStatsGrid({
    super.key,
    required this.totalTeamMembers,
    required this.onlineMembers,
    required this.totalPending,
    required this.totalApproved,
    required this.totalHoursThisMonth,
    this.onRefresh,
    this.onCardTap,
    
    // HSSE Properties (default)
    this.isHSSEManager = false,
    this.totalRiskSubmissions = 0,
    this.hasUrgentRisk = false,
    this.onRiskCardTap,
    this.onViewAllRisk,
    
    // Display Options (default)
    this.showRiskSection = true,
    this.showInsightBanner = true,
    this.compactMode = false,
    this.customTitle,
    this.customSubtitle,
    
    // ✅ NEW: Overtime notification (default)
    this.hasOvertimeSubmission = false,
    this.overtimeCount = 0,
    this.overtimeMessage,
    this.onOvertimeTap,
    
    // ✅ Deprecated - dipertahankan untuk backward compatibility
    @Deprecated('Gunakan totalRiskSubmissions') int highRiskPending = 0,
    @Deprecated('Tidak digunakan lagi') int mediumRiskPending = 0,
    @Deprecated('Tidak digunakan lagi') int lowRiskPending = 0,
    @Deprecated('Tidak digunakan lagi') List<Map<String, dynamic>>? riskDetails,
  });

  // ==================== 🎨 COLOR CONSTANTS ====================
  static const Color primaryNavy = Color(0xFF1A2744);
  static const Color primaryBlue = Color(0xFF1E3C72);
  static const Color secondaryBlue = Color(0xFF2D5AA0);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color dangerDark = Color(0xFFDC2626);
  static const Color warningOrange = Color(0xFFF97316);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF10B981);
  static const Color neutralGray = Color(0xFF64748B);
  static const Color neutralDark = Color(0xFF475569);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color surfaceLight = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final offlineMembers = totalTeamMembers - onlineMembers;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // ✅ Responsive calculations
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 420;
    
    // ✅ Dynamic sizing
    final headerIconSize = isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0);
    final headerTitleSize = isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 17.0);
    final headerSubtitleSize = isSmallScreen ? 10.0 : (isMediumScreen ? 11.0 : 12.0);
    final gridSpacing = isSmallScreen ? 8.0 : (isMediumScreen ? 10.0 : 12.0);
    final cardAspectRatio = isSmallScreen 
        ? 1.05 
        : (isMediumScreen ? 1.20 : (screenWidth > 500 ? 1.40 : 1.30));
    final headerPadding = isSmallScreen ? 8.0 : (isMediumScreen ? 10.0 : 12.0);
    final bannerIconSize = isSmallScreen ? 14.0 : 16.0;
    final bannerFontSize = isSmallScreen ? 10.0 : 11.0;

    // ✅ Build stat items based on role
    final items = _buildStatItems();
    
    // ✅ HSSE Manager: 4 item → grid 2×2 (genap)
    // Non-HSSE Manager: 3 item → 2+1 full width (ganjil)
    final isOddCount = items.length % 2 != 0;

    // 🔥 DEBUG: Print untuk memastikan nilai totalRiskSubmissions
    debugPrint('📊 ManagerStatsGrid: isHSSEManager=$isHSSEManager, totalRiskSubmissions=$totalRiskSubmissions, hasUrgentRisk=$hasUrgentRisk');
    debugPrint('📊 ManagerStatsGrid: items count=${items.length}, isOddCount=$isOddCount');
    debugPrint('📊 ManagerStatsGrid: hasOvertimeSubmission=$hasOvertimeSubmission, overtimeCount=$overtimeCount');

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔥 NOTIFIKASI PENGAJUAN LEMBUR - DIPINDAHKAN KE ATAS
            if (hasOvertimeSubmission) ...[
              _buildOvertimeNotification(
                isSmallScreen: isSmallScreen,
                count: overtimeCount,
                message: overtimeMessage,
                onTap: onOvertimeTap,
              ),
              SizedBox(height: isSmallScreen ? 8 : 12),
            ],

            /// 🎯 HEADER SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  // Header Icon Container
                  _buildHeaderIcon(isSmallScreen, headerPadding, headerIconSize),
                  SizedBox(width: isSmallScreen ? 8 : 10),
                  // Title & Subtitle
                  _buildHeaderText(isSmallScreen, headerTitleSize, headerSubtitleSize),
                  // Refresh Button
                  if (onRefresh != null)
                    _buildRefreshButton(isSmallScreen, headerPadding, headerIconSize),
                ],
              ),
            ),

            SizedBox(height: isSmallScreen ? 8 : 12),

            /// 🔥 HSSE TOTAL RISK SUMMARY CARD
            /// ✅ Selalu tampil untuk HSSE Manager jika showRiskSection = true
            if (isHSSEManager && showRiskSection) ...[
              _buildHSSETotalRiskCard(
                isSmallScreen: isSmallScreen,
                totalRisk: totalRiskSubmissions, // ✅ Explicit passing
                hasUrgent: hasUrgentRisk,
                onTap: onViewAllRisk,
              ),
              SizedBox(height: isSmallScreen ? 8 : 12),
            ],

            /// 📊 MAIN STATS GRID
            if (isOddCount && !compactMode)
              _buildOddCountLayout(
                items: items,
                gridSpacing: gridSpacing,
                isSmallScreen: isSmallScreen,
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: compactMode ? 4 : 2,
                  crossAxisSpacing: gridSpacing,
                  mainAxisSpacing: gridSpacing,
                  childAspectRatio: compactMode ? 0.85 : cardAspectRatio,
                ),
                itemBuilder: (context, index) => _buildCard(items[index], index),
              ),

            /// 💡 INSIGHT BANNER
            if (showInsightBanner && (totalPending > 0 || offlineMembers > 0 || 
                (isHSSEManager && hasUrgentRisk))) ...[
              SizedBox(height: isSmallScreen ? 8 : 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildInsightBanner(
                  totalPending,
                  offlineMembers,
                  hasUrgentRisk,
                  iconSize: bannerIconSize,
                  fontSize: bannerFontSize,
                ),
              ),
            ],
            
            SizedBox(height: isSmallScreen ? 4 : 6),
          ],
        );
      },
    );
  }

  // ==================== 🔔 OVERTIME NOTIFICATION ====================
  
  /// ✅ Notifikasi pengajuan lembur yang ditampilkan di ATAS widget
  Widget _buildOvertimeNotification({
    required bool isSmallScreen,
    required int count,
    String? message,
    VoidCallback? onTap,
  }) {
    final notificationMessage = message ?? 'Ada $count pengajuan lembur yang perlu ditinjau';
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            warningOrange.withValues(alpha: 0.95),
            accentOrange.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: warningOrange.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                // Animated Icon Container
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.92, end: 1.08),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.access_time_filled_rounded,
                          color: Colors.white,
                          size: isSmallScreen ? 20 : 24,
                        ),
                      ),
                    );
                  },
                ),
                
                SizedBox(width: isSmallScreen ? 12 : 14),
                
                // Notification Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pengajuan Lembur',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: isSmallScreen ? 10 : 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 3),
                      Text(
                        notificationMessage,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Count Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 10,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          color: warningOrange,
                          fontSize: isSmallScreen ? 16 : 20,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 3 : 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: warningOrange,
                        size: isSmallScreen ? 12 : 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 🎨 HEADER COMPONENTS ====================
  
  Widget _buildHeaderIcon(bool isSmallScreen, double headerPadding, double iconSize) {
    return Container(
      padding: EdgeInsets.all(headerPadding * 0.8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHSSEManager && hasUrgentRisk
              ? [dangerRed, warningOrange]
              : [primaryBlue, secondaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        boxShadow: [
          BoxShadow(
            color: (isHSSEManager && hasUrgentRisk ? dangerRed : primaryBlue)
                .withValues(alpha: 0.2),
            blurRadius: isSmallScreen ? 6 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        isHSSEManager ? Icons.security_rounded : Icons.dashboard_rounded,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }

  Widget _buildHeaderText(bool isSmallScreen, double titleSize, double subtitleSize) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            customTitle ?? (isHSSEManager ? 'Ringkasan Kinerja & HSSE' : 'Ringkasan Kinerja'),
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
            customSubtitle ?? (isHSSEManager ? 'Ringkasan Kinerja, lembur & risiko' : 'Statistik tim & lembur'),
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

  // ==================== 📐 LAYOUT HELPERS ====================
  
  /// Layout untuk jumlah ganjil (3 card untuk Non-HSSE Manager)
  /// ✅ Card ke-3 FULL WIDTH di bawah
  Widget _buildOddCountLayout({
    required List<_StatItem> items,
    required double gridSpacing,
    required bool isSmallScreen,
  }) {
    // Safety check
    if (items.length < 3) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: gridSpacing,
          mainAxisSpacing: gridSpacing,
          childAspectRatio: 1.30,
        ),
        itemBuilder: (context, index) => _buildCard(items[index], index),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _buildCard(items[0], 0)),
            SizedBox(width: gridSpacing),
            Expanded(child: _buildCard(items[1], 1)),
          ],
        ),
        SizedBox(height: gridSpacing),
        _buildCard(items[2], 2),
      ],
    );
  }

  // ==================== 🃏 CARD BUILDER ====================
  
  Widget _buildCard(_StatItem item, int index) {
    return ManagerStatCard(
      title: item.title,
      value: item.value,
      icon: item.icon,
      subtitle: item.subtitle,
      gradientColors: item.gradientColors,
      badge: item.badge,
      index: index,
      isHSSECard: item.type == 'hss_risk',
      hasRiskAlert: item.type == 'hss_risk' && hasUrgentRisk,
      riskLevel: item.riskLevel,
      showPulseAnimation: item.type == 'hss_risk' && hasUrgentRisk,
      tooltipMessage: item.tooltipMessage,
      isCompact: compactMode,
      onTap: () {
        if (item.type == 'hss_risk' && onRiskCardTap != null) {
          onRiskCardTap!();
        } else if (onCardTap != null) {
          onCardTap!(item.type);
        }
      },
    );
  }

  // ==================== 📊 STAT ITEMS BUILDER ====================
  
  /// 🔥 MEMBANGUN DAFTAR STAT ITEMS
  /// - HSSE Manager: 4 item (Total Risiko, Total Tim, Pending, Disetujui)
  /// - Non-HSSE Manager: 3 item (Total Tim, Pending, Disetujui)
  List<_StatItem> _buildStatItems() {
    final items = <_StatItem>[];
    
    // ✅ HSSE Manager: SELALU tampilkan "Total Risiko" sebagai item pertama
    // 🎨 Warna dinamis: Biru Navy (0) → Orange (1-3) → Merah (>3 atau urgent)
    if (isHSSEManager) {
      final hasRisk = totalRiskSubmissions > 0;
      
      // Tentukan warna berdasarkan jumlah & urgensi
      List<Color> riskColors;
      String riskSubtitle;
      String? riskBadge;
      String riskLevel;
      IconData riskIcon;
      
      if (!hasRisk) {
        // Tidak ada risiko
        riskColors = [primaryNavy, primaryBlue];
        riskSubtitle = 'Semua aman terkendali';
        riskBadge = null;
        riskLevel = 'none';
        riskIcon = Icons.shield_outlined;
      } else if (hasUrgentRisk || totalRiskSubmissions > 3) {
        // Risiko tinggi/urgent
        riskColors = [dangerRed, dangerDark];
        riskSubtitle = hasUrgentRisk ? '⚠️ Perlu tindakan segera' : '⚠️ Banyak pengajuan berisiko';
        riskBadge = 'URGENT';
        riskLevel = 'high';
        riskIcon = Icons.warning_amber_rounded;
      } else {
        // Risiko sedang (1-3)
        riskColors = [warningOrange, accentOrange];
        riskSubtitle = 'Perlu ditinjau oleh HSSE';
        riskBadge = '!';
        riskLevel = 'medium';
        riskIcon = Icons.warning_rounded;
      }
      
      items.add(
        _StatItem(
          title: 'Total Risiko',
          value: '$totalRiskSubmissions',
          icon: riskIcon,
          subtitle: riskSubtitle,
          gradientColors: riskColors,
          badge: riskBadge,
          type: 'hss_risk',
          riskLevel: riskLevel,
          tooltipMessage: hasRisk
              ? '$totalRiskSubmissions pengajuan berisiko perlu ditinjau'
              : 'Semua pengajuan dalam kondisi aman',
        ),
      );
    }
    
    // ✅ Standard items (semua manager)
    // 🎨 Biru (team) → Abu (pending 0) / Oranye (pending 1-3) / Merah (pending >3) → Navy (approved)
    items.addAll([
      _StatItem(
        title: 'Total Tim',
        value: '$totalTeamMembers',
        icon: Icons.people_rounded,
        subtitle: '$onlineMembers online${isHSSEManager ? ' | Siap siaga' : ''}',
        gradientColors: [infoBlue, primaryBlue],
        type: 'team',
        tooltipMessage: 'Total anggota tim dengan status online',
      ),
      _StatItem(
        title: 'Pending',
        value: '$totalPending',
        icon: Icons.pending_actions_rounded,
        subtitle: 'Perlu persetujuan',
        gradientColors: totalPending > 0
            ? (totalPending > 3 
                ? [dangerRed, dangerDark]
                : [warningOrange, accentOrange])
            : [neutralGray, neutralDark],
        badge: totalPending > 3 ? 'Urgent' : (totalPending > 0 ? 'Ada' : null),
        type: 'pending',
        tooltipMessage: totalPending > 0
            ? '$totalPending pengajuan membutuhkan persetujuan Anda'
            : 'Tidak ada pengajuan yang perlu disetujui',
      ),
      _StatItem(
        title: 'Disetujui',
        value: '$totalApproved',
        icon: Icons.check_circle_rounded,
        subtitle: 'Approved',
        gradientColors: [primaryBlue, secondaryBlue],
        badge: totalApproved > 0 ? 'Done' : null,
        type: 'approved',
        tooltipMessage: 'Total pengajuan yang sudah disetujui',
      ),
    ]);
    
    return items;
  }

  // ==================== 🔥 HSSE TOTAL RISK CARD ====================

  /// ✅ Summary Card untuk Total Risiko HSSE
  /// Ditampilkan di atas grid untuk HSSE Manager
  /// 🎨 Biru Navy (aman=0) → Orange (1-3) → Merah (>3 atau urgent)
  Widget _buildHSSETotalRiskCard({
    required bool isSmallScreen,
    required int totalRisk,
    required bool hasUrgent,
    VoidCallback? onTap,
  }) {
    final hasRisk = totalRisk > 0;
    
    // Tentukan warna card
    final Color cardColor;
    final IconData cardIcon;
    final String statusText;
    
    if (!hasRisk) {
      cardColor = primaryBlue;
      cardIcon = Icons.shield_outlined;
      statusText = 'Tidak ada pengajuan berisiko';
    } else if (hasUrgent || totalRisk > 3) {
      cardColor = dangerRed;
      cardIcon = Icons.priority_high_rounded;
      statusText = '⚠️ Memerlukan tindakan segera';
    } else {
      cardColor = warningOrange;
      cardIcon = Icons.warning_amber_rounded;
      statusText = 'Perlu ditinjau oleh HSSE';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasRisk ? cardColor.withValues(alpha: 0.2) : borderLight,
          width: hasUrgent ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: hasRisk ? 0.06 : 0.03),
            blurRadius: hasUrgent ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated Icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.95, end: 1.05),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: hasUrgent ? value : 1.0,
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cardColor.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    cardIcon,
                    color: cardColor,
                    size: isSmallScreen ? 22 : 26,
                  ),
                ),
              );
            },
          ),
          
          SizedBox(width: isSmallScreen ? 12 : 16),
          
          // Info Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Pengajuan Berisiko',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalRisk',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 28 : 34,
                        fontWeight: FontWeight.w800,
                        color: hasRisk ? cardColor : textPrimary,
                        height: 1.1,
                      ),
                    ),
                    if (!hasRisk) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: successGreen,
                          size: isSmallScreen ? 14 : 18,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 11,
                    color: hasRisk ? cardColor : textTertiary,
                    fontWeight: hasRisk ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          
          // CTA Button
          if (onTap != null)
            _buildCTAButton(
              label: 'TINJAU',
              color: hasRisk ? cardColor : primaryBlue,
              isSmallScreen: isSmallScreen,
              onTap: onTap,
            ),
        ],
      ),
    );
  }

  Widget _buildCTAButton({
    required String label,
    required Color color,
    required bool isSmallScreen,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 10 : 14,
            vertical: isSmallScreen ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: isSmallScreen ? 14 : 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 💡 INSIGHT BANNER ====================

  Widget _buildInsightBanner(
    int pending, 
    int offline,
    bool hasUrgentRisk, {
    required double iconSize,
    required double fontSize,
  }) {
    String message;
    IconData icon;
    Color color;

    if (isHSSEManager && hasUrgentRisk) {
      message = '⚠️ Pengajuan berisiko butuh persetujuan segera!';
      icon = Icons.priority_high_rounded;
      color = dangerRed;
    } else if (pending > 3) {
      message = '$pending pengajuan butuh persetujuan segera';
      icon = Icons.warning_rounded;
      color = dangerRed;
    } else if (pending > 0) {
      message = 'Ada $pending pengajuan perlu ditinjau';
      icon = Icons.info_rounded;
      color = warningOrange;
    } else if (offline > 0) {
      message = '$offline anggota tim sedang offline';
      icon = Icons.people_outline_rounded;
      color = infoBlue;
    } else {
      message = 'Semua berjalan lancar!';
      icon = Icons.check_circle_rounded;
      color = successGreen;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize > 10 ? 12 : 10, 
        vertical: fontSize > 10 ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(width: fontSize > 10 ? 8 : 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isHSSEManager && hasUrgentRisk && onViewAllRisk != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onViewAllRisk,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.arrow_forward_rounded, color: color, size: iconSize),
                ),
              ),
            ),
        ],
      ),
    );
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
  final String type;
  
  // HSSE Properties
  final String? riskLevel;
  final String? tooltipMessage;

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    required this.gradientColors,
    this.badge,
    this.type = '',
    this.riskLevel,
    this.tooltipMessage,
  });
}