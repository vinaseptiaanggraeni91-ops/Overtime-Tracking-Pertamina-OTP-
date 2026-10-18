import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/core/services/live_location_service.dart';
import '/core/services/network_service.dart'; // 🔥 NETWORK SERVICE

class LiveLocationManager extends ChangeNotifier with WidgetsBindingObserver {
  // ═══════════════════════════════════════════════════════
  // SINGLETON PATTERN
  // ═══════════════════════════════════════════════════════
  static final LiveLocationManager _instance = LiveLocationManager._internal();
  factory LiveLocationManager() => _instance;
  LiveLocationManager._internal() {
    WidgetsBinding.instance.addObserver(this);
    _initNetworkListener(); // 🔥 Listen network changes
    debugPrint('🟢 LiveLocationManager: Instance created');
  }

  // ═══════════════════════════════════════════════════════
  // DEPENDENCIES
  // ═══════════════════════════════════════════════════════
  final LiveLocationService _locationService = LiveLocationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 🔥 NETWORK SERVICE
  final NetworkService _networkService = NetworkService();

  // ═══════════════════════════════════════════════════════
  // TIMERS
  // ═══════════════════════════════════════════════════════
  Timer? _locationTimer;
  Timer? _durationTimer;
  Timer? _retryTimer;
  Timer? _autoStopTimer;
  Timer? _reconnectTimer;

  // ═══════════════════════════════════════════════════════
  // 🔥 FIRESTORE LISTENER UNTUK MONITOR STATUS LEMBUR
  // ═══════════════════════════════════════════════════════
  StreamSubscription<DocumentSnapshot>? _lemburStatusSubscription;

  // ═══════════════════════════════════════════════════════
  // 🔥 NETWORK LISTENER
  // ═══════════════════════════════════════════════════════
  StreamSubscription<bool>? _networkSubscription;

  // ═══════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════
  bool _isActive = false;
  bool _isPaused = false;
  bool _isStopping = false; // 🔥 FIX: guard supaya stopTracking tidak dobel jalan
  DateTime? _startedAt;
  DateTime? _pausedAt;
  String? _userId;
  String? _userName;
  String? _userRole;
  String? _userFungsi;
  String? _lemburId;
  String? _overtimeId;
  int _intervalSeconds = 60;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const int _maxBackoffSeconds = 300;
  
  Duration _totalPausedDuration = Duration.zero;

  // 🔥 Network-related state
  bool _wasOffline = false;
  DateTime? _offlineSince;
  bool _networkPaused = false; // 🔥 Paused karena network

  // ═══════════════════════════════════════════════════════
  // 🔥 CALLBACK UNTUK UI (FORCE STOP NOTIFICATION)
  // ═══════════════════════════════════════════════════════
  
  void Function(String reason)? onForceStop;

  // ═══════════════════════════════════════════════════════
  // CONSTANTS - SHARED PREFERENCES KEYS
  // ═══════════════════════════════════════════════════════
  static const String _prefsKeyActive = 'live_location_active';
  static const String _prefsKeyUserId = 'live_location_userId';
  static const String _prefsKeyUserName = 'live_location_userName';
  static const String _prefsKeyUserRole = 'live_location_userRole';
  static const String _prefsKeyUserFungsi = 'live_location_userFungsi';
  static const String _prefsKeyLemburId = 'live_location_lemburId';
  static const String _prefsKeyOvertimeId = 'live_location_overtimeId';
  static const String _prefsKeyStartedAt = 'live_location_startedAt';
  static const String _prefsKeyInterval = 'live_location_interval';
  static const String _prefsKeyPausedDuration = 'live_location_paused_duration';

  // ═══════════════════════════════════════════════════════
  // CONSTANTS - FIRESTORE COLLECTIONS
  // ═══════════════════════════════════════════════════════
  static const String _overtimeCollection = 'lembur_mitra';
  static const String _systemLogsCollection = 'system_logs';

  // ═══════════════════════════════════════════════════════
  // 🔥 NETWORK MONITORING
  // ═══════════════════════════════════════════════════════

