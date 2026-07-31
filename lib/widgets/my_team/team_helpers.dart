import 'package:flutter/material.dart';

class TeamHelpers {
  static String getFungsiLabel(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation':
        return 'Operational';
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

  static String getRoleLabel(String? role) {
    if (role == null) return '-';
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

  static Color getRoleColor(String? role) {
    if (role == null) return Colors.grey;
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
}