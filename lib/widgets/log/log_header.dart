import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LogHeader extends StatelessWidget {
  final Color primaryBlue;
  final int totalLogs;
  
  // Constants untuk konsistensi
  static const _borderRadius = Radius.circular(30);
  static const _headerPadding = EdgeInsets.fromLTRB(20, 24, 20, 16);

  const LogHeader({
    super.key,
    required this.primaryBlue,
    required this.totalLogs,
  });

  // Computed properties
  Color get _secondaryBlue => Color.lerp(primaryBlue, Colors.black, 0.2)!;
  
  String get _formattedTotalLogs {
    if (totalLogs < 0) return '0';
    if (totalLogs > 9999) {
      return '${(totalLogs / 1000).toStringAsFixed(1)}K+';
    }
    return NumberFormat('#,###').format(totalLogs);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Semantics(
      header: true,
      container: true,
      label: 'System Logs Monitor. Total $_formattedTotalLogs logs',
      child: Container(
        width: double.infinity,
        padding: _headerPadding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryBlue, _secondaryBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: _borderRadius,
            bottomRight: _borderRadius,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log Sistem',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ) ?? GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pantau aktivitas sistem, pengguna, lembur, dan absensi',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ) ?? GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            _buildLogCountBadge(textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCountBadge(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storage, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            'Total Log: $_formattedTotalLogs',
            style: (textTheme.labelSmall ?? GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white,
            )).copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}