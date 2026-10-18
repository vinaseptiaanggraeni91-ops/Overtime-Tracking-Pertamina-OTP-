import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '/core/services/overtime_absensi_service.dart';
import '/core/services/watermark_service.dart';
import '/core/services/cloudinary_storage_service.dart';
import '/core/services/live_location_manager.dart';
import '/widgets/absensi/location_validator.dart';
import '/widgets/bottom_nav/mitra_bottom_nav.dart';

class AbsensiPage extends StatefulWidget {
  const AbsensiPage({super.key});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> with WidgetsBindingObserver {
  // ═══════════════════════════════════════════════════════
  // SERVICES & MANAGERS
  // ═══════════════════════════════════════════════════════
  Timer? _autoStopTimer;
  static const Duration _debounceDuration = Duration(seconds: 2);
  DateTime? _lastLocationUpdate;

  final Connectivity _connectivity = Connectivity();
  final ImagePicker _imagePicker = ImagePicker();
  final LocationValidator _locationValidator = LocationValidator();
  final WatermarkService _watermarkService = WatermarkService();
  final OvertimeAbsensiService _absensiService = OvertimeAbsensiService();
  final CloudinaryStorageService _cloudinaryService = CloudinaryStorageService();
  final LiveLocationManager _liveLocationManager = LiveLocationManager();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════
  // UI STATES
  // ═══════════════════════════════════════════════════════
  bool _isLoading = true;
  bool _isLoadingLocation = false;
  bool _isTakingPhoto = false;
  bool _isSubmitting = false;
  String _statusMessage = 'Memuat data lembur...';
  String? _errorDetail;
  Position? _currentPosition;
  String? _currentAddress;
  XFile? _capturedImage;
  File? _previewFile;
  bool _locationValid = false;
  bool _locationVerified = false;
  bool _hasAttemptedRetry = false;
  double? _distanceInMeters;
  double? _maxRadius;
  static const int _maxRetries = 2;

  // ═══════════════════════════════════════════════════════
  // DATA LEMBUR & USER
  // ═══════════════════════════════════════════════════════
  OvertimeHistory? _overtimeItem;
  String? _cachedWorkerName;

  bool _isLateOvertime = false;
  bool _hasUpcomingOvertime = false;

  // ═══════════════════════════════════════════════════════
  // TAB LEMBUR TERLAMBAT
  // ═══════════════════════════════════════════════════════
  int _currentTabIndex = 0;
  List<OvertimeHistory> _lateOvertimeList = [];
  bool _isLoadingLateList = false;
  bool _isViewingLateOvertime = false;

  // ═══════════════════════════════════════════════════════
  // KONFIRMASI KETERLAMBATAN
  // ═══════════════════════════════════════════════════════
  bool _isCheckingStatus = false;
  bool _canConfirm = false;
  bool _showKonfirmasiForm = false;
  bool? _melakukanLembur;
  final TextEditingController _alasanController = TextEditingController();
  File? _buktiFotoTerlambat;
  bool _isUploadingBukti = false;
  String _debugKonfirmasiStatus = '';
  bool _hasInitCheckRun = false;
  String? _konfirmasiError;

  // ═══════════════════════════════════════════════════════
  // CHECK-IN STATE
  // ═══════════════════════════════════════════════════════
  bool _hasCheckedIn = false;
  DateTime? _checkInTime;
  bool _isCheckInFinalized = false;

  // ═══════════════════════════════════════════════════════
  // CHECK-OUT STATE
  // ═══════════════════════════════════════════════════════
  bool _isCheckingOut = false;
  bool _hasCheckedOut = false;
  bool _canCheckOut = false;
  XFile? _checkOutImage;
  File? _checkOutPreviewFile;
  Timer? _checkOutTimer;
  Timer? _countdownTimer;

  // ═══════════════════════════════════════════════════════
  // 🔥 BARU: FLAG UNTUK MENCEGAH BUG LIVE LOCATION
  // ═══════════════════════════════════════════════════════
  bool _isAutoStopped = false;
  bool _isExpired = false;
  bool _isLemburLintasHari = false;
  DateTime? _lastLifecycleResume;

  // ═══════════════════════════════════════════════════════
  // 🔥 BARU: KONFIRMASI KETERLAMBATAN CHECK-OUT
  // Beda dari _showKonfirmasiForm/_melakukanLembur di atas, yang khusus
  // untuk keterlambatan CHECK-IN. Ini khusus untuk telat CHECK-OUT
  // (lewat checkOutEnd = jamSelesai + 2 jam, tapi masih dalam grace period).
  // ═══════════════════════════════════════════════════════
  bool _isLateCheckOut = false;
  bool _showCheckOutKonfirmasiForm = false;
  final TextEditingController _alasanCheckOutController = TextEditingController();
  File? _buktiFotoCheckOutTerlambat;
  bool _isSubmittingCheckOutTerlambat = false;
  bool _isUploadingBuktiCheckOut = false;
  String? _konfirmasiCheckOutError;
  String? _batasKonfirmasiCheckOutLabel;

  // ═══════════════════════════════════════════════════════
  // HIDE VERIFIKASI LOKASI
  // ═══════════════════════════════════════════════════════
  bool _hideLocationVerification = false;
  bool _isNormalAbsensiReady = false;

  // ═══════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    debugPrint('🔵 AbsensiPage: initState START');
    WidgetsBinding.instance.addObserver(this);
    _liveLocationManager.addListener(_onLiveLocationUpdate);
    _liveLocationManager.onForceStop = _handleForceStop;
    _loadOvertimeData();
  }

  @override
  void dispose() {
    debugPrint('🔵 AbsensiPage: dispose');
    _liveLocationManager.onForceStop = null;
    WidgetsBinding.instance.removeObserver(this);
    _liveLocationManager.removeListener(_onLiveLocationUpdate);
    _countdownTimer?.cancel();
    _checkOutTimer?.cancel();
    _autoStopTimer?.cancel();
    _cleanupPreviewFile();
    _cleanupCheckOutPreviewFile();
    _cleanupBuktiFoto();
    _alasanController.dispose();
    _alasanCheckOutController.dispose();
    super.dispose();
  }

  void _onLiveLocationUpdate() {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastLocationUpdate != null &&
        now.difference(_lastLocationUpdate!) < _debounceDuration) {
      return;
    }
    _lastLocationUpdate = now;
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('🔄 AppLifecycleState: $state');

