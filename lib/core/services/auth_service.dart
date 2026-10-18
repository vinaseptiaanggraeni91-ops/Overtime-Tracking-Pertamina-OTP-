// lib/core/services/auth_service.dart
// 🔥 COMPLETE VERSION - ALL ERRORS FIXED - FINAL

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// DASHBOARD
import '../../dashboard/manager/manager_dashboard.dart';
import '../../dashboard/mitra/mitra_dashboard.dart';
import '../../dashboard/pengawas/pengawas_dashboard.dart';
import '../../dashboard/superadmin/superadmin_dashboard.dart';

// SCREEN
import '../../screens/login_screen.dart';
import '../../screens/welcome_screen.dart';

// NETWORK SERVICE
import 'network_service.dart';

// NOTIFICATION SERVICE
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // NETWORK SERVICE
  final NetworkService _networkService = NetworkService();
  
  // STREAM SUBSCRIPTIONS
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _authSubscription;

  // 🔥 GUARD FLAG - Mencegah infinite loop signOut
  bool _isSigningOut = false;

  // =========================================================
  // 🔥 INITIALIZATION
  // =========================================================
  
  AuthService() {
    _initializeNetworkMonitoring();
    _initializeAuthStateListener();
  }

  void _initializeNetworkMonitoring() {
    _connectionSubscription = _networkService.connectionStream.listen((isOnline) {
      debugPrint('🌐 Network status changed: ${isOnline ? "ONLINE" : "OFFLINE"}');
      if (isOnline) {
        _syncOfflineData();
      }
    });
  }

  void _initializeAuthStateListener() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        debugPrint('👤 User logged in: ${user.email}');
        _updateUserOnlineStatus(true);
      } else {
        // 🔥 Hanya print jika bukan dari proses signOut internal
        if (!_isSigningOut) {
          debugPrint('👤 User logged out');
        }
      }
    });
  }

  // =========================================================
  // 🔥 DISPOSE
  // =========================================================
  
  void dispose() {
    _connectionSubscription?.cancel();
    _authSubscription?.cancel();
  }

  // =========================================================
  // 🔥 NETWORK CHECK HELPERS
  // =========================================================

  bool _checkConnection(String operationName) {
    if (!_networkService.isOnline) {
      debugPrint('⚠️ [$operationName] Dibatalkan - Tidak ada koneksi internet');
      return false;
    }
    return true;
  }

  Future<bool> _checkConnectionAsync(String operationName) async {
    final isConnected = await _networkService.checkConnection();
    if (!isConnected) {
      debugPrint('⚠️ [$operationName] Dibatalkan - Tidak ada koneksi internet');
    }
    return isConnected;
  }

  // =========================================================
  // 🔥 RETRY LOGIC UNTUK NETWORK OPERATIONS
  // =========================================================

  Future<T> _retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    while (true) {
      try {
        return await operation().timeout(const Duration(seconds: 15));
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        debugPrint('🔄 Retry attempt $attempts/$maxRetries');
        await Future.delayed(initialDelay * attempts);
      }
    }
  }

  // =========================================================
  // 🔥 SYNC OFFLINE DATA
  // =========================================================

  Future<void> _syncOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingActions = prefs.getStringList('pending_actions') ?? [];
      
      if (pendingActions.isEmpty) return;
      
      debugPrint('🔄 Syncing ${pendingActions.length} offline actions...');
      
      for (var action in pendingActions) {
        try {
          final data = jsonDecode(action);
          await _processOfflineAction(data);
        } catch (e) {
          debugPrint('⚠️ Failed to sync offline action: $e');
        }
      }
      
      await prefs.remove('pending_actions');
      debugPrint('✅ Offline sync completed');
    } catch (e) {
      debugPrint('❌ Offline sync error: $e');
    }
  }

  Future<void> _processOfflineAction(Map<String, dynamic> action) async {
    switch (action['type']) {
      case 'update_online_status':
        await _firestore.collection('users').doc(action['userId']).update({
          'isOnline': action['status'],
          'last_active': FieldValue.serverTimestamp(),
        });
        break;
    }
  }

  Future<void> _saveOfflineAction(Map<String, dynamic> action) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingActions = prefs.getStringList('pending_actions') ?? [];
    pendingActions.add(jsonEncode(action));
    await prefs.setStringList('pending_actions', pendingActions);
  }

  // =========================================================
  // 🔥 UPDATE USER ONLINE STATUS
  // =========================================================

  Future<void> _updateUserOnlineStatus(bool isOnline) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      if (_networkService.isOnline) {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': isOnline,
          'last_active': FieldValue.serverTimestamp(),
        });
      } else {
        await _saveOfflineAction({
          'type': 'update_online_status',
          'userId': user.uid,
          'status': isOnline,
        });
      }
    } catch (e) {
      debugPrint('Update online status error: $e');
    }
  }

  // =========================================================
  // 🔥 VALIDASI INPUT (CLIENT-SIDE)
  // =========================================================

  String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Email tidak boleh kosong';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return 'Format email tidak valid\nContoh: nama@email.com';
    }
    return null;
  }

  String? validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return 'Nomor HP tidak boleh kosong';
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.length < 10) return 'Nomor HP minimal 10 digit';
    if (cleanPhone.length > 13) return 'Nomor HP maksimal 13 digit';
    if (!cleanPhone.startsWith('0') && !cleanPhone.startsWith('62')) {
      return 'Nomor HP harus diawali 0 atau 62';
    }
    return null;
  }

  String? validatePassword(String? password) {
    if (password == null || password.isEmpty) return 'Password tidak boleh kosong';
    if (password.length < 8) return 'Password minimal 8 karakter';
    if (password.length > 128) return 'Password maksimal 128 karakter';
    if (password.contains(' ')) return 'Password tidak boleh mengandung spasi';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Password harus mengandung huruf besar';
    if (!password.contains(RegExp(r'[a-z]'))) return 'Password harus mengandung huruf kecil';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Password harus mengandung angka';
    return null;
  }

  String? validateNama(String? nama) {
    if (nama == null || nama.trim().isEmpty) return 'Nama lengkap tidak boleh kosong';
    if (nama.trim().length < 2) return 'Nama minimal 2 karakter';
    if (nama.trim().length > 100) return 'Nama maksimal 100 karakter';
    return null;
  }

  String? validateLoginForm(String identity, String password) {
    if (identity.trim().isEmpty) return 'Email atau nomor HP tidak boleh kosong';
    if (identity.contains('@')) {
      final e = validateEmail(identity);
      if (e != null) return e;
    } else {
      final p = validatePhone(identity);
      if (p != null) return p;
    }
    return validatePassword(password);
  }

  String? validateRegisterForm({
    required String nama,
    required String email,
    required String phone,
    required String password,
  }) {
    final n = validateNama(nama);
    if (n != null) return n;
    final e = validateEmail(email);
    if (e != null) return e;
    final p = validatePhone(phone);
    if (p != null) return p;
    return validatePassword(password);
  }

  // =========================================================
  // 🔥 HELPER UNTUK GO ROUTER
  // =========================================================

  bool get isLoggedIn => _auth.currentUser != null;
  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentUserEmail => _auth.currentUser?.email;
  bool isLoggedInSync() => _auth.currentUser != null;

  Future<String?> getUserRole() async {
    try {
      if (!_checkConnection('getUserRole')) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('cached_role');
      }
      
      final user = _auth.currentUser;
      if (user == null) return null;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      
      final role = (doc.data()?['role'] ?? '').toString().toLowerCase();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_role', role);
      
      return role;
    } catch (e) {
      debugPrint('GET USER ROLE ERROR: $e');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cached_role');
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      if (!_checkConnection('getCurrentUserData')) {
        return _getCachedUserData();
      }
      
      final user = _auth.currentUser;
      if (user == null) return null;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      
      final data = {'id': doc.id, ...doc.data()!};
      
      await _cacheUserData(data);
      
      return data;
    } catch (e) {
      debugPrint('GET CURRENT USER DATA ERROR: $e');
      return _getCachedUserData();
    }
  }

  Future<Map<String, dynamic>?> _getCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_user_data');
      if (cachedData != null) {
        return jsonDecode(cachedData);
      }
    } catch (e) {
      debugPrint('Get cached data error: $e');
    }
    return null;
  }

  Future<void> _cacheUserData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_data', jsonEncode(data));
      await prefs.setString('cached_role', data['role'] ?? '');
      await prefs.setString('cached_nama', data['nama_lengkap'] ?? '');
    } catch (e) {
      debugPrint('Cache user data error: $e');
    }
  }

  Future<bool> hasRole(String role) async {
    final r = await getUserRole();
    return r == role.toLowerCase();
  }

  Future<bool> hasAnyRole(List<String> roles) async {
    final r = await getUserRole();
    return roles.map((e) => e.toLowerCase()).contains(r);
  }

  String getDashboardPath(String? role) {
    switch (role?.toLowerCase()) {
      case 'superadmin':     return '/superadmin-dashboard';
      case 'manager':        return '/manager-dashboard';
      case 'pengawas':       return '/pengawas-dashboard';
      case 'mitra':          return '/mitra-dashboard';
      case 'manager_hsse':   return '/manager-hsse-dashboard';
      default:               return '/login';
    }
  }

  Future<String?> getUserStatus() async {
    try {
      if (!_checkConnection('getUserStatus')) {
        final data = await _getCachedUserData();
        return data?['status_akun']?.toString().toLowerCase();
      }
      
      final user = _auth.currentUser;
      if (user == null) return null;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      return (doc.data()?['status_akun'] ?? '').toString().toLowerCase();
    } catch (e) {
      debugPrint('GET USER STATUS ERROR: $e');
      return null;
    }
  }

  Future<String?> validateAccess() async {
    if (!isLoggedIn) return '/login';
    
    if (!_checkConnection('validateAccess')) {
      return null;
    }
    
    final data = await getCurrentUserData();
    if (data == null) { await signOut(); return '/login'; }
    
    final s = (data['status_akun'] ?? '').toString().toLowerCase();
    if (s == 'deleted' || s == 'blocked' || s == 'inactive') {
      await signOut(); 
      return '/login';
    }
    
    if (s != 'active') { await signOut(); return '/login'; }
    if (data['account_locked'] == true) { await signOut(); return '/login'; }
    
    return null;
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<User?> get userChanges => _auth.userChanges();

  // =========================================================
  // 🔥 AUTH CHECK
  // =========================================================

  Future<Widget> checkAuthAndGetDestination() async {
    try {
      if (!await _checkConnectionAsync('checkAuthAndGetDestination')) {
        final user = _auth.currentUser;
        if (user != null) {
          final prefs = await SharedPreferences.getInstance();
          final cachedRole = prefs.getString('cached_role');
          if (cachedRole != null) {
            debugPrint('📴 Offline - Using cached role: $cachedRole');
            return getDashboardForRole(cachedRole);
          }
        }
        debugPrint('📴 Offline - No cached data, showing WelcomeScreen');
        return const WelcomeScreen();
      }
      
      final user = _auth.currentUser;
      if (user == null) return const WelcomeScreen();
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) { 
        await signOut(); 
        return const LoginScreen(); 
      }
      
      final data = doc.data() ?? {};
      final role = (data['role'] ?? '').toString().toLowerCase();
      final status = (data['status_akun'] ?? '').toString().toLowerCase();
      
      if (status == 'deleted') { 
        await signOut(); 
        return const LoginScreen(); 
      }
      
      if (status != 'active') { 
        await signOut(); 
        return const LoginScreen(); 
      }
      
      await _cacheUserData({'id': doc.id, ...data});
      
      return getDashboardForRole(role);
    } catch (e) {
      debugPrint('checkAuthAndGetDestination error: $e');
      
      if (e.toString().contains('network') || 
          e.toString().contains('SocketException') ||
          (e is FirebaseException && e.code == 'unavailable')) {
        final prefs = await SharedPreferences.getInstance();
        final cachedRole = prefs.getString('cached_role');
        if (cachedRole != null) {
          debugPrint('📴 Network error - Using cached role: $cachedRole');
          return getDashboardForRole(cachedRole);
        }
      }
      
      await signOut();
      return const LoginScreen();
    }
  }

  // =========================================================
  // 🔥 LOGIN - FULLY FIXED
  // =========================================================

  LoginResult? _lastResult;
  LoginResult get lastResult => _lastResult ?? LoginResult(success: false);

  Future<LoginResult> login({
    required String identity,
    required String password,
    required String sessionId,
    required bool rememberMe,
  }) async {
    if (!await _checkConnectionAsync('login')) {
      return _result(false, 
        error: 'Tidak ada koneksi internet. Periksa koneksi Anda dan coba lagi.',
        code: 'no-connection'
      );
    }

    if (identity.trim().isEmpty) {
      return _result(false, error: 'Email atau nomor HP tidak boleh kosong', code: 'empty-identity');
    }
    if (password.isEmpty) {
      return _result(false, error: 'Password tidak boleh kosong', code: 'empty-password');
    }
    if (password.length < 6) {
      return _result(false, error: 'Password minimal 6 karakter', code: 'weak-password');
    }

    try {
      String email = identity.trim();

      if (!identity.contains('@')) {
        final cleanPhone = identity.replaceAll(RegExp(r'[^\d]'), '');
        if (cleanPhone.length < 10) {
          return _result(false, error: 'Nomor HP minimal 10 digit', code: 'invalid-phone');
        }
        
        // 🔒 Catatan: pakai direct Firestore get() (bukan Cloud Function)
        // karena project belum aktif Blaze plan. Ini tetap aman selama
        // rule phone_mappings di firestore.rules memisahkan `get` (publik,
        // per-dokumen — dipakai di sini) dari `list` (superadmin saja).
        // Kalau nanti Blaze plan aktif, ganti ke Cloud Function
        // `resolvePhoneToEmail` supaya bisa ditambah rate limiting.
        try {
          final phoneMapping = await _firestore
              .collection('phone_mappings')
              .doc(cleanPhone)
              .get();

          if (!phoneMapping.exists) {
            return _result(false, error: 'Nomor HP tidak terdaftar', code: 'phone-not-found');
          }
          email = phoneMapping.data()!['email'];
        } catch (e) {
          debugPrint('Phone mapping error: $e');
          return _result(false, error: 'Nomor HP tidak terdaftar', code: 'phone-not-found');
        }
      } else {
        final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
        if (!emailRegex.hasMatch(email)) {
          return _result(false, error: 'Format email tidak valid\nContoh: nama@email.com', code: 'invalid-email-format');
        }
      }

      final credential = await _retryOperation(() => _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      ));

      final user = credential.user;
      if (user == null) {
        return _result(false, error: 'Gagal mendapatkan data user', code: 'user-null');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await signOut();
        return _result(false, error: 'Data user tidak ditemukan di database', code: 'data-not-found');
      }

      final userData = userDoc.data() ?? {};
      final status = (userData['status_akun'] ?? '').toString().toLowerCase();

      if (status == 'deleted') {
        await signOut();
        return _result(false, error: 'Akun ini sudah dihapus.\nHubungi admin untuk info lebih lanjut.', code: 'account-deleted');
      }
      if (status == 'blocked') {
        await signOut();
        return _result(false, error: 'Akun ini diblokir.\nHubungi admin untuk mengaktifkan kembali.', code: 'account-blocked');
      }
      if (status == 'inactive') {
        await signOut();
        return _result(false, error: 'Akun ini sedang dinonaktifkan.\nHubungi admin untuk info lebih lanjut.', code: 'account-inactive');
      }
      if (userData['account_locked'] == true) {
        await signOut();
        return _result(false, error: 'Akun terkunci karena terlalu banyak percobaan login.\nHubungi admin atau reset password.', code: 'account-locked');
      }
      if (status != 'active') {
        await signOut();
        return _result(false, error: 'Status akun tidak valid.\nHubungi admin.', code: 'account-status-invalid');
      }

      final role = (userData['role'] ?? '').toString();
      final nama = (userData['nama_lengkap'] ?? '').toString();

      await _firestore.collection('users').doc(user.uid).update({
        'last_login': FieldValue.serverTimestamp(),
        'login_attempts': 0,
        'isOnline': true,
        'audit_trail': FieldValue.arrayUnion([
          {'action': 'login', 'timestamp': Timestamp.now(), 'session_id': sessionId}
        ]),
      });

      await _cacheUserData({
        'id': user.uid,
        ...userData,
      });

      if (rememberMe) {
        await _saveRememberMe(identity);
      } else {
        await _clearRememberMe();
      }

      return _result(true, role: role, nama: nama, userData: userData);
          
    } on FirebaseAuthException catch (e) {
      await _trackFailedLogin(identity);
      return _result(false, error: _getFirebaseErrorMessage(e.code), code: e.code);
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      
      if (e is TimeoutException) {
        return _result(false, error: 'Koneksi timeout. Periksa internet Anda dan coba lagi.', code: 'timeout');
      }
      
      if (e.toString().contains('SocketException') || 
          e.toString().contains('network') ||
          (e is FirebaseException && e.code == 'unavailable')) {
        return _result(false, error: 'Koneksi internet terputus. Silakan coba lagi.', code: 'network-error');
      }
      
      return _result(false, error: 'Terjadi kesalahan sistem. Silakan coba lagi.', code: 'unknown');
    }
  }

  // =========================================================
  // AUTO LOGIN
  // =========================================================

  Future<LoginResult?> tryAutoLogin() async {
    try {
      if (!await _checkConnectionAsync('tryAutoLogin')) {
        final user = _auth.currentUser;
        if (user != null) {
          final prefs = await SharedPreferences.getInstance();
          final cachedRole = prefs.getString('cached_role') ?? '';
          final cachedNama = prefs.getString('cached_nama') ?? '';
          if (cachedRole.isNotEmpty) {
            return _result(true, role: cachedRole, nama: cachedNama);
          }
        }
        return null;
      }
      
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) { await signOut(); return null; }
      
      final data = doc.data() ?? {};
      final status = (data['status_akun'] ?? '').toString().toLowerCase();
      
      if (status == 'deleted' || status != 'active') { 
        await signOut(); 
        return null; 
      }
      
      final sessionId = generateSessionId();
      await _firestore.collection('users').doc(user.uid).update({
        'last_login': FieldValue.serverTimestamp(),
        'login_attempts': 0,
        'isOnline': true,
        'audit_trail': FieldValue.arrayUnion([
          {'action': 'auto_login', 'timestamp': Timestamp.now(), 'session_id': sessionId}
        ]),
      });
      
      final role = (data['role'] ?? '').toString();
      final nama = (data['nama_lengkap'] ?? '').toString();
      
      await _cacheUserData({'id': doc.id, ...data});
      
      return _result(true, role: role, nama: nama, userData: data);
    } catch (e) {
      debugPrint('AUTO LOGIN ERROR: $e');
      
      if (e.toString().contains('network') || 
          e.toString().contains('SocketException') ||
          (e is FirebaseException && e.code == 'unavailable')) {
        final prefs = await SharedPreferences.getInstance();
        final cachedRole = prefs.getString('cached_role');
        if (cachedRole != null && _auth.currentUser != null) {
          return _result(true, role: cachedRole);
        }
      }
      
      await signOut();
      return null;
    }
  }

  // =========================================================
  // 🔥 REGISTER (DENGAN ID PEKERJA & FUNGSI)
  // =========================================================

  Future<RegisterResult> register({
    required String nama,
    required String email,
    required String phone,
    required String password,
    required String sessionId,
    String? idPekerja,
    String fungsi = 'operation',
  }) async {
    if (!await _checkConnectionAsync('register')) {
      return RegisterResult(success: false, message: 'Tidak ada koneksi internet. Periksa koneksi Anda.');
    }

    final error = validateRegisterForm(nama: nama, email: email, phone: phone, password: password);
    if (error != null) return RegisterResult(success: false, message: error);

    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

      // 🔑 Pengaman: emailCheck/phoneCheck di bawah query koleksi `users`,
      // yang rules-nya butuh isAuthenticated(). Normalnya sudah ada sesi
      // anonymous dari validateWorkerId() sebelum sampai sini, tapi jaga-jaga
      // kalau register() dipanggil langsung tanpa lewat validasi ID dulu.
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }

      try {
        final emailCheck = await _firestore
            .collection('users')
            .where('email', isEqualTo: email.trim().toLowerCase())
            .limit(1)
            .get();
        
        if (emailCheck.docs.isNotEmpty) {
          return RegisterResult(success: false, message: 'Email sudah terdaftar.\nSilakan login atau gunakan email lain.');
        }

        final phoneCheck = await _firestore
            .collection('users')
            .where('phone', isEqualTo: cleanPhone)
            .limit(1)
            .get();
        
        if (phoneCheck.docs.isNotEmpty) {
          return RegisterResult(success: false, message: 'Nomor HP sudah terdaftar.\nSilakan login atau gunakan nomor lain.');
        }
      } catch (e) {
        debugPrint('Firestore check error: $e');
        return RegisterResult(success: false, message: 'Gagal memverifikasi data. Silakan coba lagi.');
      }

      final credential = await _retryOperation(() => _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      ));
      
      final user = credential.user;
      if (user == null) {
        return RegisterResult(success: false, message: 'Gagal membuat akun. Coba lagi.');
      }

      final now = Timestamp.now();
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'id': user.uid,
          'nama_lengkap': nama.trim(),
          'email': email.trim().toLowerCase(),
          'email_hash': _hashData(email.trim().toLowerCase()),
          'phone': cleanPhone,
          'phone_hash': _hashData(cleanPhone),
          'role': 'mitra',
          'fungsi': fungsi,
          'fungsi_label': _getFungsiLabel(fungsi),
          'id_pekerja': idPekerja ?? '',
          'status_akun': 'active',
          'is_verified': true,
          'account_locked': false,
          'login_attempts': 0,
          'isOnline': false,
          'security': {
            'session_id': sessionId,
            'registered_at': now,
            'security_level': 'standard',
            'created_by': 'self_register',
            'created_by_email': 'self_register',
          },
          'terms_accepted': true,
          'terms_accepted_at': now,
          'terms_version': '2.0.0',
          'created_at': now,
          'updated_at': now,
          'last_login': null,
          'audit_trail': [
            {
              'action': 'self_register',
              'timestamp': now,
              'session_id': sessionId,
              'id_pekerja': idPekerja ?? '',
            }
          ],
        });

        await _firestore.collection('phone_mappings').doc(cleanPhone).set({
          'phone': cleanPhone,
          'email': email.trim().toLowerCase(),
          'user_id': user.uid,
          'created_at': now,
        });

        // 🔔 Kabari semua Superadmin aktif ada Mitra baru daftar
        NotificationService().sendUserRegisteredNotification(
          userName: nama.trim(),
          userEmail: email.trim().toLowerCase(),
          userPhone: cleanPhone,
        );

        return RegisterResult(success: true, message: 'Registrasi berhasil! Silakan login.');
        
      } catch (e) {
        debugPrint('Firestore save error: $e');
        await user.delete();
        return RegisterResult(success: false, message: 'Gagal menyimpan data. Silakan coba lagi.');
      }
      
    } on FirebaseAuthException catch (e) {
      return RegisterResult(success: false, message: _getRegisterErrorMessage(e.code));
    } catch (e) {
      debugPrint('REGISTER ERROR: $e');
      return RegisterResult(success: false, message: 'Terjadi kesalahan sistem. Silakan coba lagi.');
    }
  }

  // =========================================================
  // 🔥 CREATE USER (ADMIN)
  // =========================================================

  Future<CreateUserResult> createUser({
    required String nama,
    required String email,
    required String phone,
    required String password,
    required String role,
    required String fungsi,
    String? idPekerja,
  }) async {
    if (!await _checkConnectionAsync('createUser')) {
      return CreateUserResult(success: false, message: 'Tidak ada koneksi internet. Periksa koneksi Anda.');
    }

    final error = validateRegisterForm(nama: nama, email: email, phone: phone, password: password);
    if (error != null) return CreateUserResult(success: false, message: error);

    try {
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) {
        return CreateUserResult(success: false, message: 'Admin belum login');
      }

      const validRoles = ['superadmin', 'manager', 'pengawas', 'mitra', 'manager_hsse'];
      if (!validRoles.contains(role.toLowerCase())) {
        return CreateUserResult(success: false, message: 'Role tidak valid. Pilih: ${validRoles.join(", ")}');
      }

      final effectiveFungsi = role.toLowerCase() == 'manager_hsse' ? 'hsse' : fungsi;
      
      if (role.toLowerCase() != 'manager_hsse') {
        if (!['operation', 'maintenance', 'hsse', 'gpr', 'bs'].contains(fungsi)) {
          return CreateUserResult(success: false, message: 'Fungsi tidak valid');
        }
      }

      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

      try {
        final emailCheck = await _firestore
            .collection('users')
            .where('email', isEqualTo: email.trim().toLowerCase())
            .limit(1)
            .get();
        if (emailCheck.docs.isNotEmpty) {
          return CreateUserResult(success: false, message: 'Email sudah digunakan oleh user lain');
        }

        final phoneCheck = await _firestore
            .collection('users')
            .where('phone', isEqualTo: cleanPhone)
            .limit(1)
            .get();
        if (phoneCheck.docs.isNotEmpty) {
          return CreateUserResult(success: false, message: 'Nomor HP sudah digunakan oleh user lain');
        }
      } catch (e) {
        debugPrint('Firestore check error: $e');
        return CreateUserResult(success: false, message: 'Gagal memverifikasi data');
      }

      String newUserUid;
      try {
        final FirebaseApp secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}',
          options: Firebase.app().options,
        );
        final FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        
        final UserCredential credential = await _retryOperation(
          () => secondaryAuth.createUserWithEmailAndPassword(
            email: email.trim().toLowerCase(),
            password: password.trim(),
          )
        );
        
        newUserUid = credential.user!.uid;
        await secondaryAuth.signOut();
        await secondaryApp.delete();
      } catch (e) {
        debugPrint('Secondary auth error: $e');
        return CreateUserResult(success: false, message: 'Gagal membuat akun. Email mungkin sudah terdaftar di sistem.');
      }

      final sessionId = generateSessionId();
      final now = Timestamp.now();

      final userData = <String, dynamic>{
        'id': newUserUid,
        'nama_lengkap': nama.trim(),
        'email': email.trim().toLowerCase(),
        'email_hash': _hashData(email.trim().toLowerCase()),
        'phone': cleanPhone,
        'phone_hash': _hashData(cleanPhone),
        'role': role.toLowerCase(),
        'fungsi': effectiveFungsi,
        'fungsi_label': _getFungsiLabel(effectiveFungsi),
        'id_pekerja': idPekerja ?? '',
        'status_akun': 'active',
        'is_verified': true,
        'account_locked': false,
        'login_attempts': 0,
        'isOnline': false,
        'security': {
          'session_id': sessionId,
          'registered_at': now,
          'security_level': role.toLowerCase() == 'manager_hsse' ? 'high' : 'standard',
          'created_by': currentAdmin.uid,
          'created_by_email': currentAdmin.email,
        },
        'terms_accepted': true,
        'terms_accepted_at': now,
        'terms_version': '2.0.0',
        'created_at': now,
        'updated_at': now,
        'last_login': null,
        'audit_trail': [
          {
            'action': 'admin_created',
            'timestamp': now,
            'session_id': sessionId,
            'admin_id': currentAdmin.uid,
            'admin_email': currentAdmin.email,
            'id_pekerja': idPekerja ?? '',
          }
        ],
      };

      if (role.toLowerCase() == 'manager_hsse') {
        userData.addAll({
          'manager_hsse_level': 'manager',
          'manager_hsse_department': 'HSSE',
          'manager_hsse_authority': {
            'can_validate_risk': true,
            'can_approve_high_risk': true,
            'can_issue_stop_work': false,
            'can_validate_safety_procedure': true,
            'can_audit_work_area': false,
          },
          'manager_hsse_certification': [],
          'manager_hsse_license_number': null,
          'manager_hsse_joined_date': now,
        });
      }

      await _firestore.collection('users').doc(newUserUid).set(userData);

      await _firestore.collection('phone_mappings').doc(cleanPhone).set({
        'phone': cleanPhone,
        'email': email.trim().toLowerCase(),
        'user_id': newUserUid,
        'created_at': now,
      });

      await _firestore.collection('system_logs').add({
        'type': 'user_created',
        'admin_id': currentAdmin.uid,
        'admin_email': currentAdmin.email,
        'target_user_id': newUserUid,
        'target_user_email': email.trim().toLowerCase(),
        'target_user_role': role.toLowerCase(),
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Admin membuat user baru: $nama (${role.toUpperCase()})',
      });

      return CreateUserResult(success: true, message: 'User $nama berhasil dibuat sebagai ${_getRoleLabel(role)}');
    } on FirebaseAuthException catch (e) {
      debugPrint('CREATE USER AUTH ERROR: ${e.code}');
      return CreateUserResult(success: false, message: _getCreateUserErrorMessage(e.code));
    } catch (e) {
      debugPrint('CREATE USER ERROR: $e');
      
      if (e.toString().contains('network') || e.toString().contains('SocketException')) {
        return CreateUserResult(success: false, message: 'Koneksi internet terputus. Silakan coba lagi.');
      }
      
      return CreateUserResult(success: false, message: 'Terjadi kesalahan sistem');
    }
  }

  // =========================================================
  // GET ALL USERS
  // =========================================================
  
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      if (!_checkConnection('getAllUsers')) return [];
      
      final snapshot = await _retryOperation(() => _firestore
          .collection('users')
          .orderBy('created_at', descending: true)
          .get());
      
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((user) => (user['status_akun'] ?? 'active') != 'deleted')
          .toList();
    } catch (e) {
      debugPrint('GET ALL USERS ERROR: $e');
      throw _handleFirestoreError(e);
    }
  }

  // =========================================================
  // GET USER BY ID
  // =========================================================
  
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      if (!_checkConnection('getUserById')) return null;
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      if ((data['status_akun'] ?? 'active') == 'deleted') return null;
      
      return {'id': doc.id, ...data};
    } catch (e) {
      debugPrint('GET USER BY ID ERROR: $e');
      throw _handleFirestoreError(e);
    }
  }

  // =========================================================
  // UPDATE USER
  // =========================================================
  
  Future<UpdateUserResult> updateUser({
    required String userId,
    required String nama,
    required String email,
    required String phone,
    String? password,
    required String role,
    required String fungsi,
    String? idPekerja,
    required String sessionId,
  }) async {
    try {
      if (!await _checkConnectionAsync('updateUser')) {
        return UpdateUserResult(success: false, message: 'Tidak ada koneksi internet');
      }
      
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) return UpdateUserResult(success: false, message: 'Admin belum login');

      const validRoles = ['superadmin', 'manager', 'pengawas', 'mitra', 'manager_hsse'];
      if (!validRoles.contains(role.toLowerCase())) {
        return UpdateUserResult(success: false, message: 'Role tidak valid');
      }

      final userRef = _firestore.collection('users').doc(userId);
      final existingDoc = await userRef.get();
      if (!existingDoc.exists) return UpdateUserResult(success: false, message: 'User tidak ditemukan');
      
      final currentData = existingDoc.data()!;
      
      if ((currentData['status_akun'] ?? 'active') == 'deleted') {
        return UpdateUserResult(success: false, message: 'User sudah dihapus');
      }
      
      final updateData = <String, dynamic>{};

      if (nama.isNotEmpty && nama != currentData['nama_lengkap']) {
        updateData['nama_lengkap'] = nama.trim();
      }

      if (email.isNotEmpty && email.toLowerCase() != currentData['email']) {
        final emailCheck = await _firestore
            .collection('users')
            .where('email', isEqualTo: email.toLowerCase())
            .limit(1)
            .get();
        if (emailCheck.docs.isNotEmpty && emailCheck.docs.first.id != userId) {
          return UpdateUserResult(success: false, message: 'Email sudah digunakan oleh user lain');
        }
        updateData['email'] = email.toLowerCase();
        updateData['email_hash'] = _hashData(email.toLowerCase());
      }

      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanPhone != _cleanPhone(currentData['phone'] ?? '')) {
        final phoneCheck = await _firestore
            .collection('users')
            .where('phone', isEqualTo: cleanPhone)
            .limit(1)
            .get();
        if (phoneCheck.docs.isNotEmpty && phoneCheck.docs.first.id != userId) {
          return UpdateUserResult(success: false, message: 'Nomor HP sudah digunakan oleh user lain');
        }
        updateData['phone'] = cleanPhone;
        updateData['phone_hash'] = _hashData(cleanPhone);
        
        if (currentData['phone'] != null) {
          await _firestore.collection('phone_mappings').doc(_cleanPhone(currentData['phone'])).delete();
        }
        await _firestore.collection('phone_mappings').doc(cleanPhone).set({
          'phone': cleanPhone,
          'email': email.isNotEmpty ? email.toLowerCase() : currentData['email'],
          'user_id': userId,
          'updated_at': Timestamp.now(),
        });
      }

      if (role.isNotEmpty && role.toLowerCase() != currentData['role']) {
        final oldRole = currentData['role'];
        final newRole = role.toLowerCase();
        updateData['role'] = newRole;
        
        if (newRole == 'manager_hsse') {
          updateData['fungsi'] = 'hsse';
          updateData['fungsi_label'] = 'HSSE';
          updateData['security.security_level'] = 'high';
          updateData['manager_hsse_level'] = 'manager';
          updateData['manager_hsse_department'] = 'HSSE';
          updateData['manager_hsse_authority'] = {
            'can_validate_risk': true, 'can_approve_high_risk': true,
            'can_issue_stop_work': false, 'can_validate_safety_procedure': true,
            'can_audit_work_area': false,
          };
          updateData['manager_hsse_certification'] = [];
          updateData['manager_hsse_joined_date'] = Timestamp.now();
        }
        
        if (oldRole == 'manager_hsse' && newRole != 'manager_hsse') {
          updateData['manager_hsse_level'] = FieldValue.delete();
          updateData['manager_hsse_department'] = FieldValue.delete();
          updateData['manager_hsse_authority'] = FieldValue.delete();
          updateData['manager_hsse_certification'] = FieldValue.delete();
          updateData['manager_hsse_license_number'] = FieldValue.delete();
          updateData['manager_hsse_joined_date'] = FieldValue.delete();
          updateData['security.security_level'] = 'standard';
        }
      }

      if (fungsi.isNotEmpty && fungsi != currentData['fungsi']) {
        updateData['fungsi'] = fungsi;
        updateData['fungsi_label'] = _getFungsiLabel(fungsi);
      }

      if (idPekerja != null) {
        updateData['id_pekerja'] = idPekerja;
      }

      if (password != null && password.isNotEmpty) {
        try {
          await _auth.sendPasswordResetEmail(email: currentData['email']);
        } catch (e) {
          debugPrint('PASSWORD RESET EMAIL ERROR: $e');
        }
      }

      updateData['updated_at'] = FieldValue.serverTimestamp();
      updateData['audit_trail'] = FieldValue.arrayUnion([
        {
          'action': 'user_updated_by_admin',
          'timestamp': Timestamp.now(),
          'session_id': sessionId,
          'admin_id': currentAdmin.uid,
        }
      ]);

      await userRef.update(updateData);

      await _firestore.collection('system_logs').add({
        'type': 'user_updated',
        'admin_id': currentAdmin.uid,
        'target_user_id': userId,
        'target_user_email': currentData['email'],
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'User diperbarui: $nama',
      });

      return UpdateUserResult(success: true, message: 'User berhasil diperbarui');
    } catch (e) {
      debugPrint('UPDATE USER ERROR: $e');
      return UpdateUserResult(success: false, message: 'Gagal memperbarui user: ${e.toString()}');
    }
  }

  // =========================================================
  // DELETE USER
  // =========================================================
  
  Future<DeleteUserResult> deleteUser({
    required String userId,
    required String sessionId,
  }) async {
    try {
      if (!await _checkConnectionAsync('deleteUser')) {
        return DeleteUserResult(success: false, message: 'Tidak ada koneksi internet');
      }
      
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) return DeleteUserResult(success: false, message: 'Admin belum login');

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return DeleteUserResult(success: false, message: 'User tidak ditemukan');

      final userData = userDoc.data()!;
      if (userId == currentAdmin.uid) {
        return DeleteUserResult(success: false, message: 'Tidak dapat menghapus akun sendiri');
      }

      final userName = userData['nama_lengkap'] ?? 'Unknown';
      final userEmail = userData['email'] ?? 'Unknown';
      final userRole = userData['role'] ?? 'unknown';
      final userPhone = userData['phone'];

      await _firestore.collection('deleted_users').doc(userId).set({
        ...userData,
        'deleted_at': FieldValue.serverTimestamp(),
        'deleted_by': currentAdmin.uid,
        'deleted_by_email': currentAdmin.email,
        'deleted_by_name': currentAdmin.displayName ?? 'Admin',
        'deletion_reason': 'Dihapus permanen oleh admin',
      });

      await _firestore.collection('system_logs').add({
        'type': 'user_deleted_permanent',
        'admin_id': currentAdmin.uid,
        'admin_email': currentAdmin.email,
        'target_user_id': userId,
        'target_user_email': userEmail,
        'target_user_name': userName,
        'target_user_role': userRole,
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'User "$userName" ($userEmail) dihapus permanen oleh admin',
      });

      if (userPhone != null) {
        final cleanPhone = _cleanPhone(userPhone);
        try {
          await _firestore.collection('phone_mappings').doc(cleanPhone).delete();
        } catch (e) {
          debugPrint('⚠️ Delete phone mapping error: $e');
        }
      }

      await _firestore.collection('users').doc(userId).delete();

      return DeleteUserResult(success: true, message: 'User "$userName" berhasil dihapus permanen');
    } catch (e) {
      debugPrint('❌ DELETE USER ERROR: $e');
      return DeleteUserResult(success: false, message: 'Gagal menghapus user: ${e.toString()}');
    }
  }

  // =========================================================
  // TOGGLE USER STATUS
  // =========================================================
  
  Future<ToggleStatusResult> toggleUserStatus({
    required String userId,
    required String newStatus,
    required String sessionId,
  }) async {
    try {
      if (!await _checkConnectionAsync('toggleUserStatus')) {
        return ToggleStatusResult(success: false, message: 'Tidak ada koneksi internet');
      }
      
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) return ToggleStatusResult(success: false, message: 'Admin belum login');
      
      const validStatus = ['active', 'inactive', 'blocked'];
      if (!validStatus.contains(newStatus)) return ToggleStatusResult(success: false, message: 'Status tidak valid');
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return ToggleStatusResult(success: false, message: 'User tidak ditemukan');
      
      if (userId == currentAdmin.uid) {
        return ToggleStatusResult(success: false, message: 'Tidak dapat mengubah status akun sendiri');
      }
      
      final currentStatus = userDoc.data()!['status_akun'] ?? 'active';
      await _firestore.collection('users').doc(userId).update({
        'status_akun': newStatus,
        'isOnline': false,
        'audit_trail': FieldValue.arrayUnion([
          {
            'action': 'status_changed_by_admin',
            'timestamp': Timestamp.now(),
            'session_id': sessionId,
            'admin_id': currentAdmin.uid,
            'old_status': currentStatus,
            'new_status': newStatus,
          }
        ]),
      });
      
      await _firestore.collection('system_logs').add({
        'type': 'user_status_changed',
        'admin_id': currentAdmin.uid,
        'target_user_id': userId,
        'old_status': currentStatus,
        'new_status': newStatus,
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Status user diubah dari $currentStatus menjadi $newStatus',
      });
      
      final message = newStatus == 'active'
          ? 'User berhasil diaktifkan'
          : newStatus == 'inactive'
              ? 'User berhasil dinonaktifkan'
              : 'User berhasil diblokir';
      return ToggleStatusResult(success: true, message: message);
    } catch (e) {
      debugPrint('TOGGLE STATUS ERROR: $e');
      return ToggleStatusResult(success: false, message: 'Gagal mengubah status user');
    }
  }

  // =========================================================
  // BULK STATUS CHANGE
  // =========================================================
  
  Future<BulkStatusResult> bulkStatusChange({
    required List<String> userIds,
    required String newStatus,
    required String sessionId,
  }) async {
    try {
      if (!await _checkConnectionAsync('bulkStatusChange')) {
        return BulkStatusResult(success: false, message: 'Tidak ada koneksi internet');
      }
      
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) return BulkStatusResult(success: false, message: 'Admin belum login');
      if (userIds.isEmpty) return BulkStatusResult(success: false, message: 'Tidak ada user yang dipilih');
      
      const validStatus = ['active', 'inactive', 'blocked'];
      if (!validStatus.contains(newStatus)) return BulkStatusResult(success: false, message: 'Status tidak valid');
      
      final batch = _firestore.batch();
      final timestamp = Timestamp.now();
      for (var userId in userIds) {
        batch.update(_firestore.collection('users').doc(userId), {
          'status_akun': newStatus,
          'isOnline': false,
          'audit_trail': FieldValue.arrayUnion([
            {
              'action': 'bulk_status_change_by_admin',
              'timestamp': timestamp,
              'session_id': sessionId,
              'admin_id': currentAdmin.uid,
              'new_status': newStatus,
            }
          ]),
        });
      }
      await batch.commit();
      
      await _firestore.collection('system_logs').add({
        'type': 'bulk_status_change',
        'admin_id': currentAdmin.uid,
        'affected_count': userIds.length,
        'new_status': newStatus,
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Bulk status change to $newStatus for ${userIds.length} users',
      });
      
      return BulkStatusResult(success: true, message: 'Status ${userIds.length} user berhasil diubah', affectedCount: userIds.length);
    } catch (e) {
      debugPrint('BULK STATUS ERROR: $e');
      return BulkStatusResult(success: false, message: 'Gagal mengubah status user secara massal');
    }
  }

  // =========================================================
  // SEND PASSWORD RESET EMAIL (ADMIN)
  // =========================================================
  
  Future<ResetPasswordResult> adminResetPassword({
    required String email,
    required String sessionId,
  }) async {
    try {
      if (!await _checkConnectionAsync('adminResetPassword')) {
        return ResetPasswordResult(success: false, errorMessage: 'Tidak ada koneksi internet');
      }
      
      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) return ResetPasswordResult(success: false, errorMessage: 'Admin belum login');
      
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      if (query.docs.isEmpty) return ResetPasswordResult(success: false, errorMessage: 'Email tidak ditemukan');
      
      final uid = query.docs.first.id;
      await _auth.sendPasswordResetEmail(email: email.trim());
      
      await _firestore.collection('users').doc(uid).update({
        'audit_trail': FieldValue.arrayUnion([
          {
            'action': 'password_reset_by_admin',
            'timestamp': Timestamp.now(),
            'session_id': sessionId,
            'admin_id': currentAdmin.uid,
          }
        ]),
      });
      
      await _firestore.collection('system_logs').add({
        'type': 'password_reset_by_admin',
        'admin_id': currentAdmin.uid,
        'target_user_id': uid,
        'target_user_email': email,
        'session_id': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Admin mereset password user: ${query.docs.first.data()['nama_lengkap']}',
      });
      
      return ResetPasswordResult(success: true, errorMessage: '');
    } on FirebaseAuthException catch (e) {
      return ResetPasswordResult(success: false, errorMessage: _getResetPasswordErrorMessage(e.code));
    } catch (e) {
      debugPrint('ADMIN RESET PASSWORD ERROR: $e');
      return ResetPasswordResult(success: false, errorMessage: 'Gagal mengirim email reset password');
    }
  }

  // =========================================================
  // RESET PASSWORD (USER SELF SERVICE)
  // =========================================================
  
  // 🔗 GANTI SESUAI DOMAIN YANG SUDAH DI-VERIFY sebagai Android App Link /
  // iOS Universal Link untuk project ini. Link reset password akan mengarah
  // langsung ke sini (bukan ke halaman hosted Firebase), lalu dibuka oleh
  // app itu sendiri via deep link, ditangani route '/reset-password'.
  static const String _resetPasswordContinueUrl =
      'https://GANTI-DENGAN-DOMAIN-ANDA.com/reset-password';
  static const String _androidPackageName = 'com.pertamina.kmj.project_otp_kmj';
  // 🔧 GANTI dengan bundle id iOS asli project ini kalau ada target iOS.
  static const String _iosBundleId = 'com.pertamina.kmj.projectOtpKmj';

  Future<ResetPasswordResult> sendResetPasswordEmail({
    required String email,
    required String sessionId,
  }) async {
    try {
      if (!await _checkConnectionAsync('sendResetPasswordEmail')) {
        return ResetPasswordResult(success: false, errorMessage: 'Tidak ada koneksi internet');
      }

      final actionCodeSettings = ActionCodeSettings(
        // sessionId ikut dibawa di continue URL murni buat referensi/log,
        // TIDAK dipakai lagi untuk menentukan sukses/gagalnya reset.
        url: '$_resetPasswordContinueUrl?session=$sessionId',
        handleCodeInApp: true,
        androidPackageName: _androidPackageName,
        androidInstallApp: true,
        androidMinimumVersion: '1',
        iOSBundleId: _iosBundleId,
      );

      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: actionCodeSettings,
      );
      await _addResetAuditTrail(action: 'reset_password_request', email: email, sessionId: sessionId);
      return ResetPasswordResult(success: true);
    } on FirebaseAuthException catch (e) {
      return ResetPasswordResult(success: false, errorMessage: _getResetPasswordErrorMessage(e.code));
    } catch (e) {
      debugPrint('RESET PASSWORD ERROR: $e');
      return ResetPasswordResult(success: false, errorMessage: 'Terjadi kesalahan');
    }
  }

  /// Validasi oobCode dari deep link & ambil email pemiliknya, sebelum
  /// menampilkan form password baru. Dipanggil begitu app dibuka lewat
  /// link reset password.
  Future<CheckResetCodeResult> checkPasswordResetCode(String oobCode) async {
    try {
      final email = await _auth.verifyPasswordResetCode(oobCode);
      return CheckResetCodeResult(success: true, email: email);
    } on FirebaseAuthException catch (e) {
      return CheckResetCodeResult(success: false, errorMessage: _getResetCodeErrorMessage(e.code));
    } catch (e) {
      debugPrint('CHECK RESET CODE ERROR: $e');
      return CheckResetCodeResult(success: false, errorMessage: 'Link reset password tidak valid.');
    }
  }

  /// Terapkan password baru menggunakan oobCode dari deep link.
  /// Ini MENGGANTIKAN seluruh mekanisme lama (verifyPasswordReset yang
  /// coba login pakai password palsu). Begitu method ini sukses, password
  /// SUDAH PASTI berubah di sisi Firebase — tidak ada lagi tebak-tebakan.
  Future<ResetPasswordResult> applyPasswordReset({
    required String oobCode,
    required String newPassword,
    String? sessionId,
  }) async {
    try {
      if (!await _checkConnectionAsync('applyPasswordReset')) {
        return ResetPasswordResult(success: false, errorMessage: 'Tidak ada koneksi internet');
      }

      final email = await _auth.verifyPasswordResetCode(oobCode);
      await _auth.confirmPasswordReset(code: oobCode, newPassword: newPassword);

      await _addResetAuditTrail(
        action: 'reset_password_complete',
        email: email,
        sessionId: sessionId ?? generateSessionId(),
      );

      return ResetPasswordResult(success: true);
    } on FirebaseAuthException catch (e) {
      return ResetPasswordResult(success: false, errorMessage: _getResetCodeErrorMessage(e.code));
    } catch (e) {
      debugPrint('APPLY PASSWORD RESET ERROR: $e');
      return ResetPasswordResult(success: false, errorMessage: 'Terjadi kesalahan. Silakan coba lagi.');
    }
  }

  String _getResetCodeErrorMessage(String code) {
    switch (code) {
      case 'expired-action-code':
        return 'Link reset password sudah kedaluwarsa. Silakan minta link baru.';
      case 'invalid-action-code':
        return 'Link reset password tidak valid atau sudah pernah dipakai.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan. Hubungi admin.';
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      case 'weak-password':
        return 'Password terlalu lemah. Minimal 8 karakter dengan kombinasi huruf dan angka.';
      default:
        return 'Link reset password tidak valid (kode: $code).';
    }
  }

  // =========================================================
  // REMEMBER ME
  // =========================================================
  
  Future<RememberMeData> loadRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return RememberMeData(
        remembered: prefs.getBool('remember_me') ?? false,
        identity: prefs.getString('saved_identity') ?? '',
      );
    } catch (e) {
      return RememberMeData(remembered: false, identity: '');
    }
  }

  Future<void> _saveRememberMe(String identity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', true);
      await prefs.setString('saved_identity', identity);
    } catch (e) {
      debugPrint('SAVE REMEMBER ME ERROR: $e');
    }
  }

  Future<void> _clearRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_identity');
      await prefs.setBool('remember_me', false);
    } catch (e) {
      debugPrint('CLEAR REMEMBER ME ERROR: $e');
    }
  }

  // =========================================================
  // MANAGER HSSE METHODS
  // =========================================================
  
  Future<bool> isManagerHsse() async {
    final role = await getUserRole();
    return role == 'manager_hsse';
  }

  Future<List<Map<String, dynamic>>> getActiveManagerHsse() async {
    try {
      if (!_checkConnection('getActiveManagerHsse')) return [];
      
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'manager_hsse')
          .where('status_akun', isEqualTo: 'active')
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('GET MANAGER HSSE ERROR: $e');
      return [];
    }
  }

  Future<bool> updateManagerHsseAuthority({
    required String userId,
    required Map<String, bool> authority,
  }) async {
    try {
      if (!_checkConnection('updateManagerHsseAuthority')) return false;
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      final role = userDoc.data()?['role'] ?? '';
      if (role != 'manager_hsse') return false;
      await _firestore.collection('users').doc(userId).update({
        'manager_hsse_authority': authority,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('UPDATE MANAGER HSSE AUTHORITY ERROR: $e');
      return false;
    }
  }

  Future<bool> addManagerHsseCertification({
    required String userId,
    required String certification,
  }) async {
    try {
      if (!_checkConnection('addManagerHsseCertification')) return false;
      
      await _firestore.collection('users').doc(userId).update({
        'manager_hsse_certification': FieldValue.arrayUnion([certification]),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('ADD CERTIFICATION ERROR: $e');
      return false;
    }
  }

  // =========================================================
  // DASHBOARD
  // =========================================================
  
  Widget getDashboardForRole(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':     return const SuperAdminDashboard();
      case 'manager':        return const ManagerDashboard();
      case 'pengawas':       return const PengawasDashboard();
      case 'mitra':          return const MitraDashboard();
      case 'manager_hsse':   return const ManagerDashboard();
      default:               return const WelcomeScreen();
    }
  }

  // =========================================================
  // 🔥 SIGN OUT - FULLY FIXED (ANTI INFINITE LOOP)
  // =========================================================
  
  Future<void> signOut() async {
    // 🔥 GUARD: Cegah double call yang menyebabkan infinite loop
    if (_isSigningOut) {
      debugPrint('⚠️ signOut already in progress, ignoring duplicate call');
      return;
    }
    
    _isSigningOut = true;
    debugPrint('🔄 Starting signOut process...');
    
    try {
      // 1. Update status offline di Firestore
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await _firestore.collection('users').doc(user.uid).update({
            'isOnline': false,
            'last_active': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('⚠️ Update online status error: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Update online status outer error: $e');
    }
    
    // 2. Hapus cache lokal
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_role');
      await prefs.remove('cached_nama');
      await prefs.remove('cached_user_data');
      debugPrint('🧹 Local cache cleared');
    } catch (e) {
      debugPrint('⚠️ Clear cache error: $e');
    }
    
    // 3. Cancel stream subscriptions dulu sebelum signOut
    //    supaya listener tidak trigger lagi
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _authSubscription?.cancel();
    _authSubscription = null;
    debugPrint('🔌 Stream subscriptions cancelled');
    
    // 4. Sign out dari Firebase Auth
    try {
      await _auth.signOut();
      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Firebase signOut error: $e');
    }
    
    // 5. Reset flag
    _isSigningOut = false;
  }

  // =========================================================
  // CLEANUP
  // =========================================================
  
  Future<void> cleanupOrphanPhoneMappings() async {
    if (!_checkConnection('cleanupOrphanPhoneMappings')) return;
    
    try {
      final mappings = await _firestore.collection('phone_mappings').get();
      for (var doc in mappings.docs) {
        final userId = doc.data()['user_id'];
        if (userId == null) {
          await doc.reference.delete();
          continue;
        }
        
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists || (userDoc.data()?['status_akun'] ?? '') == 'deleted') {
          await doc.reference.delete();
          debugPrint('🧹 Cleaned orphan phone mapping: ${doc.id}');
        }
      }
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }

  // =========================================================
  // HELPER
  // =========================================================
  
  String generateSessionId() {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomInt = random.nextInt(999999);
    return 'session_${timestamp}_${randomInt.toString().padLeft(6, '0')}';
  }

  String _hashData(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  String _cleanPhone(String phone) {
    return phone.toString().replaceAll(RegExp(r'[^\d]'), '');
  }

  String _getFungsiLabel(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation':   return 'Operation';
      case 'lab':         return 'Laboratorium';
      case 'maintenance': return 'Maintenance';
      case 'hsse':        return 'HSSE';
      case 'gpr':         return 'GPR';
      case 'bs':          return 'Business Support';
      default:            return fungsi.toUpperCase();
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':     return 'SUPERADMIN';
      case 'manager':        return 'MANAGER';
      case 'pengawas':       return 'PENGAWAS';
      case 'mitra':          return 'MITRA';
      case 'manager_hsse':   return 'MANAGER HSSE';
      default:               return role.toUpperCase();
    }
  }

  Exception _handleFirestoreError(dynamic e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied': return Exception('Anda tidak memiliki izin untuk mengakses data');
        case 'unavailable': return Exception('Layanan sedang tidak tersedia. Coba lagi nanti.');
        case 'deadline-exceeded': return Exception('Koneksi timeout. Periksa koneksi Anda.');
        default: return Exception('Error: ${e.message}');
      }
    }
    if (e.toString().contains('network') || e.toString().contains('SocketException')) {
      return Exception('Gagal terhubung ke server. Periksa koneksi internet.');
    }
    return Exception(e.toString());
  }

  Future<void> _trackFailedLogin(String identity) async {
    try {
      if (identity.contains('@')) {
        final query = await _firestore
            .collection('users')
            .where('email', isEqualTo: identity.trim().toLowerCase())
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          final attempts = (doc.data()['login_attempts'] ?? 0) + 1;
          await doc.reference.update({
            'login_attempts': attempts,
            'last_failed_login': Timestamp.now(),
            'account_locked': attempts >= 5 ? true : false,
          });
        }
      }
    } catch (e) {
      debugPrint('TRACK FAILED LOGIN ERROR: $e');
    }
  }

  LoginResult _result(bool success,
      {String error = '', String code = '', Map<String, dynamic>? userData, String role = '', String nama = ''}) {
    _lastResult = LoginResult(
      success: success, errorMessage: error, errorCode: code,
      userData: userData, role: role, nama: nama,
    );
    return _lastResult!;
  }

  // =========================================================
  // ERROR MESSAGES
  // =========================================================
  
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':        return 'Format email tidak valid.\nContoh: nama@email.com';
      case 'user-not-found':       return 'Email tidak terdaftar.\nPeriksa kembali atau hubungi admin.';
      case 'wrong-password':       return 'Password salah.\nCoba lagi atau klik "Lupa Password".';
      case 'invalid-credential':   return 'Email atau password tidak sesuai.';
      case 'user-disabled':        return 'Akun dinonaktifkan.\nHubungi admin.';
      case 'too-many-requests':    return 'Terlalu banyak percobaan.\nCoba lagi dalam 1 menit.';
      case 'network-request-failed': return 'Gagal terhubung ke server.\nPeriksa koneksi internet.';
      case 'operation-not-allowed':  return 'Login belum diaktifkan.\nHubungi admin.';
      case 'unavailable':          return 'Layanan sedang tidak tersedia.\nCoba lagi nanti.';
      default:                     return 'Login gagal (kode: $code).\nSilakan coba lagi.';
    }
  }

  String _getRegisterErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Email sudah terdaftar.\nSilakan login atau gunakan email lain.';
      case 'invalid-email':        return 'Format email tidak valid.\nContoh: nama@email.com';
      case 'weak-password':        return 'Password terlalu lemah.\nGunakan minimal 8 karakter dengan kombinasi huruf dan angka.';
      case 'operation-not-allowed': return 'Pendaftaran belum diaktifkan.\nHubungi admin.';
      case 'network-request-failed': return 'Gagal terhubung ke server.\nPeriksa koneksi internet.';
      default:                     return 'Pendaftaran gagal. Silakan coba lagi.';
    }
  }

  String _getResetPasswordErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':     return 'Format email tidak valid.';
      case 'user-not-found':    return 'Email tidak terdaftar.';
      case 'too-many-requests': return 'Terlalu banyak permintaan.\nCoba lagi nanti.';
      default:                  return 'Gagal reset password.';
    }
  }

  String _getCreateUserErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Email sudah digunakan.\nGunakan email lain.';
      case 'invalid-email':        return 'Format email tidak valid.';
      case 'weak-password':        return 'Password terlalu lemah.\nMinimal 8 karakter dengan kombinasi huruf dan angka.';
      case 'operation-not-allowed': return 'Pendaftaran belum diaktifkan.';
      default:                     return 'Gagal membuat user.';
    }
  }

  Future<void> _addResetAuditTrail({
    required String action,
    required String email,
    required String sessionId,
  }) async {
    try {
      // 🔑 Query email== butuh isAuthenticated() (rules `users` read).
      // Di forgot-password flow user belum login, jadi pastikan ada sesi
      // (anonymous cukup) sebelum query. Rules `users` update sudah dilonggarkan
      // khusus untuk menambah SATU entry audit_trail (lihat isValidResetAuditAppend
      // di firestore.rules), jadi write di bawah tidak perlu jadi diri sendiri/admin.
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }

      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (query.docs.isEmpty) return;
      final uid = query.docs.first.id;
      await _firestore.collection('users').doc(uid).update({
        'audit_trail': FieldValue.arrayUnion([
          {'action': action, 'timestamp': Timestamp.now(), 'session_id': sessionId, 'email': email}
        ]),
      });
    } catch (e) {
      debugPrint('RESET AUDIT ERROR: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════════════════════

class LoginResult {
  final bool success;
  final String errorMessage;
  final String errorCode;
  final Map<String, dynamic>? userData;
  final String role;
  final String nama;

  LoginResult({
    required this.success,
    this.errorMessage = '',
    this.errorCode = '',
    this.userData,
    this.role = '',
    this.nama = '',
  });
}

class RegisterResult {
  final bool success;
  final String message;
  RegisterResult({required this.success, required this.message});
}

class RememberMeData {
  final bool remembered;
  final String identity;
  RememberMeData({required this.remembered, required this.identity});
}

class ResetPasswordResult {
  final bool success;
  final String errorMessage;
  ResetPasswordResult({required this.success, this.errorMessage = ''});
}

class CheckResetCodeResult {
  final bool success;
  final String errorMessage;
  final String? email;
  CheckResetCodeResult({required this.success, this.errorMessage = '', this.email});
}

class CreateUserResult {
  final bool success;
  final String message;
  CreateUserResult({required this.success, required this.message});
}

class UpdateUserResult {
  final bool success;
  final String message;
  UpdateUserResult({required this.success, required this.message});
}

class DeleteUserResult {
  final bool success;
  final String message;
  DeleteUserResult({required this.success, required this.message});
}

class ToggleStatusResult {
  final bool success;
  final String message;
  ToggleStatusResult({required this.success, required this.message});
}

class BulkStatusResult {
  final bool success;
  final String message;
  final int? affectedCount;
  BulkStatusResult({required this.success, required this.message, this.affectedCount});
}