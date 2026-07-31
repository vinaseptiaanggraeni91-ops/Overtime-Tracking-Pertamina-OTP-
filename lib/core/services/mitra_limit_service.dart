// lib/core/services/mitra_limit_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Service untuk mengecek batasan dan duplikasi lembur mitra
/// 
/// 🔥 V2: Support multi-hari (rentang tanggal) + overnight
class MitraLimitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ==================== KONSTANTA ====================
  static const double maxJamBulanan = 60.0; // Maksimal 60 jam/bulan
  static const String collectionLemburMitra = 'lembur_mitra';
  static const String collectionPengajuan = 'pengajuan_lembur';

  
  // ==================== CHECK MONTHLY LIMIT ====================
  

  /// Cek batas lembur bulanan mitra (maks 60 jam/bulan)
  Future<Map<String, dynamic>> checkMitraLimit({
    required String mitraId,
    required DateTime tanggal,
    required double tambahanJam,
  }) async {
    try {
      final tahunBulan = DateFormat('yyyy-MM').format(tanggal);
      
      debugPrint('🔍 Checking monthly limit for mitra $mitraId on $tahunBulan');
      debugPrint('   Additional hours: ${tambahanJam.toStringAsFixed(1)}');

      // Ambil semua lembur mitra di bulan tersebut
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: mitraId)
          .where('tahun_bulan', isEqualTo: tahunBulan)
          .where('status', whereIn: ['disetujui', 'pending', 'selesai'])
          .get();

      double totalJam = 0;
      int totalPengajuan = snapshot.docs.length;
      List<Map<String, dynamic>> existingLembur = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final jam = (data['total_jam_desimal'] ?? 0).toDouble();
        totalJam += jam;
        
        existingLembur.add({
          'id': doc.id,
          'tanggal': (data['tanggal'] as Timestamp?)?.toDate(),
          'jam': jam,
          'status': data['status'],
        });
      }

      final totalSetelahLembur = totalJam + tambahanJam;
      final sisaJam = (maxJamBulanan - totalJam).clamp(0.0, maxJamBulanan);
      final isExceeded = totalSetelahLembur > maxJamBulanan;
      final persentase = ((totalJam + tambahanJam) / maxJamBulanan * 100).clamp(0.0, 100.0);

      debugPrint('📊 Monthly limit check:');
      debugPrint('   Total jam bulan ini: ${totalJam.toStringAsFixed(1)}');
      debugPrint('   Setelah lembur: ${totalSetelahLembur.toStringAsFixed(1)}');
      debugPrint('   Sisa jam: ${sisaJam.toStringAsFixed(1)}');
      debugPrint('   Is exceeded: $isExceeded');

      return {
        'is_exceeded': isExceeded,
        'total_jam_bulan_ini': totalJam,
        'tambahan_jam': tambahanJam,
        'total_setelah_lembur': totalSetelahLembur,
        'sisa_jam': sisaJam,
        'max_jam': maxJamBulanan,
        'persentase': persentase,
        'total_pengajuan': totalPengajuan,
        'existing_lembur': existingLembur,
        'tahun_bulan': tahunBulan,
        'message': isExceeded
            ? '⚠️ Mitra akan melebihi batas maksimal ${maxJamBulanan.toInt()} jam/bulan '
              '(total: ${totalSetelahLembur.toStringAsFixed(1)} jam)'
            : '✅ Masih dalam batas (${sisaJam.toStringAsFixed(1)} jam tersisa)',
        'status': isExceeded ? 'warning' : 'ok',
      };
    } catch (e) {
      debugPrint('❌ Error checking mitra limit: $e');
      return {
        'is_exceeded': false,
        'total_jam_bulan_ini': 0,
        'tambahan_jam': tambahanJam,
        'total_setelah_lembur': tambahanJam,
        'sisa_jam': maxJamBulanan,
        'max_jam': maxJamBulanan,
        'persentase': (tambahanJam / maxJamBulanan * 100).clamp(0.0, 100.0),
        'total_pengajuan': 0,
        'existing_lembur': [],
        'tahun_bulan': DateFormat('yyyy-MM').format(tanggal),
        'message': 'Gagal memeriksa batas lembur: $e',
        'status': 'error',
      };
    }
  }

  
  // ==================== CHECK DAILY DUPLICATE (SINGLE DAY) ====================
  

  /// Cek duplikasi lembur harian (mitra hanya bisa 1x lembur per hari)
  /// 🔥 Tetap dipertahankan untuk backward compatibility
  Future<Map<String, dynamic>> checkDuplicateLemburHarian({
    required String mitraId,
    required DateTime tanggal,
  }) async {
    try {
      // Buat range tanggal (start of day sampai end of day)
      final startOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      debugPrint('🔍 Checking duplicate for mitra $mitraId on ${DateFormat('yyyy-MM-dd').format(tanggal)}');

      // Cari lembur yang sudah ada di tanggal tersebut
      final existingLembur = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: mitraId)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: ['pending', 'disetujui', 'selesai'])
          .get();

      final isDuplicate = existingLembur.docs.isNotEmpty;
      
      List<Map<String, dynamic>> existingData = [];
      if (isDuplicate) {
        for (var doc in existingLembur.docs) {
          final data = doc.data();
          existingData.add({
            'id': doc.id,
            'group_id': data['group_id'] ?? '',
            'pengawas_id': data['pengawas_id'] ?? '',
            'tanggal': (data['tanggal'] as Timestamp?)?.toDate(),
            'jam_mulai': data['jam_mulai'] ?? '',
            'jam_selesai': data['jam_selesai'] ?? '',
            'total_jam': (data['total_jam_desimal'] ?? 0).toDouble(),
            'status': data['status'] ?? '',
            'lokasi': data['lokasi'] ?? {},
          });
        }
      }

      debugPrint('📊 Duplicate check result: $isDuplicate (${existingLembur.docs.length} existing)');

      return {
        'is_duplicate': isDuplicate,
        'existing_count': existingLembur.docs.length,
        'existing_ids': existingLembur.docs.map((doc) => doc.id).toList(),
        'existing_data': existingData,
        'message': isDuplicate 
            ? '⚠️ Mitra sudah memiliki ${existingLembur.docs.length} pengajuan lembur di tanggal ini'
            : '✅ Mitra belum memiliki pengajuan lembur di tanggal ini',
        'status': isDuplicate ? 'warning' : 'ok',
      };
    } catch (e) {
      debugPrint('❌ Error checking duplicate lembur harian: $e');
      return {
        'is_duplicate': false,
        'existing_count': 0,
        'existing_ids': [],
        'existing_data': [],
        'message': 'Gagal memeriksa duplikasi: $e',
        'status': 'error',
      };
    }
  }

  
  // ==================== 🔥 CHECK DUPLICATE RENTANG (MULTI-HARI) ====================
  

  /// Cek duplikasi lembur untuk RENTANG TANGGAL (multi-hari)
  /// 🔥 Method BARU untuk support multi-hari
  Future<Map<String, dynamic>> checkDuplicateLemburRentang({
    required String mitraId,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
  }) async {
    try {
      final startOfDay = DateTime(
        tanggalMulai.year, tanggalMulai.month, tanggalMulai.day,
      );
      final endOfDay = DateTime(
        tanggalSelesai.year, tanggalSelesai.month, tanggalSelesai.day,
      ).add(const Duration(days: 1));

      debugPrint('🔍 Checking duplicate RENTANG for mitra $mitraId');
      debugPrint('   ${DateFormat('dd MMM yyyy').format(tanggalMulai)} → ${DateFormat('dd MMM yyyy').format(tanggalSelesai)}');

      // Cari lembur yang overlap dengan rentang
      final existingLembur = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: mitraId)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: ['pending', 'disetujui', 'selesai'])
          .get();

      final isDuplicate = existingLembur.docs.isNotEmpty;

      // 🔥 Group by tanggal untuk info detail
      final Map<String, List<Map<String, dynamic>>> duplicatesByDate = {};
      List<Map<String, dynamic>> allDuplicates = [];

      for (var doc in existingLembur.docs) {
        final data = doc.data();
        final tgl = (data['tanggal'] as Timestamp?)?.toDate();
        final dateKey = tgl != null ? DateFormat('yyyy-MM-dd').format(tgl) : 'unknown';

        final item = {
          'id': doc.id,
          'group_id': data['group_id'] ?? '',
          'tanggal': tgl,
          'jam_mulai': data['jam_mulai'] ?? '',
          'jam_selesai': data['jam_selesai'] ?? '',
          'total_jam': (data['total_jam_desimal'] ?? 0).toDouble(),
          'status': data['status'] ?? '',
        };

        if (!duplicatesByDate.containsKey(dateKey)) {
          duplicatesByDate[dateKey] = [];
        }
        duplicatesByDate[dateKey]!.add(item);
        allDuplicates.add(item);
      }

      // 🔥 Generate list tanggal yang bentrok
      final List<String> conflictDates = duplicatesByDate.keys.toList()..sort();

      // 🔥 Generate daftar tanggal yang AMAN (tidak bentrok)
      final allDatesInRange = _getDatesInRange(tanggalMulai, tanggalSelesai);
      final List<String> safeDates = [];
      for (final date in allDatesInRange) {
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        if (!conflictDates.contains(dateKey)) {
          safeDates.add(dateKey);
        }
      }

      debugPrint('📊 Rentang duplicate result: $isDuplicate');
      debugPrint('   Total existing: ${existingLembur.docs.length}');
      debugPrint('   Conflict dates (${conflictDates.length}): $conflictDates');
      debugPrint('   Safe dates (${safeDates.length}): $safeDates');

      return {
        'is_duplicate': isDuplicate,
        'existing_count': existingLembur.docs.length,
        'existing_ids': existingLembur.docs.map((doc) => doc.id).toList(),
        'existing_data': allDuplicates,
        'duplicates_by_date': duplicatesByDate,
        'conflict_dates': conflictDates,
        'safe_dates': safeDates,
        'conflict_count': conflictDates.length,
        'safe_count': safeDates.length,
        'message': isDuplicate
            ? '⚠️ Mitra sudah memiliki pengajuan di ${conflictDates.length} tanggal: ${conflictDates.map((d) => DateFormat('dd/MM').format(DateTime.parse(d))).join(', ')}'
            : '✅ Mitra belum memiliki pengajuan lembur di rentang tanggal ini',
        'status': isDuplicate ? 'warning' : 'ok',
      };
    } catch (e) {
      debugPrint('❌ Error checking duplicate rentang: $e');
      return {
        'is_duplicate': false,
        'existing_count': 0,
        'existing_ids': [],
        'existing_data': [],
        'duplicates_by_date': {},
        'conflict_dates': [],
        'safe_dates': [],
        'conflict_count': 0,
        'safe_count': 0,
        'message': 'Gagal memeriksa duplikasi: $e',
        'status': 'error',
      };
    }
  }

  
  // ==================== COMPREHENSIVE CHECK (SINGLE DAY) ====================
  

  /// Pengecekan komprehensif (duplikasi + limit) untuk satu mitra (single day)
  Future<Map<String, dynamic>> comprehensiveCheck({
    required String mitraId,
    required DateTime tanggal,
    required double tambahanJam,
  }) async {
    try {
      // Jalankan kedua pengecekan secara paralel
      final results = await Future.wait([
        checkDuplicateLemburHarian(mitraId: mitraId, tanggal: tanggal),
        checkMitraLimit(mitraId: mitraId, tanggal: tanggal, tambahanJam: tambahanJam),
      ]);

      final duplicateCheck = results[0];
      final limitCheck = results[1];

      final isDuplicate = duplicateCheck['is_duplicate'] == true;
      final isLimitExceeded = limitCheck['is_exceeded'] == true;
      
      // Tidak bisa submit jika duplikat
      final canSubmit = !isDuplicate;
      // Bisa override jika bukan duplikat tapi limit exceeded
      final canOverride = !isDuplicate && isLimitExceeded;
      // Valid jika tidak duplikat dan tidak exceed limit
      final isValid = !isDuplicate && !isLimitExceeded;

      return {
        'mitra_id': mitraId,
        'tanggal': DateFormat('yyyy-MM-dd').format(tanggal),
        'tambahan_jam': tambahanJam,
        'duplicate_check': duplicateCheck,
        'limit_check': limitCheck,
        'is_duplicate': isDuplicate,
        'is_limit_exceeded': isLimitExceeded,
        'can_submit': canSubmit,
        'can_override': canOverride,
        'is_valid': isValid,
        'summary': _generateSummary(isDuplicate, isLimitExceeded),
        'status': isValid ? 'ok' : (canOverride ? 'warning' : 'error'),
      };
    } catch (e) {
      debugPrint('❌ Error comprehensive check: $e');
      return {
        'mitra_id': mitraId,
        'is_valid': false,
        'status': 'error',
        'message': 'Gagal melakukan pengecekan: $e',
      };
    }
  }

  
  // ==================== 🔥 COMPREHENSIVE CHECK RENTANG (MULTI-HARI) ====================
  

  /// Pengecekan komprehensif untuk RENTANG TANGGAL (multi-hari)
  /// 🔥 Method BARU untuk support multi-hari
  Future<Map<String, dynamic>> comprehensiveCheckRentang({
    required String mitraId,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    required double tambahanJam,
  }) async {
    try {
      // Jalankan kedua pengecekan secara paralel
      final results = await Future.wait([
        checkDuplicateLemburRentang(
          mitraId: mitraId,
          tanggalMulai: tanggalMulai,
          tanggalSelesai: tanggalSelesai,
        ),
        checkMitraLimit(
          mitraId: mitraId,
          tanggal: tanggalMulai,
          tambahanJam: tambahanJam,
        ),
      ]);

      final duplicateCheck = results[0];
      final limitCheck = results[1];

      final isDuplicate = duplicateCheck['is_duplicate'] == true;
      final isLimitExceeded = limitCheck['is_exceeded'] == true;
      final conflictDates = duplicateCheck['conflict_dates'] as List<String>? ?? [];
      final safeDates = duplicateCheck['safe_dates'] as List<String>? ?? [];

      final canSubmit = !isDuplicate;
      final canOverride = !isDuplicate && isLimitExceeded;
      final isValid = !isDuplicate && !isLimitExceeded;

      return {
        'mitra_id': mitraId,
        'tanggal_mulai': DateFormat('yyyy-MM-dd').format(tanggalMulai),
        'tanggal_selesai': DateFormat('yyyy-MM-dd').format(tanggalSelesai),
        'tambahan_jam': tambahanJam,
        'duplicate_check': duplicateCheck,
        'limit_check': limitCheck,
        'is_duplicate': isDuplicate,
        'is_limit_exceeded': isLimitExceeded,
        'conflict_dates': conflictDates,
        'safe_dates': safeDates,
        'conflict_count': conflictDates.length,
        'safe_count': safeDates.length,
        'can_submit': canSubmit,
        'can_override': canOverride,
        'is_valid': isValid,
        'summary': _generateSummaryRentang(isDuplicate, isLimitExceeded, conflictDates),
        'status': isValid ? 'ok' : (canOverride ? 'warning' : 'error'),
      };
    } catch (e) {
      debugPrint('❌ Error comprehensive check rentang: $e');
      return {
        'mitra_id': mitraId,
        'is_valid': false,
        'status': 'error',
        'message': 'Gagal melakukan pengecekan: $e',
      };
    }
  }

  
  // ==================== BATCH CHECKS (SINGLE DAY) ====================
  

  /// Cek batas lembur untuk multiple mitra sekaligus
  Future<Map<String, Map<String, dynamic>>> checkMultipleMitraLimit({
    required List<String> mitraIds,
    required DateTime tanggal,
    required double tambahanJam,
  }) async {
    final results = <String, Map<String, dynamic>>{};
    
    for (final mitraId in mitraIds) {
      results[mitraId] = await checkMitraLimit(
        mitraId: mitraId,
        tanggal: tanggal,
        tambahanJam: tambahanJam,
      );
    }
    
    return results;
  }

  /// Cek duplikasi untuk multiple mitra
  Future<Map<String, Map<String, dynamic>>> checkMultipleDuplicate({
    required List<String> mitraIds,
    required DateTime tanggal,
  }) async {
    final results = <String, Map<String, dynamic>>{};
    
    for (final mitraId in mitraIds) {
      results[mitraId] = await checkDuplicateLemburHarian(
        mitraId: mitraId,
        tanggal: tanggal,
      );
    }
    
    return results;
  }

  /// Comprehensive check untuk multiple mitra
  Future<Map<String, Map<String, dynamic>>> comprehensiveCheckMultiple({
    required List<String> mitraIds,
    required DateTime tanggal,
    required double tambahanJam,
  }) async {
    final results = <String, Map<String, dynamic>>{};
    
    for (final mitraId in mitraIds) {
      results[mitraId] = await comprehensiveCheck(
        mitraId: mitraId,
        tanggal: tanggal,
        tambahanJam: tambahanJam,
      );
    }
    
    return results;
  }

  
  // ==================== 🔥 BATCH CHECKS RENTANG (MULTI-HARI) ====================
  

  /// Cek duplikasi untuk multiple mitra dengan RENTANG TANGGAL
  /// 🔥 Method BARU
  Future<Map<String, Map<String, dynamic>>> checkMultipleDuplicateRentang({
    required List<String> mitraIds,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
  }) async {
    final results = <String, Map<String, dynamic>>{};
    
    for (final mitraId in mitraIds) {
      results[mitraId] = await checkDuplicateLemburRentang(
        mitraId: mitraId,
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
      );
    }
    
    return results;
  }

  /// Comprehensive check untuk multiple mitra dengan RENTANG TANGGAL
  /// 🔥 Method BARU
  Future<Map<String, Map<String, dynamic>>> comprehensiveCheckMultipleRentang({
    required List<String> mitraIds,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    required double tambahanJam,
  }) async {
    final results = <String, Map<String, dynamic>>{};
    
    for (final mitraId in mitraIds) {
      results[mitraId] = await comprehensiveCheckRentang(
        mitraId: mitraId,
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
        tambahanJam: tambahanJam,
      );
    }
    
    return results;
  }

  
  // ==================== STATISTICS & REPORTS ====================
  

  /// Get statistik lembur mitra bulanan
  Future<Map<String, dynamic>> getMitraMonthlyStats({
    required String mitraId,
    required String yearMonth,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: mitraId)
          .where('tahun_bulan', isEqualTo: yearMonth)
          .where('status', whereIn: ['disetujui', 'pending', 'selesai'])
          .get();

      double totalJam = 0;
      double totalBiaya = 0;
      int totalLembur = snapshot.docs.length;
      int pending = 0;
      int approved = 0;
      int completed = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalJam += (data['total_jam_desimal'] as num?)?.toDouble() ?? 0;
        totalBiaya += (data['estimasi_biaya_per_mitra'] as num?)?.toDouble() ?? 0;
        
        switch (data['status']) {
          case 'pending': pending++; break;
          case 'disetujui': approved++; break;
          case 'selesai': completed++; break;
        }
      }

      final sisaJam = (maxJamBulanan - totalJam).clamp(0.0, maxJamBulanan);

      return {
        'mitra_id': mitraId,
        'tahun_bulan': yearMonth,
        'total_jam': totalJam,
        'total_biaya': totalBiaya,
        'total_lembur': totalLembur,
        'pending': pending,
        'approved': approved,
        'completed': completed,
        'max_jam': maxJamBulanan,
        'sisa_jam': sisaJam,
        'is_exceeded': totalJam >= maxJamBulanan,
        'persentase': (totalJam / maxJamBulanan * 100).clamp(0.0, 100.0),
      };
    } catch (e) {
      debugPrint('❌ Error getting mitra monthly stats: $e');
      return {
        'mitra_id': mitraId,
        'tahun_bulan': yearMonth,
        'total_jam': 0,
        'total_biaya': 0,
        'total_lembur': 0,
        'sisa_jam': maxJamBulanan,
        'is_exceeded': false,
        'persentase': 0,
      };
    }
  }

  /// Get laporan bulanan detail
  Future<List<Map<String, dynamic>>> getMonthlyReport({
    required String mitraId,
    required String yearMonth,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: mitraId)
          .where('tahun_bulan', isEqualTo: yearMonth)
          .orderBy('tanggal', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'group_id': data['group_id'] ?? '',
          'tanggal': (data['tanggal'] as Timestamp?)?.toDate(),
          'jam_mulai': data['jam_mulai'] ?? '',
          'jam_selesai': data['jam_selesai'] ?? '',
          'total_jam': (data['total_jam_desimal'] ?? 0).toDouble(),
          'status': data['status'] ?? '',
          'absensi_status': data['absensi_status'] ?? '',
          'estimasi_biaya': (data['estimasi_biaya_per_mitra'] ?? 0).toDouble(),
          'jenis_lembur': data['jenis_lembur'] ?? '',
          'lokasi': data['lokasi'] ?? {},
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting monthly report: $e');
      return [];
    }
  }

  /// Get ringkasan tahunan
  Future<Map<String, dynamic>> getYearlySummary({
    required String mitraId,
    required int year,
  }) async {
    try {
      final yearStart = '$year-01';
      final yearEnd = '$year-12';
      
      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('mitra_id', isEqualTo: mitraId)
          .where('tahun_bulan', isGreaterThanOrEqualTo: yearStart)
          .where('tahun_bulan', isLessThanOrEqualTo: yearEnd)
          .where('status', whereIn: ['disetujui', 'pending', 'selesai'])
          .get();

      double totalJam = 0;
      double totalBiaya = 0;
      final monthlyBreakdown = <String, Map<String, double>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final jam = (data['total_jam_desimal'] as num?)?.toDouble() ?? 0;
        final biaya = (data['estimasi_biaya_per_mitra'] as num?)?.toDouble() ?? 0;
        
        totalJam += jam;
        totalBiaya += biaya;

        final month = data['tahun_bulan'] as String? ?? '';
        if (month.isNotEmpty) {
          if (!monthlyBreakdown.containsKey(month)) {
            monthlyBreakdown[month] = {'jam': 0, 'biaya': 0};
          }
          monthlyBreakdown[month]!['jam'] = (monthlyBreakdown[month]!['jam'] ?? 0) + jam;
          monthlyBreakdown[month]!['biaya'] = (monthlyBreakdown[month]!['biaya'] ?? 0) + biaya;
        }
      }

      return {
        'mitra_id': mitraId,
        'year': year,
        'total_jam': totalJam,
        'total_biaya': totalBiaya,
        'total_pengajuan': snapshot.docs.length,
        'rata_rata_jam_per_bulan': snapshot.docs.isNotEmpty ? totalJam / 12 : 0,
        'max_jam_per_bulan': maxJamBulanan,
        'monthly_breakdown': monthlyBreakdown,
      };
    } catch (e) {
      debugPrint('❌ Error getting yearly summary: $e');
      return {
        'mitra_id': mitraId,
        'year': year,
        'total_jam': 0,
        'total_biaya': 0,
        'total_pengajuan': 0,
        'error': e.toString(),
      };
    }
  }

  
  // ==================== HELPERS ====================
  

  /// 🔥 Generate list tanggal dalam rentang
  List<DateTime> _getDatesInRange(DateTime start, DateTime end) {
    final dates = <DateTime>[];
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    for (var d = startDay; !d.isAfter(endDay); d = d.add(const Duration(days: 1))) {
      dates.add(d);
    }
    return dates;
  }

  /// Format jam untuk display
  String formatJam(double jam) {
    if (jam <= 0) return '0 jam';
    if (jam % 1 == 0) {
      return '${jam.toInt()} jam';
    }
    final hours = jam.floor();
    final minutes = ((jam - hours) * 60).round();
    if (minutes == 0) return '$hours jam';
    return '$hours jam $minutes menit';
  }

  /// Format jam compact
  String formatJamCompact(double jam) {
    return '${jam.toStringAsFixed(1)} jam';
  }

  /// Generate summary dari comprehensive check (single day)
  String _generateSummary(bool isDuplicate, bool isLimitExceeded) {
    if (isDuplicate) {
      return '❌ Mitra sudah memiliki pengajuan lembur di tanggal ini';
    } else if (isLimitExceeded) {
      return '⚠️ Mitra akan melebihi batas maksimal ${maxJamBulanan.toInt()} jam/bulan';
    } else {
      return '✅ Mitra dapat diajukan lembur';
    }
  }

  /// 🔥 Generate summary untuk rentang (multi-hari)
  String _generateSummaryRentang(
    bool isDuplicate, 
    bool isLimitExceeded, 
    List<String> conflictDates,
  ) {
    if (isDuplicate) {
      if (conflictDates.length == 1) {
        return '❌ Mitra sudah memiliki pengajuan di tanggal ${DateFormat('dd MMM').format(DateTime.parse(conflictDates.first))}';
      }
      return '❌ Mitra sudah memiliki pengajuan di ${conflictDates.length} tanggal';
    } else if (isLimitExceeded) {
      return '⚠️ Mitra akan melebihi batas maksimal ${maxJamBulanan.toInt()} jam/bulan';
    } else {
      return '✅ Mitra dapat diajukan lembur untuk seluruh rentang';
    }
  }

  /// Get status label
  String getStatusLabel(String status) {
    switch (status) {
      case 'ok':
        return '✅ OK';
      case 'warning':
        return '⚠️ Warning';
      case 'error':
        return '❌ Error';
      default:
        return status;
    }
  }

  /// Get status color
  Color getStatusColor(String status) {
    switch (status) {
      case 'ok':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get progress bar color berdasarkan persentase
  Color getProgressColor(double persentase) {
    if (persentase >= 100) return Colors.red;
    if (persentase >= 80) return Colors.orange;
    if (persentase >= 50) return Colors.yellow.shade700;
    return Colors.green;
  }
}