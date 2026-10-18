// lib/widgets/absensi/status_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusCard extends StatelessWidget {
  final bool isLoading;
  final bool locationValid;
  final String statusMessage;
  final String? errorDetail;
  final VoidCallback onVerify;

  const StatusCard({
    super.key,
    required this.isLoading,
    required this.locationValid,
    required this.statusMessage,
    this.errorDetail,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    final bg = locationValid
        ? Colors.green.withOpacity(0.08)
        : Colors.orange.withOpacity(0.08);

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: locationValid
              ? Colors.green.withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const CircularProgressIndicator(color: Color(0xFF1A237E))
          else
            Icon(
              locationValid ? Icons.check_circle : Icons.location_off,
              size: 42,
              color: locationValid ? Colors.green : Colors.orange,
            ),
          SizedBox(height: 12),
          Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: isSmall ? 12 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (errorDetail != null) ...[
            SizedBox(height: 8),
            Text(
              errorDetail!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: isSmall ? 10 : 11,
                color: Colors.red.shade700,
              ),
            ),
          ],
          if (!locationValid && !isLoading) ...[
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onVerify,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Verifikasi Lokasi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}