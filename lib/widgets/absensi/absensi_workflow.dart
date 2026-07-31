// lib/core/services/absensi/absensi_workflow.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '/core/services/overtime_absensi_service.dart';
import '/core/services/watermark_service.dart';
import '/core/services/cloudinary_storage_service.dart';
import '/core/services/live_location_manager.dart';
import '/dashboard/mitra/absensi_state.dart';

class AbsensiWorkflow {
  final AbsensiState state;
  final OvertimeAbsensiService absensiService;
  final CloudinaryStorageService cloudinaryService;
  final WatermarkService watermarkService;
  final LiveLocationManager liveLocationManager;
  final String userId;

  AbsensiWorkflow({
    required this.state,
    required this.absensiService,
    required this.cloudinaryService,
    required this.watermarkService,
    required this.liveLocationManager,
    required this.userId,
  });

  // ═══════════════════════════════════════════
  // LOAD DATA
  // ═══════════════════════════════════════════
  Future<void> loadOvertimeData() async {
    if (state.hasCheckedIn && state.hasCheckedOut) return;

    state.viewState = AbsensiViewState.loading;
    state.statusMessage = 'Memuat data lembur...';
    state.refresh();

    try {
      await state.getWorkerName();

      // Coba restore live tracking
      if (liveLocationManager.isActive && !state.hasCheckedIn) {
        state.hasCheckedIn = true;
        state.checkInTime = liveLocationManager.startedAt;
        state.locationValid = true;
      }

      // Cari lembur hari ini
      final overtime = await absensiService.getTodayOvertimeForAbsensi(userId);
      
      // Load lembur terlambat untuk tab
      final lateList = await _loadLateOvertimeList();
      state.lateOvertimeList = lateList;

      if (overtime == null && lateList.isEmpty) {
        state.viewState = AbsensiViewState.noSchedule;
        state.statusMessage = 'Tidak ada jadwal lembur';
        state.refresh();
        return;
      }

      OvertimeHistory? activeOvertime = overtime;

      // Jika ada lembur hari ini, cek timing
      if (overtime != null) {
        final now = DateTime.now();
        final partsMulai = overtime.jamMulai.split(':');
        if (partsMulai.length == 2) {
          final jamMulai = DateTime(now.year, now.month, now.day,
              int.parse(partsMulai[0]), int.parse(partsMulai[1]));
          final earliestCheckIn = jamMulai.subtract(const Duration(minutes: 30));

          if (now.isBefore(earliestCheckIn) &&
              overtime.absensiStatus != 'check_in' &&
              overtime.absensiStatus != 'sudah_absen') {
            // Belum waktunya
            state.overtimeItem = overtime;
            state.viewState = AbsensiViewState.idle;
            state.statusMessage = 'Belum waktunya absen';
            state.refresh();
            return;
          }
        }
      }

      // Jika tidak ada lembur hari ini atau sudah waktunya, cek lembur terlambat
      if (overtime == null && lateList.isNotEmpty) {
        activeOvertime = lateList.first;
        state.isLateOvertime = true;
        state.currentTabIndex = 1;
      }

      if (activeOvertime == null) {
        state.viewState = AbsensiViewState.noSchedule;
        state.refresh();
        return;
      }

      // Setup active overtime
      state.overtimeItem = activeOvertime;
      
      // Cek status absensi
      final isCheckedIn = activeOvertime.checkInTime != null ||
          activeOvertime.absensiStatus == 'check_in' ||
          activeOvertime.absensiStatus == 'sudah_absen';

      if (isCheckedIn || state.hasCheckedIn) {
        state.hasCheckedIn = true;
        state.checkInTime = activeOvertime.checkInTime ?? DateTime.now();
        state.locationValid = true;
        
        if (activeOvertime.isCheckedOut || state.hasCheckedOut) {
          state.hasCheckedOut = true;
          state.viewState = AbsensiViewState.checkedOut;
          state.statusMessage = '✅ Lembur selesai!';
        } else {
          state.viewState = AbsensiViewState.checkedIn;
          _startLiveLocation();
          _startCheckOutTimer();
        }
        state.refresh();
        return;
      }

      // Belum check-in - tentukan status
      await _determineAbsensiStatus();

    } catch (e) {
      debugPrint('❌ loadOvertimeData error: $e');
      state.viewState = AbsensiViewState.noSchedule;
      state.statusMessage = 'Gagal memuat data';
      state.errorDetail = e.toString();
      state.refresh();
    }
  }

