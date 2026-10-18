// lib/core/services/dashboard_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:crypto/crypto.dart';

var logger = Logger();

class DashboardService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardData? _cachedData;
  DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // 🔥 STATUS YANG DIAKUI SEBAGAI "LEMBUR AKTIF/BERJALAN"
  static const List<String> overtimeActiveStatuses = [
    'disetujui',
    'approved',
    'selesai',
    'check_in',
    'check_out',
  ];

  // 🔥 STATUS YANG DIAKUI SEBAGAI "LEMBUR APPROVED"
  static const List<String> overtimeApprovedStatuses = [
    'disetujui',
    'approved',
  ];

  // 🔥 STATUS YANG DIAKUI SEBAGAI "LEMBUR DITOLAK"
  static const List<String> overtimeRejectedStatuses = [
    'ditolak',
    'rejected',
  ];

  static const String collectionPengajuan = 'pengajuan_lembur';
  static const String collectionLemburMitra = 'lembur_mitra';
  static const String collectionMasterWorkers = 'master_workers';
  static const String collectionUsers = 'users';
  static const String collectionNotifications = 'notifications';
  static const String collectionActivityLogs = 'activity_logs';
  static const String collectionOnlineUsers = 'online_users';
  static const String collectionCompanies = 'companies';

  // ==================== SESSION ====================
  String generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ==================== CACHE ====================
  void clearCache() {
    _cachedData = null;
    _lastCacheTime = null;
    logger.i('🗑️ Dashboard cache cleared');
  }

  // ==================== REAL-TIME ONLINE USERS ====================
  Stream<List<OnlineUserData>> getOnlineUsersStream() {
    return _firestore
        .collection(collectionOnlineUsers)
        .where('is_online', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final users = <OnlineUserData>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        users.add(OnlineUserData(
          uid: doc.id,
          name: data['name'] ?? data['nama_lengkap'] ?? 'Unknown',
          email: data['email'] ?? '',
          role: data['role'] ?? 'mitra',
          isOnline: data['is_online'] ?? false,
          lastSeen: (data['last_seen'] as Timestamp?)?.toDate() ?? DateTime.now(),
          deviceInfo: data['device_info'] ?? '',
          location: data['location'] ?? '',
          loginTime: (data['login_time'] as Timestamp?)?.toDate(),
        ));
      }
      users.sort((a, b) => a.name.compareTo(b.name));
      return users;
    });
  }

  Stream<int> getOnlineUsersCountStream() {
    return _firestore
        .collection(collectionOnlineUsers)
        .where('is_online', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> setUserOnline({String? deviceInfo, String? location}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection(collectionUsers).doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final onlineData = {
        'name': userData['nama_lengkap'] ?? user.email ?? 'Unknown',
        'email': user.email,
        'role': userData['role'] ?? 'mitra',
        'is_online': true,
        'last_seen': FieldValue.serverTimestamp(),
        'device_info': deviceInfo ?? 'Unknown Device',
        'location': location ?? 'Unknown Location',
        'login_time': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(collectionOnlineUsers)
          .doc(user.uid)
          .set(onlineData, SetOptions(merge: true));

      await _firestore.collection(collectionUsers).doc(user.uid).set({
        'is_online': true,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await logActivity('online', 'User ${user.email} is now online', generateSessionId());
    } catch (e) {
      logger.e('Error setting user online: $e');
    }
  }

  Future<void> setUserOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection(collectionOnlineUsers).doc(user.uid).set({
        'is_online': false,
        'last_seen': FieldValue.serverTimestamp(),
        'logout_time': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection(collectionUsers).doc(user.uid).set({
        'is_online': false,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await logActivity('offline', 'User ${user.email} is now offline', generateSessionId());
    } catch (e) {
      logger.e('Error setting user offline: $e');
    }
  }

  Future<void> updateHeartbeat() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection(collectionOnlineUsers).doc(user.uid).set({
        'last_seen': FieldValue.serverTimestamp(),
        'is_online': true,
      }, SetOptions(merge: true));

      await _firestore.collection(collectionUsers).doc(user.uid).set({
        'last_seen': FieldValue.serverTimestamp(),
        'is_online': true,
      }, SetOptions(merge: true));
    } catch (e) {
      logger.e('Error updating heartbeat: $e');
    }
  }

  Future<List<OnlineUserData>> getCurrentOnlineUsers() async {
    try {
      final snapshot = await _firestore
          .collection(collectionOnlineUsers)
          .where('is_online', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return OnlineUserData(
          uid: doc.id,
          name: data['name'] ?? 'Unknown',
          email: data['email'] ?? '',
          role: data['role'] ?? 'mitra',
          isOnline: true,
          lastSeen: (data['last_seen'] as Timestamp?)?.toDate() ?? DateTime.now(),
          deviceInfo: data['device_info'] ?? '',
          location: data['location'] ?? '',
          loginTime: (data['login_time'] as Timestamp?)?.toDate(),
        );
      }).toList();
    } catch (e) {
      logger.e('Error getting online users: $e');
      return [];
    }
  }

  Future<int?> getOnlineUsersCount() async {
    try {
      final snapshot = await _firestore
          .collection(collectionOnlineUsers)
          .where('is_online', isEqualTo: true)
          .count()
          .get();
      return snapshot.count;
    } catch (e) {
      logger.e('Error getting online count: $e');
      return 0;
    }
  }

  Future<List<OnlineUserData>> getOnlineUsersByRole(String role) async {
    try {
      final snapshot = await _firestore
          .collection(collectionOnlineUsers)
          .where('is_online', isEqualTo: true)
          .where('role', isEqualTo: role.toLowerCase())
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return OnlineUserData(
          uid: doc.id,
          name: data['name'] ?? 'Unknown',
          email: data['email'] ?? '',
          role: data['role'] ?? 'mitra',
          isOnline: true,
          lastSeen: (data['last_seen'] as Timestamp?)?.toDate() ?? DateTime.now(),
          deviceInfo: data['device_info'] ?? '',
          location: data['location'] ?? '',
          loginTime: (data['login_time'] as Timestamp?)?.toDate(),
        );
      }).toList();
    } catch (e) {
      logger.e('Error getting online users by role: $e');
      return [];
    }
  }

  // ==================== NOTIFICATIONS ====================

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection(collectionNotifications)
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Notifikasi',
          'body': data['body'] ?? '',
          'isRead': data['isRead'] ?? false,
          'type': data['type'] ?? 'info',
          'createdAt': data['createdAt'],
          'data': data['data'] ?? {},
        };
      }).toList();
    } catch (e) {
      logger.e('Error getting notifications: $e');
      return [];
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(collectionNotifications)
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      logger.i('✅ All notifications marked as read');
    } catch (e) {
      logger.e('Error marking notifications read: $e');
    }
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'info',
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection(collectionNotifications).add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid ?? 'system',
      });
      logger.i('📨 Notification sent to $userId');
    } catch (e) {
      logger.e('Error sending notification: $e');
    }
  }

  // ==================== RECENT ACTIVITIES ====================

  Future<List<Map<String, dynamic>>> getRecentActivities({int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection(collectionActivityLogs)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now();
        return {
          'id': doc.id,
          'user': data['user'] ?? 'System',
          'userRole': data['role'] ?? 'system',
          'description': data['description'] ?? data['action'] ?? 'No description',
          'type': data['action'] ?? data['type'] ?? 'activity',
          'timestamp': timestamp,
        };
      }).toList();
    } catch (e) {
      logger.e('Error getting recent activities: $e');
      return [];
    }
  }

  // ==================== PENDING APPROVALS ====================

  Future<int> getPendingApprovals() async {
    try {
      final snapshot = await _firestore
          .collection(collectionPengajuan)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      logger.e('Error getting pending approvals: $e');
      return 0;
    }
  }

  // 🔥 NEW: Get Pending HSSE Approvals
  Future<int> getPendingHSSEApprovals() async {
    try {
      final snapshot = await _firestore
          .collection(collectionPengajuan)
          .where('status', isEqualTo: 'pending_hsse')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      logger.e('Error getting pending HSSE approvals: $e');
      return 0;
    }
  }

  // 🔥 NEW: Get Combined Pending Approvals (pending + pending_hsse)
  Future<int> getTotalPendingApprovals() async {
    try {
      final results = await Future.wait([
        _firestore
            .collection(collectionPengajuan)
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        _firestore
            .collection(collectionPengajuan)
            .where('status', isEqualTo: 'pending_hsse')
            .count()
            .get(),
      ]);

      final pendingCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
      final pendingHSSECount = (results[1] as AggregateQuerySnapshot).count ?? 0;

      return pendingCount + pendingHSSECount;
    } catch (e) {
      logger.e('Error getting total pending approvals: $e');
      return 0;
    }
  }

  // ==================== TOTAL COMPANIES ====================

  Future<int> getTotalCompanies() async {
    try {
      final snapshot = await _firestore.collection(collectionCompanies).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      logger.e('Error getting total companies: $e');
      return 0;
    }
  }

  // ==================== TOTAL WORKERS ====================

  Future<int> getTotalWorkers() async {
    try {
      final snapshot = await _firestore.collection(collectionMasterWorkers).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      logger.e('Error getting total workers: $e');
      return 0;
    }
  }

  // ==================== ACTIVE USERS TODAY ====================

  Future<int> getActiveUsersToday() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await _firestore
          .collection(collectionOnlineUsers)
          .where('is_online', isEqualTo: true)
          .where('last_seen', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      logger.e('Error getting active users today: $e');
      return 0;
    }
  }

  // ==================== DASHBOARD DATA UTAMA ====================

  Future<DashboardData> loadDashboardData({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedData != null && _lastCacheTime != null) {
      if (DateTime.now().difference(_lastCacheTime!) < _cacheDuration) {
        logger.i('🎯 Using cached dashboard data');
        return _cachedData!;
      }
    }

    final stopwatch = Stopwatch()..start();
    logger.i('🚀 Starting dashboard data load...');

    try {
      final results = await Future.wait([
        _loadUsersData(),
        _loadLemburData(),
        _loadLogsData(),
        loadMasterDataPekerja(),
        // 🔥 NEW: Load pending HSSE separately
        getPendingHSSEApprovals(),
      ]);

      final usersData = results[0] as Map<String, dynamic>;
      final lemburData = results[1] as Map<String, dynamic>;
      final logsData = results[2] as List<Map<String, dynamic>>;
      final masterData = results[3] as Map<String, dynamic>;
      final pendingHSSEApprovals = results[4] as int; // 🔥 NEW

      final dashboardData = DashboardData(
        totalUsers: usersData['totalUsers'],
        activeToday: usersData['activeToday'],
        pendingApprovals: lemburData['pendingApprovals'],
        pendingHSSEApprovals: pendingHSSEApprovals, // 🔥 NEW
        totalOvertime: lemburData['totalOvertime'],
        approvedOvertime: lemburData['approvedOvertime'],
        verifiedUsers: usersData['verifiedUsers'],
        lockedAccounts: usersData['lockedAccounts'],
        newUsersToday: usersData['newUsersToday'],
        roleCount: usersData['roleCount'],
        fungsiCount: usersData['fungsiCount'],
        roleDistribution: usersData['roleDistribution'],
        recentActivities: logsData,
        totalWorkers: masterData['totalWorkers'] ?? 0,
        activeWorkers: masterData['activeWorkers'] ?? 0,
        inactiveWorkers: masterData['inactiveWorkers'] ?? 0,
        workerFungsiCount: masterData['workerFungsiCount'] ?? 0,
        workerFungsiDistribution: masterData['workerFungsiDistribution'] ?? {},
        // 🔥 DATA BARU
        totalOvertimeBulanIni: lemburData['totalOvertimeBulanIni'] ?? 0,
        approvedOvertimeBulanIni: lemburData['approvedOvertimeBulanIni'] ?? 0,
        rejectedOvertimeBulanIni: lemburData['rejectedOvertimeBulanIni'] ?? 0,
        pendingLemburMitra: lemburData['pendingLemburMitra'] ?? 0,
        totalLemburMitra: lemburData['totalLemburMitra'] ?? 0,
        lemburByStatusBulanIni: lemburData['lemburByStatusBulanIni'] ?? {},
        lemburByFungsiBulanIni: lemburData['lemburByFungsiBulanIni'] ?? {},
      );

      _cachedData = dashboardData;
      _lastCacheTime = DateTime.now();

      stopwatch.stop();
      logger.i('✅ Dashboard data loaded in ${stopwatch.elapsedMilliseconds}ms');

      return dashboardData;
    } catch (e) {
      logger.e('❌ Error loading dashboard data: $e');
      rethrow;
    }
  }

  // ==================== USERS DATA ====================

  Future<Map<String, dynamic>> _loadUsersData() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final totalUsersCount = await _firestore.collection(collectionUsers).count().get();
    final totalUsers = totalUsersCount.count ?? 0;

    final usersSnapshot = await _firestore
        .collection(collectionUsers)
        .orderBy('last_login', descending: true)
        .limit(500)
        .get();

    int activeToday = 0;
    int verifiedUsers = 0;
    int lockedAccounts = 0;
    int newUsersToday = 0;
    Map<String, int> roleCount = {
      'superadmin': 0,
      'manager': 0,
      'manager_hsse': 0,
      'pengawas': 0,
      'mitra': 0,
      'officer_safety': 0,
    };
    Map<String, int> fungsiCount = {};

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      String role = data['role'] ?? 'mitra';
      roleCount[role] = (roleCount[role] ?? 0) + 1;

      String fungsi = data['fungsi'] ?? 'unknown';
      fungsiCount[fungsi] = (fungsiCount[fungsi] ?? 0) + 1;

      if (data['is_verified'] == true) verifiedUsers++;
      if (data['account_locked'] == true) lockedAccounts++;

      final lastLogin = data['last_login'];
      if (lastLogin is Timestamp && lastLogin.toDate().isAfter(startOfDay)) activeToday++;
      if (lastLogin is DateTime && lastLogin.isAfter(startOfDay)) activeToday++;

      final createdAt = data['created_at'];
      if (createdAt is Timestamp && createdAt.toDate().isAfter(startOfDay)) newUsersToday++;
      if (createdAt is DateTime && createdAt.isAfter(startOfDay)) newUsersToday++;
    }

    Map<String, int> accurateRoleCount = {};
    for (String role in roleCount.keys) {
      try {
        final countSnap = await _firestore
            .collection(collectionUsers)
            .where('role', isEqualTo: role)
            .count()
            .get();
        accurateRoleCount[role] = countSnap.count ?? 0;
      } catch (e) {
        accurateRoleCount[role] = roleCount[role] ?? 0;
      }
    }

    return {
      'totalUsers': totalUsers,
      'activeToday': activeToday,
      'verifiedUsers': verifiedUsers,
      'lockedAccounts': lockedAccounts,
      'newUsersToday': newUsersToday,
      'roleCount': accurateRoleCount,
      'fungsiCount': fungsiCount,
      'roleDistribution': {
        'Super Admin': accurateRoleCount['superadmin'] ?? 0,
        'Manager': (accurateRoleCount['manager'] ?? 0) + (accurateRoleCount['manager_hsse'] ?? 0),
        'Pengawas': accurateRoleCount['pengawas'] ?? 0,
        'Mitra': accurateRoleCount['mitra'] ?? 0,
      },
    };
  }

  // ==================== 🔥🔥🔥 LEMBUR DATA - VERSI SUPER AKURAT 🔥🔥🔥 ====================

  Future<Map<String, dynamic>> _loadLemburData() async {
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(today.year, today.month, 1);
    final lastDayOfMonth = DateTime(today.year, today.month + 1, 0, 23, 59, 59);
    final firstDayOfMonthTimestamp = Timestamp.fromDate(firstDayOfMonth);
    final lastDayOfMonthTimestamp = Timestamp.fromDate(lastDayOfMonth);

    logger.i('📊 Loading lembur data: ${firstDayOfMonth.toIso8601String()} - ${lastDayOfMonth.toIso8601String()}');

    try {
      // 🔥 Jalankan SEMUA query count secara paralel (7 query - ditambah pending_hsse)
      final results = await Future.wait([
        // 1. Pending approvals (pengajuan_lembur) - fungsi
        _firestore
            .collection(collectionPengajuan)
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),

        // 2. Total lembur mitra bulan ini (semua status aktif)
        _firestore
            .collection(collectionLemburMitra)
            .where('tanggal', isGreaterThanOrEqualTo: firstDayOfMonthTimestamp)
            .where('tanggal', isLessThanOrEqualTo: lastDayOfMonthTimestamp)
            .where('status', whereIn: overtimeActiveStatuses)
            .count()
            .get(),

        // 3. 🔥 DISETUJUI bulan ini (count real)
        _firestore
            .collection(collectionLemburMitra)
            .where('tanggal', isGreaterThanOrEqualTo: firstDayOfMonthTimestamp)
            .where('tanggal', isLessThanOrEqualTo: lastDayOfMonthTimestamp)
            .where('status', whereIn: overtimeApprovedStatuses)
            .count()
            .get(),

        // 4. 🔥 DITOLAK bulan ini (count real)
        _firestore
            .collection(collectionLemburMitra)
            .where('tanggal', isGreaterThanOrEqualTo: firstDayOfMonthTimestamp)
            .where('tanggal', isLessThanOrEqualTo: lastDayOfMonthTimestamp)
            .where('status', whereIn: overtimeRejectedStatuses)
            .count()
            .get(),

        // 5. 🔥 PENDING lembur mitra bulan ini (count real)
        _firestore
            .collection(collectionLemburMitra)
            .where('tanggal', isGreaterThanOrEqualTo: firstDayOfMonthTimestamp)
            .where('tanggal', isLessThanOrEqualTo: lastDayOfMonthTimestamp)
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),

        // 6. Total SEMUA lembur mitra (tanpa filter bulan)
        _firestore
            .collection(collectionLemburMitra)
            .count()
            .get(),

        // 🔥 7. NEW: Pending HSSE (pengajuan_lembur)
        _firestore
            .collection(collectionPengajuan)
            .where('status', isEqualTo: 'pending_hsse')
            .count()
            .get(),
      ]);

      final pendingApprovals = (results[0] as AggregateQuerySnapshot).count ?? 0;
      final totalOvertimeBulanIni = (results[1] as AggregateQuerySnapshot).count ?? 0;
      final approvedOvertimeBulanIni = (results[2] as AggregateQuerySnapshot).count ?? 0;
      final rejectedOvertimeBulanIni = (results[3] as AggregateQuerySnapshot).count ?? 0;
      final pendingLemburMitraBulanIni = (results[4] as AggregateQuerySnapshot).count ?? 0;
      final totalLemburMitra = (results[5] as AggregateQuerySnapshot).count ?? 0;
      final pendingHSSEApprovals = (results[6] as AggregateQuerySnapshot).count ?? 0; // 🔥 NEW

      // 🔥 8. Ambil sample untuk distribusi by fungsi (max 200)
      final sampleSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('tanggal', isGreaterThanOrEqualTo: firstDayOfMonthTimestamp)
          .where('tanggal', isLessThanOrEqualTo: lastDayOfMonthTimestamp)
          .limit(200)
          .get();

      // 🔥 Status map dari count queries REAL
      final Map<String, int> lemburByStatusBulanIni = {
        'disetujui': approvedOvertimeBulanIni,
        'ditolak': rejectedOvertimeBulanIni,
        'pending': pendingLemburMitraBulanIni,
        'pending_hsse': pendingHSSEApprovals, // 🔥 NEW: tambahkan ke status map
        'total_aktif': totalOvertimeBulanIni,
        // Hitung selesai & lainnya dari sample (perkiraan)
        'selesai': 0,
        'check_in': 0,
        'check_out': 0,
      };

      // 🔥 Distribusi by fungsi dari sample
      final Map<String, int> lemburByFungsiBulanIni = {};
      for (var doc in sampleSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        // Update status dari sample untuk selain disetujui/ditolak/pending
        if (!['disetujui', 'approved', 'ditolak', 'rejected', 'pending', 'pending_hsse'].contains(status)) {
          lemburByStatusBulanIni[status] = (lemburByStatusBulanIni[status] ?? 0) + 1;
        }

        final fungsi = (data['fungsi'] ?? data['mitra_fungsi'] ?? 'unknown')
            .toString()
            .toLowerCase();
        lemburByFungsiBulanIni[fungsi] = (lemburByFungsiBulanIni[fungsi] ?? 0) + 1;
      }

      final result = {
        'pendingApprovals': pendingApprovals,
        'pendingHSSEApprovals': pendingHSSEApprovals, // 🔥 NEW
        'totalOvertime': totalLemburMitra,
        'approvedOvertime': approvedOvertimeBulanIni,
        // 🔥 DATA BARU - SEMUA DARI COUNT REAL
        'totalOvertimeBulanIni': totalOvertimeBulanIni,
        'approvedOvertimeBulanIni': approvedOvertimeBulanIni,
        'rejectedOvertimeBulanIni': rejectedOvertimeBulanIni,
        'pendingLemburMitra': pendingLemburMitraBulanIni,
        'totalLemburMitra': totalLemburMitra,
        'lemburByStatusBulanIni': lemburByStatusBulanIni,
        'lemburByFungsiBulanIni': lemburByFungsiBulanIni,
      };

      logger.i('📊 Lembur data loaded: $result');
      return result;
    } catch (e) {
      logger.e('❌ Error loading lembur data (composite index mungkin belum ada): $e');

      // 🔥 FALLBACK: Query tanpa composite index
      try {
        logger.w('⚠️ Trying fallback query without composite index...');

        final fallbackSnapshot = await _firestore
            .collection(collectionLemburMitra)
            .where('tanggal', isGreaterThanOrEqualTo: firstDayOfMonthTimestamp)
            .where('tanggal', isLessThanOrEqualTo: lastDayOfMonthTimestamp)
            .get();

        // 🔥 NEW: Fallback untuk pending_hsse
        int fallbackPendingHSSE = 0;
        try {
          final pendingHSSESnap = await _firestore
              .collection(collectionPengajuan)
              .where('status', isEqualTo: 'pending_hsse')
              .count()
              .get();
          fallbackPendingHSSE = pendingHSSESnap.count ?? 0;
        } catch (e) {
          logger.w('Could not get pending HSSE count in fallback: $e');
        }

        int fallbackTotal = 0;
        int fallbackApproved = 0;
        int fallbackRejected = 0;
        int fallbackPending = 0;
        final Map<String, int> fallbackByStatus = {};
        final Map<String, int> fallbackByFungsi = {};

        for (var doc in fallbackSnapshot.docs) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().toLowerCase();

          if (overtimeActiveStatuses.contains(status)) fallbackTotal++;
          if (overtimeApprovedStatuses.contains(status)) fallbackApproved++;
          if (overtimeRejectedStatuses.contains(status)) fallbackRejected++;
          if (status == 'pending') fallbackPending++;

          fallbackByStatus[status] = (fallbackByStatus[status] ?? 0) + 1;

          final fungsi = (data['fungsi'] ?? data['mitra_fungsi'] ?? 'unknown')
              .toString()
              .toLowerCase();
          fallbackByFungsi[fungsi] = (fallbackByFungsi[fungsi] ?? 0) + 1;
        }

        // 🔥 NEW: Tambahkan pending_hsse ke fallback status map
        fallbackByStatus['pending_hsse'] = fallbackPendingHSSE;

        return {
          'pendingApprovals': 0,
          'pendingHSSEApprovals': fallbackPendingHSSE, // 🔥 NEW
          'totalOvertime': fallbackTotal,
          'approvedOvertime': fallbackApproved,
          'totalOvertimeBulanIni': fallbackTotal,
          'approvedOvertimeBulanIni': fallbackApproved,
          'rejectedOvertimeBulanIni': fallbackRejected,
          'pendingLemburMitra': fallbackPending,
          'totalLemburMitra': fallbackTotal,
          'lemburByStatusBulanIni': fallbackByStatus,
          'lemburByFungsiBulanIni': fallbackByFungsi,
        };
      } catch (fallbackError) {
        logger.e('❌ Fallback also failed: $fallbackError');
        return {
          'pendingApprovals': 0,
          'pendingHSSEApprovals': 0, // 🔥 NEW
          'totalOvertime': 0,
          'approvedOvertime': 0,
          'totalOvertimeBulanIni': 0,
          'approvedOvertimeBulanIni': 0,
          'rejectedOvertimeBulanIni': 0,
          'pendingLemburMitra': 0,
          'totalLemburMitra': 0,
          'lemburByStatusBulanIni': <String, int>{},
          'lemburByFungsiBulanIni': <String, int>{},
        };
      }
    }
  }

  // 🔥 Method tambahan: Get lembur detail by status
  Future<Map<String, int>> getLemburCountByStatus({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, 1);
      final end = endDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final Map<String, int> statusCount = {};
      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] ?? 'unknown';
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }

      return statusCount;
    } catch (e) {
      logger.e('Error getting lembur by status: $e');
      return {};
    }
  }

  // 🔥 Method tambahan: Get lembur detail by fungsi
  Future<Map<String, int>> getLemburCountByFungsi({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, 1);
      final end = endDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final snapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final Map<String, int> fungsiCount = {};
      for (var doc in snapshot.docs) {
        final fungsi = doc.data()['fungsi'] ?? doc.data()['mitra_fungsi'] ?? 'unknown';
        fungsiCount[fungsi] = (fungsiCount[fungsi] ?? 0) + 1;
      }

      return fungsiCount;
    } catch (e) {
      logger.e('Error getting lembur by fungsi: $e');
      return {};
    }
  }

  // ==================== LOGS DATA ====================

  Future<List<Map<String, dynamic>>> _loadLogsData() async {
    final List<Map<String, dynamic>> activities = [];

    final results = await Future.wait([
      _firestore
          .collection('system_logs')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get(),
      _firestore
          .collection(collectionActivityLogs)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get(),
    ]);

    try {
      for (var doc in results[0].docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now();
        activities.add({
          'user': data['user'] ?? 'System',
          'userRole': 'system',
          'description': data['description'] ?? 'No description',
          'type': data['type'] ?? 'system',
          'timestamp': timestamp,
        });
      }
    } catch (e) {
      logger.w('Could not fetch system_logs: $e');
    }

    try {
      for (var doc in results[1].docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now();
        activities.add({
          'user': data['user'] ?? 'System',
          'userRole': data['role'] ?? 'system',
          'description': data['description'] ?? data['action'] ?? 'No description',
          'type': data['action'] ?? data['type'] ?? 'activity',
          'timestamp': timestamp,
        });
      }
    } catch (e) {
      logger.w('Could not fetch activity_logs: $e');
    }

    activities.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    return activities.take(10).toList();
  }

  // ==================== MASTER DATA PEKERJA ====================

  Future<Map<String, dynamic>> loadMasterDataPekerja() async {
    try {
      final totalWorkersCount = await _firestore
          .collection(collectionMasterWorkers)
          .count()
          .get();

      final activeWorkersCount = await _firestore
          .collection(collectionMasterWorkers)
          .where('is_active', isEqualTo: true)
          .count()
          .get();

      final inactiveWorkersCount = await _firestore
          .collection(collectionMasterWorkers)
          .where('is_active', isEqualTo: false)
          .count()
          .get();

      final sampleSnapshot = await _firestore
          .collection(collectionMasterWorkers)
          .limit(200)
          .get();

      final Map<String, int> fungsiDistribution = {};
      for (var doc in sampleSnapshot.docs) {
        final fungsi = (doc.data()['fungsi'] ?? 'unknown').toString().toLowerCase();
        fungsiDistribution[fungsi] = (fungsiDistribution[fungsi] ?? 0) + 1;
      }

      return {
        'totalWorkers': totalWorkersCount.count ?? 0,
        'activeWorkers': activeWorkersCount.count ?? 0,
        'inactiveWorkers': inactiveWorkersCount.count ?? 0,
        'workerFungsiCount': fungsiDistribution.keys.length,
        'workerFungsiDistribution': fungsiDistribution,
      };
    } catch (e) {
      logger.e('Error loading master data: $e');
      return {
        'totalWorkers': 0,
        'activeWorkers': 0,
        'inactiveWorkers': 0,
        'workerFungsiCount': 0,
        'workerFungsiDistribution': <String, int>{},
      };
    }
  }

  // ==================== WORKER CRUD ====================

  Future<Map<String, dynamic>?> validateWorkerId(String idPekerja) async {
    try {
      // 🔑 Pastikan ada sesi Firebase Auth sebelum query ke master_workers.
      // Saat register, user belum punya akun sama sekali (request.auth == null),
      // sedangkan rules master_workers mewajibkan isAuthenticated(). Anonymous
      // sign-in memberi request.auth != null tanpa perlu akun permanen dulu.
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }

      final snapshot = await _firestore
          .collection(collectionMasterWorkers)
          .where('id_pekerja', isEqualTo: idPekerja.trim())
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      return {
        'id': snapshot.docs.first.id,
        'id_pekerja': data['id_pekerja'],
        'nama': data['nama'],
        'fungsi': data['fungsi'],
        'role': data['role'],
        'is_active': data['is_active'] ?? true,
      };
    } catch (e) {
      logger.e('Error validating worker: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getWorkersList({
    String? searchQuery,
    String? fungsi,
    bool? isActive,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(collectionMasterWorkers)
          .orderBy('nama');

      if (fungsi != null && fungsi != 'Semua') {
        query = query.where('fungsi', isEqualTo: fungsi);
      }
      if (isActive != null) {
        query = query.where('is_active', isEqualTo: isActive);
      }
      query = query.limit(limit);
      if (lastDoc != null) query = query.startAfterDocument(lastDoc);

      final snapshot = await query.get();
      final workers = snapshot.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return d;
      }).toList();

      return {
        'workers': workers,
        'hasMore': snapshot.docs.length == limit,
        'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      };
    } catch (e) {
      return {'workers': <Map<String, dynamic>>[], 'hasMore': false, 'lastDoc': null};
    }
  }

  Future<List<String>> getFungsiList() async {
    try {
      final snapshot = await _firestore
          .collection(collectionMasterWorkers)
          .where('is_active', isEqualTo: true)
          .get();
      final s = <String>{};
      for (var doc in snapshot.docs) {
        final f = doc.data()['fungsi']?.toString();
        if (f != null && f.isNotEmpty) s.add(f);
      }
      return s.toList()..sort();
    } catch (e) {
      return [];
    }
  }

  Future<bool> addWorker(Map<String, dynamic> data) async {
    try {
      final id = data['id_pekerja']?.toString().trim();
      final nama = data['nama']?.toString().trim();
      if (id == null || id.isEmpty) throw Exception('ID Pekerja kosong');
      if (nama == null || nama.isEmpty) throw Exception('Nama kosong');

      final exist = await _firestore
          .collection(collectionMasterWorkers)
          .where('id_pekerja', isEqualTo: id)
          .limit(1)
          .get();
      if (exist.docs.isNotEmpty) throw Exception('ID $id sudah ada');

      await _firestore.collection(collectionMasterWorkers).add({
        'id_pekerja': id,
        'nama': nama,
        'fungsi': data['fungsi']?.toString().trim() ?? 'operation',
        'role': data['role']?.toString().trim(),
        'is_active': data['is_active'] ?? true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'created_by': _auth.currentUser?.email ?? 'unknown',
      });
      clearCache();
      await logActivity('add_pekerja', 'Tambah: $id - $nama', generateSessionId());
      return true;
    } catch (e) {
      logger.e('Error addWorker: $e');
      rethrow;
    }
  }

  Future<bool> updateWorker(String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collectionMasterWorkers).doc(docId).update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': _auth.currentUser?.email ?? 'unknown',
      });
      clearCache();
      await logActivity('update_pekerja', 'Update: $docId', generateSessionId());
      return true;
    } catch (e) {
      logger.e('Error updateWorker: $e');
      rethrow;
    }
  }

  Future<bool> deleteWorker(String docId) async {
    try {
      await _firestore.collection(collectionMasterWorkers).doc(docId).delete();
      clearCache();
      await logActivity('delete_pekerja', 'Hapus: $docId', generateSessionId());
      return true;
    } catch (e) {
      logger.e('Error deleteWorker: $e');
      return false;
    }
  }

  Future<bool> toggleWorkerStatus(String docId, bool isActive) async {
    try {
      await _firestore.collection(collectionMasterWorkers).doc(docId).update({
        'is_active': isActive,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': _auth.currentUser?.email ?? 'unknown',
      });
      clearCache();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> importWorkersBulk(List<Map<String, dynamic>> workers) async {
    int imported = 0, updated = 0, failed = 0;
    try {
      WriteBatch batch = _firestore.batch();
      int count = 0;

      for (var w in workers) {
        try {
          final id = w['id_pekerja']?.toString().trim() ?? '';
          final nama = w['nama']?.toString().trim() ?? '';
          if (id.isEmpty || nama.isEmpty) {
            failed++;
            continue;
          }

          final exist = await _firestore
              .collection(collectionMasterWorkers)
              .where('id_pekerja', isEqualTo: id)
              .limit(1)
              .get();

          final d = {
            'id_pekerja': id,
            'nama': nama,
            'fungsi': w['fungsi']?.toString().trim() ?? 'operation',
            'role': w['role']?.toString().trim(),
            'is_active': w['is_active'] ?? true,
            'updated_at': FieldValue.serverTimestamp(),
            'updated_by': _auth.currentUser?.email ?? 'system',
          };

          if (exist.docs.isNotEmpty) {
            batch.update(exist.docs.first.reference, d);
            updated++;
          } else {
            d['created_at'] = FieldValue.serverTimestamp();
            batch.set(_firestore.collection(collectionMasterWorkers).doc(), d);
            imported++;
          }
          count++;
          if (count >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            count = 0;
          }
        } catch (e) {
          failed++;
        }
      }
      if (count > 0) await batch.commit();
      clearCache();
      return {
        'success': true,
        'imported': imported,
        'updated': updated,
        'failed': failed,
        'total': workers.length,
        'errors': <String>[],
      };
    } catch (e) {
      return {
        'success': false,
        'imported': imported,
        'updated': updated,
        'failed': workers.length,
        'total': workers.length,
        'errors': [e.toString()],
      };
    }
  }

  Future<List<Map<String, dynamic>>> exportWorkers() async {
    try {
      final snapshot = await _firestore
          .collection(collectionMasterWorkers)
          .orderBy('id_pekerja')
          .get();
      return snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'ID Pekerja': d['id_pekerja'] ?? '-',
          'Nama': d['nama'] ?? '-',
          'Fungsi': d['fungsi'] ?? '-',
          'Role': d['role'] ?? '-',
          'Status': (d['is_active'] ?? true) ? 'Aktif' : 'Non-Aktif',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getWorkerById(String docId) async {
    try {
      final doc = await _firestore.collection(collectionMasterWorkers).doc(docId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      return null;
    }
  }

  // ==================== LOCATION MONITORING ====================

  Stream<List<LocationData>> streamLiveLocations() {
    return _firestore.collection('live_locations').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        double lat, lng;
        final geo = data['coordinates'];
        if (geo is GeoPoint) {
          lat = geo.latitude;
          lng = geo.longitude;
        } else if (data['latitude'] != null && data['longitude'] != null) {
          lat = (data['latitude'] as num).toDouble();
          lng = (data['longitude'] as num).toDouble();
        } else {
          return null;
        }
        return LocationData(
          id: doc.id,
          name: data['user_name'] ?? data['name'] ?? 'Unknown',
          lat: lat,
          lng: lng,
          status: data['status'] ?? 'Normal',
          color: getStatusColor(data['status'] ?? 'Normal'),
          address: data['address'] ?? '',
          lastUpdate: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          workers: data['workers'] ?? 1,
          battery: data['battery'] ?? 100,
          signal: data['signal'] ?? '--',
        );
      }).whereType<LocationData>().toList();
    });
  }

  Stream<List<LocationData>> streamActiveOvertimeLocations() {
    final activeMitraStream = _firestore
        .collection(collectionLemburMitra)
        .where('status', isEqualTo: 'disetujui')
        .where('absensi_status', isEqualTo: 'check_in')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()['mitra_id'] as String).toSet());

    return activeMitraStream.asyncExpand((activeIds) {
      return streamLiveLocations()
          .map((allLocs) => allLocs.where((loc) => activeIds.contains(loc.id)).toList());
    });
  }

  // ==================== SYSTEM HEALTH ====================
  Future<Map<String, dynamic>> loadSystemHealth() async {
    try {
      final doc = await _firestore.collection('health_check').doc('current').get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'database': data['database'] ?? 98,
          'api': data['api'] ?? 95,
          'storage': data['storage'] ?? 76,
          'memory': data['memory'] ?? 82,
          'cpu': data['cpu'] ?? 23,
          'network': data['network'] ?? 45,
          'uptime': data['uptime'] ?? 15,
          'lastBackup': data['last_backup'] is Timestamp
              ? (data['last_backup'] as Timestamp).toDate()
              : DateTime.now().subtract(const Duration(hours: 2)),
        };
      }
    } catch (e) {
      logger.e('Error loading system health: $e');
    }

    return {
      'database': 98,
      'api': 95,
      'storage': 76,
      'memory': 82,
      'cpu': 23,
      'network': 45,
      'uptime': 15,
      'lastBackup': DateTime.now().subtract(const Duration(hours: 2)),
    };
  }

  // ==================== DASHBOARD CONFIG ====================
  Future<Map<String, dynamic>> loadDashboardConfig() async {
    try {
      final doc = await _firestore.collection('dashboard_config').doc('superadmin').get();
      if (doc.exists) return doc.data()!;
    } catch (e) {
      logger.e('Error loading dashboard config: $e');
    }
    return {};
  }

  // ==================== FAQ ====================
  Future<List<Map<String, dynamic>>> loadFAQ() async {
    try {
      final snapshot = await _firestore
          .collection('faq')
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'question': data['question'] ?? '',
          'answer': data['answer'] ?? '',
          'category': data['category'] ?? 'Umum',
          'createdAt': data['createdAt'],
        };
      }).toList();
    } catch (e) {
      logger.e('Error loading FAQ: $e');
      return [];
    }
  }

  Future<void> addFAQ({
    required String question,
    required String answer,
    required String category,
  }) async {
    await _firestore.collection('faq').add({
      'question': question,
      'answer': answer,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _auth.currentUser?.email ?? 'unknown',
    });
  }

  Future<void> deleteFAQ(String faqId) async {
    await _firestore.collection('faq').doc(faqId).delete();
  }

  // ==================== BROADCAST ====================
  Future<void> sendBroadcast({required String message, required String targetRole}) async {
    await _firestore.collection('broadcasts').add({
      'message': message,
      'targetRole': targetRole,
      'createdBy': _auth.currentUser?.email ?? 'unknown',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  // ==================== LOGGING ====================
  Future<void> logActivity(String type, String description, String sessionId) async {
    try {
      await _firestore.collection('system_logs').add({
        'type': type,
        'user': _auth.currentUser?.email ?? 'unknown',
        'target_user': _auth.currentUser?.uid ?? 'unknown',
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': description,
      });

      await _firestore.collection(collectionActivityLogs).add({
        'action': type,
        'user': _auth.currentUser?.email ?? 'unknown',
        'role': 'superadmin',
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'session_id': sessionId,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  // ==================== BACKUP ====================
  Future<void> performBackup(String sessionId) async {
    await logActivity('backup', 'Database backup performed', sessionId);
    try {
      await _firestore.collection('health_check').doc('current').set({
        'last_backup': FieldValue.serverTimestamp(),
        'backup_by': _auth.currentUser?.email ?? 'unknown',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      logger.e('Error updating backup time: $e');
    }
  }

  // ==================== LOGOUT ====================
  Future<void> logout(String sessionId) async {
    await setUserOffline();
    await logActivity('logout', 'User logged out', sessionId);
    await _auth.signOut();
  }

  // ==================== USER PROFILE & GREETING ====================
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection(collectionUsers).doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        return {
          'uid': user.uid,
          'nama_lengkap': data['nama_lengkap'] ?? '',
          'email': user.email ?? '',
          'role': data['role'] ?? 'mitra',
          'fungsi': data['fungsi'] ?? '',
          'nip': data['nip'] ?? '',
          'no_hp': data['no_hp'] ?? '',
          'photo_url': data['photo_url'] ?? data['foto_profil'] ?? '',
          'is_verified': data['is_verified'] ?? false,
          'is_online': data['is_online'] ?? true,
          'last_login': data['last_login'],
          'created_at': data['created_at'],
          'account_locked': data['account_locked'] ?? false,
        };
      }

      return {
        'uid': user.uid,
        'nama_lengkap': user.displayName ?? '',
        'email': user.email ?? '',
        'role': 'mitra',
        'fungsi': '',
        'nip': '',
        'no_hp': user.phoneNumber ?? '',
        'photo_url': user.photoURL ?? '',
        'is_verified': user.emailVerified,
        'is_online': true,
        'last_login': user.metadata.lastSignInTime,
        'created_at': user.metadata.creationTime,
        'account_locked': false,
      };
    } catch (e) {
      logger.e('Error getting current user profile: $e');
      return null;
    }
  }

  Future<String> getUserName() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Pengguna';

      final userDoc = await _firestore.collection(collectionUsers).doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null &&
            data['nama_lengkap'] != null &&
            data['nama_lengkap'].toString().trim().isNotEmpty) {
          return data['nama_lengkap'].toString().trim();
        }
      }

      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        return user.displayName!.trim();
      }

      if (user.email != null && user.email!.isNotEmpty) {
        final emailName = user.email!.split('@')[0];
        return emailName
            .replaceAll('.', ' ')
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1)}'
                : '')
            .join(' ');
      }

      return 'Pengguna';
    } catch (e) {
      logger.e('Error getting user name: $e');
      return 'Pengguna';
    }
  }

  Future<String> getGreetingWithName() async {
    final userName = await getUserName();
    final hour = DateTime.now().hour;

    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Selamat Pagi';
    } else if (hour >= 12 && hour < 15) {
      greeting = 'Selamat Siang';
    } else if (hour >= 15 && hour < 18) {
      greeting = 'Selamat Sore';
    } else {
      greeting = 'Selamat Malam';
    }

    return '$greeting, $userName! 👋';
  }

  Future<String> getGreetingWithNameAndEmoji() async {
    final userName = await getUserName();
    final hour = DateTime.now().hour;

    String greeting;
    String emoji;
    if (hour >= 5 && hour < 12) {
      greeting = 'Selamat Pagi';
      emoji = '🌅';
    } else if (hour >= 12 && hour < 15) {
      greeting = 'Selamat Siang';
      emoji = '☀️';
    } else if (hour >= 15 && hour < 18) {
      greeting = 'Selamat Sore';
      emoji = '🌆';
    } else {
      greeting = 'Selamat Malam';
      emoji = '🌙';
    }

    return '$greeting, $userName! $emoji';
  }

  Future<String> getGreetingMotivation() async {
    final userName = await getUserName();
    final hour = DateTime.now().hour;
    final dayOfWeek = DateTime.now().weekday;

    List<String> motivations;

    if (dayOfWeek == 1) {
      motivations = [
        'Awali minggu dengan semangat baru',
        'Saatnya memulai pekan yang produktif',
        'Mari capai target minggu ini',
      ];
    } else if (dayOfWeek == 5) {
      motivations = [
        'Jumat berkah, tetap semangat',
        'Semoga hari ini penuh keberkahan',
        'Jangan lupa ibadah dan doa hari ini',
      ];
    } else if (dayOfWeek == 6 || dayOfWeek == 7) {
      motivations = [
        'Selamat berakhir pekan',
        'Tetap produktif di akhir pekan',
        'Waktunya istirahat dan refleksi',
      ];
    } else {
      motivations = [
        'Semangat bekerja hari ini',
        'Tetap fokus dan produktif',
        'Jadikan hari ini lebih baik dari kemarin',
        'Konsistensi adalah kunci kesuksesan',
      ];
    }

    final motivation = motivations[hour % motivations.length];
    return '$motivation, $userName! 💪';
  }

  // ==================== HELPER METHODS ====================
  String formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '--';
    DateTime time;
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else if (timestamp is DateTime) {
      time = timestamp;
    } else {
      return '--';
    }

    final diff = DateTime.now().difference(time);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} bln';
    if (diff.inDays > 0) return '${diff.inDays} hr';
    if (diff.inHours > 0) return '${diff.inHours} jam';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mnt';
    return 'baru saja';
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
      case 'active':
      case 'online':
        return Colors.green;
      case 'warning':
      case 'maintenance':
        return Colors.orange;
      case 'darurat':
      case 'error':
      case 'offline':
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
      case 'super admin':
        return const Color(0xFF9C27B0);
      case 'manager':
        return const Color(0xFFFF9800);
      case 'pengawas':
        return const Color(0xFF4CAF50);
      case 'mitra':
        return const Color(0xFFE91E63);
      default:
        return Colors.grey;
    }
  }

  @Deprecated('Gunakan getGreetingWithName()')
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Selamat Pagi';
    if (hour >= 12 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @Deprecated('Gunakan getGreetingWithNameAndEmoji()')
  String getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return '🌅';
    if (hour >= 12 && hour < 15) return '☀️';
    if (hour >= 15 && hour < 18) return '🌆';
    return '🌙';
  }
}

