import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ═══════════════════════════════════════════════════════
// 📦 MODEL: LaporanItem
// ═══════════════════════════════════════════════════════

class LaporanItem {
  // ─── BASIC INFO ───
  final String id;
  final String groupId;

  // ─── MITRA INFO ───
  final String? mitraId;
  final String? namaMitra;
  final String? fungsiMitra;
  final String? noHpMitra;

  // ─── PENGAWAS INFO ───
  final String? pengawasId;
  final String? namaPengawas;
  final String? pengawasFungsi;

  // ─── WAKTU & DURASI ───
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final double totalJam;
  final double totalJamReal;

  // ─── DETAIL LEMBUR ───
  final String jenisLembur;
  final String urgensi;
  final String alasan;
  final String? lokasiNama;
  final String? lokasiAlamat;

  // ─── BIAYA / PENDAPATAN ───
  final double estimasiBiaya;
  final double pendapatanActual;
  final double ratePerJam;

  // ─── STATUS UTAMA ───
  final String status;

  // ─── ABSENSI ───
  final String absensiStatus;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? checkInFotoUrl;
  final String? checkOutFotoUrl;
  final bool isTerlambat;
  final String? keterlambatanAlasan;

  // ─── HSSE ───
  final bool isRisky;
  final String? risikoLevel;

  // ─── PEMBAYARAN ───
  final bool isPaid;
  final DateTime? paidAt;
  final String? paidBy;
  final String? paidByName;
  final String? paidNote;

  // ─── TIMESTAMPS ───
  final DateTime createdAt;
  final DateTime updatedAt;
  final String tahunBulan;

  // ─── RAW DATA ───
  final Map<String, dynamic> rawData;

  LaporanItem({
    required this.id,
    required this.groupId,
    this.mitraId,
    this.namaMitra,
    this.fungsiMitra,
    this.noHpMitra,
    this.pengawasId,
    this.namaPengawas,
    this.pengawasFungsi,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.totalJam,
    required this.totalJamReal,
    required this.jenisLembur,
    required this.urgensi,
    required this.alasan,
    this.lokasiNama,
    this.lokasiAlamat,
    required this.estimasiBiaya,
    required this.pendapatanActual,
    required this.ratePerJam,
    required this.status,
    required this.absensiStatus,
    this.checkInTime,
    this.checkOutTime,
    this.checkInFotoUrl,
    this.checkOutFotoUrl,
    this.isTerlambat = false,
    this.keterlambatanAlasan,
    this.isRisky = false,
    this.risikoLevel,
    this.isPaid = false,
    this.paidAt,
    this.paidBy,
    this.paidByName,
    this.paidNote,
    required this.createdAt,
    required this.updatedAt,
    required this.tahunBulan,
    required this.rawData,
  });

  // ═══════════════════════════════════════════════════════
  // 🔥 FROM FIRESTORE
  // ═══════════════════════════════════════════════════════

  factory LaporanItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // ─── HELPERS ───
    DateTime parseTanggal(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime(2000);
    }

