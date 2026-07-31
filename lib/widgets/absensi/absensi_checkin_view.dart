// lib/screens/absensi/widgets/absensi_checkin_view.dart

import 'package:flutter/material.dart';

import '/dashboard/mitra/absensi_state.dart';
import '/widgets/absensi/absensi_workflow.dart';
import '/widgets/absensi/shared/overtime_info_card.dart';

class AbsensiCheckinView extends StatelessWidget {
  final AbsensiState state;
  final AbsensiWorkflow workflow;

  const AbsensiCheckinView({
    super.key,
    required this.state,
    required this.workflow,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    final hp = MediaQuery.of(context).size.width * 0.04;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 24),
      child: Column(
        children: [
          // ── INFO CARD ──
          OvertimeInfoCard(
            overtimeItem: state.overtimeItem!,
            isLateOvertime: state.isLateOvertime,
          ),
          
          const SizedBox(height: 20),
          
          // ── STEP INDICATOR ──
          _StepIndicator(
            isLocationValid: state.locationValid,
            hasSelfie: state.capturedImage != null,
            isSmall: isSmall,
          ),
          
          const SizedBox(height: 24),
          
          // ── STATUS CARD (Verifikasi Lokasi) ──
          _LocationStatusCard(
            isSmall: isSmall,
            isLoadingLocation: state.isLoadingLocation,
            locationValid: state.locationValid,
            statusMessage: state.statusMessage,
            errorDetail: state.errorDetail,
            currentPosition: state.currentPosition,
            distanceInMeters: state.distanceInMeters,
          ),
          
          const SizedBox(height: 20),
          
          // ── PHOTO PREVIEW ──
          if (state.previewFile != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Image.file(state.previewFile!, height: isSmall ? 200 : 260, width: double.infinity, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: state.isSubmitting ? null : () => state.takePhoto(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // ── ACTION BUTTONS ──
          if (!state.locationValid)
            _ActionButton(
              label: '📍 Verifikasi Lokasi',
              icon: Icons.refresh,
              color: Colors.orange,
              isLoading: state.isLoadingLocation,
              onTap: () => state.verifyLocation(),
              isSmall: isSmall,
            )
          else if (state.capturedImage == null)
            _ActionButton(
              label: '📸 Ambil Selfie',
              icon: Icons.camera_alt,
              color: const Color(0xFF1976D2),
              isLoading: state.isTakingPhoto,
              onTap: () => state.takePhoto(),
              isSmall: isSmall,
            )
          else
            _ActionButton(
              label: '✅ Submit Absensi',
              icon: Icons.check_circle,
              color: Colors.green,
              isLoading: state.isSubmitting,
              onTap: () => workflow.submitCheckIn(),
              isSmall: isSmall,
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════
// STEP INDICATOR WIDGET
// ═════════════════════════════════════════════
class _StepIndicator extends StatelessWidget {
  final bool isLocationValid;
  final bool hasSelfie;
  final bool isSmall;

  const _StepIndicator({
    required this.isLocationValid,
    required this.hasSelfie,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Step(
          number: '1',
          label: 'Lokasi',
          isDone: isLocationValid,
          isActive: !isLocationValid,
          isSmall: isSmall,
        ),
        _StepDivider(isDone: isLocationValid, isSmall: isSmall),
        _Step(
          number: '2',
          label: 'Selfie',
          isDone: hasSelfie,
          isActive: isLocationValid && !hasSelfie,
          isSmall: isSmall,
        ),
        _StepDivider(isDone: hasSelfie, isSmall: isSmall),
        _Step(
          number: '3',
          label: 'Submit',
          isDone: false,
          isActive: hasSelfie,
          isSmall: isSmall,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String label;
  final bool isDone;
  final bool isActive;
  final bool isSmall;

  const _Step({
    required this.number,
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? Colors.green
        : isActive
            ? const Color(0xFF1976D2)
            : Colors.grey.shade300;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: isSmall ? 15 : 18,
          backgroundColor: color,
          child: isDone
              ? Icon(Icons.check, color: Colors.white, size: isSmall ? 15 : 18)
              : Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color),
        ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  final bool isDone;
  final bool isSmall;

  const _StepDivider({required this.isDone, required this.isSmall});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: EdgeInsets.only(bottom: isSmall ? 18 : 20),
        color: isDone ? Colors.green : Colors.grey.shade300,
      ),
    );
  }
}

// ═════════════════════════════════════════════
// LOCATION STATUS CARD
// ═════════════════════════════════════════════
class _LocationStatusCard extends StatelessWidget {
  final bool isSmall;
  final bool isLoadingLocation;
  final bool locationValid;
  final String statusMessage;
  final String? errorDetail;
  final dynamic currentPosition;
  final double? distanceInMeters;

  const _LocationStatusCard({
    required this.isSmall,
    required this.isLoadingLocation,
    required this.locationValid,
    required this.statusMessage,
    this.errorDetail,
    this.currentPosition,
    this.distanceInMeters,
  });

  @override
  Widget build(BuildContext context) {
    final bg = locationValid
        ? Colors.green.withValues(alpha: 0.08)
        : Colors.orange.withValues(alpha: 0.08);

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: locationValid
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoadingLocation)
            const CircularProgressIndicator()
          else
            Icon(
              locationValid ? Icons.check_circle : Icons.location_off,
              size: 42,
              color: locationValid ? Colors.green : Colors.orange,
            ),
          const SizedBox(height: 12),
          Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          if (errorDetail != null) ...[
            const SizedBox(height: 8),
            Text(
              errorDetail!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.red),
            ),
          ],
          if (currentPosition != null) ...[
            const SizedBox(height: 12),
            Text(
              '${currentPosition.latitude.toStringAsFixed(6)}, ${currentPosition.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
          if (distanceInMeters != null)
            Text(
              'Jarak: ${distanceInMeters!.toStringAsFixed(0)}m',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════
// ACTION BUTTON
// ═════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;
  final bool isSmall;

  const _ActionButton({
    required this.label,
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
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(
          isLoading ? 'Memproses...' : label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}