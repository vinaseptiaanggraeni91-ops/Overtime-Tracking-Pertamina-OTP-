// lib/core/services/pengawas_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'notification_service.dart';

var logger = Logger();

class PengawasService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notifService = NotificationService();

  // ==================== SESSION ====================
  String generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  // ==================== HELPERS ====================
  String formatNumber(int number) {
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '--';
    DateTime time;
    if (timestamp is Timestamp) time = timestamp.toDate();
    else if (timestamp is DateTime) time = timestamp;
    else return '--';
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} bln';
    if (diff.inDays > 0) return '${diff.inDays} hr';
    if (diff.inHours > 0) return '${diff.inHours} jam';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mnt';
    return 'br saja';
  }

  Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
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

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'approved':
      case 'check_in':
      case 'normal':
        return Colors.green;
      case 'pending':
      case 'warning':
        return Colors.orange;
      case 'ditolak':
      case 'rejected':
      case 'darurat':
        return Colors.red;
      case 'check_out':
      case 'selesai':
        return Colors.blue;
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

  // ==================== FIELD EXTRACTION HELPERS ====================
  String _extractFullName(Map<String, dynamic> data) {
    return (data['nama_lengkap']?.toString() ?? '')
        .isNotEmpty
        ? data['nama_lengkap']!.toString()
        : (data['nama']?.toString() ?? '')
            .isNotEmpty
            ? data['nama']!.toString()
            : (data['name']?.toString() ?? '')
                .isNotEmpty
                ? data['name']!.toString()
                : (data['display_name']?.toString() ?? '')
                    .isNotEmpty
                    ? data['display_name']!.toString()
                    : (data['displayName']?.toString() ?? '')
                        .isNotEmpty
                        ? data['displayName']!.toString()
                        : (data['full_name']?.toString() ?? '')
                            .isNotEmpty
                            ? data['full_name']!.toString()
                            : (data['fullName']?.toString() ?? '')
                                .isNotEmpty
                                ? data['fullName']!.toString()
                                : 'Unknown';
  }

  String _extractEmail(Map<String, dynamic> data) {
    return (data['email']?.toString() ?? '')
        .isNotEmpty
        ? data['email']!.toString()
        : (data['email_address']?.toString() ?? '')
            .isNotEmpty
            ? data['email_address']!.toString()
            : (data['user_email']?.toString() ?? '')
                .isNotEmpty
                ? data['user_email']!.toString()
                : '-';
  }

  String _extractPhone(Map<String, dynamic> data) {
    return (data['phone']?.toString() ?? '')
        .isNotEmpty
        ? data['phone']!.toString()
        : (data['phone_number']?.toString() ?? '')
            .isNotEmpty
            ? data['phone_number']!.toString()
            : (data['no_hp']?.toString() ?? '')
                .isNotEmpty
                ? data['no_hp']!.toString()
                : (data['telepon']?.toString() ?? '')
                    .isNotEmpty
                    ? data['telepon']!.toString()
                    : (data['whatsapp']?.toString() ?? '')
                        .isNotEmpty
                        ? data['whatsapp']!.toString()
                        : '-';
  }

  String _extractRole(Map<String, dynamic> data) {
    return (data['role']?.toString() ?? '')
        .isNotEmpty
        ? data['role']!.toString()
        : (data['user_role']?.toString() ?? '')
            .isNotEmpty
            ? data['user_role']!.toString()
            : (data['jabatan']?.toString() ?? '')
                .isNotEmpty
                ? data['jabatan']!.toString()
                : (data['position']?.toString() ?? '')
                    .isNotEmpty
                    ? data['position']!.toString()
                    : 'mitra';
  }

  String _extractStatus(Map<String, dynamic> data) {
    return (data['status_akun']?.toString() ?? '')
        .isNotEmpty
        ? data['status_akun']!.toString()
        : (data['status']?.toString() ?? '')
            .isNotEmpty
            ? data['status']!.toString()
            : (data['account_status']?.toString() ?? '')
                .isNotEmpty
                ? data['account_status']!.toString()
                : 'active';
  }

  String? _extractPhotoUrl(Map<String, dynamic> data) {
    return (data['photo_url']?.toString() ?? '')
        .isNotEmpty
        ? data['photo_url']!.toString()
        : (data['photoUrl']?.toString() ?? '')
            .isNotEmpty
            ? data['photoUrl']!.toString()
            : (data['avatar']?.toString() ?? '')
                .isNotEmpty
                ? data['avatar']!.toString()
                : (data['profile_picture']?.toString() ?? '')
                    .isNotEmpty
                    ? data['profile_picture']!.toString()
                    : null;
  }

  bool _extractIsOnline(Map<String, dynamic> data) {
    if (data.containsKey('isOnline')) return data['isOnline'] == true;
    if (data.containsKey('is_online')) return data['is_online'] == true;
    if (data.containsKey('online')) return data['online'] == true;
    if (data.containsKey('status_online')) return data['status_online'] == true;
    return false;
  }

  String _extractFungsi(Map<String, dynamic> data, String defaultFungsi) {
    return (data['fungsi']?.toString() ?? '')
        .isNotEmpty
        ? data['fungsi']!.toString()
        : (data['department']?.toString() ?? '')
            .isNotEmpty
            ? data['department']!.toString()
            : (data['divisi']?.toString() ?? '')
                .isNotEmpty
                ? data['divisi']!.toString()
                : defaultFungsi;
  }

  double _extractTotalLembur(Map<String, dynamic> data) {
    if (data.containsKey('totalLemburBulanIni')) {
      return (data['totalLemburBulanIni'] ?? 0).toDouble();
    }
    if (data.containsKey('total_lembur_bulanan')) {
      return (data['total_lembur_bulanan'] ?? 0).toDouble();
    }
    if (data.containsKey('total_lembur_bulan_ini')) {
      return (data['total_lembur_bulan_ini'] ?? 0).toDouble();
    }
    if (data.containsKey('total_lembur')) {
      return (data['total_lembur'] ?? 0).toDouble();
    }
    if (data.containsKey('overtime_hours')) {
      return (data['overtime_hours'] ?? 0).toDouble();
    }
    if (data.containsKey('total_overtime')) {
      return (data['total_overtime'] ?? 0).toDouble();
    }
    return 0.0;
  }

  Map<String, dynamic>? _extractLastLocation(Map<String, dynamic> data) {
    if (data.containsKey('lastLocation') && data['lastLocation'] != null) {
      return Map<String, dynamic>.from(data['lastLocation']);
    }
    if (data.containsKey('last_location') && data['last_location'] != null) {
      return Map<String, dynamic>.from(data['last_location']);
    }
    if (data.containsKey('current_location') && data['current_location'] != null) {
      return Map<String, dynamic>.from(data['current_location']);
    }
    final lat = data['latitude'] ?? data['lat'];
    final lng = data['longitude'] ?? data['lng'];
    if (lat != null && lng != null) {
      return {
        'latitude': lat,
        'longitude': lng,
        'address': data['address'] ?? data['alamat'] ?? '',
        'timestamp': data['location_timestamp'] ?? data['last_update'] ?? DateTime.now().toIso8601String(),
      };
    }
    return null;
  }

  // ==================== DASHBOARD DATA (REAL DATA - OPTIMIZED) ====================
  Future<PengawasDashboardData> loadDashboardData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    logger.i('🔄 Loading dashboard data for user: ${user.uid}');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User not found');
    final userData = userDoc.data()!;
    userData['uid'] = user.uid;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfMonth = DateTime(today.year, today.month, 1);

    logger.i('📅 Period: Day=$startOfDay, Week=$startOfWeek, Month=$startOfMonth');

    final fungsi = _extractFungsi(userData, 'operation');
    logger.i('🏢 Fungsi pengawas: $fungsi');

    // ==================== QUERY LEMBUR - OPTIMIZED ====================
    final myLemburSnapshot = await _firestore
        .collection('lembur_mitra')
        .where('diajukan_oleh_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .limit(200)
        .get();

    final teamPendingSnapshot = await _firestore
        .collection('lembur_mitra')
        .where('fungsi', isEqualTo: fungsi)
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .limit(50)
        .get();

    logger.i('📊 Lembur pribadi: ${myLemburSnapshot.docs.length} docs');
    logger.i('📊 Pending tim: ${teamPendingSnapshot.docs.length} docs');

    // ==================== PROCESS LEMBUR DATA ====================
    List<Map<String, dynamic>> pending = [];
    List<Map<String, dynamic>> recent = [];
    int todayCount = 0;
    int weekCount = 0;
    int monthCount = 0;
    int todayPendingCount = 0;
    int todayApprovedCount = 0;  // 🔥 NEW
    int rejectedCount = 0;        // 🔥 NEW
    Map<String, dynamic>? activeLembur;
    
    final Set<String> processedIds = {};

    // Process lembur pribadi
    for (var doc in myLemburSnapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      processedIds.add(doc.id);

      final tanggal = (data['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now();
      final createdAt = (data['created_at'] as Timestamp?)?.toDate();
      final approvedAt = (data['approved_at'] as Timestamp?)?.toDate();
      final status = (data['status'] ?? 'pending').toString().toLowerCase();

      // Hitung approved
      if (status == 'disetujui' || status == 'approved') {
        if (tanggal.isAfter(startOfDay) || DateUtils.isSameDay(tanggal, startOfDay)) {
          todayCount++;
        }
        if (tanggal.isAfter(startOfWeek) || DateUtils.isSameDay(tanggal, startOfWeek)) {
          weekCount++;
        }
        if (tanggal.isAfter(startOfMonth) || DateUtils.isSameDay(tanggal, startOfMonth)) {
          monthCount++;
        }
        
        // 🔥 NEW: Disetujui hari ini
        if (approvedAt != null && 
            (approvedAt.isAfter(startOfDay) || DateUtils.isSameDay(approvedAt, startOfDay))) {
          todayApprovedCount++;
        }
      }

      // Pending
      if (status == 'pending') {
        pending.add(data);
        if (createdAt != null && 
            (createdAt.isAfter(startOfDay) || DateUtils.isSameDay(createdAt, startOfDay))) {
          todayPendingCount++;
        }
      } else {
        recent.add(data);
      }

      // 🔥 NEW: Ditolak
      if (status == 'ditolak' || status == 'rejected') {
        rejectedCount++;
      }

      // Active lembur
      if ((status == 'disetujui' || status == 'approved') &&
          data['check_in'] != null &&
          data['check_out'] == null) {
        activeLembur = data;
      }
    }

    // Process pending tim
    for (var doc in teamPendingSnapshot.docs) {
      if (processedIds.contains(doc.id)) continue;
      
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      
      final createdAt = (data['created_at'] as Timestamp?)?.toDate();
      
      pending.add(data);
      
      if (createdAt != null && 
          (createdAt.isAfter(startOfDay) || DateUtils.isSameDay(createdAt, startOfDay))) {
        todayPendingCount++;
      }
    }

    logger.i('✅ Lembur - Today: $todayCount | Week: $weekCount | Month: $monthCount');
    logger.i('✅ Pending: ${pending.length} total, $todayPendingCount today');
    logger.i('✅ Today Approved: $todayApprovedCount | Rejected: $rejectedCount');

    // ==================== TEAM MEMBERS ====================
    final teamSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'mitra')
        .where('fungsi', isEqualTo: fungsi)
        .limit(50)
        .get();

    final teamMembers = teamSnapshot.docs.map((doc) {
      final d = doc.data();
      return {
        'id': doc.id,
        'nama_lengkap': _extractFullName(d),
        'nama': _extractFullName(d),
        'role': _extractRole(d),
        'email': _extractEmail(d),
        'phone': _extractPhone(d),
        'status': _extractStatus(d),
        'isOnline': _extractIsOnline(d),
        'lastLocation': _extractLastLocation(d),
        'fungsi': _extractFungsi(d, fungsi),
        'totalLembur': _extractTotalLembur(d),
        'photo_url': _extractPhotoUrl(d),
      };
    }).toList();

    final onlineMembers = teamMembers.where((m) => m['isOnline'] == true).length;

    // ==================== UNREAD NOTIFICATIONS ====================
    final int unreadNotifications = await _notifService.getUnreadCount(user.uid);

    // ==================== RECENT ACTIVITIES ====================
    List<Map<String, dynamic>> activities = [];
    try {
      final logSnapshot = await _firestore
          .collection('system_logs')
          .where('target_user', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      activities.addAll(logSnapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'type': d['type'] ?? 'system',
          'description': d['description'] ?? '',
          'timestamp': (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'user': d['user'] ?? 'System',
          'userRole': 'system',
        };
      }).toList());
    } catch (e) {
      logger.w('⚠️ Error loading system_logs: $e');
    }

    try {
      final activitySnapshot = await _firestore
          .collection('activity_logs')
          .where('user', isEqualTo: user.email)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
      activities.addAll(activitySnapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'type': d['action'] ?? 'activity',
          'description': d['description'] ?? '',
          'timestamp': (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'user': d['user'] ?? 'System',
          'userRole': d['role'] ?? 'system',
        };
      }).toList());
    } catch (e) {
      logger.w('⚠️ Error loading activity_logs: $e');
    }

    activities.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    activities = activities.take(15).toList();

    // ==================== SYSTEM HEALTH ====================
    Map<String, dynamic> systemHealth = {};
    try {
      final healthDoc = await _firestore.collection('health_check').doc('current').get();
      if (healthDoc.exists) {
        systemHealth = Map<String, dynamic>.from(healthDoc.data()!);
      }
    } catch (e) {
      logger.w('⚠️ Error loading health_check: $e');
    }

    // ==================== LOCATIONS ====================
    List<Map<String, dynamic>> locations = [];
    try {
      final locSnapshot = await _firestore.collection('live_locations').limit(50).get();
      locations = locSnapshot.docs.map((doc) {
        final d = doc.data();
        double lat = 0, lng = 0;
        final geo = d['coordinates'];
        if (geo is GeoPoint) {
          lat = geo.latitude;
          lng = geo.longitude;
        } else {
          lat = (d['latitude'] as num?)?.toDouble() ?? 0;
          lng = (d['longitude'] as num?)?.toDouble() ?? 0;
        }
        
        return {
          'id': doc.id,
          'name': d['user_name'] ?? d['name'] ?? 'Unknown',
          'lat': lat,
          'lng': lng,
          'status': d['status'] ?? 'Normal',
          'color': getStatusColor(d['status'] ?? 'Normal'),
          'address': d['address'] ?? '',
          'workers': d['workers'] ?? 1,
          'battery': d['battery'] ?? 100,
          'signal': d['signal'] ?? '--',
          'lastUpdate': (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      logger.w('⚠️ Error loading locations: $e');
    }

    // ==================== FINAL LOG SUMMARY ====================
    logger.i('========================================');
    logger.i('=== 📊 DASHBOARD DATA LOADED ===');
    logger.i('========================================');
    logger.i('👤 User: ${_extractFullName(userData)} (${user.email})');
    logger.i('🏢 Fungsi: $fungsi');
    logger.i('👥 Team: ${teamMembers.length} total, $onlineMembers online');
    logger.i('📋 Lembur Today: $todayCount | Week: $weekCount | Month: $monthCount');
    logger.i('✅ Today Approved: $todayApprovedCount');
    logger.i('❌ Rejected: $rejectedCount');
    logger.i('⏳ Pending: ${pending.length} total, $todayPendingCount today');
    logger.i('🔴 Active Lembur: ${activeLembur != null ? "YES" : "NO"}');
    logger.i('🔔 Unread Notifications: $unreadNotifications');
    logger.i('========================================');

    return PengawasDashboardData(
      userData: userData,
      fungsi: fungsi,
      pendingList: pending,
      recentList: recent.take(10).toList(),
      activeLembur: activeLembur,
      totalLemburToday: todayCount,
      totalLemburWeek: weekCount,
      totalLemburMonth: monthCount,
      pendingApproval: pending.length,
      todayPending: todayPendingCount,
      todayApproved: todayApprovedCount,  // 🔥 NEW
      rejected: rejectedCount,            // 🔥 NEW
      teamMembers: teamMembers,
      onlineMembers: onlineMembers,
      totalTeamMembers: teamMembers.length,
      unreadNotifications: unreadNotifications,
      recentActivities: activities,
      systemHealth: systemHealth,
      locations: locations,
    );
  }

  // ==================== NOTIFICATIONS ====================
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    return _notifService.getNotificationsOnce(user.uid);
  }

  Future<void> markAllNotificationsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _notifService.markAllAsRead(user.uid);
  }

  Future<void> markNotificationRead(String notifId) async {
    await _notifService.markAllAsRead(notifId);
  }

  // ==================== LEMBUR ACTIONS ====================
  Future<void> cancelLembur(String lemburId) async {
    await _firestore.collection('lembur_mitra').doc(lemburId).update({
      'status': 'dibatalkan',
      'updated_at': FieldValue.serverTimestamp(),
    });
    await logActivity('cancel_lembur', 'Membatalkan lembur $lemburId');
  }

  Future<void> checkIn(String lemburId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('lembur_mitra').doc(lemburId).update({
      'check_in': FieldValue.serverTimestamp(),
      'absensi_status': 'check_in',
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': true,
      'lastActive': FieldValue.serverTimestamp(),
    });

    await logActivity('check_in', 'Check-in lembur $lemburId');
  }

  Future<void> checkOut(String lemburId, double totalJam) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('lembur_mitra').doc(lemburId).update({
      'check_out': FieldValue.serverTimestamp(),
      'total_jam_real': totalJam,
      'absensi_status': 'check_out',
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': false,
      'lastActive': FieldValue.serverTimestamp(),
    });

    await logActivity('check_out', 'Check-out lembur $lemburId, total $totalJam jam');
  }

  // ==================== ACTIVITY LOGGING ====================
  Future<void> logActivity(String type, String description) async {
    final sessionId = generateSessionId();
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('system_logs').add({
        'type': type,
        'user': user.email,
        'target_user': user.uid,
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': description,
      });

      await _firestore.collection('activity_logs').add({
        'action': type,
        'user': user.email,
        'role': 'pengawas',
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'session_id': sessionId,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  // ==================== AUTH & PROFILE ====================
  Future<void> logout() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': false,
          'lastActive': FieldValue.serverTimestamp(),
        });
        await logActivity('logout', 'Pengawas logout');
      } catch (_) {}
    }
    await _auth.signOut();
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) throw Exception('User not found');
    return doc.data()!;
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      ...updates,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await logActivity('update_profile', 'Update profil');
  }

  // ==================== LOCATIONS ====================
  Future<List<Map<String, dynamic>>> getLocations() async {
    try {
      final snapshot = await _firestore.collection('live_locations').limit(50).get();
      return snapshot.docs.map((doc) {
        final d = doc.data();
        double lat = 0, lng = 0;
        final geo = d['coordinates'];
        if (geo is GeoPoint) {
          lat = geo.latitude;
          lng = geo.longitude;
        } else {
          lat = (d['latitude'] as num?)?.toDouble() ?? 0;
          lng = (d['longitude'] as num?)?.toDouble() ?? 0;
        }
        
        return {
          'id': doc.id,
          'name': d['user_name'] ?? d['name'] ?? 'Unknown',
          'lat': lat,
          'lng': lng,
          'status': d['status'] ?? 'Normal',
          'color': getStatusColor(d['status'] ?? 'Normal'),
          'address': d['address'] ?? '',
          'workers': d['workers'] ?? 1,
          'battery': d['battery'] ?? 100,
          'signal': d['signal'] ?? '--',
          'lastUpdate': (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      logger.e('Error get locations: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final doc = await _firestore.collection('health_check').doc('current').get();
      if (doc.exists) return doc.data()!;
    } catch (_) {}
    return {};
  }

  Future<List<Map<String, dynamic>>> getFAQ() async {
    try {
      final snapshot = await _firestore.collection('faq').orderBy('createdAt').limit(20).get();
      return snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'question': d['question'] ?? '',
          'answer': d['answer'] ?? '',
          'category': d['category'] ?? 'Umum',
        };
      }).toList();
    } catch (e) {
      logger.e('Error get FAQ: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getOvertimeSettings() async {
    try {
      final doc = await _firestore
          .collection('system_settings')
          .doc('lembur_config')
          .get();
      if (doc.exists) return doc.data()!;
    } catch (_) {}
    return {};
  }

  // ==================== GREETING & PROFILE ====================
  Future<String> getGreetingWithNameAndEmoji() async {
    final user = _auth.currentUser;
    if (user == null) return '${getGreeting()}! 👋';
    final profile = await getUserProfile();
    final name = _extractFullName(profile) != 'Unknown'
        ? _extractFullName(profile)
        : user.displayName ?? user.email?.split('@')[0] ?? 'Pengawas';
    return '${getGreeting()}, $name! ${getGreetingEmoji()}';
  }

  Future<String> getGreetingMotivation() async {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Semoga aktivitas pengawasanmu lancar hari ini! ☀️';
    if (hour < 15) return 'Tetap semangat mengawasi tim, ya! 💪';
    if (hour < 18) return 'Sore yang produktif untuk memonitor lembur. 🌆';
    return 'Jaga kesehatan, awasi tim dengan bijak malam ini. 🌙';
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'nama_lengkap': _extractFullName(data),
          'role': _extractRole(data),
          'photo_url': _extractPhotoUrl(data),
          'email': _extractEmail(data),
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ==================== KIRIM PESAN KE MANAGER ====================
  Future<void> sendMessageToManager(String message) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userData = await getUserProfile();
    final fungsi = _extractFungsi(userData, 'operation');

    final managerSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'manager')
        .where('fungsi', isEqualTo: fungsi)
        .where('status_akun', isEqualTo: 'active')
        .limit(1)
        .get();

    for (var doc in managerSnapshot.docs) {
      await _notifService.sendGeneralNotification(
        userId: doc.id,
        title: 'Pesan dari ${_extractFullName(userData)}',
        message: message,
        data: {
          'sender_id': user.uid,
          'sender_name': _extractFullName(userData),
          'sender_role': 'pengawas',
          'fungsi': fungsi,
        },
      );
    }
  }
}

// ==================== DATA CLASS ====================
class PengawasDashboardData {
  final Map<String, dynamic> userData;
  final String fungsi;
  final List<Map<String, dynamic>> pendingList;
  final List<Map<String, dynamic>> recentList;
  final Map<String, dynamic>? activeLembur;
  final int totalLemburToday;
  final int totalLemburWeek;
  final int totalLemburMonth;
  final int pendingApproval;
  final int todayPending;
  final int todayApproved;   // 🔥 NEW
  final int rejected;         // 🔥 NEW
  final List<Map<String, dynamic>> teamMembers;
  final int onlineMembers;
  final int totalTeamMembers;
  final int unreadNotifications;
  final List<Map<String, dynamic>> recentActivities;
  final Map<String, dynamic> systemHealth;
  final List<Map<String, dynamic>> locations;

  PengawasDashboardData({
    required this.userData,
    required this.fungsi,
    required this.pendingList,
    required this.recentList,
    this.activeLembur,
    required this.totalLemburToday,
    required this.totalLemburWeek,
    required this.totalLemburMonth,
    required this.pendingApproval,
    required this.todayPending,
    required this.todayApproved,  // 🔥 NEW
    required this.rejected,        // 🔥 NEW
    required this.teamMembers,
    required this.onlineMembers,
    required this.totalTeamMembers,
    required this.unreadNotifications,
    required this.recentActivities,
    this.systemHealth = const {},
    this.locations = const [],
  });

  bool get isCheckedIn => activeLembur != null;
  bool get hasPendingApprovals => pendingApproval > 0;
  bool get hasTodayPending => todayPending > 0;
  bool get hasActiveLembur => activeLembur != null;
  bool get hasRejected => rejected > 0;
  int get totalLemburBulanIni => totalLemburMonth;
}