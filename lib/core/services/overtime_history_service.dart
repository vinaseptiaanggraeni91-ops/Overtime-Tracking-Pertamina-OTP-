// lib/core/services/overtime_history_service.dart
// 🔥 FINAL VERSION - V11 FIX DocumentSnapshot Sealed Class ERROR

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ============================================================================
// MODEL: OvertimeHistory - FULL COMPLETE VERSION V7
// ============================================================================

class OvertimeHistory {
  // ─── BASIC INFO ───
  final String id;
  final String groupId;
  final String tipeDokumen;

  // ─── PENGAJU INFO ───
  final String? pengawasId;
  final String? namaPengawas;
  final String? pengawasFungsi;
  final String? diajukanOlehId;
  final String? diajukanOlehNama;

  // ─── MITRA INFO ───
  final String? mitraId;
  final String? namaMitra;
  final String? fungsiMitra;
  final String? noHpMitra;
  final List<String>? mitraIds;
  final int totalMitra;
  final bool isMultiple;

  // ─── WAKTU & DURASI ───
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final double totalJam;

  // ─── DETAIL LEMBUR ───
  final String jenisLembur;
  final Map<String, dynamic> lokasi;
  final String urgensi;
  final String alasan;
  final String catatanTambahan;

  // ─── BIAYA ───
  final double estimasiBiayaPerMitra;
  final double estimasiBiayaTotal;
  final bool isOverride;

  // ─── STATUS UTAMA ───
  final String status;

  // ─── APPROVAL UMUM ───
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;

  // ─── SPKL ───
  final bool spklGenerated;
  final String? spklNomor;
  final String? spklPath;

  // ─── TIMESTAMPS ───
  final DateTime createdAt;
  final DateTime updatedAt;

  // ─── PEMBATALAN ───
  final DateTime? dibatalkanPada;
  final String? dibatalkanOleh;

  // ─── ABSENSI ───
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? checkInFotoUrl;
  final String? checkOutFotoUrl;
  final String? absensiStatus;
  final Map<String, dynamic>? absensiKeterlambatan;

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 PROPERTI BARU V7
  // ═══════════════════════════════════════════════════════
  final String? keterlambatanAlasan;
  final String? alasanTidakLembur;
  final DateTime? confirmedAt;

  // ─── HSSE FIELDS ───
  final bool isRisky;
  final String? risikoLevel;
  final String? risikoKategori;
  final String? risikoDeskripsi;
  final List<String>? risikoMitigasi;
  final String hsseStatus;
  final String? hsseApprovedBy;
  final String? hsseApprovedByName;
  final DateTime? hsseApprovedAt;
  final String? hsseRejectedBy;
  final String? hsseRejectedByName;
  final DateTime? hsseRejectedAt;
  final String? hsseAlasanPenolakan;
  final String? hsseReviewBy;
  final String? hsseReviewByName;
  final DateTime? hsseReviewAt;
  final String? hsseCatatanRevisi;
  final List<String>? hsseItemsRevisi;
  final String? hsseCatatan;
  final String? hsseRekomendasi;
  final List<String>? hsseDokumenPendukung;
  final Map<String, dynamic>? hsseChecklist;
  final bool hsseNeedEscalation;
  final String? hsseEscalationTo;
  final String? hsseEscalationReason;
  final DateTime? hsseEscalationAt;
  final String? hsseEscalationBy;
  final String? hsseEscalationByName;
  final bool hsseSafetyBriefing;
  final DateTime? hsseSafetyBriefingDate;
  final String? hsseSafetyBriefingBy;
  final String? hsseSafetyBriefingByName;
  final String? hsseSafetyBriefingCatatan;
  final List<Map<String, dynamic>>? hsseApprovalHistory;
  final Map<String, dynamic>? approvalChain;
  final String approvalLevel;
  final int maxApprovalLevel;
  final String? lastModifiedBy;
  final String? lastModifiedByName;
  final DateTime? lastModifiedAt;
  final List<String>? tags;
  final Map<String, dynamic>? metadata;

  // ─── CONSTRUCTOR ───
  OvertimeHistory({
    required this.id,
    required this.groupId,
    this.tipeDokumen = 'lembur_mitra',
    this.pengawasId,
    this.namaPengawas,
    this.pengawasFungsi,
    this.diajukanOlehId,
    this.diajukanOlehNama,
    this.mitraId,
    this.namaMitra,
    this.fungsiMitra,
    this.noHpMitra,
    this.mitraIds,
    this.totalMitra = 1,
    this.isMultiple = false,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.totalJam,
    required this.jenisLembur,
    required this.lokasi,
    required this.urgensi,
    required this.alasan,
    required this.catatanTambahan,
    required this.estimasiBiayaPerMitra,
    required this.estimasiBiayaTotal,
    this.isOverride = false,
    required this.status,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.spklGenerated = false,
    this.spklNomor,
    this.spklPath,
    required this.createdAt,
    required this.updatedAt,
    this.checkInTime,
    this.checkOutTime,
    this.checkInFotoUrl,
    this.checkOutFotoUrl,
    this.absensiStatus,
    this.absensiKeterlambatan,
    this.keterlambatanAlasan,
    this.alasanTidakLembur,
    this.confirmedAt,
    this.dibatalkanPada,
    this.dibatalkanOleh,
    this.isRisky = false,
    this.risikoLevel,
    this.risikoKategori,
    this.risikoDeskripsi,
    this.risikoMitigasi,
    this.hsseStatus = 'pending',
    this.hsseApprovedBy,
    this.hsseApprovedByName,
    this.hsseApprovedAt,
    this.hsseRejectedBy,
    this.hsseRejectedByName,
    this.hsseRejectedAt,
    this.hsseAlasanPenolakan,
    this.hsseReviewBy,
    this.hsseReviewByName,
    this.hsseReviewAt,
    this.hsseCatatanRevisi,
    this.hsseItemsRevisi,
    this.hsseCatatan,
    this.hsseRekomendasi,
    this.hsseDokumenPendukung,
    this.hsseChecklist,
    this.hsseNeedEscalation = false,
    this.hsseEscalationTo,
    this.hsseEscalationReason,
    this.hsseEscalationAt,
    this.hsseEscalationBy,
    this.hsseEscalationByName,
    this.hsseSafetyBriefing = false,
    this.hsseSafetyBriefingDate,
    this.hsseSafetyBriefingBy,
    this.hsseSafetyBriefingByName,
    this.hsseSafetyBriefingCatatan,
    this.hsseApprovalHistory,
    this.approvalChain,
    this.approvalLevel = '',
    this.maxApprovalLevel = 1,
    this.lastModifiedBy,
    this.lastModifiedByName,
    this.lastModifiedAt,
    this.tags,
    this.metadata,
  });

  // ─── PARSING HELPERS ───
  static DateTime _parseTimestamp(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return fallback ?? DateTime.now();
  }

