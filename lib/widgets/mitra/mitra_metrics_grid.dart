// lib/widgets/mitra/mitra_metrics_grid.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MitraMetricsGrid extends StatelessWidget {
  final int totalLembur;
  final double totalJam;
  final int pending;
  final int disetujui;
  final double totalIncome;
  final double sisaKuota;
  final double trendLembur;
  final double trendJam;
  final double trendIncome;
  final String bulanIniLabel;

  const MitraMetricsGrid({
    super.key,
    required this.totalLembur,
    required this.totalJam,
    required this.pending,
    required this.disetujui,
    required this.totalIncome,
    required this.sisaKuota,
    this.trendLembur = 0.0,
    this.trendJam = 0.0,
    this.trendIncome = 0.0,
    this.bulanIniLabel = '',
  });

  static const Color navy = Color(0xFF1E3C72);
  static const Color darkNavy = Color(0xFF0A1128);
  static const Color royal = Color(0xFF2A5298);
  static const Color accent = Color(0xFF5B8DEF);
  static const Color soft = Color(0xFF8DB3FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color green = Color(0xFF2E7D32);
  static const Color orange = Color(0xFFFF6D00);
  static const Color textLight = Color(0xFF90A4AE);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isSmall = w < 360;
        final sf = (w / 400).clamp(0.92, 1.05); // ✅ DIPERKECIL MAX

        const double maxKuota = 60.0;
        final double kuotaTerpakai = (maxKuota - sisaKuota).clamp(0, maxKuota);
        final double kuotaPct = maxKuota > 0 ? (kuotaTerpakai / maxKuota).clamp(0.0, 1.0) : 0.0;

        final String tLembur = _fmtTrend(trendLembur);
        final String tJam = _fmtTrend(trendJam);
        final String tIncome = _fmtTrend(trendIncome);
        final bool tLemburUp = trendLembur >= 0;
        final bool tJamUp = trendJam >= 0;
        final bool tIncomeUp = trendIncome >= 0;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, c) => Transform.scale(scale: v.clamp(0.0, 1.0), child: Opacity(opacity: v.clamp(0.0, 1.0), child: c)),
          child: Container(
            padding: EdgeInsets.all(16 * sf),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF0F4FC), Color(0xFFFFFFFF), Color(0xFFE8EEF8)]),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(color: navy.withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 12), spreadRadius: 1),
                BoxShadow(color: accent.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, -5)),
              ],
              border: Border.all(color: navy.withValues(alpha: 0.06), width: 1.5),
            ),
            child: Stack(
              children: [
                Positioned(top: -50, right: -50, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [accent.withValues(alpha: 0.06), Colors.transparent])))),
                Positioned(bottom: -40, left: -40, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [royal.withValues(alpha: 0.05), Colors.transparent])))),

                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.only(bottom: 14 * sf),
                    child: Row(children: [
                      Container(width: 4, height: 22 * sf, decoration: const BoxDecoration(gradient: LinearGradient(colors: [accent, royal]), borderRadius: BorderRadius.vertical(top: Radius.circular(2), bottom: Radius.circular(2)))),
                      SizedBox(width: 10 * sf),
                      Text('Ringkasan Bulan Ini', style: TextStyle(fontSize: 16 * sf, fontWeight: FontWeight.w800, color: darkNavy, letterSpacing: -0.3)),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10 * sf, vertical: 5 * sf),
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [accent.withValues(alpha: 0.1), royal.withValues(alpha: 0.05)]), borderRadius: BorderRadius.circular(10 * sf), border: Border.all(color: accent.withValues(alpha: 0.2), width: 1)),
                        child: Text(bulanIniLabel.isNotEmpty ? bulanIniLabel : _getCurrentMonth(), style: TextStyle(fontSize: 11 * sf, fontWeight: FontWeight.w700, color: royal)),
                      ),
                    ]),
                  ),

                  // Row 1
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _metricCard(icon: Icons.work_history_rounded, label: 'Total Lembur', value: '$totalLembur', suffix: 'kali', gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)]), color: navy, sf: sf, trend: tLembur, trendUp: tLemburUp, accentColor: const Color(0xFF42A5F5))),
                    SizedBox(width: 10 * sf),
                    Expanded(child: _metricCard(icon: Icons.timer_rounded, label: 'Total Jam', value: totalJam.toStringAsFixed(1), suffix: 'jam', gradient: const LinearGradient(colors: [Color(0xFF2A5298), Color(0xFF5B8DEF)]), color: royal, sf: sf, trend: tJam, trendUp: tJamUp, accentColor: accent)),
                  ]),
                  SizedBox(height: 10 * sf),

                  // Row 2
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _metricCard(icon: Icons.pending_actions_rounded, label: 'Pending', value: '$pending', suffix: 'pengajuan', gradient: const LinearGradient(colors: [Color(0xFFFF6D00), Color(0xFFFF9100)]), color: orange, sf: sf, isWarning: pending > 0, trend: pending > 0 ? 'Perlu Aksi' : 'Aman', trendUp: false, accentColor: const Color(0xFFFFAB40))),
                    SizedBox(width: 10 * sf),
                    Expanded(child: _metricCard(icon: Icons.check_circle_rounded, label: 'Disetujui', value: '$disetujui', suffix: 'pengajuan', gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)]), color: green, sf: sf, trend: _fmtTrend(trendLembur), trendUp: tLemburUp, accentColor: const Color(0xFF66BB6A))),
                  ]),

                  if (totalIncome > 0) ...[
                    SizedBox(height: 10 * sf),
                    _incomeRow(totalIncome, sf, tIncome, tIncomeUp),
                  ],

                  SizedBox(height: 18 * sf),
                  Container(height: 1.5, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, accent.withValues(alpha: 0.2), royal.withValues(alpha: 0.15), accent.withValues(alpha: 0.2), Colors.transparent]))),
                  SizedBox(height: 18 * sf),

                  _kuotaCard(kuotaPct, maxKuota, sf),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // METRIC CARD - ✅ FONT DIPERKECIL
  // ═══════════════════════════════════════════════════════
  Widget _metricCard({
    required IconData icon, required String label, required String value, required String suffix,
    required Gradient gradient, required Color color, required double sf,
    String? trend, bool trendUp = true, bool isWarning = false, required Color accentColor,
  }) {
    return Container(
      padding: EdgeInsets.all(12 * sf),
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isWarning ? orange.withValues(alpha: 0.4) : color.withValues(alpha: 0.1), width: isWarning ? 2.0 : 1.2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: isWarning ? 0.12 : 0.06), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: 1),
          BoxShadow(color: accentColor.withValues(alpha: isWarning ? 0.06 : 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(padding: EdgeInsets.all(8 * sf), decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 5)), BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))], border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.2)), child: Icon(icon, size: 18 * sf, color: Colors.white)),
          const Spacer(),
          if (trend != null) _trendBadge(trend, trendUp, isWarning, sf),
        ]),
        SizedBox(height: 12 * sf),
        Text(value, style: TextStyle(fontSize: 28 * sf, fontWeight: FontWeight.w900, color: darkNavy, letterSpacing: -1.5, height: 0.9, shadows: [Shadow(color: color.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))]), maxLines: 1, overflow: TextOverflow.ellipsis),
        SizedBox(height: 3 * sf),
        if (suffix.isNotEmpty) Text(suffix, style: TextStyle(fontSize: 11 * sf, color: color.withValues(alpha: 0.6), fontWeight: FontWeight.w600, letterSpacing: -0.2)),
        SizedBox(height: 4 * sf),
        Text(label, style: TextStyle(fontSize: 11 * sf, color: textLight, fontWeight: FontWeight.w500, letterSpacing: 0.1), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _trendBadge(String text, bool up, bool warn, double sf) {
    final Color c = warn ? orange : (up ? green : const Color(0xFFD32F2F));
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7 * sf, vertical: 4 * sf),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.3)), boxShadow: [BoxShadow(color: c.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(warn ? Icons.warning_amber_rounded : (up ? Icons.trending_up_rounded : Icons.trending_down_rounded), size: 11 * sf, color: c),
        SizedBox(width: 2),
        Text(text, style: TextStyle(fontSize: 9 * sf, fontWeight: FontWeight.w800, color: c, letterSpacing: -0.2)),
      ]),
    );
  }

  Widget _incomeRow(double income, double sf, String trend, bool trendUp) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * sf, vertical: 12 * sf),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [royal.withValues(alpha: 0.04), accent.withValues(alpha: 0.08), soft.withValues(alpha: 0.04)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withValues(alpha: 0.2), width: 1.5), boxShadow: [BoxShadow(color: royal.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 6))]),
      child: Row(children: [
        Container(padding: EdgeInsets.all(10 * sf), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: navy.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))], border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.2)), child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20 * sf)),
        SizedBox(width: 12 * sf),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Estimasi Pendapatan', style: TextStyle(fontSize: 11 * sf, color: textLight, fontWeight: FontWeight.w500)),
          SizedBox(height: 3 * sf),
          Text(_fmtCurrency(income), style: TextStyle(fontSize: 22 * sf, fontWeight: FontWeight.w900, color: darkNavy, letterSpacing: -1.0, shadows: [Shadow(color: navy.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))]), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (trend.isNotEmpty) _trendBadge(trend, trendUp, false, sf),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  // KUOTA CARD - ✅ DIPERKECIL & RAPI
  // ═══════════════════════════════════════════════════════
  Widget _kuotaCard(double kuotaPct, double maxKuota, double sf) {
    final bool isWarn = kuotaPct > 0.8;
    final bool isMid = kuotaPct > 0.5 && kuotaPct <= 0.8;
    final Color c = isWarn ? orange : (isMid ? accent : green);
    final String status = isWarn ? '⚡ Hampir Penuh' : (isMid ? '📊 Terpakai' : '✅ Aman');
    final Color bgColor = isWarn ? const Color(0xFFFFF3E0) : (isMid ? const Color(0xFFE3F2FD) : const Color(0xFFE8F5E9));

    return Container(
      padding: EdgeInsets.all(18 * sf),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [bgColor, surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(padding: EdgeInsets.all(9 * sf), decoration: BoxDecoration(gradient: LinearGradient(colors: [c, c.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 5))], border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2)), child: Icon(Icons.pie_chart_rounded, size: 20 * sf, color: Colors.white)),
          SizedBox(width: 10 * sf),
          Expanded(child: Text('Kuota Lembur', style: TextStyle(fontSize: 14 * sf, fontWeight: FontWeight.w800, color: darkNavy, letterSpacing: -0.3))),
          Container(padding: EdgeInsets.symmetric(horizontal: 8 * sf, vertical: 4 * sf), decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.25))), child: Text(status, style: TextStyle(fontSize: 10 * sf, fontWeight: FontWeight.w700, color: c))),
        ]),
        SizedBox(height: 16 * sf),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _kuotaInfo('Terpakai', '${(maxKuota - sisaKuota).toStringAsFixed(1)}', 'jam', darkNavy, sf),
          Container(width: 1, height: 40 * sf, color: textLight.withValues(alpha: 0.12)),
          _kuotaInfo('Tersisa', '${sisaKuota.toStringAsFixed(1)}', 'jam', c, sf),
          Container(width: 1, height: 40 * sf, color: textLight.withValues(alpha: 0.12)),
          _kuotaInfo('Maks', '${maxKuota.toStringAsFixed(0)}', 'jam', textLight, sf),
        ]),
        SizedBox(height: 14 * sf),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(children: [
            Container(height: 12 * sf, decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10))),
            AnimatedFractionallySizedBox(duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic, widthFactor: kuotaPct.clamp(0.0, 1.0), child: Container(height: 12 * sf, decoration: BoxDecoration(gradient: LinearGradient(colors: [c, c.withValues(alpha: 0.8)]), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]))),
          ]),
        ),
        SizedBox(height: 8 * sf),
        Text('${(kuotaPct * 100).toStringAsFixed(0)}% terpakai dari ${maxKuota.toStringAsFixed(0)} jam', style: TextStyle(fontSize: 10 * sf, color: textLight, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _kuotaInfo(String label, String value, String suffix, Color color, double sf) {
    return SizedBox(
      width: 64 * sf,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(fontSize: 18 * sf, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5, height: 1), textAlign: TextAlign.center),
        SizedBox(height: 3),
        Text(suffix, style: TextStyle(fontSize: 10 * sf, color: color.withValues(alpha: 0.5), fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11 * sf, color: textLight, fontWeight: FontWeight.w600, letterSpacing: 0.1), textAlign: TextAlign.center),
      ]),
    );
  }

  String _fmtTrend(double trend) => trend == 0 ? '0%' : '${trend > 0 ? "+" : ""}${trend.toStringAsFixed(0)}%';
  String _fmtCurrency(double v) {
    if (v >= 1000000000) return 'Rp ${(v / 1000000000).toStringAsFixed(1)}M';
    if (v >= 1000000) return 'Rp ${(v / 1000000).toStringAsFixed(1)}Jt';
    if (v >= 1000) return 'Rp ${(v / 1000).toStringAsFixed(0)}Rb';
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(v);
  }
  String _getCurrentMonth() {
    const m = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return m[DateTime.now().month - 1];
  }
}