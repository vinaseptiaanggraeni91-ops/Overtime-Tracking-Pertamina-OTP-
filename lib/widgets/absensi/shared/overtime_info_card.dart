// lib/screens/absensi/widgets/shared/overtime_info_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OvertimeInfoCard extends StatelessWidget {
  final dynamic overtimeItem;
  final bool isLateOvertime;

  const OvertimeInfoCard({
    super.key,
    required this.overtimeItem,
    this.isLateOvertime = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    final alamat = _getAlamat(overtimeItem.lokasi);

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLateOvertime)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ Lembur Terlambat - ${DateFormat('dd MMM').format(overtimeItem.tanggal)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ),
          _InfoRow(icon: Icons.calendar_today, text: DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(overtimeItem.tanggal)),
          _InfoRow(icon: Icons.access_time, text: '${overtimeItem.jamMulai} - ${overtimeItem.jamSelesai} (${overtimeItem.totalJam.toStringAsFixed(1)} jam)'),
          _InfoRow(icon: Icons.location_on, text: alamat),
          _InfoRow(icon: Icons.person, text: overtimeItem.namaMitra ?? overtimeItem.namaPengawas ?? 'Tidak diketahui'),
        ],
      ),
    );
  }

  String _getAlamat(dynamic lokasi) {
    if (lokasi is Map) {
      return (lokasi['alamat'] ?? lokasi['nama_lokasi'] ?? 'Kantor').toString();
    }
    return lokasi?.toString() ?? 'Kantor';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white))),
        ],
      ),
    );
  }
}