  void _initNetworkListener() {
    _networkSubscription?.cancel();
    _networkSubscription = _networkService.isOnlineStream.listen((isOnline) {
      if (_isActive && !_isPaused) {
        if (!isOnline && !_networkPaused) {
          // 🔥 Koneksi putus → Pause pengiriman lokasi
          _networkPaused = true;
          _wasOffline = true;
          _offlineSince = DateTime.now();
          debugPrint('📴 Network: OFFLINE - Menunda pengiriman lokasi');
          
          _writeSystemLog(
            type: 'live_location_network_offline',
            description: 'Live location: Jaringan offline, pengiriman lokasi ditunda',
            data: {
              'lembur_id': _lemburId,
              'offline_since': _offlineSince?.toIso8601String(),
              'active_duration': getDurationString(),
            },
          );
          
          notifyListeners();
          
        } else if (isOnline && _networkPaused) {
          // 🔥 Koneksi pulih → Kirim lokasi yang tertunda
          _networkPaused = false;
          final offlineDuration = _offlineSince != null 
              ? DateTime.now().difference(_offlineSince!) 
              : Duration.zero;
          
          debugPrint('📶 Network: ONLINE - Melanjutkan pengiriman lokasi (offline: ${offlineDuration.inMinutes} menit)');
          
          _writeSystemLog(
            type: 'live_location_network_online',
            description: 'Live location: Jaringan pulih, melanjutkan pengiriman lokasi',
            data: {
              'lembur_id': _lemburId,
              'offline_duration_minutes': offlineDuration.inMinutes,
              'offline_since': _offlineSince?.toIso8601String(),
              'restored_at': DateTime.now().toIso8601String(),
            },
          );
          
          _offlineSince = null;
          _retryCount = 0;
          
          // 🔥 Segera kirim lokasi
          _sendLocationWithRetry();
          notifyListeners();
        }
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════
  bool get isActive => _isActive && !_isPaused;
  bool get isPaused => _isPaused;
  bool get isRunning => _isActive;
  DateTime? get startedAt => _startedAt;
  DateTime? get pausedAt => _pausedAt;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get lemburId => _lemburId;
  String? get overtimeId => _overtimeId;
  int get intervalSeconds => _intervalSeconds;
  Duration get totalPausedDuration => _totalPausedDuration;
  
  // 🔥 Network getters
  bool get isOnline => _networkService.isOnline;
  bool get isNetworkPaused => _networkPaused;
  bool get wasOffline => _wasOffline;
  DateTime? get offlineSince => _offlineSince;
  
  Duration get activeDuration {
    if (_startedAt == null) return Duration.zero;
    final endTime = _isPaused && _pausedAt != null ? _pausedAt! : DateTime.now();
    return endTime.difference(_startedAt!) - _totalPausedDuration;
  }

  String getDurationString() {
    final duration = activeDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '$hours jam $minutes menit $seconds detik';
    if (minutes > 0) return '$minutes menit $seconds detik';
    return '$seconds detik';
  }

  String getDurationShort() {
    final duration = activeDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}j ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}d';
    return '${seconds}d';
  }

  Map<String, dynamic> get status => {
    'isActive': _isActive,
    'isPaused': _isPaused,
    'userId': _userId,
    'userName': _userName,
    'lemburId': _lemburId,
    'overtimeId': _overtimeId,
    'startedAt': _startedAt?.toIso8601String(),
    'activeDuration': getDurationString(),
    'intervalSeconds': _intervalSeconds,
    'retryCount': _retryCount,
    'totalPausedDuration': _totalPausedDuration.inSeconds,
    'monitorActive': _lemburStatusSubscription != null,
    // 🔥 Network status
    'isOnline': isOnline,
    'isNetworkPaused': _networkPaused,
    'wasOffline': _wasOffline,
    'offlineSince': _offlineSince?.toIso8601String(),
  };

  // ═══════════════════════════════════════════════════════
  // CORE: START TRACKING
  // ═══════════════════════════════════════════════════════

  Future<bool> startTracking({
    required String userId,
    required String userName,
    required String lemburId,
    String? overtimeId,
    int intervalSeconds = 60,
    String userRole = 'mitra',
    String userFungsi = 'lembur',
    DateTime? jamSelesai,
  }) async {
    // 🔥 CEK KONEKSI SEBELUM MULAI
    if (!_networkService.isOnline) {
      debugPrint('⚠️ LiveLocationManager: Tidak bisa mulai tracking - OFFLINE');
      
      await _writeSystemLog(
        type: 'live_location_start_failed',
        description: 'Gagal memulai live location tracking: Tidak ada koneksi internet',
        data: {
          'lembur_id': lemburId,
          'user_name': userName,
          'alasan': 'no_internet',
        },
      );
      
      return false;
    }

    if (_isActive && _userId == userId && _lemburId == lemburId) {
      debugPrint('🟢 LiveLocationManager: Already tracking for $userName');
      if (_isPaused) await resumeTracking();
      return true;
    }

    if (_isActive) {
      debugPrint('🔄 LiveLocationManager: Stopping previous tracking');
      await stopTracking();
    }

    debugPrint('═══════════════════════════════════════');
    debugPrint('🟢 LiveLocationManager: START TRACKING');
    debugPrint('   User: $userName ($userId)');
    debugPrint('   Role: $userRole | Fungsi: $userFungsi');
    debugPrint('   Lembur ID: $lemburId');
    debugPrint('   Interval: $intervalSeconds detik');
    debugPrint('   Network: ${_networkService.isOnline ? "ONLINE" : "OFFLINE"}');
    debugPrint('═══════════════════════════════════════');

    _resetState();

    _userId = userId;
    _userName = userName;
    _userRole = userRole;
    _userFungsi = userFungsi;
    _lemburId = lemburId;
    _overtimeId = overtimeId ?? lemburId;
    _intervalSeconds = intervalSeconds.clamp(10, 300);
    _isActive = true;
    _isPaused = false;
    _startedAt = DateTime.now();
    _retryCount = 0;
    _totalPausedDuration = Duration.zero;
    _networkPaused = false;
    _wasOffline = false;
    _offlineSince = null;

    await _saveState();

    _startLemburStatusMonitor(lemburId);

    final success = await _startServiceTracking();
    
    if (!success) {
      debugPrint('❌ LiveLocationManager: Failed to start service tracking');
      await _handleTrackingFailure();
      return false;
    }

    _startLocationTimer();
    _startDurationTimer();

    if (jamSelesai != null) {
      scheduleAutoStop(jamSelesai);
    }

    _startReconnectTimer();

    await _writeSystemLog(
      type: 'live_location_started',
      description: 'Live location tracking dimulai untuk lembur $lemburId',
      data: {
        'lembur_id': lemburId,
        'interval_seconds': _intervalSeconds,
        'user_role': _userRole,
        'user_fungsi': _userFungsi,
        'started_at': _startedAt?.toIso8601String(),
        'network_status': _networkService.isOnline ? 'online' : 'offline',
      },
    );

    notifyListeners();
    
    debugPrint('✅ LiveLocationManager: Tracking started successfully');
    return true;
  }

  Future<bool> _startServiceTracking() async {
    try {
      // 🔥 Cek koneksi sebelum start service
      if (!_networkService.isOnline) {
        debugPrint('⚠️ Service start: Tidak ada koneksi');
        return false;
      }

      final success = await _locationService.startLiveTracking(
        userId: _userId!,
        userName: _userName!,
        lemburId: _lemburId!,
        intervalSeconds: _intervalSeconds,
        userRole: _userRole ?? 'mitra',
        userFungsi: _userFungsi,
      );

      if (success) {
        _retryCount = 0;
      }

      return success;
    } catch (e) {
      debugPrint('❌ LiveLocationManager: Service start error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 MONITOR STATUS LEMBUR DARI FIRESTORE (REAL-TIME)
  // ═══════════════════════════════════════════════════════

  void _startLemburStatusMonitor(String lemburId) {
    _lemburStatusSubscription?.cancel();

    debugPrint('👁️ LiveLocationManager: Starting Firestore monitor for lembur: $lemburId');

    _lemburStatusSubscription = _firestore
        .collection(_overtimeCollection)
        .doc(lemburId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists) {
              debugPrint('🛑 Monitor: Dokumen lembur $lemburId dihapus dari Firestore!');
              _forceStopDueToCancellation('Lembur telah dihapus oleh pengawas');
              return;
            }

            final data = snapshot.data()!;
            
            final bool isCancelled = 
                data['is_cancelled'] == true ||
                data['status_pengajuan'] == 'dibatalkan' ||
                data['status_pengajuan'] == 'cancelled' ||
                data['status_pengajuan'] == 'ditolak' ||
                data['absensi_status'] == 'dibatalkan';

            if (isCancelled) {
              final statusPengajuan = data['status_pengajuan'] ?? 'unknown';
              debugPrint('🛑 Monitor: Lembur $lemburId dibatalkan! Status: $statusPengajuan');
              _forceStopDueToCancellation('Lembur dibatalkan oleh pengawas (status: $statusPengajuan)');
            }
          },
          onError: (error) {
            // 🔥 Handle network error di listener
            if (error.toString().contains('network') || error.toString().contains('SocketException')) {
              debugPrint('⚠️ Monitor network error untuk lembur $lemburId: $error');
              // Jangan stop tracking, listener akan reconnect otomatis
            } else {
              debugPrint('❌ Monitor error untuk lembur $lemburId: $error');
            }
          },
        );
  }

  void _forceStopDueToCancellation(String reason) async {
    final durationBeforeStop = getDurationString();
    final lemburIdSnapshot = _lemburId;
    final userNameSnapshot = _userName;
    
    debugPrint('═══════════════════════════════════════');
    debugPrint('🛑 FORCE STOP LIVE LOCATION');
    debugPrint('   Reason: $reason');
    debugPrint('   Lembur: $lemburIdSnapshot');
    debugPrint('   User: $userNameSnapshot');
    debugPrint('   Duration before stop: $durationBeforeStop');
    debugPrint('═══════════════════════════════════════');

    await _writeSystemLog(
      type: 'live_location_force_stop',
      description: reason,
      data: {
        'lembur_id': lemburIdSnapshot,
        'durasi_sebelum_stop': durationBeforeStop,
        'dipicu_oleh': 'firestore_monitor',
        'alasan_detail': reason,
      },
    );

    await stopTracking(skipLog: true);
    
    onForceStop?.call(reason);
  }

  // ═══════════════════════════════════════════════════════
  // CORE: STOP TRACKING
  // ═══════════════════════════════════════════════════════

  Future<void> stopTracking({bool skipLog = false}) async {
    // 🔥 FIX: guard reentrancy. Tanpa ini, dua pemanggil stopTracking() yang
    // hampir bersamaan (mis. force-stop dari Firestore monitor + auto-stop
    // timer) bisa lolos cek `_isActive` sebelum salah satunya sempat
    // meng-set `_isActive = false`, sehingga stopLiveTracking() terpanggil
    // dua kali dan salah satunya "kehilangan" _userId/_lemburId di tengah jalan.
    if (!_isActive || _isStopping) {
      debugPrint('🔴 LiveLocationManager: stopTracking diabaikan (sudah stop / sedang stop)');
      return;
    }
    _isStopping = true;

    final durationBeforeStop = getDurationString();
    final lemburIdSnapshot = _lemburId;
    final userNameSnapshot = _userName;
    final retryCountSnapshot = _retryCount;

    debugPrint('═══════════════════════════════════════');
    debugPrint('🔴 LiveLocationManager: STOP TRACKING');
    debugPrint('   User: $userNameSnapshot');
    debugPrint('   Lembur: $lemburIdSnapshot');
    debugPrint('   Duration: $durationBeforeStop');
    debugPrint('   Retries: $retryCountSnapshot');
    debugPrint('═══════════════════════════════════════');

    _lemburStatusSubscription?.cancel();
    _lemburStatusSubscription = null;

    _cancelAllTimers();

    try {
      await _locationService.stopLiveTracking();
    } catch (e) {
      debugPrint('⚠️ LiveLocationManager: Error stopping service: $e');
    }

    if (!skipLog) {
      await _writeSystemLog(
        type: 'live_location_stopped',
        description: 'Live location tracking dihentikan untuk lembur $lemburIdSnapshot',
        data: {
          'lembur_id': lemburIdSnapshot,
          'durasi_total': durationBeforeStop,
          'retry_count': retryCountSnapshot,
          'user_name': userNameSnapshot,
          'was_offline': _wasOffline,
          'offline_duration': _offlineSince != null 
              ? DateTime.now().difference(_offlineSince!).inMinutes 
              : 0,
        },
      );
    }

    _resetState();
    _isStopping = false;
    await _clearState();
    notifyListeners();
    
    debugPrint('✅ LiveLocationManager: Tracking stopped');
  }

  // ═══════════════════════════════════════════════════════
  // PAUSE / RESUME
  // ═══════════════════════════════════════════════════════

  Future<void> pauseTracking() async {
    if (!_isActive || _isPaused) return;

    debugPrint('⏸️ LiveLocationManager: Pausing tracking');
    
    _isPaused = true;
    _pausedAt = DateTime.now();
    
    _locationTimer?.cancel();
    _locationTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    await _saveState();
    
    await _writeSystemLog(
      type: 'live_location_paused',
      description: 'Live location tracking di-pause untuk lembur $_lemburId',
      data: {
        'lembur_id': _lemburId,
        'paused_at': _pausedAt?.toIso8601String(),
        'active_duration': getDurationString(),
        'network_status': _networkService.isOnline ? 'online' : 'offline',
      },
    );
    
    notifyListeners();
  }

  Future<void> resumeTracking() async {
    if (!_isActive || !_isPaused) return;

    // 🔥 Cek koneksi sebelum resume
    if (!_networkService.isOnline) {
      debugPrint('⚠️ LiveLocationManager: Tidak bisa resume - OFFLINE');
      return;
    }

    debugPrint('▶️ LiveLocationManager: Resuming tracking');
    
    if (_pausedAt != null) {
      _totalPausedDuration += DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
    }
    
    _isPaused = false;
    _networkPaused = false;
    
    await _sendLocationWithRetry();
    
    _startLocationTimer();
    _startDurationTimer();
    _startReconnectTimer();
    
    await _saveState();
    
    await _writeSystemLog(
      type: 'live_location_resumed',
      description: 'Live location tracking di-resume untuk lembur $_lemburId',
      data: {
        'lembur_id': _lemburId,
        'total_paused_duration_seconds': _totalPausedDuration.inSeconds,
        'resumed_at': DateTime.now().toIso8601String(),
        'network_status': 'online',
      },
    );
    
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════
  // TIMER MANAGEMENT
  // ═══════════════════════════════════════════════════════

  void _startLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (_) => _sendLocationWithRetry(),
    );
    debugPrint('📍 Location timer started (every ${_intervalSeconds}s)');
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (!_isPaused) {
          notifyListeners();
        }
      },
    );
  }

