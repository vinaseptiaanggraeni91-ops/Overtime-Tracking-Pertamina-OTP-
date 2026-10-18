// lib/widgets/absensi/action_buttons.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionButtons extends StatelessWidget {
  final bool locationValid;
  final bool hasSelfie;
  final bool isSubmitting;
  final bool isTakingPhoto;
  final bool isLoadingLocation;
  final bool hasAttemptedRetry;
  final VoidCallback onVerifyLocation;
  final VoidCallback onTakeSelfie;
  final VoidCallback onSubmit;

  const ActionButtons({
    super.key,
    required this.locationValid,
    required this.hasSelfie,
    required this.isSubmitting,
    required this.isTakingPhoto,
    required this.isLoadingLocation,
    required this.hasAttemptedRetry,
    required this.onVerifyLocation,
    required this.onTakeSelfie,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;

    if (!locationValid) {
      return _ActionButton(
        text: hasAttemptedRetry ? '🔄 Coba Lagi' : '📍 Verifikasi Lokasi',
        icon: Icons.refresh,
        color: Colors.orange,
        isLoading: isLoadingLocation,
        onTap: onVerifyLocation,
        isSmall: isSmall,
      );
    }

    if (!hasSelfie) {
      return _ActionButton(
        text: '📸 Ambil Selfie',
        icon: Icons.camera_alt,
        color: const Color(0xFF1976D2),
        isLoading: isTakingPhoto,
        onTap: onTakeSelfie,
        isSmall: isSmall,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          text: '✅ Submit Absensi',
          icon: Icons.check_circle,
          color: Colors.green,
          isLoading: isSubmitting,
          onTap: onSubmit,
          isSmall: isSmall,
        ),
        if (!isSubmitting) ...[
          const SizedBox(height: 8),
          _ActionButton(
            text: '📸 Ambil Ulang',
            icon: Icons.refresh,
            color: Colors.grey.shade700,
            isLoading: isTakingPhoto,
            onTap: onTakeSelfie,
            isSmall: isSmall,
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;
  final bool isSmall;

  const _ActionButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: isSmall ? 46 : 54,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(
          isLoading ? 'Memproses...' : text,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: isSmall ? 12 : 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}