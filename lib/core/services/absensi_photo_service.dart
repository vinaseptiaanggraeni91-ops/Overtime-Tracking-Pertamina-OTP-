// lib/core/services/absensi_photo_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'cloudinary_storage_service.dart';
import 'watermark_service.dart';
import 'absensi_state_service.dart';

class AbsensiPhotoService {
  final AbsensiStateService _stateService;
  final WatermarkService _watermarkService;
  final CloudinaryStorageService _cloudinaryService;
  final ImagePicker _imagePicker;

  XFile? _capturedImage;
  XFile? get capturedImage => _capturedImage;
  
  File? _previewFile;
  File? get previewFile => _previewFile;

  AbsensiPhotoService({
    required AbsensiStateService stateService,
    required WatermarkService watermarkService,
    required CloudinaryStorageService cloudinaryService,
    ImagePicker? imagePicker,
  })  : _stateService = stateService,
        _watermarkService = watermarkService,
        _cloudinaryService = cloudinaryService,
        _imagePicker = imagePicker ?? ImagePicker();

  /// Ambil foto selfie
  Future<XFile?> takeSelfie() async {
    try {
      _stateService.emit((s) => s.copyWith(
        statusMessage: 'Membuka kamera...',
      ));

      XFile? photo;

      // Coba kamera depan dulu
      try {
        photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 60,
          maxWidth: 1280,
          maxHeight: 1280,
        );
      } catch (_) {
        // Fallback ke gallery
        photo = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 60,
          maxWidth: 1280,
          maxHeight: 1280,
        );
      }

      if (photo == null) {
        _stateService.emit((s) => s.copyWith(
          statusMessage: 'Foto dibatalkan',
        ));
        return null;
      }

      // Validasi file
      final file = File(photo.path);
      if (!await file.exists()) {
        throw Exception('File foto tidak ditemukan');
      }

      // Simpan
      _capturedImage = photo;
      _previewFile = file;

      _stateService.emit((s) => s.copyWith(
        flow: AbsensiFlow.selfieReady,
        statusMessage: '📸 Foto berhasil! Silakan submit.',
      ));

      return photo;

    } catch (e) {
      _stateService.emit((s) => s.copyWith(
        statusMessage: 'Gagal mengambil foto',
        errorDetail: e.toString(),
      ));
      return null;
    }
  }

  /// Upload foto dengan watermark
  Future<String> uploadWithWatermark({
    required String photoPath,
    required String userName,
    required String lemburId,
    required double latitude,
    required double longitude,
    required String address,
    required bool isLate,
    required bool isCheckOut,
  }) async {
    _stateService.emit((s) => s.copyWith(
      statusMessage: 'Menambahkan watermark...',
    ));

    // Tambahkan watermark
    final label = isCheckOut 
        ? 'CHECK-OUT LEMBUR PGE' 
        : isLate 
            ? 'CHECK-IN LEMBUR TERLAMBAT PGE' 
            : 'CHECK-IN LEMBUR PGE';

    Uint8List watermarkedBytes;
    try {
      watermarkedBytes = await _watermarkService.addWatermark(
        imagePath: photoPath,
        latitude: latitude,
        longitude: longitude,
        address: address,
        timestamp: DateTime.now(),
        workerName: userName,
        customLabel: label,
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('⚠️ Watermark gagal, retry...');
      watermarkedBytes = await _watermarkService.addWatermark(
        imagePath: photoPath,
        latitude: latitude,
        longitude: longitude,
        address: address,
        timestamp: DateTime.now(),
        workerName: userName,
        customLabel: label,
      ).timeout(const Duration(seconds: 10));
    }

    // Simpan ke temp
    final dir = await getTemporaryDirectory();
    final uid = '${DateTime.now().microsecondsSinceEpoch}_${lemburId.hashCode}';
    final tempFile = File('${dir.path}/absensi_$uid.jpg');
    await tempFile.writeAsBytes(watermarkedBytes);

    // Upload ke Cloudinary
    _stateService.emit((s) => s.copyWith(
      statusMessage: 'Mengupload foto...',
    ));

    String? url;
    for (int i = 1; i <= 3; i++) {
      try {
        final result = await _cloudinaryService.uploadFoto(
          photoFile: tempFile,
          fileName: uid,
          lemburId: lemburId,
        ).timeout(const Duration(seconds: 60));

        if (result['success'] == true) {
          url = result['url'] as String;
          break;
        }
      } catch (e) {
        debugPrint('⚠️ Upload attempt $i gagal: $e');
        if (i >= 3) rethrow;
        await Future.delayed(Duration(seconds: i * 2));
      }
    }

    // Cleanup temp file
    try {
      if (await tempFile.exists()) await tempFile.delete();
    } catch (_) {}

    if (url == null) {
      throw Exception('Gagal upload foto setelah 3 percobaan');
    }

    return url;
  }

  /// Cleanup preview file
  Future<void> cleanupPreview() async {
    try {
      if (_previewFile != null && await _previewFile!.exists()) {
        await _previewFile!.delete();
      }
    } catch (_) {}
    _capturedImage = null;
    _previewFile = null;
  }

  void reset() {
    _capturedImage = null;
    _previewFile = null;
  }
}