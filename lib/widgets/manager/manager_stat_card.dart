// lib/widgets/manager/manager_stat_card.dart
import 'package:flutter/material.dart';

/// Premium Manager Stat Card dengan dukungan penuh untuk HSSE Risk Data
class ManagerStatCard extends StatelessWidget {
  // Basic Properties
  final String title;
  final String value;
  final IconData icon;
  final String subtitle;
  final List<Color> gradientColors;
  final String? badge;
  final VoidCallback? onTap;
  final int index;

  // HSSE Risk Properties (NEW)
  final bool isHSSECard;
  final bool hasRiskAlert;
  final String? riskLevel;
  final int? highRiskCount;
  final int? mediumRiskCount;
  final int? lowRiskCount;
  final bool showPulseAnimation;
  final Widget? customIndicator;
  final String? tooltipMessage;
  final bool isCompact;
  final double? customHeight;
  final double? customWidth;

  // Animation Properties
  final bool enableHoverEffect;
  final bool enableShimmer;
  final Duration animationDuration;
  final Curve animationCurve;

  const ManagerStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
    required this.gradientColors,
    this.badge,
    this.onTap,
    this.index = 0,
    
    // HSSE Properties (default)
    this.isHSSECard = false,
    this.hasRiskAlert = false,
    this.riskLevel,
    this.highRiskCount,
    this.mediumRiskCount,
    this.lowRiskCount,
    this.showPulseAnimation = false,
    this.customIndicator,
    this.tooltipMessage,
    this.isCompact = false,
    this.customHeight,
    this.customWidth,
    
