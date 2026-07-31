// lib/screens/absensi/widgets/absensi_idle_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'shared/overtime_info_card.dart';

class AbsensiIdleView extends StatelessWidget {
  final dynamic overtimeItem; // OvertimeHistory
  final int lateOvertimeCount;
  final String statusMessage;
  final String? errorDetail;
  final VoidCallback onRefresh;
  final VoidCallback onGoToLateOvertime;

  const AbsensiIdleView({
    super.key,
    required this.overtimeItem,
    required this.lateOvertimeCount,
    required this.statusMessage,
    this.errorDetail,
    required this.onRefresh,
    required this.onGoToLateOvertime,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    final hp = MediaQuery.of(context).size.width * 0.04;

    final now = DateTime.now();
    final partsMulai = overtimeItem.jamMulai.split(':');
    DateTime? earliestCheckIn;

    if (partsMulai.length == 2) {
      final jamMulai = DateTime(now.year, now.month, now.day,
          int.parse(partsMulai[0]), int.parse(partsMulai[1]));
      earliestCheckIn = jamMulai.subtract(const Duration(minutes: 30));
    }

    final diff = earliestCheckIn != null ? earliestCheckIn.difference(now) : null;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 24),
      child: Column(
        children: [
          OvertimeInfoCard(
            overtimeItem: overtimeItem,
            isLateOvertime: false,
          ),
          const SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(isSmall ? 14 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.blue.shade50],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.blue.shade700, size: isSmall ? 24 : 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⏰ Jadwal Lembur Hari Ini',
                            style: TextStyle(
                              fontSize: isSmall ? 13 : 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusMessage,
                            style: TextStyle(fontSize: isSmall ? 11 : 12, color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (earliestCheckIn != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Check-in dibuka: ${DateFormat('dd MMM HH:mm').format(earliestCheckIn)} WIB',
                          style: TextStyle(
                            fontSize: isSmall ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        if (diff != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${diff.inHours}j ${diff.inMinutes.remainder(60)}m lagi',
                            style: TextStyle(fontSize: isSmall ? 16 : 20, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (lateOvertimeCount > 0) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onGoToLateOvertime,
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      label: Text(
                        'Lihat $lateOvertimeCount Lembur Terlambat',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}