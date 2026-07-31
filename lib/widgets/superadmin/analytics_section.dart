// lib/features/superadmin/widgets/analytics_section.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_colors.dart';
import '../../../core/services/superadmin_service.dart';

class AnalyticsSection extends StatefulWidget {
  final DashboardData data;

  const AnalyticsSection({
    super.key,
    required this.data,
  });

  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection> {
  int _selectedIndex = -1;
  bool _isLoading = true;
  List<double> _weeklyData = [0, 0, 0, 0, 0, 0, 0];

  // Data untuk pie chart status distribusi
  Map<String, int> _statusDistribution = {};
  bool _isStatusLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
    _loadStatusDistribution();
  }

  Future<void> _loadWeeklyData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

      final snapshot = await firestore
          .collection('lembur_mitra')
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .orderBy('tanggal', descending: false)
          .limit(300)
          .get();

      final List<double> dailyData = [0, 0, 0, 0, 0, 0, 0];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final tanggal = (data['tanggal'] as Timestamp?)?.toDate();
        final totalJam = (data['total_jam_desimal'] as num?)?.toDouble() ?? 0;

        if (tanggal != null && totalJam > 0) {
          final index = tanggal.weekday - 1;
          if (index >= 0 && index < 7) {
            dailyData[index] += totalJam;
          }
        }
      }

      if (mounted) {
        setState(() {
          _weeklyData = dailyData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AnalyticsSection Error: $e');

      final avg = (widget.data.totalOvertimeBulanIni / 7).clamp(0.0, 25.0);
      if (mounted) {
        setState(() {
          _weeklyData = List.generate(
            7,
            (i) => (avg * (0.45 + (i % 5) * 0.22)).clamp(0.0, 25.0),
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStatusDistribution() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final firestore = FirebaseFirestore.instance;

      final results = await Future.wait([
        firestore
            .collection('pengajuan_lembur')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        firestore
            .collection('pengajuan_lembur')
            .where('status', isEqualTo: 'pending_hsse')
            .count()
            .get(),
        firestore
            .collection('lembur_mitra')
            .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
            .limit(500)
            .get(),
      ]);

      final pendingFungsi = (results[0] as AggregateQuerySnapshot).count ?? 0;
      final pendingHSSE = (results[1] as AggregateQuerySnapshot).count ?? 0;
      final lemburSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;

      int approved = 0;
      int rejected = 0;
      int selesai = 0;
      int checkIn = 0;

      for (var doc in lemburSnapshot.docs) {
        final status = (doc.data()['status'] ?? '').toString().toLowerCase();
        switch (status) {
          case 'disetujui':
          case 'approved':
            approved++;
            break;
          case 'ditolak':
          case 'rejected':
            rejected++;
            break;
          case 'selesai':
            selesai++;
            break;
          case 'check_in':
            checkIn++;
            break;
        }
      }

      if (mounted) {
        setState(() {
          _statusDistribution = {
            'Disetujui': approved,
            'Ditolak': rejected,
            'Pending Fungsi': pendingFungsi,
            'Pending HSSE': pendingHSSE,
            'Selesai': selesai,
            'Check In': checkIn,
          };
          _statusDistribution.removeWhere((key, value) => value == 0);
          _isStatusLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Status Distribution Error: $e');
      if (mounted) {
        setState(() {
          _statusDistribution = {
            'Disetujui': widget.data.approvedOvertimeBulanIni,
            'Ditolak': widget.data.rejectedOvertimeBulanIni,
            'Pending Fungsi': widget.data.pendingApprovals,
            'Pending HSSE': widget.data.pendingHSSEApprovals,
          };
          _statusDistribution.removeWhere((key, value) => value == 0);
          _isStatusLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _isStatusLoading = true;
    });
    await Future.wait([
      _loadWeeklyData(),
      _loadStatusDistribution(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 430;
    final isTablet = width >= 700;

    // 🔥 Sesuaikan ukuran berdasarkan device
    final containerPadding = isMobile ? 12.0 : 18.0;
    final chartHeight = isMobile ? 180.0 : (isTablet ? 270.0 : 220.0);
    final barWidth = isMobile ? 14.0 : (isTablet ? 24.0 : 18.0);
    final headerIconSize = isMobile ? 16.0 : 20.0;
    final headerTitleSize = isMobile ? 13.0 : 16.0;
    final headerSubtitleSize = isMobile ? 9.0 : 11.0;
    final chipFontSize = isMobile ? 8.5 : 10.0;
    final chipIconSize = isMobile ? 11.0 : 13.0;
    final chipPaddingH = isMobile ? 6.0 : 10.0;
    final chipPaddingV = isMobile ? 4.0 : 6.0;
    final sectionTitleSize = isMobile ? 9.5 : 11.0;

    final maxVal = _weeklyData.reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal * 1.4).ceilToDouble().clamp(10.0, 50.0);
    final hasData = _weeklyData.any((e) => e > 0);

    return Container(
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // =========================
          // HEADER
          // =========================
          _buildHeader(
            isMobile: isMobile,
            headerIconSize: headerIconSize,
            headerTitleSize: headerTitleSize,
            headerSubtitleSize: headerSubtitleSize,
          ),
          SizedBox(height: isMobile ? 12 : 18),

          // =========================
          // STATS CARDS - BULAN INI
          // =========================
          _buildStatsChips(
            isMobile: isMobile,
            chipFontSize: chipFontSize,
            chipIconSize: chipIconSize,
            chipPaddingH: chipPaddingH,
            chipPaddingV: chipPaddingV,
          ),
          SizedBox(height: isMobile ? 14 : 20),

          // =========================
          // PIE CHART - DISTRIBUSI STATUS
          // =========================
          if (_statusDistribution.isNotEmpty) ...[
            _buildPieChartSection(
              isMobile: isMobile,
              isTablet: isTablet,
              sectionTitleSize: sectionTitleSize,
            ),
            SizedBox(height: isMobile ? 14 : 20),
          ],

          // =========================
          // BAR CHART - WEEKLY
          // =========================
          _buildSectionTitle(
            title: 'Jam Lembur Mingguan',
            color: AppColors.primaryBlue,
            fontSize: sectionTitleSize,
          ),
          SizedBox(height: isMobile ? 8 : 12),
          _buildBarChart(
            chartHeight: chartHeight,
            barWidth: barWidth,
            maxY: maxY,
            hasData: hasData,
            isMobile: isMobile,
          ),
          const SizedBox(height: 14),

          // =========================
          // LEGEND
          // =========================
          Center(
            child: _buildLegend(
              'Jam Lembur',
              AppColors.primaryBlue,
              fontSize: isMobile ? 9.0 : 11.0,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // 🔥 HEADER (Responsive)
  // =========================
  Widget _buildHeader({
    required bool isMobile,
    required double headerIconSize,
    required double headerTitleSize,
    required double headerSubtitleSize,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 7 : 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(20),
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: AppColors.primaryBlue,
                  size: headerIconSize,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Analisis Lembur',
                      style: GoogleFonts.poppins(
                        fontSize: headerTitleSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isMobile ? 1 : 2),
                    Text(
                      'Statistik lembur bulan ini',
                      style: GoogleFonts.poppins(
                        fontSize: headerSubtitleSize,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _refresh,
          icon: Icon(Icons.refresh_rounded, size: isMobile ? 16 : 20),
          tooltip: 'Refresh Data',
          constraints: BoxConstraints(
            minWidth: isMobile ? 32 : 40,
            minHeight: isMobile ? 32 : 40,
          ),
          padding: EdgeInsets.all(isMobile ? 6 : 8),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primaryBlue.withAlpha(15),
            foregroundColor: AppColors.primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // 🔥 STATS CHIPS (Responsive)
  // =========================
  Widget _buildStatsChips({
    required bool isMobile,
    required double chipFontSize,
    required double chipIconSize,
    required double chipPaddingH,
    required double chipPaddingV,
  }) {
    // 🔥 Gunakan Wrap untuk mobile agar chips bisa wrapping
    if (isMobile) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _buildChip(
            label: 'Total',
            value: '${widget.data.totalOvertimeBulanIni}',
            icon: Icons.work_history_rounded,
            color: AppColors.primaryBlue,
            fontSize: chipFontSize,
            iconSize: chipIconSize,
            paddingH: chipPaddingH,
            paddingV: chipPaddingV,
          ),
          _buildChip(
            label: 'Disetujui',
            value: '${widget.data.approvedOvertimeBulanIni}',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF16A34A),
            fontSize: chipFontSize,
            iconSize: chipIconSize,
            paddingH: chipPaddingH,
            paddingV: chipPaddingV,
          ),
          _buildChip(
            label: 'Ditolak',
            value: '${widget.data.rejectedOvertimeBulanIni}',
            icon: Icons.cancel_rounded,
            color: const Color(0xFFDC2626),
            fontSize: chipFontSize,
            iconSize: chipIconSize,
            paddingH: chipPaddingH,
            paddingV: chipPaddingV,
          ),
          _buildChip(
            label: 'Pending Fungsi',
            value: '${widget.data.pendingApprovals}',
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFFEA580C),
            fontSize: chipFontSize,
            iconSize: chipIconSize,
            paddingH: chipPaddingH,
            paddingV: chipPaddingV,
          ),
          _buildChip(
            label: 'Pending HSSE',
            value: '${widget.data.pendingHSSEApprovals}',
            icon: Icons.shield_rounded,
            color: const Color(0xFFB45309),
            fontSize: chipFontSize,
            iconSize: chipIconSize,
            paddingH: chipPaddingH,
            paddingV: chipPaddingV,
          ),
        ],
      );
    }

    // Tablet / Desktop: Gunakan Wrap juga agar rapi
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildChip(
          label: 'Total',
          value: '${widget.data.totalOvertimeBulanIni}',
          icon: Icons.work_history_rounded,
          color: AppColors.primaryBlue,
          fontSize: chipFontSize,
          iconSize: chipIconSize,
          paddingH: chipPaddingH,
          paddingV: chipPaddingV,
        ),
        _buildChip(
          label: 'Disetujui',
          value: '${widget.data.approvedOvertimeBulanIni}',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF16A34A),
          fontSize: chipFontSize,
          iconSize: chipIconSize,
          paddingH: chipPaddingH,
          paddingV: chipPaddingV,
        ),
        _buildChip(
          label: 'Ditolak',
          value: '${widget.data.rejectedOvertimeBulanIni}',
          icon: Icons.cancel_rounded,
          color: const Color(0xFFDC2626),
          fontSize: chipFontSize,
          iconSize: chipIconSize,
          paddingH: chipPaddingH,
          paddingV: chipPaddingV,
        ),
        _buildChip(
          label: 'Pending Fungsi',
          value: '${widget.data.pendingApprovals}',
          icon: Icons.pending_actions_rounded,
          color: const Color(0xFFEA580C),
          fontSize: chipFontSize,
          iconSize: chipIconSize,
          paddingH: chipPaddingH,
          paddingV: chipPaddingV,
        ),
        _buildChip(
          label: 'Pending HSSE',
          value: '${widget.data.pendingHSSEApprovals}',
          icon: Icons.shield_rounded,
          color: const Color(0xFFB45309),
          fontSize: chipFontSize,
          iconSize: chipIconSize,
          paddingH: chipPaddingH,
          paddingV: chipPaddingV,
        ),
      ],
    );
  }

  // =========================
  // 🔥 SECTION TITLE
  // =========================
  Widget _buildSectionTitle({
    required String title,
    required Color color,
    required double fontSize,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // =========================
  // 🔥 BAR CHART (Responsive)
  // =========================
  Widget _buildBarChart({
    required double chartHeight,
    required double barWidth,
    required double maxY,
    required bool hasData,
    required bool isMobile,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: SizedBox(
        key: ValueKey(_isLoading.toString() + hasData.toString()),
        height: chartHeight,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryBlue,
                  strokeWidth: isMobile ? 2 : 3,
                ),
              )
            : !hasData
                ? _buildEmptyState(isMobile: isMobile)
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          setState(() {
                            _selectedIndex = response?.spot?.touchedBarGroupIndex ?? -1;
                          });
                        },
                        touchTooltipData: BarTouchTooltipData(
                          tooltipPadding: EdgeInsets.all(isMobile ? 8 : 10),
                          tooltipMargin: 8,
                          getTooltipColor: (_) => const Color(0xFF2D3748),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
                            return BarTooltipItem(
                              '${days[group.x.toInt()]}\n${_weeklyData[group.x.toInt()].toStringAsFixed(1)} jam',
                              GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 10 : 12,
                              ),
                            );
                          },
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: (maxY / 4).clamp(1, 25),
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withAlpha(20),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (maxY / 4).ceilToDouble(),
                            reservedSize: isMobile ? 28 : 34,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}j',
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 8.5 : 10,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w400,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                              if (value >= 0 && value < 7) {
                                final isToday = DateTime.now().weekday - 1 == value.toInt();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    days[value.toInt()],
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 8.5 : 10,
                                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                      color: isToday ? AppColors.primaryBlue : Colors.grey[500],
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(7, (index) {
                        final value = _weeklyData[index];
                        final isSelected = _selectedIndex == index;
                        final isToday = DateTime.now().weekday - 1 == index;

                        return BarChartGroupData(
                          x: index,
                          showingTooltipIndicators: isSelected ? [0] : [],
                          barRods: [
                            BarChartRodData(
                              toY: value,
                              width: barWidth,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(isMobile ? 4 : 6),
                                topRight: Radius.circular(isMobile ? 4 : 6),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: isSelected
                                    ? [
                                        AppColors.accentOrange,
                                        AppColors.accentOrange.withAlpha(180),
                                      ]
                                    : isToday
                                        ? [
                                            AppColors.primaryBlue,
                                            AppColors.primaryBlue.withAlpha(200),
                                          ]
                                        : [
                                            AppColors.primaryBlue.withAlpha(140),
                                            AppColors.primaryBlue.withAlpha(90),
                                          ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
      ),
    );
  }

  // =========================
  // 🔥 PIE CHART SECTION (Responsive)
  // =========================
  Widget _buildPieChartSection({
    required bool isMobile,
    required bool isTablet,
    required double sectionTitleSize,
  }) {
    final pieHeight = isMobile ? 130.0 : (isTablet ? 200.0 : 160.0);
    final total = _statusDistribution.values.fold<int>(0, (sum, val) => sum + val);

    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSectionTitle(
          title: 'Distribusi Status',
          color: const Color(0xFF7C3AED),
          fontSize: sectionTitleSize,
        ),
        SizedBox(height: isMobile ? 8 : 12),
        // 🔥 Mobile: Stack vertically, Tablet: Row
        isMobile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pie Chart - Center
                  Center(
                    child: SizedBox(
                      height: pieHeight,
                      width: pieHeight,
                      child: _isStatusLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: const Color(0xFF7C3AED),
                              ),
                            )
                          : PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: pieHeight * 0.22,
                                sections: _buildPieSections(isMobile: true),
                                pieTouchData: PieTouchData(
                                  touchCallback: (event, response) {},
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Legend - Wrap untuk mobile
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: _buildPieLegends(total, isMobile: true),
                  ),
                ],
              )
            : Row(
                children: [
                  SizedBox(
                    height: pieHeight,
                    width: pieHeight,
                    child: _isStatusLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: const Color(0xFF7C3AED),
                            ),
                          )
                        : PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: pieHeight * 0.25,
                              sections: _buildPieSections(isMobile: false),
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {},
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildPieLegends(total, isMobile: false),
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  // 🔥 Build pie chart sections
  List<PieChartSectionData> _buildPieSections({required bool isMobile}) {
    final Map<String, Color> statusColors = {
      'Disetujui': const Color(0xFF16A34A),
      'Ditolak': const Color(0xFFDC2626),
      'Pending Fungsi': const Color(0xFFEA580C),
      'Pending HSSE': const Color(0xFFB45309),
      'Selesai': const Color(0xFF2563EB),
      'Check In': const Color(0xFF0D9488),
    };

    final total = _statusDistribution.values.fold<int>(0, (sum, val) => sum + val);

    return _statusDistribution.entries.map((entry) {
      final percentage = (entry.value / total * 100).toStringAsFixed(1);
      final color = statusColors[entry.key] ?? Colors.grey;
      final showPercentage = (entry.value / total) >= 0.05; // Tampilkan % jika >= 5%

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: showPercentage ? '$percentage%' : '',
        radius: isMobile ? 30 : 40,
        titleStyle: GoogleFonts.poppins(
          fontSize: isMobile ? 8.5 : 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        badgeWidget: entry.value > 0
            ? Container(
                padding: EdgeInsets.all(isMobile ? 1.5 : 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _getStatusIcon(entry.key),
                  size: isMobile ? 8 : 10,
                  color: color,
                ),
              )
            : null,
      );
    }).toList();
  }

  // 🔥 Build pie legends
  List<Widget> _buildPieLegends(int total, {required bool isMobile}) {
    final Map<String, Color> statusColors = {
      'Disetujui': const Color(0xFF16A34A),
      'Ditolak': const Color(0xFFDC2626),
      'Pending Fungsi': const Color(0xFFEA580C),
      'Pending HSSE': const Color(0xFFB45309),
      'Selesai': const Color(0xFF2563EB),
      'Check In': const Color(0xFF0D9488),
    };

    return _statusDistribution.entries.map((entry) {
      final percentage = (entry.value / total * 100).toStringAsFixed(1);
      final color = statusColors[entry.key] ?? Colors.grey;

      return Padding(
        padding: EdgeInsets.only(
          bottom: isMobile ? 0 : 4,
          right: isMobile ? 4 : 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMobile ? 8 : 10,
              height: isMobile ? 8 : 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(isMobile ? 2 : 3),
              ),
            ),
            SizedBox(width: isMobile ? 4 : 6),
            Flexible(
              child: Text(
                '${entry.key}: ${entry.value} ($percentage%)',
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 8.5 : 10,
                  color: const Color(0xFF4A5568),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // 🔥 Get icon for status
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Disetujui':
        return Icons.check_circle;
      case 'Ditolak':
        return Icons.cancel;
      case 'Pending Fungsi':
        return Icons.pending_actions;
      case 'Pending HSSE':
        return Icons.shield;
      case 'Selesai':
        return Icons.task_alt;
      case 'Check In':
        return Icons.login;
      default:
        return Icons.circle;
    }
  }

  // =========================
  // CHIP (Responsive)
  // =========================
  Widget _buildChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required double fontSize,
    required double iconSize,
    required double paddingH,
    required double paddingV,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 60),
      padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          SizedBox(width: paddingH * 0.4),
          Flexible(
            child: Text(
              '$label: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // LEGEND
  // =========================
  Widget _buildLegend(String label, Color color, {required double fontSize}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            color: const Color(0xFF4A5568),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // =========================
  // EMPTY STATE
  // =========================
  Widget _buildEmptyState({required bool isMobile}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isMobile ? 50 : 70,
            height: isMobile ? 50 : 70,
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              size: isMobile ? 28 : 38,
              color: Colors.grey[350],
            ),
          ),
          SizedBox(height: isMobile ? 10 : 14),
          Text(
            'Belum ada data lembur',
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4A5568),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada aktivitas lembur minggu ini.',
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 9 : 11,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}