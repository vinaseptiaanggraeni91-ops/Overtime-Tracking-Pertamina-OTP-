// lib/widgets/absensi/absensi_detail_content.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

// ✅ IMPORT DARI ABSENSI SERVICE
import '/core/services/overtime_absensi_service.dart';
// ✅ IMPORT CLOUDINARY SERVICE
import '/core/services/cloudinary_storage_service.dart';
// ✅ IMPORT LIVE LOCATION SERVICE
import '/core/services/live_location_service.dart';
// ✅ IMPORT LOCATION VALIDATOR
import '/widgets/absensi/location_validator.dart';

class AbsensiDetailContent extends StatefulWidget {
  final OvertimeHistory overtime;

  const AbsensiDetailContent({
    super.key,
    required this.overtime,
  });

  @override
  State<AbsensiDetailContent> createState() => _AbsensiDetailContentState();
}

class _AbsensiDetailContentState extends State<AbsensiDetailContent> {
  final OvertimeAbsensiService _absensiService = OvertimeAbsensiService();
  final CloudinaryStorageService _cloudinaryService = CloudinaryStorageService();
  final LiveLocationService _locationService = LiveLocationService();
  final LocationValidator _locationValidator = LocationValidator();

  // 🔥 TENGGAT STATE
  TenggatInfo? _tenggatInfo;
  // FIX: Hapus field yang tidak digunakan
  // bool _isLoadingTenggat = true;
  Timer? _countdownTimer;

  // 🔥 VALIDASI LOKASI STATE
  bool _isValidatingLocation = false;
  Map<String, dynamic>? _locationValidation;
  bool _locationChecked = false;
  bool _isLocationValid = false;

  // 🔥 KONFIRMASI STATE
  // FIX: Hapus field yang tidak digunakan
  // bool _showKonfirmasiForm = false;
  bool _melakukanLembur = true;
  final TextEditingController _alasanController = TextEditingController();
  File? _buktiFoto;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isUploading = false;
  String? _uploadProgress;
  final _formKey = GlobalKey<FormState>();