    // Animation Properties (default)
    this.enableHoverEffect = true,
    this.enableShimmer = false,
    this.animationDuration = const Duration(milliseconds: 500),
    this.animationCurve = Curves.easeOutBack,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final textScale = MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2);
    
    // Responsive Scaling
    final scaleFactor = _getScaleFactor(screenWidth);
    final finalScale = scaleFactor * textScale;

    // HSSE Alert Colors
    final riskColor = _getRiskColor();
    final hasRiskData = isHSSECard && hasRiskAlert;

    // Ukuran proporsional
    final iconSize = _getIconSize(finalScale);
    final valueSize = _getValueSize(finalScale);
    final titleSize = _getTitleSize(finalScale);
    final subtitleSize = _getSubtitleSize(finalScale);
    final badgeSize = _getBadgeSize(finalScale);
    final paddingSize = _getPaddingSize(finalScale);
    final iconPadding = _getIconPadding(finalScale);
    final spacing = _getSpacing(finalScale);

    // Build card based on type
    if (isCompact) {
      return _buildCompactCard(context, finalScale, riskColor, hasRiskData);
    }

    if (hasRiskData) {
      return _buildHSSERiskCard(context, finalScale, riskColor);
    }

    return _buildStandardCard(
      context, 
      finalScale, 
      iconSize, 
      valueSize, 
      titleSize, 
      subtitleSize, 
      badgeSize, 
      paddingSize, 
      iconPadding, 
      spacing
    );
  }

  // ==================== CARD BUILDERS ====================

  /// Standard Premium Card
  Widget _buildStandardCard(
    BuildContext context,
    double finalScale,
    double iconSize,
    double valueSize,
    double titleSize,
    double subtitleSize,
    double badgeSize,
    double paddingSize,
    double iconPadding,
    double spacing,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(
        milliseconds: animationDuration.inMilliseconds + (index * 100),
      ),
      curve: animationCurve,
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: Opacity(
            opacity: animation.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: _HoverableCard(
        enableHover: enableHoverEffect,
        onTap: onTap,
        tooltipMessage: tooltipMessage,
        child: Container(
          constraints: BoxConstraints(
            minHeight: customHeight ?? 140.0 * finalScale,
            maxHeight: customHeight ?? 180.0 * finalScale,
            minWidth: customWidth ?? 140.0 * finalScale,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.30),
                blurRadius: 20,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: gradientColors.last.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative Elements
              _buildDecorativeCircles(),
              
              // Shimmer Effect (if enabled)
              if (enableShimmer) _buildShimmerOverlay(),
              
              // Pulse Animation (for alerts)
              if (showPulseAnimation && hasRiskAlert)
                _buildPulseRing(finalScale),
              
              // Main Content
              Padding(
                padding: EdgeInsets.all(paddingSize),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Section: Icon & Badge
                    _buildTopSection(
                      finalScale, 
                      iconSize, 
                      iconPadding, 
                      badgeSize,
                      hasRiskAlert: false,
                    ),
                    
                    // Middle Section: Value & Title
                    _buildMiddleSection(
                      value, 
                      valueSize, 
                      title, 
                      titleSize, 
                      spacing
                    ),
                    
                    // Bottom Section: Subtitle
                    _buildBottomSection(subtitle, subtitleSize, spacing),
                  ],
                ),
              ),
              
              // Risk Level Indicator (if applicable)
              if (isHSSECard && riskLevel != null)
                _buildRiskLevelIndicator(finalScale, _getRiskColor()),
            ],
          ),
        ),
      ),
    );
  }

  /// HSSE Risk Card with Special Design
  Widget _buildHSSERiskCard(
    BuildContext context,
    double finalScale,
    Color riskColor,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(
        milliseconds: animationDuration.inMilliseconds + (index * 150),
      ),
      curve: Curves.easeOutBack,
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: child,
        );
      },
      child: _HoverableCard(
        enableHover: enableHoverEffect,
        onTap: onTap,
        tooltipMessage: tooltipMessage ?? 'Lihat detail pengajuan berisiko',
        child: Container(
          constraints: BoxConstraints(
            minHeight: customHeight ?? 160.0 * finalScale,
            maxHeight: customHeight ?? 200.0 * finalScale,
            minWidth: customWidth ?? 160.0 * finalScale,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                riskColor.withValues(alpha: 0.9),
                riskColor.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 2,
            ),
            boxShadow: [
              // Glow effect untuk high risk
              if (riskLevel == 'high' || riskLevel == 'tinggi')
                BoxShadow(
                  color: riskColor.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              BoxShadow(
                color: riskColor.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Warning Pattern Background
              if (riskLevel == 'high' || riskLevel == 'tinggi')
                _buildWarningPattern(riskColor),
              
              // Decorative Elements
              _buildDecorativeCircles(),
              
              // Pulse Ring Animation for High Risk
              if (showPulseAnimation && 
                  (riskLevel == 'high' || riskLevel == 'tinggi'))
                _buildPulseRing(finalScale),
              
              // Main Content
              Padding(
                padding: EdgeInsets.all(16.0 * finalScale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Section with Risk Badge
                    Row(
                      children: [
                        // Risk Icon
                        Container(
                          padding: EdgeInsets.all(10.0 * finalScale),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _getRiskIcon(),
                            size: 24.0 * finalScale,
                            color: Colors.white,
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Risk Level Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.0 * finalScale,
                            vertical: 6.0 * finalScale,
                          ),
                          decoration: BoxDecoration(
                            color: riskLevel == 'high' || riskLevel == 'tinggi'
                                ? Colors.red.withValues(alpha: 0.3)
                                : riskLevel == 'medium' || riskLevel == 'sedang'
                                    ? Colors.orange.withValues(alpha: 0.3)
                                    : Colors.green.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                riskLevel == 'high' || riskLevel == 'tinggi'
                                    ? Icons.priority_high_rounded
                                    : riskLevel == 'medium' || riskLevel == 'sedang'
                                        ? Icons.warning_amber_rounded
                                        : Icons.info_outline_rounded,
                                color: Colors.white,
                                size: 14.0 * finalScale,
                              ),
                              SizedBox(width: 4 * finalScale),
                              Text(
                                riskLevel?.toUpperCase() ?? 'RISK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.0 * finalScale,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 8 * finalScale),
                    
                    // Value with Alert Indicator
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36.0 * finalScale,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        if (hasRiskAlert) ...[
                          SizedBox(width: 8 * finalScale),
                          Container(
                            padding: EdgeInsets.all(4 * finalScale),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                              size: 14.0 * finalScale,
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    SizedBox(height: 4 * finalScale),
                    
                    // Title
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.0 * finalScale,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    SizedBox(height: 6 * finalScale),
                    
                    // Risk Breakdown - FIXED with Wrap
                    if (highRiskCount != null || 
                        mediumRiskCount != null || 
                        lowRiskCount != null)
                      _buildRiskBreakdown(finalScale),
                    
                    if (highRiskCount == null && 
                        mediumRiskCount == null && 
                        lowRiskCount == null)
                      // Subtitle
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 12.0 * finalScale,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          SizedBox(width: 4 * finalScale),
                          Flexible(
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11.0 * finalScale,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
              // Custom Indicator (if provided)
              if (customIndicator != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: customIndicator!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact Card for Grid Layouts
  Widget _buildCompactCard(
    BuildContext context,
    double finalScale,
    Color riskColor,
    bool hasRiskData,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(
        milliseconds: animationDuration.inMilliseconds + (index * 80),
      ),
      curve: Curves.easeOutCubic,
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: child,
        );
      },
      child: _HoverableCard(
        enableHover: enableHoverEffect,
        onTap: onTap,
        tooltipMessage: tooltipMessage,
        child: Container(
          constraints: BoxConstraints(
            minHeight: customHeight ?? 100.0,
            maxHeight: customHeight ?? 120.0,
            minWidth: customWidth ?? 100.0,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: hasRiskData 
                  ? [riskColor.withValues(alpha: 0.9), riskColor.withValues(alpha: 0.7)]
                  : gradientColors,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (hasRiskData ? riskColor : gradientColors.first)
                    .withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(12.0 * finalScale),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Row
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6 * finalScale),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 18.0 * finalScale,
                        color: Colors.white,
                      ),
                    ),
                    if (badge != null) ...[
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6 * finalScale,
                          vertical: 2 * finalScale,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.0 * finalScale,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                SizedBox(height: 8 * finalScale),
                
                // Value
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.0 * finalScale,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                
                SizedBox(height: 2 * finalScale),
                
                // Title
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 10.0 * finalScale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildTopSection(
    double finalScale,
    double iconSize,
    double iconPadding,
    double badgeSize, {
    bool hasRiskAlert = false,
  }) {
    return Row(
      children: [
        // Icon Container
        Container(
          padding: EdgeInsets.all(iconPadding),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: hasRiskAlert
                ? [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            hasRiskAlert ? Icons.warning_amber_rounded : icon,
            size: iconSize,
            color: Colors.white,
          ),
        ),

        const Spacer(),

        // Badge
        if (badge != null)
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8 * finalScale,
                vertical: 4 * finalScale,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                badge!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: badgeSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMiddleSection(
    String value,
    double valueSize,
    String title,
    double titleSize,
    double spacing,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: spacing * 3),
        // Value
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: valueSize,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: spacing * 2),
        // Title
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection(
    String subtitle,
    double subtitleSize,
    double spacing,
  ) {
    return Row(
      children: [
        Icon(
          Icons.arrow_forward_ios_rounded,
          size: subtitleSize * 0.9,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        SizedBox(width: spacing * 2),
        Flexible(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: subtitleSize,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }

  // ✅ FIXED: Menggunakan Wrap agar tidak overflow dan teks tidak terpotong
  Widget _buildRiskBreakdown(double finalScale) {
    final List<Widget> riskBars = [];
    
    if (highRiskCount != null && highRiskCount! > 0) {
      riskBars.add(
        Flexible(
          flex: 1,
          child: _buildRiskBar(
            label: 'HIGH',
            count: highRiskCount!,
            color: Colors.red,
            finalScale: finalScale,
          ),
        ),
      );
    }
    
    if (mediumRiskCount != null && mediumRiskCount! > 0) {
      if (riskBars.isNotEmpty) {
        riskBars.add(SizedBox(width: 4 * finalScale));
      }
      riskBars.add(
        Flexible(
          flex: 1,
          child: _buildRiskBar(
            label: 'MED',
            count: mediumRiskCount!,
            color: Colors.orange,
            finalScale: finalScale,
          ),
        ),
      );
    }
    
    if (lowRiskCount != null && lowRiskCount! > 0) {
      if (riskBars.isNotEmpty) {
        riskBars.add(SizedBox(width: 4 * finalScale));
      }
      riskBars.add(
        Flexible(
          flex: 1,
          child: _buildRiskBar(
            label: 'LOW',
            count: lowRiskCount!,
            color: Colors.green,
            finalScale: finalScale,
          ),
        ),
      );
    }

    // Jika hanya ada 1 atau 2 risk bars, gunakan Wrap
    if (riskBars.length <= 3) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: riskBars,
      );
    }

    // Jika lebih dari 3, gunakan Wrap agar turun ke baris berikutnya
    return Wrap(
      spacing: 4 * finalScale,
      runSpacing: 4 * finalScale,
      alignment: WrapAlignment.start,
      children: riskBars,
    );
  }

  Widget _buildRiskBar({
    required String label,
    required int count,
    required Color color,
    required double finalScale,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8 * finalScale,
        vertical: 4 * finalScale,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6 * finalScale,
            height: 6 * finalScale,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4 * finalScale),
          Text(
            '$count',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10 * finalScale,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 2 * finalScale),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 7 * finalScale,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskLevelIndicator(double finalScale, Color riskColor) {
    return Positioned(
      top: 12 * finalScale,
      right: 12 * finalScale,
      child: Container(
        padding: EdgeInsets.all(4 * finalScale),
        decoration: BoxDecoration(
          color: riskColor.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: riskColor.withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          _getRiskIcon(),
          color: Colors.white,
          size: 16 * finalScale,
        ),
      ),
    );
  }

  Widget _buildDecorativeCircles() {
    return Stack(
      children: [
        // Top Right Circle
        Positioned(
          top: -25,
          right: -25,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
        // Bottom Left Circle
        Positioned(
          bottom: -35,
          left: -25,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningPattern(Color riskColor) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(
          painter: _WarningPatternPainter(riskColor),
        ),
      ),
    );
  }

  Widget _buildPulseRing(double finalScale) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.2),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3 * (1.2 - value)),
                  width: 2,
                ),
              ),
            ),
          );
        },
        onEnd: () {
          // Animation repeats automatically
        },
      ),
    );
  }

  Widget _buildShimmerOverlay() {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Shimmer.fromColors(
          baseColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.3),
          child: Container(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
    );
  }

  // ==================== UTILITY METHODS ====================

  double _getScaleFactor(double screenWidth) {
    if (screenWidth < 360) return 0.75;
    if (screenWidth < 380) return 0.80;
    if (screenWidth < 400) return 0.85;
    if (screenWidth < 450) return 0.90;
    return 1.0;
  }

  double _getIconSize(double scale) => 22.0 * scale;
  double _getValueSize(double scale) => 26.0 * scale;
  double _getTitleSize(double scale) => 13.0 * scale;
  double _getSubtitleSize(double scale) => 10.0 * scale;
  double _getBadgeSize(double scale) => 9.0 * scale;
  double _getPaddingSize(double scale) => 14.0 * scale.clamp(0.7, 1.0);
  double _getIconPadding(double scale) => 8.0 * scale.clamp(0.7, 1.0);
  double _getSpacing(double scale) => 2.0 * scale.clamp(0.5, 1.0);

  Color _getRiskColor() {
    if (riskLevel == 'high' || riskLevel == 'tinggi') {
      return const Color(0xFFFF3B3B);
    } else if (riskLevel == 'medium' || riskLevel == 'sedang') {
      return const Color(0xFFFF9500);
    } else if (riskLevel == 'low' || riskLevel == 'rendah') {
      return const Color(0xFF34C759);
    }
    return const Color(0xFFFF3B3B); // Default high risk
  }

  IconData _getRiskIcon() {
    if (riskLevel == 'high' || riskLevel == 'tinggi') {
      return Icons.dangerous_rounded;
    } else if (riskLevel == 'medium' || riskLevel == 'sedang') {
      return Icons.warning_amber_rounded;
    } else if (riskLevel == 'low' || riskLevel == 'rendah') {
      return Icons.check_circle_outline_rounded;
    }
    return Icons.warning_amber_rounded; // Default
  }
}

// ==================== CUSTOM PAINTER ====================

class _WarningPatternPainter extends CustomPainter {
  final Color color;

  _WarningPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final spacing = 30.0;
    
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(
          Offset(x, y),
          2,
          Paint()..color = color.withValues(alpha: 0.1),
        );
      }
    }

    // Draw diagonal lines
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== HOVERABLE CARD WRAPPER ====================

class _HoverableCard extends StatefulWidget {
  final Widget child;
  final bool enableHover;
  final VoidCallback? onTap;
  final String? tooltipMessage;

  const _HoverableCard({
    required this.child,
    required this.enableHover,
    this.onTap,
    this.tooltipMessage,
  });

  @override
  State<_HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<_HoverableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget card = GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.enableHover ? (_) => setState(() => _isHovered = true) : null,
      onTapUp: widget.enableHover ? (_) => setState(() => _isHovered = false) : null,
      onTapCancel: widget.enableHover ? () => setState(() => _isHovered = false) : null,
      child: AnimatedScale(
        scale: _isHovered && widget.enableHover ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );

    if (widget.tooltipMessage != null) {
      card = Tooltip(
        message: widget.tooltipMessage!,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
        child: card,
      );
    }

    return card;
  }
}

// ==================== SHIMMER (Built-in) ====================

class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({
    super.key,
    required this.child,
  });

  static ShimmerState? of(BuildContext context) {
    return context.findAncestorStateOfType<ShimmerState>();
  }

  static LinearGradient defaultGradient = const LinearGradient(
    colors: [
      Color(0xFFEBEBF4),
      Color(0xFFF4F4F4),
      Color(0xFFEBEBF4),
    ],
    stops: [
      0.1,
      0.3,
      0.4,
    ],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );

  static fromColors({
    required Color baseColor,
    required Color highlightColor,
    Widget? child,
  }) {
    return Shimmer(
      child: child ?? const SizedBox.expand(),
    );
  }

  @override
  ShimmerState createState() => ShimmerState();
}

class ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  LinearGradient get gradient => Shimmer.defaultGradient;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return gradient.createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}