import 'package:flutter/material.dart';

class OvertimeHelpers {
  static Color getStatusColor(String status) {
    switch (status) {
      case 'disetujui': return Colors.green;
      case 'ditolak': return Colors.red;
      case 'pending': return Colors.orange;
      case 'selesai': return Colors.blue;
      case 'kadaluarsa': return Colors.grey;
      default: return Colors.grey;
    }
  }

  static String getStatusText(String status) {
    switch (status) {
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      case 'pending': return 'Pending';
      case 'selesai': return 'Selesai';
      case 'kadaluarsa': return 'Kadaluarsa';
      default: return status;
    }
  }

  static String getJenisLemburLabel(String jenis) {
    switch (jenis) {
      case 'hari_kerja': return 'Hari Kerja';
      case 'hari_libur': return 'Hari Libur';
      default: return jenis;
    }
  }

  static Color getFungsiColor(String? fungsi) {
    switch (fungsi?.toLowerCase()) {
      case 'operation': return const Color(0xFF1976D2);
      case 'maintenance': return const Color(0xFFFF9800);
      case 'hsse': return const Color(0xFF9C27B0);
      case 'gpr': return const Color(0xFFF44336);
      case 'bs': return const Color(0xFF795548);
      default: return const Color(0xFF757575);
    }
  }

  static String getCardTitle(dynamic item) {
    if (item.isMultiple) return 'Lembur Grup (${item.totalMitra} mitra)';
    if (item.namaMitra?.isNotEmpty == true) return item.namaMitra;
    if (item.namaPengawas?.isNotEmpty == true) return item.namaPengawas;
    return 'Unknown';
  }

  static bool isMitraPelaksana(dynamic item, String? userId, String? userName) {
    if (item.isMultiple && item.mitraIds != null && item.mitraIds!.isNotEmpty) {
      return item.mitraIds!.contains(userId);
    }
    if (item.mitraId?.isNotEmpty == true) {
      return item.mitraId == userId;
    }
    if (item.namaMitra?.isNotEmpty == true) {
      return item.namaMitra == userName;
    }
    return false;
  }

  static String getLokasiString(Map<String, dynamic>? lokasi) {
    if (lokasi == null || lokasi.isEmpty) return 'Tidak diketahui';
    if (lokasi['nama_lokasi']?.toString().isNotEmpty == true) return lokasi['nama_lokasi'].toString();
    if (lokasi['alamat']?.toString().isNotEmpty == true) return lokasi['alamat'].toString();
    if (lokasi['latitude'] != null && lokasi['longitude'] != null) {
      return '📍 ${lokasi['latitude']}, ${lokasi['longitude']}';
    }
    return 'Tidak diketahui';
  }

  static bool isOutsideRadius(Map<String, dynamic>? lokasi) {
    return lokasi?['is_outside_radius'] == true;
  }
}