  // 🔥 IMAGE PICKER
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadTenggatInfo();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _alasanController.dispose();
    super.dispose();
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  TENGGAT INFO LOADING                                                   ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Future<void> _loadTenggatInfo() async {
    try {
      final info = await _absensiService.getTenggatInfo(widget.overtime.id);
      if (mounted) {
        setState(() {
          _tenggatInfo = info;
        });
      }
    } catch (e) {
      debugPrint('Error loading tenggat info: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      final info = await _absensiService.getTenggatInfo(widget.overtime.id);
      if (mounted) {
        setState(() => _tenggatInfo = info);
      }
    });
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  VALIDASI LOKASI                                                        ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Future<bool> _validateLocationBeforeSubmit() async {
    setState(() {
      _isValidatingLocation = true;
      _errorMessage = null;
    });

    try {
      final result = await _locationValidator.validateCurrentLocation(
        overtimeItem: widget.overtime,
      );

      if (mounted) {
        setState(() {
          _locationValidation = result;
          _locationChecked = true;
          _isLocationValid = result['valid'] == true;
          _isValidatingLocation = false;
        });

        if (!_isLocationValid) {
          _errorMessage = result['message'] ?? 'Lokasi tidak valid';
        }
      }

      return _isLocationValid;
    } catch (e) {
      debugPrint('❌ Validasi lokasi error: $e');
      if (mounted) {
        setState(() {
          _isValidatingLocation = false;
          _errorMessage = 'Gagal memvalidasi lokasi: $e';
        });
      }
      return false;
    }
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  IMAGE PICKER                                                           ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _buktiFoto = File(pickedFile.path);
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal mengambil foto: $e');
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih Sumber Foto',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imageSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    color: const Color(0xFF1E3C72),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _imageSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeri',
                    color: const Color(0xFF2A4F8C),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥 START LIVE TRACKING                                                 ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  void _startLiveTracking() {
    try {
      final jamSelesai = _parseJamSelesai(widget.overtime);
      final now = DateTime.now();

      _locationService.startTracking(
        userId: widget.overtime.mitraId ?? '',
        userName: widget.overtime.namaMitra ?? 'Mitra',
        overtimeId: widget.overtime.id,
        lemburId: widget.overtime.id,
        userRole: 'mitra',
        userFungsi: _getFungsi(),
      );

      if (jamSelesai.isAfter(now)) {
        _locationService.scheduleAutoStop(jamSelesai);
        debugPrint('📍 Live tracking aktif, auto-stop: ${DateFormat('HH:mm').format(jamSelesai)}');
      }

      debugPrint('✅ Live tracking dimulai setelah absensi');
    } catch (e) {
      debugPrint('⚠️ Gagal start tracking: $e');
    }
  }

  DateTime _parseJamSelesai(OvertimeHistory overtime) {
    try {
      final parts = overtime.jamSelesai.split(':');
      final jam = int.tryParse(parts[0]) ?? 0;
      final menit = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return DateTime(
        overtime.tanggal.year,
        overtime.tanggal.month,
        overtime.tanggal.day,
        jam,
        menit,
      );
    } catch (e) {
      return overtime.tanggal;
    }
  }

  String? _getFungsi() {
    try {
      // FIX: Hapus type check yang tidak perlu
      final lokasi = widget.overtime.lokasi;
      return lokasi['fungsi']?.toString();
    } catch (e) {
      // ignore
    }
    return null;
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥 SUBMIT KONFIRMASI DENGAN UPLOAD CLOUDINARY                          ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Future<void> _submitKonfirmasi() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi foto jika menyatakan tetap lembur
    if (_melakukanLembur && _buktiFoto == null) {
      setState(() => _errorMessage = '❌ Foto bukti kerja wajib diupload');
      return;
    }

    // 🔥 Validasi lokasi
    await _validateLocationBeforeSubmit();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      String? fotoUrl;
      String? fotoPublicId;

      // 🔥 UPLOAD FOTO KE CLOUDINARY
      if (_buktiFoto != null) {
        final uploadResult = await _uploadFotoToCloudinary(_buktiFoto!);

        if (uploadResult == null || uploadResult['success'] != true) {
          if (mounted) {
            setState(() {
              _errorMessage = '❌ ${uploadResult?['message'] ?? 'Gagal upload foto, coba lagi'}';
              _isSubmitting = false;
            });
          }
          return;
        }

        fotoUrl = uploadResult['url'] as String?;
        fotoPublicId = uploadResult['publicId'] as String?;

        debugPrint('✅ Upload Cloudinary berhasil:');
        debugPrint('   URL: $fotoUrl');
        debugPrint('   Public ID: $fotoPublicId');
      }

      // 🔥 SIMPAN KE FIRESTORE VIA SERVICE
      if (mounted) {
        setState(() => _uploadProgress = 'Menyimpan data...');
      }

      final result = await _absensiService.konfirmasiKeterlambatan(
        lemburId: widget.overtime.id,
        userId: widget.overtime.mitraId ?? '',
        userName: widget.overtime.namaMitra ?? 'Mitra',
        melakukanLembur: _melakukanLembur,
        alasan: _alasanController.text,
        buktiFotoUrl: fotoUrl,
      );

      if (mounted) {
        if (result['success'] == true) {
          // 🔥 Start live tracking jika tetap lembur
          if (_melakukanLembur) {
            _startLiveTracking();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(result['message'] ?? '✅ Konfirmasi berhasil disimpan',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (_melakukanLembur)
                          const Text('📍 Live tracking aktif',
                              style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: _melakukanLembur ? Colors.green : Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context);
        } else {
          // 🔥 Rollback: hapus foto dari Cloudinary jika gagal simpan
          if (fotoPublicId != null) {
            await _cloudinaryService.deleteFoto(fotoPublicId);
            debugPrint('🗑️ Foto dihapus dari Cloudinary (rollback)');
          }

          if (mounted) {
            setState(() {
              _errorMessage = result['message'] ?? '❌ Gagal menyimpan konfirmasi';
              _isSubmitting = false;
              _uploadProgress = null;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Submit konfirmasi error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '❌ Gagal: ${e.toString()}';
          _isSubmitting = false;
          _uploadProgress = null;
        });
      }
    }
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥 UPLOAD FOTO KE CLOUDINARY                                           ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Future<Map<String, dynamic>?> _uploadFotoToCloudinary(File file) async {
    try {
      if (mounted) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 'Mengupload foto ke Cloudinary...';
        });
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uuid = const Uuid().v4().substring(0, 8);
      final fileName = 'bukti_${widget.overtime.mitraId ?? 'mitra'}_${widget.overtime.id}_$timestamp$uuid';

      debugPrint('📤 Uploading foto to Cloudinary...');
      debugPrint('   File: ${file.path}');
      debugPrint('   Size: ${await file.length()} bytes');
      debugPrint('   FileName: $fileName');
      debugPrint('   Lembur ID: ${widget.overtime.id}');

      final result = await _cloudinaryService.uploadFoto(
        photoFile: file,
        fileName: fileName,
        lemburId: widget.overtime.id,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = null;
        });
      }

      if (result['success'] == true) {
        debugPrint('✅ Cloudinary upload sukses!');
        debugPrint('   URL: ${result['url']}');
        debugPrint('   Size: ${result['size']} bytes');
        debugPrint('   Format: ${result['format']}');

        final optimizedUrl = _cloudinaryService.getOptimizedUrl(
          result['publicId'] as String,
        );
        debugPrint('   Optimized URL: $optimizedUrl');
      }

      return result;
    } catch (e) {
      debugPrint('❌ Cloudinary upload error: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = null;
        });
      }
      return {
        'success': false,
        'message': 'Gagal upload ke Cloudinary: $e',
      };
    }
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  BUILD                                                                  ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  @override
  Widget build(BuildContext context) {
    final absensiStatus = widget.overtime.absensiStatus;
    final sudahAbsen = absensiStatus == 'check_in' ||
        absensiStatus == 'check_out' ||
        absensiStatus == 'selesai' ||
        absensiStatus == 'sudah_absen' ||
        absensiStatus == 'selesai_terlambat' ||
        absensiStatus == 'tidak_lembur';
    final isExpired = widget.overtime.status == 'kadaluarsa' ||
        widget.overtime.absensiStatus == 'expired';

    // 🔥 Cek expired dari tenggat info juga
    final isTenggatExpired = _tenggatInfo?.isExpired ?? false;
    final benarExpired = isExpired || isTenggatExpired;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
          child: Column(
            children: [
              // ── Konten Scrollable ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // ── Handle Bar ──
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Header Status ──
                    _buildHeader(benarExpired, sudahAbsen),
                    const Divider(height: 32),

                    // 🔥 TENGGAT ALERT (Jika telat & belum absen & belum expired)
                    if (!sudahAbsen && !benarExpired && _tenggatInfo != null)
                      _buildTenggatAlert(),

                    // 🔥 EXPIRED INFO (Jika sudah kadaluarsa)
                    if (benarExpired && !sudahAbsen)
                      _buildExpiredInfo(),

                    // 🔥 STATUS VALIDASI LOKASI
                    if (!sudahAbsen && _locationChecked)
                      _buildLocationValidationStatus(),

                    // ── Info Lembur ──
                    _buildInfoSection(),
                    const SizedBox(height: 16),

                    // ── Info Absensi (jika sudah absen) ──
                    if (sudahAbsen) _buildAbsensiInfo(),

                    // ── Info Belum Absen (HANYA jika belum expired & belum telat)
                    if (!sudahAbsen && !benarExpired && _tenggatInfo != null && !_tenggatInfo!.canConfirm)
                      _buildBelumAbsenInfo(),

                    // 🔥 KONFIRMASI KETERLAMBATAN SECTION
                    if (_tenggatInfo != null &&
                        _tenggatInfo!.canConfirm &&
                        !sudahAbsen &&
                        !benarExpired)
                      _buildKonfirmasiSection(),

                    const SizedBox(height: 20),

                    // ── Foto Bukti Absensi ──
                    if (widget.overtime.absensiFotoUrl != null &&
                        widget.overtime.absensiFotoUrl!.isNotEmpty)
                      _buildFotoBukti(context),

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // 🔥 BOTTOM NAVIGATION BAR
              _buildBottomNavBar(sudahAbsen, benarExpired),
            ],
          ),
        );
      },
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥 STATUS VALIDASI LOKASI                                              ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildLocationValidationStatus() {
    if (_isValidatingLocation) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Memvalidasi lokasi Anda...',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      );
    }

