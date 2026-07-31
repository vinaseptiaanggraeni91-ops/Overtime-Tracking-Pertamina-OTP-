// lib/core/widgets/network_popup.dart
// 🔥 NETWORK POPUP WIDGET - TAMPILAN KONEKSI TIDAK STABIL

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '/core/services/network_service.dart';

class NetworkPopup extends StatefulWidget {
  final Widget child;

  const NetworkPopup({
    super.key,
    required this.child,
  });

  @override
  State<NetworkPopup> createState() => _NetworkPopupState();
}

class _NetworkPopupState extends State<NetworkPopup> {
  final NetworkService _networkService = NetworkService();
  StreamSubscription<bool>? _popupSubscription;

  bool _showPopup = false;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();

    // Cek status awal
    _showPopup = !_networkService.isOnline;

    // Listen popup state
    _popupSubscription = _networkService.showPopupStream.listen((show) {
      if (mounted) {
        setState(() {
          _showPopup = show;
          if (!show && _wasOffline) {
            _wasOffline = false;
            _showConnectionRestored();
          }
          if (show) {
            _wasOffline = true;
          }
        });
      }
    });
  }

  void _showConnectionRestored() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text('Koneksi internet kembali normal'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _popupSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Network popup overlay
        if (_showPopup)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildPopup(),
          ),
      ],
    );
  }

  Widget _buildPopup() {
    final status = _networkService.currentStatus;

    String title;
    String message;
    IconData icon;
    Color backgroundColor;

    switch (status) {
      case NetworkStatus.offline:
        title = 'Tidak Ada Koneksi Internet';
        message = 'Periksa koneksi internet Anda dan coba lagi';
        icon = Icons.wifi_off_rounded;
        backgroundColor = Colors.red.shade600;
        break;
      case NetworkStatus.unstable:
        title = 'Koneksi Tidak Stabil';
        message = 'Koneksi internet Anda tidak stabil. Mohon tunggu...';
        icon = Icons.wifi_find_rounded;
        backgroundColor = Colors.orange.shade700;
        break;
      default:
        title = 'Memeriksa Koneksi...';
        message = 'Mohon tunggu sebentar';
        icon = Icons.wifi_rounded;
        backgroundColor = Colors.blue;
    }

    return Material(
      elevation: 8,
      shadowColor: backgroundColor.withOpacity(0.5),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          bottom: 16,
          left: 20,
          right: 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              backgroundColor,
              backgroundColor.withOpacity(0.8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // Icon dengan animasi pulse
              Icon(
                icon,
                color: Colors.white,
                size: 28,
              )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.15, 1.15),
                    duration: 800.ms,
                    curve: Curves.easeInOut,
                  ),

              const SizedBox(width: 14),

              // Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Retry button (untuk unstable)
              if (status == NetworkStatus.unstable) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 34,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final isConnected = await _networkService.checkConnection();
                      if (isConnected && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Koneksi tersedia!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Coba Lagi',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: backgroundColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],

              // Close button (opsional)
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  setState(() => _showPopup = false);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(
      begin: -1,
      end: 0,
      duration: 400.ms,
      curve: Curves.easeOutCubic,
    );
  }
}