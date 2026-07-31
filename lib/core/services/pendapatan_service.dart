// lib/core/services/pendapatan_service.dart
// 🔥 VERSION 4.0 - FULL SYNC: Gunakan OvertimeRateService untuk tarif AKURAT
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/core/services/overtime_rate_service.dart'; // 🔥 IMPORT OVERTIME RATE SERVICE

// ============================================================
// 📦 MODEL: PendapatanItem
// ============================================================
class PendapatanItem {
  final String id;
  final String? lemburId;
  final String? groupId;
  final DateTime tanggal;
  final String? jamMulai;
  final String? jamSelesai;
  final double totalJam;
  final String? jenisLembur;
  final String? statusAbsensi;
  final String? statusLembur;
  final DateTime? absensiWaktu;
  final DateTime? completedAt;
  final double tarifPerJam;
  final double estimasiPendapatan;
  final String? fotoUrl;
  final String? lokasi;
  final String? namaPengawas;
  final DateTime? createdAt;

  final bool isPaid;
  final DateTime? paidAt;
  final String? paidByName;
  final String? paidNote;
  final String? keterlambatanAlasan;
  final bool memenuhiSyaratBayar;
  final List<String> syaratBelumTerpenuhi;

  const PendapatanItem({
    required this.id,
    this.lemburId,
    this.groupId,
    required this.tanggal,
    this.jamMulai,
    this.jamSelesai,
    required this.totalJam,
    this.jenisLembur,
    this.statusAbsensi,
    this.statusLembur,
    this.absensiWaktu,
    this.completedAt,
    required this.tarifPerJam,
    required this.estimasiPendapatan,
    this.fotoUrl,
    this.lokasi,
    this.namaPengawas,
    this.createdAt,
    this.isPaid = false,
    this.paidAt,
    this.paidByName,
    this.paidNote,
    this.keterlambatanAlasan,
    this.memenuhiSyaratBayar = false,
    this.syaratBelumTerpenuhi = const [],
  });

