export '/core/services/overtime_history_service.dart' 
    show OvertimeHistory, HSSEViewMode;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '/core/services/overtime_history_service.dart';
import '/core/services/network_service.dart'; // 🔥 NETWORK SERVICE

var logger = Logger();

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration KONFIRMASI_GRACE_PERIOD = Duration(days: 3);
// 🔥 FIX: disamakan dengan window "belum waktunya" di AbsensiPage (30 menit).
// Sebelumnya nilainya 10 menit, beda dengan UI (30 menit) — menyebabkan
// server sudah menganggap "boleh check-in" 20 menit lebih awal dari yang
// ditampilkan UI, rawan bikin state UI dan server tidak sinkron.
const Duration CHECKIN_EARLY_WINDOW = Duration(minutes: 30);
const Duration ABSENSI_NORMAL_WINDOW = Duration(minutes: 30);
const Duration CHECKOUT_EARLY_WINDOW = Duration(minutes: 30);
const Duration CHECKOUT_LATE_WINDOW = Duration(minutes: 30);

// ============================================================================
// STATUS FILTER CONSTANTS
// ============================================================================

const List<String> _excludedStatuses = ['dibatalkan', 'cancelled', 'ditolak', 'rejected'];

// ============================================================================
// EXTENSION: OvertimeHistoryAbsensi
// ============================================================================

extension OvertimeHistoryAbsensi on OvertimeHistory {
  
  String get absensiStatus {
    try {
      final raw = (this as dynamic).rawData as Map<String, dynamic>?;
      if (raw != null && raw.containsKey('absensi_status')) {
        return raw['absensi_status']?.toString() ?? 'belum_absen';
      }
    } catch (_) {}
    
    try {
      final data = (this as dynamic).data as Map<String, dynamic>?;
      if (data != null && data.containsKey('absensi_status')) {
        return data['absensi_status']?.toString() ?? 'belum_absen';
      }
    } catch (_) {}
    
    return 'belum_absen';
  }
  
  DateTime? get absensiWaktu {
    try {
      final raw = (this as dynamic).rawData as Map<String, dynamic>?;
      if (raw != null) {
        if (raw.containsKey('absensi_waktu')) {
          final val = raw['absensi_waktu'];
          if (val is Timestamp) return val.toDate();
          if (val is DateTime) return val;
        }
        if (raw.containsKey('check_in_waktu')) {
          final val = raw['check_in_waktu'];
          if (val is Timestamp) return val.toDate();
          if (val is DateTime) return val;
        }
        if (raw.containsKey('check_in_time')) {
          final val = raw['check_in_time'];
          if (val is Timestamp) return val.toDate();
          if (val is DateTime) return val;
        }
      }
    } catch (_) {}
    return null;
  }
  
  String? get absensiFotoUrl {
    try {
      final raw = (this as dynamic).rawData as Map<String, dynamic>?;
      if (raw != null) {
        if (raw.containsKey('absensi_foto_url')) return raw['absensi_foto_url']?.toString();
        if (raw.containsKey('check_in_foto_url')) return raw['check_in_foto_url']?.toString();
      }
    } catch (_) {}
    return null;
  }
  
  String? get absensiOleh {
    try {
      final raw = (this as dynamic).rawData as Map<String, dynamic>?;
      if (raw != null && raw.containsKey('absensi_oleh')) {
        return raw['absensi_oleh']?.toString();
      }
    } catch (_) {}
    return null;
  }
  