  Future<List<OvertimeHistory>> _loadLateOvertimeList() async {
    try {
      final allPending = await absensiService.getLemburNeedAbsensi(
        userId: userId,
        userRole: 'mitra',
      );

      final now = DateTime.now();
      final lateList = <OvertimeHistory>[];

      for (final item in allPending) {
        final partsSelesai = item.jamSelesai.split(':');
        if (partsSelesai.length != 2) continue;

        var jamSelesai = DateTime(item.tanggal.year, item.tanggal.month, item.tanggal.day,
            int.parse(partsSelesai[0]), int.parse(partsSelesai[1]));
        
        final partsMulai = item.jamMulai.split(':');
        if (partsMulai.length == 2) {
          final jamMulai = DateTime(item.tanggal.year, item.tanggal.month, item.tanggal.day,
              int.parse(partsMulai[0]), int.parse(partsMulai[1]));
          if (jamSelesai.isBefore(jamMulai)) jamSelesai = jamSelesai.add(const Duration(days: 1));
        }

        final batasNormal = jamSelesai.add(const Duration(hours: 2));
        final batasExpired = jamSelesai.add(const Duration(days: 3));

        if (now.isAfter(batasNormal) && now.isBefore(batasExpired) && !item.isAbsensiResolved) {
          lateList.add(item);
        }
      }

      lateList.sort((a, b) => a.tanggal.compareTo(b.tanggal));
      return lateList;
    } catch (e) {
      debugPrint('❌ _loadLateOvertimeList error: $e');
      return [];
    }
  }

  Future<void> _determineAbsensiStatus() async {
    if (state.overtimeItem == null) return;

    final now = DateTime.now();
    final partsMulai = state.overtimeItem!.jamMulai.split(':');
    final partsSelesai = state.overtimeItem!.jamSelesai.split(':');

    if (partsMulai.length != 2 || partsSelesai.length != 2) return;

    final tanggal = state.overtimeItem!.tanggal;
    var jamSelesai = DateTime(tanggal.year, tanggal.month, tanggal.day,
        int.parse(partsSelesai[0]), int.parse(partsSelesai[1]));
    final jamMulai = DateTime(tanggal.year, tanggal.month, tanggal.day,
        int.parse(partsMulai[0]), int.parse(partsMulai[1]));
    if (jamSelesai.isBefore(jamMulai)) jamSelesai = jamSelesai.add(const Duration(days: 1));

    final batasNormal = jamSelesai.add(const Duration(hours: 2));
    final batasExpired = jamSelesai.add(const Duration(days: 3));

    if (now.isAfter(batasNormal) && now.isBefore(batasExpired)) {
      // Terlambat
      state.isLateOvertime = true;
      state.viewState = AbsensiViewState.lateBanner;
      state.statusMessage = '⚠️ ANDA TERLAMBAT!';
      state.errorDetail = 'Batas normal: ${DateFormat('HH:mm').format(batasNormal)}';
    } else if (now.isAfter(batasExpired)) {
      state.viewState = AbsensiViewState.noSchedule;
      state.statusMessage = '❌ Waktu absensi sudah kadaluarsa (3 hari)';
    } else {
      // Normal - siap absensi
      state.viewState = AbsensiViewState.ready;
      state.statusMessage = '✅ Silakan verifikasi lokasi';
    }

    state.refresh();
  }

  // ═══════════════════════════════════════════
  // TAB NAVIGATION
  // ═══════════════════════════════════════════
  Future<void> selectLateOvertime(OvertimeHistory item) async {
    state.resetForNewOvertime();
    state.overtimeItem = item;
    state.isLateOvertime = true;
    state.isViewingLateOvertime = true;
    state.viewState = AbsensiViewState.lateBanner;
    state.statusMessage = '⚠️ Lembur Terlambat - ${DateFormat('dd MMM yyyy').format(item.tanggal)}';
    state.refresh();
    await _determineAbsensiStatus();
  }

  Future<void> switchToNormalAbsensi() async {
    state.resetForNewOvertime();
    state.isLateOvertime = false;
    state.isViewingLateOvertime = false;
    state.currentTabIndex = 0;
    await loadOvertimeData();
  }