    if (_locationValidation != null) {
      final isValid = _locationValidation!['valid'] == true;
      final distance = _locationValidation!['distance_text'] ?? '-';
      final maxRadius = _locationValidation!['max_radius_text'] ?? '-';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isValid ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isValid ? Colors.green.shade200 : Colors.red.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isValid ? Icons.location_on_rounded : Icons.location_off_rounded,
              color: isValid ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isValid ? '✅ Lokasi Valid' : '❌ Lokasi Tidak Valid',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isValid ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                  Text(
                    isValid
                        ? 'Jarak: $distance (max: $maxRadius)'
                        : _locationValidation!['message'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (!isValid)
              TextButton(
                onPressed: () {
                  setState(() {
                    _locationChecked = false;
                    _locationValidation = null;
                  });
                },
                child: Text(
                  'Coba Lagi',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  HEADER                                                                 ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildHeader(bool isExpired, bool sudahAbsen) {
    Color headerColor;
    IconData headerIcon;
    String headerTitle;

    if (isExpired) {
      headerColor = const Color(0xFFEF5350);
      headerIcon = Icons.timer_off_rounded;
      headerTitle = '⏰ Lembur Kadaluarsa';
    } else if (_tenggatInfo != null && _tenggatInfo!.canConfirm) {
      // FIX: Ganti warnaIndikator dengan warna yang sesuai dari TenggatInfo
      headerColor = _getTenggatColor();
      headerIcon = Icons.warning_amber_rounded;
      headerTitle = 'Konfirmasi Keterlambatan';
    } else if (sudahAbsen) {
      headerColor = Colors.green;
      headerIcon = Icons.check_circle_rounded;
      headerTitle = 'Absensi Tercatat';
    } else if (_tenggatInfo != null && _tenggatInfo!.isNormal) {
      headerColor = const Color(0xFF66BB6A);
      headerIcon = Icons.timer_rounded;
      headerTitle = 'Menunggu Absensi';
    } else {
      headerColor = Colors.orange;
      headerIcon = Icons.pending_actions_rounded;
      headerTitle = 'Belum Absensi';
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: headerColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(headerIcon, color: headerColor, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headerTitle,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: headerColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.overtime.namaMitra ?? 'Mitra',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.overtime.statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.overtime.statusColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            widget.overtime.statusLabel,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.overtime.statusColor,
            ),
          ),
        ),
      ],
    );
  }

  // FIX: Helper method untuk mendapatkan warna tenggat
  Color _getTenggatColor() {
    if (_tenggatInfo == null) return Colors.orange;
    
    // Gunakan properti yang ada di TenggatInfo
    if (_tenggatInfo!.isExpired) return const Color(0xFFEF5350);
    if (_tenggatInfo!.canConfirm) return Colors.orange;
    if (_tenggatInfo!.isNormal) return const Color(0xFF66BB6A);
    return Colors.orange;
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥🔥🔥 EXPIRED INFO - DITAMPILKAN SAAT KEDALUARSA 🔥🔥🔥               ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildExpiredInfo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEF5350).withValues(alpha: 0.08),
            const Color(0xFFEF5350).withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEF5350).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Icon besar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_off_rounded,
              color: Color(0xFFEF5350),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            '⏰ Lembur Telah Kadaluarsa',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD32F2F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            'Batas waktu absensi sudah terlewat (lebih dari 1x24 jam setelah jam selesai lembur). '
                'Lembur ini tidak dapat diabseni atau dikonfirmasi lagi.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Info detail
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _expiredDetailRow(
                  Icons.calendar_today_rounded,
                  'Tanggal Lembur',
                  DateFormat('dd MMM yyyy', 'id_ID').format(widget.overtime.tanggal),
                ),
                const SizedBox(height: 8),
                _expiredDetailRow(
                  Icons.access_time_rounded,
                  'Jam Lembur',
                  '${widget.overtime.jamMulai} - ${widget.overtime.jamSelesai}',
                ),
                if (_tenggatInfo != null) ...[
                  const SizedBox(height: 8),
                  _expiredDetailRow(
                    Icons.event_busy_rounded,
                    'Batas Expired',
                    // FIX: Ganti dengan properti yang ada
                    _getBatasExpiredFormatted(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Info tambahan
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFEF5350), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lembur ini sudah tidak dapat diproses lebih lanjut.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFFD32F2F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // FIX: Helper untuk format batas expired
  String _getBatasExpiredFormatted() {
    if (_tenggatInfo == null) return '-';
    // Sesuaikan dengan properti yang ada di TenggatInfo
    // Misalnya jika ada batasExpired, format dengan DateFormat
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(_tenggatInfo!.batasExpired);
    } catch (e) {
      return _tenggatInfo!.batasExpired.toString();
    }
  }

  Widget _expiredDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥 TENGGAT ALERT                                                       ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildTenggatAlert() {
    if (_tenggatInfo == null) return const SizedBox.shrink();

    final tenggatColor = _getTenggatColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tenggatColor.withValues(alpha: 0.1),
            tenggatColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tenggatColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // FIX: Gunakan icon yang sesuai
              Icon(
                _tenggatInfo!.isLate ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                color: tenggatColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _tenggatInfo!.isLate ? '⚠️ Terlambat Absensi' : '⏰ Info Tenggat',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tenggatColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _tenggatInfo!.progressPercent,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                tenggatColor,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          _alertInfoRow('Sisa Waktu', _tenggatInfo!.sisaWaktuFormatted),
          const SizedBox(height: 6),
          // FIX: Ganti dengan properti yang ada
          _alertInfoRow('Batas Normal', _getBatasNormalFormatted()),
          const SizedBox(height: 6),
          _alertInfoRow('Batas Expired', _getBatasExpiredFormatted()),
          const SizedBox(height: 6),
          _alertInfoRow('Level', _getLevelPrioritas()),
          const SizedBox(height: 6),
          _alertInfoRow('Aksi', _getAksiLabel()),
          if (_tenggatInfo!.canConfirm) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tenggatColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_rounded,
                      size: 18, color: tenggatColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Anda terlambat absen normal. Silakan konfirmasi apakah tetap melakukan lembur atau tidak.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: tenggatColor,
                        fontWeight: FontWeight.w500,
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

  // FIX: Helper methods untuk properti yang tidak ada
  String _getBatasNormalFormatted() {
    if (_tenggatInfo == null) return '-';
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(_tenggatInfo!.batasNormal);
    } catch (e) {
      return _tenggatInfo!.batasNormal.toString();
    }
  }

  String _getLevelPrioritas() {
    if (_tenggatInfo == null) return '-';
    if (_tenggatInfo!.isExpired) return 'Kritis';
    if (_tenggatInfo!.canConfirm) return 'Tinggi';
    if (_tenggatInfo!.isLate) return 'Sedang';
    return 'Normal';
  }

  String _getAksiLabel() {
    if (_tenggatInfo == null) return '-';
    if (_tenggatInfo!.isExpired) return 'Expired';
    if (_tenggatInfo!.canConfirm) return 'Konfirmasi';
    return 'Absensi Normal';
  }

  Widget _alertInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥 KONFIRMASI KETERLAMBATAN SECTION                                    ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildKonfirmasiSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8F0), Color(0xFFFFF0E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konfirmasi Keterlambatan',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      Text(
                        'Wajib diisi karena melewati batas absensi normal',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🔥 VALIDASI LOKASI
            if (!_locationChecked)
              _buildValidateLocationButton(),
            if (_locationChecked)
              _buildLocationValidationStatus(),
            const SizedBox(height: 16),

            // 🔥 PILIHAN: Melakukan Lembur atau Tidak
            Text(
              'Apakah Anda tetap melakukan lembur?',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _radioOption(
                    value: true,
                    label: '✅ Ya, Saya Lembur',
                    description: 'Upload bukti foto kerja',
                    icon: Icons.work_rounded,
                    isSelected: _melakukanLembur,
                    onTap: () => setState(() {
                      _melakukanLembur = true;
                      _errorMessage = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _radioOption(
                    value: false,
                    label: '❌ Tidak Lembur',
                    description: 'Hanya alasan',
                    icon: Icons.cancel_rounded,
                    isSelected: !_melakukanLembur,
                    onTap: () => setState(() {
                      _melakukanLembur = false;
                      _buktiFoto = null;
                      _errorMessage = null;
                    }),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🔥 ALASAN INPUT
            Text(
              'Alasan Keterlambatan Absensi',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _alasanController,
              maxLines: 4,
              maxLength: 500,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Alasan wajib diisi';
                }
                if (value.trim().length < 10) {
                  return 'Alasan minimal 10 karakter';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: _melakukanLembur
                    ? 'Jelaskan mengapa Anda terlambat absen, namun tetap melakukan lembur...'
                    : 'Jelaskan mengapa Anda tidak jadi melakukan lembur...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Colors.orange, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                counterStyle: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 13),
            ),

            const SizedBox(height: 16),

            // 🔥 UPLOAD BUKTI FOTO (Jika tetap lembur)
            if (_melakukanLembur) ...[
              Text(
                'Foto Bukti Kerja *',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isSubmitting ? null : _showImageSourceDialog,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _buktiFoto != null
                          ? Colors.green.shade300
                          : Colors.orange.shade200,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: _buktiFoto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                _buktiFoto!,
                                fit: BoxFit.cover,
                              ),
                              if (!_isSubmitting)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _buktiFoto = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '✅ Foto Terpilih',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_rounded,
                              size: 48,
                              color: Colors.orange.shade300,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ketuk untuk upload foto bukti kerja',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Wajib diisi',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.red.shade400,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 🔥 UPLOAD PROGRESS
            if (_isUploading && _uploadProgress != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _uploadProgress!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 🔥 ERROR MESSAGE
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _errorMessage!.startsWith('⏳') || _errorMessage!.startsWith('Mengupload')
                      ? Colors.blue.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _errorMessage!.startsWith('⏳') || _errorMessage!.startsWith('Mengupload')
                        ? Colors.blue.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _errorMessage!.startsWith('⏳') || _errorMessage!.startsWith('Mengupload')
                          ? Icons.cloud_upload_rounded
                          : Icons.error_rounded,
                      color: _errorMessage!.startsWith('⏳') || _errorMessage!.startsWith('Mengupload')
                          ? Colors.blue
                          : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _errorMessage!.startsWith('⏳') || _errorMessage!.startsWith('Mengupload')
                              ? Colors.blue.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 🔥 SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitKonfirmasi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: _isSubmitting ? 0 : 2,
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Mengirim...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Kirim Konfirmasi',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidateLocationButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _validateLocationBeforeSubmit(),
        icon: Icon(
          _isValidatingLocation
              ? Icons.hourglass_top_rounded
              : Icons.my_location_rounded,
          size: 18,
        ),
        label: Text(
          _isValidatingLocation ? 'Memvalidasi...' : 'Validasi Lokasi Saya',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1976D2),
          side: const BorderSide(color: Color(0xFF1976D2)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  RADIO OPTION (YA/TIDAK)                                                ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _radioOption({
    required bool value,
    required String label,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? value
                    ? Colors.green
                    : Colors.red
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (value ? Colors.green : Colors.red)
                        .withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? (value ? Colors.green : Colors.red)
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? (value ? Colors.green.shade700 : Colors.red.shade700)
                    : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  INFO LEMBUR                                                            ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _detailRow(
            '📅 Tanggal',
            DateFormat('EEEE, dd MMM yyyy', 'id_ID')
                .format(widget.overtime.tanggal),
          ),
          const SizedBox(height: 10),
          _detailRow(
            '🕐 Jam',
            '${widget.overtime.jamMulai} - ${widget.overtime.jamSelesai}',
          ),
          const SizedBox(height: 10),
          _detailRow(
            '⏱️ Durasi',
            '${widget.overtime.totalJam.toStringAsFixed(1)} jam',
          ),
          const SizedBox(height: 10),
          _detailRow(
            '📋 Jenis',
            widget.overtime.jenisLembur == 'hari_libur'
                ? 'Hari Libur'
                : 'Hari Kerja',
          ),
          const SizedBox(height: 10),
          _detailRow(
            '📍 Lokasi',
            _lokasiText(widget.overtime.lokasi),
          ),
          const SizedBox(height: 10),
          _detailRow(
            '📊 Status Absensi',
            widget.overtime.absensiStatusLabel,
          ),
        ],
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  INFO ABSENSI (JIKA SUDAH)                                              ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildAbsensiInfo() {
    final absensiStatus = widget.overtime.absensiStatus;
    final isTerlambat = absensiStatus == 'selesai_terlambat';
    final isTidakLembur = absensiStatus == 'tidak_lembur';

    Color infoColor;
    IconData infoIcon;
    String infoTitle;

    if (isTerlambat) {
      infoColor = Colors.orange;
      infoIcon = Icons.warning_amber_rounded;
      infoTitle = 'Absen Terlambat (Dikonfirmasi)';
    } else if (isTidakLembur) {
      infoColor = Colors.red;
      infoIcon = Icons.cancel_rounded;
      infoTitle = 'Tidak Melakukan Lembur';
    } else {
      infoColor = Colors.green;
      infoIcon = Icons.check_circle_rounded;
      infoTitle = 'Detail Absensi';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: infoColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: infoColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(infoIcon, color: infoColor, size: 20),
              const SizedBox(width: 8),
              Text(
                infoTitle,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: infoColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.overtime.absensiWaktu != null) ...[
            _detailRow(
              'Waktu Absen',
              DateFormat('dd MMM yyyy, HH:mm:ss')
                  .format(widget.overtime.absensiWaktu!),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.overtime.absensiNama != null &&
              widget.overtime.absensiNama!.isNotEmpty)
            _detailRow(
              'Diinput oleh',
              widget.overtime.absensiNama!,
            ),
          // 🔥 LIVE TRACKING STATUS
          _buildLiveTrackingStatus(),
        ],
      ),
    );
  }

  // 🔥 LIVE TRACKING STATUS INDICATOR
  Widget _buildLiveTrackingStatus() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFC8E6C9)),
        ),
        child: Row(
          children: [
            _buildPulsingDot(),
            const SizedBox(width: 8),
            Text(
              '📍 Live tracking aktif',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Container(
          width: 10 * value,
          height: 10 * value,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥 INFO BELUM ABSEN - HANYA TAMPIL SAAT NORMAL (TIDAK EXPIRED)        ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildBelumAbsenInfo() {
    // 🔥 Jangan tampilkan jika sudah telat (ada form konfirmasi)
    if (_tenggatInfo != null && _tenggatInfo!.canConfirm) {
      return const SizedBox.shrink();
    }

    // 🔥🔥🔥 JANGAN TAMPILKAN JIKA EXPIRED!
    if (_tenggatInfo != null && _tenggatInfo!.isExpired) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF66BB6A).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF66BB6A).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF66BB6A), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Silakan Absensi',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tenggatInfo != null
                      ? 'Batas absensi normal sampai ${_getBatasNormalFormatted()} WIB'
                      : 'Gunakan tombol kamera 📸 untuk mengambil foto bukti kehadiran.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF66BB6A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  FOTO BUKTI                                                             ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildFotoBukti(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📸 Foto Bukti Absensi',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _lihatFoto(context, widget.overtime.absensiFotoUrl!),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              image: DecorationImage(
                image: NetworkImage(widget.overtime.absensiFotoUrl!),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.zoom_in,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 12,
                  child: Text(
                    'Ketuk untuk memperbesar',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  DETAIL ROW                                                             ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  HELPER: LOKASI TEXT                                                    ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  String _lokasiText(Map<String, dynamic> lokasi) {
    if (lokasi.isEmpty) return 'Tidak diketahui';

    final pilihan = lokasi['pilihan'] ?? 'kantor';

    switch (pilihan) {
      case 'kantor':
        return 'Kantor PGE';
      case 'proyek':
        return lokasi['proyek'] ?? 'Lokasi Proyek';
      case 'lainnya':
        return lokasi['alamat'] ?? 'Lokasi Lain';
      default:
        return pilihan.toString();
    }
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  LIHAT FOTO FULLSCREEN                                                  ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  void _lihatFoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      color: Colors.black12,
                      child: const Center(
                        child:
                            CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey.shade200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Gagal memuat foto',
                            style: GoogleFonts.poppins(
                                color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Pinch to zoom',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥 BOTTOM NAVIGATION BAR                                               ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Widget _buildBottomNavBar(bool sudahAbsen, bool isExpired) {
    // 🔥 EXPIRED: Tombol tutup
    if (isExpired) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 20),
            label: Text('Tutup',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.grey.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      );
    }

    // 🔥 SUDAH ABSEN: Live tracking + Selesai
    if (sudahAbsen) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.green.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _buildPulsingDot(),
                  const SizedBox(width: 6),
                  Text(
                    '📍 Live tracking aktif',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text('Selesai',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 🔥 TERLAMBAT: Konfirmasi
    if (_tenggatInfo != null && _tenggatInfo!.canConfirm) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.orange.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '⚠️ Anda terlambat! Segera konfirmasi.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _submitKonfirmasi(),
                icon: const Icon(Icons.warning_rounded, size: 20),
                label: Text('Konfirmasi Keterlambatan',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 🔥 NORMAL: Ambil Foto + Kirim Absensi
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.green.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.timer_rounded,
                    color: Color(0xFF66BB6A), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _tenggatInfo != null
                        ? '🟢 Sisa waktu: ${_tenggatInfo!.sisaWaktuFormatted}'
                        : 'Silakan lakukan absensi normal',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _showImageSourceDialog(),
                    icon: const Icon(Icons.camera_alt_rounded, size: 20),
                    label: Text(
                      _buktiFoto != null ? 'Ganti Foto' : 'Ambil Foto',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3C72),
                      side: const BorderSide(color: Color(0xFF1E3C72)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isSubmitting ? null : _submitAbsensiNormal,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      _isSubmitting ? 'Mengirim...' : 'Kirim Absensi',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3C72),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  🔥 SUBMIT ABSENSI NORMAL (VALIDASI → FOTO → SUBMIT → TRACKING)        ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  Future<void> _submitAbsensiNormal() async {
    // 🔥 STEP 1: Validasi lokasi
    final isLocationValid = await _validateLocationBeforeSubmit();
    if (!isLocationValid) return;

    // 🔥 STEP 2: Ambil foto
    if (_buktiFoto == null) {
      setState(() => _errorMessage = '❌ Foto bukti wajib diambil');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // 🔥 STEP 3: Upload foto ke Cloudinary
      if (mounted) setState(() => _uploadProgress = 'Mengupload foto...');
      final uploadResult = await _uploadFotoToCloudinary(_buktiFoto!);

      if (uploadResult == null || uploadResult['success'] != true) {
        if (mounted) {
          setState(() {
            _errorMessage =
                '❌ ${uploadResult?['message'] ?? 'Gagal upload foto'}';
            _isSubmitting = false;
          });
        }
        return;
      }

      final fotoUrl = uploadResult['url'] as String?;

      // 🔥 STEP 4: Submit absensi
      if (mounted) setState(() => _uploadProgress = 'Menyimpan absensi...');

      final result = await _absensiService.submitAbsensi(
        docId: widget.overtime.id,
        fotoUrl: fotoUrl ?? '',
        userId: widget.overtime.mitraId ?? '',
        userName: widget.overtime.namaMitra ?? 'Mitra',
      );

      if (mounted) {
        if (result['success'] == true) {
          // 🔥 STEP 5: Start live tracking
          _startLiveTracking();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            result['message'] ?? '✅ Absensi berhasil',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        const Text('📍 Live tracking aktif',
                            style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context);
        } else {
          setState(() {
            _errorMessage =
                result['message'] ?? '❌ Gagal menyimpan absensi';
            _isSubmitting = false;
            _uploadProgress = null;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Submit absensi error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '❌ Gagal: ${e.toString()}';
          _isSubmitting = false;
          _uploadProgress = null;
        });
      }
    }
  }
}