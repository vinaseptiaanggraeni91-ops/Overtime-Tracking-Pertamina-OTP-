import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

// Service imports
import '/core/services/overtime_absensi_service.dart';
import '/core/services/watermark_service.dart';
import '/core/services/cloudinary_storage_service.dart';
import '/widgets/absensi/location_validator.dart';

/// ============================================================================
/// ABSENSI DIALOG WIDGET
/// ============================================================================

class AbsensiDialog extends StatefulWidget {
  final OvertimeHistory overtimeItem;
  final bool isCheckOut;

  const AbsensiDialog({
    super.key,
    required this.overtimeItem,
    this.isCheckOut = false,
  });

  /// Show absensi dialog as modal bottom sheet
  /// Returns true if absensi berhasil, false if gagal, null if dibatalkan
  static Future<bool?> show(
    BuildContext context,
    OvertimeHistory overtimeItem, {
    bool isCheckOut = false,
  }) {
    if (!context.mounted) {
      debugPrint('AbsensiDialog: Context not mounted');
      return Future.value(null);
    }

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => AbsensiDialog(
        overtimeItem: overtimeItem,
        isCheckOut: isCheckOut,
      ),
    );
  }

  @override
  State<AbsensiDialog> createState() => _AbsensiDialogState();
}

/// ============================================================================
/// STATE
/// ============================================================================

class _AbsensiDialogState extends State<AbsensiDialog> {
  // ===========================================================================
  // SERVICES
  // ===========================================================================
  final ImagePicker _imagePicker = ImagePicker();
  final LocationValidator _locationValidator = LocationValidator();
  final WatermarkService _watermarkService = WatermarkService();
  final OvertimeAbsensiService _absensiService = OvertimeAbsensiService();
  final CloudinaryStorageService _cloudinaryService = CloudinaryStorageService();

  // ===========================================================================
  // STATES
  // ===========================================================================
  bool _isLoadingLocation = false;
  bool _isTakingPhoto = false;
  bool _isSubmitting = false;
  String _statusMessage = 'Memverifikasi lokasi Anda...';
  String? _errorDetail;
  Position? _currentPosition;
  String? _currentAddress;
  XFile? _capturedImage;
  File? _previewFile;
  bool _locationValid = false;
  bool _hasAttemptedRetry = false;
  double? _distanceInMeters;
  double? _maxRadius;
  static const int _maxRetries = 2;

  bool _isCheckingStatus = true;
  bool _isLate = false;
  bool _canConfirm = false;
  bool _showKonfirmasiForm = false;
  bool? _melakukanLembur;
  final TextEditingController _alasanController = TextEditingController();
  File? _buktiFotoTerlambat;