  // ═══════════════════════════════════════════
  // SUBMIT CHECK-IN
  // ═══════════════════════════════════════════
  Future<bool> submitCheckIn() async {
    if (state.isSubmitting || state.capturedImage == null || state.currentPosition == null || state.overtimeItem == null) {
      return false;
    }

    state.isSubmitting = true;
    state.statusMessage = '🔄 Menyiapkan upload...';
    state.refresh();

    try {
      final workerName = await state.getWorkerName();

      // Upload foto dengan retry
      final fotoUrl = await _uploadPhotoWithRetry(
        imagePath: state.capturedImage!.path,
        fileNamePrefix: 'ci_$userId',
        workerName: workerName,
        label: state.isLateOvertime ? 'CHECK-IN LEMBUR TERLAMBAT' : 'CHECK-IN LEMBUR',
      );

      if (fotoUrl == null) throw Exception('Gagal upload foto');

      // Submit ke Firestore
      state.statusMessage = '📝 Menyimpan data...';
      state.refresh();

      final result = await absensiService.submitAbsensi(
        docId: state.overtimeItem!.id,
        fotoUrl: fotoUrl,
        userId: userId,
        userName: workerName,
        latitude: state.currentPosition!.latitude,
        longitude: state.currentPosition!.longitude,
        address: state.currentAddress,
      );

      if (result['success'] != true) throw Exception(result['message'] ?? 'Gagal menyimpan');

      // Success
      final now = DateTime.now();
      state.hasCheckedIn = true;
      state.checkInTime = now;
      state.locationValid = true;
      state.viewState = AbsensiViewState.checkedIn;
      state.statusMessage = '✅ Check-in berhasil!';
      state.capturedImage = null;
      state.previewFile = null;
      state.isSubmitting = false;
      state.refresh();

      await _startLiveLocation();
      _startCheckOutTimer();

      // Refresh late list
      await loadOvertimeData();

      return true;
    } catch (e) {
      state.isSubmitting = false;
      state.statusMessage = 'Gagal submit';
      state.errorDetail = e.toString();
      state.refresh();
      return false;
    }
  }

  // ═══════════════════════════════════════════
  // SUBMIT CHECK-OUT
  // ═══════════════════════════════════════════
  Future<bool> performCheckOut() async {
    if (state.isCheckingOut || state.checkOutImage == null || state.overtimeItem == null) return false;

    state.isCheckingOut = true;
    state.statusMessage = '🔄 Menyiapkan check-out...';
    state.refresh();

    try {
      final workerName = await state.getWorkerName();

      // Refresh lokasi
      final pos = await GeolocatorPlatform.instance.getCurrentPosition();
      state.currentPosition = pos;

      final fotoUrl = await _uploadPhotoWithRetry(
        imagePath: state.checkOutImage!.path,
        fileNamePrefix: 'co_$userId',
        workerName: workerName,
        label: 'CHECK-OUT LEMBUR',
      );

      if (fotoUrl == null) throw Exception('Gagal upload foto');

      await liveLocationManager.stopTracking();
      
      await absensiService.submitCheckOut(
        docId: state.overtimeItem!.id,
        userId: userId,
        userName: workerName,
        fotoUrl: fotoUrl,
        latitude: pos.latitude,
        longitude: pos.longitude,
        address: state.currentAddress,
      );

      cancelAllTimers();

      state.isCheckingOut = false;
      state.hasCheckedOut = true;
      state.canCheckOut = false;
      state.viewState = AbsensiViewState.checkedOut;
      state.statusMessage = '✅ Check-out berhasil!';
      state.refresh();

      return true;
    } catch (e) {
      state.isCheckingOut = false;
      state.statusMessage = 'Gagal check-out';
      state.errorDetail = e.toString();
      state.refresh();
      return false;
    }
  }

  // ═══════════════════════════════════════════
  // KONFIRMASI KETERLAMBATAN
  // ═══════════════════════════════════════════
  Future<bool> submitKonfirmasi() async {
    if (state.melakukanLembur == null) return false;
    if (state.alasanController.text.trim().isEmpty) return false;
    if (state.melakukanLembur == true && state.buktiFotoTerlambat == null) return false;

    state.isSubmitting = true;
    state.statusMessage = '🔄 Memproses konfirmasi...';
    state.refresh();

    try {
      final workerName = await state.getWorkerName();
      String? fotoUrl;

      if (state.melakukanLembur == true && state.buktiFotoTerlambat != null) {
        fotoUrl = await _uploadPhotoWithRetry(
          imagePath: state.buktiFotoTerlambat!.path,
          fileNamePrefix: 'bukti_terlambat',
          workerName: workerName,
          label: 'BUKTI LEMBUR TERLAMBAT',
        );
      }

      final result = await absensiService.konfirmasiKeterlambatan(
        lemburId: state.overtimeItem!.id,
        userId: userId,
        userName: workerName,
        melakukanLembur: state.melakukanLembur!,
        alasan: state.alasanController.text.trim(),
        buktiFotoUrl: fotoUrl,
      );

      if (result['success'] != true) throw Exception(result['message']);

      final memilihLembur = state.melakukanLembur; // ✅ Simpan dulu sebelum di-null-kan

      if (memilihLembur == true) {
        state.hasCheckedIn = true;
        state.checkInTime = DateTime.now();
        state.locationValid = true;
        state.viewState = AbsensiViewState.checkedIn;
        await _startLiveLocation();
        _startCheckOutTimer();
      }

      state.isSubmitting = false;
      state.melakukanLembur = null;
      state.alasanController.clear();
      state.buktiFotoTerlambat = null;
      state.statusMessage = memilihLembur == true
          ? '✅ Check-in berhasil via konfirmasi!'
          : '✅ Konfirmasi berhasil!';
      state.refresh();

      await loadOvertimeData();
      return true;
    } catch (e) {
      state.isSubmitting = false;
      state.statusMessage = 'Gagal konfirmasi';
      state.errorDetail = e.toString();
      state.refresh();
      return false;
    }
  }

