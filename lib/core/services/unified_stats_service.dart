// lib/core/services/unified_stats_service.dart
// 🔥 FINAL VERSION - SATU SERVICE UNTUK SEMUA DASHBOARD
// 🔥 HANYA DARI COLLECTION lembur_mitra
// 🔥 PENDING ≠ DIBATALKAN (dibatalkan EXCLUDE dari pending)
// 🔥 PENDING ≠ PENDING HSSE (pending_hsse TERPISAH dari pending)
// 🔥 PENDING HSSE terdeteksi terpisah
// 🔥 Status unknown di-SKIP (tidak masuk counter)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UnifiedStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final UnifiedStatsService _instance = UnifiedStatsService._internal();
  factory UnifiedStatsService() => _instance;
  UnifiedStatsService._internal();

  // ═══════════════════════════════════════════════════════════════
  // 🔥 STATUS KONSTANTA
  // ═══════════════════════════════════════════════════════════════

  static const List<String> activeStatuses = [
    'pending',
    'manager_approved',
    'pending_hsse',
    'manager_approval_pending_hsse',
    'manager_approved_pending_hsse',
  ];

  static const List<String> finalStatuses = [
    'disetujui', 'approved',
    'ditolak', 'rejected',
    'dibatalkan', 'cancelled',
    'selesai', 'completed',
    'kadaluarsa',
  ];

  static const List<String> allDisplayStatuses = [
    ...activeStatuses,
    ...finalStatuses,
  ];

  // 🔥 Status yang masuk ke counter pendingHSSE (BUKAN pending)
  static const List<String> hssePendingStatuses = [
    'pending_hsse',
    'manager_approval_pending_hsse',
    'manager_approved_pending_hsse',
  ];

  // ═══════════════════════════════════════════════════════════════
  // 🔥 GET STATS BY ROLE
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getStats({
    required String role,
    String? fungsi,
    String? userId,
    String? bulan,
  }) async {
    try {
      // Konversi bulan ke range Timestamp
      DateTime startDate, endDate;
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        final parts = bulan.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        startDate = DateTime(year, month, 1);
        endDate = DateTime(year, month + 1, 0, 23, 59, 59);
      } else {
        final now = DateTime.now();
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      }

      // 🔥 HANYA collection lembur_mitra + FILTER status yang dikenal
      Query<Map<String, dynamic>> query = _firestore
          .collection('lembur_mitra')
          .where('status', whereIn: allDisplayStatuses);

      // Filter berdasarkan role
      switch (role) {
        case 'superadmin':
          if (fungsi != null && fungsi.isNotEmpty && fungsi != 'semua') {
            query = query.where('pengawas_fungsi', isEqualTo: fungsi);
          }
          break;
        case 'manager':
          if (fungsi != null && fungsi.isNotEmpty) {
            query = query.where('pengawas_fungsi', isEqualTo: fungsi);
          }
          break;
        case 'pengawas':
          if (userId != null && userId.isNotEmpty) {
            query = query.where('diajukan_oleh_id', isEqualTo: userId);
          }
          break;
        case 'mitra':
          if (userId != null && userId.isNotEmpty) {
            query = query.where('mitra_id', isEqualTo: userId);
          }
          break;
      }

      // Filter bulan
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        query = query.where('tahun_bulan', isEqualTo: bulan);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      debugPrint('📊 [QUERY] Found ${docs.length} docs in lembur_mitra');

      // 🔥 GROUP BY group_id untuk hindari duplikasi
      final Map<String, Map<String, dynamic>> uniqueGroups = {};
      for (var doc in docs) {
        final data = doc.data();
        final String groupId = (data['group_id'] ?? doc.id).toString();
        if (!uniqueGroups.containsKey(groupId) ||
            _isNewer(data, uniqueGroups[groupId]!)) {
          uniqueGroups[groupId] = data;
        }
      }

      debugPrint('📊 [UNIQUE] After group by: ${uniqueGroups.length} groups');

      // ═══════════════════════════════════════════════════════════
      // 🔥 HITUNG STATS DENGAN LOGIKA TEPAT
      // ═══════════════════════════════════════════════════════════

      int total = uniqueGroups.length;
      int pending = 0;
      int approved = 0;
      int completed = 0;
      int rejected = 0;
      int cancelled = 0;
      int pendingHSSE = 0;
      int needAbsensi = 0;
      int riskyCount = 0;
      int perluRevisi = 0;
      int escalated = 0;

      double completedTotalJam = 0;
      double completedTotalBiaya = 0;

      int hssApproved = 0;
      int hssRejected = 0;

      final Set<String> uniqueMitraIds = {};
      final Set<String> statusesFound = {};

      for (var entry in uniqueGroups.entries) {
        final data = entry.value;
        final String status =
            (data['status'] ?? '').toString().toLowerCase().trim();
        final String hsseStatus =
            (data['hsse_status'] ?? 'pending').toString().toLowerCase().trim();

        statusesFound.add(status.isEmpty ? '(empty)' : status);

        final double jam = _parseDouble(data['total_jam_desimal']);
        final double biaya = _parseDouble(
            data['estimasi_biaya_total'] ?? data['estimasi_biaya']);

        // 🔥 Skip data dengan status kosong/null
        if (status.isEmpty || status == 'null') {
          debugPrint('⚠️ [SKIP] Empty status for doc ${entry.key}');
          total--;
          continue;
        }

        // ═══════════════════════════════════════════
        // 🔥 STATUS COUNTER - URUTAN PENTING
        // ═══════════════════════════════════════════

        if (status == 'dibatalkan' || status == 'cancelled') {
          // 🔥 DIBATALKAN - TIDAK MASUK KE COUNTER LAIN
          cancelled++;
        } else if (status == 'ditolak' || status == 'rejected') {
          // 🔥 DITOLAK
          rejected++;
        } else if (status == 'selesai' || status == 'completed') {
          // 🔥 SELESAI
          completed++;
          completedTotalJam += jam;
          completedTotalBiaya += biaya;
        } else if (status == 'kadaluarsa') {
          // 🔥 KADALUARSA - hanya untuk total
        } else if (hssePendingStatuses.contains(status)) {
          // 🔥 PENDING HSSE - TERPISAH DARI PENDING BIASA
          pendingHSSE++;
          if (status == 'manager_approved_pending_hsse' ||
              status == 'manager_approval_pending_hsse') {
            if (!_isAbsensiComplete(data)) {
              needAbsensi++;
            }
          }
        } else if (status == 'pending') {
          // 🔥 PENDING BIASA (TANPA HSSE) - hanya 'pending' murni
          pending++;
        } else if (status == 'manager_approved') {
          // 🔥 DISETUJUI MANAGER
          approved++;
          if (!_isAbsensiComplete(data)) {
            needAbsensi++;
          }
        } else if (status == 'disetujui' || status == 'approved') {
          // 🔥 DISETUJUI FINAL
          approved++;
          if (!_isAbsensiComplete(data)) {
            needAbsensi++;
          }
        } else {
          // 🔥 Status tidak dikenal - SKIP dari counter
          debugPrint('⚠️ [SKIP] Unknown status: "$status" for doc ${entry.key}');
          total--;
        }

        // ═══════════════════════════════════════════
        // 🔥 HSSE STATUS COUNTER (terpisah)
        // ═══════════════════════════════════════════
        if (!_isCancelled(data)) {
          if (hsseStatus == 'disetujui') {
            hssApproved++;
          } else if (hsseStatus == 'ditolak') {
            hssRejected++;
          } else if (hsseStatus == 'perlu_revisi') {
            perluRevisi++;
          }
        }

        // 🔥 RISKY CHECK
        if ((data['is_risky'] == true ||
                data['requires_hsse_approval'] == true) &&
            !_isCancelled(data)) {
          riskyCount++;
        }

        // 🔥 ESCALATION
        if (data['hsse_need_escalation'] == true) {
          escalated++;
        }

        // 🔥 KUMPULKAN MITRA UNIK
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

      // Build response
      final result = <String, dynamic>{
        'total': total,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'completed': completed,
        'cancelled': cancelled,
        'pendingHSSE': pendingHSSE,
        'needAbsensi': needAbsensi,
        'riskyCount': riskyCount,
        'perluRevisi': perluRevisi,
        'escalated': escalated,
        'completedTotalJam': completedTotalJam,
        'completedTotalBiaya': completedTotalBiaya,
        'totalMitra': uniqueMitraIds.length,
        'hssApproved': hssApproved,
        'hssRejected': hssRejected,
      };

      // 🔥 SUPERADMIN SPECIAL
      if (role == 'superadmin') {
        final userStats = await _getUserStats();
        result.addAll(userStats);
      }

      // 🔥 Debug log
      debugPrint('📋 [STATUSES] $statusesFound');
      debugPrint('📊 [Stats] total=$total | pending=$pending | '
          'pendingHSSE=$pendingHSSE | approved=$approved | '
          'completed=$completed | rejected=$rejected | cancelled=$cancelled');
      final sum = pending + pendingHSSE + approved + completed + rejected + cancelled;
      debugPrint('📊 [Verify] Sum=$sum | Total=$total | ${sum == total ? "✅ MATCH" : "❌ MISMATCH"}');

      return result;
    } catch (e) {
      debugPrint('❌ [UnifiedStatsService.getStats] Error: $e');
      return _getEmptyStats();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 GET HSSE STATS (UNTUK MANAGER HSSE & SUPERADMIN)
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getHSSEStats({
    String? bulan,
    String? fungsi,
  }) async {
    try {
      Query<Map<String, dynamic>> qm = _firestore
          .collection('lembur_mitra')
          .where('status', whereIn: allDisplayStatuses);

      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        qm = qm.where('tahun_bulan', isEqualTo: bulan);
      }

      if (fungsi != null && fungsi.isNotEmpty && fungsi != 'semua') {
        qm = qm.where('pengawas_fungsi', isEqualTo: fungsi);
      }

      final allDocs = (await qm.get()).docs;

      // Filter HSSE-related & GROUP BY group_id
      final Map<String, Map<String, dynamic>> uniqueGroups = {};
      for (var doc in allDocs) {
        final data = doc.data();
        final bool isHSSERelated = data['is_risky'] == true ||
            data['requires_hsse_approval'] == true ||
            hssePendingStatuses.contains(data['status']) ||
            data['hsse_validated'] == true;

        if (!isHSSERelated) continue;

        final String groupId = (data['group_id'] ?? doc.id).toString();
        if (!uniqueGroups.containsKey(groupId) ||
            _isNewer(data, uniqueGroups[groupId]!)) {
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
        final String hsseStatus =
            (data['hsse_status'] ?? 'pending').toString().toLowerCase().trim();
        final String status =
            (data['status'] ?? '').toString().toLowerCase().trim();

        // 🔥 EXCLUDE dibatalkan
        if (_isCancelled(data)) continue;

        switch (hsseStatus) {
          case 'pending':
            pendingHSSE++;
            break;
          case 'disetujui':
            approvedHSSE++;
            break;
          case 'ditolak':
            rejectedHSSE++;
            break;
          case 'perlu_revisi':
            perluRevisi++;
            break;
          case 'dalam_review':
            dalamReview++;
            break;
        }

        if (data['hsse_need_escalation'] == true) escalated++;

        final biaya = _parseDouble(
            data['estimasi_biaya_total'] ?? data['estimasi_biaya']);
        totalBiaya += biaya;

        if (status == 'selesai' || status == 'completed') {
          completedTotalBiaya += biaya;
        }

        final fungsiData = data['pengawas_fungsi'] as String?;
        if (fungsiData != null && fungsiData.isNotEmpty) {
          fungsiSet.add(fungsiData);
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
      debugPrint('❌ [getHSSEStats] Error: $e');
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
  // 🔥 GET USER STATS (SUPERADMIN)
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _getUserStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final usersSnapshot = await _firestore
          .collection('users')
          .orderBy('last_login', descending: true)
          .limit(500)
          .get();

      int totalUsers = usersSnapshot.docs.length;
      int activeToday = 0;
      int verifiedUsers = 0;
      int lockedAccounts = 0;
      int newUsersToday = 0;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();

        if (data['is_verified'] == true) verifiedUsers++;
        if (data['account_locked'] == true) lockedAccounts++;

        final lastLogin = data['last_login'];
        if (lastLogin != null) {
          DateTime loginDate;
          if (lastLogin is Timestamp) {
            loginDate = lastLogin.toDate();
          } else if (lastLogin is String) {
            loginDate = DateTime.tryParse(lastLogin) ?? DateTime(2000);
          } else {
            loginDate = DateTime(2000);
          }
          if (loginDate.isAfter(startOfDay)) activeToday++;
        }

        final createdAt = data['created_at'];
        if (createdAt != null) {
          DateTime createDate;
          if (createdAt is Timestamp) {
            createDate = createdAt.toDate();
          } else if (createdAt is String) {
            createDate = DateTime.tryParse(createdAt) ?? DateTime(2000);
          } else {
            createDate = DateTime(2000);
          }
          if (createDate.isAfter(startOfDay)) newUsersToday++;
        }
      }

      final onlineSnapshot = await _firestore
          .collection('online_users')
          .where('is_online', isEqualTo: true)
          .count()
          .get();
      final onlineNow = onlineSnapshot.count ?? 0;

      return {
        'totalUsers': totalUsers,
        'activeToday': activeToday,
        'onlineNow': onlineNow,
        'verifiedUsers': verifiedUsers,
        'lockedAccounts': lockedAccounts,
        'newUsersToday': newUsersToday,
      };
    } catch (e) {
      return {
        'totalUsers': 0,
        'activeToday': 0,
        'onlineNow': 0,
        'verifiedUsers': 0,
        'lockedAccounts': 0,
        'newUsersToday': 0,
      };
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  bool _isCancelled(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase().trim();
    return status == 'dibatalkan' || status == 'cancelled';
  }

  bool _isAbsensiComplete(Map<String, dynamic> data) {
    final checkOutTime = data['check_out_time'];
    final absensiStatus = data['absensi_status'] as String?;
    if (checkOutTime != null) return true;
    if (absensiStatus == 'selesai' ||
        absensiStatus == 'check_out' ||
        absensiStatus == 'tidak_lembur' ||
        absensiStatus == 'expired') {
      return true;
    }
    return false;
  }

  bool _isNewer(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aUpdated = a['updated_at'];
    final bUpdated = b['updated_at'];
    if (aUpdated == null) return false;
    if (bUpdated == null) return true;

    DateTime aDate, bDate;
    if (aUpdated is Timestamp) {
      aDate = aUpdated.toDate();
    } else if (aUpdated is String) {
      aDate = DateTime.tryParse(aUpdated) ?? DateTime(2000);
    } else {
      return false;
    }

    if (bUpdated is Timestamp) {
      bDate = bUpdated.toDate();
    } else if (bUpdated is String) {
      bDate = DateTime.tryParse(bUpdated) ?? DateTime(2000);
    } else {
      return true;
    }

    return aDate.isAfter(bDate);
  }

  Map<String, dynamic> _getEmptyStats() {
    return {
      'total': 0,
      'pending': 0,
      'approved': 0,
      'rejected': 0,
      'completed': 0,
      'cancelled': 0,
      'pendingHSSE': 0,
      'needAbsensi': 0,
      'riskyCount': 0,
      'perluRevisi': 0,
      'escalated': 0,
      'completedTotalJam': 0.0,
      'completedTotalBiaya': 0.0,
      'totalMitra': 0,
      'hssApproved': 0,
      'hssRejected': 0,
      'totalUsers': 0,
      'activeToday': 0,
      'onlineNow': 0,
      'verifiedUsers': 0,
      'lockedAccounts': 0,
      'newUsersToday': 0,
    };
  }
}