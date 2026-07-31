// lib/core/utils/user_helpers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserHelpers {
  // ================= COLOR PALETTE =================
  // Primary Colors
  static const Color headerBlue = Color(0xFF1E3C72);
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF1976D2);
  
  // Accent Colors
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color accentLightBlue = Color(0xFF42A5F5);
  static const Color accentSky = Color(0xFF64B5F6);
  static const Color accentCyan = Color(0xFF26C6DA);
  static const Color accentIndigo = Color(0xFF3F51B5);
  
  // Status Colors
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentRed = Color(0xFFF44336);
  static const Color accentPink = Color(0xFFE91E63);
  static const Color accentDeepPurple = Color(0xFF7C3AED);
  static const Color accentYellow = Color(0xFFF59E0B); // Untuk warning/nonaktif
  static const Color accentInfo = Color(0xFF3B82F6); // Untuk info
  
  // Background Colors
  static const Color bgWhite = Color(0xFFF5F7FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color dividerColor = Color(0xFFE3E8F0);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF4A5B6B);
  static const Color textLight = Color(0xFF8FA0B4);
  static const Color textHint = Color(0xFFB0BEC5);
  
  // Status Background Colors (with opacity)
  static Color get statusActiveBg => accentGreen.withOpacity(0.1);
  static Color get statusInactiveBg => accentOrange.withOpacity(0.1);
  static Color get statusBlockedBg => accentRed.withOpacity(0.1);

  // ================= ROLE HELPERS =================
  static String roleLabel(String role) {
    switch (role) {
      case 'superadmin': return 'Super Admin';
      case 'manager': return 'Manager';
      case 'pengawas': return 'Pengawas';
      case 'mitra': return 'Mitra';
      default: return role;
    }
  }

  static Color roleColor(String role) {
    switch (role) {
      case 'superadmin': return accentIndigo;
      case 'manager': return accentBlue;
      case 'pengawas': return accentCyan;
      case 'mitra': return accentOrange;
      case 'officer_safety': return accentDeepPurple;
      default: return textLight;
    }
  }

  static IconData roleIcon(String role) {
    switch (role) {
      case 'superadmin': return Icons.shield_rounded;
      case 'manager': return Icons.stars_rounded;
      case 'pengawas': return Icons.verified_rounded;
      case 'mitra': return Icons.person_rounded;
      case 'officer_safety': return Icons.health_and_safety_rounded;
      default: return Icons.person_outline_rounded;
    }
  }

  static List<String> get roleList => ['superadmin', 'manager', 'pengawas', 'mitra'];
  static List<String> get roleLabelList => ['Super Admin', 'Manager', 'Pengawas', 'Mitra'];

  // ================= STATUS HELPERS =================
  static String statusLabel(String status) {
    switch (status) {
      case 'active': return 'Aktif'; // 🔥 Diubah ke Bahasa Indonesia
      case 'inactive': return 'Tidak Aktif'; // 🔥 Diubah ke Bahasa Indonesia
      case 'blocked': return 'Diblokir'; // 🔥 Diubah ke Bahasa Indonesia
      default: return status;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'active': return accentGreen;
      case 'inactive': return accentOrange;
      case 'blocked': return accentRed;
      default: return textLight;
    }
  }

  static Color statusBackgroundColor(String status) {
    switch (status) {
      case 'active': return statusActiveBg;
      case 'inactive': return statusInactiveBg;
      case 'blocked': return statusBlockedBg;
      default: return textLight.withOpacity(0.1);
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case 'active': return Icons.check_circle_rounded;
      case 'inactive': return Icons.pause_circle_rounded;
      case 'blocked': return Icons.block_rounded;
      default: return Icons.help_rounded;
    }
  }

  static List<String> get statusList => ['active', 'inactive', 'blocked'];
  static List<String> get statusLabelList => ['Aktif', 'Tidak Aktif', 'Diblokir']; // 🔥 Diubah ke Bahasa Indonesia

  // ================= FUNGSI HELPERS =================
  static String fungsiLabel(String fungsi) {
    switch (fungsi) {
      case 'operation': return 'Operasional'; 
      case 'maintenance': return 'Maintenance'; 
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'Business Support';
      default: return fungsi;
    }
  }

  static Color fungsiColor(String fungsi) {
    switch (fungsi) {
      case 'operation': return accentBlue;
      case 'maintenance': return accentOrange;
      case 'hsse': return accentGreen;
      case 'gpr': return accentCyan;
      case 'bs': return accentPink;
      default: return textLight;
    }
  }

  static List<String> get fungsiList => ['operation', 'maintenance', 'hsse', 'gpr', 'bs'];
  static List<String> get fungsiLabelList => ['Operational', 'Maintenance', 'HSSE', 'GPR', 'Business Support']; // 🔥 Diubah ke Bahasa Indonesia

  // ================= DATE FORMATTER =================
  static String formatDate(dynamic t) {
    if (t == null) return '-';
    DateTime d;
    if (t is Timestamp) {
      d = t.toDate();
    } else if (t is DateTime) {
      d = t;
    } else {
      return '-';
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // Format tanggal dengan jam
  static String formatDateTime(dynamic t) {
    if (t == null) return '-';
    DateTime d;
    if (t is Timestamp) {
      d = t.toDate();
    } else if (t is DateTime) {
      d = t;
    } else {
      return '-';
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // Format relative time (contoh: "2 jam yang lalu")
  static String timeAgo(dynamic t) {
    if (t == null) return '-';
    DateTime d;
    if (t is Timestamp) {
      d = t.toDate();
    } else if (t is DateTime) {
      d = t;
    } else {
      return '-';
    }
    
    final now = DateTime.now();
    final difference = now.difference(d);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} tahun yang lalu';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} bulan yang lalu';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }

  // ================= SESSION ID =================
  static String generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  // ================= OPACITY HELPER =================
  static Color withOp(Color color, double opacity) => color.withOpacity(opacity);

  // ================= VALIDATION HELPERS =================
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email tidak boleh kosong';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Format email tidak valid';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nomor telepon tidak boleh kosong';
    }
    final phoneRegex = RegExp(r'^[0-9]{10,13}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Nomor telepon harus 10-13 digit';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }

  // ================= TEXT FORMATTERS =================
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String capitalizeEachWord(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // ================= NOTIFICATION MESSAGES =================
  static String get userCreatedSuccess => 'Pengguna berhasil ditambahkan';
  static String get userUpdatedSuccess => 'Data pengguna berhasil diperbarui';
  static String get userDeletedSuccess => 'Pengguna berhasil dihapus';
  static String get userActivatedSuccess => 'Akun pengguna berhasil diaktifkan';
  static String get userDeactivatedSuccess => 'Akun pengguna berhasil dinonaktifkan';
  static String get userBlockedSuccess => 'Akun pengguna berhasil diblokir';
  
  static String get errorLoadingUsers => 'Gagal memuat data pengguna';
  static String get errorCreatingUser => 'Gagal menambahkan pengguna';
  static String get errorUpdatingUser => 'Gagal memperbarui pengguna';
  static String get errorDeletingUser => 'Gagal menghapus pengguna';
  static String get errorTogglingStatus => 'Gagal mengubah status pengguna';
}