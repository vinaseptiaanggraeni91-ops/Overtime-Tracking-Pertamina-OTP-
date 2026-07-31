// lib/core/services/mitra_service.dart
// 🔥 FINAL VERSION V9 - NETWORK MONITORING + PERBAIKAN TOTAL JAM, KUOTA & PENDAPATAN
// 🔥 EXCLUDE DIBATALKAN & DITOLAK DARI PERHITUNGAN
// 🔥 FILTER DIBATALKAN di client-side
// 🔥 totalLembur = HANYA disetujui + selesai
// 🔥 FIX: _getTodayOvertime TANPA whereIn (hindari composite index error)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import '/core/services/network_service.dart'; // 🔥 NETWORK SERVICE

var logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.dateAndTime,
  ),
);

class MitraService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notifService = NotificationService();
  
  // 🔥 NETWORK SERVICE
  final NetworkService _networkService = NetworkService();

  // 📦 KONSTANTA NAMA COLLECTION
  static const String collectionUsers = 'users';
  static const String collectionPengajuan = 'pengajuan_lembur';
  static const String collectionLemburMitra = 'lembur_mitra';
  static const String collectionAbsensi = 'absensi';
  static const String collectionSettings = 'settings';
  static const String collectionConfirmations = 'mitra_confirmations';

  // 💰 DEFAULT RATES (fallback jika settings tidak ada)
  static const double defaultBaseSalary = 3000000.0;
  static const double defaultJamKerjaPerBulan = 173.0;
  static const double defaultRatePerHour = defaultBaseSalary / defaultJamKerjaPerBulan;
  static const double defaultMaxKuota = 60.0;
  static const double defaultWeekdayFirstHourMultiplier = 1.5;
  static const double defaultWeekdayNextHoursMultiplier = 2.0;
  static const double defaultHolidayFirst8HoursMultiplier = 2.0;
  static const double defaultHolidayNinthHourMultiplier = 3.0;
  static const double defaultHolidayTenthPlusMultiplier = 4.0;

  // 🔥 STATUS YANG DIABAIKAN DALAM PERHITUNGAN
  static const List<String> _excludedStatuses = ['dibatalkan', 'ditolak', 'rejected', 'draft'];

  // 🔥 STATUS VALID UNTUK TODAY OVERTIME
  static const List<String> _validTodayStatuses = [
    'disetujui', 'approved', 'check_in', 'check_out', 'selesai'
  ];

  // ═══════════════════════════════════════════════════════
  // 🔥 NETWORK CHECK HELPERS
  // ═══════════════════════════════════════════════════════

  bool _checkConnection(String operationName) {
    if (!_networkService.isOnline) {
      logger.w('⚠️ [$operationName] Dibatalkan - Tidak ada koneksi internet');
      return false;
    }
    return true;
  }

  // ═══════════════════════════════════════════════════════
  // 📅 DATE HELPERS
  // ═══════════════════════════════════════════════════════

  DateTime getStartOfCurrentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime getEndOfCurrentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  }

  DateTime getStartOfLastMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 1, 1);
  }

  DateTime getEndOfLastMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 0, 23, 59, 59, 999);
  }

  DateTime getStartOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime getEndOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  String getCurrentYearMonth() => DateFormat('yyyy-MM').format(DateTime.now());

  String getLastMonthYearMonth() {
    final lastMonth = DateTime.now().subtract(const Duration(days: 30));
    return DateFormat('yyyy-MM').format(lastMonth);
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 HELPER: Cek status dibatalkan/ditolak (client-side)
  // ═══════════════════════════════════════════════════════

  bool _isExcluded(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    return _excludedStatuses.contains(status);
  }

  bool _isDibatalkan(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    return status == 'dibatalkan';
  }

  bool _isDitolak(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    return status == 'ditolak' || status == 'rejected';
  }

  bool _isValidTodayStatus(String? status) {
    return _validTodayStatuses.contains(status?.toLowerCase());
  }

  // ═══════════════════════════════════════════════════════
  // 🎨 HELPER METHODS
  // ═══════════════════════════════════════════════════════

  String formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '-';
    DateTime time;
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else if (timestamp is DateTime) {
      time = timestamp;
    } else if (timestamp is String) {
      time = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return '-';
    }
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 365) return DateFormat('dd MMM yyyy').format(time);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} bln lalu';
    if (diff.inDays > 0) return '${diff.inDays} hari lalu';
    if (diff.inHours > 0) return '${diff.inHours} jam lalu';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mnt lalu';
    return 'Baru saja';
  }

  Color getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'approved':
        return Colors.green;
      case 'selesai':
        return Colors.teal;
      case 'pending':
        return Colors.orange;
      case 'ditolak':
      case 'rejected':
        return Colors.red;
      case 'dibatalkan':
        return Colors.red.shade300;
      case 'check_in':
        return Colors.blue;
      case 'check_out':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return const Color(0xFF9C27B0);
      case 'manager':
        return const Color(0xFFFF9800);
      case 'pengawas':
        return const Color(0xFF4CAF50);
      case 'mitra':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '🌅';
    if (hour < 15) return '☀️';
    if (hour < 18) return '🌆';
    return '🌙';
  }

  String formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  String formatRupiahCompact(double amount) {
    if (amount >= 1000000) {
      final juta = amount / 1000000;
      final decimal = amount % 1000000 == 0 ? 0 : 1;
      return 'Rp ${juta.toStringAsFixed(decimal)} Jt';
    } else if (amount >= 1000) {
      final ribu = amount / 1000;
      return 'Rp ${ribu.toStringAsFixed(0)} Rb';
    } else {
      return 'Rp ${amount.toStringAsFixed(0)}';
    }
  }

  // ═══════════════════════════════════════════════════════
  // 💰 KALKULASI INCOME - SUPER LENGKAP
  // ═══════════════════════════════════════════════════════

  double calculateIncome(double hours, {Map<String, dynamic>? settings, bool isHoliday = false}) {
    if (hours <= 0) return 0;

    final rate = (settings?['rate_per_hour'] as num?)?.toDouble() ?? defaultRatePerHour;

    if (isHoliday) {
      final m1 = (settings?['holiday_rate']?['first_8_hours_multiplier'] as num?)?.toDouble() 
          ?? defaultHolidayFirst8HoursMultiplier;
      final m2 = (settings?['holiday_rate']?['ninth_hour_multiplier'] as num?)?.toDouble() 
          ?? defaultHolidayNinthHourMultiplier;
      final m3 = (settings?['holiday_rate']?['tenth_plus_multiplier'] as num?)?.toDouble() 
          ?? defaultHolidayTenthPlusMultiplier;

      if (hours <= 8) return hours * rate * m1;
      if (hours <= 9) return (8 * rate * m1) + ((hours - 8) * rate * m2);
      return (8 * rate * m1) + (1 * rate * m2) + ((hours - 9) * rate * m3);
    } else {
      final m1 = (settings?['weekday_rate']?['first_hour_multiplier'] as num?)?.toDouble() 
          ?? defaultWeekdayFirstHourMultiplier;
      final m2 = (settings?['weekday_rate']?['next_hours_multiplier'] as num?)?.toDouble() 
          ?? defaultWeekdayNextHoursMultiplier;

      if (hours <= 1) return hours * rate * m1;
      return (1 * rate * m1) + ((hours - 1) * rate * m2);
    }
  }

  double estimateIncomeFromSchedule(String jamMulai, String jamSelesai, {Map<String, dynamic>? settings, bool isHoliday = false}) {
    final hours = calculateHoursFromSchedule(jamMulai, jamSelesai);
    return calculateIncome(hours, settings: settings, isHoliday: isHoliday);
  }

  double calculateHoursFromSchedule(String jamMulai, String jamSelesai) {
    try {
      final partsMulai = jamMulai.split(':');
      final partsSelesai = jamSelesai.split(':');

      if (partsMulai.length != 2 || partsSelesai.length != 2) return 0;

      final mulaiMinutes = (int.tryParse(partsMulai[0]) ?? 0) * 60 + (int.tryParse(partsMulai[1]) ?? 0);
      var selesaiMinutes = (int.tryParse(partsSelesai[0]) ?? 0) * 60 + (int.tryParse(partsSelesai[1]) ?? 0);

      if (selesaiMinutes <= mulaiMinutes) selesaiMinutes += 24 * 60;

      return (selesaiMinutes - mulaiMinutes) / 60.0;
    } catch (_) {
      return 0;
    }
  }

  String formatDuration(String jamMulai, String jamSelesai) {
    final hours = calculateHoursFromSchedule(jamMulai, jamSelesai);
    if (hours <= 0) return '';
    
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    
    if (h > 0 && m > 0) return '${h}j ${m}m';
    if (h > 0) return '${h}j';
    if (m > 0) return '${m}m';
    return '';
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  // ═══════════════════════════════════════════════════════
  // 📊 LOAD DASHBOARD DATA - FULLY OPTIMIZED
  // ═══════════════════════════════════════════════════════

  Future<MitraDashboardData> loadDashboardData() async {
    // 🔥 CEK KONEKSI
    if (!_checkConnection('loadDashboardData')) {
      logger.w('⚠️ loadDashboardData: OFFLINE - Mengembalikan data kosong');
      return MitraDashboardData(
        userData: {},
        userName: 'Offline',
        fungsi: 'unknown',
        todayOvertime: null,
        todayAbsensi: null,
        isCheckedIn: false,
        isCheckedOut: false,
        lastCheckIn: null,
        lastCheckOut: null,
        workDuration: null,
        allLembur: [],
        schedules: [],
        pendingRequests: [],
        stats: {},
        overtimeSettings: {},
        unreadNotifications: 0,
        bulanStats: _BulanStats.empty(),
        bulanLaluStats: _BulanStats.empty(),
      );
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('User tidak login');

    final userId = user.uid;

    logger.i('🚀 Memulai load dashboard data untuk user: $userId');
    logger.i('📅 Filter BULAN INI: ${DateFormat('dd MMM yyyy').format(getStartOfCurrentMonth())} - ${DateFormat('dd MMM yyyy').format(getEndOfCurrentMonth())}');
    logger.i('⚠️ Status dibatalkan & ditolak akan DIIGNORE dalam perhitungan');

    try {
      final results = await Future.wait([
        _getUserData(userId),
        _getLemburBulanIni(userId),
        _getLemburBulanLalu(userId),
        _getTodayOvertime(userId),
        _getAbsensiToday(userId, DateTime.now()),
        _getPendingRequests(userId, DateTime.now()),
        _getAdditionalData(userId),
        _getAllLemburData(userId),
      ]);

      final userData = results[0] as Map<String, dynamic>;
      final lemburBulanIni = results[1] as _BulanStats;
      final lemburBulanLalu = results[2] as _BulanStats;
      final todayOvertime = results[3] as Map<String, dynamic>?;
      final absensiData = results[4] as _AbsensiResult;
      final pendingData = results[5] as List<Map<String, dynamic>>;
      final additionalData = results[6] as _AdditionalData;
      final allLemburData = results[7] as List<Map<String, dynamic>>;

      final mergedStats = _mergeStats(lemburBulanIni, lemburBulanLalu);
      final schedules = _buildSchedules(allLemburData, DateTime.now());

      logger.i('✅ DASHBOARD DATA LOADED SUCCESSFULLY');
      logger.i('📊 STATS BULAN INI: totalLembur=${lemburBulanIni.totalLembur}, totalJam=${lemburBulanIni.totalJam.toStringAsFixed(2)}, '
          'income=${formatCurrency(lemburBulanIni.totalIncome)}, sisaKuota=${lemburBulanIni.sisaKuota.toStringAsFixed(2)}');
      logger.i('📊 STATUS: pending=${lemburBulanIni.pending}, disetujui=${lemburBulanIni.disetujui}, '
          'ditolak=${lemburBulanIni.ditolak}, selesai=${lemburBulanIni.selesai}');
      logger.i('🔍 TODAY OVERTIME: ${todayOvertime != null ? "ADA (${todayOvertime!['id']}, status=${todayOvertime!['status']})" : "KOSONG - Tidak ada lembur aktif hari ini"}');

      return MitraDashboardData(
        userData: userData,
        userName: userData['nama_lengkap']?.toString() ?? user.email?.split('@')[0] ?? 'Mitra',
        fungsi: userData['fungsi']?.toString() ?? 'operation',
        todayOvertime: todayOvertime,
        todayAbsensi: absensiData.doc,
        isCheckedIn: absensiData.isCheckedIn,
        isCheckedOut: absensiData.isCheckedOut,
        lastCheckIn: absensiData.checkInTime,
        lastCheckOut: absensiData.checkOutTime,
        workDuration: absensiData.workDuration,
        allLembur: allLemburData,
        schedules: schedules,
        pendingRequests: pendingData,
        stats: mergedStats,
        overtimeSettings: additionalData.settings,
        unreadNotifications: additionalData.unreadCount,
        bulanStats: lemburBulanIni,
        bulanLaluStats: lemburBulanLalu,
      );
    } catch (e, stackTrace) {
      logger.e('❌ Gagal load dashboard data', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔍 PRIVATE GETTER METHODS
  // ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      final doc = await _firestore.collection(collectionUsers).doc(userId).get();
      if (!doc.exists) throw Exception('Data user tidak ditemukan');
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      logger.e('Gagal ambil data user: $e');
      throw Exception('Gagal memuat data user');
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    return _getUserData(user.uid);
  }

  // ═══════════════════════════════════════════════════════
  // GET LEMBUR BULAN INI & BULAN LALU
  // ═══════════════════════════════════════════════════════

  Future<_BulanStats> _getLemburBulanIni(String userId) async {
    try {
      final startOfMonth = getStartOfCurrentMonth();
      final endOfMonth = getEndOfCurrentMonth();

      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: userId)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      logger.i('📊 Lembur bulan ini (SEBELUM filter): ${snapshot.docs.length} data');

      final validDocs = snapshot.docs.where((doc) => !_isExcluded(doc.data())).toList();
      
      logger.i('📊 Lembur bulan ini (SETELAH filter): ${validDocs.length} data');
      
      for (var doc in validDocs) {
        final data = doc.data();
        final status = data['status']?.toString() ?? 'unknown';
        logger.d('  - ${doc.id}: status=$status');
      }

      return _calculateBulanStats(validDocs);
    } catch (e) {
      logger.e('❌ Gagal ambil lembur bulan ini: $e');
      return _BulanStats.empty();
    }
  }

  Future<_BulanStats> _getLemburBulanLalu(String userId) async {
    try {
      final startOfLastMonth = getStartOfLastMonth();
      final endOfLastMonth = getEndOfLastMonth();

      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: userId)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfLastMonth))
          .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(endOfLastMonth))
          .get();

      final validDocs = snapshot.docs.where((doc) => !_isExcluded(doc.data())).toList();
      
      return _calculateBulanStats(validDocs);
    } catch (e) {
      logger.e('❌ Gagal ambil lembur bulan lalu: $e');
      return _BulanStats.empty();
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 PERBAIKAN UTAMA: _calculateBulanStats
  // totalLembur = HANYA disetujui + selesai
  // ═══════════════════════════════════════════════════════

  _BulanStats _calculateBulanStats(List<QueryDocumentSnapshot> docs) {
    int totalLemburKeseluruhan = 0;
    int totalLemburSelesai = 0;
    double totalJam = 0;
    int pending = 0;
    int disetujui = 0;
    int ditolak = 0;
    int selesai = 0;
    double totalIncome = 0;

    final statusCounts = <String, int>{};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final status = (data['status'] as String? ?? 'pending').toLowerCase();
      
      if (_excludedStatuses.contains(status)) continue;

      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      totalLemburKeseluruhan++;

      switch (status) {
        case 'pending':
          pending++;
          break;
          
        case 'disetujui':
        case 'approved':
          disetujui++;
          totalLemburSelesai++;
          final jamDisetujui = _parseDouble(data['actual_total_jam'] ?? 0);
          if (jamDisetujui > 0) {
            totalJam += jamDisetujui;
            final inc = _parseDouble(data['actual_income'] ?? data['income_amount'] ?? 0);
            if (inc > 0) totalIncome += inc;
          }
          break;
          
        case 'selesai':
          selesai++;
          totalLemburSelesai++;
          
          double jamAktual = 0;
          final jamFields = ['actual_total_jam', 'total_jam_desimal', 'total_jam_real', 'total_jam_aktual', 'total_jam'];
          for (String field in jamFields) {
            final val = _parseDouble(data[field] ?? 0);
            if (val > 0) { jamAktual = val; break; }
          }
          if (jamAktual == 0) {
            final jamMulai = data['jam_mulai']?.toString() ?? '';
            final jamSelesai = data['jam_selesai']?.toString() ?? '';
            if (jamMulai.isNotEmpty && jamSelesai.isNotEmpty) {
              jamAktual = calculateHoursFromSchedule(jamMulai, jamSelesai);
            }
          }
          totalJam += jamAktual;
          
          double income = 0;
          final incomeFields = ['actual_income', 'income_amount', 'income', 'pendapatan_actual', 'estimasi_biaya_per_mitra', 'estimasi_biaya'];
          for (String field in incomeFields) {
            final val = _parseDouble(data[field] ?? 0);
            if (val > 0) { income = val; break; }
          }
          if (income == 0 && jamAktual > 0) {
            final isHoliday = (data['jenis_lembur']?.toString() ?? '') == 'hari_libur';
            final ratePerHour = _parseDouble(data['rate_per_hour'] ?? 0);
            if (ratePerHour > 0) {
              income = jamAktual * ratePerHour;
            } else {
              income = calculateIncome(jamAktual, isHoliday: isHoliday);
            }
          }
          totalIncome += income;
          
          logger.d('  ✅ SELESAI: ${doc.id} | jam=$jamAktual | income=$income');
          break;
          
        case 'check_in':
        case 'check_out':
          pending++;
          break;
          
        default:
          pending++;
          break;
      }
    }

    logger.d('📊 Status counts: $statusCounts');
    logger.i('📊 HASIL: totalKeseluruhan=$totalLemburKeseluruhan | totalSelesai=$totalLemburSelesai | jam=$totalJam | income=${formatCurrency(totalIncome)} | '
        'pending=$pending | disetujui=$disetujui | selesai=$selesai | ditolak=$ditolak');

    final double sisaKuota = (defaultMaxKuota - totalJam).clamp(0.0, defaultMaxKuota);

    return _BulanStats(
      totalLembur: totalLemburSelesai,
      totalJam: totalJam,
      pending: pending,
      disetujui: disetujui,
      ditolak: ditolak,
      selesai: selesai,
      totalIncome: totalIncome,
      sisaKuota: sisaKuota,
    );
  }

  // ═══════════════════════════════════════════════════════
  // _mergeStats
  // ═══════════════════════════════════════════════════════

  Map<String, dynamic> _mergeStats(_BulanStats bulanIni, _BulanStats bulanLalu) {
    final double trendLembur = bulanLalu.totalLembur > 0
        ? ((bulanIni.totalLembur - bulanLalu.totalLembur) / bulanLalu.totalLembur) * 100
        : 0.0;

    final double trendJam = bulanLalu.totalJam > 0
        ? ((bulanIni.totalJam - bulanLalu.totalJam) / bulanLalu.totalJam) * 100
        : 0.0;

    final double trendIncome = bulanLalu.totalIncome > 0
        ? ((bulanIni.totalIncome - bulanLalu.totalIncome) / bulanLalu.totalIncome) * 100
        : 0.0;

    return {
      'trendLembur': trendLembur,
      'trendJam': trendJam,
      'trendIncome': trendIncome,
      'bulanIni': getCurrentYearMonth(),
      'bulanLalu': getLastMonthYearMonth(),
    };
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 PERBAIKAN KRUSIAL: _getTodayOvertime
  // TANPA whereIn('status', ...) untuk menghindari error composite index
  // Filter status dilakukan secara manual di kode Dart
  // ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> _getTodayOvertime(String userId) async {
    try {
      final startOfToday = getStartOfToday();
      final endOfToday = getEndOfToday();

      logger.d('🔍 Mencari lembur hari ini untuk user: $userId');
      logger.d('📅 Range: ${DateFormat('dd MMM yyyy HH:mm').format(startOfToday)} - ${DateFormat('dd MMM yyyy HH:mm').format(endOfToday)}');

      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: userId)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(endOfToday))
          .get();

      logger.d('📊 Ditemukan ${snapshot.docs.length} dokumen lembur hari ini');

      if (snapshot.docs.isEmpty) {
        logger.d('❌ Tidak ada lembur sama sekali hari ini untuk $userId');
        return null;
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? 'unknown');
        logger.d('  📄 ${doc.id}: status="$status" | mitra_id=${data['mitra_id']} | tanggal=${data['tanggal']}');
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? '').toLowerCase().trim();

        if (_excludedStatuses.contains(status)) {
          logger.d('  ⛔ ${doc.id}: status "$status" excluded (dibatalkan/ditolak)');
          continue;
        }

        if (_validTodayStatuses.contains(status)) {
          logger.i('✅ Lembur valid ditemukan: ${doc.id} (status: $status)');
          return _normalizeLemburData(doc);
        } else {
          logger.d('  ❓ ${doc.id}: status "$status" tidak termasuk dalam valid status list');
        }
      }

      final allStatuses = snapshot.docs.map((d) => d.data()['status']?.toString() ?? 'null').toList();
      logger.w('❌ Tidak ada lembur dengan status valid. Status yang ditemukan: $allStatuses');
      logger.w('   Status valid yang dicari: $_validTodayStatuses');
      
      return null;
    } catch (e) {
      logger.e('❌ Gagal ambil overtime hari ini: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getAllLemburData(String userId) async {
    try {
      final startOfMonth = getStartOfCurrentMonth();

      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: userId)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .orderBy('tanggal', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .where((doc) => !_isExcluded(doc.data()))
          .map((doc) => _normalizeLemburData(doc))
          .toList();
    } catch (e) {
      logger.e('❌ Gagal ambil semua data lembur: $e');
      return [];
    }
  }

  Map<String, dynamic> _normalizeLemburData(QueryDocumentSnapshot doc) {
    final raw = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);

    if (raw['tanggal'] is Timestamp) {
      raw['tanggal_date'] = (raw['tanggal'] as Timestamp).toDate();
    }
    if (raw['created_at'] is Timestamp) {
      raw['created_at_date'] = (raw['created_at'] as Timestamp).toDate();
    }
    if (raw['updated_at'] is Timestamp) {
      raw['updated_at_date'] = (raw['updated_at'] as Timestamp).toDate();
    }

    final status = raw['status']?.toString().toLowerCase() ?? 'pending';
    final jamMulai = raw['jam_mulai']?.toString() ?? '19:00';
    final jamSelesai = raw['jam_selesai']?.toString() ?? '22:00';
    final isHoliday = (raw['jenis_lembur']?.toString() ?? '') == 'hari_libur';
    final jamAktual = _parseDouble(raw['actual_total_jam']);
    
    double income = 0;
    if (status == 'selesai') {
      income = _parseDouble(raw['actual_income'] ?? raw['income_amount'] ?? 0);
      if (income == 0 && jamAktual > 0) {
        income = calculateIncome(jamAktual, isHoliday: isHoliday);
      }
    }

    final durasi = formatDuration(jamMulai, jamSelesai);
    final totalJam = status == 'selesai' 
        ? (jamAktual > 0 ? jamAktual : calculateHoursFromSchedule(jamMulai, jamSelesai))
        : calculateHoursFromSchedule(jamMulai, jamSelesai);

    return {
      'id': doc.id,
      'status': status,
      'tanggal': raw['tanggal'],
      'tanggal_date': raw['tanggal_date'],
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'durasi': durasi,
      'total_jam': totalJam,
      'total_jam_desimal': _parseDouble(raw['total_jam_desimal'] ?? raw['total_jam'] ?? totalJam),
      'actual_total_jam': jamAktual,
      'income': income,
      'income_formatted': formatCurrency(income),
      'income_compact': formatRupiahCompact(income),
      'is_holiday': isHoliday,
      'alasan': raw['alasan']?.toString() ?? raw['keterangan']?.toString() ?? 'Lembur',
      'jenis_lembur': raw['jenis_lembur']?.toString() ?? 'hari_kerja',
      'lokasi': raw['lokasi'] is Map ? raw['lokasi']['pilihan']?.toString() ?? 'Kantor' : 'Kantor',
      'nama_pengawas': raw['nama_pengawas']?.toString() ?? raw['pengawas_nama']?.toString() ?? 'Pengawas',
      'pengawas_id': raw['pengawas_id']?.toString() ?? raw['diajukan_oleh_id']?.toString(),
      'pengawas_fungsi': raw['pengawas_fungsi']?.toString(),
      'tahun_bulan': raw['tahun_bulan']?.toString(),
      'absensi_status': raw['absensi_status']?.toString(),
      'absensi_waktu': raw['absensi_waktu'],
      'absensi_checkout_waktu': raw['absensi_checkout_waktu'],
      'absensi_oleh': raw['absensi_oleh']?.toString(),
      'absensi_nama': raw['absensi_nama']?.toString(),
      'is_income_calculated': raw['is_income_calculated'] == true,
      'group_id': raw['group_id']?.toString(),
      'mitra_id': raw['mitra_id']?.toString(),
      'created_at': raw['created_at'],
      'updated_at': raw['updated_at'],
      'created_at_date': raw['created_at_date'],
      'updated_at_date': raw['updated_at_date'],
    };
  }

  Future<_AbsensiResult> _getAbsensiToday(String userId, DateTime now) async {
    try {
      final startOfDay = getStartOfToday();
      final snapshot = await _firestore
          .collection(collectionAbsensi)
          .where('user_id', isEqualTo: userId)
          .where('waktu', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return _AbsensiResult.empty();

      final data = snapshot.docs.first.data() as Map<String, dynamic>? ?? {};
      DateTime? checkInTime;
      DateTime? checkOutTime;

      if (data['waktu'] is Timestamp) checkInTime = (data['waktu'] as Timestamp).toDate();
      if (data['waktu_checkout'] is Timestamp) checkOutTime = (data['waktu_checkout'] as Timestamp).toDate();

      return _AbsensiResult(
        doc: data,
        isCheckedIn: checkInTime != null,
        isCheckedOut: checkOutTime != null,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
        workDuration: checkInTime != null
            ? (checkOutTime ?? DateTime.now()).difference(checkInTime)
            : null,
      );
    } catch (e) {
      logger.e('Gagal ambil data absensi: $e');
      return _AbsensiResult.empty();
    }
  }

  Future<List<Map<String, dynamic>>> _getPendingRequests(String userId, DateTime now) async {
    try {
      final snapshot = await _firestore
          .collection(collectionPengajuan)
          .where('mitra_ids', arrayContains: userId)
          .where('status', isEqualTo: 'pending')
          .where('tanggal_lembur', isGreaterThanOrEqualTo: Timestamp.fromDate(now.subtract(const Duration(days: 1))))
          .orderBy('tanggal_lembur', descending: false)
          .get();

      final confDoc = await _firestore.collection(collectionConfirmations).doc(userId).get();
      final confirmedIds = <String>{};
      if (confDoc.exists && confDoc.data() != null) {
        final data = confDoc.data() as Map<String, dynamic>;
        if (data['confirmed_overtime_ids'] is List) {
          confirmedIds.addAll(List<String>.from(data['confirmed_overtime_ids']));
        }
      }

      final requests = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final d = doc.data() as Map<String, dynamic>? ?? {};
        if (confirmedIds.contains(doc.id)) continue;
        if (_isDibatalkan(d)) continue;
        
        final jamMulai = d['jam_mulai']?.toString() ?? '19:00';
        final jamSelesai = d['jam_selesai']?.toString() ?? '22:00';
        final isHoliday = (d['jenis_lembur']?.toString() ?? '') == 'hari_libur';
        final estimasiJam = calculateHoursFromSchedule(jamMulai, jamSelesai);
        final estimasiBiaya = calculateIncome(estimasiJam, isHoliday: isHoliday);

        requests.add({
          'id': doc.id,
          'tanggal': d['tanggal_lembur'] ?? d['tanggal'],
          'jam_mulai': jamMulai,
          'jam_selesai': jamSelesai,
          'durasi': formatDuration(jamMulai, jamSelesai),
          'total_jam': estimasiJam,
          'estimasi_biaya': estimasiBiaya,
          'estimasi_biaya_formatted': formatCurrency(estimasiBiaya),
          'alasan': d['alasan']?.toString() ?? 'Lembur',
          'pengawas_nama': d['nama_pengawas']?.toString() ?? 'Pengawas',
          'pengawas_id': d['pengawas_id']?.toString(),
          'pengawas_fungsi': d['pengawas_fungsi']?.toString() ?? '',
          'urgensi': d['urgensi']?.toString() ?? 'normal',
          'jenis_lembur': d['jenis_lembur']?.toString() ?? 'hari_kerja',
          'is_holiday': isHoliday,
          'lokasi': d['lokasi'] is Map ? d['lokasi']['pilihan']?.toString() ?? 'Kantor' : 'Kantor',
        });
      }
      return requests;
    } catch (e) {
      logger.e('Gagal ambil pending requests: $e');
      return [];
    }
  }

  Future<_AdditionalData> _getAdditionalData(String userId) async {
    final results = await Future.wait([
      _notifService.getUnreadCount(userId).catchError((e) {
        logger.e('Gagal ambil notifikasi: $e');
        return 0;
      }),
      _firestore.collection(collectionSettings).doc('overtime_rates').get().then((doc) {
        if (doc.exists && doc.data() != null) {
          return doc.data() as Map<String, dynamic>;
        }
        return <String, dynamic>{};
      }).catchError((e) {
        logger.e('Gagal ambil settings: $e');
        return <String, dynamic>{};
      }),
    ]);

    return _AdditionalData(
      unreadCount: results[0] as int,
      settings: results[1] as Map<String, dynamic>,
    );
  }

  List<Map<String, dynamic>> _buildSchedules(List<Map<String, dynamic>> allLembur, DateTime now) {
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    return allLembur.where((d) {
      final status = (d['status'] as String? ?? '').toLowerCase();
      final tanggal = d['tanggal_date'] as DateTime?;
      return (status == 'disetujui' || status == 'approved') &&
          tanggal != null &&
          tanggal.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
          tanggal.isBefore(endOfWeek.add(const Duration(days: 1)));
    }).toList();
  }

  // ═══════════════════════════════════════════════════════
  // 📋 PUBLIC METHODS
  // ═══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getUpcomingSchedules() async {
    try {
      if (!_checkConnection('getUpcomingSchedules')) return [];
      
      final user = _auth.currentUser;
      if (user == null) return [];

      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));

      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: user.uid)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
          .orderBy('tanggal', descending: false)
          .get();

      return snapshot.docs
          .where((doc) {
            final status = (doc.data()['status']?.toString() ?? '').toLowerCase();
            return (status == 'disetujui' || status == 'approved') && !_isDibatalkan(doc.data());
          })
          .map((doc) {
            final data = doc.data();
            final date = (data['tanggal'] as Timestamp).toDate();
            final jamMulai = data['jam_mulai']?.toString() ?? '--:--';
            final jamSelesai = data['jam_selesai']?.toString() ?? '--:--';
            final isHoliday = (data['jenis_lembur']?.toString() ?? '') == 'hari_libur';

            return {
              'id': doc.id,
              'date': DateFormat('dd MMM yyyy', 'id_ID').format(date),
              'date_raw': date,
              'jam_mulai': jamMulai,
              'jam_selesai': jamSelesai,
              'durasi': formatDuration(jamMulai, jamSelesai),
              'description': data['alasan']?.toString() ?? data['keterangan']?.toString() ?? 'Lembur Rutin',
              'status': data['status']?.toString() ?? 'scheduled',
              'location': data['lokasi'] is Map ? data['lokasi']['pilihan']?.toString() ?? 'Kantor' : 'Kantor',
              'is_holiday': isHoliday,
              'estimasi_income': estimateIncomeFromSchedule(jamMulai, jamSelesai, isHoliday: isHoliday),
            };
          }).toList();
    } catch (e) {
      logger.e('Error getting upcoming schedules: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRecentOvertimeHistory({int limit = 5}) async {
    try {
      if (!_checkConnection('getRecentOvertimeHistory')) return [];
      
      final user = _auth.currentUser;
      if (user == null) return [];

      final startOfMonth = getStartOfCurrentMonth();
      final endOfMonth = getEndOfCurrentMonth();

      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: user.uid)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('tanggal', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .where((doc) => !_isExcluded(doc.data()))
          .map((doc) {
            final data = doc.data();
            final date = (data['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now();
            final status = data['status']?.toString() ?? 'pending';
            final jamMulai = data['jam_mulai']?.toString() ?? '--:--';
            final jamSelesai = data['jam_selesai']?.toString() ?? '--:--';
            final isHoliday = (data['jenis_lembur']?.toString() ?? '') == 'hari_libur';

            double income = 0;
            if (status == 'selesai') {
              income = _parseDouble(data['actual_income'] ?? data['income_amount'] ?? 0);
              if (income == 0) {
                final jamAktual = _parseDouble(data['actual_total_jam']);
                if (jamAktual > 0) income = calculateIncome(jamAktual, isHoliday: isHoliday);
              }
              if (income == 0 && jamMulai != '--:--' && jamSelesai != '--:--') {
                income = estimateIncomeFromSchedule(jamMulai, jamSelesai, isHoliday: isHoliday);
              }
            }

            final totalJam = status == 'selesai'
                ? (_parseDouble(data['actual_total_jam']) > 0 ? _parseDouble(data['actual_total_jam']) : calculateHoursFromSchedule(jamMulai, jamSelesai))
                : calculateHoursFromSchedule(jamMulai, jamSelesai);

            return {
              'id': doc.id,
              'date': DateFormat('dd MMM yyyy', 'id_ID').format(date),
              'date_raw': date,
              'jam_mulai': jamMulai,
              'jam_selesai': jamSelesai,
              'durasi': formatDuration(jamMulai, jamSelesai),
              'total_jam': totalJam,
              'income': income,
              'income_formatted': formatCurrency(income),
              'income_compact': formatRupiahCompact(income),
              'status': status,
              'description': data['alasan']?.toString() ?? data['keterangan']?.toString() ?? '',
              'is_holiday': isHoliday,
              'location': data['lokasi'] is Map ? data['lokasi']['pilihan']?.toString() ?? 'Kantor' : 'Kantor',
            };
          }).toList();
    } catch (e) {
      logger.e('Error getting recent overtime history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getTodayAttendance() async {
    try {
      if (!_checkConnection('getTodayAttendance')) return null;
      
      final user = _auth.currentUser;
      if (user == null) return null;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection(collectionAbsensi)
          .where('user_id', isEqualTo: user.uid)
          .where('waktu', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('waktu', isLessThan: Timestamp.fromDate(todayEnd))
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'is_checked_in': false,
          'check_in_time': '--:--',
          'working_hours': '0',
          'status': 'Belum Absen',
        };
      }

      final data = snapshot.docs.first.data();
      final checkInTime = (data['waktu'] as Timestamp?)?.toDate();
      final checkOutTime = (data['waktu_checkout'] as Timestamp?)?.toDate();

      double workingHours = 0;
      if (checkInTime != null) {
        final endTime = checkOutTime ?? DateTime.now();
        workingHours = endTime.difference(checkInTime).inMinutes / 60.0;
      }

      return {
        'is_checked_in': checkInTime != null,
        'check_in_time': checkInTime != null ? DateFormat('HH:mm').format(checkInTime) : '--:--',
        'working_hours': workingHours.toStringAsFixed(1),
        'status': checkOutTime != null ? 'Selesai' : (checkInTime != null ? 'Sedang Bekerja' : 'Belum Absen'),
      };
    } catch (e) {
      logger.e('Error getting today attendance: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPerformanceData({int months = 6}) async {
    try {
      if (!_checkConnection('getPerformanceData')) return [];
      
      final user = _auth.currentUser;
      if (user == null) return [];

      final now = DateTime.now();
      final result = <Map<String, dynamic>>[];

      for (int i = months - 1; i >= 0; i--) {
        final targetMonth = DateTime(now.year, now.month - i, 1);
        final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
        final endOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59, 999);

        final snapshot = await _firestore
            .collection(collectionLemburMitra)
            .where('mitra_id', isEqualTo: user.uid)
            .where('status', isEqualTo: 'selesai')
            .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
            .get();

        double totalHours = 0;
        double totalIncome = 0;
        int count = snapshot.docs.where((doc) => !_isDibatalkan(doc.data())).length;

        for (var doc in snapshot.docs) {
          if (_isDibatalkan(doc.data())) continue;
          final data = doc.data();
          totalHours += _parseDouble(data['actual_total_jam'] ?? 0);
          totalIncome += _parseDouble(data['actual_income'] ?? data['income_amount'] ?? 0);
        }

        result.add({
          'month': DateFormat('MMM', 'id_ID').format(targetMonth),
          'year': targetMonth.year,
          'hours': totalHours,
          'count': count,
          'income': totalIncome,
          'income_formatted': formatCurrency(totalIncome),
          'monthKey': DateFormat('yyyy-MM').format(targetMonth),
        });
      }

      return result;
    } catch (e) {
      logger.e('❌ Error getting performance data: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CHECK-IN & CHECK-OUT
  // ═══════════════════════════════════════════════════════

  Future<void> checkInLembur(String lemburId, String userName) async {
    // 🔥 CEK KONEKSI
    if (!_checkConnection('checkInLembur')) {
      throw Exception('Tidak ada koneksi internet. Tidak dapat melakukan check-in.');
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('User tidak login');

    try {
      final lemburDoc = await _firestore.collection(collectionLemburMitra).doc(lemburId).get();
      if (!lemburDoc.exists) throw Exception('Data lembur tidak ditemukan');

      final lemburData = lemburDoc.data() ?? {};
      if (lemburData['mitra_id'] != user.uid) throw Exception('Bukan lembur milik Anda');
      if (_isExcluded(lemburData)) throw Exception('Lembur sudah dibatalkan atau ditolak');

      final now = FieldValue.serverTimestamp();
      final batch = _firestore.batch();

      batch.update(_firestore.collection(collectionLemburMitra).doc(lemburId), {
        'absensi_status': 'check_in',
        'absensi_waktu': now,
        'absensi_oleh': user.uid,
        'absensi_nama': userName,
        'updated_at': now,
      });

      batch.set(_firestore.collection(collectionAbsensi).doc(), {
        'lembur_id': lemburId,
        'user_id': user.uid,
        'user_name': userName,
        'waktu': now,
        'tanggal_lembur': lemburData['tanggal'],
        'pengawas_id': lemburData['diajukan_oleh_id'] ?? lemburData['pengawas_id'],
        'created_at': now,
      });

      await batch.commit();

      final pengawasId = lemburData['diajukan_oleh_id']?.toString() ?? lemburData['pengawas_id']?.toString();
      if (pengawasId != null && pengawasId.isNotEmpty) {
        _notifService.sendMitraCheckInNotification(
          mitraName: userName,
          lemburId: lemburId,
          pengawasId: pengawasId,
        );
      }

      logger.i('Check-in berhasil: $userName -> $lemburId');
    } catch (e) {
      logger.e('Gagal check-in: $e');
      rethrow;
    }
  }

  Future<double> checkOutLembur(String lemburId, String userName, Map<String, dynamic> overtimeSettings) async {
    // 🔥 CEK KONEKSI
    if (!_checkConnection('checkOutLembur')) {
      throw Exception('Tidak ada koneksi internet. Tidak dapat melakukan check-out.');
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('User tidak login');

    try {
      final lemburDoc = await _firestore.collection(collectionLemburMitra).doc(lemburId).get();
      if (!lemburDoc.exists) throw Exception('Data lembur tidak ditemukan');

      final lemburData = lemburDoc.data() ?? {};
      if (lemburData['mitra_id'] != user.uid) throw Exception('Bukan lembur milik Anda');
      if (_isExcluded(lemburData)) throw Exception('Lembur sudah dibatalkan atau ditolak');

      final checkInTimestamp = lemburData['absensi_waktu'];
      if (checkInTimestamp == null || checkInTimestamp is! Timestamp) {
        throw Exception('Belum check-in, tidak bisa check-out');
      }

      final checkInTime = checkInTimestamp.toDate();
      final checkOutTime = DateTime.now();
      if (checkOutTime.difference(checkInTime).inMinutes < 1) {
        throw Exception('Durasi lembur terlalu singkat');
      }

      final actualHours = checkOutTime.difference(checkInTime).inMinutes / 60.0;
      final isHoliday = (lemburData['jenis_lembur']?.toString() ?? '') == 'hari_libur';
      final income = calculateIncome(actualHours, settings: overtimeSettings, isHoliday: isHoliday);
      final now = FieldValue.serverTimestamp();
      final batch = _firestore.batch();

      batch.update(_firestore.collection(collectionLemburMitra).doc(lemburId), {
        'absensi_status': 'selesai',
        'absensi_checkout_waktu': now,
        'status': 'selesai',
        'completed_at': now,
        'actual_total_jam': actualHours,
        'actual_income': income,
        'income_amount': income,
        'is_income_calculated': true,
        'updated_at': now,
      });

      final absensiQuery = await _firestore
          .collection(collectionAbsensi)
          .where('lembur_id', isEqualTo: lemburId)
          .where('user_id', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (absensiQuery.docs.isNotEmpty) {
        batch.update(_firestore.collection(collectionAbsensi).doc(absensiQuery.docs.first.id), {
          'waktu_checkout': now,
          'actual_duration': (actualHours * 60).toInt(),
          'updated_at': now,
        });
      }

      await batch.commit();

      final pengawasId = lemburData['diajukan_oleh_id']?.toString() ?? lemburData['pengawas_id']?.toString();
      if (pengawasId != null && pengawasId.isNotEmpty) {
        _notifService.sendMitraCheckOutNotification(
          mitraName: userName,
          lemburId: lemburId,
          pengawasId: pengawasId,
          actualHours: actualHours,
          income: income,
        );
      }

      logger.i('Check-out berhasil: $userName -> $lemburId, jam=$actualHours, income=$income');
      return income;
    } catch (e) {
      logger.e('Gagal check-out: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ KONFIRMASI & REJECT
  // ═══════════════════════════════════════════════════════

  Future<void> confirmOvertime(String overtimeId) async {
    if (!_checkConnection('confirmOvertime')) {
      throw Exception('Tidak ada koneksi internet');
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('User tidak login');
    try {
      await _firestore.collection(collectionConfirmations).doc(user.uid).set({
        'confirmed_overtime_ids': FieldValue.arrayUnion([overtimeId]),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      logger.i('Konfirmasi berhasil: $overtimeId');
    } catch (e) {
      logger.e('Gagal konfirmasi: $e');
      rethrow;
    }
  }

  Future<void> rejectOvertime(String overtimeId, String? reason) async {
    if (!_checkConnection('rejectOvertime')) {
      throw Exception('Tidak ada koneksi internet');
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('User tidak login');
    try {
      final now = FieldValue.serverTimestamp();
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(collectionConfirmations).doc(user.uid),
        {
          'confirmed_overtime_ids': FieldValue.arrayUnion([overtimeId]),
          'rejected_overtime_ids': FieldValue.arrayUnion([overtimeId]),
          'rejection_reasons': {overtimeId: reason ?? 'Tidak ada alasan'},
          'updated_at': now,
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      _notifService.sendMitraRejectionNotification(
        mitraId: user.uid,
        overtimeId: overtimeId,
        reason: reason,
      );

      logger.i('Reject berhasil: $overtimeId, alasan: $reason');
    } catch (e) {
      logger.e('Gagal reject: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ NOTIFICATIONS & LOGOUT
  // ═══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getNotifications() async {
    if (!_checkConnection('getNotifications')) return [];
    final user = _auth.currentUser;
    if (user == null) return [];
    return _notifService.getNotificationsOnce(user.uid);
  }

  Future<void> markAllNotificationsRead() async {
    if (!_checkConnection('markAllNotificationsRead')) return;
    final user = _auth.currentUser;
    if (user == null) return;
    await _notifService.markAllAsRead(user.uid);
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      logger.i('Logout berhasil');
    } catch (e) {
      logger.e('Gagal logout: $e');
      rethrow;
    }
  }
}

// ═══════════════════════════════════════════════════════
// 📦 DATA CLASSES
// ═══════════════════════════════════════════════════════

class _BulanStats {
  final int totalLembur;
  final double totalJam;
  final int pending;
  final int disetujui;
  final int ditolak;
  final int selesai;
  final double totalIncome;
  final double sisaKuota;

  const _BulanStats({
    required this.totalLembur,
    required this.totalJam,
    required this.pending,
    required this.disetujui,
    required this.ditolak,
    required this.selesai,
    required this.totalIncome,
    required this.sisaKuota,
  });

  factory _BulanStats.empty() {
    return const _BulanStats(
      totalLembur: 0, totalJam: 0, pending: 0,
      disetujui: 0, ditolak: 0, selesai: 0,
      totalIncome: 0, sisaKuota: 60,
    );
  }
}

class MitraDashboardData {
  final Map<String, dynamic> userData;
  final String userName;
  final String fungsi;
  final Map<String, dynamic>? todayOvertime;
  final Map<String, dynamic>? todayAbsensi;
  final bool isCheckedIn;
  final bool isCheckedOut;
  final DateTime? lastCheckIn;
  final DateTime? lastCheckOut;
  final Duration? workDuration;
  final List<Map<String, dynamic>> allLembur;
  final List<Map<String, dynamic>> schedules;
  final List<Map<String, dynamic>> pendingRequests;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> overtimeSettings;
  final int unreadNotifications;
  final _BulanStats bulanStats;
  final _BulanStats bulanLaluStats;

  const MitraDashboardData({
    required this.userData, required this.userName, required this.fungsi,
    this.todayOvertime, this.todayAbsensi,
    required this.isCheckedIn, required this.isCheckedOut,
    this.lastCheckIn, this.lastCheckOut, this.workDuration,
    required this.allLembur, required this.schedules,
    required this.pendingRequests, required this.stats,
    required this.overtimeSettings, required this.unreadNotifications,
    required this.bulanStats, required this.bulanLaluStats,
  });

  bool get hasTodayOvertime => todayOvertime != null;
  bool get isLemburCheckedIn => todayOvertime?['absensi_status'] == 'check_in';
  bool get isLemburCheckedOut =>
      todayOvertime?['absensi_status'] == 'check_out' ||
      todayOvertime?['absensi_status'] == 'selesai';

  int get totalLemburStat => bulanStats.totalLembur;
  int get totalJamStat => bulanStats.totalJam.toInt();
  int get sisaKuotaStat => bulanStats.sisaKuota.toInt();
  int get pendingStat => bulanStats.pending;
  int get disetujuiStat => bulanStats.disetujui;
  int get ditolakStat => bulanStats.ditolak;
  int get selesaiStat => bulanStats.selesai;
  double get totalIncomeStat => bulanStats.totalIncome;
  
  double get trendLembur => (stats['trendLembur'] as num?)?.toDouble() ?? 0.0;
  double get trendJam => (stats['trendJam'] as num?)?.toDouble() ?? 0.0;
  double get trendIncome => (stats['trendIncome'] as num?)?.toDouble() ?? 0.0;

  String get workDurationFormatted {
    if (workDuration == null) return '-';
    final hours = workDuration!.inHours;
    final minutes = workDuration!.inMinutes.remainder(60);
    if (hours > 0) return '$hours jam $minutes mnt';
    return '$minutes mnt';
  }
}

class _AbsensiResult {
  final Map<String, dynamic>? doc;
  final bool isCheckedIn;
  final bool isCheckedOut;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final Duration? workDuration;

  const _AbsensiResult({
    this.doc, required this.isCheckedIn, required this.isCheckedOut,
    this.checkInTime, this.checkOutTime, this.workDuration,
  });

  factory _AbsensiResult.empty() {
    return const _AbsensiResult(
      doc: null, isCheckedIn: false, isCheckedOut: false,
      checkInTime: null, checkOutTime: null, workDuration: null,
    );
  }
}

class _AdditionalData {
  final int unreadCount;
  final Map<String, dynamic> settings;

  const _AdditionalData({required this.unreadCount, required this.settings});
}