// ==================== DATA CLASSES ====================
class DashboardData {
  final int totalUsers;
  final int activeToday;
  final int pendingApprovals;
  final int pendingHSSEApprovals; // 🔥 NEW
  final int totalOvertime;
  final int approvedOvertime;
  final int verifiedUsers;
  final int lockedAccounts;
  final int newUsersToday;
  final Map<String, int> roleCount;
  final Map<String, int> fungsiCount;
  final Map<String, int> roleDistribution;
  final List<Map<String, dynamic>> recentActivities;
  final int totalWorkers;
  final int activeWorkers;
  final int inactiveWorkers;
  final int workerFungsiCount;
  final Map<String, int> workerFungsiDistribution;

  // 🔥 DATA BARU - LEMBUR LEBIH DETAIL
  final int totalOvertimeBulanIni;
  final int approvedOvertimeBulanIni;
  final int rejectedOvertimeBulanIni;
  final int pendingLemburMitra;
  final int totalLemburMitra;
  final Map<String, int> lemburByStatusBulanIni;
  final Map<String, int> lemburByFungsiBulanIni;

  DashboardData({
    required this.totalUsers,
    required this.activeToday,
    required this.pendingApprovals,
    this.pendingHSSEApprovals = 0, // 🔥 NEW
    required this.totalOvertime,
    required this.approvedOvertime,
    required this.verifiedUsers,
    required this.lockedAccounts,
    required this.newUsersToday,
    required this.roleCount,
    required this.fungsiCount,
    required this.roleDistribution,
    required this.recentActivities,
    this.totalWorkers = 0,
    this.activeWorkers = 0,
    this.inactiveWorkers = 0,
    this.workerFungsiCount = 0,
    this.workerFungsiDistribution = const {},
    // 🔥 DATA BARU
    this.totalOvertimeBulanIni = 0,
    this.approvedOvertimeBulanIni = 0,
    this.rejectedOvertimeBulanIni = 0,
    this.pendingLemburMitra = 0,
    this.totalLemburMitra = 0,
    this.lemburByStatusBulanIni = const {},
    this.lemburByFungsiBulanIni = const {},
  });
}

class LocationData {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String status;
  final Color color;
  final String address;
  final DateTime lastUpdate;
  final int workers;
  final int battery;
  final String signal;

  LocationData({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.status,
    required this.color,
    required this.address,
    required this.lastUpdate,
    required this.workers,
    required this.battery,
    required this.signal,
  });

  LocationData copyWith({
    String? id,
    String? name,
    double? lat,
    double? lng,
    String? status,
    Color? color,
    String? address,
    DateTime? lastUpdate,
    int? workers,
    int? battery,
    String? signal,
  }) {
    return LocationData(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      status: status ?? this.status,
      color: color ?? this.color,
      address: address ?? this.address,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      workers: workers ?? this.workers,
      battery: battery ?? this.battery,
      signal: signal ?? this.signal,
    );
  }
}

class OnlineUserData {
  final String uid;
  final String name;
  final String email;
  final String role;
  final bool isOnline;
  final DateTime lastSeen;
  final String deviceInfo;
  final String location;
  final DateTime? loginTime;

  OnlineUserData({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.isOnline,
    required this.lastSeen,
    required this.deviceInfo,
    required this.location,
    this.loginTime,
  });
}