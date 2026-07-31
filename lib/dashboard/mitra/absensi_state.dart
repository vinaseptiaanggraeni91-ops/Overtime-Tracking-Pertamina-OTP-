// lib/screens/absensi/absensi_state.dart

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';        // Untuk TextEditingController
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '/core/services/overtime_absensi_service.dart';
import '/core/services/live_location_manager.dart';
import '/widgets/absensi/location_validator.dart';

enum AbsensiViewState {
  loading,
  noSchedule,
  idle,
  ready,
  lateBanner,
  lateForm,
  checkedIn,
  checkedOut,
}

class AbsensiState extends ChangeNotifier {
  // DEPENDENCIES
  final OvertimeAbsensiService absensiService;
  final LiveLocationManager liveLocationManager;
  final FirebaseFirestore firestore;
  final ImagePicker imagePicker;
  final LocationValidator locationValidator;

  // CORE STATE
  AbsensiViewState viewState = AbsensiViewState.loading;
  OvertimeHistory? overtimeItem;
  List<OvertimeHistory> lateOvertimeList = [];
  
  String statusMessage = 'Memuat data...';
  String? errorDetail;
  bool isLoadingLocation = false;
  bool isTakingPhoto = false;
  bool isSubmitting = false;

  // LOCATION STATE
  Position? currentPosition;
  String? currentAddress;
  bool locationValid = false;
  double? distanceInMeters;

  // PHOTO STATE
  XFile? capturedImage;
  File? previewFile;
  File? buktiFotoTerlambat;

  // CHECK-IN / CHECK-OUT STATE
  bool hasCheckedIn = false;
  DateTime? checkInTime;
  bool hasCheckedOut = false;
  bool canCheckOut = false;
  
  XFile? checkOutImage;
  File? checkOutPreviewFile;
  bool isCheckingOut = false;
  Timer? checkOutTimer;
  Timer? countdownTimer;

  // LATE OVERTIME STATE
  bool isLateOvertime = false;
  bool isViewingLateOvertime = false;
  bool? melakukanLembur;
  final TextEditingController alasanController = TextEditingController();
  bool isUploadingBukti = false;

  // TAB STATE
  int currentTabIndex = 0;

  // WORKER NAME
  String? cachedWorkerName;

  String? _userId;
  String get userId => _userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  AbsensiState({
    required this.absensiService,
    required this.liveLocationManager,
    required this.firestore,
    required this.imagePicker,
    required this.locationValidator,
  }) {
    liveLocationManager.addListener(_onLiveLocationUpdate);
  }

  void _onLiveLocationUpdate() {
    notifyListeners();
  }

  // ✅✅✅ TAMBAHKAN METHOD INI - Public method untuk trigger UI update dari luar
  /// Method public untuk trigger UI update dari class eksternal seperti AbsensiWorkflow
  void refresh() {
    notifyListeners();
  }

  @override
  void dispose() {
    liveLocationManager.removeListener(_onLiveLocationUpdate);
    checkOutTimer?.cancel();
    countdownTimer?.cancel();
    alasanController.dispose();
    _cleanupFiles();
    super.dispose();
  }

