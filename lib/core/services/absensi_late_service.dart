// lib/core/services/absensi_late_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '/core/services/overtime_absensi_service.dart';
import 'absensi_state_service.dart';

class AbsensiLateService {
  final OvertimeAbsensiService _absensiService;
  final AbsensiStateService _stateService;
  final FirebaseFirestore _firestore;

  AbsensiLateService({
    required OvertimeAbsensiService absensiService,
    required AbsensiStateService stateService,
    FirebaseFirestore? firestore,
  })  : _absensiService = absensiService,
        _stateService = stateService,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Load daftar lembur terlambat
  Future<List<OvertimeHistory>> loadLateOvertimeList(String userId) async {
    try {
      final now = DateTime.now();
      final allPending = await _absensiService.getLemburNeedAbsensi(
        userId: userId,
        userRole: 'mitra',
      );

      final List<OvertimeHistory> lateList = [];

      for (final item in allPending) {
        // Skip yang dibatalkan
        if (item.isCancelled == true) continue;
        if (item.statusPengajuan == 'dibatalkan' || 
            item.statusPengajuan == 'cancelled' ||
            item.statusPengajuan == 'ditolak') continue;

        // Parse jam
        final partsMulai = item.jamMulai.split(':');
        final partsSelesai = item.jamSelesai.split(':');
        if (partsMulai.length != 2 || partsSelesai.length != 2) continue;

        final tanggal = item.tanggal;
        final jamMulai = DateTime(tanggal.year, tanggal.month, tanggal.day,
            int.parse(partsMulai[0]), int.parse(partsMulai[1]));
        var jamSelesai = DateTime(tanggal.year, tanggal.month, tanggal.day,
            int.parse(partsSelesai[0]), int.parse(partsSelesai[1]));
        if (jamSelesai.isBefore(jamMulai)) {
          jamSelesai = jamSelesai.add(const Duration(days: 1));
        }

        final batasNormal = jamSelesai.add(const Duration(minutes: 30));
        final batasExpired = jamSelesai.add(const Duration(days: 3));

        // Cek status
        final sudahCheckIn = item.absensiStatus == 'check_in' ||
            item.absensiStatus == 'sudah_absen' ||
            item.checkInTime != null;

        bool shouldInclude;
        if (sudahCheckIn) {
          // Sudah check-in: tampilkan SELAMA belum check-out
          final maxExpiry = jamSelesai.add(const Duration(days: 7));
          final masihDalamBatas = now.isBefore(maxExpiry);
          
          shouldInclude = masihDalamBatas &&
              item.absensiStatus != 'selesai' &&
              item.absensiStatus != 'check_out' &&
              item.absensiStatus != 'selesai_terlambat' &&
              item.absensiStatus != 'tidak_lembur' &&
              item.absensiStatus != 'expired';
        } else {
          // Belum check-in: cek batas 3 hari
          final isLate = now.isAfter(batasNormal) && now.isBefore(batasExpired);
          shouldInclude = isLate && !item.isAbsensiResolved;
        }

        if (shouldInclude) {
          lateList.add(item);
        }
      }

      // Sort by tanggal
      lateList.sort((a, b) => a.tanggal.compareTo(b.tanggal));

      return lateList;
    } catch (e) {
      debugPrint('❌ Load late list error: $e');
      return [];
    }
  }

