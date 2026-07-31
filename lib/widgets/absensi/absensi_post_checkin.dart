// lib/screens/absensi/widgets/absensi_post_checkin.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/dashboard/mitra/absensi_state.dart';
import '/widgets/absensi/absensi_workflow.dart';

class AbsensiPostCheckin extends StatelessWidget {
  final AbsensiState state;
  final AbsensiWorkflow workflow;

  const AbsensiPostCheckin({
    super.key,
    required this.state,
    required this.workflow,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    final hp = MediaQuery.of(context).size.width * 0.04;

    final now = DateTime.now();
    final parts = state.overtimeItem!.jamSelesai.split(':');
    DateTime? jamSelesai;
    if (parts.length == 2) {
      jamSelesai = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 24),
      child: Column(
        children: [
          // Success card
          Container(
            padding: EdgeInsets.all(isSmall ? 16 : 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_rounded, size: isSmall ? 48 : 60, color: Colors.white),
                const SizedBox(height: 14),
                Text('✅ Check-in Berhasil!', style: TextStyle(fontSize: isSmall ? 18 : 22, fontWeight: FontWeight.bold, color: Colors.white)),
                if (state.checkInTime != null)
                  Text('Check-in: ${DateFormat('HH:mm').format(state.checkInTime!)} WIB', style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Status cards
          Row(
            children: [
              Expanded(child: _StatusItem(icon: Icons.access_time, title: 'Jam', value: '${state.overtimeItem!.jamMulai} - ${state.overtimeItem!.jamSelesai}', color: Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _StatusItem(icon: Icons.timer, title: 'Durasi', value: '${state.overtimeItem!.totalJam.toStringAsFixed(1)} jam', color: Colors.purple)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatusItem(
                icon: state.isLiveLocationActive ? Icons.location_on : Icons.location_off,
                title: 'Live Location',
                value: state.isLiveLocationActive ? '🟢 Aktif' : '🔴 Off',
                color: state.isLiveLocationActive ? Colors.green : Colors.red,
              )),
              const SizedBox(width: 8),
              Expanded(child: _StatusItem(
                icon: state.canCheckOut ? Icons.logout : Icons.schedule,
                title: 'Check-out',
                value: state.canCheckOut ? '✅ Siap' : '⏳ Menunggu',
                color: state.canCheckOut ? Colors.orange : Colors.grey,
              )),
            ],
          ),
          
          // Reminder
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pengingat', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('• Live location Anda sedang aktif\n• Jangan lupa check-out setelah selesai\n• Check-out 30 menit sebelum jam selesai'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatusItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}