  void showKonfirmasiForm() {
    state.viewState = AbsensiViewState.lateForm;
    state.refresh();
  }

  void hideKonfirmasiForm() {
    state.viewState = AbsensiViewState.lateBanner;
    state.melakukanLembur = null;
    state.alasanController.clear();
    state.buktiFotoTerlambat = null;
    state.refresh();
  }

  // ═══════════════════════════════════════════
  // LIVE LOCATION
  // ═══════════════════════════════════════════
  Future<void> _startLiveLocation() async {
    if (state.overtimeItem == null || userId.isEmpty) return;

    try {
      await liveLocationManager.startTracking(
        userId: userId,
        userName: await state.getWorkerName(),
        lemburId: state.overtimeItem!.id,
        intervalSeconds: 60,
        userRole: 'mitra',
        userFungsi: 'lembur',
      );
      state.refresh();
    } catch (e) {
      debugPrint('Gagal start live location: $e');
    }
  }

  Future<void> stopLiveLocation() async {
    await liveLocationManager.stopTracking();
    state.refresh();
  }

  // ═══════════════════════════════════════════
  // CHECK-OUT TIMER
  // ═══════════════════════════════════════════
  void _startCheckOutTimer() {
    if (state.overtimeItem == null) return;

    cancelAllTimers();

    try {
      final now = DateTime.now();
      final parts = state.overtimeItem!.jamSelesai.split(':');
      if (parts.length != 2) return;

      final jamSelesai = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
      final checkOutStart = jamSelesai.subtract(const Duration(minutes: 30));
      final checkOutEnd = jamSelesai.add(const Duration(hours: 2));

      state.canCheckOut = now.isAfter(checkOutStart) && now.isBefore(checkOutEnd);
      state.refresh();

      if (!state.canCheckOut && now.isBefore(checkOutStart)) {
        state.checkOutTimer = Timer(checkOutStart.difference(now), () {
          state.canCheckOut = true;
          state.refresh();
        });
      }
    } catch (e) {
      debugPrint('Error check-out timer: $e');
    }
  }

  void cancelAllTimers() {
    state.checkOutTimer?.cancel();
    state.countdownTimer?.cancel();
  }

  // ═══════════════════════════════════════════
  // UPLOAD PHOTO HELPER
  // ═══════════════════════════════════════════
  Future<String?> _uploadPhotoWithRetry({
    required String imagePath,
    required String fileNamePrefix,
    required String workerName,
    required String label,
  }) async {
    try {
      // Watermark
      Uint8List watermarkedBytes;
      try {
        watermarkedBytes = await watermarkService.addWatermark(
          imagePath: imagePath,
          latitude: state.currentPosition?.latitude ?? 0,
          longitude: state.currentPosition?.longitude ?? 0,
          address: state.currentAddress ?? 'Lokasi Absensi',
          timestamp: DateTime.now(),
          workerName: workerName,
          customLabel: label,
        );
      } catch (_) {
        watermarkedBytes = await File(imagePath).readAsBytes();
      }

      // Simpan sementara
      final dir = await getTemporaryDirectory();
      final fileName = '${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}';
      final tempFile = File('${dir.path}/$fileName.jpg');
      await tempFile.writeAsBytes(watermarkedBytes);

      // Upload dengan retry
      String? url;
      for (int i = 0; i < 3; i++) {
        try {
          final result = await cloudinaryService.uploadFoto(
            photoFile: tempFile,
            fileName: fileName,
            lemburId: state.overtimeItem!.id,
          );
          if (result['success'] == true) {
            url = result['url'] as String;
            break;
          }
        } catch (_) {
          if (i == 2) rethrow;
          await Future.delayed(Duration(seconds: (i + 1) * 2));
        }
      }

      // Cleanup
      try { if (await tempFile.exists()) await tempFile.delete(); } catch (_) {}

      return url;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  void dispose() {
    cancelAllTimers();
  }
}