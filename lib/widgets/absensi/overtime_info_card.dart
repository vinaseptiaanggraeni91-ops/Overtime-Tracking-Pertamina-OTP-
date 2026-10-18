// lib/widgets/absensi/overtime_info_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class OvertimeInfoCard extends StatelessWidget {
  final String tanggal;
  final String jamMulai;
  final String jamSelesai;
  final double totalJam;
  final String lokasi;
  final String nama;
  final bool isLate;

  const OvertimeInfoCard({
    super.key,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.totalJam,
    required this.lokasi,
    required this.nama,
    this.isLate = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Late badge
          if (isLate) _buildLateBadge(isSmall),
          if (isLate) SizedBox(height: isSmall ? 8 : 10),

          // Header
          Row(
            children: [
              Icon(Icons.work, color: Colors.white, size: isSmall ? 16 : 20),
              SizedBox(width: isSmall ? 6 : 8),
              Flexible(
                child: Text(
                  'Detail Lembur',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: isSmall ? 13 : 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 10 : 12),

          // Info rows
          _buildInfoRow(Icons.calendar_today, tanggal, isSmall),
          _buildInfoRow(
            Icons.access_time,
            '$jamMulai - $jamSelesai (${totalJam.toStringAsFixed(1)} jam)',
            isSmall,
          ),
          _buildInfoRow(Icons.location_on, lokasi, isSmall),
          _buildInfoRow(Icons.person, nama, isSmall),
        ],
      ),
    );
  }

  Widget _buildLateBadge(bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 10,
        vertical: isSmall ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.shade400,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: isSmall ? 14 : 16),
          SizedBox(width: isSmall ? 4 : 6),
          Text(
            '⚠️ Lembur Terlambat',
            style: GoogleFonts.poppins(
              fontSize: isSmall ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isSmall) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmall ? 4 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: isSmall ? 12 : 14, color: Colors.white70),
          SizedBox(width: isSmall ? 8 : 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: isSmall ? 11 : 12,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}