  static DateTime? _parseTimestampOrNull(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => e.toString()).toList();
    return null;
  }

  static Map<String, dynamic>? _parseMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>>? _parseMapList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return null;
  }

  // ─── FROM FIRESTORE ───
  factory OvertimeHistory.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    final tanggalValue = data['tanggal'] ?? data['tanggal_lembur'];
    final DateTime tanggal = _parseTimestamp(tanggalValue);
    final createdAt = _parseTimestamp(data['created_at']);
    final updatedAt = _parseTimestamp(data['updated_at']);
    final estimasiBiayaPerMitra =
        (data['estimasi_biaya_per_mitra'] ?? data['estimasi_biaya'] ?? 0)
            .toDouble();
    final estimasiBiayaTotal =
        (data['estimasi_biaya_total'] ?? data['estimasi_biaya'] ?? 0)
            .toDouble();

    String? keterlambatanAlasan;
    String? alasanTidakLembur;
    DateTime? confirmedAt;

    if (data['absensi_keterlambatan'] is Map) {
      final map = data['absensi_keterlambatan'] as Map;
      final isLemburTerlambat = map['melakukan_lembur'] == true;
      final isTidakLembur = map['melakukan_lembur'] == false;

      if (isLemburTerlambat) {
        keterlambatanAlasan = map['alasan']?.toString();
      } else if (isTidakLembur) {
        alasanTidakLembur = map['alasan']?.toString();
      }

      if (map['confirmed_at'] != null) {
        confirmedAt = _parseTimestampOrNull(map['confirmed_at']);
      }
    }

    keterlambatanAlasan ??= data['keterlambatan_alasan']?.toString();
    alasanTidakLembur ??= data['alasan_tidak_lembur']?.toString();
    confirmedAt ??= _parseTimestampOrNull(
        data['confirmed_at'] ?? data['tidak_lembur_at'] ?? data['check_out_time']);

    return OvertimeHistory(
      id: doc.id,
      groupId: data['group_id'] ?? doc.id,
      tipeDokumen: data['tipe_dokumen'] ?? 'lembur_mitra',
      pengawasId: data['pengawas_id'] ?? data['diajukan_oleh_id'],
      namaPengawas: data['nama_pengawas'] ?? data['diajukan_oleh_nama'],
      pengawasFungsi: data['pengawas_fungsi'],
      diajukanOlehId: data['diajukan_oleh_id'] ?? data['pengawas_id'],
      diajukanOlehNama: data['diajukan_oleh_nama'] ?? data['nama_pengawas'],
      mitraId: data['mitra_id'],
      namaMitra: data['nama_mitra'],
      fungsiMitra: data['fungsi_mitra'],
      noHpMitra: data['no_hp_mitra'],
      mitraIds: _parseStringList(data['mitra_ids']),
      totalMitra: data['total_mitra'] ?? 1,
      isMultiple: data['is_multiple'] ?? false,
      tanggal: tanggal,
      jamMulai: data['jam_mulai'] ?? '',
      jamSelesai: data['jam_selesai'] ?? '',
      totalJam: (data['total_jam_desimal'] ?? 0).toDouble(),
      jenisLembur: data['jenis_lembur'] ?? 'hari_kerja',
      lokasi: data['lokasi'] ?? {},
      urgensi: data['urgensi'] ?? 'normal',
      alasan: data['alasan'] ?? '',
      catatanTambahan: data['catatan_tambahan'] ?? '',
      estimasiBiayaPerMitra: estimasiBiayaPerMitra,
      estimasiBiayaTotal:
          estimasiBiayaTotal > 0 ? estimasiBiayaTotal : estimasiBiayaPerMitra,
      isOverride: data['is_override'] ?? false,
      status: data['status'] ?? 'pending',
      approvedBy: data['approved_by'],
      approvedByName: data['approved_by_name'],
      approvedAt: _parseTimestampOrNull(data['approved_at']),
      spklGenerated: data['spkl_generated'] ?? false,
      spklNomor: data['spkl_nomor'],
      spklPath: data['spkl_path'],
      createdAt: createdAt,
      updatedAt: updatedAt,
      checkInTime: _parseTimestampOrNull(data['check_in_time']),
      checkOutTime: _parseTimestampOrNull(data['check_out_time']),
      checkInFotoUrl: data['check_in_foto_url'] ?? data['absensi_foto_url'],
      checkOutFotoUrl: data['check_out_foto_url'],
      absensiStatus: data['absensi_status'],
      absensiKeterlambatan: _parseMap(data['absensi_keterlambatan']),
      keterlambatanAlasan: keterlambatanAlasan,
      alasanTidakLembur: alasanTidakLembur,
      confirmedAt: confirmedAt,
      dibatalkanPada: _parseTimestampOrNull(data['dibatalkan_pada']),
      dibatalkanOleh: data['dibatalkan_oleh'],
      isRisky: data['is_risky'] ?? false,
      risikoLevel: data['risiko_level'] ?? data['risk_level'],
      risikoKategori: data['risiko_kategori'],
      risikoDeskripsi: data['risiko_deskripsi'],
      risikoMitigasi: _parseStringList(data['risiko_mitigasi']),
      hsseStatus: data['hsse_status'] ?? 'pending',
      hsseApprovedBy: data['hsse_approved_by'],
      hsseApprovedByName: data['hsse_approved_by_name'],
      hsseApprovedAt: _parseTimestampOrNull(data['hsse_approved_at']),
      hsseRejectedBy: data['hsse_rejected_by'],
      hsseRejectedByName: data['hsse_rejected_by_name'],
      hsseRejectedAt: _parseTimestampOrNull(data['hsse_rejected_at']),
      hsseAlasanPenolakan: data['hsse_alasan_penolakan'],
      hsseReviewBy: data['hsse_review_by'],
      hsseReviewByName: data['hsse_review_by_name'],
      hsseReviewAt: _parseTimestampOrNull(data['hsse_review_at']),
      hsseCatatanRevisi: data['hsse_catatan_revisi'],
      hsseItemsRevisi: _parseStringList(data['hsse_items_revisi']),
      hsseCatatan: data['hsse_catatan'],
      hsseRekomendasi: data['hsse_rekomendasi'],
      hsseDokumenPendukung: _parseStringList(data['hsse_dokumen_pendukung']),
      hsseChecklist: _parseMap(data['hsse_checklist']),
      hsseNeedEscalation: data['hsse_need_escalation'] ?? false,
      hsseEscalationTo: data['hsse_escalation_to'],
      hsseEscalationReason: data['hsse_escalation_reason'],
      hsseEscalationAt: _parseTimestampOrNull(data['hsse_escalation_at']),
      hsseEscalationBy: data['hsse_escalation_by'],
      hsseEscalationByName: data['hsse_escalation_by_name'],
      hsseSafetyBriefing: data['hsse_safety_briefing'] ?? false,
      hsseSafetyBriefingDate:
          _parseTimestampOrNull(data['hsse_safety_briefing_date']),
      hsseSafetyBriefingBy: data['hsse_safety_briefing_by'],
      hsseSafetyBriefingByName: data['hsse_safety_briefing_by_name'],
      hsseSafetyBriefingCatatan: data['hsse_safety_briefing_catatan'],
      hsseApprovalHistory: _parseMapList(data['hsse_approval_history']),
      approvalChain: _parseMap(data['approval_chain']),
      approvalLevel: data['approval_level']?.toString() ?? '',
      maxApprovalLevel: data['max_approval_level'] ?? 1,
      lastModifiedBy: data['last_modified_by'],
      lastModifiedByName: data['last_modified_by_name'],
      lastModifiedAt: _parseTimestampOrNull(data['last_modified_at']),
      tags: _parseStringList(data['tags']),
      metadata: _parseMap(data['metadata']),
    );
  }

  // ═══════════════════════════════════════════════════════
  // COMPUTED PROPERTIES
  // ═══════════════════════════════════════════════════════

  // 🔥🔥🔥 GETTER BARU UNTUK FILTER PEMBATALAN (V12)
  /// Getter untuk cek status pengajuan (alias dari field `status`)
  String? get statusPengajuan => status;
  
  /// Getter untuk cek apakah lembur dibatalkan/ditolak
  bool get isCancelled => 
      status == 'dibatalkan' || 
      status == 'cancelled' || 
      status == 'ditolak';
  
  /// Getter untuk cek apakah absensi sudah resolved (check-out/selesai/expired)
  bool get isAbsensiResolved => 
      isCheckedOut || 
      absensiStatus == 'selesai' || 
      absensiStatus == 'selesai_terlambat' || 
      absensiStatus == 'tidak_lembur' || 
      absensiStatus == 'expired';

  String get tahunBulan => DateFormat('yyyy-MM').format(tanggal);
  String get tanggalFormatted => DateFormat('dd MMM yyyy', 'id_ID').format(tanggal);
  String get namaPengaju => diajukanOlehNama ?? namaPengawas ?? 'Tidak diketahui';
  bool get isMitraDocument => tipeDokumen == 'lembur_mitra';
  bool get isPengajuanDocument => tipeDokumen == 'pengajuan';
  double get biayaAktual => estimasiBiayaTotal > 0 ? estimasiBiayaTotal : estimasiBiayaPerMitra;

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Menunggu Manager';
      case 'manager_approved': return 'Disetujui Manager';
      case 'pending_hsse':
      case 'manager_approval_pending_hsse':
      case 'manager_approved_pending_hsse': return 'Menunggu HSSE';
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      case 'selesai': return 'Selesai';
      case 'kadaluarsa': return 'Kadaluarsa';
      case 'dibatalkan': return 'Dibatalkan';
      default: return status;
    }
  }

  String get risikoLevelLabel {
    switch (risikoLevel?.toLowerCase()) {
      case 'rendah': case 'low': return 'Rendah';
      case 'sedang': case 'medium': return 'Sedang';
      case 'tinggi': case 'high': return 'Tinggi';
      case 'kritis': case 'critical': return 'Kritis';
      default: return 'Tidak Diketahui';
    }
  }

  String get hsseStatusLabel {
    switch (hsseStatus) {
      case 'pending': return 'Menunggu HSSE';
      case 'disetujui': return 'Disetujui HSSE';
      case 'ditolak': return 'Ditolak HSSE';
      case 'perlu_revisi': return 'Perlu Revisi';
      case 'dalam_review': return 'Dalam Review';
      default: return hsseStatus;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'manager_approved': return Colors.blue.shade400;
      case 'pending_hsse':
      case 'manager_approval_pending_hsse':
      case 'manager_approved_pending_hsse': return Colors.deepOrange;
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      case 'selesai': return Colors.blue;
      case 'kadaluarsa': return Colors.grey;
      case 'dibatalkan': return Colors.red.shade300;
      default: return Colors.grey;
    }
  }

  Color get risikoLevelColor {
    switch (risikoLevel?.toLowerCase()) {
      case 'rendah': case 'low': return Colors.green;
      case 'sedang': case 'medium': return Colors.orange;
      case 'tinggi': case 'high': return Colors.deepOrange;
      case 'kritis': case 'critical': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color get hsseStatusColor {
    switch (hsseStatus) {
      case 'pending': return Colors.orange;
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      case 'perlu_revisi': return Colors.amber;
      case 'dalam_review': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String get absensiLabel {
    switch (absensiStatus) {
      case 'belum_absen': return '⏳ Belum Absen';
      case 'check_in':
      case 'sudah_absen': return '📥 Check In';
      case 'check_out': return '📤 Check Out';
      case 'selesai': return '✅ Selesai';
      case 'selesai_terlambat': return '⚠️ Terlambat';
      case 'tidak_lembur': return '❌ Tidak Lembur';
      case 'expired': return '⏰ Kadaluarsa';
      default: return absensiStatus ?? 'Tidak Diketahui';
    }
  }

  Color get absensiColor {
    switch (absensiStatus) {
      case 'check_in':
      case 'sudah_absen': return Colors.blue;
      case 'selesai': return Colors.green;
      case 'selesai_terlambat': return Colors.orange;
      case 'tidak_lembur':
      case 'expired': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'pending': return Icons.schedule;
      case 'manager_approved': return Icons.thumb_up_outlined;
      case 'pending_hsse':
      case 'manager_approval_pending_hsse':
      case 'manager_approved_pending_hsse': return Icons.health_and_safety_outlined;
      case 'disetujui': return Icons.check_circle_outline;
      case 'ditolak': return Icons.cancel_outlined;
      case 'selesai': return Icons.task_alt;
      case 'kadaluarsa': return Icons.timer_off;
      case 'dibatalkan': return Icons.remove_circle_outline;
      default: return Icons.help_outline;
    }
  }

  IconData get risikoLevelIcon {
    switch (risikoLevel?.toLowerCase()) {
      case 'rendah': case 'low': return Icons.check_circle_outline;
      case 'sedang': case 'medium': return Icons.info_outline;
      case 'tinggi': case 'high': return Icons.warning_amber_outlined;
      case 'kritis': case 'critical': return Icons.dangerous_outlined;
      default: return Icons.help_outline;
    }
  }

  IconData get hsseStatusIcon {
    switch (hsseStatus) {
      case 'pending': return Icons.schedule;
      case 'disetujui': return Icons.verified;
      case 'ditolak': return Icons.cancel;
      case 'perlu_revisi': return Icons.edit_note;
      case 'dalam_review': return Icons.visibility;
      default: return Icons.help_outline;
    }
  }

  bool get canBeCancelled {
    if (status != 'pending' && status != 'disetujui') return false;
    return DateTime.now().difference(createdAt).inDays <= 3;
  }

  bool get isCheckedIn =>
      checkInTime != null ||
      absensiStatus == 'check_in' ||
      absensiStatus == 'sudah_absen' ||
      absensiStatus == 'selesai' ||
      absensiStatus == 'selesai_terlambat';

  bool get isCheckedOut =>
      checkOutTime != null ||
      absensiStatus == 'check_out' ||
      absensiStatus == 'selesai' ||
      absensiStatus == 'selesai_terlambat' ||
      absensiStatus == 'tidak_lembur';

  bool get needsAbsensi =>
      !isCheckedOut &&
      (status == 'disetujui' || status == 'selesai') &&
      (absensiStatus == null ||
          absensiStatus == 'belum_absen' ||
          absensiStatus == 'check_in' ||
          absensiStatus == 'sudah_absen');

  String get checkInTimeFormatted {
    if (checkInTime == null) return '-';
    return DateFormat('HH:mm', 'id_ID').format(checkInTime!);
  }

  String get checkOutTimeFormatted {
    if (checkOutTime == null) return '-';
    return DateFormat('HH:mm', 'id_ID').format(checkOutTime!);
  }

  String get checkInDateTimeFormatted {
    if (checkInTime == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(checkInTime!);
  }

  String get checkOutDateTimeFormatted {
    if (checkOutTime == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(checkOutTime!);
  }

  String get absensiStatusLabel {
    switch (absensiStatus) {
      case 'belum_absen': return 'Belum Absen';
      case 'check_in': return 'Check In';
      case 'sudah_absen': return 'Sudah Absen';
      case 'check_out': return 'Check Out';
      case 'selesai': return 'Selesai';
      case 'selesai_terlambat': return 'Absen Terlambat';
      case 'tidak_lembur': return 'Tidak Lembur';
      case 'expired': return 'Kadaluarsa';
      default: return absensiStatus ?? 'Tidak Diketahui';
    }
  }

  Color get absensiStatusColor {
    switch (absensiStatus) {
      case 'belum_absen': return Colors.orange;
      case 'check_in': return Colors.blue;
      case 'sudah_absen': return Colors.blue.shade700;
      case 'check_out': return Colors.purple;
      case 'selesai': return Colors.green;
      case 'selesai_terlambat': return Colors.deepOrange;
      case 'tidak_lembur': return Colors.red;
      case 'expired': return Colors.grey;
      default: return Colors.grey;
    }
  }

  IconData get absensiStatusIcon {
    switch (absensiStatus) {
      case 'belum_absen': return Icons.schedule;
      case 'check_in': return Icons.login;
      case 'sudah_absen': return Icons.check_circle_outline;
      case 'check_out': return Icons.logout;
      case 'selesai': return Icons.task_alt;
      case 'selesai_terlambat': return Icons.warning_amber;
      case 'tidak_lembur': return Icons.cancel;
      case 'expired': return Icons.timer_off;
      default: return Icons.help_outline;
    }
  }

  bool get isLateAbsensi =>
      absensiStatus == 'selesai_terlambat' ||
      (absensiKeterlambatan != null &&
          absensiKeterlambatan!['melakukan_lembur'] == true);

  bool get isTidakLembur =>
      absensiStatus == 'tidak_lembur' ||
      (absensiKeterlambatan != null &&
          absensiKeterlambatan!['melakukan_lembur'] == false);

  String? get alasanKeterlambatan => keterlambatanAlasan;

  bool get needsHSSEApproval => hsseStatus == 'pending';
  bool get isHSSEApproved => hsseStatus == 'disetujui';
  bool get isHSSERejected => hsseStatus == 'ditolak';
  bool get isHSSEReview => hsseStatus == 'dalam_review';
  bool get needsHSSERevision => hsseStatus == 'perlu_revisi';

  // 🔥🔥🔥 V11: Static factory method untuk parsing langsung dari Map
  factory OvertimeHistory.fromMap(Map<String, dynamic> data, String id) {
    final tanggalValue = data['tanggal'] ?? data['tanggal_lembur'];
    final DateTime tanggal = _parseTimestamp(tanggalValue);
    final createdAt = _parseTimestamp(data['created_at']);
    final updatedAt = _parseTimestamp(data['updated_at']);
    final estimasiBiayaPerMitra =
        (data['estimasi_biaya_per_mitra'] ?? data['estimasi_biaya'] ?? 0)
            .toDouble();
    final estimasiBiayaTotal =
        (data['estimasi_biaya_total'] ?? data['estimasi_biaya'] ?? 0)
            .toDouble();

    String? keterlambatanAlasan;
    String? alasanTidakLembur;
    DateTime? confirmedAt;

    if (data['absensi_keterlambatan'] is Map) {
      final map = data['absensi_keterlambatan'] as Map;
      final isLemburTerlambat = map['melakukan_lembur'] == true;
      final isTidakLembur = map['melakukan_lembur'] == false;

      if (isLemburTerlambat) {
        keterlambatanAlasan = map['alasan']?.toString();
      } else if (isTidakLembur) {
        alasanTidakLembur = map['alasan']?.toString();
      }

      if (map['confirmed_at'] != null) {
        confirmedAt = _parseTimestampOrNull(map['confirmed_at']);
      }
    }

    keterlambatanAlasan ??= data['keterlambatan_alasan']?.toString();
    alasanTidakLembur ??= data['alasan_tidak_lembur']?.toString();
    confirmedAt ??= _parseTimestampOrNull(
        data['confirmed_at'] ?? data['tidak_lembur_at'] ?? data['check_out_time']);

    return OvertimeHistory(
      id: id,
      groupId: data['group_id'] ?? id,
      tipeDokumen: data['tipe_dokumen'] ?? 'lembur_mitra',
      pengawasId: data['pengawas_id'] ?? data['diajukan_oleh_id'],
      namaPengawas: data['nama_pengawas'] ?? data['diajukan_oleh_nama'],
      pengawasFungsi: data['pengawas_fungsi'],
      diajukanOlehId: data['diajukan_oleh_id'] ?? data['pengawas_id'],
      diajukanOlehNama: data['diajukan_oleh_nama'] ?? data['nama_pengawas'],
      mitraId: data['mitra_id'],
      namaMitra: data['nama_mitra'],
      fungsiMitra: data['fungsi_mitra'],
      noHpMitra: data['no_hp_mitra'],
      mitraIds: _parseStringList(data['mitra_ids']),
      totalMitra: data['total_mitra'] ?? 1,
      isMultiple: data['is_multiple'] ?? false,
      tanggal: tanggal,
      jamMulai: data['jam_mulai'] ?? '',
      jamSelesai: data['jam_selesai'] ?? '',
      totalJam: (data['total_jam_desimal'] ?? 0).toDouble(),
      jenisLembur: data['jenis_lembur'] ?? 'hari_kerja',
      lokasi: data['lokasi'] ?? {},
      urgensi: data['urgensi'] ?? 'normal',
      alasan: data['alasan'] ?? '',
      catatanTambahan: data['catatan_tambahan'] ?? '',
      estimasiBiayaPerMitra: estimasiBiayaPerMitra,
      estimasiBiayaTotal:
          estimasiBiayaTotal > 0 ? estimasiBiayaTotal : estimasiBiayaPerMitra,
      isOverride: data['is_override'] ?? false,
      status: data['status'] ?? 'pending',
      approvedBy: data['approved_by'],
      approvedByName: data['approved_by_name'],
      approvedAt: _parseTimestampOrNull(data['approved_at']),
      spklGenerated: data['spkl_generated'] ?? false,
      spklNomor: data['spkl_nomor'],
      spklPath: data['spkl_path'],
      createdAt: createdAt,
      updatedAt: updatedAt,
      checkInTime: _parseTimestampOrNull(data['check_in_time']),
      checkOutTime: _parseTimestampOrNull(data['check_out_time']),
      checkInFotoUrl: data['check_in_foto_url'] ?? data['absensi_foto_url'],
      checkOutFotoUrl: data['check_out_foto_url'],
      absensiStatus: data['absensi_status'],
      absensiKeterlambatan: _parseMap(data['absensi_keterlambatan']),
      keterlambatanAlasan: keterlambatanAlasan,
      alasanTidakLembur: alasanTidakLembur,
      confirmedAt: confirmedAt,
      dibatalkanPada: _parseTimestampOrNull(data['dibatalkan_pada']),
      dibatalkanOleh: data['dibatalkan_oleh'],
      isRisky: data['is_risky'] ?? false,
      risikoLevel: data['risiko_level'] ?? data['risk_level'],
      risikoKategori: data['risiko_kategori'],
      risikoDeskripsi: data['risiko_deskripsi'],
      risikoMitigasi: _parseStringList(data['risiko_mitigasi']),
      hsseStatus: data['hsse_status'] ?? 'pending',
      hsseApprovedBy: data['hsse_approved_by'],
      hsseApprovedByName: data['hsse_approved_by_name'],
      hsseApprovedAt: _parseTimestampOrNull(data['hsse_approved_at']),
      hsseRejectedBy: data['hsse_rejected_by'],
      hsseRejectedByName: data['hsse_rejected_by_name'],
      hsseRejectedAt: _parseTimestampOrNull(data['hsse_rejected_at']),
      hsseAlasanPenolakan: data['hsse_alasan_penolakan'],
      hsseReviewBy: data['hsse_review_by'],
      hsseReviewByName: data['hsse_review_by_name'],
      hsseReviewAt: _parseTimestampOrNull(data['hsse_review_at']),
      hsseCatatanRevisi: data['hsse_catatan_revisi'],
      hsseItemsRevisi: _parseStringList(data['hsse_items_revisi']),
      hsseCatatan: data['hsse_catatan'],
      hsseRekomendasi: data['hsse_rekomendasi'],
      hsseDokumenPendukung: _parseStringList(data['hsse_dokumen_pendukung']),
      hsseChecklist: _parseMap(data['hsse_checklist']),
      hsseNeedEscalation: data['hsse_need_escalation'] ?? false,
      hsseEscalationTo: data['hsse_escalation_to'],
      hsseEscalationReason: data['hsse_escalation_reason'],
      hsseEscalationAt: _parseTimestampOrNull(data['hsse_escalation_at']),
      hsseEscalationBy: data['hsse_escalation_by'],
      hsseEscalationByName: data['hsse_escalation_by_name'],
      hsseSafetyBriefing: data['hsse_safety_briefing'] ?? false,
      hsseSafetyBriefingDate:
          _parseTimestampOrNull(data['hsse_safety_briefing_date']),
      hsseSafetyBriefingBy: data['hsse_safety_briefing_by'],
      hsseSafetyBriefingByName: data['hsse_safety_briefing_by_name'],
      hsseSafetyBriefingCatatan: data['hsse_safety_briefing_catatan'],
      hsseApprovalHistory: _parseMapList(data['hsse_approval_history']),
      approvalChain: _parseMap(data['approval_chain']),
      approvalLevel: data['approval_level']?.toString() ?? '',
      maxApprovalLevel: data['max_approval_level'] ?? 1,
      lastModifiedBy: data['last_modified_by'],
      lastModifiedByName: data['last_modified_by_name'],
      lastModifiedAt: _parseTimestampOrNull(data['last_modified_at']),
      tags: _parseStringList(data['tags']),
      metadata: _parseMap(data['metadata']),
    );
  }
}

// ============================================================================
// ENUM: HSSE View Mode
// ============================================================================
enum HSSEViewMode {
  all,
  needApproval,
  myHistory,
}

// ============================================================================
// SERVICE: OvertimeHistoryService - FINAL VERSION V11
// ============================================================================
class OvertimeHistoryService {
  // ─── SINGLETON ───
  static final OvertimeHistoryService _instance =
      OvertimeHistoryService._internal();
  factory OvertimeHistoryService() => _instance;
  OvertimeHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── NAMA COLLECTION ───
  static const String collectionLemburMitra = 'lembur_mitra';
  static const String collectionPengajuan = 'pengajuan_lembur';
  static const String collectionUsers = 'users';
  static const String collectionActivityLogs = 'activity_logs';
  static const String collectionHSSELogs = 'hsse_activity_logs';
  static const String collectionSafetyBriefing = 'safety_briefings';

  // ═══════════════════════════════════════════════════════════════
  // STATUS KONSTANTA
  // ═══════════════════════════════════════════════════════════════

  static const List<String> allActiveStatuses = [
    'pending', 'manager_approved', 'pending_hsse',
    'manager_approval_pending_hsse', 'manager_approved_pending_hsse',
  ];

  static const List<String> finalStatuses = [
    'disetujui', 'ditolak', 'dibatalkan', 'selesai', 'kadaluarsa',
  ];

  static const List<String> allDisplayStatuses = [
    ...allActiveStatuses, ...finalStatuses,
  ];

  static const List<String> hssePendingStatuses = [
    'pending_hsse', 'manager_approval_pending_hsse', 'manager_approved_pending_hsse',
  ];

  static const List<String> hsseResolvedStatuses = ['disetujui', 'ditolak'];

  static const int batasWaktuPembatalan = 3;

  // ═══════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  List<OvertimeHistory> _filterByBulan(List<OvertimeHistory> data, String? bulan) {
    if (bulan == null || bulan.isEmpty || bulan == 'semua') return data;
    return data.where((item) => item.tahunBulan == bulan).toList();
  }

  /// 🔥 GROUP BY group_id untuk menghindari duplikasi
  List<OvertimeHistory> _groupByGroupId(List<OvertimeHistory> items) {
    final Map<String, OvertimeHistory> uniqueMap = {};
    for (var item in items) {
      final key = item.groupId;
      if (!uniqueMap.containsKey(key) || 
          item.createdAt.isAfter(uniqueMap[key]!.createdAt)) {
        uniqueMap[key] = item;
      }
    }
    final result = uniqueMap.values.toList();
    result.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return result;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findDocument(String documentId) async {
    var doc = await _firestore.collection(collectionLemburMitra).doc(documentId).get();
    if (doc.exists) return doc;
    doc = await _firestore.collection(collectionPengajuan).doc(documentId).get();
    if (doc.exists) return doc;
    return null;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<String?> _getUserRole(String userId) async {
    try {
      final doc = await _firestore.collection(collectionUsers).doc(userId).get();
      if (doc.exists) return doc.data()?['role'] as String?;
      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting user role: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STREAM UTAMA - DENGAN GROUP BY group_id
  // ═══════════════════════════════════════════════════════════════

  Stream<List<OvertimeHistory>> getOvertimeHistoryStream({
    required String userRole,
    String? userFungsi,
    String? userId,
    String? bulan,
    String? statusFilter,
  }) {
    if (userRole == 'manager' && userFungsi == 'hsse') {
      return _getHSSEManagerStream(bulan: bulan, statusFilter: statusFilter);
    }
    if (userFungsi == 'hsse') {
      return _getHSSEStaffStream(bulan: bulan, statusFilter: statusFilter, hsseUserId: userId);
    }
    switch (userRole) {
      case 'mitra': return _getMitraHistoryStream(mitraId: userId!, bulan: bulan, statusFilter: statusFilter);
      case 'pengawas': return _getPengawasHistoryStream(pengawasId: userId!, bulan: bulan, statusFilter: statusFilter);
      case 'manager': return _getManagerHistoryStream(fungsi: userFungsi, bulan: bulan, statusFilter: statusFilter);
      case 'superadmin': return _getAllHistoryStream(bulan: bulan, statusFilter: statusFilter);
      default: return Stream.value([]);
    }
  }

  Stream<List<OvertimeHistory>> _getMitraHistoryStream({
    required String mitraId, String? bulan, String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('mitra_id', isEqualTo: mitraId)
        .where('status', whereIn: allDisplayStatuses);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var docs = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc))
          .where((item) => item.mitraId == mitraId)
          .toList();
      return _filterByBulan(_groupByGroupId(docs), bulan);
    });
  }

  Stream<List<OvertimeHistory>> _getPengawasHistoryStream({
    required String pengawasId, String? bulan, String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('diajukan_oleh_id', isEqualTo: pengawasId)
        .where('status', whereIn: allDisplayStatuses);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var docs = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      return _filterByBulan(_groupByGroupId(docs), bulan);
    });
  }

  Stream<List<OvertimeHistory>> _getManagerHistoryStream({
    String? fungsi, String? bulan, String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('status', whereIn: allDisplayStatuses);
    if (fungsi != null && fungsi.isNotEmpty) {
      query = query.where('pengawas_fungsi', isEqualTo: fungsi);
    }
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var docs = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      return _filterByBulan(_groupByGroupId(docs), bulan);
    });
  }

  Stream<List<OvertimeHistory>> _getAllHistoryStream({
    String? bulan, String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('status', whereIn: allDisplayStatuses);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    return query.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var docs = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
        docs = docs.where((item) => item.status == statusFilter).toList();
      }
      return _filterByBulan(_groupByGroupId(docs), bulan);
    });
  }

  Stream<List<OvertimeHistory>> _getHSSEManagerStream({
    String? bulan, String? statusFilter, String? hsseStatus,
    String? risikoLevel, String? risikoKategori,
  }) {
    Query<Map<String, dynamic>> qm = _firestore
        .collection(collectionLemburMitra)
        .where('status', whereIn: allDisplayStatuses);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') qm = qm.where('tahun_bulan', isEqualTo: bulan);
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') qm = qm.where('status', isEqualTo: statusFilter);
    if (risikoLevel != null && risikoLevel.isNotEmpty && risikoLevel != 'semua') qm = qm.where('risiko_level', isEqualTo: risikoLevel);
    if (risikoKategori != null && risikoKategori.isNotEmpty && risikoKategori != 'semua') qm = qm.where('risiko_kategori', isEqualTo: risikoKategori);
    return qm.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var allData = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      allData = _groupByGroupId(allData);
      if (hsseStatus != null && hsseStatus.isNotEmpty && hsseStatus != 'semua') {
        allData = allData.where((item) => item.hsseStatus == hsseStatus).toList();
      }
      allData.sort((a, b) {
        if (a.hsseStatus == 'pending' && b.hsseStatus != 'pending') return -1;
        if (b.hsseStatus == 'pending' && a.hsseStatus != 'pending') return 1;
        final levelOrder = {'kritis': 0, 'tinggi': 1, 'sedang': 2, 'rendah': 3};
        final aLevel = levelOrder[a.risikoLevel?.toLowerCase()] ?? 4;
        final bLevel = levelOrder[b.risikoLevel?.toLowerCase()] ?? 4;
        if (aLevel != bLevel) return aLevel.compareTo(bLevel);
        return b.tanggal.compareTo(a.tanggal);
      });
      return allData;
    });
  }

  Stream<List<OvertimeHistory>> _getHSSEStaffStream({
    String? bulan, String? statusFilter, String? hsseUserId,
  }) {
    Query<Map<String, dynamic>> qm = _firestore
        .collection(collectionLemburMitra)
        .where('status', whereIn: allDisplayStatuses);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') qm = qm.where('tahun_bulan', isEqualTo: bulan);
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') qm = qm.where('status', isEqualTo: statusFilter);
    return qm.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var allData = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      allData = _groupByGroupId(allData);
      if (hsseUserId != null && hsseUserId.isNotEmpty) {
        allData = allData.where((item) {
          if (item.hsseStatus == 'pending') return true;
          if (item.hsseApprovedBy == hsseUserId) return true;
          if (item.hsseRejectedBy == hsseUserId) return true;
          if (item.hsseReviewBy == hsseUserId) return true;
          return false;
        }).toList();
      }
      allData.sort((a, b) {
        if (a.hsseStatus == 'pending' && b.hsseStatus != 'pending') return -1;
        if (b.hsseStatus == 'pending' && a.hsseStatus != 'pending') return 1;
        final levelOrder = {'kritis': 0, 'tinggi': 1, 'sedang': 2, 'rendah': 3};
        final aLevel = levelOrder[a.risikoLevel?.toLowerCase()] ?? 4;
        final bLevel = levelOrder[b.risikoLevel?.toLowerCase()] ?? 4;
        if (aLevel != bLevel) return aLevel.compareTo(bLevel);
        return b.tanggal.compareTo(a.tanggal);
      });
      return allData;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // PUBLIC HSSE STREAMS
  // ═══════════════════════════════════════════════════════════════

  Stream<List<OvertimeHistory>> getHSSERiskyOvertimeStream({
    String? bulan, String? statusFilter, String? risikoLevel,
    String? risikoKategori, String? hsseStatus, String? hsseUserId,
  }) {
    return _getHSSEManagerStream(
      bulan: bulan, statusFilter: statusFilter, hsseStatus: hsseStatus,
      risikoLevel: risikoLevel, risikoKategori: risikoKategori,
    ).map((data) {
      return data.where((item) {
        if (hssePendingStatuses.contains(item.status)) return true;
        if (item.isRisky) return true;
        if (item.risikoLevel != null &&
            ['tinggi', 'high', 'kritis', 'critical', 'sedang', 'medium']
                .contains(item.risikoLevel?.toLowerCase())) return true;
        if (item.hsseStatus != 'pending') return true;
        return false;
      }).toList();
    });
  }

  Stream<List<OvertimeHistory>> getHSSEApprovedByMeStream({
    required String hsseUserId, String? bulan, String? statusFilter,
  }) {
    Query<Map<String, dynamic>> qm = _firestore
        .collection(collectionLemburMitra)
        .where('status', whereIn: hsseResolvedStatuses);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') qm = qm.where('tahun_bulan', isEqualTo: bulan);
    return qm.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var allData = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      allData = _groupByGroupId(allData);
      allData = allData.where((item) {
        return item.hsseApprovedBy == hsseUserId ||
            item.hsseRejectedBy == hsseUserId ||
            item.hsseReviewBy == hsseUserId;
      }).toList();
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
        allData = allData.where((item) => item.status == statusFilter).toList();
      }
      allData.sort((a, b) {
        final aDate = a.hsseApprovedAt ?? a.hsseRejectedAt ?? a.createdAt;
        final bDate = b.hsseApprovedAt ?? b.hsseRejectedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
      return allData;
    });
  }

  Stream<List<OvertimeHistory>> getHSSEApprovalHistoryStream({
    required String hsseUserId, String? bulan, String? hsseStatus,
  }) {
    return getHSSEApprovedByMeStream(hsseUserId: hsseUserId, bulan: bulan, statusFilter: hsseStatus);
  }

  Stream<List<OvertimeHistory>> getHSSEManagerHistoryStream({
    String? bulan, String? statusFilter, String? hsseStatus,
    String? risikoLevel, String? risikoKategori,
  }) {
    return _getHSSEManagerStream(
      bulan: bulan, statusFilter: statusFilter, hsseStatus: hsseStatus,
      risikoLevel: risikoLevel, risikoKategori: risikoKategori,
    );
  }

  Stream<List<OvertimeHistory>> getHSSEEscalationStream({String? bulan}) {
    Query<Map<String, dynamic>> qm = _firestore
        .collection(collectionLemburMitra)
        .where('hsse_need_escalation', isEqualTo: true);
    if (bulan != null && bulan.isNotEmpty && bulan != 'semua') qm = qm.where('tahun_bulan', isEqualTo: bulan);
    return qm.orderBy('tanggal', descending: true).snapshots().map((snap) {
      var allData = snap.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      allData = _groupByGroupId(allData);
      allData.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      return allData;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // STATISTIK
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getOvertimeStats({
    required String userRole, String? userFungsi, String? userId, String? bulan,
  }) async {
    try {
      Query<Map<String, dynamic>> queryMitra = _firestore.collection(collectionLemburMitra);
      if (userRole == 'mitra' && userId != null && userId.isNotEmpty) {
        queryMitra = queryMitra.where('mitra_id', isEqualTo: userId);
      } else if (userRole == 'pengawas' && userId != null && userId.isNotEmpty) {
        queryMitra = queryMitra.where('diajukan_oleh_id', isEqualTo: userId);
      } else if (userRole == 'manager' && userFungsi != null && userFungsi.isNotEmpty) {
        queryMitra = queryMitra.where('pengawas_fungsi', isEqualTo: userFungsi);
      }
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        queryMitra = queryMitra.where('tahun_bulan', isEqualTo: bulan);
      }
      final allDocs = (await queryMitra.get()).docs;
      final Map<String, Map<String, dynamic>> uniqueGroups = {};
      for (var doc in allDocs) {
        final data = doc.data();
        final String groupId = (data['group_id'] ?? doc.id).toString();
        if (!uniqueGroups.containsKey(groupId)) uniqueGroups[groupId] = data;
      }
      int total = uniqueGroups.length;
      int pending = 0, approved = 0, completed = 0, rejected = 0, cancelled = 0;
      int needAbsensi = 0, riskyCount = 0;
      double totalJam = 0, totalBiaya = 0;
      double completedTotalJam = 0, completedTotalBiaya = 0;
      final Set<String> uniqueMitraIds = {};

      for (var entry in uniqueGroups.entries) {
        final data = entry.value;
        final String status = (data['status'] ?? '').toString().toLowerCase().trim();

        if (allActiveStatuses.contains(status)) {
          pending++;
          if (hssePendingStatuses.contains(status)) riskyCount++;
        } else if (status == 'disetujui' || status == 'approved') {
          approved++;
          final checkOutTime = data['check_out_time'];
          final absensiStatus = data['absensi_status'] as String?;
          if (checkOutTime == null && (absensiStatus == null || absensiStatus == 'belum_absen' || absensiStatus == 'check_in' || absensiStatus == 'sudah_absen')) {
            needAbsensi++;
          }
        } else if (status == 'selesai' || status == 'completed') {
          completed++;
          totalJam += _parseDouble(data['total_jam_desimal']);
          totalBiaya += _parseDouble(data['estimasi_biaya_total'] ?? data['estimasi_biaya']);
          completedTotalJam += _parseDouble(data['total_jam_desimal']);
          completedTotalBiaya += _parseDouble(data['estimasi_biaya_total'] ?? data['estimasi_biaya']);
        } else if (status == 'ditolak' || status == 'rejected') {
          rejected++;
        } else if (status == 'dibatalkan' || status == 'cancelled') {
          cancelled++;
        }

        if (data['is_risky'] == true || data['requires_hsse_approval'] == true) riskyCount++;
        final mitraId = data['mitra_id'] as String?;
        if (mitraId != null && mitraId.isNotEmpty) uniqueMitraIds.add(mitraId);
        final mitraIds = data['mitra_ids'] as List?;
        if (mitraIds != null && mitraIds.isNotEmpty) {
          for (var id in mitraIds) {
            if (id != null && id.toString().isNotEmpty) uniqueMitraIds.add(id.toString());
          }
        }
      }

      return {
        'total': total, 'pending': pending, 'approved': approved,
        'completed': completed, 'rejected': rejected, 'cancelled': cancelled,
        'needAbsensi': needAbsensi, 'totalJam': totalJam, 'totalBiaya': totalBiaya,
        'completedTotalJam': completedTotalJam, 'completedTotalBiaya': completedTotalBiaya,
        'riskyCount': riskyCount, 'totalMitra': uniqueMitraIds.length,
      };
    } catch (e) {
      debugPrint('❌ [getOvertimeStats] Error: $e');
      return {
        'total': 0, 'pending': 0, 'approved': 0, 'completed': 0,
        'rejected': 0, 'cancelled': 0, 'needAbsensi': 0,
        'totalJam': 0, 'totalBiaya': 0,
        'completedTotalJam': 0, 'completedTotalBiaya': 0,
        'riskyCount': 0, 'totalMitra': 0,
      };
    }
  }

  Future<Map<String, dynamic>> getHSSEStats({String? bulan, String? hsseUserId}) async {
    try {
      Query<Map<String, dynamic>> qm = _firestore
          .collection(collectionLemburMitra)
          .where('status', whereIn: allDisplayStatuses);
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') qm = qm.where('tahun_bulan', isEqualTo: bulan);
      var allDocs = (await qm.get()).docs;
      allDocs = allDocs.where((doc) {
        final data = doc.data();
        return data['is_risky'] == true || data['requires_hsse_approval'] == true ||
            hssePendingStatuses.contains(data['status']) || data['hsse_validated'] == true;
      }).toList();
      int totalRisky = allDocs.length;
      int pendingHSSE = 0, approvedHSSE = 0, rejectedHSSE = 0;
      int perluRevisi = 0, dalamReview = 0, escalated = 0;
      double totalBiaya = 0, completedTotalBiaya = 0;
      Set<String> fungsiSet = {};
      for (var doc in allDocs) {
        final overtime = OvertimeHistory.fromFirestore(doc);
        switch (overtime.hsseStatus) {
          case 'pending': pendingHSSE++; break;
          case 'disetujui': approvedHSSE++; break;
          case 'ditolak': rejectedHSSE++; break;
          case 'perlu_revisi': perluRevisi++; break;
          case 'dalam_review': dalamReview++; break;
        }
        if (overtime.hsseNeedEscalation) escalated++;
        final biaya = overtime.estimasiBiayaTotal > 0 ? overtime.estimasiBiayaTotal : overtime.estimasiBiayaPerMitra;
        totalBiaya += biaya;
        if (overtime.status == 'selesai' || overtime.status == 'completed') completedTotalBiaya += biaya;
        final fungsi = overtime.pengawasFungsi ?? overtime.fungsiMitra;
        if (fungsi != null) fungsiSet.add(fungsi);
      }
      return {
        'totalRisky': totalRisky, 'pendingHSSE': pendingHSSE,
        'approvedHSSE': approvedHSSE, 'rejectedHSSE': rejectedHSSE,
        'perluRevisi': perluRevisi, 'dalamReview': dalamReview, 'escalated': escalated,
        'totalBiaya': totalBiaya, 'completedTotalBiaya': completedTotalBiaya,
        'fungsiTerkait': fungsiSet.toList(),
        'approvalRate': totalRisky > 0 ? (approvedHSSE / totalRisky * 100) : 0,
        'rejectionRate': totalRisky > 0 ? (rejectedHSSE / totalRisky * 100) : 0,
      };
    } catch (e) {
      debugPrint('❌ [getHSSEStats] Error: $e');
      return {
        'totalRisky': 0, 'pendingHSSE': 0, 'approvedHSSE': 0, 'rejectedHSSE': 0,
        'perluRevisi': 0, 'dalamReview': 0, 'escalated': 0,
        'totalBiaya': 0, 'completedTotalBiaya': 0, 'fungsiTerkait': [],
        'approvalRate': 0, 'rejectionRate': 0,
      };
    }
  }

  Future<Map<String, dynamic>> getHSSEQuickStats() async {
    try {
      final mitraSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('status', whereIn: hssePendingStatuses)
          .where('hsse_status', isEqualTo: 'pending')
          .get();
      final pendingCount = mitraSnapshot.docs.length;
      int kritisCount = 0;
      for (var doc in mitraSnapshot.docs) {
        final riskLevel = (doc.data()['risiko_level'] ?? doc.data()['risk_level'] ?? '').toString().toLowerCase();
        if (riskLevel == 'kritis' || riskLevel == 'critical') kritisCount++;
      }
      return {
        'pendingTotal': pendingCount, 'kritisCount': kritisCount,
        'needsAttention': kritisCount > 0 || pendingCount > 5,
      };
    } catch (e) {
      return {'pendingTotal': 0, 'kritisCount': 0, 'needsAttention': false};
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥🔥🔥 METHOD UNTUK LEMBUR_MITRA (BUKAN PENGAJUAN)
  // ═══════════════════════════════════════════════════════════════

  /// Get overtime stats dari collection lembur_mitra (bukan pengajuan)
  /// Ini adalah source of truth untuk data lembur yang sudah disetujui
  Future<Map<String, dynamic>> getOvertimeStatsLemburMitra({
    required String userRole,
    String? userFungsi,
    String? userId,
    String? bulan,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);
      
      // Filter berdasarkan role
      if (userRole == 'mitra' && userId != null && userId.isNotEmpty) {
        query = query.where('mitra_id', isEqualTo: userId);
      } else if (userRole == 'pengawas' && userId != null && userId.isNotEmpty) {
        query = query.where('diajukan_oleh_id', isEqualTo: userId);
      } else if (userRole == 'manager' && userFungsi != null && userFungsi.isNotEmpty) {
        query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
      }
      
      // Filter bulan
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }
      
      final snapshot = await query.get();
      final docs = snapshot.docs;
      
      // 🔥 Group by group_id untuk menghindari duplikasi
      final Map<String, Map<String, dynamic>> uniqueGroups = {};
      for (var doc in docs) {
        final data = doc.data();
        final String groupId = (data['group_id'] ?? doc.id).toString();
        if (!uniqueGroups.containsKey(groupId)) {
          uniqueGroups[groupId] = data;
        }
      }
      
      int total = uniqueGroups.length;
      int pending = 0;
      int approved = 0;
      int completed = 0;
      int rejected = 0;
      int cancelled = 0;
      int needAbsensi = 0;
      int riskyCount = 0;
      double totalJam = 0;
      double totalBiaya = 0;
      double completedTotalJam = 0;
      double completedTotalBiaya = 0;
      final Set<String> uniqueMitraIds = {};
      
      for (var entry in uniqueGroups.entries) {
        final data = entry.value;
        final String status = (data['status'] ?? '').toString().toLowerCase().trim();
        
        // 🔥 Ambil total jam
        final jam = _parseDouble(data['total_jam_desimal']);
        final biaya = _parseDouble(data['estimasi_biaya_total'] ?? data['estimasi_biaya']);
        
        // 🔥 Count berdasarkan status
        if (status == 'pending' || status == 'menunggu') {
          pending++;
        } else if (status == 'disetujui' || status == 'approved') {
          approved++;
          // Cek perlu absensi
          final checkOutTime = data['check_out_time'];
          final absensiStatus = data['absensi_status'] as String?;
          if (checkOutTime == null && 
              (absensiStatus == null || 
               absensiStatus == 'belum_absen' || 
               absensiStatus == 'check_in' || 
               absensiStatus == 'sudah_absen')) {
            needAbsensi++;
          }
        } else if (status == 'selesai' || status == 'completed') {
          completed++;
          totalJam += jam;
          totalBiaya += biaya;
          completedTotalJam += jam;
          completedTotalBiaya += biaya;
        } else if (status == 'ditolak' || status == 'rejected') {
          rejected++;
        } else if (status == 'dibatalkan' || status == 'cancelled') {
          cancelled++;
        }
        
        // 🔥 Risky check
        if (data['is_risky'] == true || data['requires_hsse_approval'] == true) {
          riskyCount++;
        }
        
        // 🔥 Kumpulkan mitra unik
        final mitraId = data['mitra_id'] as String?;
        if (mitraId != null && mitraId.isNotEmpty) {
          uniqueMitraIds.add(mitraId);
        }
        final mitraIds = data['mitra_ids'] as List?;
        if (mitraIds != null && mitraIds.isNotEmpty) {
          for (var id in mitraIds) {
            if (id != null && id.toString().isNotEmpty) {
              uniqueMitraIds.add(id.toString());
            }
          }
        }
      }
      
      return {
        'total': total,
        'pending': pending,
        'approved': approved,
        'completed': completed,
        'rejected': rejected,
        'cancelled': cancelled,
        'needAbsensi': needAbsensi,
        'totalJam': totalJam,
        'totalBiaya': totalBiaya,
        'completedTotalJam': completedTotalJam,
        'completedTotalBiaya': completedTotalBiaya,
        'riskyCount': riskyCount,
        'totalMitra': uniqueMitraIds.length,
      };
    } catch (e) {
      debugPrint('❌ [getOvertimeStatsLemburMitra] Error: $e');
      return {
        'total': 0,
        'pending': 0,
        'approved': 0,
        'completed': 0,
        'rejected': 0,
        'cancelled': 0,
        'needAbsensi': 0,
        'totalJam': 0,
        'totalBiaya': 0,
        'completedTotalJam': 0,
        'completedTotalBiaya': 0,
        'riskyCount': 0,
        'totalMitra': 0,
      };
    }
  }

  /// Get HSSE stats dari collection lembur_mitra
  Future<Map<String, dynamic>> getHSSEStatsLemburMitra({
    String? bulan,
    String? hsseUserId,
  }) async {
    try {
      Query<Map<String, dynamic>> qm = _firestore
          .collection(collectionLemburMitra)
          .where('status', whereIn: allDisplayStatuses);
      
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        qm = qm.where('tahun_bulan', isEqualTo: bulan);
      }
      
      var allDocs = (await qm.get()).docs;
      
      // Filter untuk HSSE
      allDocs = allDocs.where((doc) {
        final data = doc.data();
        return data['is_risky'] == true || 
               data['requires_hsse_approval'] == true ||
               hssePendingStatuses.contains(data['status']) || 
               data['hsse_validated'] == true;
      }).toList();
      
      // Group by group_id
      final Map<String, Map<String, dynamic>> uniqueGroups = {};
      for (var doc in allDocs) {
        final data = doc.data();
        final String groupId = (data['group_id'] ?? doc.id).toString();
        if (!uniqueGroups.containsKey(groupId)) {
          uniqueGroups[groupId] = data;
        }
      }
      
      int totalRisky = uniqueGroups.length;
      int pendingHSSE = 0;
      int approvedHSSE = 0;
      int rejectedHSSE = 0;
      int perluRevisi = 0;
      int dalamReview = 0;
      int escalated = 0;
      double totalBiaya = 0;
      double completedTotalBiaya = 0;
      Set<String> fungsiSet = {};
      
      for (var entry in uniqueGroups.entries) {
        final data = entry.value;
        final id = entry.key;
        
        // 🔥🔥🔥 V11: Gunakan OvertimeHistory.fromMap langsung
        final overtime = OvertimeHistory.fromMap(data, id);
        
        switch (overtime.hsseStatus) {
          case 'pending': pendingHSSE++; break;
          case 'disetujui': approvedHSSE++; break;
          case 'ditolak': rejectedHSSE++; break;
          case 'perlu_revisi': perluRevisi++; break;
          case 'dalam_review': dalamReview++; break;
        }
        
        if (overtime.hsseNeedEscalation) escalated++;
        
        final biaya = overtime.estimasiBiayaTotal > 0 
            ? overtime.estimasiBiayaTotal 
            : overtime.estimasiBiayaPerMitra;
        totalBiaya += biaya;
        
        if (overtime.status == 'selesai' || overtime.status == 'completed') {
          completedTotalBiaya += biaya;
        }
        
        final fungsi = overtime.pengawasFungsi ?? overtime.fungsiMitra;
        if (fungsi != null && fungsi.isNotEmpty) {
          fungsiSet.add(fungsi);
        }
      }
      
      return {
        'totalRisky': totalRisky,
        'pendingHSSE': pendingHSSE,
        'approvedHSSE': approvedHSSE,
        'rejectedHSSE': rejectedHSSE,
        'perluRevisi': perluRevisi,
        'dalamReview': dalamReview,
        'escalated': escalated,
        'totalBiaya': totalBiaya,
        'completedTotalBiaya': completedTotalBiaya,
        'fungsiTerkait': fungsiSet.toList(),
        'approvalRate': totalRisky > 0 ? (approvedHSSE / totalRisky * 100) : 0,
        'rejectionRate': totalRisky > 0 ? (rejectedHSSE / totalRisky * 100) : 0,
      };
    } catch (e) {
      debugPrint('❌ [getHSSEStatsLemburMitra] Error: $e');
      return {
        'totalRisky': 0,
        'pendingHSSE': 0,
        'approvedHSSE': 0,
        'rejectedHSSE': 0,
        'perluRevisi': 0,
        'dalamReview': 0,
        'escalated': 0,
        'totalBiaya': 0,
        'completedTotalBiaya': 0,
        'fungsiTerkait': [],
        'approvalRate': 0,
        'rejectionRate': 0,
      };
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CRUD & GET BY ID
  // ═══════════════════════════════════════════════════════════════

  Future<OvertimeHistory?> getOvertimeById(String id) async {
    try {
      final doc = await _findDocument(id);
      return doc != null ? OvertimeHistory.fromFirestore(doc) : null;
    } catch (e) {
      return null;
    }
  }

  Future<List<OvertimeHistory>> getOvertimeByGroupId(String groupId) async {
    try {
      final mitraDocs = await _firestore
          .collection(collectionLemburMitra)
          .where('group_id', isEqualTo: groupId)
          .get();
      return _groupByGroupId(
        mitraDocs.docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList()
      );
    } catch (e) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PEMBATALAN PENGAJUAN
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> batalkanPengajuan({
    required String documentId,
    required String userId,
  }) async {
    try {
      final userRole = await _getUserRole(userId);
      if (userRole != 'pengawas') {
        return {'success': false, 'message': 'Hanya pengawas yang dapat membatalkan pengajuan'};
      }

      final docSnapshot = await _findDocument(documentId);
      if (docSnapshot == null) {
        return {'success': false, 'message': 'Data pengajuan tidak ditemukan'};
      }

      final data = docSnapshot.data()!;
      final status = data['status'] as String?;
      final createdAt = (data['created_at'] as Timestamp?)?.toDate();
      final diajukanOlehId = data['diajukan_oleh_id'] as String?;

      if (diajukanOlehId != userId) {
        return {'success': false, 'message': 'Anda hanya dapat membatalkan pengajuan yang Anda buat sendiri'};
      }
      if (status != 'pending' && status != 'disetujui') {
        return {'success': false, 'message': 'Hanya pengajuan dengan status menunggu atau disetujui yang bisa dibatalkan'};
      }
      if (createdAt != null && DateTime.now().difference(createdAt).inDays > batasWaktuPembatalan) {
        return {'success': false, 'message': 'Batas waktu pembatalan sudah lewat (maksimal $batasWaktuPembatalan hari)'};
      }

      final updateData = <String, dynamic>{
        'status': 'dibatalkan',
        'dibatalkan_pada': FieldValue.serverTimestamp(),
        'dibatalkan_oleh': userId,
        'updated_at': FieldValue.serverTimestamp(),
      };

      await docSnapshot.reference.update(updateData);

      final groupId = data['group_id'] as String?;
      if (groupId != null && groupId.isNotEmpty) {
        try {
          final mitraDocs = await _firestore
              .collection(collectionLemburMitra)
              .where('group_id', isEqualTo: groupId)
              .get();
          for (var doc in mitraDocs.docs) {
            await doc.reference.update(updateData);
          }
        } catch (e) {
          debugPrint('⚠️ Gagal sinkronisasi group: $e');
        }
      }

      await _logActivity(action: 'batalkan_pengajuan', documentId: documentId, userId: userId, details: 'Membatalkan pengajuan lembur');
      return {'success': true, 'message': 'Pengajuan berhasil dibatalkan'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal: ${e.toString()}'};
    }
  }

  Future<bool> canBatalkanPengajuan(String documentId) async {
    try {
      final docSnapshot = await _findDocument(documentId);
      if (docSnapshot == null) return false;
      final data = docSnapshot.data()!;
      final status = data['status'] as String?;
      final createdAt = (data['created_at'] as Timestamp?)?.toDate();
      if (status != 'pending' && status != 'disetujui') return false;
      if (createdAt != null) return DateTime.now().difference(createdAt).inDays <= batasWaktuPembatalan;
      return false;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UPDATE OVERTIME STATUS
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> updateOvertimeStatus({
    required String docId, required String status, String? note,
  }) async {
    try {
      final doc = await _findDocument(docId);
      if (doc == null) return {'success': false, 'message': 'Dokumen tidak ditemukan'};

      final data = doc.data()!;
      final groupId = data['group_id'] as String?;
      final updateData = <String, dynamic>{
        'status': status, 'updated_at': FieldValue.serverTimestamp(), 'last_modified_at': FieldValue.serverTimestamp(),
      };
      if (status == 'disetujui') {
        updateData['approved_at'] = FieldValue.serverTimestamp();
        updateData['approved_by'] = 'system';
        updateData['approved_by_name'] = 'System (Superadmin)';
      } else if (status == 'ditolak' && note != null) {
        updateData['rejected_reason'] = note;
        updateData['rejected_at'] = FieldValue.serverTimestamp();
      } else if (status == 'selesai') {
        updateData['completed_at'] = FieldValue.serverTimestamp();
      }

      await doc.reference.update(updateData);
      if (groupId != null && groupId.isNotEmpty) {
        try {
          final mitraDocs = await _firestore.collection(collectionLemburMitra).where('group_id', isEqualTo: groupId).get();
          for (var mitraDoc in mitraDocs.docs) await mitraDoc.reference.update(updateData);
        } catch (e) { debugPrint('⚠️ Gagal sinkronisasi: $e'); }
      }
      await _logActivity(action: 'update_status', documentId: docId, userId: 'system', details: 'Status: $status');
      return {'success': true, 'message': 'Status berhasil diupdate'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal: ${e.toString()}'};
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILITY
  // ═══════════════════════════════════════════════════════════════

  String getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Menunggu Manager';
      case 'manager_approved': return 'Disetujui Manager';
      case 'pending_hsse': case 'manager_approval_pending_hsse':
      case 'manager_approved_pending_hsse': return 'Menunggu HSSE';
      case 'disetujui': return 'Disetujui'; case 'ditolak': return 'Ditolak';
      case 'selesai': return 'Selesai'; case 'kadaluarsa': return 'Kadaluarsa';
      case 'dibatalkan': return 'Dibatalkan'; default: return status;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'manager_approved': return Colors.blue.shade400;
      case 'pending_hsse': case 'manager_approval_pending_hsse':
      case 'manager_approved_pending_hsse': return Colors.deepOrange;
      case 'disetujui': return Colors.green; case 'ditolak': return Colors.red;
      case 'selesai': return Colors.blue; case 'kadaluarsa': return Colors.grey;
      case 'dibatalkan': return Colors.red.shade300; default: return Colors.grey;
    }
  }

  String formatRupiah(dynamic value) {
    final number = (value is num) ? value : 0;
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  // ═══════════════════════════════════════════════════════════════
  // EXPORT CSV
  // ═══════════════════════════════════════════════════════════════

  Future<String> exportToCsv({
    required String userRole, String? userFungsi, String? userId,
    String? bulan, String? statusFilter, bool includeHSSE = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(collectionLemburMitra);
      if (userRole == 'mitra' && userId != null) query = query.where('mitra_id', isEqualTo: userId);
      else if (userRole == 'pengawas' && userId != null) query = query.where('diajukan_oleh_id', isEqualTo: userId);
      else if (userRole == 'manager' && userFungsi != null && userFungsi.isNotEmpty) query = query.where('pengawas_fungsi', isEqualTo: userFungsi);
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') query = query.where('tahun_bulan', isEqualTo: bulan);
      var allData = (await query.get()).docs.map((doc) => OvertimeHistory.fromFirestore(doc)).toList();
      allData = _filterByBulan(allData, bulan);
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'semua') {
        allData = allData.where((item) => item.status == statusFilter).toList();
      }
      allData = _groupByGroupId(allData);
      allData.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      final csvBuffer = StringBuffer();
      List<String> headers = ['No', 'Tanggal', 'Nama Mitra', 'Jam Mulai', 'Jam Selesai', 'Total Jam', 'Status', 'Biaya', 'Fungsi', 'Jenis Lembur', 'Urgensi'];
      if (includeHSSE) headers.addAll(['HSSE Status', 'Risiko Level', 'Risiko Kategori', 'HSSE Oleh', 'HSSE Catatan']);
      csvBuffer.writeln(headers.join(','));
      for (var i = 0; i < allData.length; i++) {
        final item = allData[i];
        List<String> row = [
          (i + 1).toString(), DateFormat('dd/MM/yyyy').format(item.tanggal),
          '"${item.namaMitra ?? '-'}"', item.jamMulai, item.jamSelesai,
          item.totalJam.toStringAsFixed(1), item.statusLabel,
          (item.estimasiBiayaTotal > 0 ? item.estimasiBiayaTotal : item.estimasiBiayaPerMitra).toStringAsFixed(0),
          item.pengawasFungsi ?? '-', item.jenisLembur, item.urgensi,
        ];
        if (includeHSSE) {
          row.addAll([item.hsseStatusLabel, item.risikoLevel ?? '-', item.risikoKategori ?? '-', item.hsseApprovedByName ?? item.hsseRejectedByName ?? '-', '"${item.hsseCatatan ?? '-'}"']);
        }
        csvBuffer.writeln(row.join(','));
      }
      return csvBuffer.toString();
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getHSSEActivityLogs({String? userId, int limit = 50}) {
    Query<Map<String, dynamic>> query = _firestore.collection(collectionHSSELogs).orderBy('timestamp', descending: true).limit(limit);
    if (userId != null && userId.isNotEmpty) query = query.where('user_id', isEqualTo: userId);
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      return {'id': doc.id, ...data, 'timestamp': (data['timestamp'] as Timestamp?)?.toDate()};
    }).toList());
  }

  Future<void> _logActivity({
    required String action, required String documentId,
    required String userId, String? details,
  }) async {
    try {
      await _firestore.collection(collectionActivityLogs).add({
        'action': action, 'document_id': documentId,
        'user_id': userId, 'timestamp': FieldValue.serverTimestamp(), 'details': details,
      });
    } catch (e) {
      debugPrint('⚠️ Error logging activity: $e');
    }
  }
}