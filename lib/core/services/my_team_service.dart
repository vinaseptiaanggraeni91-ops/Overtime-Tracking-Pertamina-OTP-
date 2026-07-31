// lib/core/services/my_team_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeamMember {
  final String id;
  final String namaLengkap;
  final String email;
  final String phone;
  final String role;
  final String fungsi;
  final String fungsiLabel;
  final String statusAkun;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final bool isActive;
  final String? fotoUrl;

  TeamMember({
    required this.id,
    required this.namaLengkap,
    required this.email,
    required this.phone,
    required this.role,
    required this.fungsi,
    required this.fungsiLabel,
    required this.statusAkun,
    this.lastLogin,
    required this.createdAt,
    required this.isActive,
    this.fotoUrl,
  });

  factory TeamMember.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    DateTime? lastLogin;
    if (data['last_login'] != null) {
      if (data['last_login'] is Timestamp) {
        lastLogin = (data['last_login'] as Timestamp).toDate();
      }
    }

    DateTime createdAt;
    if (data['created_at'] != null) {
      if (data['created_at'] is Timestamp) {
        createdAt = (data['created_at'] as Timestamp).toDate();
      } else {
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }

    // Format fungsi label yang lebih rapi
    String fungsiLabel = data['fungsi_label'] ?? '';
    if (fungsiLabel.isEmpty && data['fungsi'] != null) {
      fungsiLabel = _formatFungsiLabel(data['fungsi']);
    }

    return TeamMember(
      id: doc.id,
      namaLengkap: data['nama_lengkap'] ?? 'Tanpa Nama',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'mitra',
      fungsi: data['fungsi'] ?? '',
      fungsiLabel: fungsiLabel,
      statusAkun: data['status_akun'] ?? 'inactive',
      lastLogin: lastLogin,
      createdAt: createdAt,
      isActive: data['status_akun'] == 'active',
      fotoUrl: data['foto_url'],
    );
  }

  static String _formatFungsiLabel(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation':
        return 'Operation';
      case 'maintenance':
        return 'Maintenance';
      case 'hsse':
        return 'HSSE';
      case 'gpr':
        return 'GPR';
      case 'bs':
        return 'Business Support';
      default:
        return fungsi.toUpperCase();
    }
  }

  String get inisial {
    if (namaLengkap.isEmpty) return '?';
    final parts = namaLengkap.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return namaLengkap[0].toUpperCase();
  }

  String get lastLoginFormatted {
    if (lastLogin == null) return 'Belum pernah login';
    final now = DateTime.now();
    final diff = now.difference(lastLogin!);
    
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${lastLogin!.day}/${lastLogin!.month}/${lastLogin!.year}';
  }

  /// Mendapatkan warna berdasarkan role
  Color get roleColor {
    switch (role.toLowerCase()) {
      case 'pengawas':
        return const Color(0xFF1976D2);
      case 'manager':
        return const Color(0xFF7C3AED);
      case 'mitra':
        return const Color(0xFF059669);
      case 'admin':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  /// Mendapatkan label role yang readable
  String get roleLabel {
    switch (role.toLowerCase()) {
      case 'pengawas':
        return 'Pengawas';
      case 'manager':
        return 'Manager';
      case 'mitra':
        return 'Mitra';
      case 'admin':
        return 'Admin';
      default:
        return role;
    }
  }
}

class MyTeamService {
  static final MyTeamService _instance = MyTeamService._internal();
  factory MyTeamService() => _instance;
  MyTeamService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mendapatkan semua anggota tim berdasarkan fungsi DAN role user
  /// 
  /// Rules:
  /// - Manager: melihat pengawas + mitra dalam fungsi yang sama
  /// - Pengawas: hanya melihat mitra dalam fungsi yang sama
  /// - Role lain: melihat semua dalam fungsi yang sama
  Stream<List<TeamMember>> getTeamMembersStream({
    required String fungsi,
    required String userRole, // ← TAMBAH: parameter role
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('fungsi', isEqualTo: fungsi.toLowerCase());

    // Filter berdasarkan role user
    switch (userRole.toLowerCase()) {
      case 'manager':
        // Manager melihat pengawas dan mitra (TIDAK melihat manager lain)
        query = query.where('role', whereIn: ['pengawas', 'mitra']);
        break;
      
      case 'pengawas':
        // Pengawas hanya melihat mitra
        query = query.where('role', isEqualTo: 'mitra');
        break;
      
      default:
        // Role lain (admin, dll) melihat semua role dalam fungsi tersebut
        // Tidak perlu filter tambahan
        break;
    }

    return query.snapshots().map((snapshot) {
      final members = snapshot.docs
          .map((doc) => TeamMember.fromFirestore(doc))
          .toList();

      // Sort: role priority (pengawas dulu, baru mitra), lalu active, lalu by name
      members.sort((a, b) {
        // 1. Sort by role priority
        final roleOrder = _getRolePriority(a.role).compareTo(_getRolePriority(b.role));
        if (roleOrder != 0) return roleOrder;
        
        // 2. Sort by active status
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        
        // 3. Sort by name
        return a.namaLengkap.compareTo(b.namaLengkap);
      });

      return members;
    });
  }

  /// Prioritas role untuk sorting (semakin kecil semakin tinggi)
  int _getRolePriority(String role) {
    switch (role.toLowerCase()) {
      case 'pengawas':
        return 0;
      case 'mitra':
        return 1;
      default:
        return 2;
    }
  }

  /// Mendapatkan jumlah total anggota tim
  Future<int> getTotalTeamMembers({
    required String fungsi,
    required String userRole,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .where('fungsi', isEqualTo: fungsi.toLowerCase());

      // Filter berdasarkan role user
      if (userRole.toLowerCase() == 'manager') {
        query = query.where('role', whereIn: ['pengawas', 'mitra']);
      } else if (userRole.toLowerCase() == 'pengawas') {
        query = query.where('role', isEqualTo: 'mitra');
      }

      final snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting total team members: $e');
      return 0;
    }
  }

  /// Mendapatkan statistik tim
  Future<Map<String, dynamic>> getTeamStats({
    required String fungsi,
    required String userRole,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .where('fungsi', isEqualTo: fungsi.toLowerCase());

      // Filter berdasarkan role user
      if (userRole.toLowerCase() == 'manager') {
        query = query.where('role', whereIn: ['pengawas', 'mitra']);
      } else if (userRole.toLowerCase() == 'pengawas') {
        query = query.where('role', isEqualTo: 'mitra');
      }

      final snapshot = await query.get();
      final members = snapshot.docs;

      int total = members.length;
      int active = members.where((d) => d.data()['status_akun'] == 'active').length;
      int inactive = members.where((d) => d.data()['status_akun'] != 'active').length;
      
      // Hitung berdasarkan role
      int totalPengawas = members.where((d) => d.data()['role'] == 'pengawas').length;
      int totalMitra = members.where((d) => d.data()['role'] == 'mitra').length;
      
      // Hitung yang login dalam 7 hari terakhir
      int recentlyActive = 0;
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      for (var doc in members) {
        final data = doc.data();
        if (data['last_login'] != null) {
          final lastLogin = (data['last_login'] as Timestamp).toDate();
          if (lastLogin.isAfter(sevenDaysAgo)) {
            recentlyActive++;
          }
        }
      }

      return {
        'total': total,
        'active': active,
        'inactive': inactive,
        'recentlyActive': recentlyActive,
        'totalPengawas': totalPengawas,
        'totalMitra': totalMitra,
        'fungsi': fungsi,
      };
    } catch (e) {
      debugPrint('Error getting team stats: $e');
      return {
        'total': 0,
        'active': 0,
        'inactive': 0,
        'recentlyActive': 0,
        'totalPengawas': 0,
        'totalMitra': 0,
        'fungsi': fungsi,
      };
    }
  }

  /// Cari anggota tim spesifik
  Future<TeamMember?> getTeamMemberById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return TeamMember.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting team member: $e');
      return null;
    }
  }

  /// Mendapatkan daftar pengawas saja (untuk manager)
  Stream<List<TeamMember>> getPengawasStream({
    required String fungsi,
  }) {
    return _firestore
        .collection('users')
        .where('fungsi', isEqualTo: fungsi.toLowerCase())
        .where('role', isEqualTo: 'pengawas')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TeamMember.fromFirestore(doc))
              .toList()
            ..sort((a, b) => a.namaLengkap.compareTo(b.namaLengkap));
        });
  }

  /// Mendapatkan daftar mitra dari pengawas tertentu (untuk manager)
  Stream<List<TeamMember>> getMitraByPengawasStream({
    required String fungsi,
  }) {
    return _firestore
        .collection('users')
        .where('fungsi', isEqualTo: fungsi.toLowerCase())
        .where('role', isEqualTo: 'mitra')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TeamMember.fromFirestore(doc))
              .toList()
            ..sort((a, b) {
              if (a.isActive && !b.isActive) return -1;
              if (!a.isActive && b.isActive) return 1;
              return a.namaLengkap.compareTo(b.namaLengkap);
            });
        });
  }

  /// Cari anggota tim berdasarkan query
  Future<List<TeamMember>> searchTeamMembers({
    required String fungsi,
    required String userRole,
    required String searchQuery,
  }) async {
    try {
      // Firebase tidak support full-text search, jadi kita ambil semua dulu
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .where('fungsi', isEqualTo: fungsi.toLowerCase());

      if (userRole.toLowerCase() == 'manager') {
        query = query.where('role', whereIn: ['pengawas', 'mitra']);
      } else if (userRole.toLowerCase() == 'pengawas') {
        query = query.where('role', isEqualTo: 'mitra');
      }

      final snapshot = await query.get();
      
      final searchLower = searchQuery.toLowerCase();
      
      return snapshot.docs
          .map((doc) => TeamMember.fromFirestore(doc))
          .where((member) {
            return member.namaLengkap.toLowerCase().contains(searchLower) ||
                member.email.toLowerCase().contains(searchLower) ||
                member.phone.contains(searchQuery);
          })
          .toList()
        ..sort((a, b) => a.namaLengkap.compareTo(b.namaLengkap));
    } catch (e) {
      debugPrint('Error searching team members: $e');
      return [];
    }
  }
}