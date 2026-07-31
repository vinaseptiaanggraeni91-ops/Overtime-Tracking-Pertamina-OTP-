import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';

class RegisterService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ================= ENKRIPSI DATA =================
  String hashData(String data) {
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // ================= SESSION ID =================
  String generateSessionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'session_$timestamp${random.nextInt(10000)}';
  }

  // ================= GET FUNGSI LABEL =================
  String getFungsiLabel(String fungsi) {
    switch (fungsi) {
      case 'operation':
        return 'Operation';
      case 'maintenance':
        return 'Maintenance';
      case 'hsse':
        return 'HSSE';
      case 'gpr':
        return 'GPR';
      case 'bs':
        return 'BS';
      default:
        return fungsi;
    }
  }

  // ================= GET FIREBASE ERROR MESSAGE =================
  String getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan gunakan email lain atau login.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan kombinasi yang lebih kuat.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet. Periksa jaringan Anda.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Tunggu beberapa saat.';
      case 'operation-not-allowed':
        return 'Registrasi sedang dinonaktifkan. Hubungi admin.';
      default:
        return 'Registrasi gagal. Silakan coba lagi.';
    }
  }

  // ================= PROSES REGISTER =================
  Future<void> register({
    required String email,
    required String password,
    required String nama,
    required String phone,
    required String fungsi,
    required String sessionId,
  }) async {
    // Bersihkan input
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.trim().replaceAll(RegExp(r'[^\d]'), '');
    final cleanNama = nama.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Dapatkan label fungsi
    String fungsiLabel = getFungsiLabel(fungsi);

    // Buat user di Firebase Auth
    final UserCredential userCredential = await _auth
        .createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password.trim(),
    ).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        throw TimeoutException("Koneksi timeout. Periksa jaringan Anda.");
      },
    );

    final User? user = userCredential.user;
    if (user == null) {
      throw Exception("Gagal membuat akun");
    }

    // SIMPAN KE FIRESTORE
    await _firestore
        .collection("users")
        .doc(user.uid)
        .set({
      // IDENTITAS DASAR (String)
      "id": user.uid,
      "nama_lengkap": cleanNama,
      "email": cleanEmail,
      "email_hash": hashData(cleanEmail),
      "phone": cleanPhone,
      "phone_hash": hashData(cleanPhone),
      "role": "mitra",
      "fungsi": fungsi,
      "fungsi_label": fungsiLabel,
      
      // STATUS AKUN (String, boolean, number)
      "status_akun": "active",
      "is_verified": true,
      "account_locked": false,
      "login_attempts": 0,
      
      // KEAMANAN (Map)
      "security": {
        "session_id": sessionId,
        "registered_at": FieldValue.serverTimestamp(),
        "security_level": "standard",
      },
      
      // TERMS (boolean, Timestamp, String)
      "terms_accepted": true,
      "terms_accepted_at": FieldValue.serverTimestamp(),
      "terms_version": "1.0",
      
      // METADATA (Timestamp, boolean)
      "created_at": FieldValue.serverTimestamp(),
      "last_login": FieldValue.serverTimestamp(),
      "profile_complete": true,
      
      // AUDIT TRAIL
      "audit_trail": [
        {
          "action": "register",
          "timestamp": DateTime.now(),
          "session_id": sessionId,
        }
      ],
    });
  }
}