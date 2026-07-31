import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_absensi_service.dart';
import '/core/services/network_service.dart'; // 🔥 NETWORK SERVICE

var _logger = Logger(printer: PrettyPrinter());

// CACHE ENTRY

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  _CacheEntry({required this.data, required this.timestamp});
}

// ═══════════════════════════════════════════════════════════════
// SERVICE
// ═══════════════════════════════════════════════════════════════

class AbsensiHistoryService {
  static final AbsensiHistoryService _instance = AbsensiHistoryService._internal();
  factory AbsensiHistoryService() => _instance;
  AbsensiHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OvertimeHistoryService _historyService = OvertimeHistoryService();
  final OvertimeAbsensiService _absensiService = OvertimeAbsensiService();
  
  // 🔥 NETWORK SERVICE (SINGLETON)
  final NetworkService _networkService = NetworkService();

  // ═══════════════════════════════════════════════════════════
  // CONSTANTS
  // ═══════════════════════════════════════════════════════════

  static const String _collectionLembur = 'lembur_mitra';
  static const String _collectionAbsensi = 'absensi';
  static const int _maxPageSize = 100;

  // 🔥🔥🔥 HANYA STATUS YANG DISETUJUI / APPROVED
  static const List<String> _approvedStatuses = [
    'disetujui',
    'approved',
    'selesai',
    'completed',
  ];

  // ═══════════════════════════════════════════════════════════
  // 🔥 HELPER: Cek koneksi sebelum operasi
  // ═══════════════════════════════════════════════════════════

