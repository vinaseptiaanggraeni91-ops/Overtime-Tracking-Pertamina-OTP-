// lib/widgets/absensi/step_indicator.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StepIndicator extends StatelessWidget {
  final bool locationValid;
  final bool hasSelfie;
  final bool isSubmitting;

  const StepIndicator({
    super.key,
    required this.locationValid,
    required this.hasSelfie,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;

    return Row(
      children: [
        Expanded(
          child: _Step(
            number: '1',
            label: 'Lokasi',
            done: locationValid,
            active: false,
            isSmall: isSmall,
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: EdgeInsets.only(bottom: isSmall ? 18 : 20),
            color: locationValid ? Colors.green : Colors.grey.shade300,
          ),
        ),
        Expanded(
          child: _Step(
            number: '2',
            label: 'Selfie',
            done: hasSelfie,
            active: locationValid && !hasSelfie,
            isSmall: isSmall,
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: EdgeInsets.only(bottom: isSmall ? 18 : 20),
            color: hasSelfie ? Colors.green : Colors.grey.shade300,
          ),
        ),
        Expanded(
          child: _Step(
            number: '3',
            label: 'Submit',
            done: false,
            active: isSubmitting,
            isSmall: isSmall,
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String label;
  final bool done;
  final bool active;
  final bool isSmall;

  const _Step({
    required this.number,
    required this.label,
    required this.done,
    required this.active,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? Colors.green
        : active
            ? const Color(0xFF1976D2)
            : Colors.grey.shade300;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: isSmall ? 15 : 18,
          backgroundColor: color,
          child: done
              ? Icon(Icons.check, color: Colors.white, size: isSmall ? 15 : 18)
              : Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: done
                ? Colors.green
                : active
                    ? const Color(0xFF1976D2)
                    : Colors.grey,
          ),
        ),
      ],
    );
  }
}