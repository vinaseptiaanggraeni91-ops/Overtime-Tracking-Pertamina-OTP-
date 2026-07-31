// lib/screens/absensi/widgets/shared/live_location_banner.dart

import 'package:flutter/material.dart';

class LiveLocationBanner extends StatelessWidget {
  final String duration;
  final VoidCallback onStop;

  const LiveLocationBanner({
    super.key,
    required this.duration,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF00C853), Color(0xFF00E676)]),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (_, value, __) => Container(
              width: 10 * value,
              height: 10 * value,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🟢 Live Location Aktif', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text('Durasi: $duration', style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showStopDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.stop_circle, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Stop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStopDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hentikan Live Location?'),
        content: const Text('Live location akan berhenti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onStop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hentikan'),
          ),
        ],
      ),
    );
  }
}