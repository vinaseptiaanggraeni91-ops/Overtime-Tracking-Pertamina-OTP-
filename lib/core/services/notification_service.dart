// lib/core/services/notification_service.dart
// 🔥 FINAL VERSION - COMPLETE WITH SOUND CONFIGURATION
// ✅ Semua kode asli TETAP ADA, hanya ditambahkan konfigurasi suara

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'overtime_rate_service.dart';


// ==================== ENUM & CONSTANTS (Top-Level) ====================


/// Channel notifikasi yang didukung
enum NotificationChannel {
  firestore,
  email,
  whatsapp,
  all,
}

/// Tipe notifikasi
const Map<String, String> notificationTypes = {
  'lembur_submitted': 'Pengajuan Lembur Baru',
  'lembur_approved': 'Lembur Disetujui',
  'lembur_rejected': 'Lembur Ditolak',
  'lembur_assignment': 'Penugasan Mitra',
  'spkl_ready': 'SPKL Siap',
  'absensi_reminder': 'Pengingat Absensi',
  'check_in': 'Check In',
  'check_out': 'Check Out',
  'lembur_completed': 'Lembur Selesai',
  'lembur_confirmed': 'Lembur Dikonfirmasi',
  'general': 'Notifikasi Umum',
  'hsse_risk_validation': 'Validasi Risiko HSSE',
  'user_registered': 'Registrasi User Baru',
};

/// Priority level
const Map<int, String> priorityLevels = {
  1: 'critical',
  2: 'high',
  3: 'normal',
  4: 'low',
  5: 'info',
};

/// Default channels (hanya firestore)
const List<NotificationChannel> defaultChannels = [
  NotificationChannel.firestore,
];


// ==================== NOTIFICATION SERVICE ====================


/// Service untuk mengelola notifikasi multi-channel
/// Mendukung: Firestore Notification, Email (mailto), WhatsApp (Fonnte API), Push Notification (FCM via Cloudflare Worker)
class NotificationService {
  // ==================== SINGLETON ====================
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ==================== DEPENDENCIES ====================
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OvertimeRateService _rateService = OvertimeRateService();

  // ==================== KONSTANTA ====================
  static const String collectionNotifications = 'notifications';
  static const String collectionUsers = 'users';
  
  // 🔥 CHANNEL ID UNTUK NOTIFIKASI (DITAMBAHKAN)
  static const String _channelId = 'overtime_notifications_v2';
  static const String _channelName = 'Notifikasi Lembur';
  
  // Fonnte WhatsApp API Config
  static const String _fonnteApiKey = 'Eo4VfZvp2mv9Fg6A3DRE6Uq7ydVrbRs';
  static const String _fonnteApiUrl = 'https://api.fonnte.com/send';
  
  // Base URL aplikasi
  static const String _baseUrl = 'https://otp-pge.web.app';

  // Cloudflare Worker (Push Notification via FCM)
  static const String _pushWorkerUrl =
      'https://pge-overtime-notify.overtime-tracking-pertamina.workers.dev';
  static const String _pushSharedSecret = 'Cbxq25OjimF8oSkPNIaTWr6tuwUBYnvghR9XHVJ7';

  // ==================== 🔥 PRIORITY NOTIFICATION TYPES ====================
  
  /// Tipe notifikasi yang menggunakan suara custom OTP & channel prioritas
  static const List<String> priorityNotificationTypes = [
    'lembur_submitted',
    'lembur_approved',
    'lembur_rejected',
    'lembur_assignment',
    'hsse_risk_validation',
  ];

  /// Cek apakah tipe notifikasi termasuk prioritas (suara OTP)
  static bool isPriorityType(String type) {
    return priorityNotificationTypes.contains(type);
  }

  // ==================== 🔥 GET NOTIFICATIONS STREAM (REAL-TIME) ====================
  
