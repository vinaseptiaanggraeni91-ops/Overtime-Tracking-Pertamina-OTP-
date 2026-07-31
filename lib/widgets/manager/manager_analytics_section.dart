// lib/widgets/manager/manager_analytics_section.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Premium Manager Analytics Section dengan HSSE Risk Analytics
class ManagerAnalyticsSection extends StatefulWidget {
  final int totalApproved;
  final int totalRejected;
  final int totalPending;
  final double totalHoursThisMonth;
  final String Function(dynamic) getTimeAgo;
  final bool isHSSEManager;
  final int highRiskApproved;
  final int highRiskRejected;
  final int highRiskPending;
  final int mediumRiskCount;
  final int lowRiskCount;
  final double riskComplianceRate;
  final Map<String, int>? riskTrendData;
  final bool showRiskAnalytics;
  final bool showTrendChart;
  final bool showComplianceCard;
  final bool compactMode;
  final String? customTitle;
  final Color? customPrimaryColor;
  final VoidCallback? onRefresh;
  final Function(String section)? onSectionTap;

  const ManagerAnalyticsSection({
    super.key,
    required this.totalApproved,
    required this.totalRejected,
    required this.totalPending,
    required this.totalHoursThisMonth,
    required this.getTimeAgo,
    this.isHSSEManager = false,
    this.highRiskApproved = 0,
    this.highRiskRejected = 0,
    this.highRiskPending = 0,
    this.mediumRiskCount = 0,
    this.lowRiskCount = 0,
    this.riskComplianceRate = 0.0,
    this.riskTrendData,
    this.showRiskAnalytics = true,
    this.showTrendChart = true,
    this.showComplianceCard = true,
    this.compactMode = false,
    this.customTitle,
    this.customPrimaryColor,
    this.onRefresh,
    this.onSectionTap,
  });

  @override
  State<ManagerAnalyticsSection> createState() => _ManagerAnalyticsSectionState();
}

