// lib/widgets/log/log_empty_state.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LogEmptyState extends StatelessWidget {
  final Color accentBlue;
  final VoidCallback onRefresh;

  const LogEmptyState({
    super.key,
    required this.accentBlue,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🔥 ICON lebih kecil
              Icon(
                Icons.list_alt, 
                size: 60, // 80 -> 60
                color: Colors.grey[300],
              ),
              const SizedBox(height: 12), // 16 -> 12
              
              Text(
                'Tidak ada log ditemukan',
                style: GoogleFonts.poppins(
                  fontSize: 16, // 18 -> 16
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6), // 8 -> 6
              
              Text(
                'Coba ubah filter atau cari dengan kata kunci lain',
                style: GoogleFonts.poppins(
                  fontSize: 11, // 12 -> 11
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16), // 24 -> 16
              
              // 🔥 BUTTON lebih kecil
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'Refresh Data',
                  style: TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  minimumSize: const Size(120, 36),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}