    DateTime? parseTimestampOrNull(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    String parseString(dynamic val, [String fallback = '']) {
      if (val == null) return fallback;
      return val.toString();
    }

    // ─── TANGGAL ───
    final tanggal = parseTanggal(data['tanggal'] ?? data['tanggal_lembur']);

    // ─── TOTAL JAM ───
    final totalJam = parseDouble(
        data['total_jam_desimal'] ?? data['total_jam'] ?? data['total_jam_rencana'] ?? 0);
    final totalJamReal = parseDouble(
        data['total_jam_real'] ?? data['actual_total_jam'] ?? data['total_jam_actual'] ?? totalJam);

    // ─── BIAYA ───
    final estimasiBiaya = parseDouble(
        data['estimasi_biaya_total'] ?? data['estimasi_biaya'] ?? data['estimasi_biaya_per_mitra'] ?? 0);
    final pendapatanActual = parseDouble(
        data['actual_income'] ?? data['income'] ?? data['income_amount'] ??
        data['pendapatan_actual'] ?? data['total_bayaran'] ?? data['pendapatan'] ?? 0);

    // ─── RATE PER JAM ───
    final divider = totalJamReal > 0 ? totalJamReal : totalJam;
    final ratePerJam = divider > 0
        ? (pendapatanActual > 0 ? pendapatanActual : estimasiBiaya) / divider
        : 0.0;

    // ─── CHECK-IN / CHECK-OUT TIME ───
    final checkInTime = parseTimestampOrNull(
      data['check_in_time'] ?? data['check_in_waktu'] ?? data['check_in'] ?? data['absensi_waktu']);
    final checkOutTime = parseTimestampOrNull(
      data['check_out_time'] ?? data['check_out_waktu'] ?? data['check_out'] ?? data['completed_at']);

    // ─── FOTO ───
    final checkInFotoUrl = parseString(
        data['check_in_foto_url'] ?? data['absensi_foto_url'] ?? data['foto_url'] ?? data['bukti_foto_url']);
    final checkOutFotoUrl = parseString(data['check_out_foto_url'] ?? data['foto_check_out']);

    // ─── ABSENSI STATUS ───
    final absensiStatus = parseString(data['absensi_status'], 'belum_absen');

    // ─── KETERLAMBATAN ───
    bool isTerlambat = absensiStatus == 'selesai_terlambat' ||
        absensiStatus == 'selesai_terlambat_checkout';
    String? keterlambatanAlasan;

    // Alasan terlambat CHECK-IN (ditulis oleh konfirmasiKeterlambatan)
    if (data['absensi_keterlambatan'] is Map) {
      final map = data['absensi_keterlambatan'] as Map;
      if (map['melakukan_lembur'] == true) isTerlambat = true;
      keterlambatanAlasan = map['alasan']?.toString();
    }

    // 🔥 Alasan terlambat CHECKOUT (field terpisah, ditulis oleh
    // konfirmasiKeterlambatanCheckOut) — prioritaskan jika ada, karena ini
    // yang relevan untuk status 'selesai_terlambat_checkout'.
    if (data['checkout_keterlambatan'] is Map) {
      final map = data['checkout_keterlambatan'] as Map;
      final checkoutAlasan = map['alasan']?.toString();
      if (checkoutAlasan != null && checkoutAlasan.isNotEmpty) {
        keterlambatanAlasan = checkoutAlasan;
      }
    }

    // ─── PEMBAYARAN ───
    final isPaid =
        data['is_paid'] == true ||
        data['isPaid'] == true ||
        data['gaji_diturunkan'] == true ||
        data['status_bayar'] == 'dibayar' ||
        data['status_bayar'] == 'sudah_dibayar' ||
        data['status_pembayaran'] == 'lunas' ||
        data['paid'] == true ||
        data['is_paid'] == 'true' ||
        data['isPaid'] == 'true';

    final paidAt = parseTimestampOrNull(data['paid_at'] ?? data['gaji_diturunkan_at']);
    final paidBy = parseString(data['paid_by'] ?? data['gaji_diturunkan_oleh']);
    final paidByName = parseString(data['paid_by_name']);
    final paidNote = parseString(data['paid_note'] ?? data['gaji_catatan']);

    // ─── LOKASI ───
    String? lokasiNama;
    String? lokasiAlamat;
    if (data['lokasi'] is Map) {
      final lok = data['lokasi'] as Map;
      lokasiNama = lok['nama']?.toString() ?? lok['name']?.toString();
      lokasiAlamat = lok['alamat']?.toString() ?? lok['address']?.toString();
    }

    // ─── HSSE ───
    final isRisky = data['is_risky'] == true || data['requires_hsse_approval'] == true;
    final risikoLevel = parseString(data['risiko_level'] ?? data['risk_level']);

    return LaporanItem(
      id: doc.id,
      groupId: parseString(data['group_id'], doc.id),
      mitraId: parseString(data['mitra_id']),
      namaMitra: parseString(data['nama_mitra'] ?? data['mitra_nama']),
      fungsiMitra: parseString(data['fungsi_mitra']),
      noHpMitra: parseString(data['no_hp_mitra']),
      pengawasId: parseString(data['pengawas_id'] ?? data['diajukan_oleh_id']),
      namaPengawas: parseString(data['nama_pengawas'] ?? data['diajukan_oleh_nama']),
      pengawasFungsi: parseString(data['pengawas_fungsi']),
      tanggal: tanggal,
      jamMulai: parseString(data['jam_mulai']),
      jamSelesai: parseString(data['jam_selesai']),
      totalJam: totalJam,
      totalJamReal: totalJamReal,
      jenisLembur: parseString(data['jenis_lembur'], 'hari_kerja'),
      urgensi: parseString(data['urgensi'], 'normal'),
      alasan: parseString(data['alasan']),
      lokasiNama: lokasiNama,
      lokasiAlamat: lokasiAlamat,
      estimasiBiaya: estimasiBiaya,
      pendapatanActual: pendapatanActual,
      ratePerJam: ratePerJam,
      status: parseString(data['status'], 'pending'),
      absensiStatus: absensiStatus,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      checkInFotoUrl: checkInFotoUrl.isNotEmpty ? checkInFotoUrl : null,
      checkOutFotoUrl: checkOutFotoUrl.isNotEmpty ? checkOutFotoUrl : null,
      isTerlambat: isTerlambat,
      keterlambatanAlasan: keterlambatanAlasan,
      isRisky: isRisky,
      risikoLevel: risikoLevel.isNotEmpty ? risikoLevel : null,
      isPaid: isPaid,
      paidAt: paidAt,
      paidBy: paidBy.isNotEmpty ? paidBy : null,
      paidByName: paidByName.isNotEmpty ? paidByName : null,
      paidNote: paidNote.isNotEmpty ? paidNote : null,
      createdAt: parseTanggal(data['created_at']),
      updatedAt: parseTanggal(data['updated_at']),
      tahunBulan: parseString(
          data['tahun_bulan'],
          DateFormat('yyyy-MM').format(tanggal)),
      rawData: data,
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 PERSYARATAN BAYAR V6 - DENGAN RELAKSASI TERLAMBAT
  // ═══════════════════════════════════════════════════════

  /// Cek apakah item ini memenuhi semua syarat untuk bisa dibayar
  bool get memenuhiSyaratBayar {
    if (isPaid) return false; // Sudah dibayar
    if (status == 'dibatalkan') return false; // Dibatalkan
    if (!['disetujui', 'selesai', 'approved'].contains(status)) return false; // Status tidak valid
    if (!['selesai', 'selesai_terlambat', 'selesai_terlambat_checkout']
        .contains(absensiStatus)) return false; // Absensi belum selesai

    // 🔥🔥🔥 RELAKSASI UNTUK LEMBUR TERLAMBAT (termasuk terlambat checkout)
    // Syarat: dokumentasi/bukti + alasan keterlambatan (TANPA check-in/out)
    if (absensiStatus == 'selesai_terlambat' ||
        absensiStatus == 'selesai_terlambat_checkout') {
      final hasDokumentasi = (checkInFotoUrl != null && checkInFotoUrl!.isNotEmpty) ||
                             (checkOutFotoUrl != null && checkOutFotoUrl!.isNotEmpty);
      final hasAlasan = keterlambatanAlasan != null && keterlambatanAlasan!.isNotEmpty;
      return hasDokumentasi && hasAlasan;
    }

    // 🔥 Untuk lembur NORMAL: check-in, check-out, foto wajib
    if (checkInTime == null) return false;
    if (checkOutTime == null) return false;
    if (checkInFotoUrl == null || checkInFotoUrl!.isEmpty) return false;
    return true;
  }

  /// List persyaratan yang belum terpenuhi
  List<String> get syaratBelumTerpenuhi {
    final List<String> belum = [];
    if (isPaid) belum.add('Sudah dibayar');
    if (status == 'dibatalkan') belum.add('Pengajuan dibatalkan');
    if (!['disetujui', 'selesai', 'approved'].contains(status)) {
      belum.add('Status belum disetujui (${statusLabel})');
    }
    if (!['selesai', 'selesai_terlambat', 'selesai_terlambat_checkout']
        .contains(absensiStatus)) {
      belum.add('Absensi belum selesai (${absensiLabel})');
    }

    // 🔥🔥🔥 RELAKSASI UNTUK LEMBUR TERLAMBAT (termasuk terlambat checkout)
    if (absensiStatus == 'selesai_terlambat' ||
        absensiStatus == 'selesai_terlambat_checkout') {
      final hasDokumentasi = (checkInFotoUrl != null && checkInFotoUrl!.isNotEmpty) ||
                             (checkOutFotoUrl != null && checkOutFotoUrl!.isNotEmpty);
      final hasAlasan = keterlambatanAlasan != null && keterlambatanAlasan!.isNotEmpty;
      if (!hasDokumentasi) belum.add('Tidak ada dokumentasi/bukti');
      if (!hasAlasan) belum.add('Tidak ada alasan keterlambatan');
      return belum;
    }

    // Untuk normal
    if (checkInTime == null) belum.add('Belum check-in');
    if (checkOutTime == null) belum.add('Belum check-out');
    if (checkInFotoUrl == null || checkInFotoUrl!.isEmpty) {
      belum.add('Tidak ada foto bukti check-in');
    }
    return belum;
  }

  /// Cek persyaratan per-komponen (untuk tampilan detail)
  Map<String, bool> get cekPersyaratanBayar {
    final isTerlambat = absensiStatus == 'selesai_terlambat' ||
        absensiStatus == 'selesai_terlambat_checkout';
    final hasDokumentasi = (checkInFotoUrl != null && checkInFotoUrl!.isNotEmpty) ||
                           (checkOutFotoUrl != null && checkOutFotoUrl!.isNotEmpty);
    final hasAlasan = keterlambatanAlasan != null && keterlambatanAlasan!.isNotEmpty;

    return {
      'status_valid': ['disetujui', 'selesai', 'approved'].contains(status),
      'tidak_dibatalkan': status != 'dibatalkan',
      'absensi_selesai': ['selesai', 'selesai_terlambat', 'selesai_terlambat_checkout']
          .contains(absensiStatus),
      // 🔥 Untuk terlambat: selalu true (tidak diperlukan check-in/out)
      'sudah_check_in': isTerlambat ? true : checkInTime != null,
      'sudah_check_out': isTerlambat ? true : checkOutTime != null,
      // 🔥 Untuk terlambat: pakai key dokumentasi, untuk normal: foto check-in
      'ada_dokumentasi': isTerlambat ? hasDokumentasi : (checkInFotoUrl != null && checkInFotoUrl!.isNotEmpty),
      'ada_alasan_terlambat': isTerlambat ? hasAlasan : true,
      'belum_dibayar': !isPaid,
    };
  }

  // ═══════════════════════════════════════════════════════
  // COMPUTED PROPERTIES
  // ═══════════════════════════════════════════════════════

  String get tanggalFormatted =>
      DateFormat('dd MMM yyyy', 'id_ID').format(tanggal);

  String get tanggalFullFormatted =>
      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggal);

  String get durasiFormatted => '${totalJam.toStringAsFixed(1)} Jam';

  String get durasiRealFormatted => '${totalJamReal.toStringAsFixed(1)} Jam';

  double get biayaAktual {
    if (pendapatanActual > 0) return pendapatanActual;
    if (estimasiBiaya > 0) return estimasiBiaya;
    if (ratePerJam > 0 && totalJamReal > 0) return ratePerJam * totalJamReal;
    try {
      final raw = rawData;
      final val = raw['pendapatan'] ?? raw['total_bayaran'] ?? raw['income'] ?? 0;
      if (val is num && val > 0) return val.toDouble();
    } catch (_) {}
    return 0;
  }

  String get biayaFormatted => ReportService.formatRupiah(biayaAktual);
  String get estimasiBiayaFormatted => ReportService.formatRupiah(estimasiBiaya);
  String get ratePerJamFormatted => ReportService.formatRupiah(ratePerJam);

  String get checkInFormatted {
    if (checkInTime == null) return '-';
    return DateFormat('HH:mm', 'id_ID').format(checkInTime!);
  }

  String get checkOutFormatted {
    if (checkOutTime == null) return '-';
    return DateFormat('HH:mm', 'id_ID').format(checkOutTime!);
  }

  String get checkInFullFormatted {
    if (checkInTime == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(checkInTime!);
  }

  String get checkOutFullFormatted {
    if (checkOutTime == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(checkOutTime!);
  }

  String get absensiLabel {
    switch (absensiStatus) {
      case 'belum_absen': return '⏳ Belum Absen';
      case 'check_in':
      case 'sudah_absen': return '📥 Check In';
      case 'check_out': return '📤 Check Out';
      case 'selesai': return '✅ Selesai';
      case 'selesai_terlambat': return '⚠️ Terlambat';
      case 'selesai_terlambat_checkout': return '⚠️ Terlambat Checkout';
      case 'tidak_lembur': return '❌ Tidak Lembur';
      case 'expired': return '⏰ Kadaluarsa';
      default: return absensiStatus;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Pending';
      case 'manager_approved': return 'Disetujui Manager';
      case 'pending_hsse':
      case 'manager_approval_pending_hsse':
      case 'manager_approved_pending_hsse': return 'Menunggu HSSE';
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      case 'selesai': return 'Selesai';
      case 'dibatalkan': return 'Dibatalkan';
      case 'kadaluarsa': return 'Kadaluarsa';
      default: return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'manager_approved': return Colors.blue;
      case 'pending_hsse':
      case 'manager_approval_pending_hsse':
      case 'manager_approved_pending_hsse': return Colors.deepOrange;
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      case 'selesai': return Colors.teal;
      case 'dibatalkan':
      case 'kadaluarsa': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Color get absensiColor {
    switch (absensiStatus) {
      case 'check_in':
      case 'sudah_absen': return Colors.blue;
      case 'selesai': return Colors.green;
      case 'selesai_terlambat':
      case 'selesai_terlambat_checkout': return Colors.orange;
      case 'tidak_lembur':
      case 'expired': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData get absensiIcon {
    switch (absensiStatus) {
      case 'check_in':
      case 'sudah_absen': return Icons.login_rounded;
      case 'check_out': return Icons.logout_rounded;
      case 'selesai': return Icons.check_circle_rounded;
      case 'selesai_terlambat':
      case 'selesai_terlambat_checkout': return Icons.warning_amber_rounded;
      case 'tidak_lembur': return Icons.cancel_rounded;
      case 'expired': return Icons.timer_off_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  String get pembayaranLabel => isPaid ? '✅ Sudah Dibayar' : '💰 Belum Dibayar';
  Color get pembayaranColor => isPaid ? Colors.green : Colors.orange;
  IconData get pembayaranIcon => isPaid ? Icons.check_circle : Icons.pending_outlined;

  String get lokasiFormatted {
    if (lokasiNama != null && lokasiNama!.isNotEmpty) return lokasiNama!;
    if (lokasiAlamat != null && lokasiAlamat!.isNotEmpty) return lokasiAlamat!;
    return '-';
  }

  Map<String, dynamic> toExportMap() => {
        'id': id,
        'tanggal': tanggalFullFormatted,
        'nama_mitra': namaMitra ?? '-',
        'fungsi': fungsiMitra ?? pengawasFungsi ?? '-',
        'jam_mulai': jamMulai,
        'jam_selesai': jamSelesai,
        'total_jam': totalJamReal.toStringAsFixed(1),
        'status': statusLabel,
        'absensi': absensiLabel,
        'check_in': checkInFullFormatted,
        'check_out': checkOutFullFormatted,
        'biaya': biayaAktual,
        'rate_per_jam': ratePerJam,
        'pembayaran': isPaid ? 'Sudah' : 'Belum',
        'dibayar_oleh': paidByName ?? '-',
        'tanggal_bayar': paidAt != null
            ? DateFormat('dd/MM/yyyy').format(paidAt!)
            : '-',
        'lokasi': lokasiFormatted,
      };
}

// ═══════════════════════════════════════════════════════
// 📦 MODEL: LaporanSummary
// ═══════════════════════════════════════════════════════

class LaporanSummary {
  final int totalLaporan;
  final int totalDisetujui;
  final int totalSelesai;
  final int totalPending;
  final int totalDitolak;
  final int totalDibatalkan;
  final double totalJamRencana;
  final double totalJamReal;
  final double totalEstimasiBiaya;
  final double totalPendapatan;
  final int totalSudahDibayar;
  final int totalBelumDibayar;
  final double totalDibayar;
  final double totalBelumDibayarAmount;
  final double rataJamPerLaporan;
  final double rataPendapatanPerLaporan;
  final double rataRatePerJam;
  final int totalHadir;
  final int totalTerlambat;
  final int totalTidakHadir;
  final double persentaseHadir;
  final double persentaseDibayar;
  final DateTime? earliestTanggal;
  final DateTime? latestTanggal;
  final Map<String, int> distribusiFungsi;
  final Map<String, int> distribusiStatus;
  final Map<String, double> distribusiPendapatanPerFungsi;

  LaporanSummary({
    required this.totalLaporan,
    required this.totalDisetujui,
    required this.totalSelesai,
    required this.totalPending,
    required this.totalDitolak,
    required this.totalDibatalkan,
    required this.totalJamRencana,
    required this.totalJamReal,
    required this.totalEstimasiBiaya,
    required this.totalPendapatan,
    required this.totalSudahDibayar,
    required this.totalBelumDibayar,
    required this.totalDibayar,
    required this.totalBelumDibayarAmount,
    required this.rataJamPerLaporan,
    required this.rataPendapatanPerLaporan,
    required this.rataRatePerJam,
    required this.totalHadir,
    required this.totalTerlambat,
    required this.totalTidakHadir,
    required this.persentaseHadir,
    required this.persentaseDibayar,
    this.earliestTanggal,
    this.latestTanggal,
    required this.distribusiFungsi,
    required this.distribusiStatus,
    required this.distribusiPendapatanPerFungsi,
  });

  factory LaporanSummary.empty() => LaporanSummary(
        totalLaporan: 0, totalDisetujui: 0, totalSelesai: 0,
        totalPending: 0, totalDitolak: 0, totalDibatalkan: 0,
        totalJamRencana: 0, totalJamReal: 0,
        totalEstimasiBiaya: 0, totalPendapatan: 0,
        totalSudahDibayar: 0, totalBelumDibayar: 0,
        totalDibayar: 0, totalBelumDibayarAmount: 0,
        rataJamPerLaporan: 0, rataPendapatanPerLaporan: 0, rataRatePerJam: 0,
        totalHadir: 0, totalTerlambat: 0, totalTidakHadir: 0,
        persentaseHadir: 0, persentaseDibayar: 0,
        distribusiFungsi: {}, distribusiStatus: {}, distribusiPendapatanPerFungsi: {},
      );

  String get totalJamRealFormatted => '${totalJamReal.toStringAsFixed(1)} jam';
  String get totalPendapatanFormatted => ReportService.formatRupiah(totalPendapatan);
  String get totalDibayarFormatted => ReportService.formatRupiah(totalDibayar);
  String get totalBelumDibayarFormatted => ReportService.formatRupiah(totalBelumDibayarAmount);
  String get rataPendapatanFormatted => ReportService.formatRupiah(rataPendapatanPerLaporan);
}

// ═══════════════════════════════════════════════════════
// 📦 CACHE ENTRY
// ═══════════════════════════════════════════════════════

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  _CacheEntry({required this.data, required this.timestamp});
}

// ═══════════════════════════════════════════════════════
// 🔥 SERVICE: ReportService V6 - RELAKSASI TERLAMBAT
// ═══════════════════════════════════════════════════════

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _cLembur = 'lembur_mitra';
  static const String _cPengajuan = 'pengajuan_lembur';
  static const String _cLog = 'report_activity_logs';
  static const int _maxPageSize = 100;

  // 🔥 VALID STATUS (tidak termasuk dibatalkan)
  static const List<String> _validStatuses = [
    'pending',
    'manager_approved',
    'pending_hsse',
    'manager_approval_pending_hsse',
    'manager_approved_pending_hsse',
    'disetujui',
    'approved',
    'selesai',
    'ditolak',
  ];

  // CACHE
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

  void clearCache() => _cache.clear();

  // ═══════════════════════════════════════════════════════
  // FORMATTER
  // ═══════════════════════════════════════════════════════

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0,
  );

  static String formatRupiah(dynamic value) {
    final number = (value is num) ? value : 0.0;
    return _currencyFormat.format(number);
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 HELPER: Cek status dibatalkan
  // ═══════════════════════════════════════════════════════

  bool _isDibatalkan(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    return status == 'dibatalkan';
  }

  bool _isValidStatus(String? status) {
    if (status == null) return false;
    return _validStatuses.contains(status.toLowerCase());
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 HELPER: Cek persyaratan bayar V6 - RELAKSASI TERLAMBAT
  // ═══════════════════════════════════════════════════════

  Map<String, dynamic> _cekPersyaratanBayar(Map<String, dynamic> data) {
    final status = data['status']?.toString().toLowerCase() ?? '';
    final absensiStatus = data['absensi_status']?.toString() ?? '';
    final isPaid = data['is_paid'] == true || data['isPaid'] == true;
    final isTerlambat = absensiStatus == 'selesai_terlambat' ||
        absensiStatus == 'selesai_terlambat_checkout';

    // Check-in / Check-out
    final hasCheckIn = data['check_in_time'] != null ||
                      data['check_in_waktu'] != null ||
                      data['check_in'] != null;

    final hasCheckOut = data['check_out_time'] != null ||
                       data['check_out_waktu'] != null ||
                       data['check_out'] != null;

    // Foto / Dokumentasi
    final fotoCheckIn = data['check_in_foto_url'] ??
                       data['check_in_foto'] ??
                       data['absensi_foto_url'] ??
                       data['foto_check_in'] ??
                       data['foto_absensi'] ??
                       data['bukti_foto_url'];
    final fotoCheckOut = data['check_out_foto_url'] ?? data['foto_check_out'];
    final hasDokumentasi = (fotoCheckIn != null && fotoCheckIn.toString().isNotEmpty) ||
                           (fotoCheckOut != null && fotoCheckOut.toString().isNotEmpty);

    // Alasan keterlambatan
    String? keterlambatanAlasan;
    if (data['absensi_keterlambatan'] is Map) {
      final map = data['absensi_keterlambatan'] as Map;
      keterlambatanAlasan = map['alasan']?.toString();
    }
    // 🔥 Alasan terlambat CHECKOUT (field terpisah) — prioritaskan jika ada
    if (data['checkout_keterlambatan'] is Map) {
      final map = data['checkout_keterlambatan'] as Map;
      final checkoutAlasan = map['alasan']?.toString();
      if (checkoutAlasan != null && checkoutAlasan.isNotEmpty) {
        keterlambatanAlasan = checkoutAlasan;
      }
    }
    final hasAlasan = keterlambatanAlasan != null && keterlambatanAlasan.isNotEmpty;

    // 🔥🔥🔥 VALIDASI DENGAN RELAKSASI UNTUK TERLAMBAT
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
    } else if (!['selesai', 'selesai_terlambat', 'selesai_terlambat_checkout']
        .contains(absensiStatus)) {
      isValid = false;
      syaratKurang.add('Absensi: $absensiStatus');
    } else if (isTerlambat) {
      // 🔥 Untuk terlambat: hanya perlu dokumentasi & alasan
      if (!hasDokumentasi) syaratKurang.add('Tidak ada dokumentasi/bukti');
      if (!hasAlasan) syaratKurang.add('Tidak ada alasan keterlambatan');
      isValid = hasDokumentasi && hasAlasan;
    } else {
      // 🔥 Untuk normal: perlu check-in, check-out, foto
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
        'has_foto_check_in': hasDokumentasi,
        'has_dokumentasi': hasDokumentasi,
        'alasan_keterlambatan': keterlambatanAlasan,
        'has_alasan_keterlambatan': hasAlasan,
        'is_paid': isPaid,
        'is_dibatalkan': _isDibatalkan(data),
        'mitra_nama': data['nama_mitra'] ?? data['mitra_nama'] ?? 'Unknown',
      }
    };
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 STREAM UTAMA LAPORAN - ALL ROLES
  // ═══════════════════════════════════════════════════════

  Stream<List<LaporanItem>> getLaporanStream({
    required String userRole,
    String? userId,
    String? userFungsi,
    String? bulan,
    String? statusFilter,
    String? absensiFilter,
    String? fungsiFilter,
    bool? isPaidFilter,
    String? searchQuery,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(_cLembur);

    // 🔥 ROLE-BASED FILTERING
    switch (userRole.toLowerCase()) {
      case 'mitra':
        if (userId != null && userId.isNotEmpty) {
          query = query.where(
            Filter.or(
              Filter('mitra_id', isEqualTo: userId),
              Filter('mitra_ids', arrayContains: userId),
            ),
          );
        }
        break;
      case 'pengawas':
        if (userId != null && userId.isNotEmpty) {
          query = query.where(
            Filter.or(
              Filter('diajukan_oleh_id', isEqualTo: userId),
              Filter('pengawas_id', isEqualTo: userId),
            ),
          );
        }
        break;
      case 'manager':
        if (userFungsi != null && userFungsi.isNotEmpty) {
          query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
        }
        break;
      case 'superadmin':
        break;
      default:
        if (userId != null && userId.isNotEmpty) {
          query = query.where('mitra_id', isEqualTo: userId);
        }
    }

    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    if (fungsiFilter != null && fungsiFilter.isNotEmpty && fungsiFilter != 'semua') {
      query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
    }
    if (isPaidFilter != null) {
      query = query.where('is_paid', isEqualTo: isPaidFilter);
    }

    return query.orderBy('tanggal', descending: true).limit(limit).snapshots().map((snap) {
      // 🔥🔥🔥 FILTER: Exclude status DIBATALKAN + hanya status valid
      var items = snap.docs
          .where((doc) {
            final data = doc.data();
            return !_isDibatalkan(data) && _isValidStatus(data['status']?.toString());
          })
          .map((doc) => LaporanItem.fromFirestore(doc))
          .toList();

      // Filter absensi client-side
      if (absensiFilter != null && absensiFilter.isNotEmpty && absensiFilter != 'semua') {
        items = items.where((item) => item.absensiStatus == absensiFilter).toList();
      }

      // Search query client-side
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        items = items.where((item) {
          return (item.namaMitra?.toLowerCase().contains(q) ?? false) ||
              (item.namaPengawas?.toLowerCase().contains(q) ?? false) ||
              (item.pengawasFungsi?.toLowerCase().contains(q) ?? false) ||
              (item.fungsiMitra?.toLowerCase().contains(q) ?? false) ||
              item.id.toLowerCase().contains(q);
        }).toList();
      }

      return items;
    });
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 GET HISTORY WITH PAGINATION
  // ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getLaporanPaginated({
    required String userRole,
    String? userId,
    String? userFungsi,
    String? bulan,
    String? statusFilter,
    String? absensiFilter,
    String? fungsiFilter,
    bool? isPaidFilter,
    String? searchQuery,
    int page = 1,
    int pageSize = 20,
    bool useCache = true,
  }) async {
    try {
      pageSize = pageSize.clamp(1, _maxPageSize);

      final cacheKey = 'laporan_${userRole}_${userId}_${userFungsi}_${bulan}_${statusFilter}_'
          '${absensiFilter}_${fungsiFilter}_${isPaidFilter}_${searchQuery}_${page}_$pageSize';

      if (useCache) {
        final cached = _getCache(cacheKey);
        if (cached != null) return cached as Map<String, dynamic>;
      }

      final allItems = await getLaporanStream(
        userRole: userRole, userId: userId, userFungsi: userFungsi,
        bulan: bulan, statusFilter: statusFilter, absensiFilter: absensiFilter,
        fungsiFilter: fungsiFilter, isPaidFilter: isPaidFilter,
        searchQuery: searchQuery, limit: _maxPageSize,
      ).first;

      final totalCount = allItems.length;
      final totalPages = (totalCount / pageSize).ceil();
      final startIndex = (page - 1) * pageSize;
      final endIndex = startIndex + pageSize;

      final items = allItems.sublist(
        startIndex, endIndex > totalCount ? totalCount : endIndex,
      );

      final result = {
        'items': items, 'totalCount': totalCount,
        'currentPage': page, 'totalPages': totalPages,
        'hasMore': page < totalPages, 'pageSize': pageSize,
      };

      _setCache(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('❌ getLaporanPaginated error: $e');
      return {
        'items': <LaporanItem>[], 'totalCount': 0,
        'currentPage': page, 'totalPages': 0,
        'hasMore': false, 'pageSize': pageSize, 'error': e.toString(),
      };
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 SUMMARY - EXCLUDE DIBATALKAN
  // ═══════════════════════════════════════════════════════

  Future<LaporanSummary> getLaporanSummary({
    required String userRole,
    String? userId,
    String? userFungsi,
    String? bulan,
    String? fungsiFilter,
  }) async {
    try {
      final items = await getLaporanStream(
        userRole: userRole, userId: userId, userFungsi: userFungsi,
        bulan: bulan, fungsiFilter: fungsiFilter, limit: _maxPageSize,
      ).first;

      if (items.isEmpty) return LaporanSummary.empty();

      int disetujui = 0, selesaiStat = 0, pending = 0, ditolak = 0, dibatalkan = 0;
      double totalJamRencana = 0, totalJamReal = 0;
      double totalEstimasiBiaya = 0, totalPendapatan = 0;
      int sudahDibayar = 0, belumDibayar = 0;
      double totalDibayar = 0, totalBelumDibayarAmount = 0;
      int hadir = 0, terlambat = 0, tidakHadir = 0;
      DateTime? earliest, latest;
      Map<String, int> distribusiFungsi = {};
      Map<String, int> distribusiStatus = {};
      Map<String, double> distribusiPendapatanPerFungsi = {};

      for (var item in items) {
        switch (item.status) {
          case 'disetujui': disetujui++; break;
          case 'selesai': selesaiStat++; break;
          case 'pending': pending++; break;
          case 'ditolak': ditolak++; break;
          case 'dibatalkan': dibatalkan++; break;
        }

        totalJamRencana += item.totalJam;
        totalJamReal += item.totalJamReal;
        totalEstimasiBiaya += item.estimasiBiaya;

        final pendapatan = item.biayaAktual;
        totalPendapatan += pendapatan;

        if (item.isPaid) {
          sudahDibayar++;
          totalDibayar += pendapatan;
        } else {
          belumDibayar++;
          totalBelumDibayarAmount += pendapatan;
        }

        switch (item.absensiStatus) {
          case 'selesai': hadir++; break;
          case 'selesai_terlambat':
          case 'selesai_terlambat_checkout': hadir++; terlambat++; break;
          case 'tidak_lembur': tidakHadir++; break;
        }

        final fungsi = item.pengawasFungsi ?? item.fungsiMitra ?? 'unknown';
        distribusiFungsi[fungsi] = (distribusiFungsi[fungsi] ?? 0) + 1;
        distribusiPendapatanPerFungsi[fungsi] = (distribusiPendapatanPerFungsi[fungsi] ?? 0) + pendapatan;
        distribusiStatus[item.status] = (distribusiStatus[item.status] ?? 0) + 1;

        if (earliest == null || item.tanggal.isBefore(earliest)) earliest = item.tanggal;
        if (latest == null || item.tanggal.isAfter(latest)) latest = item.tanggal;
      }

      final total = items.length;
      return LaporanSummary(
        totalLaporan: total, totalDisetujui: disetujui,
        totalSelesai: selesaiStat, totalPending: pending,
        totalDitolak: ditolak, totalDibatalkan: dibatalkan,
        totalJamRencana: totalJamRencana, totalJamReal: totalJamReal,
        totalEstimasiBiaya: totalEstimasiBiaya, totalPendapatan: totalPendapatan,
        totalSudahDibayar: sudahDibayar, totalBelumDibayar: belumDibayar,
        totalDibayar: totalDibayar, totalBelumDibayarAmount: totalBelumDibayarAmount,
        rataJamPerLaporan: total > 0 ? totalJamReal / total : 0,
        rataPendapatanPerLaporan: total > 0 ? totalPendapatan / total : 0,
        rataRatePerJam: totalJamReal > 0 ? totalPendapatan / totalJamReal : 0,
        totalHadir: hadir, totalTerlambat: terlambat,
        totalTidakHadir: tidakHadir,
        persentaseHadir: total > 0 ? (hadir / total * 100) : 0,
        persentaseDibayar: sudahDibayar + belumDibayar > 0
            ? (sudahDibayar / (sudahDibayar + belumDibayar) * 100) : 0,
        earliestTanggal: earliest, latestTanggal: latest,
        distribusiFungsi: distribusiFungsi, distribusiStatus: distribusiStatus,
        distribusiPendapatanPerFungsi: distribusiPendapatanPerFungsi,
      );
    } catch (e) {
      debugPrint('❌ getLaporanSummary error: $e');
      return LaporanSummary.empty();
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 VALIDASI PEMBAYARAN V6 - DENGAN RELAKSASI TERLAMBAT
  // ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> validasiPembayaran(String laporanId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc =
          await _firestore.collection(_cLembur).doc(laporanId).get();
      if (!doc.exists) {
        doc = await _firestore.collection(_cPengajuan).doc(laporanId).get();
      }
      if (!doc.exists) {
        return {
          'valid': false,
          'message': '❌ Data lembur tidak ditemukan',
          'syarat_kurang': ['Data tidak ditemukan'],
          'detail': {},
        };
      }

      final data = doc.data()!;
      final cek = _cekPersyaratanBayar(data);

      // 🔥 Tambahkan info relaksasi di message jika terlambat
      final isTerlambat = cek['detail']?['is_terlambat'] == true;
      String message;
      if (cek['valid'] == true) {
        message = isTerlambat
            ? '✅ Persyaratan pembayaran terpenuhi (lembur TERLAMBAT - tanpa check-in/out)'
            : '✅ Semua persyaratan pembayaran terpenuhi';
      } else {
        final syaratList = (cek['syarat_kurang'] as List).map((e) => "  • $e").join('\n');
        message = '❌ Persyaratan pembayaran belum terpenuhi:\n$syaratList';
        if (isTerlambat) {
          message += '\n\n💡 Untuk lembur TERLAMBAT, tidak perlu check-in/out. Cukup dokumentasi & alasan.';
        }
      }

      return {
        'valid': cek['valid'],
        'message': message,
        'syarat_kurang': cek['syarat_kurang'],
        'detail': cek['detail'],
      };
    } catch (e) {
      return {
        'valid': false,
        'message': '❌ Gagal validasi: ${e.toString()}',
        'syarat_kurang': ['Error: ${e.toString()}'],
        'detail': {},
      };
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 PEMBAYARAN - TANDAI SUDAH DIBAYAR (DENGAN VALIDASI V6)
  // ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> tandaiSudahDibayar({
    required String laporanId,
    required String adminId,
    required String adminName,
    String? note,
    String basisPembayaran = 'aktual', // 🔥 BARU: 'aktual' atau 'pengajuan'
  }) async {
    try {
      // 🔥🔥🔥 VALIDASI PERSYARATAN DULU (dengan relaksasi terlambat)!
      final validasi = await validasiPembayaran(laporanId);
      if (validasi['valid'] != true) {
        return {
          'success': false,
          'message': validasi['message'] ?? '❌ Persyaratan pembayaran belum terpenuhi',
          'syarat_kurang': validasi['syarat_kurang'] ?? [],
          'detail': validasi['detail'] ?? {},
        };
      }

      DocumentSnapshot<Map<String, dynamic>>? doc =
          await _firestore.collection(_cLembur).doc(laporanId).get();
      if (!doc.exists) {
        doc = await _firestore.collection(_cPengajuan).doc(laporanId).get();
      }
      if (!doc.exists) {
        return {'success': false, 'message': 'Data tidak ditemukan'};
      }

      final data = doc.data()!;
      final groupId = data['group_id'] as String?;
      final now = FieldValue.serverTimestamp();

      // 🔥 Hitung nominal sesuai basis yang dipilih, per-dokumen
      // (karena tiap mitra dalam satu grup lembur bisa punya jam/rate berbeda)
      double hitungJumlahBayar(DocumentSnapshot<Map<String, dynamic>> d) {
        final it = LaporanItem.fromFirestore(d);
        if (basisPembayaran == 'pengajuan') {
          return (it.ratePerJam > 0 && it.totalJam > 0)
              ? it.ratePerJam * it.totalJam
              : it.biayaAktual; // fallback kalau data pengajuan tidak lengkap
        }
        return it.biayaAktual;
      }

      final baseUpdateData = <String, dynamic>{
        'is_paid': true,
        'isPaid': true,
        'paid_at': now,
        'paid_by': adminId,
        'paid_by_name': adminName,
        'paid_note': note ?? 'Gaji lembur telah diturunkan',
        'updated_at': now,
        'last_modified_at': now,
        'last_modified_by': adminId,
        'last_modified_by_name': adminName,
        'status_pembayaran': 'lunas',
        'status_bayar': 'sudah_dibayar',
        'payment_validated_at': now,
        'payment_validated_by': adminId,
        'basis_pembayaran': basisPembayaran, // 🔥 audit trail
      };

      final jumlahUtama = hitungJumlahBayar(doc);
      await doc.reference.update({
        ...baseUpdateData,
        'actual_income': jumlahUtama,
        'income': jumlahUtama,
      });

      // Update group (nominal dihitung ULANG per mitra, bukan disamakan)
      if (groupId != null && groupId.isNotEmpty) {
        final batch = _firestore.batch();
        final mitraDocs = await _firestore.collection(_cLembur)
            .where('group_id', isEqualTo: groupId).get();
        for (var d in mitraDocs.docs) {
          if (d.id == doc.id) continue; // sudah diupdate di atas
          final jumlah = hitungJumlahBayar(d);
          batch.update(d.reference, {
            ...baseUpdateData,
            'actual_income': jumlah,
            'income': jumlah,
          });
        }
        final pengajuanDocs = await _firestore.collection(_cPengajuan)
            .where('group_id', isEqualTo: groupId).get();
        for (var d in pengajuanDocs.docs) {
          final jumlah = hitungJumlahBayar(d);
          batch.update(d.reference, {
            ...baseUpdateData,
            'actual_income': jumlah,
            'income': jumlah,
          });
        }
        await batch.commit();
      }

      await _log('tandai_dibayar', laporanId, adminId,
          'Ditandai dibayar oleh $adminName (basis: $basisPembayaran)', {
        'admin_name': adminName, 'note': note,
        'amount': jumlahUtama,
        'basis_pembayaran': basisPembayaran,
        'validation_detail': validasi['detail'],
        'is_terlambat': validasi['detail']?['is_terlambat'] ?? false,
      });

      clearCache();
      return {
        'success': true,
        'message': '✅ Berhasil ditandai sudah dibayar',
        'detail': validasi['detail'],
        'jumlah_dibayar': jumlahUtama,
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal: ${e.toString()}'};
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 PEMBAYARAN - TANDAI SEMUA (DENGAN VALIDASI V6)
  // ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> tandaiSemuaDibayar({
    required String adminId,
    required String adminName,
    String? bulan,
    String? fungsiFilter,
    String? note,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_cLembur)
          .where('is_paid', isEqualTo: false);

      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }
      if (fungsiFilter != null && fungsiFilter.isNotEmpty && fungsiFilter != 'semua') {
        query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        return {'success': true, 'message': 'Tidak ada yang perlu ditandai', 'totalUpdated': 0, 'totalSkipped': 0};
      }

      final now = FieldValue.serverTimestamp();
      final processedGroupIds = <String>{};
      var batch = _firestore.batch();
      int count = 0, totalUpdated = 0, totalSkipped = 0, totalTerlambatUpdated = 0;
      List<String> skippedReasons = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final groupId = data['group_id'] as String?;
        if (groupId != null && processedGroupIds.contains(groupId)) continue;
        if (groupId != null) processedGroupIds.add(groupId);

        // 🔥🔥🔥 VALIDASI PERSYARATAN SEBELUM BAYAR (dengan relaksasi terlambat)
        final cek = _cekPersyaratanBayar(data);
        if (cek['valid'] != true) {
          totalSkipped++;
          final mitra = data['nama_mitra'] ?? data['mitra_nama'] ?? doc.id;
          final alasan = (cek['syarat_kurang'] as List).join(', ');
          skippedReasons.add('$mitra: $alasan');
          continue;
        }

        final isTerlambat = cek['detail']?['is_terlambat'] == true;
        if (isTerlambat) totalTerlambatUpdated++;

        batch.update(doc.reference, {
          'is_paid': true,
          'isPaid': true,
          'paid_at': now,
          'paid_by': adminId,
          'paid_by_name': adminName,
          'paid_note': note ?? 'Gaji lembur telah diturunkan (batch)',
          'updated_at': now,
          'status_pembayaran': 'lunas',
          'status_bayar': 'sudah_dibayar',
          'payment_validated_at': now,
          'payment_validated_by': adminId,
        });
        count++;
        totalUpdated++;

        if (count >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }

      if (count > 0) await batch.commit();

      await _log('tandai_semua_dibayar', 'batch', adminId,
          'Batch V6: $totalUpdated updated ($totalTerlambatUpdated terlambat), $totalSkipped skipped');

      clearCache();

      String message = '✅ $totalUpdated laporan berhasil ditandai sudah dibayar';
      if (totalTerlambatUpdated > 0) {
        message += '\n   (termasuk $totalTerlambatUpdated lembur TERLAMBAT)';
      }
      if (totalSkipped > 0) {
        message += '\n⚠️ $totalSkipped laporan DILEWATI karena belum memenuhi persyaratan';
        if (skippedReasons.isNotEmpty) {
          message += '\n\nDetail dilewati:\n${skippedReasons.take(5).join('\n')}';
          if (skippedReasons.length > 5) {
            message += '\n...dan ${skippedReasons.length - 5} lainnya';
          }
        }
      }

      return {
        'success': true,
        'message': message,
        'totalUpdated': totalUpdated,
        'totalTerlambatUpdated': totalTerlambatUpdated,
        'totalSkipped': totalSkipped,
        'skippedReasons': skippedReasons,
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal: ${e.toString()}'};
    }
  }

  // ═══════════════════════════════════════════════════════
  // BATALKAN PEMBAYARAN
  // ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> batalkanPembayaran({
    required String laporanId,
    required String adminId,
    String? alasan,
  }) async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc =
          await _firestore.collection(_cLembur).doc(laporanId).get();
      if (!doc.exists) {
        doc = await _firestore.collection(_cPengajuan).doc(laporanId).get();
      }
      if (!doc.exists) {
        return {'success': false, 'message': 'Data tidak ditemukan'};
      }

      final data = doc.data()!;
      final groupId = data['group_id'] as String?;
      final now = FieldValue.serverTimestamp();

      final updateData = <String, dynamic>{
        'is_paid': false, 'isPaid': false,
        'paid_at': null, 'paid_by': null,
        'paid_by_name': null, 'paid_note': null,
        'cancelled_paid_at': now,
        'cancelled_paid_by': adminId,
        'cancelled_paid_reason': alasan,
        'updated_at': now,
        'status_pembayaran': 'belum_dibayar',
        'status_bayar': 'belum_dibayar',
        'payment_validated_at': null,
        'payment_validated_by': null,
      };

      await doc.reference.update(updateData);

      if (groupId != null && groupId.isNotEmpty) {
        final batch = _firestore.batch();
        final mitraDocs = await _firestore.collection(_cLembur)
            .where('group_id', isEqualTo: groupId).get();
        for (var d in mitraDocs.docs) {
          batch.update(d.reference, updateData);
        }
        final pengajuanDocs = await _firestore.collection(_cPengajuan)
            .where('group_id', isEqualTo: groupId).get();
        for (var d in pengajuanDocs.docs) {
          batch.update(d.reference, updateData);
        }
        await batch.commit();
      }

      await _log('batalkan_pembayaran', laporanId, adminId,
          'Pembayaran dibatalkan. Alasan: ${alasan ?? "-"}');
      clearCache();
      return {'success': true, 'message': '✅ Pembayaran berhasil dibatalkan'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal: ${e.toString()}'};
    }
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 EXPORT CSV
  // ═══════════════════════════════════════════════════════

  Future<String> exportLaporanToCsv({
    required String userRole,
    String? userId,
    String? userFungsi,
    String? bulan,
    String? statusFilter,
    String? fungsiFilter,
    bool? isPaidFilter,
  }) async {
    final items = await getLaporanStream(
      userRole: userRole, userId: userId, userFungsi: userFungsi,
      bulan: bulan, statusFilter: statusFilter,
      fungsiFilter: fungsiFilter, isPaidFilter: isPaidFilter,
      limit: _maxPageSize,
    ).first;

    final csv = StringBuffer();
    csv.writeln([
      'No', 'Tanggal', 'Nama Mitra', 'Fungsi', 'Pengawas',
      'Jam Mulai', 'Jam Selesai', 'Total Jam (Rencana)', 'Total Jam (Real)',
      'Status', 'Absensi', 'Check-in', 'Check-out',
      'Estimasi Biaya', 'Pendapatan', 'Rate/Jam',
      'Pembayaran', 'Dibayar Oleh', 'Tanggal Bayar', 'Lokasi',
    ].join(','));

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      csv.writeln([
        i + 1,
        '"${item.tanggalFormatted}"',
        '"${item.namaMitra ?? '-'}"',
        '"${item.fungsiMitra ?? item.pengawasFungsi ?? '-'}"',
        '"${item.namaPengawas ?? '-'}"',
        item.jamMulai, item.jamSelesai,
        item.totalJam.toStringAsFixed(1),
        item.totalJamReal.toStringAsFixed(1),
        '"${item.statusLabel}"',
        '"${item.absensiLabel}"',
        item.checkInFullFormatted,
        item.checkOutFullFormatted,
        item.estimasiBiaya, item.biayaAktual,
        item.ratePerJam.toStringAsFixed(0),
        item.isPaid ? 'Sudah' : 'Belum',
        '"${item.paidByName ?? '-'}"',
        item.paidAt != null ? DateFormat('dd/MM/yyyy').format(item.paidAt!) : '-',
        '"${item.lokasiFormatted}"',
      ].join(','));
    }
    return csv.toString();
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 BULAN TERSEDIA - EXCLUDE DIBATALKAN
  // ═══════════════════════════════════════════════════════

  Future<List<String>> getBulanTersedia() async {
    try {
      final snapshot = await _firestore
          .collection(_cLembur)
          .orderBy('tahun_bulan', descending: true)
          .get();

      final bulanSet = <String>{};
      for (var doc in snapshot.docs) {
        if (_isDibatalkan(doc.data())) continue;
        final tb = doc.data()['tahun_bulan'] as String?;
        if (tb != null && tb.isNotEmpty) bulanSet.add(tb);
      }

      final list = bulanSet.toList()..sort((a, b) => b.compareTo(a));
      return ['semua', ...list];
    } catch (e) {
      return ['semua'];
    }
  }

  /// Format label bulan
  static String formatBulanLabel(String tahunBulan) {
    if (tahunBulan == 'semua') return 'Semua Bulan';
    try {
      final parts = tahunBulan.split('-');
      if (parts.length != 2) return tahunBulan;
      final monthNames = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ];
      return '${monthNames[int.parse(parts[1])]} ${parts[0]}';
    } catch (_) {
      return tahunBulan;
    }
  }

  // ═══════════════════════════════════════════════════════
  // LOGGING
  // ═══════════════════════════════════════════════════════

  Future<void> _log(
    String action,
    String documentId,
    String userId,
    String? detail, [
    Map<String, dynamic>? extra,
  ]) async {
    try {
      await _firestore.collection(_cLog).add({
        'action': action,
        'document_id': documentId,
        'user_id': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'details': detail,
        'module': 'report',
        ...?extra,
      });
    } catch (e) {
      debugPrint('⚠️ Log error: $e');
    }
  }
}