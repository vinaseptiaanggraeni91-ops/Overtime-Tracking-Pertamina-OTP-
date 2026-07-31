// lib/core/services/network_service.dart
// 🔥 NETWORK CONNECTIVITY SERVICE - FIXED VERSION

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// NETWORK STATUS ENUM
// ═══════════════════════════════════════════════════════════════

enum NetworkStatus {
  online,
  offline,
  unstable,
}

// ═══════════════════════════════════════════════════════════════
// NETWORK SERVICE (SINGLETON)
// ═══════════════════════════════════════════════════════════════

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();

  // ═══════════════════════════════════════════════════════════
  // STREAMS & CONTROLLERS
  // ═══════════════════════════════════════════════════════════

  final _statusController = StreamController<NetworkStatus>.broadcast();
  final _isOnlineController = StreamController<bool>.broadcast();
  final _showPopupController = StreamController<bool>.broadcast();

  // Public streams
  Stream<NetworkStatus> get statusStream => _statusController.stream;
  Stream<bool> get isOnlineStream => _isOnlineController.stream;
  Stream<bool> get showPopupStream => _showPopupController.stream;
  
  // 🔥 ALIAS UNTUK KOMPATIBILITAS DENGAN AUTH_SERVICE.DART
  Stream<bool> get connectionStream => _isOnlineController.stream;

  // ═══════════════════════════════════════════════════════════
  // CURRENT STATE
  // ═══════════════════════════════════════════════════════════

  NetworkStatus _currentStatus = NetworkStatus.online;
  NetworkStatus get currentStatus => _currentStatus;
  bool get isOnline => _currentStatus != NetworkStatus.offline;
  bool get isOffline => _currentStatus == NetworkStatus.offline;

  // ═══════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════

  Future<void> _init() async {
    // Cek status awal
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results.first);

    // Listen perubahan koneksi
    _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results.first);
    });

    // 🔥 TIDAK PERLU PING CHECKER - HANYA ANDALKAN CONNECTIVITY PLUS
    debugPrint('✅ NetworkService initialized | Status: $_currentStatus');
  }

  // ═══════════════════════════════════════════════════════════
  // UPDATE STATUS
  // ═══════════════════════════════════════════════════════════

  void _updateStatus(ConnectivityResult result) {
    NetworkStatus newStatus;

    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
      case ConnectivityResult.mobile:
      case ConnectivityResult.vpn:
      case ConnectivityResult.bluetooth:
        newStatus = NetworkStatus.online;
        break;
      case ConnectivityResult.none:
        newStatus = NetworkStatus.offline;
        break;
      default:
        newStatus = NetworkStatus.online;
    }

    if (newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _statusController.add(_currentStatus);
      _isOnlineController.add(isOnline);

      debugPrint('📶 Network status changed: $_currentStatus');

      // Tampilkan/sembunyikan popup
      _handlePopupState();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // POPUP MANAGEMENT
  // ═══════════════════════════════════════════════════════════

  Timer? _debounceTimer;
  bool _popupShown = false;

  void _handlePopupState() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final shouldShow = !isOnline;

      if (shouldShow && !_popupShown) {
        _popupShown = true;
        _showPopupController.add(true);
      } else if (!shouldShow && _popupShown) {
        _popupShown = false;
        _showPopupController.add(false);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // MANUAL CHECK (TANPA PING - HANYA CEK CONNECTIVITY PLUS)
  // ═══════════════════════════════════════════════════════════

  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      
      // Update status berdasarkan hasil check
      if (online && _currentStatus == NetworkStatus.offline) {
        _currentStatus = NetworkStatus.online;
        _statusController.add(_currentStatus);
        _isOnlineController.add(true);
      } else if (!online && _currentStatus != NetworkStatus.offline) {
        _currentStatus = NetworkStatus.offline;
        _statusController.add(_currentStatus);
        _isOnlineController.add(false);
      }
      
      return online;
    } catch (e) {
      debugPrint('Check connection error: $e');
      return isOnline;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // RETRY HELPER
  // ═══════════════════════════════════════════════════════════

  Future<T?> retryOnConnectionError<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        if (!isOnline) {
          await Future.delayed(delay);
          continue;
        }
        return await operation();
      } catch (e) {
        debugPrint('⚠️ Retry ${i + 1}/$maxRetries failed: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(delay * (i + 1));
        }
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════

  void dispose() {
    _debounceTimer?.cancel();
    _statusController.close();
    _isOnlineController.close();
    _showPopupController.close();
  }
}