  String? get absensiNama {
    try {
      final raw = (this as dynamic).rawData as Map<String, dynamic>?;
      if (raw != null && raw.containsKey('absensi_nama')) {
        return raw['absensi_nama']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? get absensiKeterlambatan {
    try {
      final raw = (this as dynamic).rawData as Map<String, dynamic>?;
      if (raw != null && raw.containsKey('absensi_keterlambatan')) {
        return raw['absensi_keterlambatan'] as Map<String, dynamic>?;
      }
      if (raw != null && raw.containsKey('konfirmasi_keterlambatan')) {
        return raw['konfirmasi_keterlambatan'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  String get absensiStatusLabel {
    switch (absensiStatus) {
      case 'belum_absen':       return 'Belum Absen';
      case 'sudah_absen':       return 'Sudah Absen';
      case 'check_in':          return '✅ Check In';
      case 'check_out':         return '📤 Check Out';
      case 'selesai':           return '✅ Selesai';
      case 'selesai_terlambat': return '⚠️ Absen Terlambat';
      case 'tidak_lembur':      return '❌ Tidak Lembur';
      case 'expired':           return '⏰ Kadaluarsa';
      default:                  return absensiStatus;
    }
  }

  Color get absensiStatusColor {
    switch (absensiStatus) {
      case 'check_in': case 'selesai': case 'sudah_absen': return Colors.green;
      case 'selesai_terlambat': return Colors.orange;
      case 'tidak_lembur': case 'expired': return Colors.red;
      case 'belum_absen': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData get absensiStatusIcon {
    switch (absensiStatus) {
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

  bool get isAbsensiResolved {
    const resolved = ['selesai', 'selesai_terlambat', 'tidak_lembur', 'expired', 'check_in', 'sudah_absen'];
    return resolved.contains(absensiStatus);
  }

  bool get isCheckedIn => absensiStatus == 'check_in' || absensiStatus == 'sudah_absen';
  bool get isCheckedOut => absensiStatus == 'selesai' || absensiStatus == 'selesai_terlambat';
  bool get canAbsen => !isAbsensiResolved || absensiStatus == 'belum_absen';
}

// ============================================================================
// MODEL: OvertimeAbsensi
// ============================================================================

class OvertimeAbsensi {
  final String id;
  final String lemburId;
  final String userId;
  final String userName;
  final String fotoUrl;
  final String jenis;
  final String absensiStatus;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime waktu;
  final DateTime createdAt;
  final String? deviceInfo;
  final double? batteryLevel;

  OvertimeAbsensi({
    required this.id, required this.lemburId, required this.userId,
    required this.userName, required this.fotoUrl, required this.jenis,
    required this.absensiStatus, this.latitude, this.longitude,
    this.address, required this.waktu, required this.createdAt,
    this.deviceInfo, this.batteryLevel,
  });

  factory OvertimeAbsensi.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return OvertimeAbsensi(
      id: doc.id, lemburId: data['lembur_id'] as String? ?? '',
      userId: data['user_id'] as String? ?? '',
      userName: data['user_name'] as String? ?? '',
      fotoUrl: data['foto_url'] as String? ?? '',
      jenis: data['jenis'] as String? ?? 'check_in',
      absensiStatus: data['absensi_status'] as String? ?? 'check_in',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address']?.toString(),
      waktu: _parseTimestamp(data['waktu']),
      createdAt: _parseTimestamp(data['created_at']),
      deviceInfo: data['device_info']?.toString(),
      batteryLevel: (data['battery_level'] as num?)?.toDouble(),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Map<String, dynamic> toMap() => {
    'lembur_id': lemburId, 'user_id': userId, 'user_name': userName,
    'foto_url': fotoUrl, 'jenis': jenis, 'absensi_status': absensiStatus,
    'waktu': Timestamp.fromDate(waktu), 'created_at': Timestamp.fromDate(createdAt),
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (address != null) 'address': address,
    if (deviceInfo != null) 'device_info': deviceInfo,
    if (batteryLevel != null) 'battery_level': batteryLevel,
  };
}

// ============================================================================
// MODEL: TenggatInfo
// ============================================================================

class TenggatInfo {
  final String label;
  final String labelSingkat;
  final String status;
  final Duration sisaWaktu;
  final DateTime batasMulai;
  final DateTime batasNormal;
  final DateTime batasExpired;
  final bool isNormal;
  final bool isLate;
  final bool isExpired;
  final bool canConfirm;
  final bool canAbsenNormal;
  final double progressPercent;
  final String jamMulai;
  final String jamSelesai;
  final String tanggalLembur;

  const TenggatInfo({
    required this.label, required this.labelSingkat, required this.status,
    required this.sisaWaktu, required this.batasMulai, required this.batasNormal,
    required this.batasExpired, required this.isNormal, required this.isLate,
    required this.isExpired, required this.canConfirm, required this.canAbsenNormal,
    required this.progressPercent, required this.jamMulai, required this.jamSelesai,
    required this.tanggalLembur,
  });

  String get sisaWaktuFormatted {
    if (isExpired || sisaWaktu.isNegative) return 'Kadaluarsa';
    final hari = sisaWaktu.inDays;
    final jam = sisaWaktu.inHours.remainder(24);
    final menit = sisaWaktu.inMinutes.remainder(60);
    final parts = <String>[];
    if (hari > 0) parts.add('$hari h');
    if (jam > 0) parts.add('$jam j');
    if (menit > 0) parts.add('$menit m');
    return parts.isEmpty ? '0 mnt' : parts.join(' ');
  }

  String get sisaWaktuSingkat {
    if (isExpired) return 'EXP';
    if (sisaWaktu.inDays > 0) return '${sisaWaktu.inDays}h';
    if (sisaWaktu.inHours > 0) return '${sisaWaktu.inHours}j';
    if (sisaWaktu.inMinutes > 0) return '${sisaWaktu.inMinutes}m';
    return '${sisaWaktu.inSeconds}d';
  }

  String get batasNormalJam => DateFormat('HH:mm', 'id_ID').format(batasNormal);
  String get batasExpiredJam => DateFormat('HH:mm', 'id_ID').format(batasExpired);
  String get batasExpiredFull => DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(batasExpired);

  int get prioritas {
    if (isExpired) return 0;
    if (sisaWaktu.inMinutes < 30) return 1;
    if (sisaWaktu.inHours < 1) return 2;
    if (sisaWaktu.inHours < 2) return 3;
    if (sisaWaktu.inHours < 6) return 4;
    if (isLate) return 5;
    return 6;
  }

  Color get prioritasColor {
    switch (prioritas) {
      case 0: return Colors.red; case 1: return Colors.deepOrange;
      case 2: return Colors.orange; case 3: return Colors.amber;
      case 4: return Colors.yellow; case 5: return Colors.lime;
      default: return Colors.green;
    }
  }

  String get prioritasLabel {
    switch (prioritas) {
      case 0: return 'EXPIRED'; case 1: return 'KRITIS';
      case 2: return 'URGENT'; case 3: return 'WARNING';
      case 4: return 'PERHATIAN'; case 5: return 'TERLAMBAT';
      default: return 'NORMAL';
    }
  }

  bool get bisaDikonfirmasi => canConfirm && !isExpired;
}

// ============================================================================
// SERVICE: OvertimeAbsensiService - ONLY lembur_mitra
// ============================================================================

class OvertimeAbsensiService {
  static final OvertimeAbsensiService _instance = OvertimeAbsensiService._internal();
  factory OvertimeAbsensiService() => _instance;
  OvertimeAbsensiService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 🔥 NETWORK SERVICE
  final NetworkService _networkService = NetworkService();

  // 🔥 HANYA PAKAI lembur_mitra
  static const String _cLembur = 'lembur_mitra';
  static const String _cAbsensi = 'absensi';
  static const String _cLog = 'activity_logs';
  static const String _cUsers = 'users';

  // ==========================================================================
  // STATUS CONSTANTS
  // ==========================================================================
  
  static const List<String> _resolvedStatuses = [
    'selesai', 'expired', 'selesai_terlambat', 'tidak_lembur', 
    'check_in', 'sudah_absen', 'check_out'
  ];
  
  static const List<String> _pendingStatusesForQuery = [
    'belum_absen', 'check_in', 'sudah_absen'
  ];
  
  static const List<String> _validAbsensiStatuses = [
    'disetujui', 'approved', 'selesai',
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

  // ==========================================================================
  // PRIVATE HELPERS
  // ==========================================================================

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findDoc(String id) async {
    final doc = await _firestore.collection(_cLembur).doc(id).get();
    if (doc.exists) {
      final data = doc.data();
      if (data == null) return null;
      final status = data['status'] as String? ?? '';
      final isCancelled = data['is_cancelled'] == true;
      if (_excludedStatuses.contains(status) || isCancelled) {
        debugPrint('⛔ _findDoc: Dokumen $id dibatalkan (status: $status, is_cancelled: $isCancelled)');
        return null;
      }
      return doc;
    }
    return null;
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  DateTime _parseJam(DateTime tanggal, String jamStr) {
    final parts = jamStr.split(':');
    final jam = int.tryParse(parts[0]) ?? 0;
    final menit = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(tanggal.year, tanggal.month, tanggal.day, jam, menit);
  }

  DateTime _hitungBatasExpired(DateTime selesaiTime) => selesaiTime.add(KONFIRMASI_GRACE_PERIOD);
  DateTime _hitungBatasNormal(DateTime selesaiTime) => selesaiTime.add(ABSENSI_NORMAL_WINDOW);
  DateTime _hitungEarliestCheckIn(DateTime mulaiTime) => mulaiTime.subtract(CHECKIN_EARLY_WINDOW);
  DateTime _hitungCheckOutStart(DateTime selesaiTime) => selesaiTime.subtract(CHECKOUT_EARLY_WINDOW);
  DateTime _hitungCheckOutEnd(DateTime selesaiTime) => selesaiTime.add(CHECKOUT_LATE_WINDOW);

  bool _isPendingStatus(String? status) {
    if (status == null) return true;
    if (status.isEmpty) return true;
    return _pendingStatusesForQuery.contains(status);
  }

  bool _isTruePending(String? status) {
    if (status == null) return true;
    if (status.isEmpty) return true;
    return status == 'belum_absen';
  }

  bool _isCancelledStatus(String? status) {
    if (status == null) return false;
    return _excludedStatuses.contains(status);
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'belum_absen': return 'Belum Absen';
      case 'sudah_absen': return 'Sudah Absen';
      case 'check_in': return 'Check In';
      case 'check_out': return 'Check Out';
      case 'selesai': return 'Selesai';
      case 'selesai_terlambat': return 'Absen Terlambat';
      case 'tidak_lembur': return 'Tidak Lembur';
      case 'expired': return 'Kadaluarsa';
      case 'dibatalkan': return 'Dibatalkan';
      default: return status;
    }
  }

  Future<void> _log(String action, String docId, String userId, [String? detail]) async {
    try {
      await _firestore.collection(_cLog).add({
        'action': action, 'document_id': docId, 'user_id': userId,
        'timestamp': FieldValue.serverTimestamp(), 'details': detail,
        'module': 'absensi', 'platform': 'mobile',
      });
    } catch (e) {
      logger.e('Failed to log activity: $e');
    }
  }

  Future<bool> _isUserValid(String userId) async {
    try {
      final doc = await _firestore.collection(_cUsers).doc(userId).get();
      return doc.exists;
    } catch (_) { return false; }
  }

  bool _hasAccess(Map<String, dynamic> data, String userId) {
    final mitraId = data['mitra_id'] as String?;
    final mitraIds = (data['mitra_ids'] as List?)?.cast<String>() ?? [];
    final pengawasId = data['pengawas_id'] as String?;
    final diajukanOlehId = data['diajukan_oleh_id'] as String?;
    return mitraId == userId || mitraIds.contains(userId) || 
           pengawasId == userId || diajukanOlehId == userId;
  }

  // ==========================================================================
  // 1. SUBMIT ABSENSI (CHECK-IN) - 🔥 DENGAN NETWORK CHECK
  // ==========================================================================

  Future<Map<String, dynamic>> submitAbsensi({
    required String docId, required String fotoUrl, required String userId,
    required String userName, double? latitude, double? longitude,
    String? address, String? deviceInfo, double? batteryLevel,
  }) async {
    // 🔥 CEK KONEKSI
    if (!_checkConnection('submitAbsensi')) {
      return {
        'success': false, 
        'message': 'Tidak ada koneksi internet. Tidak dapat melakukan absensi.',
        'code': 'NO_CONNECTION'
      };
    }

    final stopwatch = Stopwatch()..start();
    
    try {
      if (docId.isEmpty) return {'success': false, 'message': 'ID dokumen tidak valid', 'code': 'INVALID_DOC_ID'};
      if (fotoUrl.isEmpty) return {'success': false, 'message': 'URL foto tidak valid', 'code': 'INVALID_PHOTO'};
      if (userId.isEmpty) return {'success': false, 'message': 'User ID tidak valid', 'code': 'INVALID_USER_ID'};
      if (userName.isEmpty) return {'success': false, 'message': 'Nama user tidak valid', 'code': 'INVALID_USER_NAME'};

      final userValid = await _isUserValid(userId);
      if (!userValid) return {'success': false, 'message': 'User tidak ditemukan', 'code': 'USER_NOT_FOUND'};

      final doc = await _findDoc(docId);
      if (doc == null) return {'success': false, 'message': 'Data lembur tidak ditemukan atau telah dibatalkan', 'code': 'DOC_NOT_FOUND'};

      final data = doc.data()!;
      final ref = doc.reference;

      final lemburStatus = (data['status'] as String? ?? '').toLowerCase();
      if (_isCancelledStatus(lemburStatus)) {
        return {'success': false, 'message': 'Lembur telah dibatalkan', 'code': 'CANCELLED'};
      }
      if (lemburStatus != 'disetujui' && lemburStatus != 'approved') {
        return {'success': false, 'message': 'Lembur belum disetujui (status: $lemburStatus)', 'code': 'NOT_APPROVED'};
      }

      final currentAbsensi = data['absensi_status'] as String? ?? 'belum_absen';
      if (_resolvedStatuses.contains(currentAbsensi)) {
        return {'success': false, 'message': 'Absensi sudah diproses (${_getStatusLabel(currentAbsensi)})', 'code': 'ALREADY_RESOLVED', 'currentStatus': currentAbsensi};
      }

      if (!_hasAccess(data, userId)) {
        return {'success': false, 'message': 'Anda tidak memiliki akses', 'code': 'ACCESS_DENIED'};
      }

      final now = DateTime.now();
      final tanggal = _parseTimestamp(data['tanggal']);
      final jamMulai = data['jam_mulai'] as String? ?? '00:00';
      final jamSelesai = data['jam_selesai'] as String? ?? '00:00';
      
      final mulaiTime = _parseJam(tanggal, jamMulai);
      var selesaiTime = _parseJam(tanggal, jamSelesai);
      if (selesaiTime.isBefore(mulaiTime)) selesaiTime = selesaiTime.add(const Duration(days: 1));
      
      final earliestCheckIn = _hitungEarliestCheckIn(mulaiTime);
      final batasNormal = _hitungBatasNormal(selesaiTime);
      
      if (now.isBefore(earliestCheckIn)) {
        final diff = earliestCheckIn.difference(now);
        return {'success': false, 'message': '⏰ Check-in dibuka dalam ${diff.inHours}j ${diff.inMinutes.remainder(60)}m (${DateFormat('HH:mm').format(earliestCheckIn)} WIB)', 'code': 'TOO_EARLY', 'availableAt': earliestCheckIn.toIso8601String()};
      }

      final isLate = now.isAfter(batasNormal);
      if (isLate) {
        return {'success': false, 'message': '⚠️ Sudah melewati batas absensi normal (${DateFormat('HH:mm').format(batasNormal)}). Silakan konfirmasi keterlambatan.', 'code': 'LATE_CHECKIN', 'batasNormal': DateFormat('HH:mm').format(batasNormal)};
      }

      final updateData = <String, dynamic>{
        'absensi_status': 'check_in', 'absensi_foto_url': fotoUrl,
        'absensi_waktu': FieldValue.serverTimestamp(), 'absensi_oleh': userId,
        'absensi_nama': userName, 'check_in_waktu': FieldValue.serverTimestamp(),
        'check_in_time': FieldValue.serverTimestamp(), 'check_in_foto_url': fotoUrl,
        'updated_at': FieldValue.serverTimestamp(), 'updated_by': userId,
      };
      if (latitude != null) updateData['check_in_latitude'] = latitude;
      if (longitude != null) updateData['check_in_longitude'] = longitude;
      if (address != null) updateData['check_in_address'] = address;

      try {
        await ref.update(updateData);
      } catch (e) {
        logger.w('⚠️ update failed: $e - Trying setData with merge...');
        await ref.set(updateData, SetOptions(merge: true));
      }

      final absensiRef = await _firestore.collection(_cAbsensi).add({
        'lembur_id': docId, 'user_id': userId, 'user_name': userName,
        'foto_url': fotoUrl, 'absensi_status': 'check_in', 'jenis': 'check_in',
        'waktu': FieldValue.serverTimestamp(), 'created_at': FieldValue.serverTimestamp(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (address != null) 'address': address,
        if (deviceInfo != null) 'device_info': deviceInfo,
        if (batteryLevel != null) 'battery_level': batteryLevel,
      });

      await _log('submit_check_in', docId, userId, 'Check-in berhasil | ${DateFormat('HH:mm').format(now)} | ${isLate ? "TERLAMBAT" : "NORMAL"}');

      stopwatch.stop();
      logger.i('✅ submitAbsensi completed in ${stopwatch.elapsedMilliseconds}ms');

      return {
        'success': true, 'message': '✅ Check-in berhasil! Selamat bekerja! 💪',
        'absensiId': absensiRef.id, 'absensiStatus': 'check_in',
        'checkInTime': now.toIso8601String(), 'isLate': isLate,
      };
    } catch (e) {
      logger.e('❌ submitAbsensi error: $e');
      
      // 🔥 Cek network error
      if (e.toString().contains('SocketException') || e.toString().contains('network')) {
        return {'success': false, 'message': 'Koneksi internet terputus. Silakan coba lagi.', 'code': 'NETWORK_ERROR'};
      }
      
      return {'success': false, 'message': 'Gagal submit absensi: ${e.toString()}', 'code': 'SYSTEM_ERROR'};
    }
  }

  // ==========================================================================
  // 2. SUBMIT CHECK-OUT - 🔥 DENGAN NETWORK CHECK
  // ==========================================================================

  Future<Map<String, dynamic>> submitCheckOut({
    required String docId, required String userId, required String userName,
    required String fotoUrl, double? latitude, double? longitude, String? address,
  }) async {
    // 🔥 CEK KONEKSI
    if (!_checkConnection('submitCheckOut')) {
      return {
        'success': false,
        'message': 'Tidak ada koneksi internet. Tidak dapat melakukan check-out.',
        'code': 'NO_CONNECTION'
      };
    }

    try {
      if (docId.isEmpty) return {'success': false, 'message': 'ID tidak valid', 'code': 'INVALID_ID'};
      if (fotoUrl.isEmpty) return {'success': false, 'message': 'Foto tidak valid', 'code': 'INVALID_PHOTO'};

      final doc = await _findDoc(docId);
      if (doc == null) return {'success': false, 'message': 'Data tidak ditemukan atau telah dibatalkan', 'code': 'NOT_FOUND'};

      final data = doc.data()!;
      final ref = doc.reference;

      final lemburStatus = (data['status'] as String? ?? '').toLowerCase();
      if (_isCancelledStatus(lemburStatus)) {
        return {'success': false, 'message': 'Lembur telah dibatalkan', 'code': 'CANCELLED'};
      }

      final currentAbsensi = data['absensi_status'] as String? ?? '';
      if (currentAbsensi == 'selesai' || currentAbsensi == 'check_out') {
        return {'success': false, 'message': 'Anda sudah check-out', 'code': 'ALREADY_CHECKOUT'};
      }
      if (currentAbsensi != 'check_in' && currentAbsensi != 'sudah_absen') {
        return {'success': false, 'message': 'Anda belum check-in. Lakukan check-in terlebih dahulu.', 'code': 'NOT_CHECKED_IN'};
      }

      if (!_hasAccess(data, userId)) {
        return {'success': false, 'message': 'Tidak memiliki akses', 'code': 'ACCESS_DENIED'};
      }

      final now = DateTime.now();
      final tanggal = _parseTimestamp(data['tanggal']);
      final jamMulai = data['jam_mulai'] as String? ?? '00:00';
      final jamSelesai = data['jam_selesai'] as String? ?? '00:00';
      
      final mulaiTime = _parseJam(tanggal, jamMulai);
      var selesaiTime = _parseJam(tanggal, jamSelesai);
      if (selesaiTime.isBefore(mulaiTime)) selesaiTime = selesaiTime.add(const Duration(days: 1));
      
      final checkOutStart = _hitungCheckOutStart(selesaiTime);
      final checkOutEnd = _hitungCheckOutEnd(selesaiTime);
      
      if (now.isBefore(checkOutStart)) {
        final diff = checkOutStart.difference(now);
        return {'success': false, 'message': '⏰ Check-out tersedia dalam ${diff.inHours}j ${diff.inMinutes.remainder(60)}m (${DateFormat('HH:mm').format(checkOutStart)} WIB)', 'code': 'TOO_EARLY_CHECKOUT', 'availableAt': checkOutStart.toIso8601String()};
      }
      
      if (now.isAfter(checkOutEnd)) {
        return {'success': false, 'message': '❌ Batas check-out sudah lewat (maks ${DateFormat('HH:mm').format(checkOutEnd)}). Hubungi pengawas.', 'code': 'CHECKOUT_EXPIRED'};
      }

      final checkInWaktu = data['check_in_waktu'] != null ? _parseTimestamp(data['check_in_waktu']) : data['check_in_time'] != null ? _parseTimestamp(data['check_in_time']) : null;
      double totalJamReal = 0;
      if (checkInWaktu != null) totalJamReal = now.difference(checkInWaktu).inMinutes / 60.0;

      final updateData = <String, dynamic>{
        'absensi_status': 'selesai', 'check_out_waktu': FieldValue.serverTimestamp(),
        'check_out_time': FieldValue.serverTimestamp(), 'check_out_foto_url': fotoUrl,
        'status': 'selesai', 'completed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(), 'updated_by': userId,
      };
      if (totalJamReal > 0) updateData['total_jam_real'] = totalJamReal;
      if (latitude != null) updateData['check_out_latitude'] = latitude;
      if (longitude != null) updateData['check_out_longitude'] = longitude;
      if (address != null) updateData['check_out_address'] = address;

      try {
        await ref.update(updateData);
      } catch (e) {
        logger.w('⚠️ update failed: $e - Trying setData with merge...');
        await ref.set(updateData, SetOptions(merge: true));
      }

      await _firestore.collection(_cAbsensi).add({
        'lembur_id': docId, 'user_id': userId, 'user_name': userName,
        'foto_url': fotoUrl, 'absensi_status': 'check_out', 'jenis': 'check_out',
        'waktu': FieldValue.serverTimestamp(), 'created_at': FieldValue.serverTimestamp(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (address != null) 'address': address,
      });

      await _log('submit_check_out', docId, userId, 'Check-out berhasil | Total: ${totalJamReal.toStringAsFixed(1)} jam');

      return {
        'success': true, 'message': '✅ Check-out berhasil! Lembur selesai. 🎉',
        'absensiStatus': 'selesai', 'totalJamReal': totalJamReal,
        'checkOutTime': now.toIso8601String(),
      };
    } catch (e) {
      logger.e('❌ submitCheckOut error: $e');
      
      // 🔥 Cek network error
      if (e.toString().contains('SocketException') || e.toString().contains('network')) {
        return {'success': false, 'message': 'Koneksi internet terputus. Silakan coba lagi.', 'code': 'NETWORK_ERROR'};
      }
      
      return {'success': false, 'message': 'Gagal: ${e.toString()}', 'code': 'SYSTEM_ERROR'};
    }
  }

  // ==========================================================================
  // 3. KONFIRMASI KETERLAMBATAN - 🔥 DENGAN NETWORK CHECK
  // ==========================================================================

  Future<Map<String, dynamic>> konfirmasiKeterlambatan({
    required String lemburId, required String userId, required String userName,
    required bool melakukanLembur, required String alasan, String? buktiFotoUrl,
  }) async {
    // 🔥 CEK KONEKSI
    if (!_checkConnection('konfirmasiKeterlambatan')) {
      return {
        'success': false,
        'message': 'Tidak ada koneksi internet. Tidak dapat mengirim konfirmasi.',
        'code': 'NO_CONNECTION'
      };
    }

    try {
      if (lemburId.isEmpty) return {'success': false, 'message': 'ID tidak valid', 'code': 'INVALID_ID'};
      
      final alasanBersih = alasan.trim();
      if (alasanBersih.isEmpty) return {'success': false, 'message': 'Alasan wajib diisi', 'code': 'EMPTY_ALASAN'};
      if (alasanBersih.length < 10) return {'success': false, 'message': 'Alasan minimal 10 karakter (sekarang ${alasanBersih.length})', 'code': 'ALASAN_TOO_SHORT'};
      if (alasanBersih.length > 500) return {'success': false, 'message': 'Alasan maksimal 500 karakter', 'code': 'ALASAN_TOO_LONG'};
      if (melakukanLembur && (buktiFotoUrl == null || buktiFotoUrl.isEmpty)) {
        return {'success': false, 'message': 'Foto bukti wajib diupload jika tetap lembur', 'code': 'BUKTI_REQUIRED'};
      }

      final doc = await _findDoc(lemburId);
      if (doc == null) return {'success': false, 'message': 'Data lembur tidak ditemukan atau telah dibatalkan', 'code': 'NOT_FOUND'};

      final data = doc.data()!;
      final ref = doc.reference;

      final lemburStatus = (data['status'] as String? ?? '').toLowerCase();
      if (_isCancelledStatus(lemburStatus)) {
        return {'success': false, 'message': 'Lembur telah dibatalkan', 'code': 'CANCELLED'};
      }

      final currentAbsensi = data['absensi_status'] as String? ?? 'belum_absen';
      if (_resolvedStatuses.contains(currentAbsensi)) {
        return {'success': false, 'message': 'Absensi sudah diproses (${_getStatusLabel(currentAbsensi)})', 'code': 'ALREADY_RESOLVED', 'currentStatus': currentAbsensi};
      }

      if (data['konfirmasi_keterlambatan'] != null || data['absensi_keterlambatan'] != null) {
        return {'success': false, 'message': 'Konfirmasi keterlambatan sudah pernah dilakukan', 'code': 'ALREADY_CONFIRMED'};
      }

      if (!_hasAccess(data, userId)) {
        return {'success': false, 'message': 'Anda tidak memiliki akses', 'code': 'ACCESS_DENIED'};
      }

      final now = DateTime.now();
      final tanggal = _parseTimestamp(data['tanggal']);
      final jamMulai = data['jam_mulai'] as String? ?? '00:00';
      final jamSelesai = data['jam_selesai'] as String? ?? '00:00';
      
      final mulaiTime = _parseJam(tanggal, jamMulai);
      var selesaiTime = _parseJam(tanggal, jamSelesai);
      if (selesaiTime.isBefore(mulaiTime)) selesaiTime = selesaiTime.add(const Duration(days: 1));
      
      final batasNormal = _hitungBatasNormal(selesaiTime);
      final batasExpired = _hitungBatasExpired(selesaiTime);
      
      if (now.isBefore(batasNormal)) {
        return {'success': false, 'message': 'Anda masih dalam masa absensi normal. Silakan absen normal.', 'code': 'STILL_IN_RANGE'};
      }
      
      if (now.isAfter(batasExpired)) {
        return {'success': false, 'message': '❌ Batas konfirmasi sudah lewat (${DateFormat('dd MMM HH:mm').format(batasExpired)}). Lembur dianggap tidak dilaksanakan.', 'code': 'CONFIRMATION_EXPIRED'};
      }

      final newAbsensiStatus = melakukanLembur ? 'selesai_terlambat' : 'tidak_lembur';

      final updateData = <String, dynamic>{
        'absensi_status': newAbsensiStatus, 'absensi_waktu': FieldValue.serverTimestamp(),
        'absensi_oleh': userId, 'absensi_nama': userName,
        'absensi_keterlambatan': {
          'melakukan_lembur': melakukanLembur, 'alasan': alasanBersih,
          'bukti_foto_url': buktiFotoUrl, 'dikonfirmasi_pada': FieldValue.serverTimestamp(),
          'dikonfirmasi_oleh': userId, 'dikonfirmasi_nama': userName,
        },
        'konfirmasi_keterlambatan': {
          'melakukanLembur': melakukanLembur, 'alasan': alasanBersih,
          'buktiFotoUrl': buktiFotoUrl, 'waktuKonfirmasi': FieldValue.serverTimestamp(),
          'userId': userId, 'userName': userName,
        },
        'status': melakukanLembur ? 'selesai' : 'ditolak',
        'is_terlambat': true,
        'keterlambatan_status': melakukanLembur ? 'dikonfirmasi_lembur' : 'dikonfirmasi_tidak_lembur',
        'updated_at': FieldValue.serverTimestamp(), 'updated_by': userId,
      };

      if (melakukanLembur) {
        updateData['check_in_waktu'] = FieldValue.serverTimestamp();
        updateData['check_in_time'] = FieldValue.serverTimestamp();
        updateData['completed_at'] = FieldValue.serverTimestamp();
      }
      if (buktiFotoUrl != null && buktiFotoUrl.isNotEmpty) {
        updateData['absensi_foto_url'] = buktiFotoUrl;
        updateData['check_in_foto_url'] = buktiFotoUrl;
      }

      try {
        await ref.update(updateData);
      } catch (e) {
        logger.w('⚠️ update failed: $e - Trying setData with merge...');
        await ref.set(updateData, SetOptions(merge: true));
      }

      final alasanLog = alasanBersih.length > 50 ? '${alasanBersih.substring(0, 50)}...' : alasanBersih;
      await _log('konfirmasi_keterlambatan', lemburId, userId, melakukanLembur ? 'Tetap Lembur | Alasan: $alasanLog' : 'Tidak Lembur | Alasan: $alasanLog');

      return {
        'success': true,
        'message': melakukanLembur ? '✅ Konfirmasi berhasil! Anda terdaftar lembur.' : '✅ Konfirmasi berhasil! Anda tidak lembur.',
        'absensiStatus': newAbsensiStatus, 'melakukanLembur': melakukanLembur, 'isCheckedIn': melakukanLembur,
      };
    } catch (e) {
      logger.e('❌ konfirmasiKeterlambatan error: $e');
      return {'success': false, 'message': 'Gagal memproses konfirmasi: ${e.toString()}', 'code': 'SYSTEM_ERROR'};
    }
  }

  // ==========================================================================
  // 4. CEK STATUS KETERLAMBATAN
  // ==========================================================================

  Future<Map<String, dynamic>> cekStatusKeterlambatan(String lemburId) async {
    try {
      if (lemburId.isEmpty) {
        return {'isLate': false, 'canConfirm': false, 'isInRange': false, 'isAlreadyResolved': false, 'isExpired': false, 'isTooEarly': false, 'message': 'ID tidak valid'};
      }

      final doc = await _findDoc(lemburId);
      if (doc == null) {
        return {'isLate': false, 'canConfirm': false, 'isInRange': false, 'isAlreadyResolved': false, 'isExpired': false, 'isTooEarly': false, 'isCancelled': true, 'message': 'Data lembur tidak ditemukan atau telah dibatalkan'};
      }

      final data = doc.data()!;
      
      final lemburStatus = (data['status'] as String? ?? '').toLowerCase();
      if (_isCancelledStatus(lemburStatus)) {
        return {'isLate': false, 'canConfirm': false, 'isInRange': false, 'isAlreadyResolved': true, 'isExpired': false, 'isTooEarly': false, 'isCancelled': true, 'message': 'Lembur telah dibatalkan'};
      }

      final absensiStatus = data['absensi_status'] as String? ?? 'belum_absen';

      if (_resolvedStatuses.contains(absensiStatus)) {
        return {'isLate': false, 'canConfirm': false, 'isInRange': false, 'isAlreadyResolved': true, 'isExpired': absensiStatus == 'expired', 'isTooEarly': false, 'currentStatus': absensiStatus, 'statusLabel': _getStatusLabel(absensiStatus), 'message': absensiStatus == 'tidak_lembur' ? 'Anda sudah konfirmasi tidak lembur' : absensiStatus == 'expired' ? 'Batas absensi sudah kadaluarsa' : 'Absensi sudah diproses'};
      }

      if (data['konfirmasi_keterlambatan'] != null || data['absensi_keterlambatan'] != null) {
        final konfirmasi = (data['konfirmasi_keterlambatan'] ?? data['absensi_keterlambatan']) as Map<String, dynamic>;
        final melakukanLembur = konfirmasi['melakukanLembur'] ?? konfirmasi['melakukan_lembur'] ?? false;
        return {'isLate': false, 'canConfirm': false, 'isInRange': false, 'isAlreadyResolved': true, 'isExpired': false, 'isTooEarly': false, 'currentStatus': melakukanLembur == true ? 'check_in' : 'tidak_lembur', 'statusLabel': melakukanLembur == true ? 'Check In (Terlambat)' : 'Tidak Lembur', 'message': melakukanLembur == true ? 'Konfirmasi lembur sudah diproses. Anda sudah check-in.' : 'Konfirmasi tidak lembur sudah dicatat.'};
      }

      final now = DateTime.now();
      final tanggal = _parseTimestamp(data['tanggal']);
      final jamMulai = data['jam_mulai'] as String? ?? '00:00';
      final jamSelesai = data['jam_selesai'] as String? ?? '00:00';
      
      final mulaiTime = _parseJam(tanggal, jamMulai);
      var selesaiTime = _parseJam(tanggal, jamSelesai);
      if (selesaiTime.isBefore(mulaiTime)) selesaiTime = selesaiTime.add(const Duration(days: 1));

      final earliestCheckIn = _hitungEarliestCheckIn(mulaiTime);
      final batasNormal = _hitungBatasNormal(selesaiTime);
      final batasExpired = _hitungBatasExpired(selesaiTime);

      final isTooEarly = now.isBefore(earliestCheckIn);
      final isInRange = !isTooEarly && now.isBefore(batasNormal);
      final isLate = now.isAfter(batasNormal) && now.isBefore(batasExpired);
      final isExpired = now.isAfter(batasExpired);
      final canConfirm = isLate && !isExpired;

      String message;
      if (isTooEarly) {
        final diff = earliestCheckIn.difference(now);
        message = '⏰ Check-in dibuka dalam ${diff.inHours}j ${diff.inMinutes.remainder(60)}m (${DateFormat('HH:mm').format(earliestCheckIn)} WIB)';
      } else if (isInRange) {
        message = '✅ Masih dalam masa absensi normal (sampai ${DateFormat('HH:mm').format(batasNormal)} WIB)';
      } else if (isExpired) {
        message = '❌ Batas absensi sudah kadaluarsa (${DateFormat('dd MMM HH:mm').format(batasExpired)})';
      } else {
        message = '⚠️ Anda terlambat! Silakan konfirmasi sebelum ${DateFormat('dd MMM HH:mm').format(batasExpired)}.';
      }

      return {
        'isLate': isLate, 'isInRange': isInRange, 'isTooEarly': isTooEarly,
        'isExpired': isExpired, 'canConfirm': canConfirm, 'isAlreadyResolved': false,
        'isCancelled': false, 'earliestCheckIn': DateFormat('HH:mm').format(earliestCheckIn),
        'batasNormal': DateFormat('HH:mm', 'id_ID').format(batasNormal),
        'batasExpired': DateFormat('dd MMM HH:mm', 'id_ID').format(batasExpired),
        'jamMulai': jamMulai, 'jamSelesai': jamSelesai, 'message': message,
        'keterlambatanMenit': isLate ? now.difference(batasNormal).inMinutes : 0,
        'gracePeriodHari': 3,
      };
    } catch (e) {
      logger.e('❌ cekStatusKeterlambatan error: $e');
      return {'isLate': false, 'canConfirm': false, 'isInRange': false, 'isAlreadyResolved': false, 'isExpired': false, 'isTooEarly': false, 'message': 'Gagal cek status: ${e.toString()}'};
    }
  }

  // ==========================================================================
  // 5. GET TODAY OVERTIME FOR ABSENSI - 🔥 DENGAN NETWORK CHECK
  // ==========================================================================

  Future<OvertimeHistory?> getTodayOvertimeForAbsensi(String userId) async {
    if (!_checkConnection('getTodayOvertimeForAbsensi')) return null;

    try {
      final now = DateTime.now();
      final threeDaysAgo = DateTime(now.year, now.month, now.day - 3);
      final endOfToday = DateTime(now.year, now.month, now.day + 1);
      
      logger.i('🔍 getTodayOvertimeForAbsensi: Mencari lembur dari ${DateFormat('dd/MM').format(threeDaysAgo)} sampai ${DateFormat('dd/MM').format(endOfToday)}');

      final mitraSnapshot = await _firestore
          .collection(_cLembur)
          .where('mitra_id', isEqualTo: userId)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(threeDaysAgo))
          .where('tanggal', isLessThan: Timestamp.fromDate(endOfToday))
          .where('status', whereIn: _validAbsensiStatuses)
          .orderBy('tanggal', descending: true)
          .limit(10)
          .get();

      logger.i('🔍 mitraSnapshot: ${mitraSnapshot.docs.length} docs');

      OvertimeHistory? result = _filterValidOvertime(mitraSnapshot.docs, now);
      if (result != null) return result;

      final multiSnapshot = await _firestore
          .collection(_cLembur)
          .where('mitra_ids', arrayContains: userId)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(threeDaysAgo))
          .where('tanggal', isLessThan: Timestamp.fromDate(endOfToday))
          .where('status', whereIn: _validAbsensiStatuses)
          .orderBy('tanggal', descending: true)
          .limit(10)
          .get();

      logger.i('🔍 multiSnapshot: ${multiSnapshot.docs.length} docs');

      result = _filterValidOvertime(multiSnapshot.docs, now);
      if (result != null) return result;

      return null;
    } catch (e) {
      logger.e('❌ getTodayOvertimeForAbsensi ERROR: $e');
      return null;
    }
  }

  OvertimeHistory? _filterValidOvertime(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, DateTime now) {
    if (docs.isEmpty) {
      logger.i('🔍 _filterValidOvertime: docs empty');
      return null;
    }

    logger.i('🔍 _filterValidOvertime: processing ${docs.length} docs');

    final prioritasStatus = ['belum_absen', 'check_in', 'sudah_absen'];
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sortedDocs = [];
    
    for (final status in prioritasStatus) {
      for (final doc in docs) {
        final data = doc.data();
        final docStatus = data['status'] as String? ?? '';
        final isCancelled = data['is_cancelled'] == true;
        if (_excludedStatuses.contains(docStatus) || isCancelled) continue;
        final absensiDocStatus = data['absensi_status'];
        if (absensiDocStatus == status && !sortedDocs.contains(doc)) sortedDocs.add(doc);
      }
    }
    
    for (final doc in docs) {
      if (!sortedDocs.contains(doc)) {
        final data = doc.data();
        final docStatus = data['status'] as String? ?? '';
        final isCancelled = data['is_cancelled'] == true;
        if (!_excludedStatuses.contains(docStatus) && !isCancelled) {
          final absensiDocStatus = data['absensi_status'];
          if (absensiDocStatus == null || (absensiDocStatus is String && absensiDocStatus.isEmpty)) sortedDocs.add(doc);
        }
      }
    }
    
    for (final doc in docs) {
      if (!sortedDocs.contains(doc)) {
        final data = doc.data();
        final docStatus = data['status'] as String? ?? '';
        final isCancelled = data['is_cancelled'] == true;
        if (!_excludedStatuses.contains(docStatus) && !isCancelled) sortedDocs.add(doc);
      }
    }

    logger.i('🔍 _filterValidOvertime: sortedDocs count = ${sortedDocs.length}');

    OvertimeHistory? upcomingOvertime;

    for (final doc in sortedDocs) {
      final data = doc.data();
      final docStatus = data['status'] as String? ?? '';
      final isCancelled = data['is_cancelled'] == true;
      if (_excludedStatuses.contains(docStatus) || isCancelled) continue;
      
      final absensiStatus = data['absensi_status'] as String? ?? 'belum_absen';
      
      logger.i('🔍 _filterValidOvertime: doc=${doc.id}, absensiStatus=$absensiStatus');
      
      if (_resolvedStatuses.contains(absensiStatus) && absensiStatus != 'check_in' && absensiStatus != 'sudah_absen') continue;

      final tanggal = _parseTimestamp(data['tanggal']);
      final jamMulai = data['jam_mulai'] as String? ?? '00:00';
      final jamSelesai = data['jam_selesai'] as String? ?? '00:00';
      
      final mulaiTime = _parseJam(tanggal, jamMulai);
      var selesaiTime = _parseJam(tanggal, jamSelesai);
      if (selesaiTime.isBefore(mulaiTime)) selesaiTime = selesaiTime.add(const Duration(days: 1));
      
      final earliestCheckIn = _hitungEarliestCheckIn(mulaiTime);
      final batasNormal = _hitungBatasNormal(selesaiTime);
      final batasExpired = _hitungBatasExpired(selesaiTime);
      if (now.isAfter(batasExpired)) continue;

      final isLate = now.isAfter(batasNormal) && now.isBefore(batasExpired);
      final isTruePending = _isTruePending(absensiStatus);
      
      if (isLate && isTruePending) return OvertimeHistory.fromFirestore(doc);
      if (now.isAfter(earliestCheckIn) && now.isBefore(batasNormal) && isTruePending) return OvertimeHistory.fromFirestore(doc);
      if (now.isBefore(earliestCheckIn) && !['check_in', 'sudah_absen'].contains(absensiStatus)) {
        upcomingOvertime ??= OvertimeHistory.fromFirestore(doc);
        continue;
      }
      
      logger.i('🔍 _filterValidOvertime: RETURNING doc=${doc.id}');
      return OvertimeHistory.fromFirestore(doc);
    }
    return upcomingOvertime;
  }

  // ==========================================================================
  // 6. TENGGAT INFO
  // ==========================================================================

  Future<TenggatInfo?> getTenggatInfo(String lemburId) async {
    try {
      final doc = await _findDoc(lemburId);
      if (doc == null) return null;

      final data = doc.data()!;
      final absensiStatus = data['absensi_status'] as String? ?? 'belum_absen';
      final tanggal = _parseTimestamp(data['tanggal']);
      final jamMulai = data['jam_mulai'] as String? ?? '00:00';
      final jamSelesai = data['jam_selesai'] as String? ?? '00:00';

      final mulaiTime = _parseJam(tanggal, jamMulai);
      var selesaiTime = _parseJam(tanggal, jamSelesai);
      if (selesaiTime.isBefore(mulaiTime)) selesaiTime = selesaiTime.add(const Duration(days: 1));

      final batasNormal = _hitungBatasNormal(selesaiTime);
      final batasExpired = _hitungBatasExpired(selesaiTime);

      if (_resolvedStatuses.contains(absensiStatus)) {
        return TenggatInfo(
          label: _getStatusLabel(absensiStatus), labelSingkat: _getStatusLabel(absensiStatus).toUpperCase(),
          status: absensiStatus, sisaWaktu: Duration.zero,
          batasMulai: mulaiTime, batasNormal: batasNormal, batasExpired: batasExpired,
          isNormal: false, isLate: false, isExpired: absensiStatus == 'expired',
          canConfirm: false, canAbsenNormal: false, progressPercent: 1.0,
          jamMulai: jamMulai, jamSelesai: jamSelesai,
          tanggalLembur: DateFormat('dd MMM yyyy', 'id_ID').format(tanggal),
        );
      }

      final now = DateTime.now();
      final isExpired = now.isAfter(batasExpired);
      final isLate = !isExpired && now.isAfter(batasNormal);
      final isNormal = !isLate && !isExpired;

      final sisaWaktu = isExpired ? Duration.zero : isNormal ? batasNormal.difference(now) : batasExpired.difference(now);
      final totalWindow = batasExpired.difference(selesaiTime);
      final elapsed = now.difference(selesaiTime);
      final progressPercent = totalWindow.inMilliseconds > 0 ? (elapsed.inMilliseconds / totalWindow.inMilliseconds).clamp(0.0, 1.0) : 0.0;

      return TenggatInfo(
        label: isExpired ? 'Kadaluarsa' : isNormal ? 'Absen sampai ${DateFormat('HH:mm').format(batasNormal)}' : 'Konfirmasi sebelum ${DateFormat('dd MMM HH:mm').format(batasExpired)}',
        labelSingkat: isExpired ? 'EXPIRED' : isLate ? 'TERLAMBAT' : 'NORMAL',
        status: absensiStatus, sisaWaktu: sisaWaktu,
        batasMulai: mulaiTime, batasNormal: batasNormal, batasExpired: batasExpired,
        isNormal: isNormal, isLate: isLate, isExpired: isExpired,
        canConfirm: isLate && !isExpired, canAbsenNormal: isNormal,
        progressPercent: progressPercent, jamMulai: jamMulai, jamSelesai: jamSelesai,
        tanggalLembur: DateFormat('dd MMM yyyy', 'id_ID').format(tanggal),
      );
    } catch (e) {
      logger.e('❌ getTenggatInfo error: $e');
      return null;
    }
  }

  // ==========================================================================
  // 7. GET LEMBUR NEED ABSENSI - 🔥 DENGAN NETWORK CHECK
  // ==========================================================================

  Future<List<OvertimeHistory>> getLemburNeedAbsensi({
    required String userId, String userRole = 'mitra', String? bulan,
  }) async {
    if (!_checkConnection('getLemburNeedAbsensi')) return [];

    try {
      final now = DateTime.now();
      
      var queryLembur = _firestore
          .collection(_cLembur)
          .where('status', isEqualTo: 'disetujui')
          .where('absensi_status', whereIn: _pendingStatusesForQuery);
      if (userRole == 'mitra') queryLembur = queryLembur.where('mitra_id', isEqualTo: userId);
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') queryLembur = queryLembur.where('tahun_bulan', isEqualTo: bulan);
      final snapshotLembur = await queryLembur.orderBy('tanggal', descending: true).get();
      
      var queryMulti = _firestore
          .collection(_cLembur)
          .where('status', isEqualTo: 'disetujui')
          .where('absensi_status', whereIn: _pendingStatusesForQuery);
      if (userRole == 'mitra') queryMulti = queryMulti.where('mitra_ids', arrayContains: userId);
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') queryMulti = queryMulti.where('tahun_bulan', isEqualTo: bulan);
      final snapshotMulti = await queryMulti.orderBy('tanggal', descending: true).get();
      
      final allDocs = [...snapshotLembur.docs, ...snapshotMulti.docs];
      
      return allDocs
          .map((d) => OvertimeHistory.fromFirestore(d))
          .where((item) {
            if (item.isCancelled) return false;
            final tanggal = item.tanggal;
            final selesaiTime = _parseJam(tanggal, item.jamSelesai);
            final mulaiTime = _parseJam(tanggal, item.jamMulai);
            var adjustedSelesai = selesaiTime;
            if (adjustedSelesai.isBefore(mulaiTime)) adjustedSelesai = adjustedSelesai.add(const Duration(days: 1));
            final batasNormal = _hitungBatasNormal(adjustedSelesai);
            final batasExpired = _hitungBatasExpired(adjustedSelesai);

            // 🔥 FIX: jangan masukkan lembur yang BELUM MULAI / BELUM TERLAMBAT
            // ke daftar "lembur terlambat" — kecuali user sudah check-in
            // (perlu tetap tampil supaya bisa lanjut proses check-out).
            final sudahCheckIn = item.absensiStatus == 'check_in' ||
                item.absensiStatus == 'sudah_absen';

            return now.isBefore(batasExpired) &&
                (sudahCheckIn || now.isAfter(batasNormal));
          })
          .toList();
    } catch (e) {
      logger.e('❌ getLemburNeedAbsensi error: $e');
      return [];
    }
  }

  // ==========================================================================
  // 8. GET ABSENSI STATS - 🔥 DENGAN NETWORK CHECK
  // ==========================================================================

  Future<Map<String, dynamic>> getAbsensiStats({required String userId, String? bulan}) async {
    if (!_checkConnection('getAbsensiStats')) {
      return {'total': 0, 'sudahAbsen': 0, 'belumAbsen': 0, 'expired': 0, 'terlambat': 0, 'tidakLembur': 0, 'persentase': 0};
    }

    try {
      var query = _firestore.collection(_cLembur).where('mitra_id', isEqualTo: userId);
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') query = query.where('tahun_bulan', isEqualTo: bulan);
      final docs = await query.get();
      int total = 0, sudah = 0, belum = 0, exp = 0, terlambat = 0, tidakLembur = 0;
      for (var d in docs.docs) {
        final s = d.data()['status'] as String? ?? '';
        if (_excludedStatuses.contains(s)) continue;
        if (_validAbsensiStatuses.contains(s)) {
          total++;
          final a = d.data()['absensi_status'] as String? ?? '';
          if (['selesai', 'check_in', 'sudah_absen'].contains(a)) { sudah++; }
          else if (a == 'selesai_terlambat') { sudah++; terlambat++; }
          else if (a == 'tidak_lembur') { tidakLembur++; }
          else if (a == 'expired') { exp++; }
          else { belum++; }
        }
      }
      return {'total': total, 'sudahAbsen': sudah, 'belumAbsen': belum, 'expired': exp, 'terlambat': terlambat, 'tidakLembur': tidakLembur, 'persentase': total > 0 ? (sudah / total * 100) : 0};
    } catch (e) {
      return {'total': 0, 'sudahAbsen': 0, 'belumAbsen': 0, 'expired': 0, 'terlambat': 0, 'tidakLembur': 0, 'persentase': 0};
    }
  }

  // ==========================================================================
  // 9. GET EXPIRY SUMMARY - 🔥 DENGAN NETWORK CHECK
  // ==========================================================================

  Future<Map<String, dynamic>> getExpirySummary({required String userId, String? bulan}) async {
    if (!_checkConnection('getExpirySummary')) {
      return {'totalPending': 0, 'akanExpired': 0, 'kritis': 0, 'warning': 0, 'perhatian': 0, 'aman': 0, 'sudahLewatNormal': 0};
    }

    try {
      final now = DateTime.now();
      var query = _firestore.collection(_cLembur).where('mitra_id', isEqualTo: userId).where('absensi_status', whereIn: _pendingStatusesForQuery);
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') query = query.where('tahun_bulan', isEqualTo: bulan);
      final docs = await query.get();
      int akanExpired = 0, kritis = 0, warning = 0, perhatian = 0, aman = 0, sudahLewatNormal = 0, totalPending = 0;
      for (var d in docs.docs) {
        final data = d.data();
        final status = data['status'] as String? ?? '';
        if (_excludedStatuses.contains(status)) continue;
        if (!_validAbsensiStatuses.contains(status)) continue;
        totalPending++;
        final tanggal = _parseTimestamp(data['tanggal']);
        final jamSelesai = data['jam_selesai'] as String? ?? '00:00';
        final jamMulai = data['jam_mulai'] as String? ?? '00:00';
        final mulaiTime = _parseJam(tanggal, jamMulai);
        var selesaiTime = _parseJam(tanggal, jamSelesai);
        if (selesaiTime.isBefore(mulaiTime)) selesaiTime = selesaiTime.add(const Duration(days: 1));
        final batasNormal = _hitungBatasNormal(selesaiTime);
        final batasExpired = _hitungBatasExpired(selesaiTime);
        if (now.isAfter(batasExpired)) { sudahLewatNormal++; }
        else if (now.isAfter(batasNormal)) {
          final sisa = batasExpired.difference(now);
          if (sisa.inHours < 1) akanExpired++; else if (sisa.inHours < 2) kritis++; else if (sisa.inHours < 6) warning++; else perhatian++;
        } else { aman++; }
      }
      return {'totalPending': totalPending, 'akanExpired': akanExpired, 'kritis': kritis, 'warning': warning, 'perhatian': perhatian, 'aman': aman, 'sudahLewatNormal': sudahLewatNormal};
    } catch (e) {
      return {'totalPending': 0, 'akanExpired': 0, 'kritis': 0, 'warning': 0, 'perhatian': 0, 'aman': 0, 'sudahLewatNormal': 0};
    }
  }

  // ==========================================================================
  // 10. IS ALREADY ABSEN
  // ==========================================================================

  Future<bool> isAlreadyAbsen({required String mitraId, required DateTime tanggal}) async {
    try {
      final start = DateTime(tanggal.year, tanggal.month, tanggal.day);
      final end = start.add(const Duration(days: 1));
      final snap = await _firestore.collection(_cAbsensi).where('user_id', isEqualTo: mitraId).where('waktu', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).where('waktu', isLessThan: Timestamp.fromDate(end)).limit(1).get();
      return snap.docs.isNotEmpty;
    } catch (_) { return false; }
  }

  // ==========================================================================
  // 11. AUTO UPDATE EXPIRED - 🔥 DENGAN NETWORK CHECK
  // ==========================================================================

  Future<Map<String, dynamic>> autoUpdateExpired({String? userId}) async {
    if (!_checkConnection('autoUpdateExpired')) {
      return {'success': false, 'expiredCount': 0, 'message': 'Offline - tidak dapat update'};
    }

    try {
      final now = DateTime.now();
      var queryLembur = _firestore.collection(_cLembur).where('absensi_status', whereIn: ['belum_absen']);
      if (userId != null) queryLembur = queryLembur.where('mitra_id', isEqualTo: userId);
      var queryNullLembur = _firestore.collection(_cLembur).where('absensi_status', isNull: true);
      if (userId != null) queryNullLembur = queryNullLembur.where('mitra_id', isEqualTo: userId);
      
      final allDocs = [...(await queryLembur.get()).docs, ...(await queryNullLembur.get()).docs];
      final batch = _firestore.batch();
      int count = 0;
      for (var d in allDocs) {
        final data = d.data();
        final status = data['status'] as String? ?? '';
        if (_excludedStatuses.contains(status)) continue;
        final tanggal = _parseTimestamp(data['tanggal']);
        final jamMulai = data['jam_mulai'] as String? ?? '00:00';
        final jamSelesaiStr = data['jam_selesai'] as String? ?? '00:00';
        final mulaiTime = _parseJam(tanggal, jamMulai);
        var selesaiTime = _parseJam(tanggal, jamSelesaiStr);
        if (selesaiTime.isBefore(mulaiTime)) selesaiTime = selesaiTime.add(const Duration(days: 1));
        if (now.isAfter(_hitungBatasExpired(selesaiTime))) {
          batch.update(d.reference, {
            'absensi_status': 'expired', 'status': 'expired',
            'expired_at': FieldValue.serverTimestamp(), 'updated_at': FieldValue.serverTimestamp(),
            'keterangan_expired': 'Melebihi batas konfirmasi 3 hari. Lembur dianggap tidak dilaksanakan.',
          });
          count++;
        }
      }
      if (count > 0) await batch.commit();
      logger.i('✅ Auto-update expired: $count dokumen');
      return {'success': true, 'expiredCount': count};
    } catch (e) {
      logger.e('❌ autoUpdateExpired error: $e');
      return {'success': false, 'expiredCount': 0};
    }
  }

  // ==========================================================================
  // 12. ✅ BATALKAN PENGAJUAN (PENGAWAS) - 🔥 DENGAN NETWORK CHECK
  // ==========================================================================

  Future<Map<String, dynamic>> batalkanPengajuan({
    required String documentId,
    required String userId,
  }) async {
    if (!_checkConnection('batalkanPengajuan')) {
      return {'success': false, 'message': 'Tidak ada koneksi internet', 'code': 'NO_CONNECTION'};
    }

    try {
      if (documentId.isEmpty) {
        return {'success': false, 'message': 'ID tidak valid', 'code': 'INVALID_ID'};
      }

      final doc = await _findDoc(documentId);
      if (doc == null) {
        return {'success': false, 'message': 'Data tidak ditemukan', 'code': 'NOT_FOUND'};
      }

      final data = doc.data()!;
      final currentStatus = (data['status'] as String? ?? '').toLowerCase();
      
      if (_excludedStatuses.contains(currentStatus)) {
        return {'success': false, 'message': 'Pengajuan sudah dibatalkan', 'code': 'ALREADY_CANCELLED'};
      }

      final updateData = <String, dynamic>{
        'status': 'dibatalkan',
        'status_pengajuan': 'dibatalkan',
        'dibatalkan_oleh': userId,
        'dibatalkan_pada': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': userId,
        'absensi_status': 'dibatalkan',
        'is_cancelled': true,
        'cancelled_at': FieldValue.serverTimestamp(),
        'cancelled_by': userId,
        'keterangan_pembatalan': 'Dibatalkan oleh pengawas',
      };

      await doc.reference.update(updateData);
      await _log('batalkan_pengajuan', documentId, userId, 'Pengajuan dibatalkan oleh pengawas');

      return {
        'success': true,
        'message': '✅ Pengajuan berhasil dibatalkan',
        'newStatus': 'dibatalkan',
      };
    } catch (e) {
      logger.e('❌ batalkanPengajuan error: $e');
      return {'success': false, 'message': 'Gagal: ${e.toString()}', 'code': 'SYSTEM_ERROR'};
    }
  }

  // ==========================================================================
  // 13. ✅ HSSE - STREAM PENGAJUAN BERISIKO
  // ==========================================================================

  Stream<List<OvertimeHistory>> getHSSERiskyOvertimeStream({
    String? bulan,
    String? statusFilter,
    String? hsseStatus,
    String? hsseUserId,
  }) {
    var query = _firestore
        .collection(_cLembur)
        .where('is_risky', isEqualTo: true);
    
    if (bulan != null && bulan.isNotEmpty) {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter != 'semua') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    if (hsseStatus != null && hsseStatus.isNotEmpty) {
      query = query.where('hsse_status', isEqualTo: hsseStatus);
    }
    
    return query
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OvertimeHistory.fromFirestore(d))
            .where((item) => !_excludedStatuses.contains(item.statusPengajuan ?? ''))
            .toList());
  }

  // ==========================================================================
  // 14. ✅ HSSE - STREAM RIWAYAT PERSETUJUAN
  // ==========================================================================

  Stream<List<OvertimeHistory>> getHSSEApprovalHistoryStream({
    required String hsseUserId,
    String? bulan,
    String? hsseStatus,
  }) {
    var query = _firestore
        .collection(_cLembur)
        .where('is_risky', isEqualTo: true)
        .where('hsse_reviewed_by', isEqualTo: hsseUserId);
    
    if (bulan != null && bulan.isNotEmpty) {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (hsseStatus != null && hsseStatus != 'semua') {
      query = query.where('hsse_status', isEqualTo: hsseStatus);
    }
    
    return query
        .orderBy('hsse_reviewed_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OvertimeHistory.fromFirestore(d))
            .toList());
  }

  // ==========================================================================
  // 15. ✅ HSSE - STREAM DISETUJUI OLEH SAYA
  // ==========================================================================

  Stream<List<OvertimeHistory>> getHSSEApprovedByMeStream({
    required String hsseUserId,
    String? bulan,
    String? statusFilter,
  }) {
    var query = _firestore
        .collection(_cLembur)
        .where('is_risky', isEqualTo: true)
        .where('hsse_reviewed_by', isEqualTo: hsseUserId);
    
    if (bulan != null && bulan.isNotEmpty) {
      query = query.where('tahun_bulan', isEqualTo: bulan);
    }
    if (statusFilter != null && statusFilter != 'semua') {
      query = query.where('hsse_status', isEqualTo: statusFilter);
    }
    
    return query
        .orderBy('hsse_reviewed_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OvertimeHistory.fromFirestore(d))
            .toList());
  }

  // ==========================================================================
  // 16. ✅ AUTO-STOP CHECK - APAKAH LEMBUR SUDAH EXPIRED
  // ==========================================================================

  Future<bool> isOvertimeExpired(String lemburId) async {
    try {
      final doc = await _findDoc(lemburId);
      if (doc == null) return true;
      
      final data = doc.data()!;
      final now = DateTime.now();
      final tanggal = _parseTimestamp(data['tanggal']);
      final jamSelesai = data['jam_selesai'] as String? ?? '00:00';
      final jamMulai = data['jam_mulai'] as String? ?? '00:00';
      
      final mulaiTime = _parseJam(tanggal, jamMulai);
      var selesaiTime = _parseJam(tanggal, jamSelesai);
      if (selesaiTime.isBefore(mulaiTime)) selesaiTime = selesaiTime.add(const Duration(days: 1));
      
      final checkOutEnd = _hitungCheckOutEnd(selesaiTime);
      return now.isAfter(checkOutEnd);
    } catch (e) {
      logger.e('❌ isOvertimeExpired error: $e');
      return true;
    }
  }
}