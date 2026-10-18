// lib/core/services/live_location_service.dart
// 🔥 FINAL VERSION - DILENGKAPI NETWORK MONITORING

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '/core/services/network_service.dart'; // 🔥 NETWORK SERVICE

/// Model data lokasi terbaru
class LiveLocationData {
  final String userId;
  final String userName;
  final String? userRole;
  final String? userFungsi;
  final String? lemburId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final double? batteryLevel;
  final bool isActive;
  final String? address;

  LiveLocationData({
    required this.userId,
    required this.userName,
    this.userRole,
    this.userFungsi,
    this.lemburId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.batteryLevel,
    this.isActive = true,
    this.address,
  });

  factory LiveLocationData.fromMap(Map<String, dynamic> map) {
    return LiveLocationData(
      userId: map['user_id'] as String? ?? '',
      userName: map['user_name'] as String? ?? 'Unknown',
      userRole: map['user_role'] as String?,
      userFungsi: map['user_fungsi'] as String?,
      lemburId: map['lembur_id'] as String?,
      latitude: (map['latitude'] ?? map['last_lat'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? map['last_lng'] ?? 0).toDouble(),
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : map['last_update'] is Timestamp
              ? (map['last_update'] as Timestamp).toDate()
              : DateTime.now(),
      accuracy: (map['accuracy'] ?? map['last_accuracy'] as num?)?.toDouble(),
      altitude: (map['altitude'] ?? map['last_altitude'] as num?)?.toDouble(),
      speed: (map['speed'] ?? map['last_speed'] as num?)?.toDouble(),
      heading: (map['heading'] ?? map['last_heading'] as num?)?.toDouble(),
      batteryLevel: (map['battery_level'] as num?)?.toDouble(),
      isActive: map['is_active'] as bool? ?? true,
      address: map['address'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'user_name': userName,
    'user_role': userRole,
    'user_fungsi': userFungsi,
    'lembur_id': lemburId,
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': Timestamp.fromDate(timestamp),
    'accuracy': accuracy,
    'altitude': altitude,
    'speed': speed,
    'heading': heading,
    'battery_level': batteryLevel,
    'is_active': isActive,
    'address': address,
  };
}

class LiveLocationService extends ChangeNotifier {
  static final LiveLocationService _instance = LiveLocationService._internal();
  factory LiveLocationService() => _instance;
  LiveLocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;
  
  // 🔥 NETWORK SERVICE
  final NetworkService _networkService = NetworkService();

  // ═══════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserRole;
  String? _currentUserFungsi;
  String? _currentOvertimeId;
  String? _currentLemburId;
  bool _isTracking = false;

  // ═══════════════════════════════════════════════════════
  // VIEWER STATE
  // ═══════════════════════════════════════════════════════
  Map<String, LiveLocationData> _latestLocations = {};
  StreamSubscription<dynamic>? _listener;
  bool _isListening = false;

  // ═══════════════════════════════════════════════════════
  // TIMERS
  // ═══════════════════════════════════════════════════════
  Timer? _trackingTimer;
  Timer? _autoStopTimer;
  int _intervalSeconds = 60;

  bool _isDisposed = false;

  // 🔥 Network state
  bool _isNetworkPaused = false;
  int _failedSendCount = 0;
  static const int _maxFailedBeforePause = 5;

  // ═══════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════
  bool get isTracking => _isTracking;
  bool get isListening => _isListening;
  Map<String, LiveLocationData> get latestLocations => _latestLocations;
  String? get currentOvertimeId => _currentOvertimeId;
  String? get currentUserId => _currentUserId;
  String? get currentLemburId => _currentLemburId;
  
  // 🔥 Network getters
  bool get isOnline => _networkService.isOnline;
  bool get isNetworkPaused => _isNetworkPaused;
  int get failedSendCount => _failedSendCount;

  // ═══════════════════════════════════════════════════════
  // 🔥 NETWORK CHECK HELPER
  // ═══════════════════════════════════════════════════════

  bool _checkConnection(String operationName) {
    if (!_networkService.isOnline) {
      debugPrint('⚠️ [$operationName] Dibatalkan - Tidak ada koneksi internet');
      return false;
    }
    return true;
  }

  // ═══════════════════════════════════════════════════════
  // SAFE NOTIFY
  // ═══════════════════════════════════════════════════════
  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  // ═══════════════════════════════════════════════════════
  // CORE: START LIVE TRACKING
  // Document ID = userId (bukan lemburId)
  // ═══════════════════════════════════════════════════════
  Future<bool> startLiveTracking({
    required String userId,
    required String userName,
    required String lemburId,
    int intervalSeconds = 60,
    String userRole = 'mitra',
    String? userFungsi,
  }) async {
    try {
      // 🔥 Cek koneksi sebelum mulai
      if (!_checkConnection('startLiveTracking')) {
        debugPrint('❌ LiveLocationService: Tidak bisa mulai tracking - OFFLINE');
        return false;
      }

      // Hentikan tracking sebelumnya
      await stopLiveTracking();

      // Set state
      _currentUserId = userId;
      _currentUserName = userName;
      _currentUserRole = userRole;
      _currentUserFungsi = userFungsi;
      _currentOvertimeId = lemburId;
      _currentLemburId = lemburId;
      _intervalSeconds = intervalSeconds.clamp(10, 300);
      _isTracking = true;
      _isNetworkPaused = false;
      _failedSendCount = 0;
      _safeNotify();

      debugPrint('═══════════════════════════════════════');
      debugPrint('🟢 LiveLocationService: START TRACKING');
      debugPrint('   User: $userName ($userId)');
      debugPrint('   Lembur ID: $lemburId');
      debugPrint('   Interval: $intervalSeconds detik');
      debugPrint('   Document ID: $userId');
      debugPrint('   Network: ONLINE');
      debugPrint('═══════════════════════════════════════');

      // Kirim posisi awal segera
      await _sendCurrentLocation();

      // Timer periodik untuk kirim lokasi
      _trackingTimer?.cancel();
      _trackingTimer = Timer.periodic(
        Duration(seconds: _intervalSeconds),
        (_) => _sendCurrentLocation(),
      );

      return true;
    } catch (e) {
      debugPrint('❌ LiveLocationService: Gagal start tracking: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // CORE: STOP LIVE TRACKING
  // ═══════════════════════════════════════════════════════
  Future<void> stopLiveTracking() async {
    if (_isDisposed) return;

    debugPrint('🔴 LiveLocationService: STOP TRACKING untuk $_currentUserId');

    // Hentikan timer
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    // Update Firestore: set is_active = false
    if (_currentUserId != null) {
      try {
        await _firestore
            .collection('live_locations')
            .doc(_currentUserId!)
            .update({
          'is_active': false,
          'stopped_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Status is_active=false disimpan');
      } catch (e) {
        debugPrint('⚠️ Gagal update status (update), coba set merge: $e');
        try {
          await _firestore
              .collection('live_locations')
              .doc(_currentUserId!)
              .set({
            'is_active': false,
            'stopped_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('✅ Status is_active=false disimpan (fallback set)');
        } catch (e2) {
          debugPrint('❌ Gagal total update status: $e2');
        }
      }
    }

    // Reset state
    _currentUserId = null;
    _currentUserName = null;
    _currentUserRole = null;
    _currentUserFungsi = null;
    _currentOvertimeId = null;
    _currentLemburId = null;
    _isTracking = false;
    _isNetworkPaused = false;
    _failedSendCount = 0;
    _safeNotify();
  }

  // ═══════════════════════════════════════════════════════
  // SEND CURRENT LOCATION
  // ═══════════════════════════════════════════════════════
  Future<void> _sendCurrentLocation() async {
    if (_isDisposed || !_isTracking || _currentUserId == null) return;

    // 🔥 Cek network pause
    if (_isNetworkPaused) {
      debugPrint('📴 Network paused, skip pengiriman lokasi (failed: $_failedSendCount)');
      return;
    }

    // 🔥 Cek koneksi
    if (!_networkService.isOnline) {
      debugPrint('📴 Offline, skip pengiriman lokasi');
      _failedSendCount++;
      
      if (_failedSendCount >= _maxFailedBeforePause) {
        _isNetworkPaused = true;
        debugPrint('⏸️ Network paused setelah $_maxFailedBeforePause kali gagal');
        _safeNotify();
      }
      
      return;
    }

    try {
      // Cek GPS
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ GPS tidak aktif, skip pengiriman lokasi');
        return;
      }

      // Cek permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // Dapatkan posisi
      final position = await _geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // 🔥 Re-check state SETELAH await getCurrentPosition().
      // Kenapa perlu: getCurrentPosition() bisa makan waktu sampai 10 detik,
      // dan selama itu stopLiveTracking() bisa saja dipanggil dari flow lain
      // (misal: overtime sudah expired), yang men-null-kan _currentUserId.
      // Tanpa re-check ini, _currentUserId! di bawah bisa crash dengan
      // "Null check operator used on a null value".
      if (_isDisposed || !_isTracking || _currentUserId == null) {
        debugPrint('⚠️ Tracking sudah dihentikan saat proses ambil lokasi, batalkan pengiriman');
        return;
      }

      // 🔥 Cek ulang koneksi sebelum simpan ke Firestore
      if (!_networkService.isOnline) {
        debugPrint('📴 Offline saat mau simpan, cache lokal dulu');
        // Bisa tambah cache lokal di sini
        _failedSendCount++;
        return;
      }

      // Simpan ke Firestore dengan document ID = userId
      final docRef = _firestore.collection('live_locations').doc(_currentUserId!);

      await docRef.set({
        'user_id': _currentUserId,
        'user_name': _currentUserName,
        'user_role': _currentUserRole,
        'user_fungsi': _currentUserFungsi,
        'lembur_id': _currentLemburId,
        'overtime_id': _currentOvertimeId,
        'last_update': FieldValue.serverTimestamp(),
        'last_lat': position.latitude,
        'last_lng': position.longitude,
        'last_accuracy': position.accuracy,
        'last_altitude': position.altitude,
        'last_speed': position.speed,
        'last_heading': position.heading,
        'is_active': true,
        'address': '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 🔥 Reset counter saat berhasil
      if (_failedSendCount > 0) {
        debugPrint('✅ Lokasi berhasil dikirim setelah $_failedSendCount kali gagal');
      }
      _failedSendCount = 0;
      _isNetworkPaused = false;
      
      debugPrint('📍 Lokasi: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
    } catch (e) {
      debugPrint('❌ Gagal mengirim lokasi: $e');
      
      // 🔥 Cek network error
      if (e.toString().contains('SocketException') || 
          e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        _failedSendCount++;
        debugPrint('📴 Network error (${_failedSendCount}/$_maxFailedBeforePause)');
        
        if (_failedSendCount >= _maxFailedBeforePause) {
          _isNetworkPaused = true;
          debugPrint('⏸️ Network paused setelah $_maxFailedBeforePause kali gagal');
          _safeNotify();
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // COMPATIBILITY METHODS (OLD API)
  // ═══════════════════════════════════════════════════════
  Future<void> startTracking({
    required String userId,
    required String userName,
    required String overtimeId,
    required String lemburId,
    String userRole = 'mitra',
    String? userFungsi,
  }) async {
    await startLiveTracking(
      userId: userId,
      userName: userName,
      lemburId: lemburId,
      userRole: userRole,
      userFungsi: userFungsi,
    );
  }

  Future<void> stopTracking() async {
    await stopLiveTracking();
  }

  // ═══════════════════════════════════════════════════════
  // VALIDASI LOKASI
  // ═══════════════════════════════════════════════════════
  Future<Map<String, dynamic>> validateLocation({
    required double targetLat,
    required double targetLng,
    double radiusMeter = 100, // 🔥 Default 100m lebih ketat
  }) async {
    try {
      // 🔥 Cek koneksi
      if (!_networkService.isOnline) {
        return {
          'valid': false,
          'message': '❌ Tidak ada koneksi internet. Tidak dapat memvalidasi lokasi.',
          'distance': null,
          'max_radius': radiusMeter,
        };
      }

      // Cek permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {
            'valid': false,
            'message': '❌ Izin lokasi ditolak. Aktifkan GPS dan izin lokasi.',
            'distance': null,
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'valid': false,
          'message': '❌ Izin lokasi ditolak permanen. Buka pengaturan aplikasi.',
          'distance': null,
        };
      }

      // Cek GPS
      bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        return {
          'valid': false,
          'message': '❌ GPS tidak aktif. Harap nyalakan GPS.',
          'distance': null,
        };
      }

      // Dapatkan posisi
      final position = await _geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Hitung jarak
      final distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLat,
        targetLng,
      );

      final isValid = distanceInMeters <= radiusMeter;

      return {
        'valid': isValid,
        'message': isValid
            ? '✅ Lokasi valid (${distanceInMeters.toStringAsFixed(0)}m dari lokasi, max: ${radiusMeter.toStringAsFixed(0)}m)'
            : '❌ Anda di luar area lembur (${distanceInMeters.toStringAsFixed(0)}m, max: ${radiusMeter.toStringAsFixed(0)}m)',
        'distance': distanceInMeters,
        'max_radius': radiusMeter,
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      return {
        'valid': false,
        'message': '❌ Gagal validasi lokasi: ${e.toString()}',
        'distance': null,
        'max_radius': radiusMeter,
      };
    }
  }

  // ═══════════════════════════════════════════════════════
  // LISTENERS
  // ═══════════════════════════════════════════════════════

  /// Listener untuk admin/pengawas - semua lokasi aktif
  void listenToAllActiveLocations() {
    if (_isDisposed) return;
    _stopListener();

    // 🔥 Cek koneksi sebelum listen
    if (!_networkService.isOnline) {
      debugPrint('⚠️ Offline - listener akan mulai saat online');
      // Listener tetap di-set, Firestore SDK akan handle reconnect
    }

    _listener = _firestore
        .collection('live_locations')
        .where('is_active', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (_isDisposed) return;

      _latestLocations.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('last_lat') || data.containsKey('latitude')) {
          _latestLocations[doc.id] = LiveLocationData.fromMap(data);
        }
      }
      _isListening = true;
      _safeNotify();
    }, onError: (error) {
      if (_isDisposed) return;
      
      // 🔥 Handle network error di listener
      if (error.toString().contains('network') || error.toString().contains('SocketException')) {
        debugPrint('⚠️ Listener network error (akan reconnect otomatis): $error');
      } else {
        debugPrint('❌ Error stream lokasi admin: $error');
      }
    });
  }

  /// Listener untuk mitra - hanya dokumen sendiri
  void listenToOwnLocation(String userId) {
    if (_isDisposed) return;
    _stopListener();

    _listener = _firestore
        .collection('live_locations')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (_isDisposed) return;

      if (doc.exists) {
        final data = doc.data()!;
        _latestLocations[doc.id] = LiveLocationData.fromMap(data);
        _isListening = true;
        _safeNotify();
      }
    }, onError: (error) {
      if (_isDisposed) return;
      
      if (error.toString().contains('network') || error.toString().contains('SocketException')) {
        debugPrint('⚠️ Listener network error (akan reconnect otomatis): $error');
      } else {
        debugPrint('❌ Error stream lokasi sendiri: $error');
      }
    });
  }

  /// Listener untuk overtime tertentu (subcollection updates)
  void listenToOvertime(String overtimeId) {
    if (_isDisposed) return;
    _stopListener();

    _listener = _firestore
        .collection('live_locations')
        .doc(overtimeId)
        .collection('updates')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      if (_isDisposed) return;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['user_id'] as String?;
        if (userId == null) continue;

        final loc = LiveLocationData.fromMap(data);

        if (!_latestLocations.containsKey(userId) ||
            loc.timestamp.isAfter(_latestLocations[userId]!.timestamp)) {
          _latestLocations[userId] = loc;
        }
      }
      _isListening = true;
      _safeNotify();
    });
  }

  void _stopListener() {
    _listener?.cancel();
    _listener = null;
    _isListening = false;
  }

  void stopListening() {
    if (_isDisposed) return;
    _stopListener();
    _latestLocations.clear();
    _safeNotify();
  }

  // ═══════════════════════════════════════════════════════
  // HISTORY
  // ═══════════════════════════════════════════════════════
  Future<List<LiveLocationData>> getLocationHistory(
    String overtimeId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    if (_isDisposed) return [];

    // 🔥 Cek koneksi
    if (!_checkConnection('getLocationHistory')) return [];

    try {
      var query = _firestore
          .collection('live_locations')
          .doc(overtimeId)
          .collection('updates')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startTime != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startTime));
      }
      if (endTime != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endTime));
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => LiveLocationData.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Gagal ambil history lokasi: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════
  // AUTO-STOP
  // ═══════════════════════════════════════════════════════
  void scheduleAutoStop(DateTime jamSelesai) {
    if (_isDisposed) return;

    _autoStopTimer?.cancel();
    final delay = jamSelesai.difference(DateTime.now());
    
    if (delay.isNegative) {
      debugPrint('⏰ Jam selesai sudah lewat, langsung hentikan');
      stopTracking();
      return;
    }

    _autoStopTimer = Timer(delay, () {
      if (_isDisposed) return;
      debugPrint('⏰ Auto-stop tracking: jam selesai tercapai');
      stopTracking();
    });

    debugPrint('⏰ Auto-stop dijadwalkan dalam ${delay.inMinutes} menit');
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 RESUME NETWORK (UNTUK LIVE LOCATION MANAGER)
  // ═══════════════════════════════════════════════════════

  /// Dipanggil saat koneksi pulih untuk melanjutkan pengiriman
  void resumeAfterNetworkRestored() {
    if (_isDisposed || !_isTracking) return;
    
    if (_isNetworkPaused) {
      debugPrint('📶 Network restored - Melanjutkan pengiriman lokasi');
      _isNetworkPaused = false;
      _failedSendCount = 0;
      _safeNotify();
      
      // 🔥 Langsung kirim lokasi
      _sendCurrentLocation();
    }
  }

  // ═══════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════
  @override
  void dispose() {
    _isDisposed = true;

    _autoStopTimer?.cancel();
    _trackingTimer?.cancel();
    _listener?.cancel();

    _autoStopTimer = null;
    _trackingTimer = null;
    _listener = null;

    _latestLocations.clear();
    _isTracking = false;
    _isListening = false;
    _currentUserId = null;
    _currentUserName = null;
    _currentUserRole = null;
    _currentUserFungsi = null;
    _currentOvertimeId = null;
    _currentLemburId = null;
    _isNetworkPaused = false;
    _failedSendCount = 0;

    super.dispose();
  }
}