  bool _checkConnection(String operationName) {
    if (!_networkService.isOnline) {
      _logger.w('⚠️ [$operationName] Dibatalkan - Tidak ada koneksi internet');
      return false;
    }
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 HELPER: Cek dibatalkan (client-side safety net)
  // ═══════════════════════════════════════════════════════════

  bool _isDibatalkan(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    return status == 'dibatalkan';
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 HELPER: Cek apakah lembur sudah DISETUJUI
  // ═══════════════════════════════════════════════════════════

  bool _isApproved(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    return _approvedStatuses.contains(status);
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 HELPER: Cek apakah absensi sudah SELESAI
  // ═══════════════════════════════════════════════════════════

  bool _isAbsensiSelesai(String? absensiStatus) {
    return absensiStatus == 'selesai' || absensiStatus == 'selesai_terlambat';
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 HELPER: Cek status pembayaran
  // ═══════════════════════════════════════════════════════════

  bool _checkIsPaid(Map<String, dynamic> data) {
    if (data['is_paid'] == true) return true;

    final statusBayar = data['status_bayar']?.toString().toLowerCase();
    if (statusBayar == 'dibayar' ||
        statusBayar == 'sudah_dibayar' ||
        statusBayar == 'lunas' ||
        statusBayar == 'paid') {
      return true;
    }

    final statusPembayaran = data['status_pembayaran']?.toString().toLowerCase();
    if (statusPembayaran == 'lunas' ||
        statusPembayaran == 'dibayar' ||
        statusPembayaran == 'sudah_dibayar' ||
        statusPembayaran == 'paid') {
      return true;
    }

    final paymentStatus = data['payment_status']?.toString().toLowerCase();
    if (paymentStatus == 'paid' ||
        paymentStatus == 'completed' ||
        paymentStatus == 'lunas' ||
        paymentStatus == 'dibayar') {
      return true;
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════
  // CACHE MANAGEMENT
  // ═══════════════════════════════════════════════════════════

  final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  void _setCache(String key, dynamic data) {
    _cache[key] = _CacheEntry(data: data, timestamp: DateTime.now());
  }

  dynamic _getCache(String key) {
    final entry = _cache[key];
    if (entry != null && DateTime.now().difference(entry.timestamp) < _cacheDuration) {
      return entry.data;
    }
    _cache.remove(key);
    return null;
  }

  void clearCache({String? userId}) {
    if (userId != null) {
      _cache.removeWhere((key, _) => key.contains(userId));
    } else {
      _cache.clear();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 PRIVATE: Build base query for a user
  // ═══════════════════════════════════════════════════════════

  Query<Map<String, dynamic>> _baseUserQuery(String userId) {
    return _firestore.collection(_collectionLembur).where(
      Filter.or(
        Filter('mitra_id', isEqualTo: userId),
        Filter('mitra_ids', arrayContains: userId),
      ),
    ).where('status', whereIn: _approvedStatuses);
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 PRIVATE: Parse double safely
  // ═══════════════════════════════════════════════════════════

  double _parseDoubleSafe(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  // ═══════════════════════════════════════════════════════════
  // CORE: GET HISTORY RECORDS - HANYA YANG DISETUJUI
  // ═══════════════════════════════════════════════════════════

  Future<AbsensiHistoryResult> getHistory({
    required String userId,
    String? bulan,
    String? statusFilter,
    String? statusBayarFilter,
    DateTime? tanggalMulai,
    DateTime? tanggalAkhir,
    int page = 1,
    int pageSize = 20,
    String sortBy = 'tanggal',
    bool sortDescending = true,
    bool useCache = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 🔥 CEK KONEKSI SEBELUM PROSES
      if (!_checkConnection('getHistory')) {
        return AbsensiHistoryResult.empty(
          error: 'Tidak ada koneksi internet. Periksa koneksi Anda.'
        );
      }

      pageSize = pageSize.clamp(1, _maxPageSize);

      final cacheKey = 'history_${userId}_${bulan}_${statusFilter}_${statusBayarFilter}_'
          '${tanggalMulai?.toIso8601String()}_${tanggalAkhir?.toIso8601String()}_'
          '${page}_${pageSize}_${sortBy}_${sortDescending}';

      if (useCache) {
        final cached = _getCache(cacheKey);
        if (cached is AbsensiHistoryResult) {
          _logger.i('✅ History loaded from cache in ${stopwatch.elapsedMilliseconds}ms');
          return cached;
        }
      }

      // 🔥 Base query dengan filter approved
      Query<Map<String, dynamic>> query = _baseUserQuery(userId);

      query = _applyFilters(
        query,
        bulan: bulan,
        statusFilter: statusFilter,
        tanggalMulai: tanggalMulai,
        tanggalAkhir: tanggalAkhir,
      );

      // 🔥 Count total
      final countSnapshot = await query.count().get();
      int totalCount = countSnapshot.count ?? 0;

      // 🔥 Sort & paginate
      query = query.orderBy(sortBy, descending: sortDescending);
      query = query.limit(pageSize);

      if (page > 1) {
        Query<Map<String, dynamic>> previousQuery = _baseUserQuery(userId);

        previousQuery = _applyFilters(
          previousQuery,
          bulan: bulan,
          statusFilter: statusFilter,
          tanggalMulai: tanggalMulai,
          tanggalAkhir: tanggalAkhir,
        );

        previousQuery = previousQuery
            .orderBy(sortBy, descending: sortDescending)
            .limit((page - 1) * pageSize);

        final previousSnapshot = await previousQuery.get();
        if (previousSnapshot.docs.isNotEmpty) {
          final lastDoc = previousSnapshot.docs.last;
          query = query.startAfterDocument(lastDoc);
        }
      }

      final snapshot = await query.get();

      // 🔥 Filter client-side: DIBATALKAN + status bayar
      final List<AbsensiHistoryItem> items = snapshot.docs
          .where((doc) => !_isDibatalkan(doc.data()))
          .where((doc) {
            if (statusBayarFilter == 'dibayar') {
              return _checkIsPaid(doc.data());
            } else if (statusBayarFilter == 'belum_dibayar') {
              return !_checkIsPaid(doc.data());
            }
            return true;
          })
          .map((doc) {
            final rawData = doc.data();
            final overtimeHistory = OvertimeHistory.fromFirestore(doc);
            return AbsensiHistoryItem.fromOvertimeHistory(overtimeHistory, rawData: rawData);
          })
          .toList();

      final totalPages = totalCount > 0 ? (totalCount / pageSize).ceil() : 0;
      final hasMore = page < totalPages;

      final result = AbsensiHistoryResult(
        items: items,
        totalCount: totalCount,
        currentPage: page,
        totalPages: totalPages,
        hasMore: hasMore,
        pageSize: pageSize,
        queryTime: stopwatch.elapsedMilliseconds,
      );

      _setCache(cacheKey, result);

      _logger.i('✅ getHistory completed in ${stopwatch.elapsedMilliseconds}ms | '
          'Items: ${items.length} | Total: $totalCount | Page: $page/$totalPages');

      return result;
    } catch (e) {
      _logger.e('❌ Error getHistory: $e');
      
      // 🔥 Cek apakah error karena koneksi
      if (!_networkService.isOnline) {
        return AbsensiHistoryResult.empty(
          error: 'Koneksi internet terputus. Silakan coba lagi.'
        );
      }
      
      return AbsensiHistoryResult.empty(error: e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 GET HISTORY WITH RETRY (NEW!)
  // ═══════════════════════════════════════════════════════════

  Future<AbsensiHistoryResult> getHistoryWithRetry({
    required String userId,
    String? bulan,
    String? statusFilter,
    String? statusBayarFilter,
    DateTime? tanggalMulai,
    DateTime? tanggalAkhir,
    int page = 1,
    int pageSize = 20,
    String sortBy = 'tanggal',
    bool sortDescending = true,
    int maxRetries = 3,
  }) async {
    return await _networkService.retryOnConnectionError(
      operation: () => getHistory(
        userId: userId,
        bulan: bulan,
        statusFilter: statusFilter,
        statusBayarFilter: statusBayarFilter,
        tanggalMulai: tanggalMulai,
        tanggalAkhir: tanggalAkhir,
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        sortDescending: sortDescending,
        useCache: false,
      ),
      maxRetries: maxRetries,
      delay: const Duration(seconds: 2),
    ) ?? AbsensiHistoryResult.empty(
      error: 'Gagal terhubung setelah $maxRetries kali percobaan'
    );
  }

  // ═══════════════════════════════════════════════════════════
  // GET HISTORY BY DATE RANGE
  // ═══════════════════════════════════════════════════════════

  Future<List<AbsensiHistoryItem>> getHistoryByDateRange({
    required String userId,
    required DateTime tanggalMulai,
    required DateTime tanggalAkhir,
    String? statusFilter,
  }) async {
    try {
      if (!_checkConnection('getHistoryByDateRange')) return [];
      
      final result = await getHistory(
        userId: userId,
        tanggalMulai: tanggalMulai,
        tanggalAkhir: tanggalAkhir,
        statusFilter: statusFilter,
        pageSize: _maxPageSize,
        useCache: false,
      );
      return result.items;
    } catch (e) {
      _logger.e('❌ Error getHistoryByDateRange: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GET SINGLE HISTORY ITEM
  // ═══════════════════════════════════════════════════════════

  Future<AbsensiHistoryItem?> getHistoryItem(String docId) async {
    try {
      if (!_checkConnection('getHistoryItem')) return null;
      
      final overtimeHistory = await _historyService.getOvertimeById(docId);
      if (overtimeHistory == null) return null;
      if (overtimeHistory.status == 'dibatalkan') return null;
      // 🔥 HANYA YANG DISETUJUI
      if (!_approvedStatuses.contains(overtimeHistory.status.toLowerCase())) return null;
      return AbsensiHistoryItem.fromOvertimeHistory(overtimeHistory);
    } catch (e) {
      _logger.e('❌ Error getHistoryItem: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 GET SUMMARY - HANYA YANG DISETUJUI
  // ═══════════════════════════════════════════════════════════

  Future<AbsensiHistorySummary> getSummary({
    required String userId,
    String? bulan,
    DateTime? tanggalMulai,
    DateTime? tanggalAkhir,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 🔥 CEK KONEKSI
      if (!_checkConnection('getSummary')) {
        return AbsensiHistorySummary.empty();
      }

      // 🔥 Base query dengan filter approved
      Query<Map<String, dynamic>> query = _baseUserQuery(userId);

      query = _applyFilters(query, bulan: bulan, tanggalMulai: tanggalMulai, tanggalAkhir: tanggalAkhir);

      final snapshot = await query.get();

      int totalLembur = 0, totalHadir = 0, totalTerlambat = 0, totalTidakHadir = 0;
      int totalExpired = 0, totalBelum = 0, totalCheckIn = 0, totalSudahAbsen = 0;
      
      double totalJam = 0, totalPendapatan = 0, totalDibayar = 0, totalBelumDibayar = 0;
      int totalPaid = 0, totalUnpaid = 0;
      double maxJam = 0, minJam = double.infinity;
      int jamCount = 0;
      
      DateTime? earliestTanggal, latestTanggal;
      Map<String, int> statusDistribution = {};
      Map<String, int> dailyDistribution = {};
      Map<String, double> hourlyDistribution = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // 🔥 Skip dibatalkan (safety net)
        if (_isDibatalkan(data)) continue;

        totalLembur++;

        final absensiStatus = data['absensi_status']?.toString() ?? 'belum_absen';
        statusDistribution[absensiStatus] = (statusDistribution[absensiStatus] ?? 0) + 1;

        switch (absensiStatus) {
          case 'selesai':
            totalHadir++;
            break;
          case 'selesai_terlambat':
            totalHadir++;
            totalTerlambat++;
            break;
          case 'tidak_lembur':
            totalTidakHadir++;
            break;
          case 'expired':
            totalExpired++;
            break;
          case 'check_in':
            totalCheckIn++;
            totalBelum++;
            break;
          case 'sudah_absen':
            totalSudahAbsen++;
            totalBelum++;
            break;
          case 'belum_absen':
            totalBelum++;
            break;
        }

        // ═══════════════════════════════════════════════
        // 🔥 HANYA JIKA ABSENSI SUDAH SELESAI
        // ═══════════════════════════════════════════════
        final bool isSelesai = _isAbsensiSelesai(absensiStatus);

        // ─── TOTAL JAM (HANYA JIKA SELESAI) ───
        if (isSelesai) {
          double jam = _parseDoubleSafe(
            data['total_jam_desimal'] ??
                data['total_jam_real'] ??
                data['actual_total_jam'] ??
                0,
          );

          if (jam > 0) {
            totalJam += jam;
            if (jam > maxJam) maxJam = jam;
            if (jam < minJam) minJam = jam;
            jamCount++;
          }
        }

        // ─── PENDAPATAN (HANYA JIKA SELESAI) ───
        double pendapatan = 0;
        if (isSelesai) {
          pendapatan = _parseDoubleSafe(
            data['actual_income'] ??
                data['income'] ??
                data['income_amount'] ??
                data['pendapatan_actual'] ??
                data['estimasi_biaya_per_mitra'] ??
                data['estimasi_biaya'] ??
                0,
          );
        }
        totalPendapatan += pendapatan;

        // ─── PEMBAYARAN (HANYA JIKA SELESAI) ───
        bool isPaid = false;
        if (isSelesai) {
          isPaid = _checkIsPaid(data);
        }

        if (isPaid) {
          totalPaid++;
          totalDibayar += pendapatan;
        } else if (isSelesai && pendapatan > 0) {
          totalUnpaid++;
          totalBelumDibayar += pendapatan;
        }

        // ─── TANGGAL ───
        DateTime tanggal;
        final tgl = data['tanggal'] ?? data['tanggal_lembur'];
        if (tgl is Timestamp) {
          tanggal = tgl.toDate();
        } else if (tgl is DateTime) {
          tanggal = tgl;
        } else {
          continue;
        }

        if (earliestTanggal == null || tanggal.isBefore(earliestTanggal)) {
          earliestTanggal = tanggal;
        }
        if (latestTanggal == null || tanggal.isAfter(latestTanggal)) {
          latestTanggal = tanggal;
        }

        final dayKey = DateFormat('EEEE', 'id_ID').format(tanggal);
        dailyDistribution[dayKey] = (dailyDistribution[dayKey] ?? 0) + 1;

        final jamMulai = data['jam_mulai']?.toString() ?? '00:00';
        final hourKey = jamMulai.split(':').first;
        hourlyDistribution[hourKey] = (hourlyDistribution[hourKey] ?? 0) + 1;
      }

      // ─── KALKULASI FINAL ───
      final double avgJam = jamCount > 0 ? totalJam / jamCount : 0;
      final double avgPendapatan = totalLembur > 0 ? totalPendapatan / totalLembur : 0;
      final double persentaseHadir = totalLembur > 0 ? (totalHadir / totalLembur) * 100 : 0;
      final double persentaseTerlambat = totalHadir > 0 ? (totalTerlambat / totalHadir) * 100 : 0;
      final double persentasePaid = totalLembur > 0 ? (totalPaid / totalLembur) * 100 : 0;

      final summary = AbsensiHistorySummary(
        totalLembur: totalLembur,
        totalHadir: totalHadir,
        totalTerlambat: totalTerlambat,
        totalTidakHadir: totalTidakHadir,
        totalExpired: totalExpired,
        totalBelum: totalBelum,
        totalCheckIn: totalCheckIn,
        totalSudahAbsen: totalSudahAbsen,
        totalJam: totalJam,
        totalPendapatan: totalPendapatan,
        totalDibayar: totalDibayar,
        totalBelumDibayar: totalBelumDibayar,
        totalPaid: totalPaid,
        totalUnpaid: totalUnpaid,
        avgJam: avgJam,
        maxJam: maxJam < double.infinity ? maxJam : 0,
        minJam: minJam < double.infinity ? minJam : 0,
        avgPendapatan: avgPendapatan,
        persentaseHadir: persentaseHadir,
        persentaseTerlambat: persentaseTerlambat,
        persentasePaid: persentasePaid,
        earliestTanggal: earliestTanggal,
        latestTanggal: latestTanggal,
        statusDistribution: statusDistribution,
        dailyDistribution: dailyDistribution,
        hourlyDistribution: hourlyDistribution,
        totalDays: dailyDistribution.length,
        totalHours: hourlyDistribution.length,
      );

      _logger.i('✅ getSummary completed in ${stopwatch.elapsedMilliseconds}ms | '
          'Total: $totalLembur | Jam: ${totalJam.toStringAsFixed(1)} | '
          'Pendapatan: $totalPendapatan');

      return summary;
    } catch (e) {
      _logger.e('❌ Error getSummary: $e');
      
      // 🔥 Cek koneksi saat error
      if (!_networkService.isOnline) {
        _logger.w('⚠️ getSummary failed: No internet connection');
      }
      
      return AbsensiHistorySummary.empty();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GET MONTHLY STATISTICS
  // ═══════════════════════════════════════════════════════════

  Future<List<MonthlyStatistic>> getMonthlyStatistics({
    required String userId,
    int? year,
    bool includeAllMonths = true,
  }) async {
    try {
      if (!_checkConnection('getMonthlyStatistics')) return [];
      
      final targetYear = year ?? DateTime.now().year;
      List<MonthlyStatistic> statistics = [];
      for (int month = 1; month <= 12; month++) {
        final bulanKey = '$targetYear-${month.toString().padLeft(2, '0')}';
        final summary = await getSummary(userId: userId, bulan: bulanKey);
        if (includeAllMonths || summary.totalLembur > 0) {
          statistics.add(MonthlyStatistic(
            tahun: targetYear,
            bulan: month,
            bulanKey: bulanKey,
            bulanNama: DateFormat('MMMM', 'id_ID').format(DateTime(targetYear, month)),
            summary: summary,
          ));
        }
      }
      return statistics;
    } catch (e) {
      _logger.e('❌ Error getMonthlyStatistics: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GET YEARLY STATISTICS
  // ═══════════════════════════════════════════════════════════

  Future<YearlyStatistic> getYearlyStatistics({required String userId, int? year}) async {
    try {
      if (!_checkConnection('getYearlyStatistics')) {
        return YearlyStatistic.empty();
      }
      
      final targetYear = year ?? DateTime.now().year;
      final monthlyStats = await getMonthlyStatistics(
        userId: userId,
        year: targetYear,
        includeAllMonths: true,
      );
      int totalLembur = 0, totalHadir = 0;
      double totalJam = 0, totalPendapatan = 0, totalDibayar = 0;
      for (var stat in monthlyStats) {
        totalLembur += stat.summary.totalLembur;
        totalHadir += stat.summary.totalHadir;
        totalJam += stat.summary.totalJam;
        totalPendapatan += stat.summary.totalPendapatan;
        totalDibayar += stat.summary.totalDibayar;
      }
      return YearlyStatistic(
        tahun: targetYear,
        totalLembur: totalLembur,
        totalHadir: totalHadir,
        totalJam: totalJam,
        totalPendapatan: totalPendapatan,
        totalDibayar: totalDibayar,
        rataRataPerBulan: monthlyStats.isNotEmpty ? totalLembur / monthlyStats.length : 0,
        monthlyStats: monthlyStats,
      );
    } catch (e) {
      _logger.e('❌ Error getYearlyStatistics: $e');
      return YearlyStatistic.empty();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 REAL-TIME HISTORY LISTENER - HANYA YANG DISETUJUI
  // ═══════════════════════════════════════════════════════════

  Stream<List<AbsensiHistoryItem>> streamHistory({
    required String userId,
    String? bulan,
    String? statusFilter,
    String? statusLemburFilter,
    int limit = 20,
  }) {
    // 🔥 Base query dengan filter approved
    Query<Map<String, dynamic>> query = _baseUserQuery(userId);

    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter != 'semua') {
      query = query.where('absensi_status', isEqualTo: statusFilter);
    }
    if (statusLemburFilter != null &&
        statusLemburFilter != 'semua' &&
        _approvedStatuses.contains(statusLemburFilter)) {
      query = query.where('status', isEqualTo: statusLemburFilter);
    }

    return query.orderBy('tanggal', descending: true).limit(limit).snapshots().map(
      (snapshot) => snapshot.docs
          .where((doc) => !_isDibatalkan(doc.data()))
          .map((doc) {
            final rawData = doc.data();
            final overtimeHistory = OvertimeHistory.fromFirestore(doc);
            return AbsensiHistoryItem.fromOvertimeHistory(overtimeHistory, rawData: rawData);
          })
          .toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔥 GET ABSENSI BY SPECIFIC STATUS - HANYA YANG DISETUJUI
  // ═══════════════════════════════════════════════════════════

  Future<List<AbsensiHistoryItem>> getAbsensiByStatus({
    required String userId,
    required List<String> statusList,
    String? bulan,
    int? limit,
  }) async {
    try {
      if (!_checkConnection('getAbsensiByStatus')) return [];
      
      Query<Map<String, dynamic>> query = _baseUserQuery(userId);

      query = query.where('absensi_status', whereIn: statusList);

      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }
      query = query.orderBy('tanggal', descending: true);
      if (limit != null) query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .where((doc) => !_isDibatalkan(doc.data()))
          .map((doc) {
            final rawData = doc.data();
            final overtimeHistory = OvertimeHistory.fromFirestore(doc);
            return AbsensiHistoryItem.fromOvertimeHistory(overtimeHistory, rawData: rawData);
          })
          .toList();
    } catch (e) {
      _logger.e('❌ Error getAbsensiByStatus: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GET PENDING / COMPLETED / TODAY ABSENSI
  // ═══════════════════════════════════════════════════════════

  Future<List<AbsensiHistoryItem>> getPendingAbsensi({
    required String userId,
    String? bulan,
  }) async {
    return getAbsensiByStatus(
      userId: userId,
      statusList: ['belum_absen', 'check_in', 'sudah_absen'],
      bulan: bulan,
    );
  }

  Future<List<AbsensiHistoryItem>> getCompletedAbsensi({
    required String userId,
    String? bulan,
    int? limit,
  }) async {
    return getAbsensiByStatus(
      userId: userId,
      statusList: ['selesai', 'selesai_terlambat'],
      bulan: bulan,
      limit: limit,
    );
  }

  Future<AbsensiHistoryItem?> getTodayAbsensi(String userId) async {
    try {
      if (!_checkConnection('getTodayAbsensi')) return null;
      
      final todayOvertime = await _absensiService.getTodayOvertimeForAbsensi(userId);
      if (todayOvertime != null) {
        if (todayOvertime.status == 'dibatalkan') return null;
        if (!_approvedStatuses.contains(todayOvertime.status.toLowerCase())) return null;
        return AbsensiHistoryItem.fromOvertimeHistory(todayOvertime);
      }
      return null;
    } catch (e) {
      _logger.e('❌ Error getTodayAbsensi: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GET ABSENSI DETAIL WITH HISTORY
  // ═══════════════════════════════════════════════════════════

  Future<AbsensiDetail> getAbsensiDetail(String docId) async {
    try {
      if (!_checkConnection('getAbsensiDetail')) return AbsensiDetail.empty();
      
      final historyItem = await getHistoryItem(docId);
      if (historyItem == null) return AbsensiDetail.empty();

      final absensiSnapshot = await _firestore
          .collection(_collectionAbsensi)
          .where('lembur_id', isEqualTo: docId)
          .orderBy('waktu', descending: false)
          .get();

      final absensiLogs = absensiSnapshot.docs
          .map((doc) => OvertimeAbsensi.fromFirestore(doc))
          .toList();
      final tenggatInfo = await _absensiService.getTenggatInfo(docId);

      return AbsensiDetail(
        historyItem: historyItem,
        absensiLogs: absensiLogs,
        tenggatInfo: tenggatInfo,
        totalLogs: absensiLogs.length,
        hasCheckIn: absensiLogs.any((log) => log.jenis == 'check_in'),
        hasCheckOut: absensiLogs.any((log) => log.jenis == 'check_out'),
      );
    } catch (e) {
      _logger.e('❌ Error getAbsensiDetail: $e');
      return AbsensiDetail.empty();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // EXPORT-READY DATA
  // ═══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getExportData({
    required String userId,
    String? bulan,
    DateTime? tanggalMulai,
    DateTime? tanggalAkhir,
  }) async {
    try {
      if (!_checkConnection('getExportData')) return [];
      
      final result = await getHistory(
        userId: userId,
        bulan: bulan,
        tanggalMulai: tanggalMulai,
        tanggalAkhir: tanggalAkhir,
        pageSize: _maxPageSize,
        useCache: false,
      );
      return result.items.map((item) => item.toExportMap()).toList();
    } catch (e) {
      _logger.e('❌ Error getExportData: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GET AVAILABLE BULAN LIST
  // ═══════════════════════════════════════════════════════════

  Future<List<String>> getAvailableBulan({required String userId}) async {
    try {
      if (!_checkConnection('getAvailableBulan')) return [];
      
      final result = await getHistory(userId: userId, pageSize: _maxPageSize);
      final bulanSet = <String>{};
      for (var item in result.items) {
        bulanSet.add(DateFormat('yyyy-MM').format(item.tanggal));
      }
      final sortedList = bulanSet.toList()..sort((a, b) => b.compareTo(a));
      return sortedList;
    } catch (e) {
      _logger.e('❌ Error getAvailableBulan: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════

  Query<Map<String, dynamic>> _applyFilters(
    Query<Map<String, dynamic>> query, {
    String? bulan,
    String? statusFilter,
    DateTime? tanggalMulai,
    DateTime? tanggalAkhir,
  }) {
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter != 'semua') {
      query = query.where('absensi_status', isEqualTo: statusFilter);
    }
    if (tanggalMulai != null) {
      query = query.where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(tanggalMulai));
    }
    if (tanggalAkhir != null) {
      query = query.where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(tanggalAkhir));
    }
    return query;
  }
}

// ═══════════════════════════════════════════════════════════════
// MODEL: AbsensiHistoryResult (Pagination)
// ═══════════════════════════════════════════════════════════════

class AbsensiHistoryResult {
  final List<AbsensiHistoryItem> items;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final bool hasMore;
  final int pageSize;
  final int queryTime;
  final String? error;

  AbsensiHistoryResult({
    required this.items,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasMore,
    required this.pageSize,
    required this.queryTime,
    this.error,
  });

  factory AbsensiHistoryResult.empty({String? error}) => AbsensiHistoryResult(
        items: [],
        totalCount: 0,
        currentPage: 1,
        totalPages: 0,
        hasMore: false,
        pageSize: 20,
        queryTime: 0,
        error: error,
      );

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get hasError => error != null && error!.isNotEmpty;
}

// ═══════════════════════════════════════════════════════════════
// MODEL: AbsensiHistoryItem V5 — DENGAN TAMPILAN DINAMIS
// ═══════════════════════════════════════════════════════════════

class AbsensiHistoryItem {
  final String id;
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final String absensiStatus;
  final String absensiLabel;
  final String? statusLembur;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? checkInFotoUrl;
  final String? checkOutFotoUrl;
  final double pendapatan;
  final bool isPaid;
  final double totalJam;
  final String? mitraId;
  final String? mitraNama;
  final String? lokasi;
  final String? catatan;
  final String? tahunBulan;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? absensiKeterlambatan;

  // 🔥🔥🔥 FIELD BARU V5
  final DateTime? confirmedAt;
  final String? alasanTidakLembur;

  final OvertimeHistory _overtimeHistory;

  AbsensiHistoryItem._({
    required this.id,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.absensiStatus,
    required this.absensiLabel,
    this.statusLembur,
    this.checkInTime,
    this.checkOutTime,
    this.checkInFotoUrl,
    this.checkOutFotoUrl,
    required this.pendapatan,
    required this.isPaid,
    required this.totalJam,
    this.mitraId,
    this.mitraNama,
    this.lokasi,
    this.catatan,
    this.tahunBulan,
    this.createdAt,
    this.updatedAt,
    this.absensiKeterlambatan,
    this.confirmedAt,
    this.alasanTidakLembur,
    required OvertimeHistory overtimeHistory,
  }) : _overtimeHistory = overtimeHistory;

  factory AbsensiHistoryItem.fromOvertimeHistory(
    OvertimeHistory history, {
    Map<String, dynamic>? rawData,
  }) {
    Map<String, dynamic>? data = rawData;
    if (data == null) {
      try {
        data = (history as dynamic).rawData as Map<String, dynamic>?;
      } catch (_) {
        data = null;
      }
    }

    final absensiStatusValue = data?['absensi_status']?.toString() ??
        history.absensiStatus ??
        'belum_absen';

    final absensiLabelValue = history.absensiStatusLabel ??
        absensiStatusValue.absensiLabel;

    final absensiKeterlambatanValue = data?['absensi_keterlambatan'] is Map
        ? data!['absensi_keterlambatan'] as Map<String, dynamic>
        : null;

    DateTime? checkInTime = history.checkInTime;
    if (checkInTime == null && data != null) {
      final raw = data['check_in_time'] ?? data['check_in_waktu'] ?? data['check_in'];
      if (raw is Timestamp) {
        checkInTime = raw.toDate();
      } else if (raw is String && raw.isNotEmpty) {
        checkInTime = DateTime.tryParse(raw);
      }
    }

    DateTime? checkOutTime = history.checkOutTime;
    if (checkOutTime == null && data != null) {
      final raw = data['check_out_time'] ?? data['check_out_waktu'] ?? data['check_out'];
      if (raw is Timestamp) {
        checkOutTime = raw.toDate();
      } else if (raw is String && raw.isNotEmpty) {
        checkOutTime = DateTime.tryParse(raw);
      }
    }

    String? checkInFotoUrl = history.checkInFotoUrl;
    if ((checkInFotoUrl == null || checkInFotoUrl.isEmpty) && data != null) {
      checkInFotoUrl = data['check_in_foto_url'] ??
          data['check_in_foto'] ??
          data['absensi_foto_url'] ??
          data['foto_check_in'] ??
          data['foto_absensi'];
    }

    String? checkOutFotoUrl = history.checkOutFotoUrl;
    if ((checkOutFotoUrl == null || checkOutFotoUrl.isEmpty) && data != null) {
      checkOutFotoUrl = data['check_out_foto_url'] ??
          data['check_out_foto'] ??
          data['foto_check_out'];
    }

    bool isPaidValue = false;
    if (data != null) {
      isPaidValue = data['is_paid'] == true ||
          data['status_bayar'] == 'dibayar' ||
          data['status_bayar'] == 'sudah_dibayar' ||
          data['status_pembayaran'] == 'lunas';
    }

    double _parseSafe(dynamic val) {
      if (val == null) return 0.0;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final pendapatan = _parseSafe(
      data?['actual_income'] ??
          data?['income'] ??
          data?['income_amount'] ??
          data?['pendapatan_actual'] ??
          history.estimasiBiayaPerMitra ??
          0,
    );

    final totalJam = _parseSafe(
      data?['total_jam_desimal'] ??
          data?['total_jam_real'] ??
          data?['actual_total_jam'] ??
          history.totalJam ??
          0,
    );

    String? lokasiStr;
    try {
      final lokasiMap = data?['lokasi'] ?? history.lokasi;
      if (lokasiMap is Map) {
        lokasiStr = (lokasiMap['nama'] ?? lokasiMap['alamat'] ?? lokasiMap['name'])?.toString();
      }
    } catch (_) {
      lokasiStr = null;
    }

    // 🔥 PARSE confirmedAt & alasanTidakLembur
    DateTime? confirmedAt;
    String? alasanTidakLembur;

    if (data?['absensi_keterlambatan'] is Map) {
      final map = data!['absensi_keterlambatan'] as Map;
      final isTidakLembur = map['melakukan_lembur'] == false;
      if (isTidakLembur) {
        alasanTidakLembur = map['alasan']?.toString();
      }
      if (map['confirmed_at'] != null) {
        final raw = map['confirmed_at'];
        if (raw is Timestamp) {
          confirmedAt = raw.toDate();
        } else if (raw is DateTime) {
          confirmedAt = raw;
        } else if (raw is String && raw.isNotEmpty) {
          confirmedAt = DateTime.tryParse(raw);
        }
      }
    }

    alasanTidakLembur ??= data?['alasan_tidak_lembur']?.toString();
    if (confirmedAt == null && data != null) {
      final raw = data!['confirmed_at'] ?? data['tidak_lembur_at'] ?? data['check_out_time'];
      if (raw is Timestamp) {
        confirmedAt = raw.toDate();
      } else if (raw is DateTime) {
        confirmedAt = raw;
      } else if (raw is String && raw.isNotEmpty) {
        confirmedAt = DateTime.tryParse(raw);
      }
    }

    return AbsensiHistoryItem._(
      id: history.id,
      tanggal: history.tanggal,
      jamMulai: history.jamMulai,
      jamSelesai: history.jamSelesai,
      absensiStatus: absensiStatusValue,
      absensiLabel: absensiLabelValue,
      statusLembur: history.status,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      checkInFotoUrl: checkInFotoUrl,
      checkOutFotoUrl: checkOutFotoUrl,
      pendapatan: pendapatan,
      isPaid: isPaidValue,
      totalJam: totalJam,
      mitraId: history.mitraId,
      mitraNama: history.namaMitra,
      lokasi: lokasiStr,
      catatan: history.catatanTambahan ?? data?['catatan']?.toString(),
      tahunBulan: history.tahunBulan ?? data?['tahun_bulan']?.toString(),
      createdAt: history.createdAt,
      updatedAt: history.updatedAt,
      absensiKeterlambatan: absensiKeterlambatanValue,
      confirmedAt: confirmedAt,
      alasanTidakLembur: alasanTidakLembur,
      overtimeHistory: history,
    );
  }

  OvertimeHistory get overtimeHistory => _overtimeHistory;

  // ═══════════════════════════════════════════════════════════
  // STATUS OPTIONS (STATIC)
  // ═══════════════════════════════════════════════════════════

  static List<Map<String, dynamic>> getStatusOptions() {
    return [
      {'value': 'semua', 'label': '📋 Semua Status', 'color': Colors.grey},
      {'value': 'belum_absen', 'label': '⏳ Belum Absen', 'color': Colors.blue},
      {'value': 'check_in', 'label': '📥 Check In', 'color': Colors.cyan},
      {'value': 'selesai', 'label': '✅ Selesai', 'color': Colors.green},
      {'value': 'selesai_terlambat', 'label': '⚠️ Terlambat', 'color': Colors.orange},
      {'value': 'tidak_lembur', 'label': '❌ Tidak Lembur', 'color': Colors.red},
      {'value': 'expired', 'label': '⏰ Expired', 'color': Colors.grey[700]},
    ];
  }

  static List<Map<String, dynamic>> getStatusBayarOptions() {
    return [
      {'value': 'semua', 'label': '💰 Semua Pembayaran'},
      {'value': 'dibayar', 'label': '✅ Sudah Dibayar'},
      {'value': 'belum_dibayar', 'label': '⏳ Belum Dibayar'},
    ];
  }

  // ═══════════════════════════════════════════════════════════
  // COMPUTED PROPERTIES
  // ═══════════════════════════════════════════════════════════

  String get tanggalFormatted {
    final df = DateFormat('EEEE, dd MMM yyyy', 'id_ID');
    return df.format(tanggal);
  }

  String get tanggalSingkat {
    final df = DateFormat('dd MMM yyyy', 'id_ID');
    return df.format(tanggal);
  }

  String get jamFormatted => '$jamMulai - $jamSelesai';

  String get durasiFormatted {
    try {
      final partsMulai = jamMulai.split(':');
      final partsSelesai = jamSelesai.split(':');

      final mulaiHours = int.tryParse(partsMulai[0]) ?? 0;
      final mulaiMinutes = partsMulai.length > 1 ? (int.tryParse(partsMulai[1]) ?? 0) : 0;
      final selesaiHours = int.tryParse(partsSelesai[0]) ?? 0;
      final selesaiMinutes = partsSelesai.length > 1 ? (int.tryParse(partsSelesai[1]) ?? 0) : 0;

      final mulaiTotal = mulaiHours * 60 + mulaiMinutes;
      var selesaiTotal = selesaiHours * 60 + selesaiMinutes;

      if (selesaiTotal <= mulaiTotal) selesaiTotal += 24 * 60;

      final diff = selesaiTotal - mulaiTotal;
      final hours = diff ~/ 60;
      final minutes = diff % 60;

      if (hours > 0 && minutes > 0) {
        return '${hours}j ${minutes.toString().padLeft(2, '0')}m';
      } else if (hours > 0) {
        return '${hours} jam';
      } else {
        return '${minutes} menit';
      }
    } catch (_) {
      return '$jamMulai - $jamSelesai';
    }
  }

  String get checkInFormatted {
    if (checkInTime == null) return '--:--';
    return DateFormat('HH:mm', 'id_ID').format(checkInTime!);
  }

  String get checkOutFormatted {
    if (checkOutTime == null) return '--:--';
    return DateFormat('HH:mm', 'id_ID').format(checkOutTime!);
  }

  String get checkInTanggalFormatted {
    if (checkInTime == null) return '--';
    return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(checkInTime!);
  }

  String get checkOutTanggalFormatted {
    if (checkOutTime == null) return '--';
    return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(checkOutTime!);
  }

  bool get hasCheckIn => checkInTime != null;
  bool get hasCheckOut => checkOutTime != null;
  bool get isComplete => absensiStatus == 'selesai' || absensiStatus == 'selesai_terlambat';
  bool get isTerlambat => absensiStatus == 'selesai_terlambat';
  bool get isPending => absensiStatus == 'belum_absen' || absensiStatus == 'check_in' || absensiStatus == 'sudah_absen';
  bool get isExpired => absensiStatus == 'expired';
  bool get isTidakLembur => absensiStatus == 'tidak_lembur';
  bool get needsAction => isPending && !isExpired;

  String get durasiRealFormatted {
    if (totalJam <= 0) return '--';
    final hours = totalJam.floor();
    final minutes = ((totalJam - hours) * 60).round();
    if (hours > 0 && minutes > 0) {
      return '${hours}j ${minutes.toString().padLeft(2, '0')}m';
    } else if (hours > 0) {
      return '${hours} jam';
    } else {
      return '${minutes} menit';
    }
  }

  String get pendapatanFormatted {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(pendapatan);
  }

  String get statusBayarLabel => isPaid ? '✅ Dibayar' : '⏳ Belum Dibayar';

  Color get statusColor => absensiStatus.absensiColor;
  Color get statusBayarColor => isPaid ? Colors.green : Colors.orange;
  IconData get statusIcon => absensiStatus.absensiIcon;
  IconData get statusBayarIcon => isPaid ? Icons.payments_rounded : Icons.payment_rounded;

  String get keterlambatanAlasan {
    if (absensiKeterlambatan == null) return '';
    return absensiKeterlambatan!['alasan']?.toString() ?? '';
  }

  bool get keterlambatanMelakukanLembur {
    if (absensiKeterlambatan == null) return false;
    return absensiKeterlambatan!['melakukan_lembur'] == true;
  }

  String? get confirmedAtFormatted {
    if (confirmedAt == null) return null;
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(confirmedAt!);
  }

  // ═══════════════════════════════════════════════════════════
  // EXPORT
  // ═══════════════════════════════════════════════════════════

  Map<String, dynamic> toExportMap() {
    return {
      'id': id,
      'tanggal': tanggalFormatted,
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'status_absensi': absensiLabel,
      'check_in': checkInTanggalFormatted,
      'check_out': checkOutTanggalFormatted,
      'total_jam': totalJam.toStringAsFixed(2),
      'pendapatan': pendapatan,
      'status_pembayaran': statusBayarLabel,
      'lokasi': lokasi ?? '',
      'catatan': catatan ?? '',
      'alasan_keterlambatan': keterlambatanAlasan,
      'waktu_konfirmasi': confirmedAtFormatted ?? '-',
      'alasan_tidak_lembur': alasanTidakLembur ?? '-',
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tanggal': tanggal.toIso8601String(),
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'absensi_status': absensiStatus,
      'absensi_label': absensiLabel,
      'status_lembur': statusLembur,
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'check_in_foto_url': checkInFotoUrl,
      'check_out_foto_url': checkOutFotoUrl,
      'pendapatan': pendapatan,
      'is_paid': isPaid,
      'total_jam': totalJam,
      'mitra_id': mitraId,
      'mitra_nama': mitraNama,
      'lokasi': lokasi,
      'catatan': catatan,
      'tahun_bulan': tahunBulan,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'absensi_keterlambatan': absensiKeterlambatan,
      'confirmed_at': confirmedAt?.toIso8601String(),
      'alasan_tidak_lembur': alasanTidakLembur,
    };
  }

  @override
  String toString() => 'AbsensiHistoryItem(id: $id, tanggal: $tanggalFormatted, status: $absensiLabel, '
      'checkIn: ${hasCheckIn ? checkInFormatted : "null"}, checkOut: ${hasCheckOut ? checkOutFormatted : "null"})';
}

// ═══════════════════════════════════════════════════════════════
// MODEL: AbsensiHistorySummary
// ═══════════════════════════════════════════════════════════════

class AbsensiHistorySummary {
  final int totalLembur;
  final int totalHadir;
  final int totalTerlambat;
  final int totalTidakHadir;
  final int totalExpired;
  final int totalBelum;
  final int totalCheckIn;
  final int totalSudahAbsen;
  final double totalJam;
  final double avgJam;
  final double maxJam;
  final double minJam;
  final double totalPendapatan;
  final double totalDibayar;
  final double totalBelumDibayar;
  final double avgPendapatan;
  final int totalPaid;
  final int totalUnpaid;
  final double persentaseHadir;
  final double persentaseTerlambat;
  final double persentasePaid;
  final DateTime? earliestTanggal;
  final DateTime? latestTanggal;
  final Map<String, int> statusDistribution;
  final Map<String, int> dailyDistribution;
  final Map<String, double> hourlyDistribution;
  final int totalDays;
  final int totalHours;

  const AbsensiHistorySummary({
    required this.totalLembur,
    required this.totalHadir,
    required this.totalTerlambat,
    required this.totalTidakHadir,
    required this.totalExpired,
    required this.totalBelum,
    required this.totalCheckIn,
    required this.totalSudahAbsen,
    required this.totalJam,
    required this.avgJam,
    required this.maxJam,
    required this.minJam,
    required this.totalPendapatan,
    required this.totalDibayar,
    required this.totalBelumDibayar,
    required this.avgPendapatan,
    required this.totalPaid,
    required this.totalUnpaid,
    required this.persentaseHadir,
    required this.persentaseTerlambat,
    required this.persentasePaid,
    this.earliestTanggal,
    this.latestTanggal,
    required this.statusDistribution,
    required this.dailyDistribution,
    required this.hourlyDistribution,
    required this.totalDays,
    required this.totalHours,
  });

  factory AbsensiHistorySummary.empty() => const AbsensiHistorySummary(
        totalLembur: 0, totalHadir: 0, totalTerlambat: 0, totalTidakHadir: 0,
        totalExpired: 0, totalBelum: 0, totalCheckIn: 0, totalSudahAbsen: 0,
        totalJam: 0, avgJam: 0, maxJam: 0, minJam: 0,
        totalPendapatan: 0, totalDibayar: 0, totalBelumDibayar: 0, avgPendapatan: 0,
        totalPaid: 0, totalUnpaid: 0,
        persentaseHadir: 0, persentaseTerlambat: 0, persentasePaid: 0,
        statusDistribution: {}, dailyDistribution: {}, hourlyDistribution: {},
        totalDays: 0, totalHours: 0,
      );

  String get totalJamFormatted => '${totalJam.toStringAsFixed(1)} jam';
  String get avgJamFormatted => '${avgJam.toStringAsFixed(1)} jam';

  String get totalPendapatanFormatted {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(totalPendapatan);
  }

  String get totalDibayarFormatted {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(totalDibayar);
  }

  String get totalBelumDibayarFormatted {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(totalBelumDibayar);
  }

  String get avgPendapatanFormatted {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(avgPendapatan);
  }

  String get dateRangeFormatted {
    if (earliestTanggal == null || latestTanggal == null) return 'Tidak ada data';
    final df = DateFormat('dd MMM yyyy', 'id_ID');
    return '${df.format(earliestTanggal!)} - ${df.format(latestTanggal!)}';
  }

  String get hariTersibuk {
    if (dailyDistribution.isEmpty) return '-';
    final sorted = dailyDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted.first.key} (${sorted.first.value}x)';
  }

  String get jamTersibuk {
    if (hourlyDistribution.isEmpty) return '-';
    final sorted = hourlyDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted.first.key}:00 (${sorted.first.value.toInt()}x)';
  }

  Map<String, dynamic> toJson() => {
        'total_lembur': totalLembur, 'total_hadir': totalHadir,
        'total_terlambat': totalTerlambat, 'total_tidak_hadir': totalTidakHadir,
        'total_expired': totalExpired, 'total_belum': totalBelum,
        'total_check_in': totalCheckIn, 'total_sudah_absen': totalSudahAbsen,
        'total_jam': totalJam, 'avg_jam': avgJam,
        'max_jam': maxJam, 'min_jam': minJam,
        'total_pendapatan': totalPendapatan, 'total_dibayar': totalDibayar,
        'total_belum_dibayar': totalBelumDibayar, 'avg_pendapatan': avgPendapatan,
        'total_paid': totalPaid, 'total_unpaid': totalUnpaid,
        'persentase_hadir': persentaseHadir, 'persentase_terlambat': persentaseTerlambat,
        'persentase_paid': persentasePaid,
      };
}

class MonthlyStatistic {
  final int tahun;
  final int bulan;
  final String bulanKey;
  final String bulanNama;
  final AbsensiHistorySummary summary;

  const MonthlyStatistic({
    required this.tahun, required this.bulan,
    required this.bulanKey, required this.bulanNama,
    required this.summary,
  });

  String get bulanTahunFormatted => '$bulanNama $tahun';
  String get totalJamFormatted => '${summary.totalJam.toStringAsFixed(1)}j';
  String get hadirFormatted => '${summary.totalHadir}/${summary.totalLembur}';
}

class YearlyStatistic {
  final int tahun;
  final int totalLembur;
  final int totalHadir;
  final double totalJam;
  final double totalPendapatan;
  final double totalDibayar;
  final double rataRataPerBulan;
  final List<MonthlyStatistic> monthlyStats;

  const YearlyStatistic({
    required this.tahun, required this.totalLembur,
    required this.totalHadir, required this.totalJam,
    required this.totalPendapatan, required this.totalDibayar,
    required this.rataRataPerBulan, required this.monthlyStats,
  });

  factory YearlyStatistic.empty() => YearlyStatistic(
        tahun: DateTime.now().year, totalLembur: 0, totalHadir: 0,
        totalJam: 0, totalPendapatan: 0, totalDibayar: 0,
        rataRataPerBulan: 0, monthlyStats: [],
      );

  String get totalPendapatanFormatted {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(totalPendapatan);
  }

  String get totalJamFormatted => '${totalJam.toStringAsFixed(1)} jam';
}

class AbsensiDetail {
  final AbsensiHistoryItem historyItem;
  final List<OvertimeAbsensi> absensiLogs;
  final TenggatInfo? tenggatInfo;
  final int totalLogs;
  final bool hasCheckIn;
  final bool hasCheckOut;

  const AbsensiDetail({
    required this.historyItem, required this.absensiLogs,
    this.tenggatInfo, required this.totalLogs,
    required this.hasCheckIn, required this.hasCheckOut,
  });

  factory AbsensiDetail.empty() => AbsensiDetail(
        historyItem: AbsensiHistoryItem._(
          id: '', tanggal: DateTime.now(), jamMulai: '00:00', jamSelesai: '00:00',
          absensiStatus: 'belum_absen', absensiLabel: 'Belum Absen',
          pendapatan: 0, isPaid: false, totalJam: 0,
          overtimeHistory: OvertimeHistory(
            id: '', groupId: '', tanggal: DateTime.now(), jamMulai: '00:00',
            jamSelesai: '00:00', totalJam: 0, jenisLembur: '', lokasi: {},
            urgensi: '', alasan: '', catatanTambahan: '',
            estimasiBiayaPerMitra: 0, estimasiBiayaTotal: 0, status: '',
            createdAt: DateTime.now(), updatedAt: DateTime.now(),
          ),
        ),
        absensiLogs: [], totalLogs: 0, hasCheckIn: false, hasCheckOut: false,
      );

  String get checkInTimeFormatted {
    if (!hasCheckIn) return 'Belum Check-in';
    final checkIn = absensiLogs.firstWhere((log) => log.jenis == 'check_in');
    return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(checkIn.waktu);
  }

  String get checkOutTimeFormatted {
    if (!hasCheckOut) return 'Belum Check-out';
    final checkOut = absensiLogs.firstWhere((log) => log.jenis == 'check_out');
    return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(checkOut.waktu);
  }

  Duration? get totalDurasi {
    if (!hasCheckIn) return null;
    final checkIn = absensiLogs.firstWhere((log) => log.jenis == 'check_in');
    final checkOut = hasCheckOut
        ? absensiLogs.firstWhere((log) => log.jenis == 'check_out')
        : null;
    if (checkOut == null) return null;
    return checkOut.waktu.difference(checkIn.waktu);
  }

  String get totalDurasiFormatted {
    final durasi = totalDurasi;
    if (durasi == null) return '-';
    final hours = durasi.inHours;
    final minutes = durasi.inMinutes.remainder(60);
    return '${hours}j ${minutes.toString().padLeft(2, '0')}m';
  }
}

extension AbsensiStatusExtension on String {
  Color get absensiColor {
    switch (this) {
      case 'check_in': case 'selesai': case 'sudah_absen': return Colors.green;
      case 'selesai_terlambat': return Colors.orange;
      case 'tidak_lembur': case 'expired': return Colors.red;
      case 'belum_absen': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData get absensiIcon {
    switch (this) {
      case 'check_in': return Icons.login_rounded;
      case 'selesai': return Icons.check_circle_rounded;
      case 'sudah_absen': return Icons.verified_rounded;
      case 'selesai_terlambat': return Icons.warning_amber_rounded;
      case 'tidak_lembur': return Icons.cancel_rounded;
      case 'expired': return Icons.timer_off_rounded;
      case 'belum_absen': return Icons.hourglass_empty_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  String get absensiLabel {
    switch (this) {
      case 'belum_absen': return '⏳ Belum Absen';
      case 'check_in': return '📥 Check In';
      case 'check_out': return '📤 Check Out';
      case 'selesai': return '✅ Selesai';
      case 'selesai_terlambat': return '⚠️ Terlambat';
      case 'tidak_lembur': return '❌ Tidak Lembur';
      case 'expired': return '⏰ Expired';
      default: return '❓ $this';
    }
  }
}