// lib/widgets/mitra/mitra_performance_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MitraPerformanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> performanceData;

  const MitraPerformanceChart({
    super.key,
    required this.performanceData,
  });

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
  Widget build(BuildContext context) {
    // ✅ CEK: Apakah data benar-benar kosong atau semua nilainya nol?
    final bool hasAllZeroValues = performanceData.isEmpty
        ? true
        : performanceData.every((data) {
            final value = (data['hours'] as num?)?.toDouble() ?? 0.0;
            return value == 0.0;
          });

    // ✅ JIKA TIDAK ADA DATA, TAMPILKAN PESAN INFORMATIF
    if (performanceData.isEmpty || hasAllZeroValues) {
      return _buildEmptyState();
    }

    // ✅ JIKA ADA DATA, TAMPILKAN CHART
    final maxY = _getMaxValue() * 1.3;

    return Container(
      padding: const EdgeInsets.all(22),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 24),

          // Chart
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toStringAsFixed(1)} jam\n${_getMonthLabel(groupIndex)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _getMonthLabel(value.toInt()),
                            style: const TextStyle(
                              fontSize: 10,
                              color: textMid,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}h',
                          style: const TextStyle(
                            fontSize: 10,
                            color: textMid,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: lightBlue.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: performanceData.asMap().entries.map((entry) {
                  final hours = (entry.value['hours'] ?? 0).toDouble();
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: hours,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [darkBlue, accentBlue],
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: lightBlue.withOpacity(0.15),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  borderColor.withOpacity(0),
                  borderColor.withOpacity(0.8),
                  borderColor.withOpacity(0),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Summary Stats
          _buildSummaryStats(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryBlue, accentBlue],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.show_chart_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Grafik Performa',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Total jam lembur per bulan',
                style: TextStyle(
                  fontSize: 11,
                  color: textMid,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // Legend
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryBlue, accentBlue],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Jam Lembur',
                style: TextStyle(
                  fontSize: 10,
                  color: textMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // SUMMARY STATS
  // ═══════════════════════════════════════════════════════
  Widget _buildSummaryStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            icon: Icons.summarize_rounded,
            label: 'Total',
            value: '${_getTotalHours().toStringAsFixed(1)} jam',
            color: darkBlue,
          ),
        ),
        Container(
          width: 1,
          height: 35,
          color: borderColor.withOpacity(0.6),
        ),
        Expanded(
          child: _buildStatChip(
            icon: Icons.trending_up_rounded,
            label: 'Rata-rata',
            value: '${_getAverageHours().toStringAsFixed(1)} jam/bln',
            color: primaryBlue,
          ),
        ),
        Container(
          width: 1,
          height: 35,
          color: borderColor.withOpacity(0.6),
        ),
        Expanded(
          child: _buildStatChip(
            icon: Icons.emoji_events_rounded,
            label: 'Tertinggi',
            value: '${_getMaxValue().toStringAsFixed(1)} jam',
            color: accentBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.7)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // EMPTY STATE - ✅ PESAN JELAS SAAT DATA KOSONG
  // ═══════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container dengan gradient subtle
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
              Icons.show_chart_rounded,
              size: 44,
              color: textLight,
            ),
          ),
          const SizedBox(height: 20),

          // Pesan utama
          const Text(
            'Belum ada data lembur bulan ini.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textMid,
              letterSpacing: -0.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Sub-pesan
          Text(
            'Data performa akan muncul setelah Anda\nmenyelesaikan aktivitas lembur.',
            style: TextStyle(
              fontSize: 12,
              color: textLight,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Ilustrasi mini chart kosong
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                6,
                (index) => Container(
                  width: 18,
                  height: [20, 30, 15, 25, 10, 20][index].toDouble(),
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

  // ═══════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════
  double _getMaxValue() {
    if (performanceData.isEmpty) return 10;
    double max = 0;
    for (var data in performanceData) {
      final hours = (data['hours'] ?? 0).toDouble();
      if (hours > max) max = hours;
    }
    return max < 10 ? 10 : max;
  }

  double _getTotalHours() {
    return performanceData.fold(
        0.0, (sum, d) => sum + (d['hours'] ?? 0).toDouble());
  }

  double _getAverageHours() {
    if (performanceData.isEmpty) return 0;
    return _getTotalHours() / performanceData.length;
  }

  String _getMonthLabel(int index) {
    if (index < performanceData.length) {
      return performanceData[index]['month']?.toString() ?? '';
    }
    return '';
  }
}