  /// Stream notifikasi real-time untuk user tertentu
  Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
    try {
      return _firestore
          .collection(collectionNotifications)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
                'readAt': (data['readAt'] as Timestamp?)?.toDate(),
              };
            }).toList();
          });
    } catch (e) {
      debugPrint('❌ Error creating notifications stream - $e');
      return Stream.value([]);
    }
  }

  /// Stream notifikasi user (real-time) dengan limit
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId, {int limit = 50}) {
    return _firestore
        .collection(collectionNotifications)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
                'readAt': (data['readAt'] as Timestamp?)?.toDate(),
              };
            }).toList());
  }

  /// Get notifikasi (Future, one-time fetch)
  Future<List<Map<String, dynamic>>> getNotificationsOnce(String userId, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection(collectionNotifications)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
          'readAt': (data['readAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getNotificationsOnce - $e');
      return [];
    }
  }

  /// Tandai notifikasi sudah dibaca
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(collectionNotifications).doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Notification $notificationId marked as read');
    } catch (e) {
      debugPrint('❌ Error markAsRead - $e');
    }
  }

  /// Tandai semua notifikasi user sudah dibaca
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(collectionNotifications)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      debugPrint('✅ Marked ${snapshot.docs.length} as read for user $userId');
    } catch (e) {
      debugPrint('❌ Error markAllAsRead - $e');
    }
  }

  /// Hitung notifikasi belum dibaca
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(collectionNotifications)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getUnreadCount - $e');
      return 0;
    }
  }

  /// Hapus notifikasi lama (cleanup)
  Future<void> cleanOldNotifications({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final snapshot = await _firestore
          .collection(collectionNotifications)
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('✅ Cleaned ${snapshot.docs.length} old notifications');
    } catch (e) {
      debugPrint('❌ Error cleanOld - $e');
    }
  }

  // ==================== 🔥 HSSE RISK VALIDATION NOTIFICATION ====================

  /// Kirim notifikasi ke Manager HSSE untuk validasi risiko
  Future<void> sendHsseApprovalRequest({
    required String hsseId,
    required String hsseEmail,
    required String hsseName,
    required String groupId,
    required String pengawasNama,
    required String tanggal,
    required String riskLevel,
    required List<String> riskFactors,
    required String approvedByManager,
    String? hsseNoHp,
    List<NotificationChannel> channels = defaultChannels,
  }) async {
    try {
      final shortGroupId = groupId.length >= 8 ? groupId.substring(0, 8) : groupId;
      
      // 🔥 Tentukan warna/icon berdasarkan risk level
      String riskEmoji;
      switch (riskLevel.toLowerCase()) {
        case 'critical':
          riskEmoji = '🔴';
          break;
        case 'high':
          riskEmoji = '🟠';
          break;
        case 'medium':
          riskEmoji = '🟡';
          break;
        case 'low':
          riskEmoji = '🟢';
          break;
        default:
          riskEmoji = '⚪';
      }

      final title = '$riskEmoji Validasi Risiko Diperlukan';
      final body = 'Pengajuan lembur dari $pengawasNama ($tanggal)\n'
          'Risk Level: ${riskLevel.toUpperCase()}\n'
          'Faktor: ${riskFactors.take(3).join(", ")}\n'
          'Disetujui oleh: $approvedByManager';

      final notificationData = {
        'group_id': groupId,
        'type': 'hsse_risk_validation',
        'risk_level': riskLevel,
        'risk_factors': riskFactors,
        'pengawas_nama': pengawasNama,
        'approved_by_manager': approvedByManager,
        'tanggal': tanggal,
        'action': 'validate_risk',
        'route': '/manager-hsse/risk-validation/$groupId',
      };

      // Firestore Notification
      if (_shouldSend(channels, NotificationChannel.firestore)) {
        await _createFirestoreNotification(
          userId: hsseId,
          type: 'hsse_risk_validation',
          title: title,
          body: body,
          data: notificationData,
          priority: 1, // Critical priority
        );
      }

      // Email Notification
      if (_shouldSend(channels, NotificationChannel.email) && hsseEmail.isNotEmpty) {
        await _sendEmailNotification(
          toEmail: hsseEmail,
          subject: '$title - $pengawasNama',
          body: _buildHsseApprovalEmailBody(
            hsseName: hsseName,
            pengawasNama: pengawasNama,
            riskLevel: riskLevel,
            riskFactors: riskFactors,
            approvedByManager: approvedByManager,
            tanggal: tanggal,
            shortGroupId: shortGroupId,
            groupId: groupId,
          ),
        );
      }

      // WhatsApp Notification
      if (_shouldSend(channels, NotificationChannel.whatsapp) && 
          hsseNoHp != null && hsseNoHp.isNotEmpty) {
        _sendWhatsAppNotification(
          phoneNumber: hsseNoHp,
          message: _buildHsseApprovalWaMessage(
            hsseName: hsseName,
            pengawasNama: pengawasNama,
            riskLevel: riskLevel,
            riskFactors: riskFactors,
            approvedByManager: approvedByManager,
            tanggal: tanggal,
            shortGroupId: shortGroupId,
            groupId: groupId,
          ),
        );
      }

      // Log notifikasi
      await _firestore.collection('notifications_log').add({
        'type': 'hsse_approval_request',
        'recipient_id': hsseId,
        'recipient_email': hsseEmail,
        'group_id': groupId,
        'risk_level': riskLevel,
        'risk_factors': riskFactors,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ HSSE validation request sent to $hsseName ($hsseEmail)');

      // 🔔 Kabari Superadmin juga ada validasi risiko HSSE yang perlu ditindaklanjuti
      notifySuperAdmins(
        type: 'hsse_risk_validation',
        title: '$riskEmoji Validasi Risiko HSSE Diperlukan',
        message: 'Pengajuan lembur dari $pengawasNama ($tanggal) butuh validasi risiko '
            '(level: ${riskLevel.toUpperCase()}).',
        data: {'groupId': groupId, 'pengawasNama': pengawasNama, 'riskLevel': riskLevel},
        priority: 3,
      );
    } catch (e) {
      debugPrint('❌ Error sendHsseApprovalRequest - $e');
    }
  }

  
  // ==================== SECTION 1: MANAGER NOTIFICATION - PENGAJUAN BARU ====================
  

  /// Kirim notifikasi pengajuan lembur baru ke manager
  Future<void> sendManagerNotification({
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required DateTime tanggal,
    required double totalBiaya,
    required String urgensi,
    required bool isOutsideRadius,
    required List<String> lemburIds,
    required Map<String, dynamic> overtimeRates,
    List<NotificationChannel> channels = defaultChannels,
  }) async {
    try {
      final managers = await _getActiveManagers(fungsi: fungsi);
      
      if (managers.isEmpty) {
        debugPrint('⚠️ No active managers found for fungsi: $fungsi');
        final allManagers = await _getActiveManagers();
        if (allManagers.isEmpty) {
          debugPrint('❌ No managers found at all');
          return;
        }
        debugPrint('🔄 Using all managers as fallback');
        await _sendToManagers(
          managers: allManagers,
          pengawasNama: pengawasNama,
          fungsi: fungsi,
          jumlahMitra: jumlahMitra,
          tanggal: tanggal,
          totalBiaya: totalBiaya,
          urgensi: urgensi,
          isOutsideRadius: isOutsideRadius,
          lemburIds: lemburIds,
          overtimeRates: overtimeRates,
          channels: channels,
        );
        return;
      }

      await _sendToManagers(
        managers: managers,
        pengawasNama: pengawasNama,
        fungsi: fungsi,
        jumlahMitra: jumlahMitra,
        tanggal: tanggal,
        totalBiaya: totalBiaya,
        urgensi: urgensi,
        isOutsideRadius: isOutsideRadius,
        lemburIds: lemburIds,
        overtimeRates: overtimeRates,
        channels: channels,
      );
    } catch (e) {
      debugPrint('❌ Error sendManagerNotification - $e');
    }
  }

  /// Internal: Kirim ke list managers
  Future<void> _sendToManagers({
    required List<Map<String, dynamic>> managers,
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required DateTime tanggal,
    required double totalBiaya,
    required String urgensi,
    required bool isOutsideRadius,
    required List<String> lemburIds,
    required Map<String, dynamic> overtimeRates,
    required List<NotificationChannel> channels,
  }) async {
    final tanggalLengkap = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(tanggal);
    final tanggalShort = DateFormat('dd/MM/yyyy').format(tanggal);
    final biayaFormat = _rateService.formatRupiah(totalBiaya);
    final ratePerHour = _rateService.formatRupiahCompact(
      (overtimeRates['rate_per_hour'] as num?)?.toDouble() ?? 0,
    );
    final groupId = lemburIds.isNotEmpty ? lemburIds.first : '';
    final shortGroupId = groupId.length >= 8 ? groupId.substring(0, 8) : groupId;
    final priority = urgensi == 'tinggi' ? 1 : urgensi == 'normal' ? 3 : 4;

    int sentCount = 0;
    int errorCount = 0;

    for (final manager in managers) {
      try {
        final managerId = manager['id'] as String;
        final managerName = manager['nama_lengkap'] as String? ?? 'Manager';
        final managerEmail = manager['email'] as String? ?? '';
        final managerNoHp = manager['no_hp'] as String? ?? '';

        final notificationData = {
          'group_id': groupId,
          'pengawas_id': _auth.currentUser?.uid ?? '',
          'pengawas_nama': pengawasNama,
          'fungsi': fungsi,
          'jumlah_mitra': jumlahMitra,
          'tanggal': tanggalShort,
          'total_biaya': biayaFormat,
          'total_biaya_raw': totalBiaya,
          'urgensi': urgensi,
          'is_outside_radius': isOutsideRadius,
          'rate_per_hour': ratePerHour,
          'action': 'approval_needed',
          'route': '/manager/approval/$groupId',
        };

        if (_shouldSend(channels, NotificationChannel.firestore)) {
          await _createFirestoreNotification(
            userId: managerId,
            type: 'lembur_submitted',
            title: '📋 Pengajuan Lembur Baru',
            body: _buildManagerNotificationBody(
              pengawasNama: pengawasNama,
              fungsi: fungsi,
              jumlahMitra: jumlahMitra,
              tanggal: tanggalLengkap,
              totalBiaya: biayaFormat,
              ratePerHour: ratePerHour,
              urgensi: urgensi,
              isOutsideRadius: isOutsideRadius,
            ),
            data: notificationData,
            priority: priority,
          );
        }

        if (_shouldSend(channels, NotificationChannel.email) && managerEmail.isNotEmpty) {
          await _sendEmailNotification(
            toEmail: managerEmail,
            subject: '🔔 Pengajuan Lembur Baru - $pengawasNama',
            body: _buildManagerEmailBody(
              managerName: managerName,
              pengawasNama: pengawasNama,
              fungsi: fungsi,
              jumlahMitra: jumlahMitra,
              tanggal: tanggalLengkap,
              totalBiaya: biayaFormat,
              ratePerHour: ratePerHour,
              urgensi: urgensi,
              isOutsideRadius: isOutsideRadius,
              shortGroupId: shortGroupId,
              groupId: groupId,
            ),
          );
        }

        if (_shouldSend(channels, NotificationChannel.whatsapp) && managerNoHp.isNotEmpty) {
          _sendWhatsAppNotification(
            phoneNumber: managerNoHp,
            message: _buildManagerWaMessage(
              managerName: managerName,
              pengawasNama: pengawasNama,
              fungsi: fungsi,
              jumlahMitra: jumlahMitra,
              tanggal: tanggalLengkap,
              totalBiaya: biayaFormat,
              ratePerHour: ratePerHour,
              urgensi: urgensi,
              isOutsideRadius: isOutsideRadius,
              shortGroupId: shortGroupId,
              groupId: groupId,
            ),
          );
        }

        sentCount++;
      } catch (e) {
        errorCount++;
        debugPrint('❌ Error sending to ${manager['nama_lengkap']} - $e');
      }
    }

    debugPrint('✅ Sent to $sentCount/${managers.length} managers ($errorCount errors)');
  }

  
  // ==================== SECTION 2: APPROVAL RESULT NOTIFICATION ====================
  

  /// Kirim notifikasi hasil approval ke pengawas
  Future<void> sendApprovalResultNotification({
    required String pengawasId,
    required String pengawasNama,
    required bool isApproved,
    required String approverName,
    required String approverRole,
    String? spklNomor,
    required String groupId,
    String? notes,
    required String tanggal,
    required String waktu,
    String? fungsi,
    String? pengawasEmail,
    String? pengawasNoHp,
    List<NotificationChannel> channels = defaultChannels,
  }) async {
    try {
      final title = isApproved ? '✅ Lembur Disetujui' : '❌ Lembur Ditolak';
      final type = isApproved ? 'lembur_approved' : 'lembur_rejected';
      final priority = isApproved ? 2 : 3;
      final shortGroupId = groupId.length >= 8 ? groupId.substring(0, 8) : groupId;

      final body = isApproved
          ? _buildApprovedBody(
              approverName: approverName,
              approverRole: approverRole,
              spklNomor: spklNomor,
              tanggal: tanggal,
              waktu: waktu,
              notes: notes,
            )
          : _buildRejectedBody(
              approverName: approverName,
              approverRole: approverRole,
              notes: notes,
            );

      final notificationData = {
        'group_id': groupId,
        'spkl_nomor': spklNomor,
        'status': isApproved ? 'disetujui' : 'ditolak',
        'approver_name': approverName,
        'approver_role': approverRole,
        'notes': notes ?? '',
        'tanggal': tanggal,
        'waktu': waktu,
        'fungsi': fungsi ?? '',
        'route': isApproved ? '/pengawas/spkl/$groupId' : '/pengawas/riwayat',
      };

      if (_shouldSend(channels, NotificationChannel.firestore)) {
        await _createFirestoreNotification(
          userId: pengawasId,
          type: type,
          title: title,
          body: body,
          data: notificationData,
          priority: priority,
        );
      }

      if (_shouldSend(channels, NotificationChannel.email) && 
          pengawasEmail != null && pengawasEmail.isNotEmpty) {
        await _sendEmailNotification(
          toEmail: pengawasEmail,
          subject: '$title - $tanggal',
          body: _buildApprovalResultEmailBody(
            recipientName: pengawasNama,
            isApproved: isApproved,
            approverName: approverName,
            approverRole: approverRole,
            spklNomor: spklNomor,
            shortGroupId: shortGroupId,
            groupId: groupId,
            tanggal: tanggal,
            waktu: waktu,
            fungsi: fungsi,
            notes: notes,
          ),
        );
      }

      if (_shouldSend(channels, NotificationChannel.whatsapp) && 
          pengawasNoHp != null && pengawasNoHp.isNotEmpty) {
        _sendWhatsAppNotification(
          phoneNumber: pengawasNoHp,
          message: _buildApprovalResultWaMessage(
            recipientName: pengawasNama,
            isApproved: isApproved,
            approverName: approverName,
            approverRole: approverRole,
            spklNomor: spklNomor,
            groupId: groupId,
            notes: notes,
            tanggal: tanggal,
            waktu: waktu,
          ),
        );
      }

      debugPrint('✅ Approval result sent to $pengawasNama');
    } catch (e) {
      debugPrint('❌ Error sendApprovalResult - $e');
    }
  }

  
  // ==================== SECTION 3: MITRA ASSIGNMENT NOTIFICATION ====================
  

  /// Kirim notifikasi penugasan ke mitra
  Future<void> sendMitraAssignmentNotification({
    required String mitraId,
    required String mitraNama,
    String? mitraEmail,
    String? mitraNoHp,
    String? spklNomor,
    required String groupId,
    required String pengawasNama,
    required String tanggal,
    required String waktu,
    required String lokasi,
    String? fungsi,
    List<NotificationChannel> channels = defaultChannels,
  }) async {
    try {
      final body = _buildMitraAssignmentBody(
        spklNomor: spklNomor,
        pengawasNama: pengawasNama,
        fungsi: fungsi,
        tanggal: tanggal,
        waktu: waktu,
        lokasi: lokasi,
      );

      final notificationData = {
        'group_id': groupId,
        'spkl_nomor': spklNomor,
        'pengawas_nama': pengawasNama,
        'tanggal': tanggal,
        'waktu': waktu,
        'lokasi': lokasi,
        'fungsi': fungsi ?? '',
        'action': 'view_spkl',
        'need_absen': true,
        'route': '/mitra/spkl/$groupId',
      };

      if (_shouldSend(channels, NotificationChannel.firestore)) {
        await _createFirestoreNotification(
          userId: mitraId,
          type: 'lembur_assignment',
          title: '📋 Jadwal Lembur Baru',
          body: body,
          data: notificationData,
          priority: 1,
        );
      }

      if (_shouldSend(channels, NotificationChannel.email) && 
          mitraEmail != null && mitraEmail.isNotEmpty) {
        await _sendEmailNotification(
          toEmail: mitraEmail,
          subject: '📋 Jadwal Lembur - $pengawasNama',
          body: _buildMitraAssignmentEmailBody(
            recipientName: mitraNama,
            spklNomor: spklNomor,
            pengawasNama: pengawasNama,
            fungsi: fungsi,
            tanggal: tanggal,
            waktu: waktu,
            lokasi: lokasi,
            groupId: groupId,
          ),
        );
      }

      if (_shouldSend(channels, NotificationChannel.whatsapp) && 
          mitraNoHp != null && mitraNoHp.isNotEmpty) {
        _sendWhatsAppNotification(
          phoneNumber: mitraNoHp,
          message: _buildMitraAssignmentWaMessage(
            recipientName: mitraNama,
            spklNomor: spklNomor,
            pengawasNama: pengawasNama,
            fungsi: fungsi,
            tanggal: tanggal,
            waktu: waktu,
            lokasi: lokasi,
            groupId: groupId,
          ),
        );
      }

      debugPrint('✅ Assignment sent to $mitraNama');
    } catch (e) {
      debugPrint('❌ Error sendMitraAssignment - $e');
    }
  }

  
  // ==================== SECTION 4: ABSENSI REMINDER ====================
  

  /// Kirim pengingat absensi ke mitra
  Future<void> sendAbsensiReminder({
    required String mitraId,
    required String mitraNama,
    String? mitraNoHp,
    required String groupId,
    required String tanggal,
    required String waktu,
    required bool isCheckIn,
    List<NotificationChannel> channels = defaultChannels,
  }) async {
    try {
      final type = isCheckIn ? 'check_in' : 'check_out';
      final title = isCheckIn ? '📸 Waktunya Absen Masuk!' : '📸 Waktunya Absen Pulang!';
      final action = isCheckIn ? 'absen_masuk' : 'absen_pulang';

      final body = _buildAbsensiReminderBody(
        isCheckIn: isCheckIn,
        tanggal: tanggal,
        waktu: waktu,
      );

      if (_shouldSend(channels, NotificationChannel.firestore)) {
        await _createFirestoreNotification(
          userId: mitraId,
          type: type,
          title: title,
          body: body,
          data: {
            'group_id': groupId,
            'action': action,
            'tanggal': tanggal,
            'waktu': waktu,
            'route': '/mitra/absen/$groupId',
          },
          priority: 1,
        );
      }

      if (_shouldSend(channels, NotificationChannel.whatsapp) && 
          mitraNoHp != null && mitraNoHp.isNotEmpty) {
        _sendWhatsAppNotification(
          phoneNumber: mitraNoHp,
          message: _buildAbsensiReminderWaMessage(
            recipientName: mitraNama,
            isCheckIn: isCheckIn,
            tanggal: tanggal,
            waktu: waktu,
            groupId: groupId,
          ),
        );
      }

      debugPrint('✅ Absensi reminder sent to $mitraNama');
    } catch (e) {
      debugPrint('❌ Error sendAbsensiReminder - $e');
    }
  }

  
  // ==================== SECTION 5: SPKL READY NOTIFICATION ====================
  

  /// Kirim notifikasi SPKL siap ke pengawas dan mitra
  Future<void> sendSpklReadyNotification({
    required String pengawasId,
    required String pengawasNama,
    String? pengawasEmail,
    required List<Map<String, String>> mitraContacts,
    required String spklNomor,
    required String groupId,
    required String tanggal,
    required String waktu,
    required String lokasi,
    List<NotificationChannel> channels = defaultChannels,
  }) async {
    try {
      // Notifikasi ke pengawas
      if (_shouldSend(channels, NotificationChannel.firestore)) {
        await _createFirestoreNotification(
          userId: pengawasId,
          type: 'spkl_ready',
          title: '📄 SPKL Telah Digenerate',
          body: _buildSpklReadyBody(
            spklNomor: spklNomor,
            tanggal: tanggal,
            waktu: waktu,
            lokasi: lokasi,
          ),
          data: {
            'group_id': groupId,
            'spkl_nomor': spklNomor,
            'action': 'view_spkl',
            'route': '/pengawas/spkl/$groupId',
          },
          priority: 1,
        );
      }

      if (_shouldSend(channels, NotificationChannel.email) && 
          pengawasEmail != null && pengawasEmail.isNotEmpty) {
        await _sendEmailNotification(
          toEmail: pengawasEmail,
          subject: '📄 SPKL Lembur Siap - $spklNomor',
          body: _buildSpklReadyEmailBody(
            recipientName: pengawasNama,
            spklNomor: spklNomor,
            groupId: groupId,
            tanggal: tanggal,
            waktu: waktu,
            lokasi: lokasi,
          ),
        );
      }

      // Notifikasi ke semua mitra
      for (final mitra in mitraContacts) {
        final mitraId = mitra['id'] ?? '';
        final mitraNama = mitra['nama'] ?? 'Mitra';
        final mitraNoHp = mitra['no_hp'] ?? '';
        if (mitraId.isEmpty) continue;

        if (_shouldSend(channels, NotificationChannel.firestore)) {
          await _createFirestoreNotification(
            userId: mitraId,
            type: 'spkl_ready',
            title: '📄 SPKL Lembur Siap',
            body: _buildSpklReadyBody(
              spklNomor: spklNomor,
              tanggal: tanggal,
              waktu: waktu,
              lokasi: lokasi,
            ),
            data: {
              'group_id': groupId,
              'spkl_nomor': spklNomor,
              'action': 'view_spkl',
              'route': '/mitra/spkl/$groupId',
            },
            priority: 1,
          );
        }

        if (_shouldSend(channels, NotificationChannel.whatsapp) && mitraNoHp.isNotEmpty) {
          _sendWhatsAppNotification(
            phoneNumber: mitraNoHp,
            message: _buildSpklReadyWaMessage(
              recipientName: mitraNama,
              spklNomor: spklNomor,
              tanggal: tanggal,
              waktu: waktu,
              lokasi: lokasi,
              groupId: groupId,
            ),
          );
        }
      }

      debugPrint('✅ SPKL ready sent to all parties');

      // 🔔 Kabari Superadmin milestone SPKL sudah terbit
      notifySuperAdmins(
        type: 'spkl_ready',
        title: '📄 SPKL Terbit',
        message: 'SPKL $spklNomor untuk pengajuan $pengawasNama ($tanggal) sudah digenerate.',
        data: {'groupId': groupId, 'spklNomor': spklNomor, 'pengawasNama': pengawasNama},
        priority: 4,
      );
    } catch (e) {
      debugPrint('❌ Error sendSpklReady - $e');
    }
  }

  
  // ==================== SECTION 6: MITRA STATUS NOTIFICATIONS ====================
  

  /// Notifikasi check-in mitra ke pengawas
  Future<void> sendMitraCheckInNotification({
    required String mitraName,
    required String lemburId,
    required String pengawasId,
  }) async {
    await _createFirestoreNotification(
      userId: pengawasId,
      type: 'check_in',
      title: '✅ Mitra Check-In',
      body: '$mitraName telah melakukan check-in lembur',
      data: {
        'lembur_id': lemburId,
        'mitra_name': mitraName,
        'action': 'view_lembur',
      },
      priority: 2,
    );
    debugPrint('✅ Check-in notification sent to pengawas $pengawasId');
  }

  /// Notifikasi check-out mitra ke pengawas
  Future<void> sendMitraCheckOutNotification({
    required String mitraName,
    required String lemburId,
    required String pengawasId,
    required double actualHours,
    required double income,
  }) async {
    final incomeFormatted = _rateService.formatRupiah(income);
    await _createFirestoreNotification(
      userId: pengawasId,
      type: 'lembur_completed',
      title: '🏁 Lembur Selesai',
      body: '$mitraName telah menyelesaikan lembur (${actualHours.toStringAsFixed(1)} jam) - $incomeFormatted',
      data: {
        'lembur_id': lemburId,
        'mitra_name': mitraName,
        'duration': actualHours,
        'income': income,
        'income_formatted': incomeFormatted,
        'action': 'view_lembur',
      },
      priority: 2,
    );
    debugPrint('✅ Check-out notification sent to pengawas $pengawasId');
  }

  /// Notifikasi mitra menolak lembur
  Future<void> sendMitraRejectionNotification({
    required String mitraId,
    required String overtimeId,
    String? reason,
  }) async {
    await _createFirestoreNotification(
      userId: mitraId,
      type: 'lembur_rejected',
      title: '❌ Lembur Ditolak',
      body: 'Anda telah menolak jadwal lembur. ${reason != null ? "Alasan: $reason" : ""}',
      data: {
        'lembur_id': overtimeId,
        'reason': reason ?? '',
        'action': 'none',
      },
      priority: 3,
    );
    debugPrint('✅ Rejection notification sent to mitra $mitraId');

    // 🔔 Kabari Superadmin ada mitra yang menolak jadwal — mungkin perlu reassign
    notifySuperAdmins(
      type: 'lembur_rejected',
      title: '⚠️ Mitra Menolak Jadwal Lembur',
      message: 'Seorang mitra menolak jadwal lembur.${reason != null ? " Alasan: $reason" : ""}',
      data: {'lemburId': overtimeId, 'mitraId': mitraId, 'reason': reason ?? ''},
      priority: 3,
    );
  }

  /// Notifikasi mitra konfirmasi lembur
  Future<void> sendMitraConfirmationNotification({
    required String mitraId,
    required String overtimeId,
  }) async {
    await _createFirestoreNotification(
      userId: mitraId,
      type: 'lembur_confirmed',
      title: '✅ Lembur Dikonfirmasi',
      body: 'Anda telah mengonfirmasi jadwal lembur',
      data: {
        'lembur_id': overtimeId,
        'action': 'none',
      },
      priority: 3,
    );
    debugPrint('✅ Confirmation notification sent to mitra $mitraId');
  }

  
  // ==================== SECTION 7: GENERAL NOTIFICATION ====================
  

  /// Kirim notifikasi umum ke user
  Future<void> sendGeneralNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String? userEmail,
    String? userNoHp,
    String? userName,
    List<NotificationChannel> channels = defaultChannels,
  }) async {
    try {
      if (_shouldSend(channels, NotificationChannel.firestore)) {
        await _createFirestoreNotification(
          userId: userId,
          type: 'general',
          title: title,
          body: message,
          data: data ?? {},
          priority: 5,
        );
      }

      if (_shouldSend(channels, NotificationChannel.email) && 
          userEmail != null && userEmail.isNotEmpty) {
        await _sendEmailNotification(
          toEmail: userEmail,
          subject: title,
          body: message,
        );
      }

      if (_shouldSend(channels, NotificationChannel.whatsapp) && 
          userNoHp != null && userNoHp.isNotEmpty) {
        _sendWhatsAppNotification(
          phoneNumber: userNoHp,
          message: '📢 *$title*\n\n$message\n\n*Sistem Lembur PGE Kamojang*',
        );
      }
      debugPrint('✅ General notification sent to $userId');
    } catch (e) {
      debugPrint('❌ Error sendGeneral - $e');
    }
  }

  
  // ==================== 🔥 TESTING METHOD ====================
  

  /// Method untuk testing push notification (development only)
  Future<void> testPushNotification({
    required String userId,
    bool testPriority = true,
  }) async {
    try {
      final token = await _getUserFcmToken(userId);
      if (token == null) {
        debugPrint('❌ User $userId tidak punya FCM token');
        return;
      }

      final type = testPriority ? 'lembur_submitted' : 'general';
      
      await _sendPushNotification(
        userId: userId,
        type: type,
        title: testPriority 
            ? '🔊 TEST - Notifikasi Prioritas OTP' 
            : '🔔 TEST - Notifikasi Umum',
        body: testPriority 
            ? 'Ini test notifikasi prioritas dengan suara OTP custom' 
            : 'Ini test notifikasi umum dengan suara default',
        data: {
          'test': 'true',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      debugPrint('✅ Test push sent - type: $type');
    } catch (e) {
      debugPrint('❌ Test push gagal - $e');
    }
  }


  // ==================== SECTION 8: SUPERADMIN NOTIFICATION ====================


  /// Ambil semua user dengan role superadmin yang aktif
  Future<List<Map<String, dynamic>>> _getActiveSuperAdmins() async {
    try {
      final snapshot = await _firestore
          .collection(collectionUsers)
          .where('role', isEqualTo: 'superadmin')
          .where('status_akun', isEqualTo: 'active')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'email': data['email'] ?? '',
          'nama_lengkap': data['nama_lengkap'] ?? 'Superadmin',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error get superadmins - $e');
      return [];
    }
  }

  /// Kirim notifikasi ke SEMUA Superadmin aktif.
  Future<void> notifySuperAdmins({
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    int priority = 4,
  }) async {
    try {
      final superadmins = await _getActiveSuperAdmins();
      if (superadmins.isEmpty) {
        debugPrint('⚠️ Tidak ada Superadmin aktif untuk dikirimi notifikasi');
        return;
      }

      for (final sa in superadmins) {
        await _createFirestoreNotification(
          userId: sa['id'],
          type: type,
          title: title,
          body: message,
          data: data ?? {},
          priority: priority,
        );
      }
      debugPrint('✅ Notified ${superadmins.length} superadmin(s) - type: $type');
    } catch (e) {
      debugPrint('❌ Error notifySuperAdmins - $e');
    }
  }

  /// Notifikasi ke Superadmin ketika ada user baru berhasil registrasi
  Future<void> sendUserRegisteredNotification({
    required String userName,
    required String userEmail,
    String? userPhone,
  }) async {
    await notifySuperAdmins(
      type: 'user_registered',
      title: '👤 Registrasi Mitra Baru',
      message: '$userName ($userEmail) baru saja mendaftar sebagai Mitra.',
      data: {
        'userName': userName,
        'userEmail': userEmail,
        if (userPhone != null) 'userPhone': userPhone,
      },
      priority: 4,
    );
  }

  
  // ==================== PRIVATE HELPERS ====================
  

  /// Cek apakah channel tertentu harus dikirim
  bool _shouldSend(List<NotificationChannel> channels, NotificationChannel channel) {
    return channels.contains(channel) || channels.contains(NotificationChannel.all);
  }

  /// Buat notifikasi di Firestore + kirim push notification
  Future<void> _createFirestoreNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    int priority = 5,
  }) async {
    try {
      await _firestore.collection(collectionNotifications).add({
        'userId': userId,
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        'isRead': false,
        'priority': priority,
        'priorityLabel': priorityLevels[priority] ?? 'info',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('📝 Firestore notification created - type: $type, priority: $priority');
    } catch (e) {
      debugPrint('❌ Error create notification - $e');
      rethrow;
    }

    // Kirim push notification (best-effort — tidak blocking)
    _sendPushNotification(
      userId: userId,
      type: type,
      title: title,
      body: body,
      data: data,
    );
  }

  // 🔥🔥🔥 KIRIM PUSH NOTIFICATION DENGAN KONFIGURASI SUARA 🔥🔥🔥
  Future<void> _sendPushNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // 1) Cek preferensi user
      final prefsAllowed = await _isPushAllowed(userId: userId, type: type);
      if (!prefsAllowed) {
        debugPrint('🔕 Push untuk "$type" di-mute user $userId, skip.');
        return;
      }

      // 2) Ambil FCM token user
      final token = await _getUserFcmToken(userId);
      if (token == null) {
        debugPrint('ℹ️ User $userId belum punya FCM token, skip push.');
        return;
      }

      // 3) Konversi data ke string
      final stringData = data.map((k, v) => MapEntry(k, v.toString()));
      
      // 4) Tentukan apakah ini notifikasi prioritas
      final isPriority = isPriorityType(type);

      // 🔔 5) Tentukan suara berdasarkan tipe notifikasi
      final soundName = isPriority ? 'otp_notification_sound' : 'default';

      // 🔥 6) Kirim ke Cloudflare Worker DENGAN KONFIGURASI SUARA LENGKAP
      final payload = {
        'token': token,
        'title': title,
        'body': body,
        'data': {
          'type': type,
          ...stringData,
        },
        'is_priority': isPriority,
        
        // 🔔 KONFIGURASI SUARA - DITAMBAHKAN
        'sound': soundName,
        'channel_id': _channelId,
        'android_channel_id': _channelId,
        
        // 📱 Android-specific config
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': _channelId,
            'sound': soundName,
            'priority': 'max',
            'visibility': 'public',
          },
        },
        
        // 🍎 iOS-specific config
        'apns': {
          'payload': {
            'aps': {
              'sound': '$soundName.caf',
              'content_available': 1,
              'mutable_content': 1,
            },
          },
        },
      };

      debugPrint('📤 Sending push to Worker - type: $type, priority: $isPriority, sound: $soundName');

      final response = await http.post(
        Uri.parse(_pushWorkerUrl),
        headers: {
          'Authorization': 'Bearer $_pushSharedSecret',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint('✅ Push terkirim ke $userId ($type) - ${result['result'] ?? 'OK'}');
      } else {
        debugPrint('❌ Push gagal (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error _sendPushNotification - $e');
      // Tidak rethrow: gagal push bukan alasan menggagalkan seluruh proses
    }
  }

  /// Ambil FCM token user dari Firestore
  Future<String?> _getUserFcmToken(String userId) async {
    try {
      final doc = await _firestore.collection(collectionUsers).doc(userId).get();
      return doc.data()?['fcmToken'] as String?;
    } catch (e) {
      debugPrint('❌ Error getUserFcmToken - $e');
      return null;
    }
  }

  /// Cek apakah push notification diizinkan user
  Future<bool> _isPushAllowed({required String userId, required String type}) async {
    try {
      final doc = await _firestore
          .collection('notification_preferences')
          .doc(userId)
          .get();

      if (!doc.exists) return true; // default: semua nyala

      final prefs = doc.data()!;
      final pushEnabled = prefs['pushEnabled'] ?? true;
      final typeEnabled = (prefs['types'] as Map<String, dynamic>?)?[type] ?? true;

      return pushEnabled && typeEnabled;
    } catch (e) {
      debugPrint('⚠️ Error cek preferensi push - $e');
      return true; // fallback aman
    }
  }

  /// Ambil daftar manager aktif
  Future<List<Map<String, dynamic>>> _getActiveManagers({String? fungsi}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(collectionUsers)
          .where('role', isEqualTo: 'manager')
          .where('status_akun', isEqualTo: 'active');

      if (fungsi != null && fungsi.isNotEmpty) {
        query = query.where('fungsi', isEqualTo: fungsi.toLowerCase());
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'email': data['email'] ?? '',
          'no_hp': data['no_hp'] ?? '',
          'nama_lengkap': data['nama_lengkap'] ?? 'Manager',
          'fungsi': data['fungsi'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error get managers - $e');
      return [];
    }
  }

  /// Kirim email via mailto
  Future<void> _sendEmailNotification({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: toEmail,
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        debugPrint('✅ Email client opened for $toEmail');
      } else {
        debugPrint('⚠️ Cannot launch email client');
      }
    } catch (e) {
      debugPrint('❌ Error sending email - $e');
    }
  }

  /// Kirim WhatsApp via Fonnte API
  void _sendWhatsAppNotification({
    required String phoneNumber,
    required String message,
  }) {
    try {
      final formattedNumber = _formatPhoneNumber(phoneNumber);

      http.post(
        Uri.parse(_fonnteApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _fonnteApiKey,
        },
        body: json.encode({
          'target': formattedNumber,
          'message': message,
          'countryCode': '62',
        }),
      ).timeout(const Duration(seconds: 15)).then((response) {
        if (response.statusCode == 200) {
          debugPrint('✅ WhatsApp sent to $formattedNumber');
        } else {
          debugPrint('⚠️ WhatsApp failed - ${response.statusCode}');
        }
      }).catchError((e) {
        debugPrint('❌ WhatsApp error - $e');
      });
    } catch (e) {
      debugPrint('❌ WhatsApp prepare error - $e');
    }
  }

  /// Format nomor telepon ke format internasional
  String _formatPhoneNumber(String phoneNumber) {
    String formatted = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (formatted.startsWith('0')) {
      formatted = '62${formatted.substring(1)}';
    } else if (!formatted.startsWith('62')) {
      formatted = '62$formatted';
    }
    return formatted;
  }

  
  // ==================== 🔥 HSSE MESSAGE TEMPLATES ====================

  /// Email body untuk HSSE approval request
  String _buildHsseApprovalEmailBody({
    required String hsseName,
    required String pengawasNama,
    required String riskLevel,
    required List<String> riskFactors,
    required String approvedByManager,
    required String tanggal,
    required String shortGroupId,
    required String groupId,
  }) {
    final riskFactorsText = riskFactors.map((f) => '  • $f').join('\n');
    
    return '''
Halo $hsseName,

Pengajuan lembur memerlukan validasi risiko dari Anda.

━━━━━━━━━━━━━━━━━━━━━━
⚠️ DETAIL RISIKO
━━━━━━━━━━━━━━━━━━━━━━
👤 Pengawas      : $pengawasNama
📅 Tanggal        : $tanggal
🔴 Risk Level     : ${riskLevel.toUpperCase()}
✅ Disetujui Oleh : $approvedByManager (Manager)

📋 Faktor Risiko:
$riskFactorsText

━━━━━━━━━━━━━━━━━━━━━━
📌 ID Pengajuan   : $shortGroupId...
━━━━━━━━━━━━━━━━━━━━━━

⚠️ Dengan menyetujui, Anda bertanggung jawab atas keselamatan kerja.

🔗 Buka aplikasi untuk validasi:
$_baseUrl/manager-hsse/risk-validation/$groupId

Terima kasih,
Sistem Lembur PGE Kamojang
© ${DateTime.now().year} Overtime PGE Kamojang
''';
  }

  /// WhatsApp message untuk HSSE approval request
  String _buildHsseApprovalWaMessage({
    required String hsseName,
    required String pengawasNama,
    required String riskLevel,
    required List<String> riskFactors,
    required String approvedByManager,
    required String tanggal,
    required String shortGroupId,
    required String groupId,
  }) {
    String riskEmoji;
    switch (riskLevel.toLowerCase()) {
      case 'critical': riskEmoji = '🔴🔴🔴'; break;
      case 'high': riskEmoji = '🟠🟠'; break;
      case 'medium': riskEmoji = '🟡'; break;
      default: riskEmoji = '🟢'; break;
    }

    final riskFactorsText = riskFactors.map((f) => '  • $f').join('\n');
    
    return '''
$riskEmoji *VALIDASI RISIKO DIPERLUKAN*
━━━━━━━━━━━━━━━━━━━

Yth. Bapak/Ibu *$hsseName*

Pengajuan lembur memerlukan validasi risiko:

👤 *Pengawas:* $pengawasNama
📅 *Tanggal:* $tanggal
🔴 *Risk Level:* ${riskLevel.toUpperCase()}
✅ *Disetujui:* $approvedByManager (Manager)

📋 *Faktor Risiko:*
$riskFactorsText

━━━━━━━━━━━━━━━━━━━
📌 *ID:* $shortGroupId...
━━━━━━━━━━━━━━━━━━━

⚠️ Dengan menyetujui, Anda bertanggung jawab atas keselamatan kerja.

🔗 *Validasi di aplikasi:*
$_baseUrl/manager-hsse/risk-validation/$groupId

Terima kasih.
''';
  }

  
  // ==================== MESSAGE TEMPLATES - BODY (untuk Firestore) ====================
  

  String _buildManagerNotificationBody({
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required String tanggal,
    required String totalBiaya,
    required String ratePerHour,
    required String urgensi,
    required bool isOutsideRadius,
  }) {
    return 'Pengawas: $pengawasNama ($fungsi)\n'
        'Mitra: $jumlahMitra orang\n'
        'Tanggal: $tanggal\n'
        'Biaya: $totalBiaya\n'
        'Rate/Jam: $ratePerHour\n'
        'Urgensi: ${urgensi.toUpperCase()}\n'
        '${isOutsideRadius ? '⚠️ LOKASI LUAR RADIUS' : '✅ Dalam Radius'}';
  }

  String _buildApprovedBody({
    required String approverName,
    required String approverRole,
    String? spklNomor,
    required String tanggal,
    required String waktu,
    String? notes,
  }) {
    return 'Lembur DISETUJUI oleh $approverName ($approverRole)\n'
        'No SPKL: ${spklNomor ?? '-'}\n'
        'Tanggal: $tanggal\n'
        'Waktu: $waktu\n'
        '${notes != null && notes.isNotEmpty ? 'Catatan: $notes' : ''}';
  }

  String _buildRejectedBody({
    required String approverName,
    required String approverRole,
    String? notes,
  }) {
    return 'Lembur DITOLAK oleh $approverName ($approverRole)\n'
        '${notes != null && notes.isNotEmpty ? 'Alasan: $notes' : 'Tidak ada alasan'}';
  }

  String _buildMitraAssignmentBody({
    String? spklNomor,
    required String pengawasNama,
    String? fungsi,
    required String tanggal,
    required String waktu,
    required String lokasi,
  }) {
    return 'No SPKL: ${spklNomor ?? '-'}\n'
        'Pengawas: $pengawasNama\n'
        'Fungsi: ${fungsi?.toUpperCase() ?? '-'}\n'
        'Tanggal: $tanggal\n'
        'Waktu: $waktu\n'
        'Lokasi: $lokasi\n\n'
        '⚠️ Wajib absensi sebelum & sesudah lembur';
  }

  String _buildAbsensiReminderBody({
    required bool isCheckIn,
    required String tanggal,
    required String waktu,
  }) {
    return '${isCheckIn ? "Waktunya absen masuk!" : "Waktunya absen pulang!"}\n'
        'Tanggal: $tanggal\n'
        'Waktu: $waktu\n\n'
        'Jangan lupa upload foto sebagai bukti absensi.';
  }

  String _buildSpklReadyBody({
    required String spklNomor,
    required String tanggal,
    required String waktu,
    required String lokasi,
  }) {
    return 'No SPKL: $spklNomor\n'
        'Tanggal: $tanggal\n'
        'Waktu: $waktu\n'
        'Lokasi: $lokasi\n\n'
        'Klik untuk melihat dan mengunduh SPKL.';
  }

  
  // ==================== MESSAGE TEMPLATES - EMAIL ====================
  

  String _buildManagerEmailBody({
    required String managerName,
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required String tanggal,
    required String totalBiaya,
    required String ratePerHour,
    required String urgensi,
    required bool isOutsideRadius,
    required String shortGroupId,
    required String groupId,
  }) {
    return '''
Halo $managerName,

Ada pengajuan lembur baru yang membutuhkan persetujuan Anda.

━━━━━━━━━━━━━━━━━━━━━━
📋 DETAIL PENGAJUAN
━━━━━━━━━━━━━━━━━━━━━━
👤 Pengawas    : $pengawasNama
🏢 Fungsi       : ${fungsi.toUpperCase()}
👥 Mitra        : $jumlahMitra orang
📅 Tanggal      : $tanggal
💰 Estimasi     : $totalBiaya
💵 Rate/Jam     : $ratePerHour
⚡ Urgensi      : ${urgensi.toUpperCase()}
📍 Lokasi       : ${isOutsideRadius ? '⚠️ LUAR RADIUS' : '✅ DALAM RADIUS'}

━━━━━━━━━━━━━━━━━━━━━━
📌 ID Pengajuan : $shortGroupId...
━━━━━━━━━━━━━━━━━━━━━━

🔗 Buka aplikasi untuk persetujuan:
$_baseUrl/approval/$groupId

Terima kasih,
Sistem Lembur PGE Kamojang
© ${DateTime.now().year} Overtime PGE Kamojang
''';
  }

  String _buildApprovalResultEmailBody({
    required String recipientName,
    required bool isApproved,
    required String approverName,
    required String approverRole,
    String? spklNomor,
    required String shortGroupId,
    required String groupId,
    required String tanggal,
    required String waktu,
    String? fungsi,
    String? notes,
  }) {
    return '''
Halo $recipientName,

Status pengajuan lembur Anda: ${isApproved ? 'DISETUJUI ✅' : 'DITOLAK ❌'}

━━━━━━━━━━━━━━━━━━━━━━
📋 DETAIL
━━━━━━━━━━━━━━━━━━━━━━
👤 Approver     : $approverName ($approverRole)
📄 No SPKL      : ${spklNomor ?? '-'}
📌 ID           : $shortGroupId
📅 Tanggal      : $tanggal
⏰ Waktu        : $waktu
🏢 Fungsi       : ${fungsi?.toUpperCase() ?? '-'}
📝 Catatan      : ${notes ?? '-'}

${isApproved ? '🔗 Lihat SPKL: $_baseUrl/spkl/$groupId' : '🔗 Ajukan ulang: $_baseUrl/ajukan-lembur'}

Terima kasih,
Sistem Lembur PGE Kamojang
© ${DateTime.now().year} Overtime PGE Kamojang
''';
  }

  String _buildMitraAssignmentEmailBody({
    required String recipientName,
    String? spklNomor,
    required String pengawasNama,
    String? fungsi,
    required String tanggal,
    required String waktu,
    required String lokasi,
    required String groupId,
  }) {
    return '''
Halo $recipientName,

Anda telah ditugaskan untuk lembur.

━━━━━━━━━━━━━━━━━━━━━━
📋 DETAIL PENUGASAN
━━━━━━━━━━━━━━━━━━━━━━
📄 No SPKL      : ${spklNomor ?? '-'}
👤 Pengawas     : $pengawasNama
🏢 Fungsi       : ${fungsi?.toUpperCase() ?? '-'}
📅 Tanggal      : $tanggal
⏰ Waktu        : $waktu
📍 Lokasi       : $lokasi

━━━━━━━━━━━━━━━━━━━━━━
⚠️ PENTING: Lakukan absensi sebelum dan sesudah lembur
━━━━━━━━━━━━━━━━━━━━━━

🔗 Lihat SPKL: $_baseUrl/spkl/$groupId

Terima kasih,
Sistem Lembur PGE Kamojang
© ${DateTime.now().year} Overtime PGE Kamojang
''';
  }

  String _buildSpklReadyEmailBody({
    required String recipientName,
    required String spklNomor,
    required String groupId,
    required String tanggal,
    required String waktu,
    required String lokasi,
  }) {
    return '''
Halo $recipientName,

SPKL lembur telah siap.

━━━━━━━━━━━━━━━━━━━━━━
📄 DETAIL SPKL
━━━━━━━━━━━━━━━━━━━━━━
📄 No SPKL      : $spklNomor
📅 Tanggal      : $tanggal
⏰ Waktu        : $waktu
📍 Lokasi       : $lokasi

🔗 Lihat SPKL: $_baseUrl/spkl/$groupId

Terima kasih,
Sistem Lembur PGE Kamojang
© ${DateTime.now().year} Overtime PGE Kamojang
''';
  }

  
  // ==================== MESSAGE TEMPLATES - WHATSAPP ====================
  

  String _buildManagerWaMessage({
    required String managerName,
    required String pengawasNama,
    required String fungsi,
    required int jumlahMitra,
    required String tanggal,
    required String totalBiaya,
    required String ratePerHour,
    required String urgensi,
    required bool isOutsideRadius,
    required String shortGroupId,
    required String groupId,
  }) {
    return '''
🔔 *PENGAJUAN LEMBUR BARU*
━━━━━━━━━━━━━━━━━━━

Yth. Bapak/Ibu *$managerName*

Ada pengajuan lembur baru yang membutuhkan persetujuan:

👤 *Pengawas:* $pengawasNama
🏢 *Fungsi:* ${fungsi.toUpperCase()}
👥 *Mitra:* $jumlahMitra orang
📅 *Tanggal:* $tanggal
💰 *Estimasi Biaya:* $totalBiaya
💵 *Rate/Jam:* $ratePerHour
⚡ *Urgensi:* ${urgensi.toUpperCase()}
📍 *Status:* ${isOutsideRadius ? '⚠️ LUAR RADIUS' : '✅ DALAM RADIUS'}

━━━━━━━━━━━━━━━━━━━
*ID:* $shortGroupId...
*Status:* Menunggu Persetujuan
━━━━━━━━━━━━━━━━━━━

🔗 *Link Approve:*
$_baseUrl/approval/$groupId

Terima kasih.
''';
  }

  String _buildApprovalResultWaMessage({
    required String recipientName,
    required bool isApproved,
    required String approverName,
    required String approverRole,
    String? spklNomor,
    required String groupId,
    String? notes,
    required String tanggal,
    required String waktu,
  }) {
    if (isApproved) {
      return '''
✅ *PENGAJUAN LEMBUR DISETUJUI*
━━━━━━━━━━━━━━━━━━━

Halo *$recipientName*,

Pengajuan lembur kamu telah *DISETUJUI*!

📄 *No SPKL:* ${spklNomor ?? '-'}
👤 *Approver:* $approverName ($approverRole)
📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu

${notes != null && notes.isNotEmpty ? '📝 *Catatan:* $notes' : ''}

🔗 Lihat SPKL di aplikasi:
$_baseUrl/spkl/$groupId

Terima kasih.
''';
    } else {
      return '''
❌ *PENGAJUAN LEMBUR DITOLAK*
━━━━━━━━━━━━━━━━━━━

Halo *$recipientName*,

Pengajuan lembur kamu *DITOLAK*.

👤 *Approver:* $approverName ($approverRole)
📝 *Alasan:* ${notes ?? 'Tidak ada alasan'}

Silakan revisi dan ajukan kembali.

🔗 Buka aplikasi:
$_baseUrl/ajukan-lembur
''';
    }
  }

  String _buildMitraAssignmentWaMessage({
    required String recipientName,
    String? spklNomor,
    required String pengawasNama,
    String? fungsi,
    required String tanggal,
    required String waktu,
    required String lokasi,
    required String groupId,
  }) {
    return '''
📋 *JADWAL LEMBUR BARU*
━━━━━━━━━━━━━━━━━━━

Halo *$recipientName*,

Kamu ditugaskan untuk lembur!

📄 *No SPKL:* ${spklNomor ?? '-'}
👤 *Pengawas:* $pengawasNama
🏢 *Fungsi:* ${fungsi?.toUpperCase() ?? '-'}
📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu
📍 *Lokasi:* $lokasi

━━━━━━━━━━━━━━━━━━━
⚠️ *Wajib:* Lakukan absensi sebelum dan sesudah lembur
━━━━━━━━━━━━━━━━━━━

🔗 Lihat SPKL di aplikasi:
$_baseUrl/spkl/$groupId

Terima kasih.
''';
  }

  String _buildAbsensiReminderWaMessage({
    required String recipientName,
    required bool isCheckIn,
    required String tanggal,
    required String waktu,
    required String groupId,
  }) {
    return '''
${isCheckIn ? '📸' : '📸'} *${isCheckIn ? 'ABSEN MASUK' : 'ABSEN PULANG'}*
━━━━━━━━━━━━━━━━━━━

Halo *$recipientName*,

${isCheckIn ? 'Waktunya absen masuk lembur!' : 'Waktunya absen pulang lembur!'}

📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu

Jangan lupa upload foto sebagai bukti absensi ya!

🔗 Buka aplikasi:
$_baseUrl/absen/$groupId

Terima kasih.
''';
  }

  String _buildSpklReadyWaMessage({
    required String recipientName,
    required String spklNomor,
    required String tanggal,
    required String waktu,
    required String lokasi,
    required String groupId,
  }) {
    return '''
📄 *SPKL LEMBUR SIAP*
━━━━━━━━━━━━━━━━━━━

Halo *$recipientName*,

SPKL untuk jadwal lembur kamu sudah siap!

📄 *No SPKL:* $spklNomor
📅 *Tanggal:* $tanggal
⏰ *Waktu:* $waktu
📍 *Lokasi:* $lokasi

🔗 Lihat SPKL di aplikasi:
$_baseUrl/spkl/$groupId

Terima kasih.
''';
  }
}