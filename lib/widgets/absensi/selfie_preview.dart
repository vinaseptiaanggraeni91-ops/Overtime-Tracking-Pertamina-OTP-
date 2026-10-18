// lib/widgets/absensi/selfie_preview.dart
import 'dart:io';
import 'package:flutter/material.dart';

class SelfiePreview extends StatelessWidget {
  final File previewFile;
  final VoidCallback onRetake;

  const SelfiePreview({
    super.key,
    required this.previewFile,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Image.file(
            previewFile,
            height: isSmall ? 200 : 260,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRetake,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}