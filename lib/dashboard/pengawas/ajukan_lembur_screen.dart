// lib/features/pengawas/lembur/ajukan_lembur_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '/core/services/overtime_service.dart';
import '/core/services/notification_service.dart';
import '/core/services/location_service.dart';
import '/core/services/mitra_limit_service.dart';
import '/widgets/rate_info_card.dart';
import '/widgets/ajukan_lembur/header_profile_card.dart';
import '/widgets/ajukan_lembur/progress_stepper.dart';
import '/widgets/ajukan_lembur/mitra_section.dart';
import '/widgets/ajukan_lembur/waktu_section.dart';
import '/widgets/ajukan_lembur/lokasi_section.dart';
import '/widgets/ajukan_lembur/alasan_section.dart';
import '/widgets/ajukan_lembur/urgensi_section.dart';
import '/widgets/ajukan_lembur/budget_breakdown_section.dart';
import '/widgets/ajukan_lembur/submit_button.dart';
import '/widgets/ajukan_lembur/map_picker_page.dart';
import '/widgets/ajukan_lembur/mitra_selection_dialog.dart';
import '/widgets/ajukan_lembur/preview_dialog.dart';
import '/widgets/bottom_nav/pengawas_bottom_nav.dart';

class AjukanLemburPage extends StatefulWidget {
  const AjukanLemburPage({super.key});

  @override
  State<AjukanLemburPage> createState() => _AjukanLemburPageState();
}

class _AjukanLemburPageState extends State<AjukanLemburPage>
    with SingleTickerProviderStateMixin {
  // ==================== SERVICES ====================
  final OvertimeService _overtimeService = OvertimeService();
  final MitraLimitService _mitraLimitService = MitraLimitService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== ANIMATION ====================
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ==================== DATA STATE ====================
  bool isLoading = true;
  bool isCheckingDuplicates = false;
  Map<String, dynamic>? _overtimeRates;
  List<Map<String, dynamic>> selectedMiras = [];
  List<String> selectedMitraIds = [];
  Map<String, bool> mitraDuplicateStatus = {};
  Map<String, String> mitraDuplicateIds = {};

  // ==================== FORM DATA (🔥 UPGRADED!) ====================
  DateTime? tanggalMulai;       // 🔥 GANTI dari tanggalLembur
  DateTime? tanggalSelesai;     // 🔥 BARU: rentang akhir
  TimeOfDay? jamMulai;
  TimeOfDay? jamSelesai;
  double totalJam = 0.0;
  bool isMultiDay = false;      // 🔥 BARU: flag multi-hari
  bool isOvernight = false;     // 🔥 BARU: flag lintas malam
  String urgensi = 'normal';
  String? fungsiPengawas;
  String? namaPengawas;
  String? photoProfileUrl;

  // ==================== BUDGET DATA ====================
  double biayaLemburPerMitra = 0.0;
  double totalBiayaLembur = 0.0;
  bool showBudgetBreakdown = false;

  // ==================== LOCATION DATA ====================
  String _locationType = 'kantor';
  LatLng? _selectedLocation;
  String? _selectedAddress;
  final _rtController = TextEditingController();
  final _rwController = TextEditingController();

  // ==================== CONTROLLERS ====================
  final alasanController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // ==================== COMPUTED PROPERTIES ====================
  bool get _isOutsideRadius {
    if (_selectedLocation == null) return false;
    return LocationService.isOutsideRadius(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );
  }

  bool get _hasDuplicateMitra =>
      mitraDuplicateStatus.values.any((isDuplicate) => isDuplicate);

  List<Map<String, dynamic>> get _validMiras =>
      selectedMiras.where((m) => mitraDuplicateStatus[m['id']] != true).toList();

  List<Map<String, dynamic>> get _duplicateMiras =>
      selectedMiras.where((m) => mitraDuplicateStatus[m['id']] == true).toList();

  bool _allDataComplete() {
    return selectedMiras.isNotEmpty &&
        _validMiras.isNotEmpty &&
        tanggalMulai != null &&          // 🔥
        tanggalSelesai != null &&        // 🔥
        jamMulai != null &&
        jamSelesai != null &&
        _selectedLocation != null &&
        alasanController.text.isNotEmpty &&
        alasanController.text.length >= 20 &&
        urgensi.isNotEmpty &&
        !_hasDuplicateMitra;
  }

  double get _completionPercentage {
    int completed = 0;
    const total = 8;  // 🔥 Tambah 1 (tanggalSelesai)
    if (selectedMiras.isNotEmpty && _validMiras.isNotEmpty) completed++;
    if (tanggalMulai != null) completed++;      // 🔥
    if (tanggalSelesai != null) completed++;    // 🔥 BARU
    if (jamMulai != null && jamSelesai != null) completed++;
    if (_selectedLocation != null) completed++;
    if (alasanController.text.length >= 20) completed++;
    if (urgensi.isNotEmpty) completed++;
    return completed / total;
  }

  // ==================== HELPER FUNCTIONS ====================

  /// Generate list semua tanggal dalam rentang
  List<DateTime> _getDatesInRange(DateTime start, DateTime end) {
    final dates = <DateTime>[];
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    for (var d = startDay; !d.isAfter(endDay); d = d.add(const Duration(days: 1))) {
      dates.add(d);
    }
    return dates;
  }

  /// Cek apakah tanggal weekend
  bool _isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    alasanController.dispose();
    _rtController.dispose();
    _rwController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([_loadUserData(), _loadOvertimeRates()]);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists && mounted) {
      final data = userDoc.data();
      setState(() {
        fungsiPengawas = data?['fungsi']?.toString().toLowerCase() ?? '';
        namaPengawas = data?['nama_lengkap'] ?? 'Pengawas';
        photoProfileUrl = data?['photo_url'];
      });
    }
  }

  Future<void> _loadOvertimeRates() async {
    _overtimeRates = await _overtimeService.loadOvertimeRates();
    if (mounted) setState(() {});
  }

  // ==================== DUPLICATE CHECK (🔥 UPGRADED: MULTI-HARI) ====================
  // ==================== DUPLICATE CHECK (🔥 UPGRADED: PAKAI RENTANG) ====================