  // ═══════════════════════════════════════════════════════
  // 🔥 FIX: Tambah flag untuk cegah double-init
  // ═══════════════════════════════════════════════════════
  bool _hasInitialized = false;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasInitialized) {
        _hasInitialized = true;
        _initCheck();
      }
    });
  }

  @override
  void dispose() {
    _cleanupPreviewFile();
    _alasanController.dispose();
    super.dispose();
  }

  /// Hapus file preview untuk hemat storage
  Future<void> _cleanupPreviewFile() async {
    try {
      if (_previewFile != null && await _previewFile!.exists()) {
        await _previewFile!.delete();
        debugPrint('Absensi: Preview file cleaned up');
      }
    } catch (e) {
      debugPrint('Absensi: Failed to cleanup preview file: $e');
    }
  }

  // ===========================================================================
  // SAFE HELPERS
  // ===========================================================================

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle
                  : color == Colors.red
                      ? Icons.error
                      : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _updateStatus(String message, {String? errorDetail}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _errorDetail = errorDetail;
    });
  }

  // ===========================================================================
  // ═══════════════════════════════════════════════════════════════════
  // 🔥🔥🔥 INIT CHECK - SUDAH DIFIX! 🔥🔥🔥
  // ═══════════════════════════════════════════════════════════════════
  // ===========================================================================

  Future<void> _initCheck() async {
    setState(() {
      _isCheckingStatus = true;
      _statusMessage = 'Mengecek status absensi...';
    });

    try {
      // ═══════════════════════════════════════════════════
      // 🔥 FIX: Cek waktu SECARA LOKAL dulu
      // ═══════════════════════════════════════════════════
      final now = DateTime.now();
      final overtimeItem = widget.overtimeItem;

      // Parse jam selesai dari overtime
      final tanggal = overtimeItem.tanggal;
      final jamSelesaiStr = overtimeItem.jamSelesai;
      final selesaiParts = jamSelesaiStr.split(':');
      final selesaiJam = int.tryParse(selesaiParts[0]) ?? 0;
      final selesaiMenit =
          selesaiParts.length > 1 ? (int.tryParse(selesaiParts[1]) ?? 0) : 0;
      var selesaiTime = DateTime(
        tanggal.year,
        tanggal.month,
        tanggal.day,
        selesaiJam,
        selesaiMenit,
      );

      // Parse jam mulai untuk adjust (lembur lintas hari)
      final jamMulaiStr = overtimeItem.jamMulai;
      final mulaiParts = jamMulaiStr.split(':');
      final mulaiJam = int.tryParse(mulaiParts[0]) ?? 0;
      final mulaiMenit =
          mulaiParts.length > 1 ? (int.tryParse(mulaiParts[1]) ?? 0) : 0;
      final mulaiTime = DateTime(
        tanggal.year,
        tanggal.month,
        tanggal.day,
        mulaiJam,
        mulaiMenit,
      );

      // Adjust jika jam selesai < jam mulai (lembur lintas hari)
      if (selesaiTime.isBefore(mulaiTime)) {
        selesaiTime = selesaiTime.add(const Duration(days: 1));
      }

      // ✅ Batas normal absensi: jam selesai + 30 menit
      final batasNormal =
          selesaiTime.add(const Duration(minutes: 30));

      // ✅ Cek: apakah sekarang sudah lewat batas normal?
      final isActuallyLate = now.isAfter(batasNormal);

      // 🔥 DEBUG LOGGING
      debugPrint('═══════════════════════════════════');
      debugPrint('🔍 _initCheck - LOCAL TIME CHECK:');
      debugPrint('  - Lembur ID: ${overtimeItem.id}');
      debugPrint(
          '  - Tanggal: ${DateFormat('dd MMM yyyy').format(tanggal)}');
      debugPrint('  - Jam Mulai: $jamMulaiStr');
      debugPrint('  - Jam Selesai: $jamSelesaiStr');
      debugPrint(
          '  - Selesai Time: ${DateFormat('dd/MM HH:mm').format(selesaiTime)}');
      debugPrint(
          '  - Batas Normal: ${DateFormat('dd/MM HH:mm').format(batasNormal)}');
      debugPrint(
          '  - Now: ${DateFormat('dd/MM HH:mm').format(now)}');
      debugPrint('  - isActuallyLate: $isActuallyLate');
      debugPrint('═══════════════════════════════════');

      // ═══════════════════════════════════════════════════
      // ✅ MASIH NORMAL — Langsung verifikasi lokasi
      // ═══════════════════════════════════════════════════
      if (!isActuallyLate) {
        if (mounted) {
          setState(() {
            _isCheckingStatus = false;
            _canConfirm = false;
            _isLate = false;
            _statusMessage = 'Memverifikasi lokasi Anda...';
            _errorDetail = null;
          });
          _startLocationVerification();
        }
        return;
      }

      // ═══════════════════════════════════════════════════
      // ✅ SUDAH TERLAMBAT — Cek ke service
      // ═══════════════════════════════════════════════════
      final status = await _absensiService
          .cekStatusKeterlambatan(overtimeItem.id)
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
          _isLate = status['isLate'] == true || isActuallyLate;
          _canConfirm = status['canConfirm'] == true || isActuallyLate;

          if (_canConfirm) {
            _statusMessage = '⚠️ Sudah lewat batas absensi normal';
            _errorDetail =
                'Anda dapat mengkonfirmasi keterlambatan\n'
                'Batas normal: ${DateFormat('HH:mm').format(batasNormal)} WIB';
          } else {
            _statusMessage = 'Memverifikasi lokasi Anda...';
            _startLocationVerification();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ _initCheck error: $e');
      // Fallback: anggap normal, langsung verifikasi lokasi
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
          _canConfirm = false;
          _isLate = false;
          _statusMessage = 'Memverifikasi lokasi Anda...';
          _errorDetail = null;
        });
        _startLocationVerification();
      }
    }
  }

  // ===========================================================================
  // LOCATION VERIFICATION
  // ===========================================================================

  Future<void> _startLocationVerification() async {
    // Anti double-tap
    if (_isLoadingLocation || _isSubmitting) {
      debugPrint('Absensi: Already processing, ignoring location request');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
      _statusMessage = 'Memverifikasi lokasi Anda...';
      _errorDetail = null;
    });

    try {
      // Check GPS service
      _updateStatus('Memeriksa GPS...');
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _updateStatus(
          'GPS tidak aktif',
          errorDetail: 'Aktifkan GPS di pengaturan perangkat Anda',
        );
        if (mounted) {
          _showRetryDialog(
            'GPS Tidak Aktif',
            'Aktifkan GPS terlebih dahulu untuk melakukan absensi.',
          );
        }
        return;
      }

      // Check permission
      _updateStatus('Memeriksa izin lokasi...');
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        _updateStatus('Meminta izin lokasi...');
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _updateStatus(
          'Izin lokasi ditolak',
          errorDetail: 'Anda harus mengizinkan akses lokasi untuk absensi',
        );
        if (mounted) {
          _showRetryDialog(
            'Izin Lokasi Diperlukan',
            'Izinkan akses lokasi untuk memverifikasi posisi Anda.',
          );
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _updateStatus(
          'Izin lokasi ditolak permanen',
          errorDetail: 'Buka Pengaturan > Aplikasi > Izin > Lokasi',
        );
        if (mounted) _showOpenSettingsDialog();
        return;
      }

      // Get current location
      _updateStatus('Mendapatkan lokasi...');
      final position =
          await _locationValidator.getCurrentLocation().timeout(
                const Duration(seconds: 25),
                onTimeout: () =>
                    throw TimeoutException('Waktu mendapatkan lokasi habis'),
              );

      if (position == null) {
        _updateStatus(
          'Gagal mendapatkan lokasi',
          errorDetail:
              'Pastikan Anda berada di area dengan sinyal GPS yang baik',
        );
        return;
      }

      _currentPosition = position;
      debugPrint(
          'Absensi: Location obtained - ${position.latitude}, ${position.longitude}');

      // Get address (optional, non-blocking)
      _updateStatus('Mendapatkan alamat...');
      try {
        _currentAddress = await _locationValidator
            .getAddressFromCoordinates(
                position.latitude, position.longitude)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Absensi: Address lookup failed: $e');
        _currentAddress = 'Alamat tidak tersedia';
      }

      // Validate location against overtime item
      _updateStatus('Memvalidasi lokasi...');
      final validationResult = await _locationValidator
          .validateLocation(
            currentLat: position.latitude,
            currentLng: position.longitude,
            overtimeItem: widget.overtimeItem,
          )
          .timeout(const Duration(seconds: 15));

      _locationValid = validationResult['valid'] as bool? ?? false;
      _distanceInMeters = validationResult['distance'] as double?;
      _maxRadius = validationResult['max_radius'] as double?;

      if (!mounted) return;

      setState(() {
        _isLoadingLocation = false;

        if (_locationValid) {
          _statusMessage = '✅ Lokasi valid! Silakan ambil selfie.';
          _errorDetail = null;
        } else {
          _statusMessage = '❌ Anda berada di luar radius absensi.';
          if (_distanceInMeters != null && _maxRadius != null) {
            _errorDetail =
                'Jarak Anda ${_distanceInMeters!.toStringAsFixed(0)}m '
                'dari lokasi. Maksimal ${_maxRadius!.toStringAsFixed(0)}m.';
          } else {
            _errorDetail =
                'Pastikan Anda berada di lokasi yang ditentukan.';
          }
        }
      });
    } on TimeoutException catch (e) {
      debugPrint('Absensi: Location timeout: $e');
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      _updateStatus(
        'Waktu verifikasi habis',
        errorDetail: 'Koneksi lambat atau sinyal GPS lemah',
      );
      _showSnackBar(
        'Timeout. Silakan coba lagi dengan koneksi yang lebih baik.',
        Colors.orange,
      );
    } catch (e) {
      debugPrint('Absensi: Location verification error: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _statusMessage = 'Gagal verifikasi lokasi';
        _errorDetail = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ===========================================================================
  // TAKE SELFIE (WITH FALLBACK)
  // ===========================================================================

  Future<void> _takeSelfie() async {
    if (_isTakingPhoto || _isSubmitting) {
      debugPrint('Absensi: Already taking photo or submitting');
      return;
    }

    if (!_locationValid) {
      _showSnackBar(
          'Lokasi tidak valid. Silakan verifikasi ulang.', Colors.red);
      return;
    }

    if (!mounted) return;

    setState(() {
      _isTakingPhoto = true;
      _statusMessage = 'Membuka kamera...';
    });

    try {
      XFile? photo;

      // Attempt 1: Front Camera (Selfie)
      try {
        _updateStatus('Mengambil foto (kamera depan)...');
        photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 60,
          maxWidth: 1280,
          maxHeight: 1280,
        );
      } catch (e) {
        debugPrint('Absensi: Front camera failed: $e');

        // Attempt 2: Rear Camera
        try {
          _updateStatus('Mengambil foto (kamera belakang)...');
          photo = await _imagePicker.pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.rear,
            imageQuality: 60,
            maxWidth: 1280,
            maxHeight: 1280,
          );
        } catch (e2) {
          debugPrint('Absensi: Rear camera also failed: $e2');

          // Attempt 3: Gallery (Last Resort)
          _updateStatus('Kamera tidak tersedia, membuka galeri...');
          photo = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 60,
            maxWidth: 1280,
            maxHeight: 1280,
          );
        }
      }

      if (!mounted) return;

      // User cancelled
      if (photo == null) {
        setState(() {
          _isTakingPhoto = false;
          _statusMessage = _locationValid
              ? '✅ Lokasi valid! Silakan ambil selfie.'
              : _statusMessage;
        });
        _showSnackBar('Pengambilan foto dibatalkan.', Colors.grey);
        return;
      }

      // Validate file
      final file = File(photo.path);
      if (!await file.exists()) {
        throw Exception('File foto tidak ditemukan setelah diambil');
      }

      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception(
          'Ukuran foto terlalu besar '
          '(${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). Maksimal 10MB.',
        );
      }

      if (!mounted) return;

      // Cleanup old preview
      await _cleanupPreviewFile();

      setState(() {
        _capturedImage = photo;
        _previewFile = file;
        _isTakingPhoto = false;
        _statusMessage = '📸 Foto berhasil! Silakan submit absensi.';
        _errorDetail = null;
      });
    } catch (e) {
      debugPrint('Absensi: Photo capture error: $e');
      if (!mounted) return;
      setState(() {
        _isTakingPhoto = false;
        _statusMessage = 'Gagal mengambil foto';
        _errorDetail = e.toString().replaceAll('Exception: ', '');
      });
      _showSnackBar(
        'Gagal mengambil foto: ${e.toString().replaceAll('Exception: ', '')}',
        Colors.red,
      );
    }
  }

  // ===========================================================================
  // PICK BUKTI FOTO (KONFIRMASI KETERLAMBATAN)
  // ===========================================================================

  Future<void> _pickBuktiFoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (photo != null && mounted) {
        setState(() => _buktiFotoTerlambat = File(photo.path));
      }
    } catch (e) {
      _showSnackBar('Gagal mengambil foto: $e', Colors.red);
    }
  }

  // ===========================================================================
  // SUBMIT ABSENSI (CLOUDINARY VERSION)
  // ===========================================================================

  Future<void> _submitAbsensi() async {
    // Anti double-submit
    if (_isSubmitting) {
      debugPrint('Absensi: Already submitting');
      return;
    }

    // Validasi
    if (_capturedImage == null) {
      _showSnackBar('Silakan ambil foto terlebih dahulu.', Colors.orange);
      return;
    }
    if (_currentPosition == null) {
      _showSnackBar(
          'Lokasi tidak tersedia. Silakan verifikasi ulang.', Colors.red);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('Anda harus login terlebih dahulu.', Colors.red);
      return;
    }

    File? tempFile;

    try {
      if (!mounted) return;

      setState(() {
        _isSubmitting = true;
        _statusMessage = '🔄 Menyiapkan upload...';
        _errorDetail = null;
      });

      // =====================================================================
      // STEP 1: ADD WATERMARK
      // =====================================================================
      _updateStatus('🎨 Menambahkan watermark...');

      Uint8List watermarkedBytes;
      try {
        watermarkedBytes = await _watermarkService
            .addWatermark(
              imagePath: _capturedImage!.path,
              latitude: _currentPosition!.latitude,
              longitude: _currentPosition!.longitude,
              address: _currentAddress ?? 'Alamat tidak tersedia',
              timestamp: DateTime.now(),
              workerName: currentUser.displayName ?? 'Mitra',
            )
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('Absensi: Watermark failed: $e');
        _updateStatus('⚠️ Watermark gagal, menggunakan foto original...');
        final originalFile = File(_capturedImage!.path);
        watermarkedBytes = await originalFile.readAsBytes();
      }

      if (watermarkedBytes.isEmpty) {
        throw Exception('Data foto kosong setelah processing');
      }

      if (!mounted) return;

      // =====================================================================
      // STEP 2: CREATE TEMP FILE
      // =====================================================================
      _updateStatus('💾 Menyimpan file sementara...');

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueId = '${currentUser.uid}_$timestamp';
      tempFile = File('${tempDir.path}/absensi_$uniqueId.jpg');
      await tempFile.writeAsBytes(watermarkedBytes);

      if (!mounted) return;

      // =====================================================================
      // STEP 3: UPLOAD TO CLOUDINARY (GRATIS 25GB!)
      // =====================================================================
      _updateStatus('☁️ Mengupload ke Cloudinary...');

      String? fotoUrl;
      int uploadAttempt = 0;

      while (uploadAttempt <= _maxRetries && fotoUrl == null) {
        try {
          uploadAttempt++;
          final result = await _cloudinaryService
              .uploadFoto(
                photoFile: tempFile,
                fileName: uniqueId,
                lemburId: widget.overtimeItem.id,
              )
              .timeout(const Duration(seconds: 60));

          if (result['success'] == true) {
            fotoUrl = result['url'] as String;
            debugPrint('Cloudinary upload success: $fotoUrl');
          } else {
            throw Exception(result['message'] ?? 'Upload gagal');
          }
        } on TimeoutException {
          debugPrint(
              'Absensi: Upload timeout on attempt $uploadAttempt');
          if (uploadAttempt > _maxRetries) {
            throw TimeoutException(
              'Upload gagal setelah $_maxRetries kali percobaan',
            );
          }
          _updateStatus('⏳ Upload lambat, mencoba lagi...');
          await Future.delayed(Duration(seconds: uploadAttempt * 2));
        } catch (e) {
          debugPrint(
              'Absensi: Upload error on attempt $uploadAttempt: $e');
          if (uploadAttempt > _maxRetries) rethrow;
          _updateStatus('⏳ Error, mencoba lagi...');
          await Future.delayed(Duration(seconds: uploadAttempt * 2));
        }
      }

      if (fotoUrl == null) {
        throw Exception('Gagal upload foto ke Cloudinary');
      }

      if (!mounted) return;

      // =====================================================================
      // STEP 4: SAVE TO FIRESTORE
      // =====================================================================
      _updateStatus('📝 Menyimpan data absensi...');

      final result = await _absensiService.submitAbsensi(
        docId: widget.overtimeItem.id,
        fotoUrl: fotoUrl,
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'Mitra',
      );

      if (!mounted) return;

      if (result['success'] == true) {
        debugPrint('Absensi: Absensi saved successfully!');
        Navigator.pop(context, true);
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _showSnackBar(
                '✅ Absensi berhasil disimpan!', Colors.green);
          }
        });
      } else {
        // Rollback: hapus foto dari Cloudinary jika save gagal
        if (result['publicId'] != null) {
          await _cloudinaryService.deleteFoto(result['publicId']);
        }
        throw Exception(
            result['message'] ?? 'Gagal menyimpan data absensi');
      }
    } on TimeoutException catch (e) {
      debugPrint('Absensi: Submit timeout: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _updateStatus(
        'Koneksi timeout',
        errorDetail: 'Periksa koneksi internet Anda dan coba lagi',
      );
      _showSnackBar(
          'Upload timeout. Periksa koneksi internet Anda.', Colors.red);
    } catch (e) {
      debugPrint('Absensi: Submit error: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _updateStatus(
        'Gagal submit absensi',
        errorDetail: e.toString().replaceAll('Exception: ', ''),
      );
      _showSnackBar('Terjadi kesalahan. Silakan coba lagi.', Colors.red);
    } finally {
      // Cleanup temp file
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
          debugPrint('Absensi: Temp file cleaned up');
        }
      } catch (e) {
        debugPrint('Absensi: Failed to cleanup temp file: $e');
      }
    }
  }

  // ===========================================================================
  // SUBMIT KONFIRMASI KETERLAMBATAN
  // ===========================================================================

  Future<void> _submitKonfirmasi() async {
    if (_melakukanLembur == null) {
      _showSnackBar(
          'Pilih apakah Anda melakukan lembur atau tidak', Colors.orange);
      return;
    }
    if (_alasanController.text.trim().isEmpty) {
      _showSnackBar('Alasan wajib diisi', Colors.orange);
      return;
    }
    if (_melakukanLembur == true && _buktiFotoTerlambat == null) {
      _showSnackBar(
          'Upload foto bukti wajib jika menyatakan tetap lembur',
          Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? fotoUrl;
      if (_buktiFotoTerlambat != null) {
        final uploadResult = await _cloudinaryService.uploadFoto(
          photoFile: _buktiFotoTerlambat!,
          fileName: 'bukti_${DateTime.now().millisecondsSinceEpoch}',
          lemburId: widget.overtimeItem.id,
        );
        if (uploadResult['success'] == true) {
          fotoUrl = uploadResult['url'] as String;
        }
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      final result = await _absensiService.konfirmasiKeterlambatan(
        lemburId: widget.overtimeItem.id,
        userId: currentUser?.uid ?? '',
        userName: currentUser?.displayName ?? 'Mitra',
        melakukanLembur: _melakukanLembur!,
        alasan: _alasanController.text.trim(),
        buktiFotoUrl: fotoUrl,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pop(context, true);
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted)
            _showSnackBar('✅ ${result['message']}', Colors.green);
        });
      } else {
        _showSnackBar(result['message'] ?? 'Gagal', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Gagal: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ===========================================================================
  // DIALOG HELPERS
  // ===========================================================================

  void _showRetryDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content:
            Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startLocationVerification();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Coba Lagi',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Izin Lokasi Diperlukan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Buka Pengaturan > Aplikasi > Pilih Aplikasi > Izin > Lokasi > Izinkan',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Geolocator.openLocationSettings();
              } catch (e) {
                debugPrint('Absensi: Cannot open settings: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Buka Pengaturan',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    // LOADING STATE
    if (_isCheckingStatus) {
      return SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                    color: Color(0xFF1A237E)),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        height: mediaQuery.size.height * 0.92,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: IgnorePointer(
          ignoring: _isSubmitting,
          child: Column(
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Absensi Lembur',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (!_isSubmitting)
                      IconButton(
                        onPressed: () =>
                            Navigator.pop(context, false),
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child:
                              const Icon(Icons.close, size: 20),
                        ),
                      ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      20, 8, 20, bottomPadding + 20),
                  child: Column(
                    children: [
                      // INFO CARD + BANNER
                      _buildInfoCard(),
                      if (_canConfirm && !_showKonfirmasiForm)
                        _buildLateBanner(),

                      // KONFIRMASI FORM ATAU ABSENSI NORMAL
                      if (_showKonfirmasiForm)
                        _buildKonfirmasiForm()
                      else ...[
                        _buildStepIndicator(),
                        const SizedBox(height: 24),
                        _buildStatusCard(),
                        const SizedBox(height: 20),
                        if (_capturedImage != null)
                          _buildPhotoPreview(),
                        if (_capturedImage != null)
                          const SizedBox(height: 20),
                        if (_isLoadingLocation)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        if (!_isLoadingLocation)
                          _buildActionButtons(),
                      ],

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // INFO LEMBUR CARD
  // ===========================================================================

  Widget _buildInfoCard() {
    final l = widget.overtimeItem;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF1A237E).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline,
                size: 18, color: Color(0xFF1A237E)),
            const SizedBox(width: 8),
            Text('Detail Lembur Hari Ini',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: const Color(0xFF1A237E))),
          ]),
          const SizedBox(height: 10),
          _infoRow(
              Icons.calendar_today,
              DateFormat('EEEE, dd MMM yyyy', 'id_ID')
                  .format(l.tanggal)),
          _infoRow(
              Icons.access_time,
              '${l.jamMulai} - ${l.jamSelesai} (${l.totalJam.toStringAsFixed(1)} jam)'),
          _infoRow(
              Icons.location_on,
              l.lokasi['alamat'] ??
                  l.lokasi['nama_lokasi'] ??
                  'Kantor'),
        ],
      ),
    );
  }

  // ===========================================================================
  // LATE BANNER
  // ===========================================================================

  Widget _buildLateBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(children: [
            const Icon(Icons.warning_amber,
                color: Colors.orange, size: 24),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Anda belum melakukan absensi!',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.orange.shade800))),
          ]),
          const SizedBox(height: 4),
          Text('Sudah melewati batas waktu absensi normal.',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.orange.shade600)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  setState(() => _showKonfirmasiForm = true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Konfirmasi Keterlambatan',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KONFIRMASI FORM
  // ===========================================================================

  Widget _buildKonfirmasiForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Konfirmasi Keterlambatan',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Apakah Anda melakukan lembur?',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _optionCard(
                    '✅ Ya, saya lembur',
                    Icons.check_circle,
                    Colors.green,
                    _melakukanLembur == true,
                    () => setState(() => _melakukanLembur = true))),
            const SizedBox(width: 10),
            Expanded(
                child: _optionCard(
                    '❌ Tidak lembur',
                    Icons.cancel,
                    Colors.red,
                    _melakukanLembur == false,
                    () =>
                        setState(() => _melakukanLembur = false))),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _alasanController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tulis alasan keterlambatan...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          if (_melakukanLembur == true) ...[
            const SizedBox(height: 12),
            if (_buktiFotoTerlambat != null)
              ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_buktiFotoTerlambat!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickBuktiFoto,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: Text(_buktiFotoTerlambat != null
                  ? 'Ganti Foto'
                  : 'Ambil Foto Bukti'),
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10))),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isSubmitting ? null : _submitKonfirmasi,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12))),
              child: Text(
                  _isSubmitting ? 'Mengirim...' : 'Kirim Konfirmasi',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _showKonfirmasiForm = false;
                _melakukanLembur = null;
                _alasanController.clear();
                _buktiFotoTerlambat = null;
              }),
              child: const Text('← Kembali ke absensi normal'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionCard(String title, IconData icon, Color color,
      bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon,
              color: selected ? color : Colors.grey, size: 28),
          const SizedBox(height: 4),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? color
                      : Colors.grey.shade600)),
        ]),
      ),
    );
  }

  // ===========================================================================
  // STEP INDICATOR
  // ===========================================================================

  Widget _buildStepIndicator() {
    final step1Complete = _locationValid;
    final step2Complete = _capturedImage != null;
    final step3Active = _isSubmitting;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildStepItem(
              number: '1',
              label: 'Lokasi',
              isComplete: step1Complete,
              isActive: _isLoadingLocation,
            ),
          ),
          _buildStepDivider(step1Complete),
          Expanded(
            child: _buildStepItem(
              number: '2',
              label: 'Selfie',
              isComplete: step2Complete,
              isActive: _isTakingPhoto,
            ),
          ),
          _buildStepDivider(step2Complete),
          Expanded(
            child: _buildStepItem(
              number: '3',
              label: 'Submit',
              isComplete: false,
              isActive: step3Active,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String number,
    required String label,
    required bool isComplete,
    required bool isActive,
  }) {
    Color bgColor;
    Color textColor;

    if (isComplete) {
      bgColor = Colors.green;
      textColor = Colors.green;
    } else if (isActive) {
      bgColor = const Color(0xFF1976D2);
      textColor = const Color(0xFF1976D2);
    } else {
      bgColor = Colors.grey.shade300;
      textColor = Colors.grey.shade500;
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: bgColor,
          child: isComplete
              ? const Icon(Icons.check,
                  color: Colors.white, size: 18)
              : Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: textColor,
            fontWeight:
                isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isComplete) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: isComplete ? Colors.green : Colors.grey.shade300,
      ),
    );
  }

  // ===========================================================================
  // STATUS CARD
  // ===========================================================================

  Widget _buildStatusCard() {
    final isValid = _locationValid;
    final Color bgColor = isValid
        ? Colors.green.withValues(alpha: 0.08)
        : Colors.orange.withValues(alpha: 0.08);
    final Color borderColor = isValid
        ? Colors.green.withValues(alpha: 0.2)
        : Colors.orange.withValues(alpha: 0.2);
    final Color iconColor = isValid ? Colors.green : Colors.orange;
    final IconData statusIcon = isValid
        ? Icons.check_circle
        : _isLoadingLocation
            ? Icons.location_searching
            : Icons.location_off;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _isLoadingLocation
              ? const SizedBox(
                  width: 42,
                  height: 42,
                  child:
                      CircularProgressIndicator(strokeWidth: 3),
                )
              : Icon(statusIcon, size: 42, color: iconColor),
          const SizedBox(height: 14),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          if (_errorDetail != null &&
              _errorDetail!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _errorDetail!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_currentPosition != null)
            _infoRow(
              Icons.pin_drop,
              '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
            ),
          if (_distanceInMeters != null)
            _infoRow(
              Icons.straighten,
              'Jarak: ${_distanceInMeters!.toStringAsFixed(0)} meter dari lokasi',
            ),
          if (_maxRadius != null)
            _infoRow(
              Icons.circle_outlined,
              'Radius maksimal: ${_maxRadius!.toStringAsFixed(0)} meter',
            ),
          if (_currentAddress != null &&
              _currentAddress!.isNotEmpty)
            _infoRow(Icons.location_city, _currentAddress!),
        ],
      ),
    );
  }

  // ===========================================================================
  // PHOTO PREVIEW
  // ===========================================================================

  Widget _buildPhotoPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Image.file(
              _previewFile!,
              width: double.infinity,
              height: 260,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 260,
                color: Colors.grey.shade100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image,
                          size: 50, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'Gagal memuat foto',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _isSubmitting ? null : _takeSelfie,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ACTION BUTTONS
  // ===========================================================================

  Widget _buildActionButtons() {
    // Case 1: Lokasi belum valid
    if (!_locationValid) {
      return Column(
        children: [
          _buildButton(
            text: _hasAttemptedRetry
                ? 'Coba Verifikasi Lagi'
                : 'Verifikasi Lokasi',
            icon: Icons.refresh,
            color: Colors.orange,
            loading: _isLoadingLocation,
            onPressed: () {
              _hasAttemptedRetry = true;
              _startLocationVerification();
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoadingLocation
                ? null
                : () => Navigator.pop(context, false),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ),
        ],
      );
    }

    // Case 2: Belum ambil foto
    if (_capturedImage == null) {
      return _buildButton(
        text: '📸 Ambil Selfie',
        icon: Icons.camera_alt,
        color: const Color(0xFF1976D2),
        loading: _isTakingPhoto,
        onPressed: _takeSelfie,
      );
    }

    // Case 3: Siap submit
    return Column(
      children: [
        _buildButton(
          text: '✅ Submit Absensi',
          icon: Icons.check_circle,
          color: Colors.green,
          loading: _isSubmitting,
          onPressed: _submitAbsensi,
        ),
        if (!_isSubmitting) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  text: '📸 Ambil Ulang',
                  icon: Icons.refresh,
                  color: Colors.grey.shade700,
                  loading: _isTakingPhoto,
                  onPressed: _takeSelfie,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // BUTTON COMPONENT
  // ===========================================================================

  Widget _buildButton({
    required String text,
    required IconData icon,
    required Color color,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 20),
        label: Text(
          loading ? 'Memproses...' : text,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ===========================================================================
  // INFO ROW COMPONENT
  // ===========================================================================

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}