  /// Cek status keterlambatan dari Firestore
  Future<Map<String, dynamic>?> cekStatusKeterlambatan(String lemburId) async {
    try {
      final doc = await _firestore.collection('lembur_mitra').doc(lemburId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final now = DateTime.now();

      // Parse jam
      final jamMulaiStr = data['jam_mulai'] as String? ?? '';
      final jamSelesaiStr = data['jam_selesai'] as String? ?? '';
      final partsMulai = jamMulaiStr.split(':');
      final partsSelesai = jamSelesaiStr.split(':');

      if (partsMulai.length != 2 || partsSelesai.length != 2) {
        return {'isAlreadyResolved': true, 'message': 'Data tidak valid'};
      }

      final tanggal = (data['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now();
      final jamMulai = DateTime(tanggal.year, tanggal.month, tanggal.day,
          int.parse(partsMulai[0]), int.parse(partsMulai[1]));
      var jamSelesai = DateTime(tanggal.year, tanggal.month, tanggal.day,
          int.parse(partsSelesai[0]), int.parse(partsSelesai[1]));
      if (jamSelesai.isBefore(jamMulai)) {
        jamSelesai = jamSelesai.add(const Duration(days: 1));
      }

      final batasNormal = jamSelesai.add(const Duration(minutes: 30));
      final batasExpired = jamSelesai.add(const Duration(days: 3));

      final absensiStatus = data['absensi_status'] as String? ?? '';
      final isAlreadyResolved = absensiStatus == 'selesai' ||
          absensiStatus == 'check_out' ||
          absensiStatus == 'selesai_terlambat' ||
          absensiStatus == 'tidak_lembur' ||
          absensiStatus == 'expired';

      if (isAlreadyResolved) {
        return {
          'isLate': false,
          'canConfirm': false,
          'isAlreadyResolved': true,
          'currentStatus': absensiStatus,
          'message': _getResolvedMessage(absensiStatus),
        };
      }

      // Cek apakah terlambat
      final isLate = now.isAfter(batasNormal) && !isAlreadyResolved;
      final isExpired = now.isAfter(batasExpired);

      if (isExpired) {
        return {
          'isLate': false,
          'canConfirm': false,
          'isAlreadyResolved': true,
          'currentStatus': 'expired',
          'message': 'Waktu konfirmasi sudah kadaluarsa (maks. 3 hari)',
        };
      }

      if (isLate) {
        return {
          'isLate': true,
          'canConfirm': true,
          'isAlreadyResolved': false,
          'currentStatus': 'late',
          'message': 'Anda terlambat! Silakan konfirmasi.',
        };
      }

      return {
        'isLate': false,
        'canConfirm': false,
        'isAlreadyResolved': false,
        'currentStatus': 'normal',
        'message': 'Masih dalam masa absensi normal',
      };

    } catch (e) {
      debugPrint('❌ Cek status error: $e');
      return null;
    }
  }

  /// Submit konfirmasi keterlambatan
  Future<Map<String, dynamic>> submitKonfirmasi({
    required String lemburId,
    required String userId,
    required String userName,
    required bool melakukanLembur,
    required String alasan,
    String? buktiFotoUrl,
  }) async {
    try {
      _stateService.emit((s) => s.copyWith(
        isSubmitting: true,
        statusMessage: 'Mengirim konfirmasi...',
      ));

      // Jika memilih "Tidak Lembur"
      if (!melakukanLembur) {
        await _firestore.collection('lembur_mitra').doc(lemburId).update({
          'absensi_status': 'tidak_lembur',
          'konfirmasi_terlambat': {
            'melakukan_lembur': false,
            'alasan': alasan,
            'waktu_konfirmasi': FieldValue.serverTimestamp(),
            'user_id': userId,
            'user_name': userName,
          },
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Catat pembatalan
        await _firestore.collection('system_logs').add({
          'type': 'lembur_dibatalkan_mitra',
          'lembur_id': lemburId,
          'user_id': userId,
          'alasan': alasan,
          'timestamp': FieldValue.serverTimestamp(),
        });

        return {'success': true, 'message': 'Konfirmasi tidak lembur berhasil dicatat'};
      }

      // Jika memilih "Ya, Lembur"
      if (buktiFotoUrl == null) {
        throw Exception('Foto bukti wajib diupload');
      }

      await _firestore.collection('lembur_mitra').doc(lemburId).update({
        'absensi_status': 'check_in',
        'check_in_time': FieldValue.serverTimestamp(),
        'check_in_foto': buktiFotoUrl,
        'konfirmasi_terlambat': {
          'melakukan_lembur': true,
          'alasan': alasan,
          'bukti_foto': buktiFotoUrl,
          'waktu_konfirmasi': FieldValue.serverTimestamp(),
          'user_id': userId,
          'user_name': userName,
        },
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update audit trail
      await _firestore.collection('users').doc(userId).update({
        'audit_trail': FieldValue.arrayUnion([
          {
            'action': 'konfirmasi_lembur_terlambat',
            'lembur_id': lemburId,
            'timestamp': Timestamp.now(),
            'melakukan_lembur': true,
          }
        ]),
      });

      return {'success': true, 'message': 'Check-in berhasil!'};

    } catch (e) {
      debugPrint('❌ Submit konfirmasi error: $e');
      _stateService.setError('Gagal menyimpan konfirmasi', detail: e.toString());
      rethrow;
    } finally {
      _stateService.emit((s) => s.copyWith(isSubmitting: false));
    }
  }

  /// Validasi form konfirmasi
  String? validateKonfirmasi({
    required bool? melakukanLembur,
    required String alasan,
    String? buktiFotoPath,
  }) {
    if (melakukanLembur == null) {
      return 'Pilih apakah Anda melakukan lembur';
    }
    if (alasan.trim().isEmpty) {
      return 'Alasan wajib diisi';
    }
    if (alasan.trim().length < 3) {
      return 'Alasan minimal 3 karakter';
    }
    if (alasan.trim().length > 500) {
      return 'Alasan maksimal 500 karakter';
    }
    if (melakukanLembur == true && buktiFotoPath == null) {
      return 'Foto bukti wajib diupload jika Anda melakukan lembur';
    }
    return null; // Valid
  }

  String _getResolvedMessage(String status) {
    switch (status) {
      case 'selesai':
      case 'check_out':
        return 'Lembur sudah selesai (check-out)';
      case 'selesai_terlambat':
        return 'Lembur terlambat sudah diselesaikan';
      case 'tidak_lembur':
        return 'Anda sudah konfirmasi tidak melakukan lembur';
      case 'expired':
        return 'Waktu konfirmasi sudah kadaluarsa';
      default:
        return 'Status absensi sudah diproses';
    }
  }
}