Future<void> _checkDuplicateLembur() async {
  if (tanggalMulai == null || tanggalSelesai == null || selectedMiras.isEmpty) return;
  setState(() => isCheckingDuplicates = true);

  // 🔥 GUNAKAN METHOD RENTANG — LEBIH EFISIEN!
  for (final mitra in selectedMiras) {
    final result = await _mitraLimitService.checkDuplicateLemburRentang(
      mitraId: mitra['id'],
      tanggalMulai: tanggalMulai!,
      tanggalSelesai: tanggalSelesai!,
    );

    if (mounted) {
      setState(() {
        mitraDuplicateStatus[mitra['id']] = result['is_duplicate'] ?? false;
        if (result['is_duplicate'] == true && result['existing_ids'] != null) {
          final ids = result['existing_ids'] as List;
          mitraDuplicateIds[mitra['id']] = ids.isNotEmpty ? ids.first.toString() : '';
        }
      });
    }
  }
  if (mounted) setState(() => isCheckingDuplicates = false);
}

  // ==================== CALCULATION (🔥 UPGRADED: MULTI-HARI + OVERNIGHT) ====================
  void _recalculateBiaya() {
    if (jamMulai == null || jamSelesai == null || 
        tanggalMulai == null || tanggalSelesai == null ||
        _overtimeRates == null) return;

    // 🔥 Build DateTime penuh (dukung overnight)
    final startDateTime = DateTime(
      tanggalMulai!.year, tanggalMulai!.month, tanggalMulai!.day,
      jamMulai!.hour, jamMulai!.minute,
    );
    final endDateTime = DateTime(
      tanggalSelesai!.year, tanggalSelesai!.month, tanggalSelesai!.day,
      jamSelesai!.hour, jamSelesai!.minute,
    );

    final diffInMinutes = endDateTime.difference(startDateTime).inMinutes;

    if (diffInMinutes <= 0) {
      if (mounted) {
        setState(() {
          totalJam = 0;
          showBudgetBreakdown = false;
        });
      }
      return;
    }

    totalJam = diffInMinutes / 60.0;

    // 🔥 Deteksi multi-day & overnight
    isMultiDay = tanggalMulai!.year != tanggalSelesai!.year ||
                 tanggalMulai!.month != tanggalSelesai!.month ||
                 tanggalMulai!.day != tanggalSelesai!.day;
    isOvernight = !isMultiDay && (jamSelesai!.hour < jamMulai!.hour ||
                   (jamSelesai!.hour == jamMulai!.hour && jamSelesai!.minute <= jamMulai!.minute));

    // 🔥 Kalkulasi biaya multi-hari (dipecah per hari)
    biayaLemburPerMitra = _calculateMultiDayCost(
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      rates: _overtimeRates!,
    );

    totalBiayaLembur = biayaLemburPerMitra * _validMiras.length;

    setState(() => showBudgetBreakdown = true);
    _checkDuplicateLembur();
  }

  /// 🔥 Kalkulasi biaya dengan memecah durasi per hari kalender
  double _calculateMultiDayCost({
    required DateTime startDateTime,
    required DateTime endDateTime,
    required Map<String, dynamic> rates,
  }) {
    double totalCost = 0;
    DateTime currentDay = DateTime(
      startDateTime.year, startDateTime.month, startDateTime.day,
    );

    while (!currentDay.isAfter(DateTime(endDateTime.year, endDateTime.month, endDateTime.day))) {
      final dayStart = DateTime(currentDay.year, currentDay.month, currentDay.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final effectiveStart = startDateTime.isAfter(dayStart) ? startDateTime : dayStart;
      final effectiveEnd = endDateTime.isBefore(dayEnd) ? endDateTime : dayEnd;

      if (effectiveStart.isBefore(effectiveEnd)) {
        final hoursToday = effectiveEnd.difference(effectiveStart).inMinutes / 60.0;
        final isHoliday = _isWeekend(currentDay);

        totalCost += _overtimeService.calculateOvertimeCost(
          totalHours: hoursToday,
          isHoliday: isHoliday,
          rates: rates,
        );
      }

      currentDay = currentDay.add(const Duration(days: 1));
    }

    return totalCost;
  }

  // ==================== FORMAT HELPERS ====================
  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _formatTanggal(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ==================== MAP PICKER ====================
  void _showMapPicker() async {
    final initialLat = _selectedLocation?.latitude ?? LocationService.kantorLat;
    final initialLng = _selectedLocation?.longitude ?? LocationService.kantorLng;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          initialLat: initialLat,
          initialLng: initialLng,
          isProjectLocation: _locationType == 'proyek',
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedLocation = LatLng(
          (result['lat'] as num).toDouble(),
          (result['lng'] as num).toDouble(),
        );
        _selectedAddress = result['address'] ?? 'Lokasi dipilih dari peta';
      });
    }
  }

  // ==================== MITRA SELECTION ====================
  Future<void> _showMitraSelectionDialog() async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => MitraSelectionDialog(
        fungsi: fungsiPengawas!,
        selectedIds: selectedMitraIds,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        selectedMiras = result;
        selectedMitraIds = result.map((m) => m['id'] as String).toList();
      });
      if (tanggalMulai != null && tanggalSelesai != null) _checkDuplicateLembur();
      _recalculateBiaya();
    }
  }

  // ==================== VALIDASI TERPUSAT (🔥 UPGRADED) ====================
  String? _validateAllData() {
    if (selectedMiras.isEmpty) {
      return 'Pilih minimal satu TAD';
    }
    if (_validMiras.isEmpty) {
      return 'Hapus TAD yang sudah terdaftar lembur di rentang tanggal ini';
    }

    if (tanggalMulai == null) {
      return 'Tanggal mulai lembur harus diisi';
    }
    if (tanggalSelesai == null) {
      return 'Tanggal selesai lembur harus diisi';
    }
    if (tanggalSelesai!.isBefore(tanggalMulai!)) {
      return 'Tanggal selesai harus ≥ tanggal mulai';
    }
    if (jamMulai == null || jamSelesai == null) {
      return 'Waktu lembur tidak valid';
    }
    if (totalJam <= 0) {
      return 'Durasi lembur harus > 0';
    }

    if (_locationType == 'proyek' && _selectedLocation == null) {
      return 'Lokasi proyek tidak ditemukan. Silakan pilih lokasi';
    }
    if (_selectedLocation == null) {
      return 'Pilih lokasi lembur';
    }

    if (alasanController.text.isEmpty) {
      return 'Alasan lembur harus diisi';
    }
    if (alasanController.text.length < 20) {
      return 'Alasan lembur minimal 20 karakter';
    }

    if (urgensi.isEmpty) {
      return 'Tingkat urgensi harus dipilih';
    }

    return null;
  }

  // ==================== SUBMIT ====================
  Future<void> _submit() async {
    final validationError = _validateAllData();

    if (validationError != null) {
      if (mounted) {
        _showValidationError(validationError);
      }
      return;
    }

    final groupId = DateTime.now().millisecondsSinceEpoch.toString();

    bool hasLimitExceeded = false;
    final limitResults = <String, dynamic>{};

    for (final mitra in _validMiras) {
      final result = await _mitraLimitService.checkMitraLimit(
        mitraId: mitra['id'],
        tanggal: tanggalMulai!,
        tambahanJam: totalJam,
      );
      limitResults[mitra['id']] = result;
      if (result['is_exceeded']) hasLimitExceeded = true;
    }

    if (hasLimitExceeded) {
      final confirmed = await _showLimitWarningDialog(limitResults);
      if (!confirmed) {
        return;
      }
    }

    _showLoadingDialog();

    try {
      await _saveOvertimeData(hasLimitExceeded, groupId);

      if (mounted) {
        try {
          await NotificationService().sendManagerNotification(
            pengawasNama: namaPengawas ?? 'Pengawas',
            fungsi: fungsiPengawas ?? '',
            jumlahMitra: _validMiras.length,
            tanggal: tanggalMulai!,
            totalBiaya: totalBiayaLembur,
            urgensi: urgensi,
            isOutsideRadius: _isOutsideRadius,
            lemburIds: [groupId],
            overtimeRates: _overtimeRates!,
          );
        } catch (e) {
          debugPrint('⚠️ Gagal kirim notifikasi: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog(groupId);
      }
    } catch (e) {
      debugPrint('❌ Submit error: $e');
      if (mounted) {
        Navigator.pop(context);
        _showValidationError('Gagal menyimpan: $e');
      }
    }
  }

  // ==================== SAVE DATA (🔥 UPGRADED: SPLIT PER TANGGAL) ====================
  Future<void> _saveOvertimeData(bool hasLimitExceeded, String groupId) async {
    final batch = _firestore.batch();
    final now = Timestamp.now();
    final isOutside = _isOutsideRadius;

    String alamatLengkap = _selectedAddress ?? '';
    if (_locationType == 'proyek') {
      if (_rtController.text.trim().isNotEmpty) {
        alamatLengkap += ' RT ${_rtController.text.trim()}';
      }
      if (_rwController.text.trim().isNotEmpty) {
        alamatLengkap += ' RW ${_rwController.text.trim()}';
      }
    }

    // 🔥 DATA PENGAJUAN (DENGAN RENTANG TANGGAL)
    final pengajuanRef = _firestore.collection('pengajuan_lembur').doc(groupId);
    batch.set(pengajuanRef, {
      'group_id': groupId,
      'tipe_dokumen': 'pengajuan',
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
      'pengawas_id': _auth.currentUser?.uid,
      'nama_pengawas': namaPengawas,
      'pengawas_fungsi': fungsiPengawas,
      // 🔥 DATA BARU: Rentang tanggal
      'tanggal_mulai': Timestamp.fromDate(tanggalMulai!),
      'tanggal_selesai': Timestamp.fromDate(tanggalSelesai!),
      'is_multi_day': isMultiDay,
      'is_overnight': isOvernight,
      // Backward compatibility
      'tanggal_lembur': Timestamp.fromDate(tanggalMulai!),
      'tahun_bulan': DateFormat('yyyy-MM').format(tanggalMulai!),
      'jam_mulai': _formatTime(jamMulai!),
      'jam_selesai': _formatTime(jamSelesai!),
      'total_jam_desimal': totalJam,
      'jenis_lembur': _isWeekend(tanggalMulai!) ? 'hari_libur' : 'hari_kerja',
      'lokasi': {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'alamat': alamatLengkap,
        'rt': _locationType == 'proyek' ? _rtController.text.trim() : '',
        'rw': _locationType == 'proyek' ? _rwController.text.trim() : '',
        'is_outside_radius': isOutside,
        'tipe_lokasi': _locationType,
      },
      'estimasi_biaya_total': totalBiayaLembur,
      'estimasi_biaya_per_mitra': biayaLemburPerMitra,
      'rate_snapshot': _overtimeRates,
      'total_mitra': _validMiras.length,
      'mitra_ids': _validMiras.map((m) => m['id'] as String).toList(),
      'detail_mitra': _validMiras
          .map((m) => {
                'id': m['id'],
                'nama': m['nama_lengkap'],
                'fungsi': m['fungsi'],
              })
          .toList(),
      'urgensi': urgensi,
      'alasan': alasanController.text.trim(),
      'is_override': hasLimitExceeded,
      'is_multiple': _validMiras.length > 1,
      'location_type': _locationType,
    });

    // 🔥 SPLIT PER TANGGAL di lembur_mitra
    final allDates = _getDatesInRange(tanggalMulai!, tanggalSelesai!);

    final baseMitraData = {
      'group_id': groupId,
      'pengajuan_id': groupId,
      'tipe_dokumen': 'lembur_mitra',
      'pengawas_id': _auth.currentUser?.uid,
      'pengawas_fungsi': fungsiPengawas,
      'diajukan_oleh_id': _auth.currentUser?.uid,
      'diajukan_oleh_nama': namaPengawas,
      'lokasi': {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'alamat': alamatLengkap,
        'rt': _locationType == 'proyek' ? _rtController.text.trim() : '',
        'rw': _locationType == 'proyek' ? _rwController.text.trim() : '',
        'is_outside_radius': isOutside,
        'tipe_lokasi': _locationType,
      },
      'estimasi_biaya_per_mitra': biayaLemburPerMitra,
      'estimasi_biaya': biayaLemburPerMitra,
      'rate_snapshot': _overtimeRates,
      'status': 'pending',
      'absensi_status': 'belum_absen',
      'urgensi': urgensi,
      'alasan': alasanController.text.trim(),
      'is_override': hasLimitExceeded,
      'created_at': now,
      'updated_at': now,
    };

    for (final mitra in _validMiras) {
      for (final date in allDates) {
        final isHoliday = _isWeekend(date);

        // Jam spesifik untuk tanggal ini
        TimeOfDay dayStart = const TimeOfDay(hour: 0, minute: 0);
        TimeOfDay dayEnd = const TimeOfDay(hour: 23, minute: 59);

        if (date.year == tanggalMulai!.year &&
            date.month == tanggalMulai!.month &&
            date.day == tanggalMulai!.day) {
          dayStart = jamMulai!;
        }
        if (date.year == tanggalSelesai!.year &&
            date.month == tanggalSelesai!.month &&
            date.day == tanggalSelesai!.day) {
          dayEnd = jamSelesai!;
        }

        final docId = '${groupId}_${mitra['id']}_${DateFormat('yyyyMMdd').format(date)}';
        final docRef = _firestore.collection('lembur_mitra').doc(docId);

        batch.set(docRef, {
          ...baseMitraData,
          'mitra_id': mitra['id'],
          'user_id': mitra['id'],
          'nama_mitra': mitra['nama_lengkap'],
          'fungsi_mitra': mitra['fungsi'],
          'tanggal': Timestamp.fromDate(date),
          'tahun_bulan': DateFormat('yyyy-MM').format(date),
          'jam_mulai': _formatTime(dayStart),
          'jam_selesai': _formatTime(dayEnd),
          'total_jam_desimal': totalJam,
          'jenis_lembur': isHoliday ? 'hari_libur' : 'hari_kerja',
        });
      }
    }

    await batch.commit();
    debugPrint('✅ Data tersimpan untuk group: $groupId (${allDates.length} hari, ${_validMiras.length} mitra)');
  }

  // ==================== DIALOGS ====================

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF1976D2)),
                SizedBox(height: 24),
                Text('Menyimpan Pengajuan...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('Mohon tunggu sebentar',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showLimitWarningDialog(Map<String, dynamic> limitResults) async {
    final mitraOver = <String>[];
    limitResults.forEach((mitraId, info) {
      if (info['is_exceeded']) {
        final mitra = _validMiras.firstWhere((m) => m['id'] == mitraId);
        mitraOver.add(
          '• ${mitra['nama_lengkap']}: ${info['total_jam_bulan_ini'].toStringAsFixed(1)} jam + ${info['tambahan_jam'].toStringAsFixed(1)} jam',
        );
      }
    });

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Melebihi Batas Lembur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Beberapa TAD akan melebihi batas maksimal 60 jam/bulan:'),
            const SizedBox(height: 12),
            ...mitraOver.map((m) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 6),
                  child: Text(m, style: const TextStyle(fontSize: 13)),
                )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Pengajuan ini akan ditandai sebagai OVERRIDE dan memerlukan persetujuan khusus.',
                style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('TETAP AJUKAN',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog(String groupId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
            SizedBox(height: 12),
            Text('Berhasil!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pengajuan lembur berhasil dikirim.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('ID Pengajuan: ${groupId.substring(0, 8)}...',
                  style: const TextStyle(fontFamily: 'monospace')),
            ),
            const SizedBox(height: 4),
            if (isMultiDay || isOvernight)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.purple.shade600),
                    const SizedBox(width: 4),
                    Text(
                      isMultiDay ? 'Lembur Multi-Hari' : 'Lembur Lintas Malam',
                      style: TextStyle(fontSize: 11, color: Colors.purple.shade600, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text('${_validMiras.length} TAD telah didaftarkan',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('SELESAI'),
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog() {
  showDialog(
    context: context,
    builder: (context) => PreviewDialog(
      namaPengawas: namaPengawas,
      fungsiPengawas: fungsiPengawas,
      validMiras: _validMiras,
      tanggalLembur: tanggalMulai,
      tanggalSelesai: tanggalSelesai,
      jamMulai: jamMulai,
      jamSelesai: jamSelesai,
      totalJam: totalJam,
      isMultiDay: isMultiDay,
      isOvernight: isOvernight,
      locationType: _locationType,
      selectedAddress: _selectedAddress,
      rtController: _rtController,
      rwController: _rwController,
      urgensi: urgensi,
      biayaLemburPerMitra: biayaLemburPerMitra,
      totalBiayaLembur: totalBiayaLembur,
      alasan: alasanController.text,
      formatTime: _formatTime,
      formatTanggal: _formatTanggal,
      // 🔥 FIX: Wrap untuk match type
      formatRupiah: (double value) => _overtimeService.formatRupiah(value),
      onConfirmed: () {
        Navigator.pop(context);
        _submit();
      },
    ),
  );
}

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF1976D2),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Memuat data...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mohon tunggu sebentar',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final bottomNavHeight = 65.0;
    final extraPadding = bottomPadding + bottomNavHeight;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_alarm_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Pengajuan Lembur',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_rounded,
                size: 18, color: Colors.white),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: Colors.white),
            ),
            onPressed: () async {
              _overtimeService.clearCache();
              await _loadOvertimeRates();
            },
          ),
          if (_completionPercentage > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                constraints: const BoxConstraints(maxWidth: 45),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${(_completionPercentage * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(16, 16, 16, extraPadding + 8),
              child: Column(
                children: [
                  HeaderProfileCard(
                    namaPengawas: namaPengawas,
                    fungsiPengawas: fungsiPengawas,
                    photoProfileUrl: photoProfileUrl,
                  ),
                  const SizedBox(height: 16),
                  // 🔥 Progress Stepper (updated)
                  ProgressStepper(
                    completionPercentage: _completionPercentage,
                    hasMitra: _validMiras.isNotEmpty,
                    hasTanggal: tanggalMulai != null && tanggalSelesai != null,  // 🔥
                    hasWaktu: jamMulai != null && jamSelesai != null,
                    hasLokasi: _selectedLocation != null,
                    hasAlasan: alasanController.text.length >= 20,
                    isMultiDay: isMultiDay,    // 🔥 BARU
                    isOvernight: isOvernight,  // 🔥 BARU
                  ),
                  const SizedBox(height: 16),
                  if (_overtimeRates != null)
                    RateInfoCard(rates: _overtimeRates!),
                  const SizedBox(height: 16),
                  MitraSection(
                    selectedMiras: selectedMiras,
                    validMiras: _validMiras,
                    duplicateMiras: _duplicateMiras,
                    mitraDuplicateStatus: mitraDuplicateStatus,
                    hasDuplicateMitra: _hasDuplicateMitra,
                    isCheckingDuplicates: isCheckingDuplicates,
                    fungsiPengawas: fungsiPengawas,
                    tanggalLembur: tanggalMulai,    // 🔥
                    onAddMitra: _showMitraSelectionDialog,
                    onRemoveMitra: (mitra) {
                      setState(() {
                        selectedMiras.removeWhere((m) => m['id'] == mitra['id']);
                        selectedMitraIds.remove(mitra['id']);
                        mitraDuplicateStatus.remove(mitra['id']);
                      });
                      _recalculateBiaya();
                    },
                    formatTanggal: _formatTanggal,
                  ),
                  const SizedBox(height: 16),
                  // 🔥🔥🔥 WAKTU SECTION V2 (MULTI-HARI) 🔥🔥🔥
                  WaktuSection(
                    tanggalMulai: tanggalMulai,
                    tanggalSelesai: tanggalSelesai,
                    jamMulai: jamMulai,
                    jamSelesai: jamSelesai,
                    totalJam: totalJam,
                    isMultiDay: isMultiDay,
                    isOvernight: isOvernight,
                    onTanggalMulaiChanged: (date) {
                      setState(() {
                        tanggalMulai = date;
                        if (tanggalSelesai == null || (date != null && tanggalSelesai!.isBefore(date))) {
                          tanggalSelesai = date;
                        }
                        jamMulai = null;
                        jamSelesai = null;
                        totalJam = 0;
                        isMultiDay = false;
                        isOvernight = false;
                      });
                    },
                    onTanggalSelesaiChanged: (date) {
                      setState(() {
                        tanggalSelesai = date;
                        jamSelesai = null;
                        totalJam = 0;
                        isMultiDay = false;
                        isOvernight = false;
                      });
                    },
                    onJamMulaiChanged: (time) {
                      setState(() {
                        jamMulai = time;
                        jamSelesai = null;
                        totalJam = 0;
                        isOvernight = false;
                      });
                    },
                    onJamSelesaiChanged: (time) {
                      jamSelesai = time;
                      _recalculateBiaya();
                    },
                    onClear: () {
                      setState(() {
                        tanggalMulai = null;
                        tanggalSelesai = null;
                        jamMulai = null;
                        jamSelesai = null;
                        totalJam = 0;
                        isMultiDay = false;
                        isOvernight = false;
                        showBudgetBreakdown = false;
                      });
                    },
                    formatTime: _formatTime,
                    formatTanggal: _formatTanggal,
                  ),
                  const SizedBox(height: 16),
                  LokasiSection(
                    locationType: _locationType,
                    selectedLocation: _selectedLocation,
                    selectedAddress: _selectedAddress,
                    isOutsideRadius: _isOutsideRadius,
                    rtController: _rtController,
                    rwController: _rwController,
                    onLocationTypeChanged: (type) {
                      setState(() {
                        _locationType = type;
                        if (type == 'kantor') {
                          _selectedLocation = LatLng(
                            LocationService.kantorLat,
                            LocationService.kantorLng,
                          );
                          _selectedAddress = LocationService.alamatKantor;
                          _rtController.clear();
                          _rwController.clear();
                        } else {
                          _selectedLocation = null;
                          _selectedAddress = null;
                        }
                      });
                    },
                    onPickMap: _showMapPicker,
                  ),
                  const SizedBox(height: 16),
                  AlasanSection(
                    controller: alasanController,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  UrgensiSection(
                    urgensi: urgensi,
                    onUrgensiChanged: (value) {
                      setState(() {
                        urgensi = value;
                        if (value == 'normal') {
                          _locationType = 'kantor';
                          _selectedLocation = LatLng(
                            LocationService.kantorLat,
                            LocationService.kantorLng,
                          );
                          _selectedAddress = LocationService.alamatKantor;
                          _rtController.clear();
                          _rwController.clear();
                        } else {
                          _locationType = 'proyek';
                        }
                      });
                    },
                  ),
                  if (showBudgetBreakdown && totalJam > 0 && _validMiras.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    BudgetBreakdownSection(
                      totalJam: totalJam,
                      validMirasCount: _validMiras.length,
                      biayaLemburPerMitra: biayaLemburPerMitra,
                      totalBiayaLembur: totalBiayaLembur,
                      // 🔥 FIX: Wrap untuk match type
                      formatRupiah: (double value) => _overtimeService.formatRupiah(value),
                      isMultiDay: isMultiDay,
                      isOvernight: isOvernight,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SubmitButton(
                    isComplete: _allDataComplete(),
                    hasDuplicateMitra: _hasDuplicateMitra,
                    completionPercentage: _completionPercentage,
                    onPressed: () => _showPreviewDialog(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: PengawasBottomNav(
        currentIndex: 1,
      ),
    );
  }
}