    if (state == AppLifecycleState.resumed) {
      _lastLifecycleResume = DateTime.now();

      if (_hasCheckedOut || _isExpired || _isAutoStopped) {
        debugPrint('⏭️ App resumed tapi sudah selesai/expired, tidak reload');
        return;
      }

      if (_overtimeItem != null && _hasCheckedIn && !_hasCheckedOut) {
        _validateAndReloadIfNeeded();
        _checkCheckOutAvailability();
      } else if (!_isCheckInFinalized && !_hasCheckedOut) {
        debugPrint('🔄 App resumed - reloading overtime data...');
        _hasInitCheckRun = false;
        _loadOvertimeData();
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 FORCE STOP HANDLER + RESET + VALIDASI
  // ═══════════════════════════════════════════════════════

  void _handleForceStop(String reason) {
    if (!mounted || _hasCheckedOut || _isAutoStopped || _isExpired) {
      debugPrint('⏭️ Skip force stop (already stopped/expired/checked-out)');
      return;
    }

    debugPrint('═══════════════════════════════════════');
    debugPrint('⚠️ AbsensiPage: Force stop detected!');
    debugPrint('   Reason: $reason');
    debugPrint('═══════════════════════════════════════');

    _stopLiveLocation();
    _isAutoStopped = true;
    _resetAllState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _isAutoStopped = false;
        _loadOvertimeData();
        _showSnackBar(
            '⚠️ Lembur dibatalkan oleh pengawas. Live location dihentikan.',
            Colors.orange);
      }
    });
  }

  void _resetAllState() {
    debugPrint('🔄 _resetAllState: Resetting ALL states...');

    _checkOutTimer?.cancel();
    _checkOutTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _lastLocationUpdate = null;

    _cleanupPreviewFile();
    _cleanupCheckOutPreviewFile();
    _cleanupBuktiFoto();

    if (mounted) {
      setState(() {
        _hasCheckedIn = false;
        _isCheckInFinalized = false;
        _checkInTime = null;
        _hasCheckedOut = false;
        _canCheckOut = false;

        _locationValid = false;
        _locationVerified = false;
        _currentPosition = null;
        _currentAddress = null;
        _distanceInMeters = null;
        _hasAttemptedRetry = false;

        _capturedImage = null;
        _previewFile = null;
        _checkOutImage = null;
        _checkOutPreviewFile = null;
        _isTakingPhoto = false;

        _showKonfirmasiForm = false;
        _canConfirm = false;
        _melakukanLembur = null;
        _alasanController.clear();
        _buktiFotoTerlambat = null;
        _isUploadingBukti = false;
        _debugKonfirmasiStatus = '';
        _konfirmasiError = null;

        _isViewingLateOvertime = false;
        _hasUpcomingOvertime = false;
        _hideLocationVerification = false;
        _isNormalAbsensiReady = false;

        _overtimeItem = null;
        _hasInitCheckRun = false;
        _isCheckingStatus = false;
        _isSubmitting = false;
        _isCheckingOut = false;
        _isLoading = false;

        _isExpired = false;
        _isLateCheckOut = false;
        _isLemburLintasHari = false;

        _statusMessage = 'Memuat ulang data...';
        _errorDetail = null;
      });
    }
  }

  Future<bool> _validateLemburStillActive(String lemburId) async {
    try {
      final doc =
          await _firestore.collection('lembur_mitra').doc(lemburId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      return !(data['is_cancelled'] == true ||
          data['status_pengajuan'] == 'dibatalkan' ||
          data['status_pengajuan'] == 'cancelled' ||
          data['status_pengajuan'] == 'ditolak' ||
          data['absensi_status'] == 'dibatalkan');
    } catch (e) {
      debugPrint('⚠️ Validasi error: $e');
      return true;
    }
  }

  Future<bool> _isLemburStillCheckedIn(String lemburId) async {
    try {
      final doc =
          await _firestore.collection('lembur_mitra').doc(lemburId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final hasCheckInTime = data['check_in_time'] != null;
      final status = data['absensi_status'];
      return hasCheckInTime || status == 'check_in' || status == 'sudah_absen';
    } catch (e) {
      debugPrint('⚠️ Validasi status check-in error: $e');
      return true;
    }
  }

  Future<bool> _isLemburDariHariSebelumnya(String lemburId) async {
    try {
      final doc =
          await _firestore.collection('lembur_mitra').doc(lemburId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final tanggalField = data['tanggal'];

      if (tanggalField == null) return false;

      DateTime tanggalLembur;
      if (tanggalField is Timestamp) {
        tanggalLembur = tanggalField.toDate();
      } else if (tanggalField is String) {
        tanggalLembur = DateTime.parse(tanggalField);
      } else {
        return false;
      }

      final now = DateTime.now();
      return tanggalLembur.day != now.day ||
          tanggalLembur.month != now.month ||
          tanggalLembur.year != now.year;
    } catch (e) {
      debugPrint('⚠️ Gagal cek tanggal lembur: $e');
      return false;
    }
  }

  Future<void> _validateAndReloadIfNeeded() async {
    if (_overtimeItem == null) return;

    if (_hasCheckedOut) {
      debugPrint('⏭️ Skip validasi, user sudah check-out');
      return;
    }

    final isValid = await _validateLemburStillActive(_overtimeItem!.id);
    if (!isValid && mounted) {
      debugPrint('🛑 Lembur dibatalkan saat app di background!');
      _handleForceStop('Lembur dibatalkan saat aplikasi di background');
    }
  }

  // ═══════════════════════════════════════════════════════
  // GET WORKER NAME
  // ═══════════════════════════════════════════════════════

  Future<String> _getWorkerName({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedWorkerName != null &&
        _cachedWorkerName!.isNotEmpty) {
      return _cachedWorkerName!;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Mitra';

    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (refreshedUser?.displayName != null &&
        refreshedUser!.displayName!.isNotEmpty) {
      _cachedWorkerName = refreshedUser.displayName;
      return _cachedWorkerName!;
    }

    try {
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        // 🔥 PERBAIKAN: Konversi Timestamp ke String sebelum caching
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        _cachedWorkerName = data['nama_lengkap'] ??
            data['name'] ??
            data['displayName'] ??
            data['nama'] ??
            'Mitra';
        return _cachedWorkerName!;
      }
    } catch (e) {
      debugPrint('⚠️ Gagal ambil nama dari Firestore: $e');
    }

    _cachedWorkerName = 'Mitra';
    return _cachedWorkerName!;
  }

  // ═══════════════════════════════════════════════════════
  // REFRESH LOKASI UNTUK CHECK-OUT
  // ═══════════════════════════════════════════════════════

  Future<void> _refreshLocationForCheckOut() async {
    try {
      debugPrint('📍 Refresh lokasi untuk check-out...');

      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('⚠️ GPS tidak aktif, pakai data terakhir');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        debugPrint('⚠️ Izin lokasi ditolak, pakai data terakhir');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _currentPosition = pos;
      debugPrint('📍 GPS updated: ${pos.latitude}, ${pos.longitude}');

      try {
        _currentAddress = await _locationValidator
            .getAddressFromCoordinates(pos.latitude, pos.longitude)
            .timeout(const Duration(seconds: 10));
        debugPrint('📍 Alamat: $_currentAddress');
      } catch (_) {
        _currentAddress = 'Lokasi Check-Out';
      }
    } catch (e) {
      debugPrint('⚠️ Gagal refresh GPS: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // CLEANUP HELPERS
  // ═══════════════════════════════════════════════════════

  Future<void> _cleanupPreviewFile() async {
    try {
      if (_previewFile != null && await _previewFile!.exists()) {
        await _previewFile!.delete();
      }
    } catch (_) {}
  }

  Future<void> _cleanupCheckOutPreviewFile() async {
    try {
      if (_checkOutPreviewFile != null &&
          await _checkOutPreviewFile!.exists()) {
        await _checkOutPreviewFile!.delete();
      }
    } catch (_) {}
  }

  Future<void> _cleanupBuktiFoto() async {
    try {
      if (_buktiFotoTerlambat != null &&
          await _buktiFotoTerlambat!.exists()) {
        await _buktiFotoTerlambat!.delete();
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 PERBAIKAN: CHECK-OUT AVAILABILITY (NO AUTO-STOP FOR OLD LEMBUR)
  // ═══════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════
  // 🔥 FIX: CEK EXPIRED TANPA SIDE-EFFECT
  // Dipakai SEBELUM start live location, supaya kita tidak
  // START tracking lalu langsung di-STOP oleh _checkCheckOutAvailability().
  // ═══════════════════════════════════════════════════════
  bool _isOvertimeCheckOutExpired(OvertimeHistory overtime) {
    try {
      final now = DateTime.now();
      final tgl = overtime.tanggal;
      final parts = overtime.jamSelesai.split(':');
      final partsMulai = overtime.jamMulai.split(':');
      if (parts.length != 2 || partsMulai.length != 2) return false;

      final jamMulai = DateTime(tgl.year, tgl.month, tgl.day,
          int.parse(partsMulai[0]), int.parse(partsMulai[1]));
      var jamSelesai = DateTime(tgl.year, tgl.month, tgl.day,
          int.parse(parts[0]), int.parse(parts[1]));
      if (jamSelesai.isBefore(jamMulai)) {
        jamSelesai = jamSelesai.add(const Duration(days: 1));
      }
      final checkOutEnd = jamSelesai.add(const Duration(hours: 2));

      return now.isAfter(checkOutEnd);
    } catch (e) {
      debugPrint('❌ Error cek expired (fail-safe: anggap belum expired): $e');
      return false;
    }
  }

  void _checkCheckOutAvailability() {
    if (_overtimeItem == null || !_hasCheckedIn || _hasCheckedOut) return;

    if (_isLemburLintasHari) {
      debugPrint('⏭️ Lembur lintas hari - tidak auto-stop');
      return;
    }

    try {
      final now = DateTime.now();
      final tgl = _overtimeItem!.tanggal;
      final parts = _overtimeItem!.jamSelesai.split(':');
      final partsMulai = _overtimeItem!.jamMulai.split(':');
      if (parts.length != 2 || partsMulai.length != 2) return;

      final jamMulai = DateTime(tgl.year, tgl.month, tgl.day,
          int.parse(partsMulai[0]), int.parse(partsMulai[1]));
      var jamSelesai = DateTime(tgl.year, tgl.month, tgl.day,
          int.parse(parts[0]), int.parse(parts[1]));
      if (jamSelesai.isBefore(jamMulai)) {
        jamSelesai = jamSelesai.add(const Duration(days: 1));
      }
      final checkOutStart = jamSelesai.subtract(const Duration(minutes: 30));
      final checkOutEnd = jamSelesai.add(const Duration(hours: 2));
      // 🔥 BARU: grace period tambahan untuk isi form konfirmasi keterlambatan
      // checkout, disamakan dengan CHECKOUT_KONFIRMASI_GRACE_PERIOD di backend
      // (overtime_absensi_service.dart) supaya kedua sisi konsisten.
      final batasKonfirmasiCheckOut = checkOutEnd.add(const Duration(days: 3));

      if (now.isAfter(checkOutEnd)) {
        _stopLiveLocation();
        _autoStopTimer?.cancel();
        _checkOutTimer?.cancel();
        _countdownTimer?.cancel();

        if (now.isBefore(batasKonfirmasiCheckOut)) {
          // 🔥 Masih dalam grace period: arahkan ke konfirmasi keterlambatan
          // checkout, JANGAN langsung ke STATE 2.5 EXPIRED ("hubungi pengawas").
          debugPrint('⏰ Checkout melewati batas normal, masuk masa konfirmasi keterlambatan');
          if (mounted) {
            setState(() {
              _canCheckOut = false;
              _isExpired = false;
              _isLateCheckOut = true;
              _statusMessage = '⏰ Waktu checkout normal sudah lewat.';
              _errorDetail =
                  'Silakan isi konfirmasi keterlambatan checkout beserta alasannya.';
              _batasKonfirmasiCheckOutLabel =
                  DateFormat('dd MMM HH:mm', 'id_ID').format(batasKonfirmasiCheckOut);
            });
          }
        } else {
          // 🔥 Grace period juga sudah habis: baru benar-benar expired.
          debugPrint('⏰ Batas konfirmasi keterlambatan checkout juga telah berakhir!');
          if (mounted) {
            setState(() {
              _canCheckOut = false;
              _isLateCheckOut = false;
              _isExpired = true;
              _statusMessage = '⏰ Waktu check-out telah berakhir.';
              _errorDetail =
                  'Lembur ini sudah melewati batas waktu. Silakan hubungi pengawas untuk penyelesaian.';
            });
          }
        }
        return;
      }

      final canCheckOut =
          now.isAfter(checkOutStart) && now.isBefore(checkOutEnd);

      if (mounted) {
        setState(() => _canCheckOut = canCheckOut);
      }

      _checkOutTimer?.cancel();
      _autoStopTimer?.cancel();

      if (!canCheckOut && now.isBefore(checkOutStart)) {
        final diff = checkOutStart.difference(now);
        _checkOutTimer = Timer(diff + const Duration(seconds: 2), () {
          if (mounted) _checkCheckOutAvailability();
        });
      } else if (canCheckOut && now.isBefore(checkOutEnd)) {
        final autoStopDiff = checkOutEnd.difference(now);
        _autoStopTimer = Timer(autoStopDiff + const Duration(seconds: 5), () {
          debugPrint('⏰ Auto-stop timer fired!');
          if (mounted) _checkCheckOutAvailability();
        });
      }

      _startCountdownTimer(checkOutStart, jamSelesai);
    } catch (e) {
      debugPrint('❌ Error check-out availability: $e');
    }
  }

  void _startCountdownTimer(DateTime checkOutStart, DateTime jamSelesai) {
    _countdownTimer?.cancel();
    final now = DateTime.now();
    final checkOutEnd = jamSelesai.add(const Duration(hours: 2));

    if (now.isBefore(checkOutEnd)) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        setState(() {});

        final currentTime = DateTime.now();
        if (currentTime.isAfter(checkOutStart) && !_canCheckOut) {
          _checkCheckOutAvailability();
        }

        if (currentTime.isAfter(checkOutEnd)) {
          _countdownTimer?.cancel();
          _checkCheckOutAvailability();
        }
      });
    }
  }

  // ═══════════════════════════════════════════════════════
  // LIVE LOCATION
  // ═══════════════════════════════════════════════════════

  Future<void> _startLiveLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _overtimeItem == null) return;

    if (_liveLocationManager.isActive &&
        _liveLocationManager.lemburId == _overtimeItem!.id) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final workerName = await _getWorkerName();
      await _liveLocationManager.startTracking(
        userId: user.uid,
        userName: workerName,
        lemburId: _overtimeItem!.id,
        intervalSeconds: 60,
        userRole: 'mitra',
        userFungsi: 'lembur',
      );
    } catch (e) {
      if (mounted) _showSnackBar('⚠️ Gagal live location: $e', Colors.red);
    }
  }

  Future<void> _stopLiveLocation() async {
    if (_liveLocationManager.isActive) {
      await _liveLocationManager.stopTracking();
      if (mounted) setState(() {});
    }
  }

  String _getLiveLocationDuration() => _liveLocationManager.getDurationString();
  bool get _isLiveLocationActive => _liveLocationManager.isActive;

  // ═══════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════

  void _goBack() {
    _checkOutTimer?.cancel();
    _countdownTimer?.cancel();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/mitra-dashboard');
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 PERBAIKAN: LOAD DATA - HANDLE LEMBUR LINTAS HARI
  // ═══════════════════════════════════════════════════════

  Future<void> _loadOvertimeData() async {
    if (_isCheckInFinalized) {
      debugPrint('⏭️ _loadOvertimeData: SKIP - already finalized');
      return;
    }

    if (_hasCheckedOut || _isExpired) {
      debugPrint('⏭️ _loadOvertimeData: SKIP - already checked out or expired');
      return;
    }

    debugPrint('═══════════════════════════════════════');
    debugPrint('🔄 _loadOvertimeData: START');

    setState(() {
      _isLoading = true;
      _statusMessage = 'Memuat data lembur...';
      _errorDetail = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Silakan login terlebih dahulu';
          });
        }
        return;
      }

      await _getWorkerName();
      await _liveLocationManager.restoreTracking();

      if (_liveLocationManager.isActive &&
          _liveLocationManager.lemburId != null) {
        final trackedLemburId = _liveLocationManager.lemburId!;

        final isLintasHari =
            await _isLemburDariHariSebelumnya(trackedLemburId);
        final isValid = await _validateLemburStillActive(trackedLemburId);
        final isStillCheckedIn =
            isValid && await _isLemburStillCheckedIn(trackedLemburId);

        if (isLintasHari && isStillCheckedIn) {
          debugPrint('⚠️ Lembur kemarin ($trackedLemburId) belum check-out!');
          await _liveLocationManager.stopTracking();
          _resetAllState();

          if (mounted) {
            setState(() {
              _isExpired = true;
              _isLateCheckOut = false;
              _isLemburLintasHari = true;
              _isLoading = false;
              _statusMessage =
                  '⚠️ Anda memiliki lembur yang belum selesai';
              _errorDetail =
                  'Lembur dari hari sebelumnya belum check-out. Silakan hubungi pengawas untuk menyelesaikan.';
            });
          }
          return;
        }

        if (!isValid || !isStillCheckedIn) {
          debugPrint(!isValid
              ? '🛑 Restored tracking tapi lembur sudah dibatalkan!'
              : '🛑 Restored tracking tapi status check-in sudah direset!');
          await _liveLocationManager.stopTracking();
          _resetAllState();
        }
      }

      if (_liveLocationManager.isActive && !_hasCheckedIn) {
        _hasCheckedIn = true;
        _isCheckInFinalized = true;
        _checkInTime = _liveLocationManager.startedAt;
        _locationValid = true;
        _locationVerified = true;
        _isLemburLintasHari = false;
        debugPrint('✅ Restored live location tracking');
      }

      // LANGKAH 1: Cari lembur hari ini
      OvertimeHistory? overtime =
          await _absensiService.getTodayOvertimeForAbsensi(user.uid);

      if (overtime != null) {
        final isCancelled = !(await _validateLemburStillActive(overtime.id));
        if (isCancelled) {
          debugPrint('⚠️ Lembur hari ini dibatalkan!');
          overtime = null;
        }
      }

      // LANGKAH 2: Load lembur terlambat
      await _loadLateOvertimeList(user.uid);

      // LANGKAH 3: Tentukan apakah "belum waktunya"
      bool isUpcoming = false;
      if (overtime != null) {
        final now = DateTime.now();
        final partsMulai = overtime.jamMulai.split(':');
        if (partsMulai.length == 2) {
          final jamMulaiToday = DateTime(
              overtime.tanggal.year,
              overtime.tanggal.month,
              overtime.tanggal.day,
              int.parse(partsMulai[0]),
              int.parse(partsMulai[1]));
          final earliestCheckIn =
              jamMulaiToday.subtract(const Duration(minutes: 30));

          if (now.isBefore(earliestCheckIn) &&
              overtime.absensiStatus != 'check_in' &&
              overtime.absensiStatus != 'sudah_absen') {
            isUpcoming = true;
            _hasUpcomingOvertime = true;
            _isNormalAbsensiReady = false;
            _hideLocationVerification = true;
            debugPrint('⏰ LEMBUR NORMAL BELUM WAKTUNYA!');
          } else {
            _isNormalAbsensiReady = true;
            _hideLocationVerification = false;
            debugPrint('✅ LEMBUR NORMAL SUDAH WAKTUNYA!');
          }
        }
      }

      // LANGKAH 4: Jika tidak ada lembur hari ini, cek lembur terlambat
      if (overtime == null || isUpcoming) {
        if (_lateOvertimeList.isNotEmpty) {
          for (final lateItem in _lateOvertimeList) {
            final isValid = await _validateLemburStillActive(lateItem.id);
            if (isValid) {
              overtime = lateItem;
              break;
            }
          }

          if (overtime != null) {
            _isLateOvertime = true;
            _isViewingLateOvertime = true;
            _hideLocationVerification = false;
            _currentTabIndex = 1;
            debugPrint(
                '🚨 AUTO-SWITCH ke lembur terlambat: ${overtime.tanggal}');
          }
        }
      }

      if (overtime == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Tidak ada jadwal lembur';
            _isExpired = false;
            _isLateCheckOut = false;
            _isLemburLintasHari = false;
          });
        }
        return;
      }

      final fireCI = overtime.checkInTime != null ||
          overtime.absensiStatus == 'check_in' ||
          overtime.absensiStatus == 'sudah_absen';
      final fireCO = overtime.isCheckedOut;

      final effectiveCI = _isCheckInFinalized || _hasCheckedIn || fireCI;
      final effectiveCO = _hasCheckedOut || fireCO;
      final llActive = _liveLocationManager.isActive &&
          _liveLocationManager.lemburId == overtime.id;

      if (mounted) {
        setState(() {
          _overtimeItem = overtime;
          _isLoading = false;
          _hasCheckedIn = effectiveCI;
          _hasCheckedOut = effectiveCO;
          _checkInTime = overtime?.checkInTime ?? _checkInTime;
          _locationValid = effectiveCI || llActive;
          _locationVerified = effectiveCI || llActive;
          if (effectiveCI) _isCheckInFinalized = true;
          _isExpired = false;
          _isLateCheckOut = false;
          _isLemburLintasHari = false;
        });
      }

      if (effectiveCO) {
        debugPrint('✅ Already checked out');
        if (llActive) await _liveLocationManager.stopTracking();
        return;
      }

      if (effectiveCI) {
        // 🔥 FIX UTAMA: cek expired DULU sebelum start live location.
        // Sebelumnya: START dulu -> baru _checkCheckOutAvailability() cek expired
        // -> kalau ternyata expired, langsung STOP lagi (makanya hidup cuma ~10 detik).
        final isExpired = _isOvertimeCheckOutExpired(overtime);

        if (isExpired) {
          debugPrint('⏰ Already checked in TAPI sudah expired - skip start live location');
          if (llActive) await _stopLiveLocation();
        } else {
          debugPrint('✅ Already checked in - starting live location');
          if (!llActive) await _startLiveLocation();
        }

        _checkCheckOutAvailability();
      } else {
        debugPrint('🟡 User BELUM check-in - FORCING _initCheck()...');
        _hasInitCheckRun = false;
        await _initCheck();
      }
    } catch (e) {
      debugPrint('❌ _loadOvertimeData ERROR: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Gagal memuat data';
          _errorDetail = e.toString();
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // LOAD LATE OVERTIME LIST (DENGAN FILTER TANGGAL BENAR)
  // ═══════════════════════════════════════════════════════

  Future<void> _loadLateOvertimeList(String userId) async {
    debugPrint('🔍 _loadLateOvertimeList: Loading...');

    setState(() => _isLoadingLateList = true);

    try {
      final now = DateTime.now();
      final allPending = await _absensiService.getLemburNeedAbsensi(
        userId: userId,
        userRole: 'mitra',
      );

      final List<OvertimeHistory> lateList = [];

      for (final item in allPending) {
        if (item.isCancelled == true ||
            item.statusPengajuan == 'dibatalkan' ||
            item.statusPengajuan == 'cancelled' ||
            item.statusPengajuan == 'ditolak') {
          debugPrint('   ⛔ Skip cancelled: ${item.tanggal}');
          continue;
        }

        final tanggalLembur = item.tanggal;
        if (tanggalLembur.isAfter(now)) {
          debugPrint('   ⏭️ Skip future: ${DateFormat('dd MMM').format(tanggalLembur)}');
          continue;
        }

        final partsMulai = item.jamMulai.split(':');
        final partsSelesai = item.jamSelesai.split(':');
        if (partsMulai.length != 2 || partsSelesai.length != 2) continue;

        final tanggal = item.tanggal;
        final jamMulai = DateTime(tanggal.year, tanggal.month, tanggal.day,
            int.parse(partsMulai[0]), int.parse(partsMulai[1]));
        var jamSelesai = DateTime(tanggal.year, tanggal.month, tanggal.day,
            int.parse(partsSelesai[0]), int.parse(partsSelesai[1]));
        if (jamSelesai.isBefore(jamMulai)) {
          jamSelesai = jamSelesai.add(const Duration(days: 1));
        }

        final batasNormal = jamSelesai.add(const Duration(minutes: 30));
        final batasExpired = jamSelesai.add(const Duration(days: 3));

        final sudahCheckIn = item.absensiStatus == 'check_in' ||
            item.absensiStatus == 'sudah_absen' ||
            item.checkInTime != null;

        bool shouldInclude;
        if (sudahCheckIn) {
          // 🔧 FIX: sebelumnya kondisi ini cuma cek status BUKAN 'selesai' dkk,
          // jadi item yang check-in TEPAT WAKTU dan masih live (status='check_in')
          // ikut kehitung "terlambat" padahal check-in-nya nggak telat sama sekali.
          // Sekarang wajib cek dulu apakah checkInTime beneran lewat batas toleransi.
          const toleransiTelatCheckIn = Duration(minutes: 15); // sesuaikan kalau beda dari kebijakan kamu
          final batasTelatCheckIn = jamMulai.add(toleransiTelatCheckIn);
          final checkInTerlambat =
              item.checkInTime != null && item.checkInTime!.isAfter(batasTelatCheckIn);

          shouldInclude = checkInTerlambat &&
              item.absensiStatus != 'selesai' &&
              item.absensiStatus != 'check_out' &&
              item.absensiStatus != 'selesai_terlambat' &&
              item.absensiStatus != 'tidak_lembur' &&
              item.absensiStatus != 'expired';
        } else {
          final isLate =
              now.isAfter(batasNormal) && now.isBefore(batasExpired);
          final isPending = !item.isAbsensiResolved;
          shouldInclude = isLate && isPending;
        }

        if (shouldInclude) {
          lateList.add(item);
        }
      }

      lateList.sort((a, b) => a.tanggal.compareTo(b.tanggal));

      if (mounted) {
        setState(() {
          _lateOvertimeList = lateList;
          _isLoadingLateList = false;
        });
      }
    } catch (e) {
      debugPrint('❌ _loadLateOvertimeList ERROR: $e');
      if (mounted) {
        setState(() {
          _lateOvertimeList = [];
          _isLoadingLateList = false;
        });
      }
    }
  }

  /// FALLBACK: Cari lembur terlambat
  Future<OvertimeHistory?> _tryLoadLateOvertime(String userId) async {
    try {
      final now = DateTime.now();
      final allPending = await _absensiService.getLemburNeedAbsensi(
          userId: userId, userRole: 'mitra');

      for (final item in allPending) {
        if (item.isCancelled == true ||
            item.statusPengajuan == 'dibatalkan' ||
            item.statusPengajuan == 'cancelled') continue;

        final partsMulai = item.jamMulai.split(':');
        final partsSelesai = item.jamSelesai.split(':');
        if (partsMulai.length != 2 || partsSelesai.length != 2) continue;

        var jamSelesai = DateTime(
            item.tanggal.year,
            item.tanggal.month,
            item.tanggal.day,
            int.parse(partsSelesai[0]),
            int.parse(partsSelesai[1]));
        final jamMulai = DateTime(
            item.tanggal.year,
            item.tanggal.month,
            item.tanggal.day,
            int.parse(partsMulai[0]),
            int.parse(partsMulai[1]));
        if (jamSelesai.isBefore(jamMulai))
          jamSelesai = jamSelesai.add(const Duration(days: 1));

        final batasNormal = jamSelesai.add(const Duration(minutes: 30));
        final batasExpired = jamSelesai.add(const Duration(days: 3));
        final isLate =
            now.isAfter(batasNormal) && now.isBefore(batasExpired);

        if (isLate && !item.isAbsensiResolved) return item;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// HANDLER: Pilih lembur terlambat dari tab
  Future<void> _selectLateOvertime(OvertimeHistory item) async {
    _checkOutTimer?.cancel();
    _checkOutTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    _hasInitCheckRun = false;
    _isAutoStopped = false;
    _isExpired = false;
    _isLateCheckOut = false;
    _showCheckOutKonfirmasiForm = false;
    _alasanCheckOutController.clear();
    _buktiFotoCheckOutTerlambat = null;
    _isLemburLintasHari = false;
    _showKonfirmasiForm = false;
    _canConfirm = false;
    _melakukanLembur = null;
    _alasanController.clear();
    _buktiFotoTerlambat = null;
    _capturedImage = null;
    _previewFile = null;
    _locationValid = false;
    _locationVerified = false;
    _hasAttemptedRetry = false;
    _hasCheckedIn = false;
    _isCheckInFinalized = false;
    _hasCheckedOut = false;
    _canCheckOut = false;
    _hideLocationVerification = false;
    _isNormalAbsensiReady = true;
    _isLateOvertime = true;
    _isViewingLateOvertime = true;
    _konfirmasiError = null;

    setState(() {
      _overtimeItem = item;
      _isLoading = false;
      _statusMessage =
          '⚠️ Lembur Terlambat - ${DateFormat('dd MMM yyyy').format(item.tanggal)}';
    });

    await _initCheck();
  }

  /// HANDLER: Kembali ke absensi normal
  Future<void> _switchToNormalAbsensi() async {
    _checkOutTimer?.cancel();
    _checkOutTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    _hasInitCheckRun = false;
    _isAutoStopped = false;
    _isExpired = false;
    _isLateCheckOut = false;
    _showCheckOutKonfirmasiForm = false;
    _alasanCheckOutController.clear();
    _buktiFotoCheckOutTerlambat = null;
    _isLemburLintasHari = false;
    _showKonfirmasiForm = false;
    _canConfirm = false;
    _melakukanLembur = null;
    _alasanController.clear();
    _buktiFotoTerlambat = null;
    _capturedImage = null;
    _previewFile = null;
    _locationValid = false;
    _locationVerified = false;
    _hasCheckedIn = false;
    _isCheckInFinalized = false;
    _hasCheckedOut = false;
    _canCheckOut = false;
    _isLateOvertime = false;
    _isViewingLateOvertime = false;
    _isNormalAbsensiReady = false;
    _hideLocationVerification = true;
    _konfirmasiError = null;

    setState(() {
      _currentTabIndex = 0;
      _isLoading = true;
      _statusMessage = 'Memuat data lembur normal...';
    });

    await _loadOvertimeData();
  }

  void _backToLateOvertimeList() {
    _checkOutTimer?.cancel();
    _checkOutTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    setState(() {
      _isViewingLateOvertime = false;
      _overtimeItem = null;
      _hasCheckedIn = false;
      _isCheckInFinalized = false;
      _hasCheckedOut = false;
      _canCheckOut = false;
      _showKonfirmasiForm = false;
      _canConfirm = false;
      _melakukanLembur = null;
      _capturedImage = null;
      _previewFile = null;
      _locationValid = false;
      _locationVerified = false;
      _hasAttemptedRetry = false;
      _hasInitCheckRun = false;
      _konfirmasiError = null;
    });
  }

  // ═══════════════════════════════════════════════════════
  // INIT CHECK (DETEKSI KETERLAMBATAN)
  // ═══════════════════════════════════════════════════════

  Future<void> _initCheck() async {
    if (_hasCheckedIn || _isCheckInFinalized || _overtimeItem == null) return;
    if (_hasInitCheckRun) return;

    debugPrint('🔍 _initCheck: STARTING (isLateOvertime=$_isLateOvertime)');

    setState(() {
      _isCheckingStatus = true;
      _statusMessage = 'Mengecek status absensi...';
    });

    try {
      final now = DateTime.now();
      final tgl = _overtimeItem!.tanggal;
      final partsMulai = _overtimeItem!.jamMulai.split(':');
      final partsSelesai = _overtimeItem!.jamSelesai.split(':');

      if (partsMulai.length == 2 && partsSelesai.length == 2) {
        final jamMulai = DateTime(tgl.year, tgl.month, tgl.day,
            int.parse(partsMulai[0]), int.parse(partsMulai[1]));
        var jamSelesai = DateTime(tgl.year, tgl.month, tgl.day,
            int.parse(partsSelesai[0]), int.parse(partsSelesai[1]));
        if (jamSelesai.isBefore(jamMulai))
          jamSelesai = jamSelesai.add(const Duration(days: 1));

        final earliestCheckIn = jamMulai.subtract(const Duration(minutes: 30));
        final batasNormal = jamSelesai.add(const Duration(minutes: 30));

        Map<String, dynamic>? firestoreStatus;
        try {
          firestoreStatus =
              await _absensiService.cekStatusKeterlambatan(_overtimeItem!.id);
        } catch (e) {
          debugPrint('⚠️ Gagal ambil status Firestore: $e');
        }

        if (!mounted || _hasCheckedIn) return;

        final isLateFromFirestore = firestoreStatus?['isLate'] == true ||
            firestoreStatus?['canConfirm'] == true;
        final isAlreadyResolved =
            firestoreStatus?['isAlreadyResolved'] == true;

        final effectiveIsLate = _isLateOvertime || isLateFromFirestore;

        if (isAlreadyResolved) {
          _handleAlreadyResolved(firestoreStatus);
          return;
        }

        if (effectiveIsLate) {
          _handleLateOvertimeFlow();
        } else {
          _handleNormalOvertimeFlow(
              now, earliestCheckIn, batasNormal, firestoreStatus);
        }
      }
    } catch (e) {
      debugPrint('❌ _initCheck ERROR: $e');
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
          _canConfirm = false;
          _showKonfirmasiForm = false;
          _statusMessage = 'Gagal cek status';
        });
      }
    }
  }

  void _handleLateOvertimeFlow() {
    setState(() {
      _isCheckingStatus = false;
      _hasInitCheckRun = true;
      _canConfirm = true;
      _locationValid = true;
      _locationVerified = true;
      _hideLocationVerification = false;
      _isNormalAbsensiReady = false;
      _statusMessage = '⚠️ ANDA TERLAMBAT!';
      _errorDetail = 'Konfirmasi apakah Anda tetap melakukan lembur';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showLateOvertimePopup();
      }
    });
  }

  void _showLateOvertimePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '⚠️ Anda Terlambat!',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    '📋 Anda belum melakukan absensi dan sudah melewati batas waktu.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Silakan konfirmasi apakah Anda tetap melakukan lembur atau tidak.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(Maksimal 3 hari setelah jam selesai)',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (_errorDetail != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorDetail!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: Text(
              'Nanti Saja',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _showKonfirmasiForm = true);
            },
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text(
              'Konfirmasi Sekarang',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNormalOvertimeFlow(DateTime now, DateTime earliestCheckIn,
      DateTime batasNormal, Map<String, dynamic>? firestoreStatus) {
    if (now.isBefore(earliestCheckIn)) {
      final diff = earliestCheckIn.difference(now);
      setState(() {
        _isCheckingStatus = false;
        _hasInitCheckRun = true;
        _hideLocationVerification = true;
        _isNormalAbsensiReady = false;
        _statusMessage = '⏰ Belum waktunya absen';
        _errorDetail =
            'Tersedia dalam ${diff.inHours}j ${diff.inMinutes.remainder(60)}m';
      });
      return;
    }

    if (now.isAfter(earliestCheckIn) && now.isBefore(batasNormal)) {
      setState(() {
        _isCheckingStatus = false;
        _hasInitCheckRun = true;
        _canConfirm = false;
        _showKonfirmasiForm = false;
        _hideLocationVerification = false;
        _isNormalAbsensiReady = true;
        _statusMessage = '✅ Masih dalam masa absensi normal';
      });

      if (!_locationVerified) {
        _startLocationVerification();
      } else {
        setState(() {
          _locationValid = true;
          _statusMessage = '✅ Lokasi terverifikasi. Silakan ambil selfie.';
        });
      }
      return;
    }

    setState(() {
      _isCheckingStatus = false;
      _hasInitCheckRun = true;
      _statusMessage = '❌ Waktu absensi sudah kadaluarsa';
    });
  }

  void _handleAlreadyResolved(Map<String, dynamic>? firestoreStatus) {
    final rs = firestoreStatus?['currentStatus'] as String?;

    final bool isCompleted = rs == 'selesai' ||
        rs == 'check_out' ||
        rs == 'selesai_terlambat';
    final bool isCheckedIn = rs == 'check_in' || rs == 'sudah_absen';

    setState(() {
      _isCheckingStatus = false;
      _hasInitCheckRun = true;
      _canConfirm = false;
      _showKonfirmasiForm = false;
      _statusMessage = firestoreStatus?['message'] ?? 'Absensi sudah diproses';

      if (isCheckedIn) {
        _hasCheckedIn = true;
        _isCheckInFinalized = true;
        _checkInTime = DateTime.now();
        _locationValid = true;
        _locationVerified = true;
      } else if (isCompleted) {
        _hasCheckedOut = true;
        _hasCheckedIn = false;
        _isCheckInFinalized = false;
        _canCheckOut = false;
      }
    });

    if (isCheckedIn) {
      // 🔥 FIX: cek expired DULU sebelum start live location (pola sama
      // seperti di _loadOvertimeData), dan panggil di luar setState()
      // karena _startLiveLocation() adalah Future.
      final overtime = _overtimeItem;
      final isExpired =
          overtime != null && _isOvertimeCheckOutExpired(overtime);

      if (isExpired) {
        debugPrint('⏰ _handleAlreadyResolved: sudah expired - skip live location');
        _stopLiveLocation();
      } else {
        _startLiveLocation();
      }
      _checkCheckOutAvailability();
    } else if (isCompleted) {
      _stopLiveLocation();
    }
  }

  // ═══════════════════════════════════════════════════════
  // VERIFIKASI LOKASI
  // ═══════════════════════════════════════════════════════

  Future<void> _startLocationVerification() async {
    if (_overtimeItem == null || _isLoadingLocation || _isSubmitting) return;
    if (_hideLocationVerification) return;

    setState(() {
      _isLoadingLocation = true;
      _statusMessage = 'Memverifikasi lokasi...';
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showSnackBar('GPS tidak aktif', Colors.orange);
        setState(() => _isLoadingLocation = false);
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showSnackBar('Izin lokasi diperlukan', Colors.red);
        setState(() => _isLoadingLocation = false);
        return;
      }

      final pos = await _locationValidator.getCurrentLocation().timeout(
            const Duration(seconds: 25),
            onTimeout: () => throw TimeoutException('Timeout'),
          );

      if (pos == null) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      _currentPosition = pos;

      try {
        _currentAddress = await _locationValidator
            .getAddressFromCoordinates(pos.latitude, pos.longitude)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        _currentAddress = 'Alamat tidak tersedia';
      }

      final val = await _locationValidator
          .validateLocation(
            currentLat: pos.latitude,
            currentLng: pos.longitude,
            overtimeItem: _overtimeItem!,
          )
          .timeout(const Duration(seconds: 15));

      _locationValid = val['valid'] == true;
      _distanceInMeters = val['distance'] as double?;
      _maxRadius = val['max_radius'] as double?;
      if (_locationValid) _locationVerified = true;

      if (!mounted) return;

      setState(() {
        _isLoadingLocation = false;
        _statusMessage = _locationValid
            ? '✅ Lokasi valid! Silakan ambil selfie.'
            : '❌ Anda berada di luar radius absensi.';
        _errorDetail = !_locationValid && _distanceInMeters != null
            ? 'Jarak: ${_distanceInMeters!.toStringAsFixed(0)}m'
            : null;
      });
    } on TimeoutException {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showSnackBar('Timeout. Coba lagi.', Colors.orange);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _statusMessage = 'Gagal verifikasi lokasi';
          _errorDetail = e.toString();
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // AMBIL SELFIE (CHECK-IN)
  // ═══════════════════════════════════════════════════════

  Future<void> _takeSelfie() async {
    if (_isTakingPhoto || _isSubmitting) return;
    if (!_locationValid && !_hasCheckedIn) {
      _showSnackBar('Lokasi tidak valid', Colors.red);
      return;
    }

    setState(() {
      _isTakingPhoto = true;
      _statusMessage = 'Membuka kamera...';
    });

    try {
      XFile? photo;
      try {
        photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 60,
          maxWidth: 1280,
          maxHeight: 1280,
        );
      } catch (_) {
        photo = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 60,
          maxWidth: 1280,
          maxHeight: 1280,
        );
      }

      if (!mounted) return;

      if (photo == null) {
        setState(() => _isTakingPhoto = false);
        _showSnackBar('Foto dibatalkan', Colors.grey);
        return;
      }

      final file = File(photo.path);
      if (!await file.exists()) throw Exception('File tidak ditemukan');

      await _cleanupPreviewFile();

      setState(() {
        _capturedImage = photo;
        _previewFile = file;
        _isTakingPhoto = false;
        _statusMessage = '📸 Foto berhasil! Silakan submit absensi.';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isTakingPhoto = false);
        _showSnackBar('Gagal: $e', Colors.red);
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // SUBMIT ABSENSI (CHECK-IN)
  // ═══════════════════════════════════════════════════════

  Future<void> _submitAbsensi() async {
    if (_isSubmitting ||
        _capturedImage == null ||
        _currentPosition == null ||
        _overtimeItem == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showSnackBar('❌ Tidak ada koneksi internet', Colors.red);
      return;
    }

    File? tempFile;

    try {
      setState(() {
        _isSubmitting = true;
        _statusMessage = '🔄 Menyiapkan upload...';
      });

      final workerName = await _getWorkerName();

      Uint8List wb;
      try {
        wb = await _watermarkService
            .addWatermark(
              imagePath: _capturedImage!.path,
              latitude: _currentPosition!.latitude,
              longitude: _currentPosition!.longitude,
              address: _currentAddress ?? 'Lokasi Absensi',
              timestamp: DateTime.now(),
              workerName: workerName,
              customLabel: _isLateOvertime
                  ? 'CHECK-IN LEMBUR TERLAMBAT PGE'
                  : 'CHECK-IN LEMBUR PGE',
            )
            .timeout(const Duration(seconds: 15));
      } catch (watermarkError) {
        debugPrint('⚠️ Watermark gagal: $watermarkError');
        try {
          wb = await _watermarkService
              .addWatermark(
                imagePath: _capturedImage!.path,
                latitude: _currentPosition!.latitude,
                longitude: _currentPosition!.longitude,
                address: _currentAddress ?? 'Lokasi Absensi',
                timestamp: DateTime.now(),
                workerName: workerName,
                customLabel: _isLateOvertime
                    ? 'CHECK-IN LEMBUR TERLAMBAT PGE'
                    : 'CHECK-IN LEMBUR PGE',
              )
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          throw Exception('Gagal menambahkan watermark: $e');
        }
      }

      if (wb.isEmpty) throw Exception('Data foto kosong');
      if (!mounted) return;

      final dir = await getTemporaryDirectory();
      final uid = 'ci_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
      tempFile = File('${dir.path}/absensi_$uid.jpg');
      await tempFile.writeAsBytes(wb);
      if (!mounted) return;

      _updateStatus('☁️ Mengupload foto...');
      String? url;
      for (int i = 1; i <= _maxRetries + 1; i++) {
        try {
          final r = await _cloudinaryService
              .uploadFoto(
                photoFile: tempFile,
                fileName: uid,
                lemburId: _overtimeItem!.id,
              )
              .timeout(const Duration(seconds: 60));
          if (r['success'] == true) {
            url = r['url'] as String;
            break;
          }
        } catch (uploadError) {
          debugPrint('⚠️ Upload attempt $i gagal: $uploadError');
          if (i > _maxRetries) rethrow;
          await Future.delayed(Duration(seconds: i * 2));
        }
      }
      if (url == null)
        throw Exception('Gagal upload setelah $_maxRetries percobaan');
      if (!mounted) return;

      _updateStatus('📝 Menyimpan data...');
      final result = await _absensiService.submitAbsensi(
        docId: _overtimeItem!.id,
        fotoUrl: url,
        userId: user.uid,
        userName: workerName,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: _currentAddress,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final t = DateTime.now();
        _locationVerified = true;
        final bool wasLateOvertime = _isLateOvertime;

        setState(() {
          _isSubmitting = false;
          _hasCheckedIn = true;
          _isCheckInFinalized = true;
          _checkInTime = t;
          _locationValid = true;
          _capturedImage = null;
          _previewFile = null;
          _canConfirm = false;
          _showKonfirmasiForm = false;
          _isCheckingStatus = false;
          _statusMessage = '✅ Check-in berhasil!';
          _isLateOvertime = false;
        });

        if (wasLateOvertime) {
          await _loadLateOvertimeList(user.uid);
        }

        _showSnackBar('✅ Check-in berhasil! 💪', Colors.green);
        await _startLiveLocation();
        _checkCheckOutAvailability();
        await _cleanupPreviewFile();
      } else {
        throw Exception(result['message'] ?? 'Gagal menyimpan');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnackBar('❌ $e', Colors.red);
      }
    } finally {
      try {
        if (tempFile != null && await tempFile.exists())
          await tempFile.delete();
      } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════════════════
  // CHECK-OUT PHOTO
  // ═══════════════════════════════════════════════════════

  Future<void> _takeCheckOutPhoto() async {
    if (_isTakingPhoto || _isCheckingOut) return;

    setState(() {
      _isTakingPhoto = true;
      _statusMessage = 'Membuka kamera...';
    });

    try {
      XFile? photo;
      try {
        photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 60,
          maxWidth: 1280,
          maxHeight: 1280,
        );
      } catch (_) {
        photo = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 60,
        );
      }

      if (!mounted) return;
      if (photo == null) {
        setState(() => _isTakingPhoto = false);
        return;
      }

      final file = File(photo.path);
      await _cleanupCheckOutPreviewFile();

      setState(() {
        _checkOutImage = photo;
        _checkOutPreviewFile = file;
        _isTakingPhoto = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  Future<bool> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    final hasConnection = !result.contains(ConnectivityResult.none);
    if (!hasConnection && mounted) {
      _showSnackBar('❌ Tidak ada koneksi internet', Colors.red);
    }
    return hasConnection;
  }

  // ═══════════════════════════════════════════════════════
  // PERFORM CHECK-OUT
  // ═══════════════════════════════════════════════════════

  Future<void> _performCheckOut() async {
    if (_isCheckingOut ||
        _hasCheckedOut ||
        _checkOutImage == null ||
        _overtimeItem == null) return;

    if (!await _checkConnectivity()) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Check-Out Lembur',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Apakah Anda yakin ingin check-out?\n\nLive location akan dihentikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Check-Out'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() {
      _isCheckingOut = true;
      _statusMessage = '🔄 Menyiapkan check-out...';
    });

    File? tempFile;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      _updateStatus('📍 Mendapatkan lokasi terbaru...');
      await _refreshLocationForCheckOut();

      final workerName = await _getWorkerName();

      _updateStatus('🖼️ Menambahkan watermark...');
      Uint8List wb;
      try {
        wb = await _watermarkService
            .addWatermark(
              imagePath: _checkOutImage!.path,
              latitude: _currentPosition?.latitude ?? 0,
              longitude: _currentPosition?.longitude ?? 0,
              address: _currentAddress ?? 'Lokasi Check-Out',
              timestamp: DateTime.now(),
              workerName: workerName,
              customLabel: 'CHECK-OUT LEMBUR PGE',
            )
            .timeout(const Duration(seconds: 15));
      } catch (watermarkError) {
        debugPrint('⚠️ Watermark retry: $watermarkError');
        try {
          wb = await _watermarkService
              .addWatermark(
                imagePath: _checkOutImage!.path,
                latitude: _currentPosition?.latitude ?? 0,
                longitude: _currentPosition?.longitude ?? 0,
                address: _currentAddress ?? 'Lokasi Check-Out',
                timestamp: DateTime.now(),
                workerName: workerName,
                customLabel: 'CHECK-OUT LEMBUR PGE',
              )
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          throw Exception('Gagal menambahkan watermark: $e');
        }
      }

      final dir = await getTemporaryDirectory();
      final uid = 'co_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
      tempFile = File('${dir.path}/$uid.jpg');
      await tempFile.writeAsBytes(wb);

      _updateStatus('☁️ Mengupload foto...');
      String? url;
      for (int i = 1; i <= _maxRetries + 1; i++) {
        try {
          final r = await _cloudinaryService
              .uploadFoto(
                photoFile: tempFile,
                fileName: uid,
                lemburId: _overtimeItem!.id,
              )
              .timeout(const Duration(seconds: 60));
          if (r['success'] == true) {
            url = r['url'] as String;
            break;
          }
        } catch (uploadError) {
          debugPrint('⚠️ Upload attempt $i gagal: $uploadError');
          if (i > _maxRetries) rethrow;
          await Future.delayed(Duration(seconds: i * 2));
        }
      }
      if (url == null)
        throw Exception('Upload gagal setelah $_maxRetries percobaan');

      _updateStatus('📝 Menyimpan data...');
      await _stopLiveLocation();

      _checkOutTimer?.cancel();
      _checkOutTimer = null;
      _countdownTimer?.cancel();
      _countdownTimer = null;
      _autoStopTimer?.cancel();
      _autoStopTimer = null;

      await _absensiService.submitCheckOut(
        docId: _overtimeItem!.id,
        userId: user.uid,
        userName: workerName,
        fotoUrl: url,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        address: _currentAddress,
      );

      if (mounted) {
        setState(() {
          _isCheckingOut = false;
          _hasCheckedOut = true;
          _canCheckOut = false;
          _locationVerified = false;
          _isCheckInFinalized = false;
          _statusMessage = '✅ Check-out berhasil!';
        });
        _showSnackBar('✅ Check-out berhasil! 🎉', Colors.green);
      }
    } catch (e) {
      debugPrint('❌ Check-out error: $e');
      if (mounted) {
        setState(() => _isCheckingOut = false);
        _showSnackBar('❌ $e', Colors.red);
      }
    } finally {
      try {
        if (tempFile != null && await tempFile.exists())
          await tempFile.delete();
      } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════════════════
  // KONFIRMASI KETERLAMBATAN
  // ═══════════════════════════════════════════════════════

  Future<void> _pickBuktiFoto() async {
    if (_isUploadingBukti || _isSubmitting) return;

    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Pilih Sumber Foto'),
          content:
              const Text('Ambil foto dari kamera atau pilih dari gallery?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
                child: const Text('📁 Gallery')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white),
              child: const Text('📸 Kamera'),
            ),
          ],
        ),
      );

      if (source == null || !mounted) return;

      XFile? photo;
      try {
        photo = await _imagePicker.pickImage(
            source: source, imageQuality: 60, maxWidth: 1280, maxHeight: 1280);
      } catch (e) {
        if (source == ImageSource.camera) {
          photo = await _imagePicker.pickImage(
              source: ImageSource.gallery, imageQuality: 60);
        } else {
          rethrow;
        }
      }

      if (photo != null && mounted) {
        await _cleanupBuktiFoto();
        setState(() => _buktiFotoTerlambat = File(photo!.path));
        _showSnackBar('✅ Foto bukti berhasil diambil!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('❌ Gagal ambil foto: $e', Colors.red);
    }
  }

  Future<void> _submitKonfirmasi() async {
    setState(() => _konfirmasiError = null);

    if (_melakukanLembur == null) {
      setState(() => _konfirmasiError = '⚠️ Pilih apakah Anda melakukan lembur');
      return;
    }
    if (_alasanController.text.trim().isEmpty) {
      setState(() => _konfirmasiError = '⚠️ Alasan wajib diisi');
      return;
    }
    if (_alasanController.text.trim().length < 10) {
      setState(() =>
          _konfirmasiError =
          '⚠️ Alasan minimal 10 karakter (${_alasanController.text.trim().length}/10)');
      return;
    }
    if (_melakukanLembur == true && _buktiFotoTerlambat == null) {
      setState(() => _konfirmasiError = '⚠️ Foto bukti lembur wajib diupload!');
      return;
    }

    if (!await _checkConnectivity()) return;

    setState(() {
      _isSubmitting = true;
      _isUploadingBukti = true;
      _statusMessage = '🔄 Memproses...';
    });

    try {
      String? fotoUrl;
      if (_melakukanLembur == true && _buktiFotoTerlambat != null) {
        _updateStatus('☁️ Mengupload foto bukti...');
        final workerName = await _getWorkerName();

        Uint8List wb;
        try {
          wb = await _watermarkService
              .addWatermark(
                imagePath: _buktiFotoTerlambat!.path,
                latitude: _currentPosition?.latitude ?? 0,
                longitude: _currentPosition?.longitude ?? 0,
                address: _currentAddress ?? 'Lokasi Absensi',
                timestamp: DateTime.now(),
                workerName: workerName,
                customLabel: 'BUKTI LEMBUR TERLAMBAT',
              )
              .timeout(const Duration(seconds: 15));
        } catch (watermarkError) {
          try {
            wb = await _watermarkService
                .addWatermark(
                  imagePath: _buktiFotoTerlambat!.path,
                  latitude: _currentPosition?.latitude ?? 0,
                  longitude: _currentPosition?.longitude ?? 0,
                  address: _currentAddress ?? 'Lokasi Absensi',
                  timestamp: DateTime.now(),
                  workerName: workerName,
                  customLabel: 'BUKTI LEMBUR TERLAMBAT',
                )
                .timeout(const Duration(seconds: 10));
          } catch (e) {
            throw Exception('Gagal menambahkan watermark: $e');
          }
        }

        final dir = await getTemporaryDirectory();
        final tempBukti = File(
            '${dir.path}/bukti_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempBukti.writeAsBytes(wb);

        for (int i = 1; i <= _maxRetries + 1; i++) {
          try {
            final r = await _cloudinaryService
                .uploadFoto(
                  photoFile: tempBukti,
                  fileName:
                      'bukti_${DateTime.now().millisecondsSinceEpoch}',
                  lemburId: _overtimeItem!.id,
                )
                .timeout(const Duration(seconds: 60));
            if (r['success'] == true) {
              fotoUrl = r['url'] as String;
              break;
            }
          } catch (uploadError) {
            if (i > _maxRetries) rethrow;
            await Future.delayed(Duration(seconds: i * 2));
          }
        }
        try {
          if (await tempBukti.exists()) await tempBukti.delete();
        } catch (_) {}
        if (fotoUrl == null)
          throw Exception(
              'Gagal upload foto bukti setelah $_maxRetries percobaan');
      }

      _updateStatus('📝 Menyimpan konfirmasi...');
      final user = FirebaseAuth.instance.currentUser;
      final workerName = await _getWorkerName();
      final result = await _absensiService.konfirmasiKeterlambatan(
        lemburId: _overtimeItem!.id,
        userId: user?.uid ?? '',
        userName: workerName,
        melakukanLembur: _melakukanLembur!,
        alasan: _alasanController.text.trim(),
        buktiFotoUrl: fotoUrl,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final t = DateTime.now();
        final bool wasMelakukanLembur = _melakukanLembur == true;
        if (wasMelakukanLembur) {
          _locationVerified = true;
          setState(() {
            _hasCheckedIn = true;
            _isCheckInFinalized = true;
            _checkInTime = t;
            _locationValid = true;
            _isLateOvertime = false;
          });
          await _startLiveLocation();
          _checkCheckOutAvailability();
        }
        setState(() {
          _isSubmitting = false;
          _isUploadingBukti = false;
          _showKonfirmasiForm = false;
          _melakukanLembur = null;
          _alasanController.clear();
          _buktiFotoTerlambat = null;
          _canConfirm = false;
          _statusMessage =
              wasMelakukanLembur ? '✅ Check-in berhasil!' : '✅ Konfirmasi berhasil!';
        });
        if (user != null) await _loadLateOvertimeList(user.uid);
      } else {
        throw Exception(result['message'] ?? 'Gagal');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingBukti = false;
        });
        _showSnackBar('❌ $e', Colors.red);
      }
    }
  }

  void _batalKonfirmasi() {
    setState(() {
      _showKonfirmasiForm = false;
      _melakukanLembur = null;
      _alasanController.clear();
      _buktiFotoTerlambat = null;
      _konfirmasiError = null;
      _statusMessage = '⚠️ Anda terlambat!';
    });
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 BARU: KONFIRMASI KETERLAMBATAN CHECK-OUT
  // ═══════════════════════════════════════════════════════

  Future<void> _pickBuktiFotoCheckOut() async {
    if (_isUploadingBuktiCheckOut || _isSubmittingCheckOutTerlambat) return;

    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Pilih Sumber Foto'),
          content:
              const Text('Ambil foto dari kamera atau pilih dari gallery?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
                child: const Text('📁 Gallery')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white),
              child: const Text('📸 Kamera'),
            ),
          ],
        ),
      );

      if (source == null || !mounted) return;

      XFile? photo;
      try {
        photo = await _imagePicker.pickImage(
            source: source, imageQuality: 60, maxWidth: 1280, maxHeight: 1280);
      } catch (e) {
        if (source == ImageSource.camera) {
          photo = await _imagePicker.pickImage(
              source: ImageSource.gallery, imageQuality: 60);
        } else {
          rethrow;
        }
      }

      if (photo != null && mounted) {
        setState(() => _buktiFotoCheckOutTerlambat = File(photo!.path));
        _showSnackBar('✅ Foto bukti berhasil diambil!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('❌ Gagal ambil foto: $e', Colors.red);
    }
  }

  Future<void> _submitKonfirmasiCheckOutTerlambat() async {
    setState(() => _konfirmasiCheckOutError = null);

    if (_alasanCheckOutController.text.trim().isEmpty) {
      setState(() =>
          _konfirmasiCheckOutError = '⚠️ Alasan wajib diisi');
      return;
    }
    if (_alasanCheckOutController.text.trim().length < 10) {
      setState(() => _konfirmasiCheckOutError =
          '⚠️ Alasan minimal 10 karakter (${_alasanCheckOutController.text.trim().length}/10)');
      return;
    }
    if (_overtimeItem == null) return;

    if (!await _checkConnectivity()) return;

    setState(() {
      _isSubmittingCheckOutTerlambat = true;
      _isUploadingBuktiCheckOut = _buktiFotoCheckOutTerlambat != null;
      _statusMessage = '🔄 Memproses konfirmasi checkout...';
    });

    try {
      String? fotoUrl;
      if (_buktiFotoCheckOutTerlambat != null) {
        _updateStatus('☁️ Mengupload foto bukti...');
        final workerName = await _getWorkerName();

        Uint8List wb;
        try {
          wb = await _watermarkService
              .addWatermark(
                imagePath: _buktiFotoCheckOutTerlambat!.path,
                latitude: _currentPosition?.latitude ?? 0,
                longitude: _currentPosition?.longitude ?? 0,
                address: _currentAddress ?? 'Lokasi Absensi',
                timestamp: DateTime.now(),
                workerName: workerName,
                customLabel: 'BUKTI CHECKOUT TERLAMBAT',
              )
              .timeout(const Duration(seconds: 15));
        } catch (watermarkError) {
          try {
            wb = await _watermarkService
                .addWatermark(
                  imagePath: _buktiFotoCheckOutTerlambat!.path,
                  latitude: _currentPosition?.latitude ?? 0,
                  longitude: _currentPosition?.longitude ?? 0,
                  address: _currentAddress ?? 'Lokasi Absensi',
                  timestamp: DateTime.now(),
                  workerName: workerName,
                  customLabel: 'BUKTI CHECKOUT TERLAMBAT',
                )
                .timeout(const Duration(seconds: 10));
          } catch (e) {
            throw Exception('Gagal menambahkan watermark: $e');
          }
        }

        final dir = await getTemporaryDirectory();
        final tempBukti = File(
            '${dir.path}/bukti_checkout_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempBukti.writeAsBytes(wb);

        for (int i = 1; i <= _maxRetries + 1; i++) {
          try {
            final r = await _cloudinaryService
                .uploadFoto(
                  photoFile: tempBukti,
                  fileName:
                      'bukti_checkout_${DateTime.now().millisecondsSinceEpoch}',
                  lemburId: _overtimeItem!.id,
                )
                .timeout(const Duration(seconds: 60));
            if (r['success'] == true) {
              fotoUrl = r['url'] as String;
              break;
            }
          } catch (uploadError) {
            if (i > _maxRetries) rethrow;
            await Future.delayed(Duration(seconds: i * 2));
          }
        }
        try {
          if (await tempBukti.exists()) await tempBukti.delete();
        } catch (_) {}
        if (fotoUrl == null) {
          throw Exception(
              'Gagal upload foto bukti setelah $_maxRetries percobaan');
        }
      }

      _updateStatus('📝 Menyimpan konfirmasi...');
      final user = FirebaseAuth.instance.currentUser;
      final workerName = await _getWorkerName();
      final result = await _absensiService.konfirmasiKeterlambatanCheckOut(
        lemburId: _overtimeItem!.id,
        userId: user?.uid ?? '',
        userName: workerName,
        alasan: _alasanCheckOutController.text.trim(),
        buktiFotoUrl: fotoUrl,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        address: _currentAddress,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        await _liveLocationManager.stopTracking();
        setState(() {
          _isSubmittingCheckOutTerlambat = false;
          _isUploadingBuktiCheckOut = false;
          _isLateCheckOut = false;
          _hasCheckedOut = true;
          _canCheckOut = false;
          _alasanCheckOutController.clear();
          _buktiFotoCheckOutTerlambat = null;
          _statusMessage = '✅ Konfirmasi checkout terlambat berhasil!';
        });
      } else {
        throw Exception(result['message'] ?? 'Gagal');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmittingCheckOutTerlambat = false;
          _isUploadingBuktiCheckOut = false;
        });
        _showSnackBar('❌ $e', Colors.red);
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // UI HELPERS
  // ═══════════════════════════════════════════════════════

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
            color == Colors.green ? Icons.check_circle : Icons.info,
            color: Colors.white,
            size: 20),
        const SizedBox(width: 12),
        Expanded(
            child: Text(msg,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.white))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _updateStatus(String msg, {String? errorDetail}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = msg;
      _errorDetail = errorDetail;
    });
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isSmall = w < 360;
        final hp = w * 0.04;
        final bp = MediaQuery.of(context).padding.bottom;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: _appBar(isSmall),
          body: SafeArea(
            child: Column(
              children: [
                if (_lateOvertimeList.isNotEmpty || _isViewingLateOvertime)
                  _tabBar(isSmall),
                if (_isLiveLocationActive &&
                    _hasCheckedIn &&
                    !_hasCheckedOut)
                  _liveLocationBanner(isSmall),
                Expanded(child: _body(isSmall: isSmall, hp: hp)),
                if (_hasCheckedIn && !_hasCheckedOut && _canCheckOut)
                  _checkOutSection(isSmall, bp),
                const MitraBottomNav(currentIndex: 1),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tabBar(bool isSmall) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_currentTabIndex == 0) return;
                _switchToNormalAbsensi();
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _currentTabIndex == 0
                          ? const Color(0xFF1A237E)
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.today,
                          size: isSmall ? 14 : 16,
                          color: _currentTabIndex == 0
                              ? const Color(0xFF1A237E)
                              : Colors.grey,
                        ),
                        SizedBox(width: isSmall ? 4 : 6),
                        Text(
                          'Absensi Normal',
                          style: GoogleFonts.poppins(
                            fontSize: isSmall ? 11 : 12,
                            fontWeight: _currentTabIndex == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _currentTabIndex == 0
                                ? const Color(0xFF1A237E)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (_hasUpcomingOvertime && _currentTabIndex == 0) ...[
                      SizedBox(height: 2),
                      Text(
                        '⏰ Belum waktunya',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.orange.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_currentTabIndex != 1) {
                  setState(() {
                    _currentTabIndex = 1;
                  });
                  if (_lateOvertimeList.isNotEmpty && !_isViewingLateOvertime) {
                    _selectLateOvertime(_lateOvertimeList.first);
                  }
                } else if (_isViewingLateOvertime) {
                  _backToLateOvertimeList();
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _currentTabIndex == 1
                          ? Colors.orange
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: isSmall ? 14 : 16,
                      color:
                          _currentTabIndex == 1 ? Colors.orange : Colors.grey,
                    ),
                    SizedBox(width: isSmall ? 4 : 6),
                    Text(
                      'Lembur Terlambat',
                      style: GoogleFonts.poppins(
                        fontSize: isSmall ? 11 : 12,
                        fontWeight: _currentTabIndex == 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _currentTabIndex == 1
                            ? Colors.orange
                            : Colors.grey,
                      ),
                    ),
                    if (_lateOvertimeList.isNotEmpty) ...[
                      SizedBox(width: isSmall ? 4 : 6),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_lateOvertimeList.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar(bool isSmall) {
    return AppBar(
      title: Text('Absensi Lembur',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: isSmall ? 16 : 18)),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
          icon: Icon(Icons.arrow_back, size: isSmall ? 20 : 24),
          onPressed: _goBack),
      actions: [
        IconButton(
            icon: Icon(Icons.close, size: isSmall ? 20 : 24),
            onPressed: _goBack)
      ],
    );
  }

  Widget _liveLocationBanner(bool isSmall) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 12 : 16, vertical: isSmall ? 8 : 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00C853), Color(0xFF00E676)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (_, v, __) => Container(
            width: (isSmall ? 8 : 10) * v,
            height: (isSmall ? 8 : 10) * v,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: BoxShape.circle),
          ),
        ),
        SizedBox(width: isSmall ? 8 : 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🟢 Live Location Aktif',
                    style: GoogleFonts.poppins(
                        fontSize: isSmall ? 10 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                Text('Durasi: ${_getLiveLocationDuration()}',
                    style: GoogleFonts.poppins(
                        fontSize: isSmall ? 8 : 9, color: Colors.white70)),
              ]),
        ),
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Hentikan Live Location?'),
              content: const Text('Live location akan berhenti.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal')),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _stopLiveLocation();
                    _showSnackBar(
                        'Live location dihentikan', Colors.orange);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Hentikan'),
                ),
              ],
            ),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 8 : 10, vertical: isSmall ? 3 : 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.stop_circle,
                  color: Colors.white, size: isSmall ? 14 : 16),
              SizedBox(width: isSmall ? 3 : 4),
              Text('Stop',
                  style: GoogleFonts.poppins(
                      fontSize: isSmall ? 10 : 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _body({required bool isSmall, required double hp}) {
    // 🔥 TAB LEMBUR TERLAMBAT
    if (_currentTabIndex == 1) {
      return _lateOvertimeTabContent(isSmall, hp);
    }

    // 🔥 STATE 0: ERROR
    if (_errorDetail != null &&
        _overtimeItem == null &&
        !_isLoading &&
        !_isCheckingStatus) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(hp * 1.5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isSmall ? 20 : 24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: isSmall ? 56 : 72,
                  color: Colors.red.shade300,
                ),
              ),
              SizedBox(height: isSmall ? 16 : 20),
              Text(
                '⚠️ Gagal Memuat Data',
                style: GoogleFonts.poppins(
                  fontSize: isSmall ? 17 : 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700,
                ),
              ),
              SizedBox(height: isSmall ? 8 : 10),
              Container(
                padding: EdgeInsets.all(isSmall ? 10 : 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorDetail!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 11 : 12,
                    color: Colors.red.shade600,
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: isSmall ? 20 : 24),
              ElevatedButton.icon(
                onPressed: () {
                  _errorDetail = null;
                  _hasInitCheckRun = false;
                  _loadOvertimeData();
                },
                icon: Icon(Icons.refresh, size: isSmall ? 18 : 20),
                label: Text(
                  'Coba Lagi',
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 24 : 32,
                    vertical: isSmall ? 12 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: isSmall ? 10 : 12),
              TextButton(
                onPressed: _goBack,
                child: Text(
                  'Kembali ke Dashboard',
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 12 : 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 🔥 STATE 1: LOADING
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A237E)),
            SizedBox(height: isSmall ? 12 : 16),
            Text(
              _statusMessage,
              style: GoogleFonts.poppins(
                fontSize: isSmall ? 13 : 14,
                color: Colors.grey.shade600,
              ),
            ),
            if (_errorDetail != null) ...[
              SizedBox(height: isSmall ? 6 : 8),
              Text(
                _errorDetail!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: isSmall ? 10 : 11,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // 🔥 STATE 2: TIDAK ADA JADWAL
    if (_overtimeItem == null && !_isExpired) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(hp * 1.5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isSmall ? 20 : 24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_empty,
                  size: isSmall ? 48 : 64,
                  color: Colors.grey.shade400,
                ),
              ),
              SizedBox(height: isSmall ? 12 : 16),
              Text(
                'Tidak Ada Jadwal Lembur',
                style: GoogleFonts.poppins(
                  fontSize: isSmall ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: isSmall ? 6 : 8),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: isSmall ? 12 : 14,
                  color: Colors.grey.shade500,
                ),
              ),
              SizedBox(height: isSmall ? 20 : 24),
              ElevatedButton.icon(
                onPressed: () {
                  _isCheckInFinalized = false;
                  _hasInitCheckRun = false;
                  _errorDetail = null;
                  _loadOvertimeData();
                },
                icon: Icon(Icons.refresh, size: isSmall ? 16 : 18),
                label: Text(
                  'Muat Ulang',
                  style: GoogleFonts.poppins(fontSize: isSmall ? 12 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 20 : 28,
                    vertical: isSmall ? 12 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: isSmall ? 8 : 10),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _currentTabIndex = 1;
                  });
                  if (_lateOvertimeList.isNotEmpty) {
                    _selectLateOvertime(_lateOvertimeList.first);
                  }
                },
                icon: Icon(
                  Icons.warning_amber_rounded,
                  size: isSmall ? 14 : 16,
                  color: Colors.orange,
                ),
                label: Text(
                  _lateOvertimeList.isNotEmpty
                      ? 'Cek ${_lateOvertimeList.length} Lembur Terlambat'
                      : 'Cek Lembur Terlambat',
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 11 : 12,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 🔥 STATE 2.5B: CHECKOUT TERLAMBAT - PERLU KONFIRMASI
    // Muncul begitu now lewat checkOutEnd (jamSelesai + 2 jam) tapi masih
    // dalam CHECKOUT_KONFIRMASI_GRACE_PERIOD. Beda dari STATE 2.5 EXPIRED
    // di bawah (yang dead-end, cuma "hubungi pengawas") — di sini user masih
    // bisa isi alasan keterlambatan checkout.
    if (_isLateCheckOut) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isSmall ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_off_outlined,
                      color: Colors.orange.shade700,
                      size: isSmall ? 28 : 32),
                  SizedBox(width: isSmall ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_statusMessage,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: isSmall ? 13 : 14,
                                color: Colors.orange.shade900)),
                        if (_errorDetail != null) ...[
                          const SizedBox(height: 4),
                          Text(_errorDetail!,
                              style: GoogleFonts.poppins(
                                  fontSize: isSmall ? 11 : 12,
                                  color: Colors.orange.shade700)),
                        ],
                        if (_batasKonfirmasiCheckOutLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                              'Batas konfirmasi: $_batasKonfirmasiCheckOutLabel WIB',
                              style: GoogleFonts.poppins(
                                  fontSize: isSmall ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade600)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmall ? 16 : 20),
            _checkOutKonfirmasiForm(isSmall),
            SizedBox(height: isSmall ? 20 : 24),
          ],
        ),
      );
    }

    // 🔥 STATE 2.5: EXPIRED (LEMBUR LINTAS HARI / KADALUARSA)
    if (_isExpired) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(hp * 1.5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isSmall ? 24 : 32),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_disabled,
                  size: isSmall ? 64 : 80,
                  color: Colors.orange.shade600,
                ),
              ),
              SizedBox(height: isSmall ? 20 : 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: isSmall ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              ),
              if (_errorDetail != null) ...[
                SizedBox(height: isSmall ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isSmall ? 12 : 14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    _errorDetail!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: isSmall ? 12 : 13,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
              SizedBox(height: isSmall ? 24 : 28),
              ElevatedButton.icon(
                onPressed: _goBack,
                icon: Icon(Icons.arrow_back, size: isSmall ? 18 : 20),
                label: Text(
                  'Kembali ke Dashboard',
                  style: GoogleFonts.poppins(fontSize: isSmall ? 13 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 24 : 32,
                    vertical: isSmall ? 14 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // STATE 3: MENGECEK STATUS
    if (_isCheckingStatus) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A237E)),
            SizedBox(height: isSmall ? 12 : 16),
            Text(
              'Mengecek status absensi...',
              style: GoogleFonts.poppins(
                fontSize: isSmall ? 13 : 14,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 10 : 12,
                vertical: isSmall ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: _isLateOvertime
                    ? Colors.orange.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isLateOvertime
                    ? '🔍 Memeriksa lembur terlambat...'
                    : '🔍 Memeriksa jadwal normal...',
                style: GoogleFonts.poppins(
                  fontSize: isSmall ? 10 : 11,
                  color: _isLateOvertime
                      ? Colors.orange.shade700
                      : Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_debugKonfirmasiStatus.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                _debugKonfirmasiStatus,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // STATE 4: SUDAH CHECK-OUT
    if (_hasCheckedOut) return _checkOutComplete(isSmall, hp);

    // STATE 5: SUDAH CHECK-IN
    if (_hasCheckedIn || _isCheckInFinalized)
      return _postCheckIn(isSmall, hp);

    // STATE 6: FORM KONFIRMASI KETERLAMBATAN
    if (_showKonfirmasiForm) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoCard(isSmall),
            SizedBox(height: isSmall ? 16 : 20),
            _konfirmasiForm(isSmall),
            SizedBox(height: isSmall ? 20 : 24),
          ],
        ),
      );
    }

    // STATE 7: BANNER TERLAMBAT (BELUM FORM)
    if (_canConfirm && !_showKonfirmasiForm) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoCard(isSmall),
            SizedBox(height: isSmall ? 16 : 20),
            _lateBanner(isSmall),
            SizedBox(height: isSmall ? 20 : 24),
          ],
        ),
      );
    }

    // STATE 8: VERIFIKASI LOKASI
    if (!_hideLocationVerification || _isLateOvertime) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoCard(isSmall),
              if (_isLateOvertime) ...[
                SizedBox(height: isSmall ? 8 : 10),
                Container(
                  padding: EdgeInsets.all(isSmall ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: isSmall ? 16 : 18,
                          color: Colors.orange.shade700),
                      SizedBox(width: isSmall ? 6 : 8),
                      Expanded(
                        child: Text(
                          'Mode: Lembur Terlambat - Konfirmasi diperlukan',
                          style: GoogleFonts.poppins(
                            fontSize: isSmall ? 10 : 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: isSmall ? 12 : 16),
              if (!_isLateOvertime) ...[
                _stepIndicator(isSmall),
                SizedBox(height: isSmall ? 20 : 24),
              ],
              Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 400),
                  child: _statusCard(isSmall),
                ),
              ),
              SizedBox(height: isSmall ? 16 : 20),
              if (_capturedImage != null) ...[
                _photoPreview(isSmall),
                SizedBox(height: isSmall ? 16 : 20),
              ],
              if (_isLoadingLocation)
                Padding(
                  padding: EdgeInsets.all(isSmall ? 20 : 24),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A237E)),
                  ),
                ),
              if (!_isLoadingLocation && !_isCheckingStatus) ...[
                _actionButtons(isSmall),
                SizedBox(height: isSmall ? 16 : 20),
              ],
              if (_isLateOvertime && !_locationValid) ...[
                SizedBox(height: isSmall ? 8 : 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showKonfirmasiForm = true;
                        _canConfirm = true;
                      });
                    },
                    icon: Icon(Icons.arrow_back,
                        size: isSmall ? 14 : 16,
                        color: Colors.orange.shade700),
                    label: Text(
                      'Kembali ke Form Konfirmasi',
                      style: GoogleFonts.poppins(
                        fontSize: isSmall ? 11 : 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // STATE 9: UPCOMING
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _infoCard(isSmall),
          if (_hideLocationVerification && !_isLateOvertime) ...[
            SizedBox(height: isSmall ? 12 : 16),
            _upcomingOvertimeBanner(isSmall),
            SizedBox(height: isSmall ? 16 : 20),
            if (_lateOvertimeList.isNotEmpty)
              Container(
                padding: EdgeInsets.all(isSmall ? 10 : 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: isSmall ? 16 : 18,
                        color: Colors.orange.shade700),
                    SizedBox(width: isSmall ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Punya lembur terlambat?',
                            style: GoogleFonts.poppins(
                              fontSize: isSmall ? 11 : 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '${_lateOvertimeList.length} jadwal perlu dikonfirmasi',
                            style: GoogleFonts.poppins(
                              fontSize: isSmall ? 10 : 11,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentTabIndex = 1;
                        });
                        if (_lateOvertimeList.isNotEmpty) {
                          _selectLateOvertime(_lateOvertimeList.first);
                        }
                      },
                      child: Text(
                        'Lihat',
                        style: GoogleFonts.poppins(
                          fontSize: isSmall ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB LEMBUR TERLAMBAT CONTENT
  // ═══════════════════════════════════════════════════════

  Widget _lateOvertimeTabContent(bool isSmall, double hp) {
    if (_isLoadingLateList) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: Colors.orange),
        SizedBox(height: isSmall ? 12 : 16),
        Text('Memuat daftar lembur terlambat...',
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 13 : 14, color: Colors.grey.shade600)),
      ]));
    }

    if (_lateOvertimeList.isEmpty && !_isViewingLateOvertime) {
      return Center(
          child: Padding(
        padding: EdgeInsets.all(hp * 1.5),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline,
              size: isSmall ? 64 : 80, color: Colors.green.shade300),
          SizedBox(height: isSmall ? 16 : 20),
          Text('🎉 Tidak Ada Lembur Terlambat!',
              style: GoogleFonts.poppins(
                  fontSize: isSmall ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700)),
          SizedBox(height: isSmall ? 8 : 10),
          Text('Semua jadwal lembur sudah teratasi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: isSmall ? 12 : 14, color: Colors.grey.shade500)),
        ]),
      ));
    }

    if (_isViewingLateOvertime && _overtimeItem != null) {
      final Widget? backButton = (!_hasCheckedIn &&
              !_isCheckInFinalized &&
              !_hasCheckedOut)
          ? Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _backToLateOvertimeList,
                icon: const Icon(Icons.arrow_back,
                    size: 16, color: Colors.orange),
                label: Text('Kembali ke daftar lembur terlambat',
                    style: GoogleFonts.poppins(
                        fontSize: isSmall ? 11 : 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600)),
              ),
            )
          : null;

      if (_hasCheckedOut) return _checkOutComplete(isSmall, hp);
      if (_hasCheckedIn || _isCheckInFinalized)
        return _postCheckIn(isSmall, hp);

      if (_showKonfirmasiForm) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (backButton != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: backButton),
                _infoCard(isSmall),
                SizedBox(height: isSmall ? 16 : 20),
                _konfirmasiForm(isSmall),
              ]),
        );
      }

      if (_canConfirm && !_showKonfirmasiForm) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (backButton != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: backButton),
                _infoCard(isSmall),
                SizedBox(height: isSmall ? 16 : 20),
                _lateBanner(isSmall),
              ]),
        );
      }

      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (backButton != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: backButton),
                _infoCard(isSmall),
                SizedBox(height: isSmall ? 16 : 20),
                _lateBanner(isSmall),
              ]),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      padding: EdgeInsets.all(hp),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: EdgeInsets.all(isSmall ? 12 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade100, Colors.orange.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: isSmall ? 24 : 28),
            SizedBox(width: isSmall ? 10 : 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '⚠️ Jadwal Lembur Terlambat',
                      style: GoogleFonts.poppins(
                        fontSize: isSmall ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${_lateOvertimeList.length} jadwal memerlukan konfirmasi (maks. 3 hari)',
                      style: GoogleFonts.poppins(
                        fontSize: isSmall ? 10 : 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ]),
            ),
          ]),
        ),
        SizedBox(height: isSmall ? 14 : 18),
        ..._lateOvertimeList.map((item) => _lateOvertimeCard(item, isSmall)),
        if (_lateOvertimeList.isEmpty && !_isViewingLateOvertime) ...[
          SizedBox(height: isSmall ? 20 : 24),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle,
                  size: isSmall ? 40 : 48, color: Colors.green),
              SizedBox(height: 8),
              Text('Semua lembur sudah dikonfirmasi',
                  style: GoogleFonts.poppins(
                      fontSize: isSmall ? 12 : 13,
                      color: Colors.grey.shade600)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _lateOvertimeCard(OvertimeHistory item, bool isSmall) {
    final now = DateTime.now();
    final partsSelesai = item.jamSelesai.split(':');
    DateTime? batasExpired;
    if (partsSelesai.length == 2) {
      var js = DateTime(
          item.tanggal.year,
          item.tanggal.month,
          item.tanggal.day,
          int.parse(partsSelesai[0]),
          int.parse(partsSelesai[1]));
      final jm = DateTime(
          item.tanggal.year,
          item.tanggal.month,
          item.tanggal.day,
          int.parse(item.jamMulai.split(':')[0]),
          int.parse(item.jamMulai.split(':')[1]));
      if (js.isBefore(jm)) js = js.add(const Duration(days: 1));
      batasExpired = js.add(const Duration(days: 3));
    }

    final isExpiringSoon =
        batasExpired != null && batasExpired.difference(now).inHours < 24;

    return Container(
      margin: EdgeInsets.only(bottom: isSmall ? 10 : 12),
      padding: EdgeInsets.all(isSmall ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpiringSoon ? Colors.red.shade300 : Colors.orange.shade200,
          width: isExpiringSoon ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpiringSoon ? Colors.red : Colors.orange)
                .withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 8 : 10, vertical: isSmall ? 3 : 4),
                decoration: BoxDecoration(
                  color: isExpiringSoon
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isExpiringSoon
                        ? Colors.red.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy', 'id_ID').format(item.tanggal),
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: isExpiringSoon
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
              SizedBox(width: isSmall ? 6 : 8),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 8 : 10, vertical: isSmall ? 3 : 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  '${item.jamMulai} - ${item.jamSelesai}',
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const Spacer(),
              if (isExpiringSoon)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '⚠️ SEGERA EXPIRED',
                    style: GoogleFonts.poppins(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          SizedBox(height: isSmall ? 8 : 10),
          Row(children: [
            Icon(Icons.location_on_outlined,
                size: isSmall ? 12 : 14, color: Colors.grey.shade500),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                (item.lokasi is Map)
                    ? ((item.lokasi as Map)['alamat'] ??
                            (item.lokasi as Map)['nama_lokasi'] ??
                            'Kantor')
                        .toString()
                    : 'Kantor',
                style: GoogleFonts.poppins(
                    fontSize: isSmall ? 10 : 11,
                    color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          if (batasExpired != null) ...[
            SizedBox(height: isSmall ? 4 : 6),
            Row(children: [
              Icon(Icons.timer_outlined,
                  size: isSmall ? 12 : 14,
                  color: isExpiringSoon ? Colors.red : Colors.orange.shade600),
              SizedBox(width: 4),
              Text(
                'Expired: ${DateFormat('dd MMM HH:mm', 'id_ID').format(batasExpired)}',
                style: GoogleFonts.poppins(
                  fontSize: isSmall ? 9 : 10,
                  color: isExpiringSoon ? Colors.red : Colors.orange.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ],
          SizedBox(height: isSmall ? 10 : 12),
          SizedBox(
            width: double.infinity,
            height: isSmall ? 34 : 38,
            child: ElevatedButton.icon(
              onPressed: () => _selectLateOvertime(item),
              icon: Icon(Icons.edit_note_rounded, size: isSmall ? 14 : 16),
              label: Text(
                'Konfirmasi Sekarang',
                style: GoogleFonts.poppins(
                    fontSize: isSmall ? 11 : 12,
                    fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isExpiringSoon
                    ? Colors.red.shade600
                    : Colors.orange.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // UPCOMING OVERTIME BANNER
  // ═══════════════════════════════════════════════════════

  Widget _upcomingOvertimeBanner(bool isSmall) {
    final now = DateTime.now();
    final partsMulai = _overtimeItem!.jamMulai.split(':');
    DateTime? earliestCheckIn;

    if (partsMulai.length == 2) {
      final jamMulai = DateTime(now.year, now.month, now.day,
          int.parse(partsMulai[0]), int.parse(partsMulai[1]));
      earliestCheckIn = jamMulai.subtract(const Duration(minutes: 30));
    }

    final diff =
        earliestCheckIn != null ? earliestCheckIn.difference(now) : null;

    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade100, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(Icons.hourglass_empty,
              color: Colors.blue.shade700, size: isSmall ? 24 : 28),
          SizedBox(width: isSmall ? 10 : 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '⏰ Jadwal Lembur Hari Ini',
                    style: GoogleFonts.poppins(
                        fontSize: isSmall ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade900),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Absensi belum bisa dilakukan',
                    style: GoogleFonts.poppins(
                        fontSize: isSmall ? 11 : 12,
                        color: Colors.blue.shade700),
                  ),
                ]),
          ),
        ]),
        SizedBox(height: isSmall ? 12 : 14),
        Container(
          padding: EdgeInsets.all(isSmall ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text(
              'Verifikasi lokasi akan muncul saat waktu absensi tiba',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: isSmall ? 11 : 12, color: Colors.grey.shade700),
            ),
            if (earliestCheckIn != null) ...[
              SizedBox(height: isSmall ? 8 : 10),
              Text(
                'Check-in dibuka: ${DateFormat('dd MMM HH:mm', 'id_ID').format(earliestCheckIn)} WIB',
                style: GoogleFonts.poppins(
                    fontSize: isSmall ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800),
              ),
              if (diff != null) ...[
                SizedBox(height: 4),
                Text(
                  '(${diff.inHours}j ${diff.inMinutes.remainder(60)}m lagi)',
                  style: GoogleFonts.poppins(
                      fontSize: isSmall ? 10 : 11,
                      color: Colors.blue.shade600),
                ),
              ],
            ],
            SizedBox(height: isSmall ? 10 : 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.location_off,
                  size: isSmall ? 14 : 16, color: Colors.grey.shade500),
              SizedBox(width: 4),
              Text(
                'Verifikasi lokasi disembunyikan',
                style: GoogleFonts.poppins(
                    fontSize: isSmall ? 10 : 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic),
              ),
            ]),
          ]),
        ),
        if (_lateOvertimeList.isNotEmpty) ...[
          SizedBox(height: isSmall ? 12 : 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _currentTabIndex = 1;
                });
                if (_lateOvertimeList.isNotEmpty) {
                  _selectLateOvertime(_lateOvertimeList.first);
                }
              },
              icon: Icon(Icons.warning_amber_rounded,
                  size: isSmall ? 14 : 16, color: Colors.orange),
              label: Text(
                'Lihat ${_lateOvertimeList.length} Lembur Terlambat',
                style: GoogleFonts.poppins(
                    fontSize: isSmall ? 11 : 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
        SizedBox(height: isSmall ? 8 : 10),
        TextButton.icon(
          onPressed: () {
            _hasInitCheckRun = false;
            _loadOvertimeData();
          },
          icon: Icon(Icons.refresh, size: isSmall ? 14 : 16),
          label:
              Text('Refresh', style: GoogleFonts.poppins(fontSize: isSmall ? 11 : 12)),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  // POST CHECK-IN VIEW
  // ═══════════════════════════════════════════════════════

  Widget _postCheckIn(bool isSmall, double hp) {
    final tgl = _overtimeItem!.tanggal;
    final parts = _overtimeItem!.jamSelesai.split(':');
    final partsMulai = _overtimeItem!.jamMulai.split(':');
    DateTime? js;
    if (parts.length == 2) {
      js = DateTime(tgl.year, tgl.month, tgl.day, int.parse(parts[0]),
          int.parse(parts[1]));
      if (partsMulai.length == 2) {
        final jm = DateTime(tgl.year, tgl.month, tgl.day,
            int.parse(partsMulai[0]), int.parse(partsMulai[1]));
        if (js.isBefore(jm)) js = js.add(const Duration(days: 1));
      }
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(hp, hp * 0.75, hp, 16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoCard(isSmall),
            SizedBox(height: isSmall ? 16 : 20),
            _checkInSuccessCard(isSmall),
            SizedBox(height: isSmall ? 16 : 20),
            _statusRow(isSmall, js),
            SizedBox(height: isSmall ? 16 : 20),
            if (js != null) _countdownCard(isSmall, js),
            _reminderCard(isSmall),
            SizedBox(height: isSmall ? 16 : 20),
          ]),
    );
  }

  Widget _checkInSuccessCard(bool isSmall) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: EdgeInsets.all(isSmall ? 16 : 20),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle),
          child: Icon(Icons.check_circle_rounded,
              size: isSmall ? 48 : 60, color: Colors.white),
        ),
        SizedBox(height: isSmall ? 14 : 18),
        Text('✅ Check-in Berhasil!',
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        SizedBox(height: isSmall ? 6 : 8),
        Text('Selamat bekerja! 💪',
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 14 : 16, color: Colors.white70)),
        if (_checkInTime != null) ...[
          SizedBox(height: isSmall ? 4 : 6),
          Text(
              'Check-in: ${DateFormat('HH:mm', 'id_ID').format(_checkInTime!)} WIB',
              style: GoogleFonts.poppins(
                  fontSize: isSmall ? 12 : 13, color: Colors.white60)),
        ],
      ]),
    );
  }

  Widget _statusRow(bool isSmall, DateTime? js) {
    return Column(children: [
      Row(children: [
        Expanded(
            child: _statusItem(
                Icons.access_time_rounded,
                'Jam Lembur',
                '${_overtimeItem!.jamMulai} - ${_overtimeItem!.jamSelesai}',
                null,
                Colors.blue,
                isSmall)),
        SizedBox(width: isSmall ? 10 : 12),
        Expanded(
            child: _statusItem(
                Icons.timer_rounded,
                'Durasi',
                '${_overtimeItem!.totalJam.toStringAsFixed(1)} jam',
                null,
                Colors.purple,
                isSmall)),
      ]),
      SizedBox(height: isSmall ? 10 : 12),
      Row(children: [
        Expanded(
            child: _statusItem(
                _isLiveLocationActive ? Icons.location_on : Icons.location_off,
                'Live Location',
                _isLiveLocationActive ? '🟢 Aktif' : '🔴 Off',
                _isLiveLocationActive ? _getLiveLocationDuration() : null,
                _isLiveLocationActive ? Colors.green : Colors.red,
                isSmall)),
        SizedBox(width: isSmall ? 10 : 12),
        Expanded(
            child: _statusItem(
                _canCheckOut ? Icons.logout : Icons.schedule,
                'Check-out',
                _canCheckOut ? '✅ Siap' : '⏳ Menunggu',
                js != null ? '${DateFormat('HH:mm').format(js)} WIB' : null,
                _canCheckOut ? Colors.orange : Colors.grey,
                isSmall)),
      ]),
    ]);
  }

  Widget _reminderCard(bool isSmall) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade200)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline,
            color: Colors.amber.shade700, size: isSmall ? 20 : 24),
        SizedBox(width: isSmall ? 10 : 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              Text('Pengingat',
                  style: GoogleFonts.poppins(
                      fontSize: isSmall ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900)),
              SizedBox(height: isSmall ? 4 : 6),
              Text(
                  '• Live location Anda sedang aktif\n• Jangan lupa check-out setelah selesai\n• Check-out 30 menit sebelum jam selesai\n• Tombol check-out muncul otomatis',
                  style: GoogleFonts.poppins(
                      fontSize: isSmall ? 10 : 11,
                      color: Colors.amber.shade800,
                      height: 1.5)),
            ])),
      ]),
    );
  }

  Widget _countdownCard(bool isSmall, DateTime js) {
    final now = DateTime.now();
    final cs = js.subtract(const Duration(minutes: 30));
    final ce = js.add(const Duration(hours: 2));
    if (now.isAfter(ce)) return _expiredCard(isSmall);
    if (now.isAfter(cs) && now.isBefore(ce))
      return _checkoutNowCard(isSmall, ce);
    if (now.isBefore(cs)) return _waitingCard(isSmall, cs);
    return const SizedBox.shrink();
  }

  Widget _expiredCard(bool isSmall) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200)),
      child: Column(children: [
        Icon(Icons.warning_amber,
            color: Colors.red.shade400, size: isSmall ? 36 : 48),
        SizedBox(height: isSmall ? 8 : 12),
        Text('⚠️ Waktu check-out telah berakhir!',
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700)),
        Text('Hubungi pengawas untuk bantuan.',
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 11 : 12, color: Colors.red.shade500)),
      ]),
    );
  }

  Widget _checkoutNowCard(bool isSmall, DateTime ce) {
    final rem = ce.difference(DateTime.now());
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.orange.shade600, Colors.deepOrange.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.alarm, color: Colors.white, size: isSmall ? 20 : 24),
          SizedBox(width: isSmall ? 8 : 10),
          Text('🔔 SEGERA CHECK-OUT!',
              style: GoogleFonts.poppins(
                  fontSize: isSmall ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ]),
        SizedBox(height: isSmall ? 8 : 10),
        Text('Sisa waktu:',
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 12 : 13, color: Colors.white70)),
        SizedBox(height: isSmall ? 4 : 6),
        _countdownTimerWidget(isSmall, rem),
        SizedBox(height: isSmall ? 10 : 14),
        Text('Gunakan tombol check-out di bawah! ⬇️',
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 11 : 12,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _waitingCard(bool isSmall, DateTime cs) {
    final rem = cs.difference(DateTime.now());
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.hourglass_bottom,
              color: Colors.white, size: isSmall ? 20 : 24),
          SizedBox(width: isSmall ? 8 : 10),
          Text('Check-out tersedia dalam',
              style: GoogleFonts.poppins(
                  fontSize: isSmall ? 13 : 14, color: Colors.white70)),
        ]),
        SizedBox(height: isSmall ? 8 : 10),
        _countdownTimerWidget(isSmall, rem),
        SizedBox(height: isSmall ? 8 : 10),
        Text(
            'Check-out mulai: ${DateFormat('HH:mm:ss').format(cs)} WIB',
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 11 : 12, color: Colors.white60)),
      ]),
    );
  }

  Widget _countdownTimerWidget(bool isSmall, Duration rem) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _timeBox('${rem.inHours}', 'Jam', isSmall),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 6 : 8),
          child: Text(':',
              style: GoogleFonts.poppins(
                  fontSize: isSmall ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white))),
      _timeBox(
          '${rem.inMinutes.remainder(60).toString().padLeft(2, '0')}',
          'Mnt',
          isSmall),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 6 : 8),
          child: Text(':',
              style: GoogleFonts.poppins(
                  fontSize: isSmall ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white))),
      _timeBox(
          '${rem.inSeconds.remainder(60).toString().padLeft(2, '0')}',
          'Dtk',
          isSmall),
    ]);
  }

  Widget _statusItem(IconData icon, String title, String value, String? sub,
      Color color, bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                padding: EdgeInsets.all(isSmall ? 6 : 8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: isSmall ? 18 : 20)),
            SizedBox(height: isSmall ? 8 : 10),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: isSmall ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A237E))),
            if (sub != null) ...[
              SizedBox(height: 2),
              Text(sub,
                  style: GoogleFonts.poppins(
                      fontSize: isSmall ? 9 : 10,
                      color: Colors.grey.shade500))
            ],
            SizedBox(height: isSmall ? 2 : 4),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: isSmall ? 9 : 10,
                    color: Colors.grey.shade500)),
          ]),
    );
  }

  Widget _timeBox(String val, String label, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 10 : 14, vertical: isSmall ? 6 : 8),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(val,
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 8 : 9, color: Colors.white70)),
      ]),
    );
  }

  Widget _checkOutComplete(bool isSmall, double hp) {
    return Center(
        child: Padding(
      padding: EdgeInsets.all(hp * 1.5),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: EdgeInsets.all(isSmall ? 24 : 32),
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)]),
                shape: BoxShape.circle),
            child: Icon(Icons.celebration_rounded,
                size: isSmall ? 64 : 80, color: Colors.white)),
        SizedBox(height: isSmall ? 20 : 24),
        Text('Lembur Selesai! 🎉',
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 20 : 26,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A237E))),
        SizedBox(height: isSmall ? 10 : 14),
        Text(_statusMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: isSmall ? 14 : 16, color: Colors.grey.shade600)),
        SizedBox(height: isSmall ? 24 : 28),
        ElevatedButton.icon(
          onPressed: _goBack,
          icon: Icon(Icons.arrow_back, size: isSmall ? 18 : 20),
          label: Text('Kembali ke Dashboard',
              style: GoogleFonts.poppins(fontSize: isSmall ? 13 : 14)),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 24 : 32,
                  vertical: isSmall ? 14 : 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
        ),
      ]),
    ));
  }

  Widget _checkOutSection(bool isSmall, double bp) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          isSmall ? 12 : 16, 12, isSmall ? 12 : 16, bp + 8),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2))
      ]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: EdgeInsets.all(isSmall ? 8 : 10),
            decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.check_circle,
                  color: Colors.green, size: isSmall ? 16 : 18),
              SizedBox(width: isSmall ? 6 : 8),
              Text('Waktu check-out telah tiba!',
                  style: GoogleFonts.poppins(
                      fontSize: isSmall ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700)),
            ])),
        SizedBox(height: isSmall ? 8 : 10),
        if (_checkOutPreviewFile != null) ...[
          ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(children: [
                Image.file(_checkOutPreviewFile!,
                    height: isSmall ? 100 : 120,
                    width: double.infinity,
                    fit: BoxFit.cover),
                Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _isCheckingOut ? null : _takeCheckOutPhoto,
                      child: Container(
                          padding: EdgeInsets.all(isSmall ? 6 : 8),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: Icon(Icons.refresh,
                              color: Colors.white,
                              size: isSmall ? 16 : 20)),
                    )),
              ])),
          SizedBox(height: isSmall ? 8 : 10),
        ],
        if (_checkOutPreviewFile == null)
          SizedBox(
              width: double.infinity,
              height: isSmall ? 42 : 48,
              child: OutlinedButton.icon(
                onPressed: _isTakingPhoto ? null : _takeCheckOutPhoto,
                icon: _isTakingPhoto
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.camera_alt, size: isSmall ? 18 : 20),
                label: Text(
                    _isTakingPhoto ? 'Membuka...' : '📸 Ambil Foto Check-Out',
                    style: GoogleFonts.poppins(
                        fontSize: isSmall ? 12 : 13,
                        fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A237E),
                    side: const BorderSide(color: Color(0xFF1A237E)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              )),
        if (_checkOutPreviewFile != null) ...[
          SizedBox(height: isSmall ? 8 : 10),
          SizedBox(
              width: double.infinity,
              height: isSmall ? 44 : 50,
              child: ElevatedButton.icon(
                onPressed: _isCheckingOut ? null : _performCheckOut,
                icon: _isCheckingOut
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.logout_rounded,
                        size: isSmall ? 18 : 20),
                label: Text(
                    _isCheckingOut ? 'Check-Out...' : '✅ Submit Check-Out',
                    style: GoogleFonts.poppins(
                        fontSize: isSmall ? 13 : 14,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              )),
        ],
      ]),
    );
  }

  Widget _infoCard(bool isSmall) {
    final l = _overtimeItem!;
    final lok = l.lokasi;
    final alamat = (lok is Map)
        ? ((lok as Map)['alamat'] ??
                (lok as Map)['nama_lokasi'] ??
                'Kantor')
            .toString()
        : (lok?.toString() ?? 'Kantor');

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1A237E).withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLateOvertime)
              Container(
                margin: EdgeInsets.only(bottom: isSmall ? 8 : 10),
                padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 8 : 10,
                    vertical: isSmall ? 4 : 6),
                decoration: BoxDecoration(
                    color: Colors.orange.shade400,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: isSmall ? 14 : 16),
                  SizedBox(width: isSmall ? 4 : 6),
                  Text(
                      '⚠️ Lembur Terlambat - ${DateFormat('dd MMM').format(l.tanggal)}',
                      style: GoogleFonts.poppins(
                          fontSize: isSmall ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ]),
              ),
            Row(children: [
              Icon(Icons.work, color: Colors.white, size: isSmall ? 16 : 20),
              SizedBox(width: isSmall ? 6 : 8),
              Flexible(
                  child: Text('Detail Lembur',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: isSmall ? 13 : 14,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
            ]),
            SizedBox(height: isSmall ? 10 : 12),
            _infoRow(Icons.calendar_today,
                DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(l.tanggal),
                isSmall),
            _infoRow(Icons.access_time,
                '${l.jamMulai} - ${l.jamSelesai} (${l.totalJam.toStringAsFixed(1)} jam)',
                isSmall),
            _infoRow(Icons.location_on, alamat, isSmall),
            _infoRow(Icons.person,
                l.namaMitra ?? l.namaPengawas ?? 'Tidak diketahui', isSmall),
          ]),
    );
  }

  Widget _infoRow(IconData icon, String text, bool isSmall) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmall ? 4 : 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: isSmall ? 12 : 14, color: Colors.white70),
        SizedBox(width: isSmall ? 8 : 10),
        Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    fontSize: isSmall ? 11 : 12, color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _lateBanner(bool isSmall) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmall ? 12 : 16),
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.orange.shade100, Colors.orange.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.orange.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                  padding: EdgeInsets.all(isSmall ? 6 : 8),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: isSmall ? 20 : 24)),
              SizedBox(width: isSmall ? 8 : 10),
              Expanded(
                  child: Text('⚠️ Anda Terlambat!',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: isSmall ? 14 : 16,
                          color: Colors.orange.shade900))),
            ]),
            SizedBox(height: isSmall ? 8 : 10),
            Container(
              padding: EdgeInsets.all(isSmall ? 10 : 12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '📋 Anda belum melakukan absensi dan sudah melewati batas waktu.',
                        style: GoogleFonts.poppins(
                            fontSize: isSmall ? 11 : 12,
                            color: Colors.grey.shade800,
                            height: 1.4)),
                    SizedBox(height: isSmall ? 4 : 6),
                    Text(
                        'Silakan konfirmasi apakah Anda tetap melakukan lembur atau tidak.\n(Maksimal 3 hari setelah jam selesai)',
                        style: GoogleFonts.poppins(
                            fontSize: isSmall ? 11 : 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500)),
                  ]),
            ),
            if (_errorDetail != null) ...[
              SizedBox(height: isSmall ? 8 : 10),
              Container(
                  padding: EdgeInsets.all(isSmall ? 8 : 10),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        size: isSmall ? 14 : 16,
                        color: Colors.red.shade400),
                    SizedBox(width: isSmall ? 6 : 8),
                    Expanded(
                        child: Text(_errorDetail!,
                            style: GoogleFonts.poppins(
                                fontSize: isSmall ? 10 : 11,
                                color: Colors.red.shade700))),
                  ])),
            ],
            SizedBox(height: isSmall ? 14 : 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      setState(() => _showKonfirmasiForm = true),
                  icon:
                      Icon(Icons.edit_note_rounded, size: isSmall ? 18 : 20),
                  label: Text('Konfirmasi Keterlambatan',
                      style: GoogleFonts.poppins(
                          fontSize: isSmall ? 13 : 14,
                          fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(vertical: isSmall ? 12 : 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2),
                )),
          ]),
    );
  }

  Widget _konfirmasiForm(bool isSmall) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmall ? 12 : 16),
      padding: EdgeInsets.all(isSmall ? 14 : 18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                  padding: EdgeInsets.all(isSmall ? 6 : 8),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.assignment_turned_in,
                      color: Colors.orange.shade700,
                      size: isSmall ? 18 : 20)),
              SizedBox(width: isSmall ? 8 : 10),
              Expanded(
                  child: Text('📋 Form Konfirmasi Keterlambatan',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: isSmall ? 14 : 16,
                          color: Colors.grey.shade800))),
            ]),
            SizedBox(height: isSmall ? 14 : 18),
            Container(height: 1, color: Colors.grey.shade200),
            SizedBox(height: isSmall ? 14 : 18),
            Text('Apakah Anda melakukan lembur?',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: isSmall ? 13 : 14,
                    color: Colors.grey.shade800)),
            SizedBox(height: isSmall ? 10 : 12),
            Row(children: [
              Expanded(
                  child: _optionCard(
                      title: '✅ Ya, Saya Lembur',
                      subtitle: 'Saya tetap bekerja lembur',
                      icon: Icons.work_history,
                      color: Colors.green,
                      selected: _melakukanLembur == true,
                      onTap: () => setState(() => _melakukanLembur = true),
                      isSmall: isSmall)),
              SizedBox(width: isSmall ? 10 : 12),
              Expanded(
                  child: _optionCard(
                      title: '❌ Tidak Lembur',
                      subtitle: 'Saya tidak jadi lembur',
                      icon: Icons.cancel_schedule_send,
                      color: Colors.red,
                      selected: _melakukanLembur == false,
                      onTap: () => setState(() => _melakukanLembur = false),
                      isSmall: isSmall)),
            ]),
            SizedBox(height: isSmall ? 14 : 18),
            Container(height: 1, color: Colors.grey.shade200),
            SizedBox(height: isSmall ? 14 : 18),
            Text('Alasan Keterlambatan',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: isSmall ? 13 : 14,
                    color: Colors.grey.shade800)),
            SizedBox(height: isSmall ? 8 : 10),
            TextField(
              controller: _alasanController,
              maxLines: 3,
              minLines: 2,
              style: GoogleFonts.poppins(fontSize: isSmall ? 12 : 13),
              decoration: InputDecoration(
                hintText: 'Tulis alasan keterlambatan Anda...',
                hintStyle: GoogleFonts.poppins(
                    fontSize: isSmall ? 11 : 12,
                    color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF1A237E), width: 2)),
                contentPadding: EdgeInsets.all(isSmall ? 12 : 14),
              ),
            ),
            if (_melakukanLembur == true) ...[
              SizedBox(height: isSmall ? 14 : 18),
              Container(height: 1, color: Colors.grey.shade200),
              SizedBox(height: isSmall ? 14 : 18),
              Text('📸 Foto Bukti Lembur',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: isSmall ? 13 : 14,
                      color: Colors.grey.shade800)),
              SizedBox(height: isSmall ? 4 : 6),
              Text('Wajib upload foto sebagai bukti Anda melakukan lembur',
                  style: GoogleFonts.poppins(
                      fontSize: isSmall ? 10 : 11,
                      color: Colors.grey.shade500)),
              SizedBox(height: isSmall ? 10 : 12),
              if (_buktiFotoTerlambat != null) ...[
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(children: [
                      Image.file(_buktiFotoTerlambat!,
                          height: isSmall ? 180 : 220,
                          width: double.infinity,
                          fit: BoxFit.cover),
                      Positioned(
                          top: 8,
                          right: 8,
                          child: Row(children: [
                            GestureDetector(
                              onTap: _isUploadingBukti || _isSubmitting
                                  ? null
                                  : _pickBuktiFoto,
                              child: Container(
                                  padding: EdgeInsets.all(isSmall ? 6 : 8),
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: Icon(Icons.refresh,
                                      color: Colors.white,
                                      size: isSmall ? 16 : 18)),
                            ),
                            SizedBox(width: isSmall ? 6 : 8),
                            GestureDetector(
                              onTap: _isUploadingBukti || _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _buktiFotoTerlambat = null;
                                      });
                                    },
                              child: Container(
                                  padding: EdgeInsets.all(isSmall ? 6 : 8),
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                  child: Icon(Icons.close,
                                      color: Colors.white,
                                      size: isSmall ? 16 : 18)),
                            ),
                          ])),
                      Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text('Foto Bukti Lembur',
                                  style: GoogleFonts.poppins(
                                      fontSize: isSmall ? 10 : 11,
                                      color: Colors.white)))),
                    ])),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isSmall ? 20 : 24),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_a_photo,
                        size: isSmall ? 40 : 48,
                        color: Colors.grey.shade400),
                    SizedBox(height: isSmall ? 8 : 10),
                    Text('Belum ada foto bukti',
                        style: GoogleFonts.poppins(
                            fontSize: isSmall ? 11 : 12,
                            color: Colors.grey.shade500)),
                    SizedBox(height: isSmall ? 10 : 12),
                    OutlinedButton.icon(
                      onPressed:
                          _isUploadingBukti || _isSubmitting ? null : _pickBuktiFoto,
                      icon: Icon(Icons.add_a_photo,
                          size: isSmall ? 16 : 18),
                      label: Text('Ambil / Pilih Foto Bukti',
                          style: GoogleFonts.poppins(
                              fontSize: isSmall ? 11 : 12)),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A237E),
                          side: const BorderSide(color: Color(0xFF1A237E)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                    ),
                  ]),
                ),
              ],
              if (_isUploadingBukti) ...[
                SizedBox(height: isSmall ? 10 : 12),
                const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF1A237E))),
                SizedBox(height: isSmall ? 4 : 6),
                Center(
                    child: Text('Mengupload foto...',
                        style: GoogleFonts.poppins(
                            fontSize: isSmall ? 11 : 12,
                            color: Colors.grey.shade600))),
              ],
            ],
            if (_melakukanLembur == false) ...[
              SizedBox(height: isSmall ? 10 : 12),
              Container(
                  padding: EdgeInsets.all(isSmall ? 10 : 12),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200)),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: isSmall ? 16 : 18),
                    SizedBox(width: isSmall ? 8 : 10),
                    Expanded(
                        child: Text(
                            'Anda memilih untuk tidak melakukan lembur. Konfirmasi ini akan dicatat oleh sistem.',
                            style: GoogleFonts.poppins(
                                fontSize: isSmall ? 10 : 11,
                                color: Colors.blue.shade700))),
                  ])),
            ],
            // 🔥 TAMPILKAN ERROR VALIDASI
            if (_konfirmasiError != null) ...[
              SizedBox(height: isSmall ? 12 : 14),
              Container(
                padding: EdgeInsets.all(isSmall ? 10 : 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade600, size: isSmall ? 16 : 18),
                    SizedBox(width: isSmall ? 8 : 10),
                    Expanded(
                      child: Text(
                        _konfirmasiError!,
                        style: GoogleFonts.poppins(
                          fontSize: isSmall ? 11 : 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: isSmall ? 18 : 22),
            Container(height: 1, color: Colors.grey.shade200),
            SizedBox(height: isSmall ? 14 : 16),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                onPressed: _isSubmitting ? null : _batalKonfirmasi,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding:
                        EdgeInsets.symmetric(vertical: isSmall ? 12 : 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text('Batal',
                    style: GoogleFonts.poppins(
                        fontSize: isSmall ? 12 : 13,
                        fontWeight: FontWeight.w600)),
              )),
              SizedBox(width: isSmall ? 10 : 12),
              Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitKonfirmasi,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        padding:
                            EdgeInsets.symmetric(vertical: isSmall ? 12 : 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2),
                    child: _isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white)),
                                SizedBox(width: isSmall ? 8 : 10),
                                Text('Mengirim...',
                                    style: GoogleFonts.poppins(
                                        fontSize: isSmall ? 12 : 13,
                                        color: Colors.white))
                              ])
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(Icons.send_rounded,
                                    size: isSmall ? 16 : 18,
                                    color: Colors.white),
                                SizedBox(width: isSmall ? 6 : 8),
                                Text('Kirim Konfirmasi',
                                    style: GoogleFonts.poppins(
                                        fontSize: isSmall ? 13 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white))
                              ]),
                  )),
            ]),
          ]),
    );
  }

  Widget _checkOutKonfirmasiForm(bool isSmall) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmall ? 12 : 16),
      padding: EdgeInsets.all(isSmall ? 14 : 18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                  padding: EdgeInsets.all(isSmall ? 6 : 8),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.assignment_late,
                      color: Colors.orange.shade700,
                      size: isSmall ? 18 : 20)),
              SizedBox(width: isSmall ? 8 : 10),
              Expanded(
                  child: Text('📋 Konfirmasi Keterlambatan Checkout',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: isSmall ? 14 : 16,
                          color: Colors.grey.shade800))),
            ]),
            SizedBox(height: isSmall ? 14 : 18),
            Container(height: 1, color: Colors.grey.shade200),
            SizedBox(height: isSmall ? 14 : 18),
            Text('Alasan Keterlambatan Checkout',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: isSmall ? 13 : 14,
                    color: Colors.grey.shade800)),
            SizedBox(height: isSmall ? 8 : 10),
            TextField(
              controller: _alasanCheckOutController,
              maxLines: 3,
              minLines: 2,
              style: GoogleFonts.poppins(fontSize: isSmall ? 12 : 13),
              decoration: InputDecoration(
                hintText: 'Tulis alasan kenapa checkout terlambat...',
                hintStyle: GoogleFonts.poppins(
                    fontSize: isSmall ? 11 : 12,
                    color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF1A237E), width: 2)),
                contentPadding: EdgeInsets.all(isSmall ? 12 : 14),
              ),
            ),
            SizedBox(height: isSmall ? 14 : 18),
            Container(height: 1, color: Colors.grey.shade200),
            SizedBox(height: isSmall ? 14 : 18),
            Text('📸 Foto Bukti (opsional)',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: isSmall ? 13 : 14,
                    color: Colors.grey.shade800)),
            SizedBox(height: isSmall ? 4 : 6),
            Text(
                'Boleh dilampirkan kalau ada bukti pendukung keterlambatan checkout',
                style: GoogleFonts.poppins(
                    fontSize: isSmall ? 10 : 11,
                    color: Colors.grey.shade500)),
            SizedBox(height: isSmall ? 10 : 12),
            if (_buktiFotoCheckOutTerlambat != null) ...[
              ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(children: [
                    Image.file(_buktiFotoCheckOutTerlambat!,
                        height: isSmall ? 160 : 200,
                        width: double.infinity,
                        fit: BoxFit.cover),
                    Positioned(
                        top: 8,
                        right: 8,
                        child: Row(children: [
                          GestureDetector(
                            onTap: _isUploadingBuktiCheckOut ||
                                    _isSubmittingCheckOutTerlambat
                                ? null
                                : _pickBuktiFotoCheckOut,
                            child: Container(
                                padding: EdgeInsets.all(isSmall ? 6 : 8),
                                decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle),
                                child: Icon(Icons.refresh,
                                    color: Colors.white,
                                    size: isSmall ? 16 : 18)),
                          ),
                          SizedBox(width: isSmall ? 6 : 8),
                          GestureDetector(
                            onTap: _isUploadingBuktiCheckOut ||
                                    _isSubmittingCheckOutTerlambat
                                ? null
                                : () {
                                    setState(() {
                                      _buktiFotoCheckOutTerlambat = null;
                                    });
                                  },
                            child: Container(
                                padding: EdgeInsets.all(isSmall ? 6 : 8),
                                decoration: const BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle),
                                child: Icon(Icons.close,
                                    color: Colors.white,
                                    size: isSmall ? 16 : 18)),
                          ),
                        ])),
                    Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('Foto Bukti Checkout Terlambat',
                                style: GoogleFonts.poppins(
                                    fontSize: isSmall ? 10 : 11,
                                    color: Colors.white)))),
                  ])),
            ] else ...[
              GestureDetector(
                onTap: _isUploadingBuktiCheckOut ||
                        _isSubmittingCheckOutTerlambat
                    ? null
                    : _pickBuktiFotoCheckOut,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isSmall ? 20 : 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(children: [
                    Icon(Icons.add_a_photo_outlined,
                        size: isSmall ? 28 : 32,
                        color: Colors.grey.shade500),
                    SizedBox(height: isSmall ? 6 : 8),
                    Text('Tap untuk tambah foto',
                        style: GoogleFonts.poppins(
                            fontSize: isSmall ? 12 : 13,
                            color: Colors.grey.shade600)),
                  ]),
                ),
              ),
            ],
            if (_konfirmasiCheckOutError != null) ...[
              SizedBox(height: isSmall ? 12 : 14),
              Container(
                padding: EdgeInsets.all(isSmall ? 10 : 12),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200)),
                child: Text(_konfirmasiCheckOutError!,
                    style: GoogleFonts.poppins(
                        fontSize: isSmall ? 11 : 12,
                        color: Colors.red.shade700)),
              ),
            ],
            SizedBox(height: isSmall ? 18 : 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isSubmittingCheckOutTerlambat ? null : _goBack,
                  style: OutlinedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: isSmall ? 12 : 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('Kembali',
                      style: GoogleFonts.poppins(fontSize: isSmall ? 13 : 14)),
                ),
              ),
              SizedBox(width: isSmall ? 10 : 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmittingCheckOutTerlambat
                      ? null
                      : _submitKonfirmasiCheckOutTerlambat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmittingCheckOutTerlambat
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Kirim Konfirmasi',
                          style: GoogleFonts.poppins(
                              fontSize: isSmall ? 13 : 14,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
    );
  }

  Widget _optionCard(
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required bool selected,
      required VoidCallback onTap,
      required bool isSmall}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isSmall ? 12 : 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isSmall ? 8 : 10),
              decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.2)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon,
                  color: selected ? color : Colors.grey.shade500,
                  size: isSmall ? 28 : 32)),
          SizedBox(height: isSmall ? 8 : 10),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: isSmall ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : Colors.grey.shade700)),
          SizedBox(height: isSmall ? 3 : 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: isSmall ? 9 : 10,
                  fontWeight: FontWeight.w400,
                  color: selected
                      ? color.withValues(alpha: 0.7)
                      : Colors.grey.shade500)),
          if (selected) ...[
            SizedBox(height: isSmall ? 6 : 8),
            Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(20)),
                child: Text('Dipilih',
                    style: GoogleFonts.poppins(
                        fontSize: isSmall ? 9 : 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)))
          ],
        ]),
      ),
    );
  }

  Widget _stepIndicator(bool isSmall) {
    return Row(children: [
      Expanded(
          child: _step('1', 'Lokasi', _locationValid, _isLoadingLocation, isSmall)),
      _stepDiv(_locationValid, isSmall),
      Expanded(
          child: _step('2', 'Selfie', _capturedImage != null, _isTakingPhoto, isSmall)),
      _stepDiv(_capturedImage != null, isSmall),
      Expanded(child: _step('3', 'Submit', false, _isSubmitting, isSmall)),
    ]);
  }

  Widget _step(String num, String label, bool done, bool active, bool isSmall) {
    final c = done
        ? Colors.green
        : active
            ? const Color(0xFF1976D2)
            : Colors.grey.shade300;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(
          radius: isSmall ? 15 : 18,
          backgroundColor: c,
          child: done
              ? Icon(Icons.check, color: Colors.white, size: isSmall ? 15 : 18)
              : Text(num,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
      SizedBox(height: 4),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10,
              color: done
                  ? Colors.green
                  : active
                      ? const Color(0xFF1976D2)
                      : Colors.grey)),
    ]);
  }

  Widget _stepDiv(bool done, bool isSmall) {
    return Expanded(
        child: Container(
            height: 2,
            margin: EdgeInsets.only(bottom: isSmall ? 18 : 20),
            color: done ? Colors.green : Colors.grey.shade300));
  }

  Widget _statusCard(bool isSmall) {
    final v = _locationValid;
    final bg = v
        ? Colors.green.withValues(alpha: 0.08)
        : Colors.orange.withValues(alpha: 0.08);
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: v
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _isLoadingLocation
            ? const CircularProgressIndicator()
            : Icon(v ? Icons.check_circle : Icons.location_off,
                size: 42, color: v ? Colors.green : Colors.orange),
        SizedBox(height: 12),
        Text(_statusMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w500)),
        if (_errorDetail != null) ...[
          SizedBox(height: 8),
          Text(_errorDetail!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: Colors.red.shade700))
        ],
        if (_currentPosition != null) ...[
          SizedBox(height: 12),
          Text(
              '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
              style: GoogleFonts.poppins(
                  fontSize: 10, color: Colors.grey.shade600))
        ],
        if (_distanceInMeters != null)
          Text('Jarak: ${_distanceInMeters!.toStringAsFixed(0)}m',
              style: GoogleFonts.poppins(
                  fontSize: 10, color: Colors.grey.shade600)),
      ]),
    );
  }

  Widget _photoPreview(bool isSmall) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(children: [
          Image.file(_previewFile!,
              height: isSmall ? 200 : 260,
              width: double.infinity,
              fit: BoxFit.cover),
          Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _isSubmitting ? null : _takeSelfie,
                child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.refresh, color: Colors.white)),
              )),
        ]));
  }

  Widget _actionButtons(bool isSmall) {
    if (!_locationValid) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        _btn(
            _hasAttemptedRetry ? '🔄 Coba Lagi' : '📍 Verifikasi Lokasi',
            Icons.refresh,
            Colors.orange,
            _isLoadingLocation, () {
          _hasAttemptedRetry = true;
          _startLocationVerification();
        }, isSmall),
        SizedBox(height: 8),
        TextButton(
            onPressed: () {
              _hasInitCheckRun = false;
              _loadOvertimeData();
            },
            child: Text('Muat Ulang',
                style: GoogleFonts.poppins(color: Colors.grey))),
      ]);
    }
    if (_capturedImage == null) {
      return _btn('📸 Ambil Selfie', Icons.camera_alt, const Color(0xFF1976D2),
          _isTakingPhoto, _takeSelfie, isSmall);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _btn('✅ Submit Absensi', Icons.check_circle, Colors.green, _isSubmitting,
          _submitAbsensi, isSmall),
      if (!_isSubmitting) ...[
        SizedBox(height: 8),
        _btn('📸 Ambil Ulang', Icons.refresh, Colors.grey.shade700,
            _isTakingPhoto, _takeSelfie, isSmall)
      ],
    ]);
  }

  Widget _btn(String text, IconData icon, Color color, bool loading,
      VoidCallback tap, bool isSmall) {
    return SizedBox(
      width: double.infinity,
      height: isSmall ? 46 : 54,
      child: ElevatedButton.icon(
        onPressed: loading ? null : tap,
        icon: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(loading ? 'Memproses...' : text,
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
      ),
    );
  }
}