  Future<void> _cleanupFiles() async {
    for (final file in [previewFile, checkOutPreviewFile, buktiFotoTerlambat]) {
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<String> getWorkerName() async {
    if (cachedWorkerName != null && cachedWorkerName!.isNotEmpty) {
      return cachedWorkerName!;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Mitra';

    if (user.displayName != null && user.displayName!.isNotEmpty) {
      cachedWorkerName = user.displayName;
      return cachedWorkerName!;
    }

    try {
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        cachedWorkerName = data['nama_lengkap'] ??
            data['name'] ??
            data['displayName'] ??
            data['nama'] ??
            'Mitra';
        return cachedWorkerName!;
      }
    } catch (e) {
      debugPrint('⚠️ Gagal ambil nama: $e');
    }

    cachedWorkerName = 'Mitra';
    return cachedWorkerName!;
  }

  void resetForNewOvertime() {
    hasCheckedIn = false;
    hasCheckedOut = false;
    canCheckOut = false;
    locationValid = false;
    capturedImage = null;
    previewFile = null;
    checkOutImage = null;
    checkOutPreviewFile = null;
    melakukanLembur = null;
    alasanController.clear();
    buktiFotoTerlambat = null;
    isLoadingLocation = false;
    isTakingPhoto = false;
    isSubmitting = false;
    isUploadingBukti = false;
    isCheckingOut = false;
    errorDetail = null;
  }

  bool get isLiveLocationActive => liveLocationManager.isActive;
  String get liveLocationDuration => liveLocationManager.getDurationString();

  Future<bool> verifyLocation() async {
    isLoadingLocation = true;
    statusMessage = 'Memverifikasi lokasi...';
    notifyListeners();

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        statusMessage = 'GPS tidak aktif';
        isLoadingLocation = false;
        notifyListeners();
        return false;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        statusMessage = 'Izin lokasi diperlukan';
        isLoadingLocation = false;
        notifyListeners();
        return false;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      currentPosition = pos;
      
      // Dapatkan alamat - gunakan locationValidator yang sudah ada
      try {
        currentAddress = await locationValidator
            .getAddressFromCoordinates(pos.latitude, pos.longitude)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        currentAddress = 'Alamat tidak tersedia';
      }

      // Validasi lokasi
      final validation = await locationValidator.validateLocation(
        currentLat: pos.latitude,
        currentLng: pos.longitude,
        overtimeItem: overtimeItem!,
      );

      locationValid = validation['valid'] == true;
      distanceInMeters = validation['distance'] as double?;

      if (locationValid) {
        statusMessage = '✅ Lokasi terverifikasi. Silakan ambil selfie.';
      } else {
        statusMessage = '❌ Anda di luar radius absensi';
        errorDetail = 'Jarak: ${distanceInMeters?.toStringAsFixed(0)}m';
      }

      isLoadingLocation = false;
      notifyListeners();
      return locationValid;
    } catch (e) {
      statusMessage = 'Gagal verifikasi lokasi';
      errorDetail = e.toString();
      isLoadingLocation = false;
      notifyListeners();
      return false;
    }
  }

  Future<File?> takePhoto({bool isCheckOut = false}) async {
    isTakingPhoto = true;
    notifyListeners();

    try {
      XFile? photo;
      try {
        photo = await imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 60,
          maxWidth: 1280,
          maxHeight: 1280,
        );
      } catch (_) {
        photo = await imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 60,
        );
      }

      if (photo == null) {
        isTakingPhoto = false;
        notifyListeners();
        return null;
      }

      final file = File(photo.path);
      if (!await file.exists()) throw Exception('File tidak ditemukan');

      if (isCheckOut) {
        try { if (checkOutPreviewFile != null && await checkOutPreviewFile!.exists()) await checkOutPreviewFile!.delete(); } catch (_) {}
        checkOutImage = photo;
        checkOutPreviewFile = file;
      } else {
        try { if (previewFile != null && await previewFile!.exists()) await previewFile!.delete(); } catch (_) {}
        capturedImage = photo;
        previewFile = file;
        statusMessage = '📸 Foto berhasil! Silakan submit.';
      }

      isTakingPhoto = false;
      notifyListeners();
      return file;
    } catch (e) {
      isTakingPhoto = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> pickBuktiFoto() async {
    try {
      XFile? photo;
      try {
        photo = await imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 60,
          maxWidth: 1280,
          maxHeight: 1280,
        );
      } catch (_) {
        photo = await imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 60,
        );
      }

      if (photo != null) {
        try { if (buktiFotoTerlambat != null && await buktiFotoTerlambat!.exists()) await buktiFotoTerlambat!.delete(); } catch (_) {}
        buktiFotoTerlambat = File(photo.path);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Gagal ambil foto bukti: $e');
    }
  }

  void clearBuktiFoto() {
    buktiFotoTerlambat = null;
    notifyListeners();
  }
}