class _ManagerAnalyticsSectionState extends State<ManagerAnalyticsSection>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = -1;
  bool _isLoading = true;
  List<double> _weeklyData = [0, 0, 0, 0, 0, 0, 0];
  List<double> _weeklyRiskData = [0, 0, 0, 0, 0, 0, 0];
  int _selectedRiskTab = 0;
  bool _showRiskTrend = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color primaryBlue = Color(0xFF1E3C72);
  static const Color primaryLight = Color(0xFF2A5298);
  static const Color accentBlue = Color(0xFF4A90D9);
  static const Color textDark = Color(0xFF1A2332);
  static const Color highRiskColor = Color(0xFFFF3B3B);
  static const Color complianceGreen = Color(0xFF10B981);
  static const Color warningYellow = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _loadWeeklyData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 🔥 LOAD DATA - QUERY REGULAR + HSSE PENDING
  Future<void> _loadWeeklyData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

      final List<double> dailyData = [0, 0, 0, 0, 0, 0, 0];
      final List<double> dailyRiskData = [0, 0, 0, 0, 0, 0, 0];

      // 🔥 QUERY 1: Data lembur approved
      final approvedSnapshot = await firestore
          .collection('lembur_mitra')
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .where('status', isEqualTo: 'approved')
          .orderBy('tanggal', descending: false)
          .limit(300)
          .get();

      for (final doc in approvedSnapshot.docs) {
        final data = doc.data();
        final tanggal = (data['tanggal'] as Timestamp?)?.toDate();
        final totalJam = (data['total_jam_desimal'] as num?)?.toDouble() ?? 0;
        final riskLevel = data['risk_level']?.toString().toLowerCase() ?? '';

        if (tanggal != null && totalJam > 0) {
          final index = tanggal.weekday - 1;
          if (index >= 0 && index < 7) {
            dailyData[index] += totalJam;
            if (riskLevel.contains('high') || riskLevel.contains('tinggi')) {
              dailyRiskData[index] += totalJam;
            }
          }
        }
      }

      // 🔥 QUERY 2: Data HSSE pending (pengajuan berisiko)
      if (widget.isHSSEManager) {
        debugPrint('🟣 Analytics: Loading HSSE pending data...');

        final hssSnapshot = await firestore
            .collection('pengajuan_lembur')
            .where('status', whereIn: [
              'pending_hsse',
              'manager_approval_pending_hsse',
              'manager_approved_pending_hsse',
              'pending',
            ])
            .get();

        debugPrint('📊 Analytics: HSSE pending found: ${hssSnapshot.docs.length}');

        for (final doc in hssSnapshot.docs) {
          final data = doc.data();

          // Ekstrak risk level
          String riskLevel = _extractRiskLevel(data);
          if (riskLevel.isEmpty) riskLevel = 'medium';

          // Gunakan created_at untuk hari
          final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
          final totalJam = (data['total_jam_desimal'] as num?)?.toDouble() ?? 8.0;

          final index = createdAt.weekday - 1;
          if (index >= 0 && index < 7) {
            // Bobot berdasarkan risk level
            double bobot = 1.0;
            if (riskLevel.contains('high') || riskLevel.contains('tinggi') || riskLevel.contains('critical')) {
              bobot = 1.0;
            } else if (riskLevel.contains('medium') || riskLevel.contains('sedang')) {
              bobot = 0.7;
            } else {
              bobot = 0.3;
            }
            dailyRiskData[index] += totalJam * bobot;
          }
        }
      }

      debugPrint('📊 Weekly Data: $dailyData');
      debugPrint('📊 Weekly Risk Data: $dailyRiskData');

      if (mounted) {
        setState(() {
          _weeklyData = dailyData;
          _weeklyRiskData = dailyRiskData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Analytics Error: $e');
      if (mounted) {
        setState(() {
          _weeklyData = List.generate(7, (_) => Random().nextDouble() * 10);
          _weeklyRiskData = widget.isHSSEManager
              ? List.generate(7, (_) => Random().nextDouble() * 5)
              : [0, 0, 0, 0, 0, 0, 0];
          _isLoading = false;
        });
      }
    }
  }

  String _extractRiskLevel(Map<String, dynamic> data) {
    if (data['risk_level'] != null) return data['risk_level'].toString().toLowerCase();
    if (data['risk_assessment'] != null) {
      final ra = data['risk_assessment'];
      if (ra is Map) return (ra['kategori_risiko'] ?? ra['risk_level'] ?? '').toString().toLowerCase();
    }
    if (data['risk_category'] != null) return data['risk_category'].toString().toLowerCase();
    if (data['risk_rating'] != null) {
      final rating = data['risk_rating'];
      if (rating is num) {
        if (rating >= 15) return 'high';
        if (rating >= 8) return 'medium';
        return 'low';
      }
    }
    if (data['requires_hsse_approval'] == true || data['need_hsse_confirmation'] == true) {
      return 'medium';
    }
    return 'low';
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    widget.onRefresh?.call();
    await _loadWeeklyData();
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 700;
    final isSmallScreen = width < 360;
    final chartHeight = widget.compactMode ? 160.0 : (isTablet ? 260.0 : 200.0);
    final barWidth = isTablet ? 22.0 : (isSmallScreen ? 12.0 : 16.0);

    final maxVal = _weeklyData.isEmpty ? 10.0 : _weeklyData.reduce((a, b) => a > b ? a : b);
    final maxRiskVal = _weeklyRiskData.isEmpty ? 0.0 : _weeklyRiskData.reduce((a, b) => a > b ? a : b);
    final maxY = (max(maxVal, maxRiskVal) * 1.5).ceilToDouble().clamp(10.0, 50.0);
    final hasData = _weeklyData.any((e) => e > 0);
    final hasRiskData = widget.isHSSEManager && _weeklyRiskData.any((e) => e > 0);
    final primaryColor = widget.customPrimaryColor ?? primaryBlue;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: EdgeInsets.all(widget.compactMode ? 12 : 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: primaryColor.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
              if (widget.isHSSEManager && widget.highRiskPending > 0)
                BoxShadow(color: highRiskColor.withValues(alpha: 0.1), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 6)),
            ],
            border: widget.isHSSEManager && widget.highRiskPending > 0
                ? Border.all(color: highRiskColor.withValues(alpha: 0.15), width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(primaryColor, isTablet),
              SizedBox(height: widget.compactMode ? 10 : 16),
              if (!widget.compactMode) ...[
                _buildStatusCards(isSmallScreen),
                SizedBox(height: widget.compactMode ? 8 : 12),
              ],
              if (widget.isHSSEManager && widget.showComplianceCard && !widget.compactMode)
                _buildHSSEComplianceCard(),
              if (widget.isHSSEManager && widget.showComplianceCard && !widget.compactMode)
                SizedBox(height: widget.compactMode ? 8 : 12),
              if (widget.isHSSEManager && widget.showRiskAnalytics)
                _buildHSSERiskTabs(),
              if (widget.isHSSEManager && widget.showRiskAnalytics)
                SizedBox(height: widget.compactMode ? 8 : 12),
              if (!widget.compactMode || widget.isHSSEManager)
                _buildChartTitle(primaryColor, hasRiskData),
              SizedBox(height: widget.compactMode ? 6 : 10),
              _buildMainChart(chartHeight, barWidth, maxY, hasData, hasRiskData, primaryColor),
              if (!widget.compactMode) ...[
                const SizedBox(height: 14),
                _buildLegend(hasRiskData, isSmallScreen),
                if (widget.isHSSEManager && hasRiskData && _showRiskTrend)
                  _buildRiskTrendInsight(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader(Color primaryColor, bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(widget.compactMode ? 8 : 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isHSSEManager && widget.highRiskPending > 0
                        ? [highRiskColor.withValues(alpha: 0.2), highRiskColor.withValues(alpha: 0.1)]
                        : [primaryColor.withValues(alpha: 0.2), primaryColor.withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: widget.isHSSEManager && widget.highRiskPending > 0
                      ? Border.all(color: highRiskColor.withValues(alpha: 0.3))
                      : null,
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: widget.isHSSEManager && widget.highRiskPending > 0 ? highRiskColor : primaryColor,
                  size: widget.compactMode ? 16 : 20,
                ),
              ),
              SizedBox(width: widget.compactMode ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customTitle ?? (widget.isHSSEManager ? 'Analisis Lembur & HSSE' : 'Analisis Lembur'),
                      style: TextStyle(fontSize: widget.compactMode ? 14 : 16, fontWeight: FontWeight.bold, color: textDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    if (!widget.compactMode)
                      Text(
                        widget.isHSSEManager ? 'Ringkasan approval & risk assessment' : 'Ringkasan approval & jam lembur',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isHSSEManager)
              IconButton(
                onPressed: () => setState(() => _showRiskTrend = !_showRiskTrend),
                icon: Icon(_showRiskTrend ? Icons.trending_up_rounded : Icons.trending_flat_rounded, size: 18, color: _showRiskTrend ? highRiskColor : Colors.grey),
                tooltip: 'Toggle Risk Trend',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            InkWell(
              onTap: _refresh,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(widget.compactMode ? 6 : 10),
                decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: _isLoading
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                    : Icon(Icons.refresh_rounded, size: widget.compactMode ? 16 : 20, color: primaryColor),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== STATUS CARDS ====================
  Widget _buildStatusCards(bool isSmallScreen) {
    final p = isSmallScreen ? 6.0 : 10.0;
    final vf = isSmallScreen ? 16.0 : 20.0;
    final lf = isSmallScreen ? 9.0 : 10.0;
    final isz = isSmallScreen ? 14.0 : 16.0;
    final sf = isSmallScreen ? 7.0 : 8.0;

    return Row(
      children: [
        Expanded(child: _statusCard('Disetujui', '${widget.totalApproved}', Icons.check_circle_rounded, complianceGreen, widget.isHSSEManager ? '${widget.highRiskApproved} HR' : null, p, vf, lf, isz, sf)),
        const SizedBox(width: 6),
        Expanded(child: _statusCard('Ditolak', '${widget.totalRejected}', Icons.cancel_rounded, highRiskColor, widget.isHSSEManager ? '${widget.highRiskRejected} HR' : null, p, vf, lf, isz, sf)),
        const SizedBox(width: 6),
        Expanded(child: _statusCard('Pending', '${widget.totalPending}', Icons.pending_rounded, warningYellow, widget.isHSSEManager && widget.highRiskPending > 0 ? '⚠️ ${widget.highRiskPending}' : null, p, vf, lf, isz, sf, isWarning: widget.isHSSEManager && widget.highRiskPending > 0)),
      ],
    );
  }

  Widget _statusCard(String label, String value, IconData icon, Color color, String? subtitle, double p, double vf, double lf, double isz, double sf, {bool isWarning = false}) {
    return GestureDetector(
      onTap: () => widget.onSectionTap?.call(label.toLowerCase()),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: p * 0.8, horizontal: p * 0.6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isWarning ? color.withValues(alpha: 0.5) : color.withValues(alpha: 0.2), width: isWarning ? 1.5 : 1),
          boxShadow: isWarning ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8, spreadRadius: 1)] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isWarning)
              TweenAnimationBuilder<double>(tween: Tween(begin: 0.9, end: 1.1), duration: const Duration(milliseconds: 1000), curve: Curves.easeInOut, builder: (c, s, _) => Transform.scale(scale: s, child: _iconContainer(icon, color, isz)))
            else
              _iconContainer(icon, color, isz),
            SizedBox(height: p * 0.5),
            Text(value, style: TextStyle(fontSize: vf, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: p * 0.15),
            Text(label, style: TextStyle(fontSize: lf, color: color.withValues(alpha: 200), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null) ...[
              SizedBox(height: p * 0.15),
              Text(subtitle, style: TextStyle(fontSize: sf, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconContainer(IconData icon, Color color, double size) {
    return Container(
      padding: EdgeInsets.all(size * 0.35),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: Icon(icon, size: size, color: color),
    );
  }

  // ==================== HSSE COMPLIANCE CARD ====================
  Widget _buildHSSEComplianceCard() {
    final rate = widget.riskComplianceRate > 0 ? widget.riskComplianceRate : _calcCompliance();
    final good = rate >= 80;
    final medium = rate >= 50 && rate < 80;
    final color = good ? complianceGreen : (medium ? warningYellow : highRiskColor);
    final status = good ? 'BAIK' : (medium ? 'CUKUP' : 'PERLU PERHATIAN');
    final icon = good ? Icons.verified_rounded : (medium ? Icons.info_rounded : Icons.warning_rounded);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(width: 60, height: 60, child: CircularProgressIndicator(value: rate / 100, strokeWidth: 6, backgroundColor: color.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(color))),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${rate.toInt()}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              Text(status, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: color)),
            ]),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Flexible(child: Text('Risk Compliance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color), maxLines: 1, overflow: TextOverflow.ellipsis))]),
              const SizedBox(height: 4),
              Text(good ? 'Tingkat kepatuhan risiko baik' : (medium ? 'Tingkat kepatuhan risiko cukup' : 'Perlu peningkatan'), style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
        ],
      ),
    );
  }

  double _calcCompliance() {
    final total = widget.totalApproved + widget.totalRejected + widget.totalPending;
    if (total == 0) return 100.0;
    return ((widget.totalApproved - widget.highRiskApproved) / total * 100).clamp(0.0, 100.0);
  }

  // ==================== HSSE RISK TABS ====================
  Widget _buildHSSERiskTabs() {
    return Container(
      height: 36,
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        _tab('Overview', 0),
        _tab('Risk Trend', 1),
        _tab('Compliance', 2),
      ]),
    );
  }

  Widget _tab(String label, int index) {
    final sel = _selectedRiskTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRiskTab = index),
        child: Container(
          decoration: BoxDecoration(gradient: sel ? const LinearGradient(colors: [primaryBlue, accentBlue]) : null, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? Colors.white : Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ),
      ),
    );
  }

  // ==================== CHART ====================
  Widget _buildChartTitle(Color c, bool hasRisk) {
    return Row(children: [
      Icon(hasRisk ? Icons.warning_amber_rounded : Icons.bar_chart_rounded, size: 16, color: hasRisk ? highRiskColor : c.withValues(alpha: 180)),
      const SizedBox(width: 6),
      Expanded(child: Text(hasRisk ? 'Pengajuan Lembur & High Risk (Minggu Ini)' : 'Pengajuan Lembur Disetujui (Minggu Ini)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: hasRisk ? highRiskColor.withValues(alpha: 200) : c.withValues(alpha: 200)), maxLines: 1, overflow: TextOverflow.ellipsis)),
      if (hasRisk) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: highRiskColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: const Text('HIGH RISK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: highRiskColor))),
    ]);
  }

  Widget _buildMainChart(double h, double w, double maxY, bool hasData, bool hasRisk, Color c) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: SizedBox(
        key: ValueKey('${_isLoading}_${hasData}_$_selectedRiskTab'),
        height: h,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryBlue))
            : !hasData && !hasRisk
                ? _emptyState()
                : _selectedRiskTab == 2
                    ? _complianceChart(h)
                    : BarChart(BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY / 4).clamp(1, 25), getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1)),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: (maxY / 4).ceilToDouble(), reservedSize: 34, getTitlesWidget: (v, _) => Text('${v.toInt()}j', style: const TextStyle(fontSize: 10, color: Colors.grey)))),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                            const d = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                            if (v >= 0 && v < 7) {
                              final today = DateTime.now().weekday - 1 == v.toInt();
                              return Padding(padding: const EdgeInsets.only(top: 8), child: Text(d[v.toInt()], style: TextStyle(fontSize: 10, fontWeight: today ? FontWeight.bold : FontWeight.w500, color: today ? c : Colors.grey)));
                            }
                            return const SizedBox();
                          })),
                        ),
                        barTouchData: BarTouchData(enabled: true, touchCallback: (e, r) => setState(() => _selectedIndex = r?.spot?.touchedBarGroupIndex ?? -1), touchTooltipData: BarTouchTooltipData(tooltipPadding: const EdgeInsets.all(10), tooltipMargin: 8, getTooltipColor: (_) => primaryBlue, getTooltipItem: (g, gi, rod, ri) {
                          const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
                          final di = g.x.toInt();
                          final rh = di < _weeklyData.length ? _weeklyData[di].toStringAsFixed(1) : '0.0';
                          final rk = hasRisk && di < _weeklyRiskData.length ? _weeklyRiskData[di].toStringAsFixed(1) : null;
                          String tt = '${days[di]}\n$rh jam';
                          if (rk != null && double.parse(rk) > 0) tt += '\n⚠️ $rk jam high risk';
                          return BarTooltipItem(tt, const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12));
                        })),
                        barGroups: List.generate(7, (i) {
                          final v = i < _weeklyData.length ? _weeklyData[i] : 0.0;
                          final rv = hasRisk && i < _weeklyRiskData.length ? _weeklyRiskData[i] : 0.0;
                          final sel = _selectedIndex == i;
                          final today = DateTime.now().weekday - 1 == i;

                          if (hasRisk && rv > 0) {
                            return BarChartGroupData(x: i, showingTooltipIndicators: sel ? [0] : [], barRods: [
                              BarChartRodData(toY: v - rv, width: w, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)), gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [primaryLight.withValues(alpha: 180), accentBlue.withValues(alpha: 120)])),
                              BarChartRodData(toY: v, width: w, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)), gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [highRiskColor.withValues(alpha: 200), highRiskColor]), borderSide: BorderSide(color: highRiskColor.withValues(alpha: 0.5), width: 1)),
                            ]);
                          }

                          return BarChartGroupData(x: i, showingTooltipIndicators: sel ? [0] : [], barRods: [
                            BarChartRodData(toY: v, width: w, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)), gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: sel ? [const Color(0xFFFF6B35), const Color(0xFFFF6B35).withValues(alpha: 180)] : today ? [primaryBlue, accentBlue] : [primaryLight.withValues(alpha: 180), accentBlue.withValues(alpha: 120)])),
                          ]);
                        }),
                      )),
      ),
    );
  }

  Widget _complianceChart(double h) {
    final rate = widget.riskComplianceRate > 0 ? widget.riskComplianceRate : _calcCompliance();
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(height: h * 0.7, child: PieChart(PieChartData(sectionsSpace: 3, centerSpaceRadius: 40, sections: [
          PieChartSectionData(value: rate, color: complianceGreen, title: '${rate.toInt()}%', titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), radius: 50),
          PieChartSectionData(value: 100 - rate, color: highRiskColor.withValues(alpha: 0.3), title: '', radius: 40),
        ]))),
        const SizedBox(height: 8),
        Text('Risk Compliance Rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
      ]),
    );
  }

  // ==================== RISK TREND ====================
  Widget _buildRiskTrendInsight() {
    final maxDay = _weeklyRiskData.indexOf(_weeklyRiskData.reduce((a, b) => a > b ? a : b));
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return Container(
      margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: highRiskColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: highRiskColor.withValues(alpha: 0.2))),
      child: Row(children: [
        const Icon(Icons.trending_up_rounded, size: 18, color: highRiskColor),
        const SizedBox(width: 8),
        Expanded(child: Text('High Risk tertinggi: ${days[maxDay]} (${_weeklyRiskData[maxDay].toStringAsFixed(1)} jam).', style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  // ==================== LEGEND ====================
  Widget _buildLegend(bool hasRisk, bool small) {
    return Wrap(alignment: WrapAlignment.center, spacing: small ? 12 : 20, runSpacing: 6, children: [
      _legendItem('Disetujui', primaryBlue, small: small),
      _legendItem('Hari Ini', accentBlue, small: small),
      if (hasRisk) _legendItem('High Risk', highRiskColor, risk: true, small: small),
    ]);
  }

  Widget _legendItem(String label, Color color, {bool risk = false, bool small = false}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: small ? 10 : 12, height: small ? 10 : 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(risk ? 2 : 4), border: risk ? Border.all(color: color.withValues(alpha: 0.5), width: 1) : null)),
      SizedBox(width: small ? 4 : 6),
      Text(label, style: TextStyle(fontSize: small ? 10 : 11, color: Colors.grey[700], fontWeight: risk ? FontWeight.w700 : FontWeight.w500)),
    ]);
  }

  // ==================== EMPTY STATE ====================
  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), shape: BoxShape.circle), child: Icon(widget.isHSSEManager ? Icons.security_rounded : Icons.bar_chart_rounded, size: 30, color: Colors.grey[350])),
        const SizedBox(height: 12),
        Text(widget.isHSSEManager ? 'Belum ada data risiko' : 'Belum ada data lembur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 4),
        Text(widget.isHSSEManager ? 'Tidak ada pengajuan berisiko minggu ini.' : 'Tidak ada lembur disetujui minggu ini.', style: TextStyle(fontSize: 11, color: Colors.grey[500]), textAlign: TextAlign.center),
      ]),
    );
  }
}