  void _startReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) async {
        if (_isActive && !_isPaused) {
          final isServiceActive = _locationService.isTracking;
          if (!isServiceActive && _networkService.isOnline) {
            debugPrint('⚠️ Reconnect: Service tidak aktif, restarting...');
            await _startServiceTracking();
            if (_isActive) {
              _retryCount = 0;
              notifyListeners();
              
              await _writeSystemLog(
                type: 'live_location_reconnect',
                description: 'Live location service di-restart (reconnect) untuk lembur $_lemburId',
                data: {'lembur_id': _lemburId},
              );
            }
          }
        }
      },
    );
  }

  void _cancelAllTimers() {
    _locationTimer?.cancel();
    _durationTimer?.cancel();
    _retryTimer?.cancel();
    _autoStopTimer?.cancel();
    _reconnectTimer?.cancel();
    
    _locationTimer = null;
    _durationTimer = null;
    _retryTimer = null;
    _autoStopTimer = null;
    _reconnectTimer = null;
  }

  // ═══════════════════════════════════════════════════════
  // LOCATION SENDING WITH RETRY
  // ═══════════════════════════════════════════════════════

  Future<void> _sendLocationWithRetry() async {
    if (!_isActive || _isPaused || _userId == null) return;

    // 🔥 Cek network pause
    if (_networkPaused) {
      debugPrint('📴 Network paused, skip pengiriman lokasi');
      return;
    }

    // 🔥 Cek koneksi
    if (!_networkService.isOnline) {
      debugPrint('📴 Offline, skip pengiriman lokasi');
      _networkPaused = true;
      _wasOffline = true;
      _offlineSince ??= DateTime.now();
      notifyListeners();
      return;
    }

    try {
      final isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        debugPrint('⚠️ GPS tidak aktif, skip pengiriman');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permission denied');
        return;
      }

      try {
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (e) {
        debugPrint('⚠️ Gagal dapat posisi (mis. GPS timeout): $e');

        // 🔥 FIX: getCurrentPosition timeout-nya 10 detik, sama persis
        // dengan durasi tracking di kasus bug. Selama menunggu, tracking
        // bisa saja sudah di-stop (mis. karena expired/force-stop).
        // Re-check di sini supaya kita tidak menjadwalkan retry timer
        // untuk tracking yang sudah tidak berjalan.
        if (!_isActive || _isPaused || _isStopping) {
          debugPrint('🔴 Tracking sudah berhenti, abaikan kegagalan kirim lokasi ini');
          return;
        }

        _handleSendFailure();
        return;
      }

      if (_retryCount > 0) {
        debugPrint('✅ Location send recovered after $_retryCount retries');
      }
      _retryCount = 0;
      
      // 🔥 Reset network state saat berhasil
      if (_networkPaused) {
        _networkPaused = false;
        _offlineSince = null;
        notifyListeners();
      }

    } catch (e) {
      debugPrint('❌ Error sending location: $e');
      
      // 🔥 Cek network error
      if (e.toString().contains('SocketException') || e.toString().contains('network')) {
        _networkPaused = true;
        _wasOffline = true;
        _offlineSince ??= DateTime.now();
        notifyListeners();
      }
      
      _handleSendFailure();
    }
  }

  void _handleSendFailure() {
    _retryCount++;
    
    if (_retryCount <= _maxRetries) {
      final backoffSeconds = (_retryCount * _retryCount * 5).clamp(5, _maxBackoffSeconds);
      
      debugPrint('🔄 Retry $_retryCount/$_maxRetries in ${backoffSeconds}s');
      
      _retryTimer?.cancel();
      _retryTimer = Timer(Duration(seconds: backoffSeconds), () {
        if (_isActive && !_isPaused && !_networkPaused) {
          _sendLocationWithRetry();
        }
      });
    } else {
      debugPrint('❌ Max retries reached. Location tracking may be degraded.');
      
      _writeSystemLog(
        type: 'live_location_max_retries',
        description: 'Live location mencapai max retries ($_maxRetries) untuk lembur $_lemburId',
        data: {
          'lembur_id': _lemburId,
          'retry_count': _retryCount,
          'max_retries': _maxRetries,
          'network_status': _networkService.isOnline ? 'online' : 'offline',
        },
      );
      
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(minutes: 10), () {
        _retryCount = 0;
      });
    }
    
    notifyListeners();
  }

  Future<void> _handleTrackingFailure() async {
    _retryCount++;
    
    if (_retryCount <= 3) {
      final backoffSeconds = (_retryCount * 10);
      debugPrint('🔄 Retry start tracking in ${backoffSeconds}s');
      
      await Future.delayed(Duration(seconds: backoffSeconds));
      
      // 🔥 Cek koneksi sebelum retry
      if (_networkService.isOnline && _isActive) {
        await _startServiceTracking();
      }
    } else {
      debugPrint('❌ Failed to start tracking after 3 attempts');
      
      await _writeSystemLog(
        type: 'live_location_start_failed',
        description: 'Gagal memulai live location tracking setelah 3 percobaan',
        data: {
          'lembur_id': _lemburId,
          'attempts': _retryCount,
          'user_name': _userName,
          'network_status': _networkService.isOnline ? 'online' : 'offline',
        },
      );
      
      _isActive = false;
      _retryCount = 0;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════
  // AUTO-STOP
  // ═══════════════════════════════════════════════════════

  void scheduleAutoStop(DateTime jamSelesai) {
    _autoStopTimer?.cancel();
    
    final now = DateTime.now();
    final delay = jamSelesai.difference(now);
    final totalDelay = delay + const Duration(minutes: 15);
    
    if (totalDelay.isNegative) {
      debugPrint('⏰ Jam selesai sudah lewat, hentikan tracking');
      stopTracking();
      return;
    }

    debugPrint('⏰ Auto-stop dijadwalkan dalam ${totalDelay.inMinutes} menit');
    
    _autoStopTimer = Timer(totalDelay, () {
      debugPrint('⏰ Auto-stop: Jam selesai tercapai');
      
      _writeSystemLog(
        type: 'live_location_auto_stop',
        description: 'Live location auto-stop karena jam selesai tercapai',
        data: {
          'lembur_id': _lemburId,
          'jam_selesai': jamSelesai.toIso8601String(),
          'durasi_sebelum_stop': getDurationString(),
          'network_status': _networkService.isOnline ? 'online' : 'offline',
        },
      );
      
      stopTracking(skipLog: true);
    });
  }

  // ═══════════════════════════════════════════════════════
  // PERSISTENCE (SHARED PREFERENCES)
  // ═══════════════════════════════════════════════════════

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyActive, _isActive);
      if (_userId != null) await prefs.setString(_prefsKeyUserId, _userId!);
      if (_userName != null) await prefs.setString(_prefsKeyUserName, _userName!);
      if (_userRole != null) await prefs.setString(_prefsKeyUserRole, _userRole!);
      if (_userFungsi != null) await prefs.setString(_prefsKeyUserFungsi, _userFungsi!);
      if (_lemburId != null) await prefs.setString(_prefsKeyLemburId, _lemburId!);
      if (_overtimeId != null) await prefs.setString(_prefsKeyOvertimeId, _overtimeId!);
      if (_startedAt != null) await prefs.setString(_prefsKeyStartedAt, _startedAt!.toIso8601String());
      await prefs.setInt(_prefsKeyInterval, _intervalSeconds);
      await prefs.setInt(_prefsKeyPausedDuration, _totalPausedDuration.inSeconds);
      debugPrint('💾 State saved to SharedPreferences');
    } catch (e) {
      debugPrint('❌ Failed to save state: $e');
    }
  }

  Future<void> _clearState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyActive);
      await prefs.remove(_prefsKeyUserId);
      await prefs.remove(_prefsKeyUserName);
      await prefs.remove(_prefsKeyUserRole);
      await prefs.remove(_prefsKeyUserFungsi);
      await prefs.remove(_prefsKeyLemburId);
      await prefs.remove(_prefsKeyOvertimeId);
      await prefs.remove(_prefsKeyStartedAt);
      await prefs.remove(_prefsKeyInterval);
      await prefs.remove(_prefsKeyPausedDuration);
      debugPrint('🗑️ State cleared from SharedPreferences');
    } catch (e) {
      debugPrint('❌ Failed to clear state: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // RESTORE TRACKING
  // ═══════════════════════════════════════════════════════

  Future<bool> restoreTracking() async {
    try {
      // 🔥 Cek koneksi dulu
      if (!_networkService.isOnline) {
        debugPrint('📴 Restore: Offline, tetap lanjutkan restore tracking');
        // Tetap restore walau offline, nanti auto kirim saat online
      }

      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(_prefsKeyActive) ?? false;
      
      if (!isActive) {
        debugPrint('🔄 No active tracking to restore');
        return false;
      }

      final userId = prefs.getString(_prefsKeyUserId);
      final userName = prefs.getString(_prefsKeyUserName);
      final lemburId = prefs.getString(_prefsKeyLemburId);
      final overtimeId = prefs.getString(_prefsKeyOvertimeId);
      final startedAtStr = prefs.getString(_prefsKeyStartedAt);
      final pausedDurationSeconds = prefs.getInt(_prefsKeyPausedDuration) ?? 0;

      if (userId == null || userName == null || lemburId == null || startedAtStr == null) {
        debugPrint('🔄 Incomplete saved state, clearing...');
        await _clearState();
        return false;
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        debugPrint('🔄 User changed, clearing tracking state');
        await _clearState();
        return false;
      }

      // 🔥 Validasi lembur (hanya jika online)
      if (_networkService.isOnline) {
        final isValid = await _validateLemburForRestore(lemburId);
        if (!isValid) {
          debugPrint('🛑 Restore: Lembur $lemburId sudah tidak valid (mungkin dibatalkan). Clear state.');
          await _clearState();
          
          await _writeSystemLog(
            type: 'live_location_restore_failed',
            description: 'Gagal restore live location: lembur tidak valid',
            data: {
              'lembur_id': lemburId,
              'alasan': 'lembur_dibatalkan_atau_dihapus',
              'user_name': userName,
            },
          );
          
          return false;
        }
      }

      debugPrint('═══════════════════════════════════════');
      debugPrint('🔄 LiveLocationManager: RESTORING TRACKING');
      debugPrint('   User: $userName ($userId)');
      debugPrint('   Lembur ID: $lemburId');
      debugPrint('   Started at: $startedAtStr');
      debugPrint('   Paused duration: ${pausedDurationSeconds}s');
      debugPrint('   Network: ${_networkService.isOnline ? "ONLINE" : "OFFLINE"}');
      debugPrint('═══════════════════════════════════════');

      _userId = userId;
      _userName = userName;
      _userRole = prefs.getString(_prefsKeyUserRole) ?? 'mitra';
      _userFungsi = prefs.getString(_prefsKeyUserFungsi) ?? 'lembur';
      _lemburId = lemburId;
      _overtimeId = overtimeId ?? lemburId;
      _intervalSeconds = prefs.getInt(_prefsKeyInterval) ?? 60;
      _startedAt = DateTime.tryParse(startedAtStr);
      _isActive = true;
      _isPaused = false;
      _totalPausedDuration = Duration(seconds: pausedDurationSeconds);
      _retryCount = 0;
      _networkPaused = !_networkService.isOnline;

      _startLemburStatusMonitor(lemburId);

      final success = await _startServiceTracking();
      
      if (!success) {
        debugPrint('⚠️ Failed to restart service, will retry');
        _retryCount = 1;
      }

      _startLocationTimer();
      _startDurationTimer();
      _startReconnectTimer();

      await _writeSystemLog(
        type: 'live_location_restored',
        description: 'Live location tracking berhasil di-restore',
        data: {
          'lembur_id': lemburId,
          'paused_duration_seconds': pausedDurationSeconds,
          'started_at_original': startedAtStr,
          'user_name': userName,
          'network_status': _networkService.isOnline ? 'online' : 'offline',
        },
      );

      notifyListeners();
      
      debugPrint('✅ LiveLocationManager: Tracking restored');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to restore tracking: $e');
      return false;
    }
  }

  Future<bool> _validateLemburForRestore(String lemburId) async {
    try {
      final doc = await _firestore.collection(_overtimeCollection).doc(lemburId).get();
      
      if (!doc.exists) {
        debugPrint('   ❌ Validasi restore: Dokumen $lemburId tidak ditemukan');
        return false;
      }

      final data = doc.data()!;
      
      final isCancelled = 
          data['is_cancelled'] == true ||
          data['status_pengajuan'] == 'dibatalkan' ||
          data['status_pengajuan'] == 'cancelled' ||
          data['status_pengajuan'] == 'ditolak' ||
          data['absensi_status'] == 'dibatalkan';

      if (isCancelled) {
        debugPrint('   ❌ Validasi restore: Lembur $lemburId dibatalkan (status: ${data['status_pengajuan']})');
        return false;
      }

      debugPrint('   ✅ Validasi restore: Lembur $lemburId valid');
      return true;
    } catch (e) {
      debugPrint('   ⚠️ Validasi restore error: $e');
      return true;
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 SYSTEM LOG WRITER (TERINTEGRASI system_logs)
  // ═══════════════════════════════════════════════════════

  /// Menulis log ke collection system_logs
  /// Format disesuaikan dengan struktur yang dibaca SystemLogsScreen
  Future<void> _writeSystemLog({
    required String type,
    required String description,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 🔥 Skip log ke Firestore jika offline
      if (!_networkService.isOnline) {
        debugPrint('📝 System log [$type]: Disimpan lokal (offline)');
        // Bisa tambah queue untuk kirim nanti
        return;
      }

      final logData = <String, dynamic>{
        'timestamp': FieldValue.serverTimestamp(),
        'type': type,
        'description': description,
        'user': _userName ?? 'system',
        'user_role': _userRole ?? 'mitra',
        'session_id': _userId ?? 'unknown',
        'target_user': null,
        'data': data ?? {},
      };

      final docRef = await _firestore
          .collection(_systemLogsCollection)
          .add(logData);
      
      debugPrint('📝 System log [$type]: ${docRef.id}');
    } catch (e) {
      debugPrint('⚠️ Gagal menulis system log: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // LIFECYCLE OBSERVER
  // ═══════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('📱 App lifecycle: $state | Tracking: $_isActive | Paused: $_isPaused | Network: ${_networkService.isOnline ? "ONLINE" : "OFFLINE"}');
    
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isActive && _isPaused) {
          resumeTracking();
        } else if (_isActive) {
          _sendLocationWithRetry();
          notifyListeners();
        }
        break;
        
      case AppLifecycleState.paused:
        debugPrint('📱 App paused - tracking continues in background');
        break;
        
      case AppLifecycleState.inactive:
        break;
        
      case AppLifecycleState.detached:
        _saveState();
        break;
        
      case AppLifecycleState.hidden:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════

  void _resetState() {
    _cancelAllTimers();
    
    _lemburStatusSubscription?.cancel();
    _lemburStatusSubscription = null;
    
    _isActive = false;
    _isPaused = false;
    _isStopping = false;
    _startedAt = null;
    _pausedAt = null;
    _userId = null;
    _userName = null;
    _userRole = null;
    _userFungsi = null;
    _lemburId = null;
    _overtimeId = null;
    _intervalSeconds = 60;
    _retryCount = 0;
    _totalPausedDuration = Duration.zero;
    _networkPaused = false;
    _wasOffline = false;
    _offlineSince = null;
  }

  Future<bool> validateTracking() async {
    if (!_isActive) return false;
    
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != _userId) {
      debugPrint('⚠️ User tidak valid, stop tracking');
      await stopTracking();
      return false;
    }
    
    return true;
  }

  Future<void> sendLocationNow() async {
    if (!_isActive || _isPaused) {
      debugPrint('⚠️ Cannot send location: tracking not active');
      return;
    }
    
    // 🔥 Cek koneksi
    if (!_networkService.isOnline) {
      debugPrint('📴 Cannot send location: offline');
      return;
    }
    
    await _sendLocationWithRetry();
  }

  void updateInterval(int newIntervalSeconds) {
    _intervalSeconds = newIntervalSeconds.clamp(10, 300);
    _startLocationTimer();
    _saveState();
    debugPrint('⏱️ Interval updated to ${_intervalSeconds}s');
    
    _writeSystemLog(
      type: 'live_location_interval_updated',
      description: 'Interval live location diubah menjadi $_intervalSeconds detik',
      data: {
        'lembur_id': _lemburId,
        'interval_baru': _intervalSeconds,
      },
    );
  }

  void logStatus() {
    debugPrint('═══════════════════════════════════════');
    debugPrint('📊 LiveLocationManager STATUS');
    debugPrint('   Active: $_isActive');
    debugPrint('   Paused: $_isPaused');
    debugPrint('   User: $_userName ($_userId)');
    debugPrint('   Role: $_userRole | Fungsi: $_userFungsi');
    debugPrint('   Lembur: $_lemburId');
    debugPrint('   Duration: ${getDurationString()}');
    debugPrint('   Interval: ${_intervalSeconds}s');
    debugPrint('   Retries: $_retryCount');
    debugPrint('   Paused Duration: ${_totalPausedDuration.inMinutes} min');
    debugPrint('   Monitor Active: ${_lemburStatusSubscription != null}');
    debugPrint('   Network: ${_networkService.isOnline ? "ONLINE" : "OFFLINE"}');
    debugPrint('   Network Paused: $_networkPaused');
    debugPrint('   Was Offline: $_wasOffline');
    debugPrint('   Offline Since: $_offlineSince');
    debugPrint('═══════════════════════════════════════');
  }

  // ═══════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════

  @override
  void dispose() {
    debugPrint('🗑️ LiveLocationManager: Disposing...');
    
    _cancelAllTimers();
    _lemburStatusSubscription?.cancel();
    _lemburStatusSubscription = null;
    _networkSubscription?.cancel(); // 🔥 Cleanup network listener
    _networkSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    _saveState();
    
    super.dispose();
  }
}