  String get formattedPendapatan {
    return NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0,
    ).format(estimasiPendapatan);
  }

  String get formattedDurasiAbsensi {
    if (absensiWaktu == null || completedAt == null) {
      return '${jamMulai ?? "-"} → ${jamSelesai ?? "-"}';
    }
    return '${DateFormat('HH:mm').format(absensiWaktu!)} → ${DateFormat('HH:mm').format(completedAt!)}';
  }

  String get absensiStatusLabel {
    switch (statusAbsensi) {
      case 'selesai': return '✅ Selesai';
      case 'selesai_terlambat': return '⚠️ Terlambat';
      case 'check_in':
      case 'sudah_absen': return '📸 Check-in';
      case 'belum_absen': return '⏳ Belum Absen';
      case 'expired': return '❌ Kadaluarsa';
      default: return statusAbsensi ?? '-';
    }
  }

  Color get absensiStatusColor {
    switch (statusAbsensi) {
      case 'selesai': return Colors.green;
      case 'selesai_terlambat': return Colors.orange;
      case 'check_in':
      case 'sudah_absen': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String get statusLemburLabel {
    switch (statusLembur) {
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      case 'pending': return 'Pending';
      case 'selesai': return 'Selesai';
      default: return statusLembur ?? '-';
    }
  }

  String get pembayaranLabel => isPaid ? '✅ Sudah Dibayar' : '💰 Belum Dibayar';
  Color get pembayaranColor => isPaid ? Colors.green : Colors.orange;
  IconData get pembayaranIcon => isPaid ? Icons.check_circle : Icons.pending;

  String get paidAtFormatted {
    if (paidAt == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(paidAt!);
  }

  bool get bisaDibayar {
    if (isPaid) return false;
    if (statusLembur?.toLowerCase() == 'dibatalkan') return false;
    if (!['disetujui', 'selesai', 'approved'].contains(statusLembur?.toLowerCase())) return false;
    if (statusAbsensi != 'selesai' && statusAbsensi != 'selesai_terlambat') return false;

    final isTerlambat = statusAbsensi == 'selesai_terlambat';
    if (isTerlambat) {
      final hasDokumentasi = fotoUrl != null && fotoUrl!.isNotEmpty;
      final hasAlasan = keterlambatanAlasan != null && keterlambatanAlasan!.isNotEmpty;
      return hasDokumentasi && hasAlasan;
    }
    return absensiWaktu != null && completedAt != null;
  }
}

// ============================================================
// 🔥 PENDAPATAN SERVICE - V4 PAKAI OVERTIME RATE SERVICE
// ============================================================

class PendapatanService {
  static final PendapatanService _instance = PendapatanService._internal();
  factory PendapatanService() => _instance;
  PendapatanService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OvertimeRateService _rateService = OvertimeRateService(); // 🔥 Pakai OvertimeRateService
  static const String _cLembur = 'lembur_mitra';

  // 🔥 Cache untuk rates & tarif
  Map<String, dynamic>? _cachedRates;
  DateTime? _lastRatesFetch;
  static const Duration _ratesCache = Duration(minutes: 5);

  static const List<String> _validStatuses = [
    'pending', 'manager_approved', 'pending_hsse',
    'manager_approval_pending_hsse', 'manager_approved_pending_hsse',
    'disetujui', 'approved', 'selesai', 'ditolak',
  ];

  bool _isValidStatus(String? status) {
    if (status == null) return false;
    return _validStatuses.contains(status.toLowerCase());
  }

  bool _isDibatalkan(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    return status == 'dibatalkan';
  }

  // ============================================================
  // 🔥 CEK PERSYARATAN BAYAR (SAMA DENGAN REPORT SERVICE)
  // ============================================================

  Map<String, dynamic> _cekPersyaratanBayar(Map<String, dynamic> data) {
    final status = data['status']?.toString().toLowerCase() ?? '';
    final absensiStatus = data['absensi_status']?.toString() ?? '';
    final isPaid = data['is_paid'] == true || data['isPaid'] == true;
    final isTerlambat = absensiStatus == 'selesai_terlambat';

    final hasCheckIn = data['check_in_time'] != null ||
                      data['check_in_waktu'] != null ||
                      data['check_in'] != null ||
                      data['absensi_waktu'] != null;

    final hasCheckOut = data['check_out_time'] != null ||
                       data['check_out_waktu'] != null ||
                       data['check_out'] != null ||
                       data['completed_at'] != null;

    final fotoCheckIn = data['check_in_foto_url'] ??
                       data['absensi_foto_url'] ??
                       data['foto_url'] ??
                       data['bukti_foto_url'];
    final fotoCheckOut = data['check_out_foto_url'] ?? data['foto_check_out'];
    final hasDokumentasi = (fotoCheckIn != null && fotoCheckIn.toString().isNotEmpty) ||
                           (fotoCheckOut != null && fotoCheckOut.toString().isNotEmpty);

    String? keterlambatanAlasan;
    if (data['absensi_keterlambatan'] is Map) {
      final map = data['absensi_keterlambatan'] as Map;
      keterlambatanAlasan = map['alasan']?.toString();
    }
    final hasAlasan = keterlambatanAlasan != null && keterlambatanAlasan.isNotEmpty;

    bool isValid;
    final List<String> syaratKurang = [];

    if (isPaid) {
      isValid = false;
      syaratKurang.add('Sudah dibayar');
    } else if (_isDibatalkan(data)) {
      isValid = false;
      syaratKurang.add('Pengajuan dibatalkan');
    } else if (!['disetujui', 'selesai', 'approved'].contains(status)) {
      isValid = false;
      syaratKurang.add('Status: $status');
    } else if (absensiStatus != 'selesai' && absensiStatus != 'selesai_terlambat') {
      isValid = false;
      syaratKurang.add('Absensi: $absensiStatus');
    } else if (isTerlambat) {
      if (!hasDokumentasi) syaratKurang.add('Tidak ada dokumentasi/bukti');
      if (!hasAlasan) syaratKurang.add('Tidak ada alasan keterlambatan');
      isValid = hasDokumentasi && hasAlasan;
    } else {
      if (!hasCheckIn) syaratKurang.add('Belum check-in');
      if (!hasCheckOut) syaratKurang.add('Belum check-out');
      if (!hasDokumentasi) syaratKurang.add('Tidak ada foto bukti');
      isValid = hasCheckIn && hasCheckOut && hasDokumentasi;
    }

    return {
      'valid': isValid,
      'syarat_kurang': syaratKurang,
      'detail': {
        'status': status,
        'absensi_status': absensiStatus,
        'is_terlambat': isTerlambat,
        'has_check_in': hasCheckIn,
        'has_check_out': hasCheckOut,
        'has_dokumentasi': hasDokumentasi,
        'alasan_keterlambatan': keterlambatanAlasan,
        'has_alasan_keterlambatan': hasAlasan,
        'is_paid': isPaid,
        'is_dibatalkan': _isDibatalkan(data),
      }
    };
  }

  // ============================================================
  // 🔥 LOAD RATES - DARI OVERTIME RATE SERVICE (FIRESTORE)
  // ============================================================

  Future<Map<String, dynamic>> _loadRates() async {
    // Gunakan cache lokal untuk performance
    if (_cachedRates != null && _lastRatesFetch != null &&
        DateTime.now().difference(_lastRatesFetch!) < _ratesCache) {
      return _cachedRates!;
    }

    // 🔥 AMBIL DARI OVERTIME RATE SERVICE (FIRESTORE)
    try {
      final rates = await _rateService.loadOvertimeRates();
      _cachedRates = rates;
      _lastRatesFetch = DateTime.now();
      debugPrint('✅ PendapatanService: Rates loaded from OvertimeRateService');
      return rates;
    } catch (e) {
      debugPrint('❌ PendapatanService: Gagal load rates, pakai default: $e');
      _cachedRates = _getDefaultRates();
      _lastRatesFetch = DateTime.now();
      return _cachedRates!;
    }
  }

  Map<String, dynamic> _getDefaultRates() {
    const defaultGaji = 3000000.0;
    final upahPerJam = defaultGaji / 173;
    return {
      'base_salary': defaultGaji,
      'rate_per_hour': upahPerJam.roundToDouble(),
      'jam_kerja_per_bulan': 173,
      'weekday_rate': {
        'first_hour_multiplier': 1.5,
        'next_hours_multiplier': 2.0,
        'is_active': true,
      },
      'holiday_rate': {
        'first_8_hours_multiplier': 2.0,
        'ninth_hour_multiplier': 3.0,
        'tenth_plus_multiplier': 4.0,
        'is_active': true,
      },
    };
  }

  Future<double> getTarifPerJam() async {
    final rates = await _loadRates();
    return (rates['rate_per_hour'] as num?)?.toDouble() ?? (3000000.0 / 173).roundToDouble();
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 STREAM PENDAPATAN - REAL-TIME DENGAN TARIF AKURAT
  // ═══════════════════════════════════════════════════════

  Stream<List<PendapatanItem>> getPendapatanStream({
    required String mitraId,
    String? bulan,
  }) {
    debugPrint('💰 [REAL-TIME] getPendapatanStream: mitraId=$mitraId, bulan=$bulan');

    var query = _firestore
        .collection(_cLembur)
        .where('mitra_id', isEqualTo: mitraId)
        .where('absensi_status', whereIn: ['selesai', 'selesai_terlambat']);

    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }

    return query.orderBy('tanggal', descending: true).snapshots().asyncMap((snapshot) async {
      debugPrint('💰 [REAL-TIME] Update diterima: ${snapshot.docs.length} dokumen');
      final items = await _parseDocuments(snapshot.docs);
      debugPrint('💰 [REAL-TIME] Selesai parse: ${items.length} items');
      return items;
    }).handleError((error, stackTrace) {
      debugPrint('❌ [REAL-TIME] Stream error: $error');
      throw error;
    });
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 PARSE DOCUMENTS - DENGAN TARIF DARI OVERTIME RATE SERVICE
  // ═══════════════════════════════════════════════════════

  Future<List<PendapatanItem>> _parseDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    // 🔥 LOAD RATES SEKALI untuk semua dokumen
    final rates = await _loadRates();
    final baseRatePerHour = (rates['rate_per_hour'] as num?)?.toDouble() ?? (3000000.0 / 173).roundToDouble();
    
    debugPrint('💰 Base rate per hour: Rp ${NumberFormat('#,###').format(baseRatePerHour)}');

    final List<PendapatanItem> items = [];

    for (var doc in docs) {
      try {
        final data = doc.data();

        if (_isDibatalkan(data)) continue;
        if (!_isValidStatus(data['status']?.toString())) continue;

        final tanggal = (data['tanggal'] as Timestamp?)?.toDate() ??
            (data['tanggal_lembur'] as Timestamp?)?.toDate() ??
            DateTime.now();
        final jamMulai = data['jam_mulai']?.toString() ?? '';
        final jamSelesai = data['jam_selesai']?.toString() ?? '';

        // ═══════════════ TOTAL JAM ═══════════════
        DateTime? absensiWaktu;
        DateTime? completedAt;

        if (data['absensi_waktu'] is Timestamp) {
          absensiWaktu = (data['absensi_waktu'] as Timestamp).toDate();
        }
        if (data['check_in_waktu'] is Timestamp) {
          absensiWaktu ??= (data['check_in_waktu'] as Timestamp).toDate();
        }
        if (data['check_in_time'] is Timestamp) {
          absensiWaktu ??= (data['check_in_time'] as Timestamp).toDate();
        }
        if (data['check_in'] is Timestamp) {
          absensiWaktu ??= (data['check_in'] as Timestamp).toDate();
        }

        if (data['completed_at'] is Timestamp) {
          completedAt = (data['completed_at'] as Timestamp).toDate();
        }
        if (data['check_out_waktu'] is Timestamp) {
          completedAt ??= (data['check_out_waktu'] as Timestamp).toDate();
        }
        if (data['check_out_time'] is Timestamp) {
          completedAt ??= (data['check_out_time'] as Timestamp).toDate();
        }
        if (data['check_out'] is Timestamp) {
          completedAt ??= (data['check_out'] as Timestamp).toDate();
        }
        if (data['absensi_checkout_waktu'] is Timestamp) {
          completedAt ??= (data['absensi_checkout_waktu'] as Timestamp).toDate();
        }

        double totalJam = 0;

        if (absensiWaktu != null && completedAt != null) {
          final durasi = completedAt.difference(absensiWaktu);
          totalJam = durasi.inMinutes / 60.0;
        }

        if (totalJam == 0) {
          totalJam = (data['actual_total_jam'] as num?)?.toDouble() ?? 0;
        }
        if (totalJam == 0) {
          totalJam = (data['total_jam_real'] as num?)?.toDouble() ?? 0;
        }
        if (totalJam == 0) {
          totalJam = (data['total_jam_desimal'] as num?)?.toDouble() ?? 0;
        }
        if (totalJam == 0 && jamMulai.isNotEmpty && jamSelesai.isNotEmpty) {
          final partsMulai = jamMulai.split(':');
          final partsSelesai = jamSelesai.split(':');
          if (partsMulai.length == 2 && partsSelesai.length == 2) {
            final h1 = int.tryParse(partsMulai[0]) ?? 0;
            final m1 = int.tryParse(partsMulai[1]) ?? 0;
            final h2 = int.tryParse(partsSelesai[0]) ?? 0;
            final m2 = int.tryParse(partsSelesai[1]) ?? 0;
            totalJam = ((h2 * 60 + m2) - (h1 * 60 + m1)) / 60.0;
            if (totalJam < 0) totalJam += 24;
          }
        }

        // ═══════════════ PENDAPATAN - AMBIL DARI FIRESTORE, FALLBACK HITUNG ═══════════════
        final jenisLembur = data['jenis_lembur']?.toString() ?? 'hari_kerja';
        final statusAbsensi = data['absensi_status']?.toString() ?? '';
        final statusLembur = data['status']?.toString() ?? '';

        // 🔥 AMBIL INCOME DARI FIRESTORE (field sama dengan ReportService)
        double estimasiPendapatan = (data['actual_income'] as num?)?.toDouble() ??
            (data['income_amount'] as num?)?.toDouble() ??
            (data['income'] as num?)?.toDouble() ??
            (data['pendapatan_actual'] as num?)?.toDouble() ??
            (data['total_bayaran'] as num?)?.toDouble() ??
            (data['pendapatan'] as num?)?.toDouble() ??
            0;

        double tarifPerJam = (data['rate_per_hour'] as num?)?.toDouble() ?? 0;

        // 🔥 FALLBACK: Hitung pakai OvertimeRateService kalau income = 0
        if (estimasiPendapatan == 0 && totalJam > 0) {
          final isHoliday = jenisLembur.toLowerCase() == 'hari_libur';
          
          // 🔥 GUNAKAN OVERTIME RATE SERVICE UNTUK KALKULASI AKURAT
          estimasiPendapatan = _rateService.calculateOvertimeCost(
            totalHours: totalJam,
            isHoliday: isHoliday,
            rates: rates,
          );
          
          tarifPerJam = estimasiPendapatan / totalJam;
          
          debugPrint('💰 ${doc.id}: HITUNG via OvertimeRateService = Rp ${NumberFormat('#,###').format(estimasiPendapatan)} '
              '(${totalJam.toStringAsFixed(1)} jam, ${isHoliday ? "LIBUR" : "KERJA"})');
        } else if (tarifPerJam == 0 && totalJam > 0) {
          tarifPerJam = estimasiPendapatan / totalJam;
        }

        // ═══════════════ CEK PERSYARATAN BAYAR ═══════════════
        final cekSyarat = _cekPersyaratanBayar(data);
        final memenuhiSyarat = cekSyarat['valid'] == true;
        final syaratBelum = (cekSyarat['syarat_kurang'] as List?)?.cast<String>() ?? [];

        // ═══════════════ PARSE LAINNYA ═══════════════
        String? lokasi;
        final locData = data['lokasi'];
        if (locData is Map) {
          lokasi = (locData['alamat'] ?? locData['nama_lokasi'] ?? 'Kantor').toString();
        } else if (locData is String) {
          lokasi = locData;
        } else {
          lokasi = 'Kantor';
        }

        final isPaid = data['is_paid'] == true || data['isPaid'] == true ||
            data['gaji_diturunkan'] == true || data['status_bayar'] == 'dibayar' ||
            data['status_bayar'] == 'sudah_dibayar' || data['status_pembayaran'] == 'lunas';

        DateTime? paidAt;
        if (data['paid_at'] is Timestamp) paidAt = (data['paid_at'] as Timestamp).toDate();
        if (data['gaji_diturunkan_at'] is Timestamp) {
          paidAt ??= (data['gaji_diturunkan_at'] as Timestamp).toDate();
        }

        final paidByName = data['paid_by_name']?.toString() ??
            data['gaji_diturunkan_oleh']?.toString() ??
            data['paid_by']?.toString();

        final paidNote = data['paid_note']?.toString() ??
            data['gaji_catatan']?.toString();

        String? keterlambatanAlasan;
        if (data['absensi_keterlambatan'] is Map) {
          final map = data['absensi_keterlambatan'] as Map;
          keterlambatanAlasan = map['alasan']?.toString();
        }
        if (data['keterlambatan_alasan'] != null) {
          keterlambatanAlasan ??= data['keterlambatan_alasan']?.toString();
        }

        debugPrint('💰 ${doc.id}: jam=$totalJam, tarif=$tarifPerJam, '
            'pendapatan=$estimasiPendapatan, isPaid=$isPaid, '
            'memenuhiSyarat=$memenuhiSyarat');

        items.add(PendapatanItem(
          id: doc.id,
          lemburId: data['lembur_id']?.toString() ?? doc.id,
          groupId: data['group_id']?.toString() ?? '',
          tanggal: tanggal,
          jamMulai: jamMulai,
          jamSelesai: jamSelesai,
          totalJam: totalJam,
          jenisLembur: jenisLembur,
          statusAbsensi: statusAbsensi,
          statusLembur: statusLembur,
          absensiWaktu: absensiWaktu,
          completedAt: completedAt,
          tarifPerJam: tarifPerJam,
          estimasiPendapatan: estimasiPendapatan,
          fotoUrl: data['absensi_foto_url']?.toString() ?? data['check_in_foto_url']?.toString(),
          lokasi: lokasi,
          namaPengawas: data['nama_pengawas']?.toString() ?? data['diajukan_oleh_nama']?.toString() ?? '-',
          createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? tanggal,
          isPaid: isPaid,
          paidAt: paidAt,
          paidByName: paidByName,
          paidNote: paidNote,
          keterlambatanAlasan: keterlambatanAlasan,
          memenuhiSyaratBayar: memenuhiSyarat,
          syaratBelumTerpenuhi: syaratBelum,
        ));
      } catch (e) {
        debugPrint('❌ Error parsing doc ${doc.id}: $e');
      }
    }

    items.sort((a, b) => b.tanggal.compareTo(a.tanggal));

    final totalEstimasi = items.fold(0.0, (sum, i) => sum + i.estimasiPendapatan);
    final totalDibayar = items.where((i) => i.isPaid).fold(0.0, (sum, i) => sum + i.estimasiPendapatan);
    final totalBelum = items.where((i) => !i.isPaid).fold(0.0, (sum, i) => sum + i.estimasiPendapatan);

    debugPrint('💰 [REAL-TIME] Total: ${items.length} items | '
        'Pendapatan: Rp ${NumberFormat('#,###').format(totalEstimasi)} | '
        'Dibayar: ${items.where((i) => i.isPaid).length} | '
        'Belum: ${items.where((i) => !i.isPaid).length}');

    return items;
  }

  void clearCache() {
    _cachedRates = null;
    _lastRatesFetch = null;
    _rateService.clearCache(); // 🔥 Clear cache OvertimeRateService juga
  }
}