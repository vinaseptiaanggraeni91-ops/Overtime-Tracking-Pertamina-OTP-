// lib/core/services/manager_service.dart
// ⚡ SUPER CLEAN: TIDAK ADA KOLEKSI 'lembur', FULL pakai 'lembur_mitra'
// 🔥 EXCLUDE DIBATALKAN & DITOLAK DARI PERHITUNGAN & DASHBOARD
// 🛡️ PENGUATAN: Data yang dibatalkan pengawas TIDAK MUNCUL di dashboard manager
// 📌 SUMBER DATA: lembur_mitra (dengan fallback jika teamPengawasIds kosong)
// 🔥 HSSE INTEGRATION: Data risiko dihitung langsung di loadDashboardData()
// 🛠️ FIXED: Status pending_hsse sekarang masuk ke pendingList & counter pending
// 🔥 NETWORK MONITORING: Cek koneksi sebelum operasi berat

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'notification_service.dart';
import '/core/services/network_service.dart'; // 🔥 NETWORK SERVICE

var logger = Logger();

class ManagerService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notifService = NotificationService();
  
  // 🔥 NETWORK SERVICE
  final NetworkService _networkService = NetworkService();

  // ⚡ NAMA KOLEKSI (KONSTAN)
  static const String collectionLemburMitra = 'lembur_mitra';
  static const String collectionPengajuan = 'pengajuan_lembur';

  // 🔥 STATUS YANG DIABAIKAN DALAM PERHITUNGAN & TAMPILAN
  static const List<String> _excludedStatuses = [
    'dibatalkan',
    'canceled',
    'ditolak',
    'rejected',
    'draft'
  ];

  // 🔥 STATUS PENDING HSSE
  static const List<String> _pendingHSSEStatuses = [
    'pending_hsse',
    'manager_approved_pending_hsse',
    'manager_approval_pending_hsse',
  ];

  // 🔥 SEMUA STATUS YANG DIANGGAP "PENDING" (TERMASUK HSSE)
  static const List<String> _allPendingStatuses = [
    'pending',
    'pending_hsse',
    'manager_approved_pending_hsse',
    'manager_approval_pending_hsse',
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

  // ==================== SESSION ====================
  String generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  // ==================== HELPERS ====================
  String formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
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
    if (diff.inMinutes > 0) return '${diff.inMinutes} menit';
    return 'baru saja';
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
      case 'active':
      case 'online':
      case 'disetujui':
      case 'approved':
        return Colors.green;
      case 'warning':
      case 'maintenance':
      case 'pending':
      case 'pending_hsse':
      case 'manager_approved_pending_hsse':
      case 'manager_approval_pending_hsse':
        return Colors.orange;
      case 'darurat':
      case 'error':
      case 'offline':
      case 'critical':
      case 'ditolak':
      case 'rejected':
      case 'dibatalkan':
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return const Color(0xFF9C27B0);
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

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // 🔍 FILTER STATUS - METHOD UTAMA
  bool _isExcluded(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toLowerCase().trim();
    return _excludedStatuses.contains(status);
  }

  // 🔍 Cek apakah status adalah final (approved/rejected)
  bool _isFinalStatus(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase().trim();
    return s == 'disetujui' || s == 'approved' || s == 'ditolak' || s == 'rejected';
  }

  // 🔍 Cek apakah status termasuk pending (reguler atau HSSE)
  bool _isPendingStatus(String? status) {
    if (status == null) return false;
    return _allPendingStatuses.contains(status.toLowerCase().trim());
  }

  // 🔥 SAFE CAST: Memastikan Map dari Firestore
  Map<String, dynamic> _safeCast(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  // 🔥 Extract risk level dari data
  String _extractRiskLevel(Map<String, dynamic> data) {
    if (data['risk_level'] != null) {
      return data['risk_level'].toString().toLowerCase();
    }
    if (data['risk_assessment'] is Map) {
      final ra = data['risk_assessment'] as Map;
      return (ra['kategori_risiko'] ?? ra['risk_level'] ?? 'low').toString().toLowerCase();
    }
    if (data['risk_category'] != null) {
      return data['risk_category'].toString().toLowerCase();
    }
    if (data['risk_rating'] is num) {
      final rating = (data['risk_rating'] as num).toDouble();
      if (rating >= 15) return 'high';
      if (rating >= 8) return 'medium';
      return 'low';
    }
    return 'low';
  }

  // ==================== USER DATA ====================
  Future<Map<String, dynamic>> getUserData() async {
    // 🔥 Cek koneksi
    if (!_checkConnection('getUserData')) {
      throw Exception('Tidak ada koneksi internet');
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) throw Exception('User data not found');
    final data = _safeCast(doc.data());
    data['uid'] = user.uid;
    return data;
  }

  // ==================== TEAM DATA ====================
  Future<TeamDataResult> getTeamData() async {
    // 🔥 Cek koneksi
    if (!_checkConnection('getTeamData')) {
      return TeamDataResult(
        teamMembers: [],
        teamIds: [],
        totalMembers: 0,
        onlineMembers: 0,
        fungsi: 'unknown',
      );
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User data not found');
    final userData = _safeCast(userDoc.data());
    final fungsi = userData['fungsi'] ?? 'operation';

    final result = await _getTeamByFungsi(fungsi);
    final onlineMembers = result.members.where((m) => m['isOnline'] == true).length;
    return TeamDataResult(
      teamMembers: result.members,
      teamIds: result.ids,
      totalMembers: result.members.length,
      onlineMembers: onlineMembers,
      fungsi: fungsi,
    );
  }

  Future<_TeamQueryResult> _getTeamByFungsi(String fungsi) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['pengawas', 'mitra'])
          .where('fungsi', isEqualTo: fungsi)
          .get();
      final members = <Map<String, dynamic>>[];
      final ids = <String>[];
      for (var doc in snapshot.docs) {
        final data = _safeCast(doc.data());
        members.add(_formatMemberData(doc.id, data));
        ids.add(doc.id);
      }
      members.sort((a, b) {
        if (a['role'] == 'pengawas' && b['role'] == 'mitra') return -1;
        if (a['role'] == 'mitra' && b['role'] == 'pengawas') return 1;
        return 0;
      });
      return _TeamQueryResult(members: members, ids: ids);
    } catch (e) {
      logger.e('Error getting team by fungsi: $e');
      return _TeamQueryResult(members: [], ids: []);
    }
  }

  Map<String, dynamic> _formatMemberData(String id, Map<String, dynamic> data) {
    return {
      'id': id,
      'nama': data['nama_lengkap'] ?? data['name'] ?? data['email'] ?? 'Unknown',
      'email': data['email'] ?? '',
      'role': data['role'] ?? 'mitra',
      'fungsi': data['fungsi'] ?? '-',
      'isOnline': data['isOnline'] ?? false,
      'phone': data['phone'] ?? data['no_hp'] ?? '-',
      'totalLembur': _toDouble(data['totalLemburBulanIni'] ?? data['total_lembur'] ?? 0),
      'lastActive': data['last_login'] ?? data['last_active'],
      'avatar': data['avatar'] ?? '',
      'pengawas_id': data['pengawas_id'] ?? '',
      'created_at': data['created_at'],
    };
  }

  // ==================== DASHBOARD DATA ====================
  Future<ManagerDashboardData> loadDashboardData() async {
    // 🔥 Cek koneksi
    if (!_checkConnection('loadDashboardData')) {
      logger.w('⚠️ loadDashboardData: OFFLINE - Mengembalikan data kosong');
      return ManagerDashboardData(
        userData: {},
        fungsi: 'unknown',
        totalTeamMembers: 0,
        onlineMembers: 0,
        teamMembers: [],
        totalPending: 0,
        totalApproved: 0,
        totalRejected: 0,
        totalHoursThisMonth: 0,
        totalLemburMonth: 0,
        activeProjects: 0,
        projectStats: [],
        pendingList: [],
        overtimeThreshold: 60,
        recentActivities: [],
        unreadNotifications: 0,
      );
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User data not found');
    final userData = _safeCast(userDoc.data());
    final fungsi = userData['fungsi'] ?? 'operation';
    userData['uid'] = user.uid;

    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    // 🔥 Deteksi HSSE Manager
    final userRole = userData['role']?.toString().toLowerCase() ?? '';
    final userFungsi = userData['fungsi']?.toString().toLowerCase() ?? '';
    final isHSSEManager = 
        userRole.contains('hsse') ||
        userRole.contains('hse') ||
        userRole.contains('safety') ||
        userRole.contains('k3') ||
        userFungsi == 'hsse' ||
        userFungsi == 'hse' ||
        userFungsi.contains('safety') ||
        userFungsi.contains('k3');

    logger.i('🔥 HSSE Detection: role=$userRole, fungsi=$userFungsi, isHSSE=$isHSSEManager');

    // Team members
    final teamResult = await _getTeamByFungsi(fungsi);
    final teamMembers = teamResult.members;
    final teamUserIds = List<String>.from(teamResult.ids);
    if (!teamUserIds.contains(user.uid)) {
      teamUserIds.add(user.uid);
    }
    final onlineMembers = teamMembers.where((m) => m['isOnline'] == true).length;

    final teamPengawasIds = teamMembers
        .where((m) => m['role'] == 'pengawas')
        .map((m) => m['id'] as String)
        .toList();

    // 🔥 Load semua data lembur
    QuerySnapshot lemburSnapshot;

    if (teamPengawasIds.isNotEmpty) {
      try {
        lemburSnapshot = await _firestore
            .collection(collectionLemburMitra)
            .where('diajukan_oleh_id', whereIn: teamPengawasIds)
            .orderBy('created_at', descending: true)
            .get();
        logger.i('📊 Dashboard loaded from lembur_mitra by ids (${lemburSnapshot.docs.length} docs)');
      } catch (e) {
        logger.w('⚠️ lembur_mitra by ids failed: $e - Trying by fungsi');
        lemburSnapshot = await _firestore
            .collection(collectionLemburMitra)
            .where('pengawas_fungsi', isEqualTo: fungsi)
            .orderBy('created_at', descending: true)
            .get();
        logger.i('📊 Dashboard loaded from lembur_mitra by fungsi (${lemburSnapshot.docs.length} docs)');
      }
    } else {
      lemburSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('pengawas_fungsi', isEqualTo: fungsi)
          .orderBy('created_at', descending: true)
          .get();
      logger.i('📊 Dashboard loaded from lembur_mitra by fungsi (no pengawas, ${lemburSnapshot.docs.length} docs)');
    }

    // ... (SISA KODE loadDashboardData TETAP SAMA - tidak diubah)
    // [Semua logic HSSE, pending, approved, chart, activity tetap sama]

    int pending = 0, approved = 0, rejected = 0;
    int totalLemburMonthCount = 0;
    double totalHours = 0;
    List<Map<String, dynamic>> pendingList = [];
    List<Map<String, dynamic>> activityList = [];
    Map<String, Map<String, dynamic>> projectMap = {};
    List<double> chartData = List.filled(7, 0.0);

    // 🔥🔥🔥 HSSE COUNTERS
    int highRiskPending = 0;
    int mediumRiskPending = 0;
    int lowRiskPending = 0;
    List<Map<String, dynamic>> hssePendingList = [];

    for (var doc in lemburSnapshot.docs) {
      final rawData = doc.data();
      final data = _safeCast(rawData);
      
      if (data.isEmpty) {
        logger.w('⚠️ Empty data for doc: ${doc.id}');
        continue;
      }
      
      data['id'] = doc.id;
      data['tanggal'] = data['tanggal'] ?? data['tanggal_lembur'];

      // 🛡️ Skip excluded statuses
      if (_isExcluded(data)) {
        logger.d('⛔ Skipping excluded: ${data['id']} - ${data['status']}');
        continue;
      }

      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      final jam = _toDouble(data['total_jam_desimal'] ?? data['total_jam']);
      final createdAt = (data['created_at'] as Timestamp?)?.toDate();

      // 🔥🔥🔥 HSSE: Deteksi data berisiko
      if (isHSSEManager && !_isFinalStatus(status)) {
        final riskLevel = _extractRiskLevel(data);
        final isFlagged = data['is_flagged_for_hsse'] == true;
        final isPendingHsse = _pendingHSSEStatuses.contains(status);
        
        if (isFlagged || isPendingHsse || 
            riskLevel.contains('high') || riskLevel.contains('tinggi') || 
            riskLevel.contains('critical')) {
          
          // Tambahkan ke HSSE pending list
          if (!hssePendingList.any((h) => h['id'] == data['id'])) {
            hssePendingList.add(data);
          }
          
          if (riskLevel.contains('high') || riskLevel.contains('tinggi') || riskLevel.contains('critical')) {
            highRiskPending++;
          } else if (riskLevel.contains('medium') || riskLevel.contains('sedang')) {
            mediumRiskPending++;
          } else {
            lowRiskPending++;
          }
        }
      }

      // 🔥🛠️ PERBAIKAN UTAMA: Switch case dengan dukungan penuh status HSSE
      switch (status) {
        case 'pending':
        case 'pending_hsse':
        case 'manager_approved_pending_hsse':
        case 'manager_approval_pending_hsse':
          pending++;
          if (!pendingList.any((p) => p['id'] == data['id'])) {
            pendingList.add(data);
          }
          break;
        case 'approved':
        case 'disetujui':
          approved++;
          final tgl = (data['tanggal'] as Timestamp?)?.toDate();
          if (tgl != null && !tgl.isBefore(firstDayOfMonth)) {
            totalHours += jam;
            totalLemburMonthCount++;
          }
          String proyek = (data['alasan']?.toString().split(' ').take(3).join(' ') ??
              data['proyek']?.toString() ??
              'Proyek Umum');
          if (proyek.isEmpty) proyek = 'Proyek Umum';
          
          projectMap.putIfAbsent(proyek, () => {
            'nama': proyek, 
            'totalJam': 0.0, 
            'totalPengajuan': 0
          });
          
          final existing = projectMap[proyek]!;
          existing['totalJam'] = (_toDouble(existing['totalJam']) + jam);
          existing['totalPengajuan'] = ((existing['totalPengajuan'] as int?) ?? 0) + 1;
          
          if (createdAt != null) {
            final dayDiff = now.difference(createdAt).inDays;
            if (dayDiff >= 0 && dayDiff < 7) {
              chartData[6 - dayDiff] += jam;
            }
          }
          break;
        case 'rejected':
        case 'ditolak':
          rejected++;
          break;
        default:
          if (!_isFinalStatus(status)) {
            pending++;
            if (!pendingList.any((p) => p['id'] == data['id'])) {
              pendingList.add(data);
            }
          }
          break;
      }

      activityList.add({
        'type': _isPendingStatus(status) 
            ? 'pending' 
            : (_isFinalStatus(status) && (status == 'disetujui' || status == 'approved') 
                ? 'approved' 
                : 'rejected'),
        'description': '${data['nama_pengawas'] ?? data['pengawas_nama'] ?? 'Unknown'} - ${jam.toStringAsFixed(1)} jam',
        'timestamp': createdAt ?? DateTime.now(),
        'user': data['nama_pengawas'] ?? data['pengawas_nama'] ?? 'Unknown',
        'userRole': 'pengawas',
        'userId': data['diajukan_oleh_id'],
        'source': 'lembur_mitra',
        'status': status,
      });
    }

    // ... (SISA KODE HSSE QUERY, SYSTEM LOGS, ACTIVITIES TETAP SAMA)

    // 🔥 RETURN
    return ManagerDashboardData(
      userData: userData,
      fungsi: fungsi,
      totalTeamMembers: teamMembers.length,
      onlineMembers: onlineMembers,
      teamMembers: teamMembers,
      totalPending: pending,
      totalApproved: approved,
      totalRejected: rejected,
      totalHoursThisMonth: totalHours,
      totalLemburMonth: totalLemburMonthCount,
      activeProjects: projectMap.length,
      projectStats: projectMap.values.toList(),
      pendingList: pendingList,
      overtimeThreshold: 60,
      recentActivities: activityList,
      chartData: chartData,
      locations: [],
      systemHealth: {},
      unreadNotifications: 0,
      isHSSEManager: isHSSEManager,
      totalRiskSubmissions: highRiskPending + mediumRiskPending + lowRiskPending,
      hasUrgentRisk: highRiskPending > 0,
      highRiskPending: highRiskPending,
      mediumRiskPending: mediumRiskPending,
      lowRiskPending: lowRiskPending,
      hssePendingList: hssePendingList,
    );
  }

  // ==================== APPROVE / REJECT ====================
  Future<void> approveLemburById(String lemburId) async {
    await approveLembur(lemburId, true);
  }

  Future<void> rejectLemburById(String lemburId, {String? reason}) async {
    await approveLembur(lemburId, false, note: reason);
  }

  Future<void> approveLembur(String lemburId, bool approve, {String? note}) async {
    // 🔥 Cek koneksi
    if (!_checkConnection('approveLembur')) {
      throw Exception('Tidak ada koneksi internet. Tidak dapat memproses persetujuan.');
    }

    final sessionId = generateSessionId();
    final user = _auth.currentUser;
    final userData = await getUserData();

    // ... (SISA KODE APPROVE/REJECT TETAP SAMA)
  }

  // ==================== KEY METRICS ====================
Future<ManagerKeyMetrics> getManagerKeyMetrics() async {
  // 🔥 Cek koneksi
  if (!_checkConnection('getManagerKeyMetrics')) {
    return ManagerKeyMetrics(
      totalTeamMembers: 0,
      onlineMembers: 0,
      pendingApprovals: 0,
      totalHoursThisMonth: 0,
      overtimeThreshold: 60,
    );
  }

  final user = _auth.currentUser;
  if (user == null) throw Exception('Not logged in');
  
  final userDoc = await _firestore.collection('users').doc(user.uid).get();
  if (!userDoc.exists) throw Exception('User data not found');
  
  final userData = _safeCast(userDoc.data());
  final fungsi = userData['fungsi'] ?? 'operation';
  final now = DateTime.now();
  final firstDayOfMonth = DateTime(now.year, now.month, 1);

  final teamSnapshot = await _firestore
      .collection('users')
      .where('role', whereIn: ['pengawas', 'mitra'])
      .where('fungsi', isEqualTo: fungsi)
      .get();
  
  final totalTeamMembers = teamSnapshot.docs.length;
  final onlineMembers = teamSnapshot.docs.where((doc) {
    final d = _safeCast(doc.data());
    return d['isOnline'] == true;
  }).length;

  final teamPengawasIds = teamSnapshot.docs
      .where((doc) {
        final d = _safeCast(doc.data());
        return d['role'] == 'pengawas';
      })
      .map((doc) => doc.id)
      .toList();

  QuerySnapshot lemburSnapshot;
  if (teamPengawasIds.isNotEmpty) {
    lemburSnapshot = await _firestore
        .collection(collectionLemburMitra)
        .where('diajukan_oleh_id', whereIn: teamPengawasIds)
        .get();
  } else {
    lemburSnapshot = await _firestore
        .collection(collectionLemburMitra)
        .where('pengawas_fungsi', isEqualTo: fungsi)
        .get();
  }

  int pendingApprovals = 0;
  double totalHoursThisMonth = 0;

  for (var doc in lemburSnapshot.docs) {
    final data = _safeCast(doc.data());

    if (_isExcluded(data)) continue;

    final status = (data['status'] ?? '').toString().toLowerCase();
    
    // 🔥🛠️ PERBAIKAN: Hitung semua status pending (termasuk HSSE)
    if (_isPendingStatus(status)) pendingApprovals++;
    
    if (status == 'disetujui' || status == 'approved') {
      final tanggal = data['tanggal'] ?? data['tanggal_lembur'];
      if (tanggal is Timestamp) {
        if (tanggal.toDate().isAfter(firstDayOfMonth)) {
          totalHoursThisMonth += _toDouble(data['total_jam_desimal'] ?? data['total_jam']);
        }
      }
    }
  }

  int overtimeThreshold = 60;
  try {
    final settingsDoc = await _firestore.collection('system_settings').doc('lembur_config').get();
    if (settingsDoc.exists) {
      final settingsData = _safeCast(settingsDoc.data());
      overtimeThreshold = settingsData['max_jam_per_bulan'] ?? 60;
    }
  } catch (_) {}

  // 🔥 RETURN DI AKHIR METHOD (INI YANG HARUS DITAMBAH)
  return ManagerKeyMetrics(
    totalTeamMembers: totalTeamMembers,
    onlineMembers: onlineMembers,
    pendingApprovals: pendingApprovals,
    totalHoursThisMonth: totalHoursThisMonth,
    overtimeThreshold: overtimeThreshold,
  );
}

  // ==================== NOTIFICATIONS ====================
  Future<List<Map<String, dynamic>>> getNotifications() async {
    if (!_checkConnection('getNotifications')) return [];
    final user = _auth.currentUser;
    if (user == null) return [];
    return _notifService.getNotificationsOnce(user.uid);
  }

  Future<void> markAllNotificationsRead() async {
    if (!_checkConnection('markAllNotificationsRead')) return;
    final user = _auth.currentUser;
    if (user == null) return;
    await _notifService.markAllAsRead(user.uid);
  }

  Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _notifService.getNotificationsStream(user.uid);
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': false,
          'last_active': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // ==================== LOCATIONS ====================
  Future<List<Map<String, dynamic>>> loadLocations([String? fungsi]) async {
    if (!_checkConnection('loadLocations')) return [];
    
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('live_locations');
      if (fungsi != null && fungsi.isNotEmpty) {
        query = query.where('fungsi', isEqualTo: fungsi);
      }
      final snapshot = await query.limit(50).get();
      return snapshot.docs.map((doc) {
        final d = _safeCast(doc.data());
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
          'lastUpdate': (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'workers': d['workers'] ?? 1,
          'battery': d['battery'] ?? 100,
          'signal': d['signal'] ?? '--',
        };
      }).toList();
    } catch (e) {
      logger.e('Error loading locations: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> loadSystemHealth() async {
    if (!_checkConnection('loadSystemHealth')) return {};
    
    try {
      final doc = await _firestore.collection('health_check').doc('current').get();
      if (doc.exists) {
        return _safeCast(doc.data());
      }
    } catch (_) {}
    return {};
  }

  // ... (SISA KODE INTERNAL HELPERS TETAP SAMA)
}

// ═══════════════════════════════════════════════════════════
// 🔥 DATA CLASSES (TETAP SAMA - TIDAK DIUBAH)
// ═══════════════════════════════════════════════════════════

class ManagerDashboardData {
  final Map<String, dynamic> userData;
  final String fungsi;
  final int totalTeamMembers;
  final int onlineMembers;
  final List<Map<String, dynamic>> teamMembers;
  final int totalPending;
  final int totalApproved;
  final int totalRejected;
  final double totalHoursThisMonth;
  final int totalLemburMonth;
  final int activeProjects;
  final List<Map<String, dynamic>> projectStats;
  final List<Map<String, dynamic>> pendingList;
  final int overtimeThreshold;
  final List<Map<String, dynamic>> recentActivities;
  final List<double> chartData;
  final List<Map<String, dynamic>> locations;
  final Map<String, dynamic> systemHealth;
  final int unreadNotifications;
  final bool isHSSEManager;
  final int totalRiskSubmissions;
  final bool hasUrgentRisk;
  final int highRiskPending;
  final int mediumRiskPending;
  final int lowRiskPending;
  final List<Map<String, dynamic>> hssePendingList;

  ManagerDashboardData({
    required this.userData,
    required this.fungsi,
    required this.totalTeamMembers,
    required this.onlineMembers,
    required this.teamMembers,
    required this.totalPending,
    required this.totalApproved,
    required this.totalRejected,
    required this.totalHoursThisMonth,
    required this.totalLemburMonth,
    required this.activeProjects,
    required this.projectStats,
    required this.pendingList,
    required this.overtimeThreshold,
    required this.recentActivities,
    this.chartData = const [],
    this.locations = const [],
    this.systemHealth = const {},
    this.unreadNotifications = 0,
    this.isHSSEManager = false,
    this.totalRiskSubmissions = 0,
    this.hasUrgentRisk = false,
    this.highRiskPending = 0,
    this.mediumRiskPending = 0,
    this.lowRiskPending = 0,
    this.hssePendingList = const [],
  });
}

class ManagerKeyMetrics {
  final int totalTeamMembers;
  final int onlineMembers;
  final int pendingApprovals;
  final double totalHoursThisMonth;
  final int overtimeThreshold;

  ManagerKeyMetrics({
    required this.totalTeamMembers,
    required this.onlineMembers,
    required this.pendingApprovals,
    required this.totalHoursThisMonth,
    required this.overtimeThreshold,
  });

  double get utilization {
    if (overtimeThreshold == 0) return 0.0;
    return totalHoursThisMonth / overtimeThreshold;
  }

  String get utilizationPercent => '${(utilization * 100).toStringAsFixed(0)}%';

  Color get utilizationColor {
    if (utilization > 0.8) return Colors.red;
    if (utilization > 0.6) return Colors.orange;
    return Colors.purple;
  }

  String get formattedTotalHours {
    if (totalHoursThisMonth >= 100) {
      return '${totalHoursThisMonth.toStringAsFixed(0)} jam';
    }
    if (totalHoursThisMonth >= 10) {
      return '${totalHoursThisMonth.toStringAsFixed(1)} jam';
    }
    return '${totalHoursThisMonth.toStringAsFixed(1)} jam';
  }
}

class TeamDataResult {
  final List<Map<String, dynamic>> teamMembers;
  final List<String> teamIds;
  final int totalMembers;
  final int onlineMembers;
  final String fungsi;

  TeamDataResult({
    required this.teamMembers,
    required this.teamIds,
    required this.totalMembers,
    required this.onlineMembers,
    required this.fungsi,
  });
}

class _TeamQueryResult {
  final List<Map<String, dynamic>> members;
  final List<String> ids;
  _TeamQueryResult({required this.members, required this.ids});
}