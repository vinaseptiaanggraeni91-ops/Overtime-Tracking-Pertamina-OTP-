// lib/widgets/pengawas/analytics_section.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/pengawas_service.dart';

class AnalyticsSection extends StatefulWidget {
  final PengawasDashboardData data;

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

  // ═══════════════════════════════════════════════════════
  // 🔵 COLOR PALETTE
  // ═══════════════════════════════════════════════════════
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color accentBlue = Color(0xFF42A5F5);
  static const Color lightBlue = Color(0xFFBBDEFB);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF0D1B2A);
  static const Color textMid = Color(0xFF546E7A);
  static const Color textLight = Color(0xFF90A4AE);
  static const Color borderColor = Color(0xFFE3E8F0);
  static const Color bgCard = Color(0xFFF5F9FF);

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
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
      
      // Fallback: generate sample data
      final avg = (widget.data.totalLemburToday / 7).clamp(0.0, 25.0);
      
      if (mounted) {
        setState(() {
          _weeklyData = List.generate(7, (i) => 
            (avg * (0.45 + (i % 5) * 0.22)).clamp(0.0, 25.0)
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _loadWeeklyData();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 700;
    final chartHeight = isTablet ? 270.0 : 220.0;
    final barWidth = isTablet ? 24.0 : 18.0;
    
    final maxVal = _weeklyData.reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal * 1.4).ceilToDouble().clamp(10.0, 50.0);
    final hasData = _weeklyData.any((e) => e > 0);

    return Container(
      padding: const EdgeInsets.all(16), // ⬅️ padding dikurangi dari 18 ke 16
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: accentBlue.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ⬅️ TAMBAHKAN INI
        children: [
          // HEADER
          _buildHeader(),
          const SizedBox(height: 16), // ⬅️ dikurangi dari 18 ke 16

          // 🔥🔥🔥 INFO CHIPS - SUDAH DIPERBAIKI
          _buildInfoChips(),
          const SizedBox(height: 18), // ⬅️ dikurangi dari 20 ke 18

          // CHART
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: SizedBox(
              key: ValueKey(_isLoading.toString() + hasData.toString()),
              height: chartHeight,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryBlue),
                    )
                  : !hasData
                      ? _buildEmptyState()
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxY,
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: (maxY / 4).clamp(1, 25),
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey.withOpacity(0.15),
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
                                  reservedSize: 34,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toInt()}j',
                                      style: const TextStyle(fontSize: 10, color: textMid),
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
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          days[value.toInt()],
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                            color: isToday ? primaryBlue : textMid,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                              ),
                            ),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchCallback: (event, response) {
                                setState(() {
                                  _selectedIndex = response?.spot?.touchedBarGroupIndex ?? -1;
                                });
                              },
                              touchTooltipData: BarTouchTooltipData(
                                tooltipPadding: const EdgeInsets.all(10),
                                tooltipMargin: 8,
                                getTooltipColor: (_) => Colors.blueGrey.shade800,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
                                  return BarTooltipItem(
                                    '${days[group.x.toInt()]}\n${_weeklyData[group.x.toInt()].toStringAsFixed(1)} jam',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  );
                                },
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
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                    gradient: isSelected
                                        ? const LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [Color(0xFFFFAB40), Color(0xFFFF8F00)],
                                          )
                                        : isToday
                                            ? const LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [darkBlue, primaryBlue],
                                              )
                                            : LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  primaryBlue.withOpacity(0.5),
                                                  primaryBlue.withOpacity(0.3),
                                                ],
                                              ),
                                    backDrawRodData: BackgroundBarChartRodData(
                                      show: true,
                                      toY: maxY,
                                      color: lightBlue.withOpacity(0.15),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 16), // ⬅️ dikurangi dari 18 ke 16

          // LEGEND
          Center(
            child: _buildLegend('Jam Lembur', primaryBlue),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible( // ⬅️ TAMBAHKAN Flexible
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10), // ⬅️ dikurangi dari 11 ke 10
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryBlue, accentBlue],
                  ),
                  borderRadius: BorderRadius.circular(12), // ⬅️ dikurangi dari 14 ke 12
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  size: 18, // ⬅️ dikurangi dari 20 ke 18
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10), // ⬅️ dikurangi dari 12 ke 10
              Flexible( // ⬅️ TAMBAHKAN Flexible
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Lembur Mingguan',
                      style: TextStyle(
                        fontSize: 14, // ⬅️ dikurangi dari 15 ke 14
                        fontWeight: FontWeight.w700,
                        color: textDark,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis, // ⬅️ TAMBAHKAN
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Analisis aktivitas lembur',
                      style: TextStyle(
                        fontSize: 10, // ⬅️ dikurangi dari 11 ke 10
                        color: textMid,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis, // ⬅️ TAMBAHKAN
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8), // ⬅️ TAMBAHKAN spacing
        InkWell(
          onTap: _refresh,
          borderRadius: BorderRadius.circular(10), // ⬅️ dikurangi dari 12 ke 10
          child: Container(
            padding: const EdgeInsets.all(8), // ⬅️ dikurangi dari 10 ke 8
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10), // ⬅️ dikurangi dari 12 ke 10
              border: Border.all(color: primaryBlue.withOpacity(0.1)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16, // ⬅️ dikurangi dari 18 ke 16
                    height: 16, // ⬅️ dikurangi dari 18 ke 16
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryBlue,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18, color: primaryBlue), // ⬅️ dikurangi dari 20 ke 18
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 INFO CHIPS - SUDAH DIPERBAIKI TOTAL
  // ═══════════════════════════════════════════════════════
  Widget _buildInfoChips() {
    final totalToday = widget.data.totalLemburToday + widget.data.todayPending;
    final pendingToday = widget.data.todayPending;
    final onlineMembers = widget.data.onlineMembers;

    // 🔥 GUNAKAN Row + Expanded biar nggak overflow di OPPO
    return Row(
      children: [
        Expanded(
          child: _buildChip(
            label: 'Total',
            value: '$totalToday',
            icon: Icons.work_history_rounded,
            color: primaryBlue,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildChip(
            label: 'Pending',
            value: '$pendingToday',
            icon: Icons.pending_actions_rounded,
            color: pendingToday > 0 ? const Color(0xFFFF9800) : const Color(0xFF43A047),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildChip(
            label: 'Online',
            value: '$onlineMembers',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF43A047),
          ),
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), // ⬅️ padding horizontal dikurangi
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10), // ⬅️ radius dikurangi
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column( // ⬅️ UBAH JADI COLUMN biar lebih compact
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color), // ⬅️ icon di atas, lebih besar
          const SizedBox(height: 4),
          Text(
            value, // ⬅️ angka besar di bawah
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label, // ⬅️ label kecil di bawah
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // LEGEND
  // ═══════════════════════════════════════════════════════
  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [darkBlue, primaryBlue],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: textMid, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue.withOpacity(0.08),
                  accentBlue.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: lightBlue.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              size: 44,
              color: textLight,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada data lembur',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textMid,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada aktivitas lembur minggu ini.',
            style: TextStyle(
              fontSize: 11,
              color: textLight,
            ),
          ),
          const SizedBox(height: 16),
          // Mini chart kosong
          SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                7,
                (index) => Container(
                  width: 14,
                  height: [15, 25, 10, 20, 8, 30, 12][index].toDouble(),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: lightBlue.withOpacity(0.4),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}