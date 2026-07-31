// lib/core/services/overtime_approval_service.dart
// 🛡️ FINAL FIXED v4: Manager statistics juga include 'selesai'
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/core/services/spkl_generator_service.dart';
import '/core/services/notification_service.dart';

class OvertimeApprovalService {
  // ============ SINGLETON PATTERN ============
  static OvertimeApprovalService? _instance;

  factory OvertimeApprovalService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SpklGeneratorService? spklGenerator,
    NotificationService? notificationService,
  }) {
    _instance ??= OvertimeApprovalService._internal(
      firestore: firestore,
      auth: auth,
      spklGenerator: spklGenerator,
      notificationService: notificationService,
    );
    return _instance!;
  }

  OvertimeApprovalService._internal({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SpklGeneratorService? spklGenerator,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _spklGenerator = spklGenerator ?? SpklGeneratorService(),
        _notificationService = notificationService ?? NotificationService();

  // ============ INJECTED DEPENDENCIES ============
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SpklGeneratorService _spklGenerator;
  final NotificationService _notificationService;

  // ============ KONSTANTA NAMA COLLECTION ============
  static const String collectionPengajuan = 'pengajuan_lembur';
  static const String collectionLemburMitra = 'lembur_mitra';
  static const String collectionUsers = 'users';
  static const String collectionSpkl = 'spkl';
  static const String collectionApprovalLogs = 'approval_logs';
  static const String collectionNotificationsLog = 'notifications_log';
  static const String collectionSpklErrors = 'spkl_errors';

  // ============ STATUS KONSTANTA ============
  static const String statusPending = 'pending';
  static const String statusPendingHSSE = 'pending_hsse';
  static const String statusManagerApproved = 'manager_approved';
  static const String statusApproved = 'disetujui';
  static const String statusRejected = 'ditolak';
  static const String statusSelesai = 'selesai';

  // ============ ROLE KONSTANTA ============
  static const String roleSuperadmin = 'superadmin';
  static const String roleManager = 'manager';
  static const String roleManagerHSSE = 'manager_hsse';

  // ============ ALL PENDING HSSE STATUSES ============
  static const List<String> allPendingHSSEStatuses = [
    'pending_hsse',
    'manager_approval_pending_hsse',
    'manager_approved_pending_hsse',
  ];

  // ============ ALL ACTIVE STATUSES (NOT FINAL) ============
  static const List<String> allActiveStatuses = [
    'pending',
    'manager_approved',
    'pending_hsse',
    'manager_approval_pending_hsse',
    'manager_approved_pending_hsse',
  ];

  // ============ STATUS TRANSISI UNTUK MANAGER FUNGSI ============
  static const List<String> managerActiveStatuses = [
    'pending',
    'pending_hsse',
  ];

  // 🔥 STATUS UNTUK TAB DISETUJUI (disetujui + selesai)
  static const List<String> approvedAndCompletedStatuses = [
    'disetujui',
    'selesai',
  ];

  // ============ RISK LEVELS YANG MEMERLUKAN HSSE ============
  static const List<String> hsseRiskLevels = [
    'high',
    'critical',
    'tinggi',
  ];

  // ============ STATUS FINAL ============
  static const List<String> finalStatuses = [
    'disetujui',
    'ditolak',
  ];

  // 🛡️🛡️🛡️ STATUS EXCLUDED (TIDAK MUNCUL) 🛡️🛡️🛡️
  static const List<String> excludedStatuses = [
    'dibatalkan',
    'canceled',
    'draft',
  ];

  // 🛡️ Helper: cek status excluded
  bool _isExcluded(String? status) {
    if (status == null) return false;
    return excludedStatuses.contains(status.toLowerCase().trim());
  }

  // ===================================================================
  // 🔥🔥🔥 HELPER: AMBIL NAMA MITRA - FULL FALLBACK 🔥🔥🔥
  // ===================================================================
  String _getMitraName(Map<String, dynamic> data) {
    final namaLangsung = data['mitra_nama_lengkap']?.toString() ??
        data['nama_mitra']?.toString() ??
        data['mitra_nama']?.toString() ??
        data['nama_lengkap']?.toString();
    if (namaLangsung != null && namaLangsung.isNotEmpty && namaLangsung != '-') {
      return namaLangsung;
    }

    final mitraData = data['mitra_data'];
    if (mitraData is Map) {
      final nested = mitraData['nama_lengkap']?.toString() ??
          mitraData['nama']?.toString() ??
          mitraData['nama_mitra']?.toString() ??
          mitraData['name']?.toString();
      if (nested != null && nested.isNotEmpty && nested != '-') return nested;
    }

    final userData = data['user_data'];
    if (userData is Map) {
      final nested = userData['nama_lengkap']?.toString() ??
          userData['nama']?.toString() ??
          userData['name']?.toString();
      if (nested != null && nested.isNotEmpty && nested != '-') return nested;
    }

    final detailMitra = data['detail_mitra'];
    if (detailMitra is List && detailMitra.isNotEmpty) {
      final firstMitra = detailMitra.first;
      if (firstMitra is Map) {
        final nested = firstMitra['nama']?.toString() ??
            firstMitra['nama_mitra']?.toString() ??
            firstMitra['nama_lengkap']?.toString() ??
            firstMitra['name']?.toString();
        if (nested != null && nested.isNotEmpty && nested != '-') return nested;
      }
    }

    final createdBy = data['created_by'];
    if (createdBy is Map) {
      final nested = createdBy['nama']?.toString() ??
          createdBy['nama_lengkap']?.toString() ??
          createdBy['name']?.toString();
      if (nested != null && nested.isNotEmpty && nested != '-') return nested;
    }

    final diajukanOleh = data['diajukan_oleh'];
    if (diajukanOleh is Map) {
      final nested = diajukanOleh['nama']?.toString() ??
          diajukanOleh['nama_lengkap']?.toString() ??
          diajukanOleh['name']?.toString();
      if (nested != null && nested.isNotEmpty && nested != '-') return nested;
    }

    final namaPengawas = data['nama_pengawas']?.toString() ??
        data['pengawas_nama_lengkap']?.toString();
    if (namaPengawas != null && namaPengawas.isNotEmpty && namaPengawas != '-') {
      return namaPengawas;
    }

    return 'Unknown';
  }

  // ===================================================================
  // HELPER - Ambil tanggal dari dokumen (standarisasi)
  // ===================================================================
  DateTime _getTanggalFromData(Map<String, dynamic> data) {
    if (data['tanggal'] is Timestamp) {
      return (data['tanggal'] as Timestamp).toDate();
    }
    if (data['tanggal_lembur'] is Timestamp) {
      return (data['tanggal_lembur'] as Timestamp).toDate();
    }
    return DateTime.now();
  }

  // ===================================================================
  // HELPER - Normalisasi field tanggal di dokumen
  // ===================================================================
  Future<void> _normalizeTanggalField(String groupId, Map<String, dynamic> data) async {
    if (data['tanggal'] is Timestamp) return;
    if (data['tanggal_lembur'] is Timestamp) {
      try {
        await _firestore.collection(collectionPengajuan).doc(groupId).update({
          'tanggal': data['tanggal_lembur'],
          '_migrated_tanggal': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('❌ Gagal normalisasi tanggal: $e');
      }
    }
  }

  // ===================================================================
  // HELPER - Validasi role HSSE approver
  // ===================================================================
  Future<bool> _isValidHSSEApprover(String userId) async {
    try {
      final userDoc = await _firestore.collection(collectionUsers).doc(userId).get();
      if (!userDoc.exists) return false;
      final data = userDoc.data()!;
      final actualRole = data['role']?.toString().toLowerCase() ?? '';
      final actualFungsi = data['fungsi']?.toString().toLowerCase() ?? '';
      return actualRole == roleManagerHSSE ||
          (actualRole == roleManager && actualFungsi == 'hsse');
    } catch (e) {
      debugPrint('❌ Error validasi HSSE approver: $e');
      return false;
    }
  }

  // ===================================================================
  // HELPER - Cek orphan lembur_mitra
  // ===================================================================
  Future<List<String>> findOrphanMitraData() async {
    try {
      final mitraSnapshot = await _firestore.collection(collectionLemburMitra).get();
      final uniqueGroupIds = mitraSnapshot.docs
          .map((doc) => doc.data()['group_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet();
      List<String> orphanGroups = [];
      for (final groupId in uniqueGroupIds) {
        final pengajuanDoc = await _firestore
            .collection(collectionPengajuan)
            .doc(groupId)
            .get();
        if (!pengajuanDoc.exists) {
          orphanGroups.add(groupId);
        }
      }
      return orphanGroups;
    } catch (e) {
      debugPrint('❌ Error cek orphan data: $e');
      return [];
    }
  }

  // ===================================================================
  // HELPER - Flag orphan data
  // ===================================================================
  Future<int> flagOrphanMitraData() async {
    try {
      final orphanGroups = await findOrphanMitraData();
      if (orphanGroups.isEmpty) return 0;
      final batch = _firestore.batch();
      int count = 0;
      for (final groupId in orphanGroups) {
        final mitraSnapshot = await _firestore
            .collection(collectionLemburMitra)
            .where('group_id', isEqualTo: groupId)
            .get();
        for (final doc in mitraSnapshot.docs) {
          batch.update(doc.reference, {
            'status': 'orphan',
            'orphan_detected_at': FieldValue.serverTimestamp(),
            'orphan_reason':
                'Tidak ditemukan pengajuan_lembur dengan group_id=$groupId',
          });
          count++;
        }
      }
      if (count > 0) await batch.commit();
      return count;
    } catch (e) {
      debugPrint('❌ Error flag orphan data: $e');
      return 0;
    }
  }

  // ===================================================================
  // APPROVAL LIST (MANAGER) - TETAP pengajuan_lembur (jarang dipakai)
  // ===================================================================
  Stream<List<Map<String, dynamic>>> getApprovalListForManager({
    required String status,
    required String fungsiManager,
  }) {
    return _firestore
        .collection(collectionPengajuan)
        .where('status', isEqualTo: status)
        .where('pengawas_fungsi', isEqualTo: fungsiManager)
        .orderBy('created_at', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> result = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (_isExcluded(data['status']?.toString())) continue;
        Map<String, dynamic> userData = {};
        final pengawasId = data['pengawas_id']?.toString() ?? '';
        if (pengawasId.isNotEmpty) {
          userData = await _getUserData(pengawasId);
        }
        result.add(_enrichData(doc.id, data, userData));
      }
      return result;
    });
  }

  // ===================================================================
  // 🔥 MANAGER - PENDING (MIGRASI KE lembur_mitra)
  // ===================================================================
  Stream<List<Map<String, dynamic>>> getPendingWithTransitionForManager({
    required String fungsiManager,
    String? searchQuery,
  }) {
    return _firestore
        .collection(collectionLemburMitra)
        .where('pengawas_fungsi', isEqualTo: fungsiManager)
        .where('status', whereIn: managerActiveStatuses)
        .orderBy('created_at', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> result = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (_isExcluded(data['status']?.toString())) continue;

        if (searchQuery != null && searchQuery.isNotEmpty) {
          final nama = _getMitraName(data).toLowerCase();
          final groupId = doc.id.toLowerCase();
          final searchLower = searchQuery.toLowerCase();
          if (!nama.contains(searchLower) && !groupId.contains(searchLower)) {
            continue;
          }
        }

        Map<String, dynamic> userData = {};
        final pengawasId = data['diajukan_oleh_id']?.toString() ?? data['pengawas_id']?.toString() ?? '';
        if (pengawasId.isNotEmpty) {
          userData = await _getUserData(pengawasId);
        }

        final enriched = _enrichData(doc.id, data, userData);

        final status = data['status']?.toString() ?? '';
        final isForwardedToHSSE = status == statusPendingHSSE;
        final fungsiApproverName = isForwardedToHSSE
            ? (data['approved_by_name']?.toString() ?? 'Manager Fungsi')
            : null;

        enriched.addAll({
          'is_forwarded_to_hsse': isForwardedToHSSE,
          'is_pending_hsse': isForwardedToHSSE,
          'fungsi_approver_name': fungsiApproverName,
          'is_approved_by_fungsi': isForwardedToHSSE,
          'approved_by_fungsi_name': fungsiApproverName,
        });

        result.add(enriched);
      }
      return result;
    });
  }

  // ===================================================================
  // 🔥🔥🔥 HELPER: ENRICH DATA - KONSISTEN UNTUK SEMUA QUERY 🔥🔥🔥
  // ===================================================================
  Map<String, dynamic> _enrichData(
    String docId,
    Map<String, dynamic> data,
    Map<String, dynamic> userData,
  ) {
    final namaMitra = _getMitraName(data);

    return {
      'id': docId,
      'docId': docId,
      'group_id': data['group_id'] ?? docId,
      ...data,
      'tanggal': _getTanggalFromData(data),
      'is_group_leader': true,

      // ✅ Field pengawas dari userData
      'pengawas_email': userData['email'] ?? data['pengawas_email']?.toString() ?? '',
      'pengawas_phone': userData['phone'] ?? data['pengawas_phone']?.toString() ?? '',
      'pengawas_nip': userData['nip'] ?? data['pengawas_nip']?.toString() ?? '',
      'pengawas_nama_lengkap': userData['nama_lengkap']?.toString() ?? data['nama_pengawas']?.toString() ?? '',

      // ✅ Field mitra - KONSISTEN untuk semua role
      'nama_mitra': namaMitra,
      'mitra_nama_lengkap': namaMitra,
      'mitra_nama': namaMitra,
      'nama_lengkap': namaMitra,

      // ✅ Field tambahan dari data asli
      'mitra_fungsi': data['mitra_fungsi']?.toString() ?? data['fungsi_mitra']?.toString() ?? '',
      'mitra_email': data['mitra_email']?.toString() ?? data['email']?.toString() ?? '',
    };
  }

  // ===================================================================
  // 🔥🔥🔥 APPROVAL LIST (SUPERADMIN) - FINAL FIX v3 🔥🔥🔥
  // ===================================================================
  // Di method getApprovalListForSuperadmin, cari bagian ini:
Stream<List<Map<String, dynamic>>> getApprovalListForSuperadmin({
  required String status,
  String? fungsiFilter,
}) {
  debugPrint('🔵 Superadmin query: status="$status", filter="$fungsiFilter"');

  if (status == 'pending') {
    return _getSuperadminPendingSplit(fungsiFilter);
  }

  if (status == 'disetujui') {
    return _getSuperadminApprovedAndCompleted(fungsiFilter);
  }

  // 🔥 PERBAIKAN: Untuk 'ditolak', TETAP gunakan fungsiFilter!
  Query<Map<String, dynamic>> query = _firestore
      .collection(collectionLemburMitra)
      .where('status', isEqualTo: status)
      .orderBy('created_at', descending: true);

  // ✅ FILTER BERDASARKAN FUNGSI JIKA ADA
  if (fungsiFilter != null &&
      fungsiFilter.isNotEmpty &&
      fungsiFilter != 'semua') {
    query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
  }

  return query.snapshots().asyncMap((snapshot) async {
    final List<Map<String, dynamic>> result = [];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      // 🛡️ JANGAN exclude data 'ditolak'!
      if (_isExcluded(data['status']?.toString())) continue;

      Map<String, dynamic> userData = {};
      final pengawasId = data['diajukan_oleh_id']?.toString() ?? data['pengawas_id']?.toString() ?? '';
      if (pengawasId.isNotEmpty) {
        userData = await _getUserData(pengawasId);
      }

      result.add(_enrichData(doc.id, data, userData));
    }
    debugPrint('🔵 Superadmin result ($status): ${result.length} docs');
    return result;
  });
}

  // ===================================================================
  // 🔥🔥🔥 HELPER: Superadmin query untuk Disetujui + Selesai 🔥🔥🔥
  // ===================================================================
  Stream<List<Map<String, dynamic>>> _getSuperadminApprovedAndCompleted(
      String? fungsiFilter) {
    debugPrint('🔵 Superadmin DISETUJUI: query disetujui + selesai');

    Query<Map<String, dynamic>> buildQuery(String statusValue) {
      Query<Map<String, dynamic>> query = _firestore
          .collection(collectionLemburMitra)
          .where('status', isEqualTo: statusValue)
          .orderBy('created_at', descending: true);

      if (fungsiFilter != null &&
          fungsiFilter.isNotEmpty &&
          fungsiFilter != 'semua') {
        query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
      }
      return query;
    }

    final List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams = [
      buildQuery('disetujui').snapshots(),
      buildQuery('selesai').snapshots(),
    ];

    return _combineSnapshots(streams).asyncMap((snapshots) async {
      final List<Map<String, dynamic>> result = [];

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (_isExcluded(data['status']?.toString())) continue;

          Map<String, dynamic> userData = {};
          final pengawasId = data['diajukan_oleh_id']?.toString() ?? data['pengawas_id']?.toString() ?? '';
          if (pengawasId.isNotEmpty) {
            userData = await _getUserData(pengawasId);
          }

          final enriched = _enrichData(doc.id, data, userData);
          enriched['is_completed'] = (data['status']?.toString() == 'selesai');

          result.add(enriched);
        }
      }

      result.sort((a, b) {
        final aTime = a['created_at'];
        final bTime = b['created_at'];
        return _compareTimestamps(bTime, aTime);
      });

      debugPrint('🔵 Superadmin DISETUJUI+SELESAI result: ${result.length} docs');
      return result;
    });
  }

  // ===================================================================
  // 🔥 HELPER: Superadmin pending split query
  // ===================================================================
  Stream<List<Map<String, dynamic>>> _getSuperadminPendingSplit(String? fungsiFilter) {
    debugPrint('🔵 Superadmin PENDING: split query');

    Query<Map<String, dynamic>> buildQuery(String statusValue) {
      Query<Map<String, dynamic>> query = _firestore
          .collection(collectionLemburMitra)
          .where('status', isEqualTo: statusValue)
          .orderBy('created_at', descending: true);

      if (fungsiFilter != null &&
          fungsiFilter.isNotEmpty &&
          fungsiFilter != 'semua') {
        query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
      }
      return query;
    }

    final List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams =
        managerActiveStatuses.map((s) => buildQuery(s).snapshots()).toList();

    return _combineSnapshots(streams).asyncMap((snapshots) async {
      final List<Map<String, dynamic>> result = [];

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (_isExcluded(data['status']?.toString())) continue;

          Map<String, dynamic> userData = {};
          final pengawasId = data['diajukan_oleh_id']?.toString() ?? data['pengawas_id']?.toString() ?? '';
          if (pengawasId.isNotEmpty) {
            userData = await _getUserData(pengawasId);
          }

          final enriched = _enrichData(doc.id, data, userData);

          final docStatus = data['status']?.toString() ?? '';
          final isForwardedToHSSE = docStatus == statusPendingHSSE;
          final fungsiApproverName = isForwardedToHSSE
              ? (data['approved_by_name']?.toString() ?? 'Manager Fungsi')
              : null;

          enriched.addAll({
            'is_forwarded_to_hsse': isForwardedToHSSE,
            'is_pending_hsse': isForwardedToHSSE,
            'fungsi_approver_name': fungsiApproverName,
            'is_approved_by_fungsi': isForwardedToHSSE,
            'approved_by_fungsi_name': fungsiApproverName,
          });

          result.add(enriched);
        }
      }

      result.sort((a, b) {
        final aTime = a['created_at'];
        final bTime = b['created_at'];
        return _compareTimestamps(bTime, aTime);
      });

      debugPrint('🔵 Superadmin PENDING result: ${result.length} docs');
      return result;
    });
  }

  // ===================================================================
  // 🔥 HELPER: Combine multiple QuerySnapshot streams
  // ===================================================================
  Stream<List<QuerySnapshot<Map<String, dynamic>>>> _combineSnapshots(
      List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams) {
    if (streams.isEmpty) {
      return Stream.value([]);
    }

    final controller =
        StreamController<List<QuerySnapshot<Map<String, dynamic>>>>();
    final subscriptions = <StreamSubscription>[];
    final latestSnapshots = <int, QuerySnapshot<Map<String, dynamic>>>{};
    bool isClosed = false;

    void emitIfReady() {
      if (!isClosed && latestSnapshots.length == streams.length) {
        final ordered = List<QuerySnapshot<Map<String, dynamic>>>.generate(
          streams.length,
          (i) => latestSnapshots[i]!,
        );
        controller.add(ordered);
      }
    }

    for (int i = 0; i < streams.length; i++) {
      final index = i;
      subscriptions.add(streams.elementAt(i).listen(
        (snapshot) {
          latestSnapshots[index] = snapshot;
          emitIfReady();
        },
        onError: (error) {
          if (!isClosed) {
            controller.addError(error);
          }
        },
      ));
    }

    controller.onCancel = () {
      isClosed = true;
      for (final sub in subscriptions) {
        sub.cancel();
      }
      controller.close();
    };

    return controller.stream;
  }

  // ===================================================================
  // 🔥 MANAGER HSSE - PENDING HSSE LIST
  // ===================================================================
  Stream<List<Map<String, dynamic>>> getHssePendingList({
    String? fungsiFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('status', whereIn: allPendingHSSEStatuses)
        .orderBy('created_at', descending: true);

    if (fungsiFilter != null &&
        fungsiFilter.isNotEmpty &&
        fungsiFilter != 'semua') {
      query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
    }

    return query.snapshots().asyncMap((snapshot) async {
      final List<Map<String, dynamic>> result = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString() ?? '';
        if (_isExcluded(status) || finalStatuses.contains(status)) continue;

        Map<String, dynamic> userData = {};
        final pengawasId = data['diajukan_oleh_id']?.toString() ?? data['pengawas_id']?.toString() ?? '';
        if (pengawasId.isNotEmpty) {
          userData = await _getUserData(pengawasId);
        }

        final enriched = _enrichData(doc.id, data, userData);
        enriched.addAll({
          'is_flagged_for_hsse': true,
          'is_pending_hsse': true,
          'is_forwarded_to_hsse': true,
          'fungsi_approver_name': data['approved_by_name']?.toString() ?? 'Manager Fungsi',
        });
        result.add(enriched);
      }
      return result;
    });
  }

  // ===================================================================
  // 🔥 MANAGER HSSE - SEMUA RISKY
  // ===================================================================
  Stream<List<Map<String, dynamic>>> getAllRiskyOvertimeForHSSE({
    String? searchQuery,
    String? fungsiFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('status', whereIn: allActiveStatuses)
        .orderBy('created_at', descending: true);

    return query.snapshots().asyncMap((snapshot) async {
      final List<Map<String, dynamic>> result = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString() ?? '';
        final pengawasFungsi = data['pengawas_fungsi']?.toString() ?? '';

        if (_isExcluded(status) || finalStatuses.contains(status)) continue;
        if (fungsiFilter != null && fungsiFilter.isNotEmpty && fungsiFilter != 'semua') {
          if (pengawasFungsi != fungsiFilter) continue;
        }

        final bool isPendingHSSE = allPendingHSSEStatuses.any((s) => status == s);
        if (!isPendingHSSE) continue;

        if (searchQuery != null && searchQuery.isNotEmpty) {
          final nama = _getMitraName(data).toLowerCase();
          final groupId = doc.id.toLowerCase();
          final fungsi = pengawasFungsi.toLowerCase();
          final searchLower = searchQuery.toLowerCase();
          if (!nama.contains(searchLower) && !groupId.contains(searchLower) && !fungsi.contains(searchLower)) continue;
        }

        Map<String, dynamic> userData = {};
        final pengawasId = data['diajukan_oleh_id']?.toString() ?? data['pengawas_id']?.toString() ?? '';
        if (pengawasId.isNotEmpty) userData = await _getUserData(pengawasId);

        final enriched = _enrichData(doc.id, data, userData);
        enriched.addAll({
          'is_flagged_for_hsse': true,
          'is_pending_hsse': true,
          'is_forwarded_to_hsse': true,
          'fungsi_approver_name': data['approved_by_name']?.toString() ?? 'Manager Fungsi',
        });
        result.add(enriched);
      }

      result.sort((a, b) {
        final aRisk = _getRiskPriority(a['risk_level']?.toString() ?? '');
        final bRisk = _getRiskPriority(b['risk_level']?.toString() ?? '');
        return aRisk.compareTo(bRisk);
      });
      return result;
    });
  }

  // ===================================================================
  // 🔥 APPROVED LIST HSSE
  // ===================================================================
  Stream<List<Map<String, dynamic>>> getApprovedListForHSSE({
    String? searchQuery,
    String? fungsiFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('status', isEqualTo: statusApproved)
        .orderBy('created_at', descending: true);
    if (fungsiFilter != null && fungsiFilter.isNotEmpty && fungsiFilter != 'semua') {
      query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
    }
    return query.snapshots().asyncMap((snapshot) async {
      final List<Map<String, dynamic>> result = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (_isExcluded(data['status']?.toString())) continue;
        if (data['hsse_validated'] != true) continue;
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final nama = _getMitraName(data).toLowerCase();
          final groupId = doc.id.toLowerCase();
          final fungsi = (data['pengawas_fungsi'] ?? '').toString().toLowerCase();
          final searchLower = searchQuery.toLowerCase();
          if (!nama.contains(searchLower) && !groupId.contains(searchLower) && !fungsi.contains(searchLower)) continue;
        }
        Map<String, dynamic> userData = {};
        final pengawasId = data['diajukan_oleh_id']?.toString() ?? data['pengawas_id']?.toString() ?? '';
        if (pengawasId.isNotEmpty) userData = await _getUserData(pengawasId);
        final enriched = _enrichData(doc.id, data, userData);
        enriched['is_hsse_validated'] = true;
        result.add(enriched);
      }
      result.sort((a, b) {
        final aTime = a['hsse_approved_at'] ?? a['approved_at'] ?? a['created_at'];
        final bTime = b['hsse_approved_at'] ?? b['approved_at'] ?? b['created_at'];
        return _compareTimestamps(bTime, aTime);
      });
      return result;
    });
  }

  // ===================================================================
  // 🔥 REJECTED LIST HSSE
  // ===================================================================
  Stream<List<Map<String, dynamic>>> getRejectedListForHSSE({
    String? searchQuery,
    String? fungsiFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionLemburMitra)
        .where('status', isEqualTo: statusRejected)
        .orderBy('created_at', descending: true);
    if (fungsiFilter != null && fungsiFilter.isNotEmpty && fungsiFilter != 'semua') {
      query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
    }
    return query.snapshots().asyncMap((snapshot) async {
      final List<Map<String, dynamic>> result = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (_isExcluded(data['status']?.toString())) continue;
        if (data['hsse_validated'] != true) continue;
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final nama = _getMitraName(data).toLowerCase();
          final groupId = doc.id.toLowerCase();
          final fungsi = (data['pengawas_fungsi'] ?? '').toString().toLowerCase();
          final searchLower = searchQuery.toLowerCase();
          if (!nama.contains(searchLower) && !groupId.contains(searchLower) && !fungsi.contains(searchLower)) continue;
        }
        Map<String, dynamic> userData = {};
        final pengawasId = data['diajukan_oleh_id']?.toString() ?? data['pengawas_id']?.toString() ?? '';
        if (pengawasId.isNotEmpty) userData = await _getUserData(pengawasId);
        final enriched = _enrichData(doc.id, data, userData);
        enriched['is_hsse_validated'] = true;
        result.add(enriched);
      }
      result.sort((a, b) {
        final aTime = a['hsse_approved_at'] ?? a['rejected_at'] ?? a['created_at'];
        final bTime = b['hsse_approved_at'] ?? b['rejected_at'] ?? b['created_at'];
        return _compareTimestamps(bTime, aTime);
      });
      return result;
    });
  }

  // ===================================================================
  // ✅ HELPER: Cek apakah data terkait HSSE
  // ===================================================================
  bool _isHSSERelated(Map<String, dynamic> data) {
    final status = data['status']?.toString().toLowerCase() ?? '';
    if (finalStatuses.contains(status)) return false;
    if (allPendingHSSEStatuses.any((s) => status == s)) return true;
    if (allActiveStatuses.contains(status)) {
      if (data['requires_hsse_approval'] == true) return true;
    }
    final riskLevel = data['risk_level']?.toString().toLowerCase() ?? '';
    if (hsseRiskLevels.contains(riskLevel)) return true;
    if (data['lokasi'] is Map) {
      if (data['lokasi']['is_outside_radius'] == true) return true;
    }
    if (_parseDouble(data['total_jam_desimal']) > 8) return true;
    final urgensi = data['urgensi']?.toString().toLowerCase() ?? '';
    if (urgensi == 'kritis' || urgensi == 'critical' || urgensi == 'tinggi' || urgensi == 'high') return true;
    if (data['jenis_lembur']?.toString().toLowerCase() == 'hari_libur') return true;
    if (data['is_override'] == true) return true;
    if (data['is_risky'] == true) return true;
    return false;
  }

  // ===================================================================
  // PUBLIC HELPER: Haruskah memerlukan review HSSE?
  // ===================================================================
  Future<bool> shouldRequireHSSEReview(String groupId) async {
    try {
      var doc = await _firestore.collection(collectionLemburMitra).doc(groupId).get();
      if (!doc.exists) {
        doc = await _firestore.collection(collectionPengajuan).doc(groupId).get();
      }
      if (!doc.exists) return false;
      return _isHSSERelated(doc.data()!);
    } catch (e) {
      debugPrint('❌ Should require HSSE error: $e');
      return false;
    }
  }

  // ===================================================================
  // SELF-HEAL: Normalisasi status legacy
  // ===================================================================
  Future<String> _normalizeLegacyStatus(String groupId, String currentStatus) async {
    const legacyToStandard = <String, String>{
      'manager_approved_pending_hsse': statusPendingHSSE,
      'manager_approval_pending_hsse': statusPendingHSSE,
    };
    final normalized = legacyToStandard[currentStatus];
    if (normalized == null) return currentStatus;
    try {
      await _firestore.collection(collectionPengajuan).doc(groupId).update({
        'status': normalized,
        'status_legacy_value': currentStatus,
        'status_normalized_at': FieldValue.serverTimestamp(),
      });
      return normalized;
    } catch (e) {
      return currentStatus;
    }
  }

  // ===================================================================
  // HELPER: Parse double
  // ===================================================================
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // ===================================================================
  // HELPER: Priority risk level
  // ===================================================================
  int _getRiskPriority(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'critical': return 0;
      case 'high': case 'tinggi': return 1;
      case 'medium': case 'sedang': return 2;
      case 'low': case 'rendah': return 3;
      default: return 4;
    }
  }

  // ===================================================================
  // 🔥🔥🔥 STATISTICS (MANAGER) - FIXED: Include 'selesai' 🔥🔥🔥
  // ===================================================================
  Future<Map<String, dynamic>> getStatisticsForManager(String fungsiManager) async {
    try {
      final pendingSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('status', isEqualTo: statusPending)
          .where('pengawas_fungsi', isEqualTo: fungsiManager)
          .get();
      final pendingHsseSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('status', whereIn: allPendingHSSEStatuses)
          .where('pengawas_fungsi', isEqualTo: fungsiManager)
          .get();
      
      // 🔥 FIX: Gunakan whereIn untuk 'disetujui' DAN 'selesai'
      final approvedSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('status', whereIn: approvedAndCompletedStatuses)
          .where('pengawas_fungsi', isEqualTo: fungsiManager)
          .get();
      
      final rejectedSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('status', isEqualTo: statusRejected)
          .where('pengawas_fungsi', isEqualTo: fungsiManager)
          .get();

      return {
        'totalPending': pendingSnapshot.docs
            .where((d) => !_isExcluded(d.data()['status']?.toString())).length,
        'totalPendingHSSE': pendingHsseSnapshot.docs
            .where((d) => !_isExcluded(d.data()['status']?.toString())).length,
        'totalApproved': approvedSnapshot.docs.length,
        'totalRejected': rejectedSnapshot.docs.length,
      };
    } catch (e) {
      debugPrint('❌ Statistics error: $e');
      return {'totalPending': 0, 'totalPendingHSSE': 0, 'totalApproved': 0, 'totalRejected': 0};
    }
  }

  // ===================================================================
  // 🔥 STATISTICS (MANAGER HSSE)
  // ===================================================================
  Future<Map<String, dynamic>> getStatisticsForHSSEManager({String? fungsiFilter}) async {
    try {
      Query<Map<String, dynamic>> applyFilter(Query<Map<String, dynamic>> query) {
        if (fungsiFilter != null && fungsiFilter.isNotEmpty && fungsiFilter != 'semua') {
          return query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
        }
        return query;
      }

      final pendingHsseSnapshot = await applyFilter(
        _firestore.collection(collectionLemburMitra).where('status', whereIn: allPendingHSSEStatuses),
      ).get();

      final allActiveSnapshot = await applyFilter(
        _firestore.collection(collectionLemburMitra).where('status', whereIn: allActiveStatuses),
      ).get();

      final riskyNotFlagged = allActiveSnapshot.docs.where((doc) {
        final data = doc.data();
        if (_isExcluded(data['status']?.toString())) return false;
        final status = data['status']?.toString() ?? '';
        final isAlreadyFlagged = allPendingHSSEStatuses.contains(status);
        return !isAlreadyFlagged && _isHSSERelated(data);
      }).toList();

      final approvedSnapshot = await applyFilter(
        _firestore.collection(collectionLemburMitra).where('status', isEqualTo: statusApproved),
      ).get();

      final rejectedSnapshot = await applyFilter(
        _firestore.collection(collectionLemburMitra).where('status', isEqualTo: statusRejected),
      ).get();

      int criticalCount = 0, highCount = 0, mediumCount = 0, lowCount = 0;
      final allPendingDocs = [
        ...pendingHsseSnapshot.docs.where((d) => !_isExcluded(d.data()['status']?.toString())),
        ...riskyNotFlagged
      ];

      for (final doc in allPendingDocs) {
        final riskLevel = (doc.data()['risk_level'] ?? '').toString().toLowerCase();
        switch (riskLevel) {
          case 'critical': criticalCount++; break;
          case 'high': case 'tinggi': highCount++; break;
          case 'medium': case 'sedang': mediumCount++; break;
          default: lowCount++;
        }
      }

      Map<String, int> perFungsi = {};
      for (final doc in allPendingDocs) {
        final fungsi = (doc.data()['pengawas_fungsi'] ?? 'unknown').toString();
        perFungsi[fungsi] = (perFungsi[fungsi] ?? 0) + 1;
      }

      return {
        'totalPending': riskyNotFlagged.length,
        'totalPendingHSSE': pendingHsseSnapshot.docs.where((d) => !_isExcluded(d.data()['status']?.toString())).length,
        'totalApproved': approvedSnapshot.docs.length,
        'totalRejected': rejectedSnapshot.docs.length,
        'criticalCount': criticalCount,
        'highCount': highCount,
        'mediumCount': mediumCount,
        'lowCount': lowCount,
        'perFungsi': perFungsi,
        'totalAllPending': pendingHsseSnapshot.docs.where((d) => !_isExcluded(d.data()['status']?.toString())).length + riskyNotFlagged.length,
      };
    } catch (e) {
      debugPrint('❌ HSSE Manager statistics error: $e');
      return {'totalPending': 0, 'totalPendingHSSE': 0, 'totalApproved': 0, 'totalRejected': 0, 'criticalCount': 0, 'highCount': 0, 'mediumCount': 0, 'lowCount': 0, 'perFungsi': {}, 'totalAllPending': 0};
    }
  }

  // ===================================================================
  // 🔥🔥🔥 STATISTICS (SUPERADMIN) - Include 'selesai' 🔥🔥🔥
  // ===================================================================
  Future<Map<String, dynamic>> getStatisticsForSuperadmin({String? fungsiFilter}) async {
    try {
      Query<Map<String, dynamic>> applyFilter(Query<Map<String, dynamic>> query) {
        if (fungsiFilter != null && fungsiFilter.isNotEmpty && fungsiFilter != 'semua') {
          return query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
        }
        return query;
      }

      final pendingSnapshot = await applyFilter(
        _firestore.collection(collectionLemburMitra).where('status', isEqualTo: statusPending),
      ).get();

      final pendingHsseSnapshot = await applyFilter(
        _firestore.collection(collectionLemburMitra).where('status', whereIn: allPendingHSSEStatuses),
      ).get();

      // 🔥 Include 'selesai' dalam perhitungan approved
      final approvedSnapshot = await applyFilter(
        _firestore.collection(collectionLemburMitra).where('status', whereIn: approvedAndCompletedStatuses),
      ).get();

      final rejectedSnapshot = await applyFilter(
        _firestore.collection(collectionLemburMitra).where('status', isEqualTo: statusRejected),
      ).get();

      Map<String, int> perFungsi = {};
      for (final doc in [...pendingSnapshot.docs, ...pendingHsseSnapshot.docs]) {
        if (_isExcluded(doc.data()['status']?.toString())) continue;
        final fungsi = (doc.data()['pengawas_fungsi'] ?? 'unknown').toString();
        perFungsi[fungsi] = (perFungsi[fungsi] ?? 0) + 1;
      }

      return {
        'totalPending': pendingSnapshot.docs.where((d) => !_isExcluded(d.data()['status']?.toString())).length,
        'totalPendingHSSE': pendingHsseSnapshot.docs.where((d) => !_isExcluded(d.data()['status']?.toString())).length,
        'totalApproved': approvedSnapshot.docs.length,
        'totalRejected': rejectedSnapshot.docs.length,
        'perFungsi': perFungsi,
      };
    } catch (e) {
      debugPrint('❌ Superadmin statistics error: $e');
      return {'totalPending': 0, 'totalPendingHSSE': 0, 'totalApproved': 0, 'totalRejected': 0, 'perFungsi': {}};
    }
  }

  // ===================================================================
  // ✅ CEK RISIKO
  // ===================================================================
  Future<RiskAssessment> checkRiskLevel(String groupId) async {
    try {
      var doc = await _firestore.collection(collectionLemburMitra).doc(groupId).get();
      if (!doc.exists) {
        doc = await _firestore.collection(collectionPengajuan).doc(groupId).get();
      }
      if (!doc.exists) return RiskAssessment(hasRisk: false, riskLevel: 'none');

      final data = doc.data()!;
      final status = data['status']?.toString() ?? '';
      if (finalStatuses.contains(status) || _isExcluded(status)) {
        return RiskAssessment(hasRisk: false, riskLevel: 'none', riskFactors: [], requiresHsseApproval: false);
      }

      final urgensi = data['urgensi']?.toString().toLowerCase() ?? '';
      final isUrgensiTinggi = urgensi == 'kritis' || urgensi == 'critical' || urgensi == 'tinggi' || urgensi == 'high';

      if (data['risk_level'] != null && data['risk_factors'] != null && data['risk_level'].toString().isNotEmpty) {
        final existingRiskLevel = data['risk_level'].toString().toLowerCase();
        final existingRiskFactors = (data['risk_factors'] as List?)?.cast<String>() ?? [];
        if (isUrgensiTinggi && !hsseRiskLevels.contains(existingRiskLevel)) {
          return RiskAssessment(hasRisk: true, riskLevel: 'high', riskFactors: [...existingRiskFactors, 'Pengajuan dengan urgensi $urgensi'], requiresHsseApproval: true);
        }
        return RiskAssessment(hasRisk: hsseRiskLevels.contains(existingRiskLevel), riskLevel: existingRiskLevel, riskFactors: existingRiskFactors, requiresHsseApproval: hsseRiskLevels.contains(existingRiskLevel));
      }

      final jenisLembur = data['jenis_lembur']?.toString().toLowerCase() ?? '';
      final isOutside = data['lokasi']?['is_outside_radius'] ?? false;
      final totalJam = _parseDouble(data['total_jam_desimal']);

      bool hasRisk = false;
      String riskLevel = 'low';
      List<String> riskFactors = [];

      if (isOutside) { hasRisk = true; riskLevel = 'high'; riskFactors.add('Lokasi di luar radius aman'); }
      if (jenisLembur == 'hari_libur') { hasRisk = true; riskLevel = riskLevel == 'high' ? 'critical' : 'medium'; riskFactors.add('Lembur pada hari libur'); }
      if (totalJam > 8) { hasRisk = true; if (riskLevel == 'high') { riskLevel = 'critical'; } else if (riskLevel != 'critical') { riskLevel = 'medium'; } riskFactors.add('Durasi lembur lebih dari 8 jam (${totalJam.toStringAsFixed(1)} jam)'); }
      if (isUrgensiTinggi) { hasRisk = true; riskLevel = 'high'; riskFactors.add('Pengajuan dengan urgensi $urgensi'); }
      if (data['is_override'] == true) { hasRisk = true; riskLevel = 'critical'; riskFactors.add('Melebihi batas jam lembur bulanan'); }

      final requiresHsse = hsseRiskLevels.contains(riskLevel);
      return RiskAssessment(hasRisk: hasRisk, riskLevel: riskLevel, riskFactors: riskFactors, requiresHsseApproval: requiresHsse);
    } catch (e) {
      debugPrint('❌ Check risk error: $e');
      return RiskAssessment(hasRisk: false, riskLevel: 'none');
    }
  }

  // ===================================================================
  // GET USER DATA
  // ===================================================================
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      if (userId.isEmpty) return {};
      final doc = await _firestore.collection(collectionUsers).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final userData = doc.data()!;
        return {
          'email': userData['email']?.toString() ?? '',
          'phone': userData['phone']?.toString() ?? userData['no_hp']?.toString() ?? '',
          'nip': userData['nip']?.toString() ?? userData['employee_id']?.toString() ?? '',
          'nama_lengkap': userData['nama_lengkap']?.toString() ?? '',
          'role': userData['role']?.toString() ?? '',
          'fungsi': userData['fungsi']?.toString() ?? '',
          'status_akun': userData['status_akun']?.toString() ?? '',
        };
      }
      return {};
    } catch (e) {
      debugPrint('❌ Error getting user data: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getUserData(String userId) async => await _getUserData(userId);

  Future<Map<String, dynamic>> getUserDataByEmail(String email) async {
    try {
      if (email.isEmpty) return {};
      final query = await _firestore.collection(collectionUsers).where('email', isEqualTo: email.toLowerCase().trim()).limit(1).get();
      if (query.docs.isNotEmpty) {
        final userData = query.docs.first.data();
        return {
          'id': query.docs.first.id,
          'email': userData['email']?.toString() ?? '',
          'phone': userData['phone']?.toString() ?? userData['no_hp']?.toString() ?? '',
          'nip': userData['nip']?.toString() ?? userData['employee_id']?.toString() ?? '',
          'nama_lengkap': userData['nama_lengkap']?.toString() ?? '',
          'role': userData['role']?.toString() ?? '',
          'fungsi': userData['fungsi']?.toString() ?? '',
          'status_akun': userData['status_akun']?.toString() ?? '',
        };
      }
      return {};
    } catch (e) {
      debugPrint('❌ Error getting user data by email: $e');
      return {};
    }
  }

  // ===================================================================
  // 🔥 DETAIL PENGAJUAN
  // ===================================================================
  Future<Map<String, dynamic>?> getDetailPengajuan(String groupId) async {
    try {
      var doc = await _firestore.collection(collectionLemburMitra).doc(groupId).get();
      if (!doc.exists) {
        doc = await _firestore.collection(collectionPengajuan).doc(groupId).get();
      }
      if (!doc.exists) return null;

      final data = doc.data()!;

      final mitraSnapshot = await _firestore
          .collection(collectionLemburMitra)
          .where('group_id', isEqualTo: groupId)
          .get();

      final mitraList = mitraSnapshot.docs.map((d) => {
            'id': d.id, 'docId': d.id, ...d.data(), 'is_group_leader': false
          }).toList();

      Map<String, dynamic> userData = {};
      final pengawasId = data['diajukan_oleh_id']?.toString() ?? data['pengawas_id']?.toString() ?? '';
      if (pengawasId.isNotEmpty) userData = await _getUserData(pengawasId);

      return {
        'id': doc.id, 'docId': doc.id, 'group_id': data['group_id'] ?? doc.id,
        ...data,
        'is_group_leader': true,
        'tanggal': _getTanggalFromData(data),
        'mitra_list': mitraList,
        'pengawas_email': userData['email'] ?? '',
        'pengawas_phone': userData['phone'] ?? '',
        'pengawas_nip': userData['nip'] ?? '',
        'pengawas_nama_lengkap': userData['nama_lengkap'] ?? _getMitraName(data),
        'pengawas_role': userData['role'] ?? '',
        'pengawas_status': userData['status_akun'] ?? '',
        'pengawas_id': pengawasId,
      };
    } catch (e) {
      debugPrint('❌ Detail error: $e');
      return null;
    }
  }

  // ===================================================================
  // ✅ PROCESS APPROVAL
  // ===================================================================
  Future<ApprovalResult> processApproval({
    required String groupId,
    required bool isApprove,
    required String notes,
    required String userRole,
    String? userFungsi,
    String? approverName,
    String? approverEmail,
    String? approverId,
    bool skipHSSE = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak ditemukan');

      final validRoles = [roleManager, roleSuperadmin, roleManagerHSSE];
      if (!validRoles.contains(userRole)) throw Exception('Role tidak memiliki akses approval');

      final pengajuanDoc = await _firestore.collection(collectionPengajuan).doc(groupId).get();
      if (!pengajuanDoc.exists) throw Exception('Data pengajuan tidak ditemukan');

      final pengajuanData = pengajuanDoc.data()!;
      String currentStatus = pengajuanData['status']?.toString() ?? statusPending;

      if (_isExcluded(currentStatus)) {
        throw Exception('Pengajuan sudah ${currentStatus == 'dibatalkan' ? 'dibatalkan oleh pengawas' : 'tidak valid'}');
      }

      final pengawasFungsi = pengajuanData['pengawas_fungsi']?.toString() ?? '';
      currentStatus = await _normalizeLegacyStatus(groupId, currentStatus);

      if (userRole == roleManagerHSSE) {
        final isActionableForHsse = allPendingHSSEStatuses.contains(currentStatus) || pengajuanData['requires_hsse_approval'] == true;
        if (!isActionableForHsse) throw Exception('Pengajuan tidak memerlukan validasi K3');
      } else if (userRole == roleManager) {
        if (currentStatus != statusPending) throw Exception('Pengajuan sudah diproses sebelumnya');
      }

      final groupLeader = {
        'docId': pengajuanDoc.id, 'id': pengajuanDoc.id, 'group_id': pengajuanDoc.id,
        ...pengajuanData, 'status': currentStatus, 'is_group_leader': true,
        'tanggal': _getTanggalFromData(pengajuanData),
      };

      final riskAssessment = await checkRiskLevel(groupId);
      final bool needsHsseApproval = skipHSSE ? false : (riskAssessment.requiresHsseApproval || pengajuanData['requires_hsse_approval'] == true || pengajuanData['need_hsse_confirmation'] == true);

      String newStatus, approvalLevel;
      if (isApprove) {
        if (userRole == roleManagerHSSE) { newStatus = statusApproved; approvalLevel = 'manager_hsse_final'; }
        else if (needsHsseApproval && userRole != roleSuperadmin) { newStatus = statusPendingHSSE; approvalLevel = 'manager_approved_pending_hsse'; }
        else { newStatus = statusApproved; approvalLevel = 'final'; }
      } else {
        newStatus = statusRejected;
        approvalLevel = userRole == roleManagerHSSE ? 'rejected_by_manager_hsse' : 'rejected';
      }

      if (userRole == roleManager && userFungsi != null && userFungsi.isNotEmpty) {
        if (userFungsi != pengawasFungsi) throw Exception('Manager tidak memiliki akses ke fungsi $pengawasFungsi');
      }
      if (userRole == roleManagerHSSE) {
        if (!await _isValidHSSEApprover(user.uid)) throw Exception('Hanya Manager HSSE yang bisa melakukan validasi');
      }

      final effectiveApproverId = approverId ?? user.uid;
      final effectiveApproverEmail = approverEmail ?? user.email ?? 'Unknown';
      String effectiveApproverName = approverName ?? user.displayName ?? 'Unknown';

      final batch = _firestore.batch();
      Map<String, dynamic> updateData = {
        'updated_at': FieldValue.serverTimestamp(),
        'status': newStatus,
        'approval_level': approvalLevel
      };

      if (isApprove) {
        updateData.addAll({
          'approved_by': effectiveApproverEmail,
          'approved_by_id': effectiveApproverId,
          'approved_by_name': effectiveApproverName,
          'approved_by_role': userRole,
          'approved_at': FieldValue.serverTimestamp(),
          'approval_note': notes
        });
      } else {
        updateData.addAll({
          'rejected_by': effectiveApproverEmail,
          'rejected_by_id': effectiveApproverId,
          'rejected_by_name': effectiveApproverName,
          'rejected_by_role': userRole,
          'rejected_at': FieldValue.serverTimestamp(),
          'rejected_reason': notes
        });
      }

      updateData['risk_level'] = riskAssessment.riskLevel;
      updateData['risk_factors'] = riskAssessment.riskFactors;

      if (skipHSSE) {
        updateData['requires_hsse_approval'] = false;
        updateData['need_hsse_confirmation'] = false;
        updateData['hsse_skipped'] = true;
        updateData['hsse_skipped_by'] = effectiveApproverName;
        updateData['hsse_skipped_at'] = FieldValue.serverTimestamp();
      } else if (needsHsseApproval) {
        updateData['requires_hsse_approval'] = true;
      } else {
        updateData['requires_hsse_approval'] = false;
      }

      if (finalStatuses.contains(newStatus)) {
        updateData['requires_hsse_approval'] = false;
        updateData['need_hsse_confirmation'] = false;
        updateData['is_risky'] = false;
      }

      if (userRole == roleManagerHSSE) {
        updateData['hsse_approved_by'] = effectiveApproverName;
        updateData['hsse_approved_by_id'] = effectiveApproverId;
        updateData['hsse_approved_at'] = FieldValue.serverTimestamp();
        updateData['hsse_approval_note'] = notes;
        updateData['hsse_validated'] = true;
        updateData['is_risky'] = false;
        updateData['requires_hsse_approval'] = false;
        updateData['hsse_approved_for_fungsi'] = pengawasFungsi;
      }

      batch.update(_firestore.collection(collectionPengajuan).doc(groupId), updateData);

      final mitraSnapshot = await _firestore.collection(collectionLemburMitra).where('group_id', isEqualTo: groupId).get();
      for (final doc in mitraSnapshot.docs) {
        batch.update(_firestore.collection(collectionLemburMitra).doc(doc.id), updateData);
      }

      await batch.commit();

      final mitraList = mitraSnapshot.docs.map((doc) {
        final data = doc.data();
        return {'docId': doc.id, 'id': doc.id, ...data, 'is_group_leader': false};
      }).toList();

      String? spklNomor; String? spklPdfPath; bool spklGenerated = false;
      if (isApprove && newStatus == statusApproved) {
        try {
          final result = await _generateSpklWithPdf(
              groupLeader: groupLeader, mitraList: mitraList,
              approvedByName: effectiveApproverName);
          spklNomor = result['nomor']?.isNotEmpty == true ? result['nomor'] : null;
          spklPdfPath = result['pdfPath']?.isNotEmpty == true ? result['pdfPath'] : null;
          spklGenerated = result['saved'] == true;
        } catch (e) { debugPrint('❌ SPKL error: $e'); }
      }

      if (newStatus == statusPendingHSSE) {
        await _notifyManagerHsse(
            groupId: groupId, groupLeader: groupLeader,
            riskAssessment: riskAssessment, approvedByManager: effectiveApproverName);
      }

      await _sendNotificationToPengawas(
          groupLeader: groupLeader, isApprove: isApprove, notes: notes,
          approverName: effectiveApproverName, approverRole: userRole,
          spklNomor: spklNomor, status: newStatus,
          needsHsseApproval: newStatus == statusPendingHSSE);

      if (isApprove && newStatus == statusApproved) {
        await _sendNotificationToMitra(
            mitraList: mitraList, groupLeader: groupLeader,
            approverName: effectiveApproverName, spklNomor: spklNomor);
      }

      await _firestore.collection(collectionApprovalLogs).add({
        'group_id': groupId, 'action': isApprove ? 'approved' : 'rejected',
        'approval_level': approvalLevel,
        'by_name': effectiveApproverName, 'by_role': userRole,
        'by_email': effectiveApproverEmail, 'by_id': effectiveApproverId,
        'notes': notes, 'spkl_nomor': spklNomor, 'spkl_generated': spklGenerated,
        'risk_level': riskAssessment.riskLevel, 'requires_hsse': needsHsseApproval,
        'hsse_skipped': skipHSSE, 'pengawas_fungsi': pengawasFungsi,
        'timestamp': FieldValue.serverTimestamp(),
      });

      String message;
      if (isApprove) {
        if (newStatus == statusPendingHSSE) {
          message = '✅ Pengajuan disetujui, menunggu validasi K3 oleh Manager HSSE';
        } else if (userRole == roleManagerHSSE) {
          message = '✅ Validasi K3 berhasil, SPKL telah digenerate';
        } else if (skipHSSE) {
          message = '✅ Pengajuan langsung disetujui (tanpa validasi K3), SPKL telah digenerate';
        } else {
          message = '✅ Pengajuan disetujui, SPKL telah digenerate & notifikasi terkirim';
        }
      } else {
        message = '❌ Pengajuan ditolak, notifikasi terkirim';
      }

      return ApprovalResult(
          success: true, successCount: 1 + mitraList.length, failCount: 0,
          spklNomor: spklNomor, spklPdfPath: spklPdfPath,
          spklGenerated: spklGenerated, message: message,
          needsHsseApproval: newStatus == statusPendingHSSE,
          riskLevel: riskAssessment.riskLevel);
    } catch (e) {
      debugPrint('❌ Process approval error: $e');
      return ApprovalResult(success: false, successCount: 0, failCount: 1, message: e.toString());
    }
  }

  // ===================================================================
  // ✅ CLEANUP
  // ===================================================================
  Future<int> cleanupCompletedRiskFlags() async {
    try {
      final completedSnapshot = await _firestore.collection(collectionPengajuan)
          .where('status', whereIn: finalStatuses).get();
      final batch = _firestore.batch();
      int cleanedCount = 0;
      for (final doc in completedSnapshot.docs) {
        final data = doc.data();
        if (data['requires_hsse_approval'] == true ||
            data['is_risky'] == true ||
            data['need_hsse_confirmation'] == true) {
          batch.update(doc.reference, {
            'requires_hsse_approval': false,
            'need_hsse_confirmation': false,
            'is_risky': false,
            '_cleaned_at': FieldValue.serverTimestamp()
          });
          cleanedCount++;
        }
      }
      if (cleanedCount > 0) await batch.commit();
      return cleanedCount;
    } catch (e) { return 0; }
  }

  // ===================================================================
  // NOTIFIKASI + SPKL (TETAP)
  // ===================================================================
  Future<void> _notifyManagerHsse({
    required String groupId,
    required Map<String, dynamic> groupLeader,
    required RiskAssessment riskAssessment,
    required String approvedByManager,
  }) async {
    try {
      final managerHsseQuery = await _firestore.collection(collectionUsers)
          .where('role', isEqualTo: roleManagerHSSE)
          .where('status_akun', isEqualTo: 'active').get();
      if (managerHsseQuery.docs.isEmpty) return;
      for (final doc in managerHsseQuery.docs) {
        final d = doc.data();
        await _notificationService.sendHsseApprovalRequest(
            hsseId: doc.id, hsseEmail: d['email'] ?? '',
            hsseName: d['nama_lengkap'] ?? 'Manager HSSE',
            hsseNoHp: d['phone'] ?? d['no_hp'] ?? '',
            groupId: groupId, pengawasNama: groupLeader['nama_pengawas'] ?? '',
            tanggal: _formatDate(groupLeader['tanggal']),
            riskLevel: riskAssessment.riskLevel,
            riskFactors: riskAssessment.riskFactors,
            approvedByManager: approvedByManager);
      }
      await _firestore.collection(collectionNotificationsLog).add({
        'type': 'manager_hsse_approval_request', 'group_id': groupId,
        'risk_level': riskAssessment.riskLevel,
        'approved_by_manager': approvedByManager,
        'timestamp': FieldValue.serverTimestamp()
      });
    } catch (e) { debugPrint('❌ Notify HSSE error: $e'); }
  }

  Future<Map<String, dynamic>> _generateSpklWithPdf({
    required Map<String, dynamic> groupLeader,
    required List<Map<String, dynamic>> mitraList,
    required String approvedByName,
  }) async {
    bool pdfGenerated = false, spklSaved = false;
    String nomorSpkl = '';
    try {
      final groupId = (groupLeader['group_id'] ?? '').toString();
      final shortId = groupId.length >= 8 ? groupId.substring(0, 8) : groupId;
      nomorSpkl = 'SPKL/${DateFormat('yyyyMMdd').format(DateTime.now())}/$shortId';
      final formattedMitraList = mitraList.map((m) => {
            'nama_mitra': m['nama_mitra'] ?? 'Unknown',
            'fungsi_mitra': m['fungsi_mitra'] ?? 'Unknown'
          }).toList();
      final spklData = {
        'nomor_spkl': nomorSpkl, 'group_id': groupId,
        'approved_by_name': approvedByName,
        'approved_at': Timestamp.fromDate(DateTime.now()),
        'tanggal_lembur': groupLeader['tanggal'],
        'jam_mulai': groupLeader['jam_mulai'] ?? '',
        'jam_selesai': groupLeader['jam_selesai'] ?? '',
        'total_jam': _parseDouble(groupLeader['total_jam_desimal']),
        'estimasi_biaya_total': _parseDouble(groupLeader['estimasi_biaya_total']),
        'pengawas_nama': groupLeader['nama_pengawas'] ?? '',
        'pengawas_fungsi': groupLeader['pengawas_fungsi'] ?? '',
        'mitra_list': formattedMitraList, 'total_mitra': formattedMitraList.length,
        'jenis_lembur': groupLeader['jenis_lembur'] ?? 'hari_kerja',
        'alasan': groupLeader['alasan'] ?? '-',
        'lokasi': groupLeader['lokasi'] ?? {'alamat': 'Area PGE'},
        'urgensi': groupLeader['urgensi'] ?? 'normal',
        'created_at': FieldValue.serverTimestamp(), 'status': 'active',
      };
      await _firestore.collection(collectionSpkl).doc(groupId).set(spklData);
      spklSaved = true;
      String pdfPath = '';
      try {
        pdfPath = await _spklGenerator.generateSpklPdf(spklData);
        pdfGenerated = true;
        await _firestore.collection(collectionSpkl).doc(groupId).update({
          'pdf_generated': true, 'pdf_path': pdfPath,
          'pdf_generated_at': FieldValue.serverTimestamp()
        });
      } catch (e) {
        await _firestore.collection(collectionSpkl).doc(groupId).update({
          'pdf_generated': false, 'pdf_error': e.toString(),
          'pdf_error_at': FieldValue.serverTimestamp()
        });
      }
      final batch = _firestore.batch();
      final spklUpdate = {
        'spkl_generated': true, 'spkl_nomor': nomorSpkl,
        'spkl_generated_at': FieldValue.serverTimestamp(),
        'spkl_status': 'active', 'spkl_pdf_generated': pdfGenerated
      };
      if (pdfPath.isNotEmpty) spklUpdate['spkl_pdf_path'] = pdfPath;
      batch.update(_firestore.collection(collectionPengajuan).doc(groupId), spklUpdate);
      final mitraSnapshot = await _firestore.collection(collectionLemburMitra)
          .where('group_id', isEqualTo: groupId).get();
      for (final doc in mitraSnapshot.docs) {
        batch.update(doc.reference, {'spkl_generated': true, 'spkl_nomor': nomorSpkl});
      }
      await batch.commit();
      return {'nomor': nomorSpkl, 'pdfPath': pdfPath, 'saved': spklSaved, 'pdfGenerated': pdfGenerated};
    } catch (e) {
      await _firestore.collection(collectionSpklErrors).add({
        'group_id': groupLeader['group_id'] ?? '', 'error': e.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'spkl_saved': spklSaved, 'pdf_generated': pdfGenerated
      });
      return {'nomor': nomorSpkl.isNotEmpty ? nomorSpkl : '', 'pdfPath': '', 'saved': spklSaved, 'pdfGenerated': false, 'error': e.toString()};
    }
  }

  Future<void> _sendNotificationToPengawas({
    required Map<String, dynamic> groupLeader,
    required bool isApprove,
    required String notes,
    required String approverName,
    required String approverRole,
    String? spklNomor,
    String? status,
    bool needsHsseApproval = false,
  }) async {
    try {
      final pengawasId = groupLeader['pengawas_id']?.toString() ?? groupLeader['diajukan_oleh_id']?.toString();
      if (pengawasId == null || pengawasId.isEmpty) return;
      final userData = await _getUserData(pengawasId);
      await _notificationService.sendApprovalResultNotification(
          pengawasId: pengawasId, pengawasNama: groupLeader['nama_pengawas'] ?? 'Unknown',
          pengawasEmail: userData['email'] ?? '', pengawasNoHp: userData['phone'] ?? '',
          isApproved: isApprove, approverName: approverName, approverRole: approverRole,
          spklNomor: spklNomor, groupId: groupLeader['group_id']?.toString() ?? '',
          notes: notes, tanggal: _formatDate(groupLeader['tanggal']),
          waktu: '${groupLeader['jam_mulai']} - ${groupLeader['jam_selesai']}',
          fungsi: groupLeader['pengawas_fungsi'] ?? 'Unknown');
    } catch (e) { debugPrint('❌ Notif pengawas error: $e'); }
  }

  Future<void> _sendNotificationToMitra({
    required List<Map<String, dynamic>> mitraList,
    required Map<String, dynamic> groupLeader,
    required String approverName,
    String? spklNomor,
  }) async {
    try {
      final groupId = (groupLeader['group_id'] ?? '').toString();
      for (final mitra in mitraList) {
        final mitraId = (mitra['mitra_id'] ?? mitra['user_id'] ?? '').toString();
        if (mitraId.isEmpty) continue;
        final userData = await _getUserData(mitraId);
        await _notificationService.sendMitraAssignmentNotification(
            mitraId: mitraId, mitraNama: mitra['nama_mitra'] ?? 'Mitra',
            mitraEmail: userData['email'] ?? '', mitraNoHp: userData['phone'] ?? '',
            spklNomor: spklNomor, groupId: groupId,
            pengawasNama: groupLeader['nama_pengawas'] ?? 'Unknown',
            tanggal: _formatDate(groupLeader['tanggal']),
            waktu: '${groupLeader['jam_mulai']} - ${groupLeader['jam_selesai']}',
            lokasi: groupLeader['lokasi']?['alamat'] ?? 'Area PGE Kamojang',
            fungsi: groupLeader['pengawas_fungsi'] ?? 'Unknown');
      }
    } catch (e) { debugPrint('❌ Notif mitra error: $e'); }
  }

  // ===================================================================
  // BULK APPROVAL, SPKL, LOGS
  // ===================================================================
  Future<Map<String, dynamic>> bulkApproval({
    required List<String> groupIds,
    required bool isApprove,
    required String notes,
    required String approverName,
    required String approverEmail,
    required String approverId,
  }) async {
    int totalSuccess = 0, totalFail = 0;
    List<String> failedGroups = [], successGroups = [];
    for (final groupId in groupIds) {
      try {
        final result = await processApproval(
            groupId: groupId, isApprove: isApprove, notes: notes,
            userRole: roleSuperadmin, approverName: approverName,
            approverEmail: approverEmail, approverId: approverId);
        if (result.success) { totalSuccess++; successGroups.add(groupId); }
        else { totalFail++; failedGroups.add(groupId); }
      } catch (e) { totalFail++; failedGroups.add(groupId); }
    }
    return {'totalSuccess': totalSuccess, 'totalFail': totalFail, 'successGroups': successGroups, 'failedGroups': failedGroups};
  }

  Future<Map<String, dynamic>?> getSpkl(String groupId) async {
    try {
      final doc = await _firestore.collection(collectionSpkl).doc(groupId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) { return null; }
  }

  Stream<Map<String, dynamic>?> getSpklStream(String groupId) {
    return _firestore.collection(collectionSpkl).doc(groupId).snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  Future<String?> previewSpkl(String groupId) async {
    final data = await getSpkl(groupId);
    if (data == null) return null;
    return await _spklGenerator.generateSpklPdf(data);
  }

  Future<String?> downloadSpkl(String groupId) async => await previewSpkl(groupId);

  Stream<List<Map<String, dynamic>>> getApprovalLogs({String? fungsiFilter, int limit = 50}) {
    Query<Map<String, dynamic>> query = _firestore.collection(collectionApprovalLogs)
        .orderBy('timestamp', descending: true).limit(limit);
    if (fungsiFilter != null && fungsiFilter.isNotEmpty && fungsiFilter != 'semua') {
      query = query.where('pengawas_fungsi', isEqualTo: fungsiFilter);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  int _compareTimestamps(dynamic a, dynamic b) {
    DateTime timeA = DateTime(2000), timeB = DateTime(2000);
    if (a is Timestamp) timeA = a.toDate();
    if (a is DateTime) timeA = a;
    if (b is Timestamp) timeB = b.toDate();
    if (b is DateTime) timeB = b;
    return timeA.compareTo(timeB);
  }

  String _formatDate(dynamic tanggal) {
    if (tanggal == null) return '-';
    try {
      if (tanggal is Timestamp) return DateFormat('dd MMMM yyyy', 'id_ID').format(tanggal.toDate());
      if (tanggal is DateTime) return DateFormat('dd MMMM yyyy', 'id_ID').format(tanggal);
      return DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.parse(tanggal.toString()));
    } catch (e) { return tanggal.toString(); }
  }
}

// ===================================================================
// RESULT MODEL
// ===================================================================
class ApprovalResult {
  final bool success;
  final int successCount;
  final int failCount;
  final List<String> failedDocs;
  final String? spklNomor;
  final String? spklPdfPath;
  final bool spklGenerated;
  final String message;
  final bool needsHsseApproval;
  final String riskLevel;

  ApprovalResult({
    required this.success,
    this.successCount = 0,
    this.failCount = 0,
    this.failedDocs = const [],
    this.spklNomor,
    this.spklPdfPath,
    this.spklGenerated = false,
    this.message = '',
    this.needsHsseApproval = false,
    this.riskLevel = 'none',
  });
}

class RiskAssessment {
  final bool hasRisk;
  final String riskLevel;
  final List<String> riskFactors;
  final bool requiresHsseApproval;

  RiskAssessment({
    required this.hasRisk,
    required this.riskLevel,
    this.riskFactors = const [],
    this.requiresHsseApproval = false,
  });
}