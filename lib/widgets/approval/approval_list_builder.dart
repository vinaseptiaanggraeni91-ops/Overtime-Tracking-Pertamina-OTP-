// lib/widgets/approval/manager/approval_list_builder.dart
// ✅ FULLY FIXED: Query untuk semua role & status sudah benar
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_approval_service.dart';
import '/core/services/overtime_rate_service.dart';

class ApprovalListBuilder extends StatelessWidget {
  final String status;
  final String userRole;
  final String? userFungsi;
  final String? fungsiFilter;
  final String searchQuery;
  final bool isDarkMode;
  final Function(String groupId) onTap;
  final bool isHSSETab;

  const ApprovalListBuilder({
    super.key,
    required this.status,
    required this.userRole,
    this.userFungsi,
    this.fungsiFilter,
    required this.searchQuery,
    required this.isDarkMode,
    required this.onTap,
    this.isHSSETab = false,
  });

  // ===================================================================
  // ✅ STATUS YANG HARUS DIEXCLUDE DARI LIST APPROVED/REJECTED
  // ===================================================================
  static const List<String> _excludedStatuses = [
    'dibatalkan',
    'canceled',
    'draft',
  ];

  // ✅ STATUS YANG VALID UNTUK MASING-MASING TAB
  static const List<String> _approvedStatuses = [
    'disetujui',
    'approved',
    'manager_approved',
    'hsse_approved',
  ];

  static const List<String> _rejectedStatuses = [
    'ditolak',
    'rejected',
    'manager_rejected',
    'hsse_rejected',
  ];

  // ===================================================================
  // 🔥 FORMATTER TANGGAL (STATIC)
  // ===================================================================
  static final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
  static final DateFormat _dateTimeFormatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  // ===================================================================
  // 🔥 FORMAT RUPIAH
  // ===================================================================
  static String _formatBiaya(double value) {
    if (value == 0 || value.isNaN || value.isInfinite) {
      return 'Rp 0';
    }

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 2,
    );

    try {
      return formatter.format(value);
    } catch (e) {
      final rounded = (value * 100).round() / 100;
      final intPart = rounded.floor();
      final decPart = ((rounded - intPart) * 100).round();

      final formattedInt = intPart.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );

      if (decPart > 0) {
        return 'Rp $formattedInt,$decPart';
      }
      return 'Rp $formattedInt';
    }
  }

  // ===================================================================
  // 🔥 PARSE TANGGAL (SUPPORT MULTIPLE FORMAT)
  // ===================================================================
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    try {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      return null;
    } catch (e) {
      debugPrint('❌ _parseDate error: $value → $e');
      return null;
    }
  }

  // ===================================================================
  // 🔥 FORMAT TANGGAL DENGAN FALLBACK
  // ===================================================================
  static String _formatTanggal(Map<String, dynamic> data) {
    final dateFieldCandidates = [
      'tanggal_formatted',
      'tanggal',
      'tanggal_lembur',
      'tgl_lembur',
      'tanggal_pengajuan',
      'tgl_pengajuan',
      'created_at',
      'submitted_at',
    ];

    for (final field in dateFieldCandidates) {
      final value = data[field];

      if (value is String && value.isNotEmpty && value.contains(RegExp(r'[A-Za-z]'))) {
        return value;
      }

      final parsed = _parseDate(value);
      if (parsed != null) {
        return _dateFormatter.format(parsed);
      }
    }

    return '-';
  }

  // ===================================================================
  // 🔥 AMBIL BIAYA ASLI DARI DATA
  // ===================================================================
  static double _getBiayaAsli(Map<String, dynamic> data) {
    double biaya = 0.0;

    final candidates = [
      'estimasi_biaya',
      'estimasi_biaya_total',
      'total_biaya',
      'biaya',
      'estimasi_biaya_total_raw',
    ];

    for (final field in candidates) {
      final value = data[field];
      if (value != null) {
        if (value is double) {
          biaya = value;
          break;
        } else if (value is int) {
          biaya = value.toDouble();
          break;
        } else if (value is num) {
          biaya = value.toDouble();
          break;
        } else if (value is String) {
          final parsed = double.tryParse(value.replaceAll(',', '.').replaceAll(' ', ''));
          if (parsed != null) {
            biaya = parsed;
            break;
          }
        }
      }
    }

    return biaya;
  }

  // ===================================================================
  // 🔥 GET STATUS DISPLAY
  // ===================================================================
  String _getHsseStatusDisplay(Map<String, dynamic> data) {
    final currentStatus = data['status']?.toString() ?? '';
    final isFlagged = data['is_flagged_for_hsse'] == true;
    final isPendingHsse = data['is_pending_hsse'] == true;

    if (isPendingHsse || isFlagged) {
      return 'Menunggu Validasi K3';
    }

    return _getStatusLabel(currentStatus);
  }

  String _getStatusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'pending_hsse':
        return 'Pending K3';
      case 'manager_approved':
        return 'Manager Approved';
      case 'manager_approval_pending_hsse':
        return 'Menunggu K3';
      case 'manager_approved_pending_hsse':
        return 'Menunggu K3';
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      case 'dibatalkan':
      case 'canceled':
        return 'Dibatalkan';
      default:
        return s.replaceAll('_', ' ');
    }
  }

  // ===================================================================
  // 🔥 GET NAMA MITRA (yang mengajukan)
  // ===================================================================
  String _getNamaMitra(Map<String, dynamic> data) {
    final nama = data['mitra_nama_lengkap']?.toString() ??
        data['mitra_nama']?.toString() ??
        data['nama_mitra']?.toString() ??
        data['mitra_name']?.toString() ??
        data['nama_lengkap']?.toString() ??
        data['nama']?.toString() ??
        data['name']?.toString() ??
        data['user_name']?.toString() ??
        data['username']?.toString() ??
        data['email']?.toString() ??
        '-';

    if (nama == '-') {
      final mitraData = data['mitra_data'] as Map?;
      if (mitraData != null) {
        return mitraData['nama_lengkap']?.toString() ??
            mitraData['nama']?.toString() ??
            mitraData['name']?.toString() ??
            mitraData['email']?.toString() ??
            '-';
      }

      final detailMitra = data['detail_mitra'] as List?;
      if (detailMitra != null && detailMitra.isNotEmpty) {
        final firstMitra = detailMitra.first as Map?;
        if (firstMitra != null) {
          return firstMitra['nama']?.toString() ??
              firstMitra['nama_mitra']?.toString() ??
              firstMitra['name']?.toString() ??
              '-';
        }
      }

      final userData = data['user_data'] as Map?;
      if (userData != null) {
        return userData['nama_lengkap']?.toString() ??
            userData['nama']?.toString() ??
            userData['name']?.toString() ??
            userData['email']?.toString() ??
            '-';
      }

      final createdBy = data['created_by'] as Map?;
      if (createdBy != null) {
        return createdBy['nama']?.toString() ??
            createdBy['name']?.toString() ??
            createdBy['email']?.toString() ??
            '-';
      }

      final diajukanOleh = data['diajukan_oleh'] as Map?;
      if (diajukanOleh != null) {
        return diajukanOleh['nama']?.toString() ??
            diajukanOleh['name']?.toString() ??
            diajukanOleh['email']?.toString() ??
            '-';
      }
    }

    return nama;
  }

  // ===================================================================
  // 🔥 GET FUNGSI MITRA
  // ===================================================================
  String _getFungsiMitra(Map<String, dynamic> data) {
    return data['mitra_fungsi']?.toString() ??
        data['fungsi_mitra']?.toString() ??
        data['pengawas_fungsi']?.toString() ??
        data['fungsi']?.toString() ??
        '-';
  }

  // ===================================================================
  // ✅ GET ROLE LABEL
  // ===================================================================
  String _getRoleLabel() {
    if (userRole == 'superadmin') return 'Superadmin';
    if (isHSSETab) return 'Manager HSSE';
    if (userRole == 'manager') return 'Manager';
    return userRole;
  }

  // ===================================================================
  // 🔥🔥🔥 BUILD - FULLY FIXED QUERY LOGIC 🔥🔥🔥
  // ===================================================================
  @override
  Widget build(BuildContext context) {
    final approvalService = OvertimeApprovalService();
    Stream<List<Map<String, dynamic>>> stream;

    // ✅ Tentukan filter fungsi yang akan digunakan
    // Untuk manager biasa: gunakan userFungsi (fungsi manager itu sendiri)
    // Untuk superadmin: gunakan fungsiFilter (filter global dari UI)
    final effectiveFungsiFilter = (userRole == 'superadmin') ? fungsiFilter : userFungsi;

    debugPrint('📋 ApprovalListBuilder: role=$userRole, status=$status, isHSSETab=$isHSSETab');
    debugPrint('   userFungsi=$userFungsi, fungsiFilter=$fungsiFilter, effectiveFilter=$effectiveFungsiFilter');

    if (isHSSETab) {
      debugPrint('🟣 HSSE Tab: Query untuk status="$status"');

      if (status == 'pending') {
        debugPrint('   → Menggunakan getHssePendingList()');
        stream = approvalService.getHssePendingList(
          fungsiFilter: effectiveFungsiFilter,
        );
      } else if (status == 'disetujui') {
        debugPrint('   → Menggunakan getApprovedListForHSSE()');
        stream = approvalService.getApprovedListForHSSE(
          searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
          fungsiFilter: effectiveFungsiFilter,
        );
      } else if (status == 'ditolak') {
        debugPrint('   → Menggunakan getRejectedListForHSSE()');
        stream = approvalService.getRejectedListForHSSE(
          searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
          fungsiFilter: effectiveFungsiFilter,
        );
      } else if (status == 'semua_berisiko') {
        debugPrint('   → Menggunakan getAllRiskyOvertimeForHSSE()');
        stream = approvalService.getAllRiskyOvertimeForHSSE(
          searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
          fungsiFilter: effectiveFungsiFilter,
        );
      } else {
        debugPrint('   → Fallback: getApprovalListForManager()');
        stream = approvalService.getApprovalListForManager(
          status: status,
          fungsiManager: userFungsi ?? '',
        );
      }
    } else if (userRole == 'superadmin') {
      // ✅ SUPERADMIN: Gunakan fungsiFilter dari UI (bisa null = semua fungsi)
      debugPrint('🔵 Superadmin Tab: Query status="$status", fungsiFilter="$fungsiFilter"');
      stream = approvalService.getApprovalListForSuperadmin(
        status: status,
        fungsiFilter: fungsiFilter, // Bisa null → tampilkan semua
      );
    } else {
      // ✅ MANAGER BIASA: Filter berdasarkan fungsi manager (userFungsi)
      debugPrint('🟢 Manager Tab: Query status="$status", fungsi="$userFungsi"');
      
      // 🔥 PERBAIKAN: Gunakan getApprovalListForSuperadmin dengan filter fungsi manager
      // Ini memastikan query ke lembur_mitra dengan where('pengawas_fungsi', isEqualTo: userFungsi)
      stream = approvalService.getApprovalListForSuperadmin(
        status: status,
        fungsiFilter: userFungsi, // ✅ Filter berdasarkan fungsi manager!
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          debugPrint('❌ ApprovalListBuilder error: ${snapshot.error}');
          return _buildErrorState();
        }

        final docs = snapshot.data ?? [];

        // ✅ FILTER: Exclude status dibatalkan/canceled/draft
        final validDocs = docs.where((data) {
          final docStatus = data['status']?.toString() ?? '';
          if (_excludedStatuses.contains(docStatus)) {
            debugPrint('⚠️ EXCLUDED from list: ${data['group_id']} (status=$docStatus)');
            return false;
          }
          return true;
        }).toList();

        // Filter client-side untuk search query
        final filteredDocs = validDocs.where((data) {
          if (searchQuery.isEmpty) return true;
          final query = searchQuery.toLowerCase();
          final nama = _getNamaMitra(data).toLowerCase();
          final groupId = (data['group_id'] ?? '').toString().toLowerCase();
          final fungsi = _getFungsiMitra(data).toLowerCase();
          final email = (data['email'] ?? data['mitra_email'] ?? '').toString().toLowerCase();
          return nama.contains(query) ||
              groupId.contains(query) ||
              fungsi.contains(query) ||
              email.contains(query);
        }).toList();

        debugPrint('📊 Result: ${filteredDocs.length} docs (from ${docs.length} total, ${validDocs.length} valid)');

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isHSSETab) _buildHSSEInfoHeader(filteredDocs.length),
                    if (isHSSETab && status == 'pending')
                      _buildPendingHsseInfoBanner(),
                    if (!isHSSETab) _buildRoleInfoHeader(filteredDocs.length),
                    ...filteredDocs.map((data) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildApprovalCard(data),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===================================================================
  // ✅ ROLE INFO HEADER
  // ===================================================================
  Widget _buildRoleInfoHeader(int count) {
    final roleLabel = _getRoleLabel();
    final isApproved = _approvedStatuses.contains(status);
    final isRejected = _rejectedStatuses.contains(status);

    Color headerColor;
    IconData iconData;
    String title;

    if (isApproved) {
      headerColor = Colors.green;
      iconData = Icons.check_circle_rounded;
      title = '$roleLabel • $count Disetujui';
    } else if (isRejected) {
      headerColor = Colors.red;
      iconData = Icons.cancel_rounded;
      title = '$roleLabel • $count Ditolak';
    } else {
      headerColor = Colors.orange;
      iconData = Icons.hourglass_bottom_rounded;
      title = '$roleLabel • $count ${_getStatusLabel(status)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            headerColor.withValues(alpha: 0.08),
            headerColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, color: headerColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: headerColor,
              ),
            ),
          ),
          // ✅ Tampilkan fungsi yang sedang difilter
          if (userFungsi != null && userFungsi!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: headerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                userFungsi!.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: headerColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===================================================================
  // HSSE INFO HEADER
  // ===================================================================
  Widget _buildHSSEInfoHeader(int count) {
    final isPending = status == 'pending';
    final isApproved = status == 'disetujui';

    Color headerColor;
    String title;
    IconData iconData;

    if (isPending) {
      headerColor = Colors.orange;
      iconData = Icons.hourglass_bottom_rounded;
      title = 'Menunggu Validasi K3 • $count pengajuan';
    } else if (isApproved) {
      headerColor = Colors.green;
      iconData = Icons.health_and_safety;
      title = 'Validasi K3 Disetujui • $count pengajuan';
    } else {
      headerColor = Colors.red;
      iconData = Icons.cancel;
      title = 'Validasi K3 Ditolak • $count pengajuan';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            headerColor.withValues(alpha: 0.08),
            headerColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, color: headerColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: headerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // PENDING HSSE INFO BANNER
  // ===================================================================
  Widget _buildPendingHsseInfoBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pengajuan ini memerlukan validasi K3 karena teridentifikasi berisiko tinggi.',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== LOADING STATE ==============
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isHSSETab ? const Color(0xFF9C27B0) : const Color(0xFF6366F1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isHSSETab ? 'Memuat data validasi K3...' : 'Memuat data...',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============== ERROR STATE ==============
  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal Memuat Data',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isHSSETab
                    ? 'Gagal mengambil data validasi K3.\nSilakan coba lagi atau refresh halaman.'
                    : 'Silakan coba lagi atau refresh halaman',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============== EMPTY STATE ==============
  Widget _buildEmptyState() {
    final isPending = status == 'pending';
    final isApproved = status == 'disetujui';
    final roleLabel = _getRoleLabel();

    Color emptyColor;
    IconData emptyIcon;
    String title;
    String subtitle;

    if (isHSSETab) {
      if (isPending) {
        emptyColor = Colors.orange;
        emptyIcon = Icons.hourglass_empty_rounded;
        title = 'Tidak Ada Pengajuan Menunggu Validasi K3';
        subtitle = 'Semua pengajuan berisiko telah divalidasi.';
      } else if (isApproved) {
        emptyColor = Colors.green;
        emptyIcon = Icons.check_circle_outline;
        title = 'Tidak Ada Validasi K3 Disetujui';
        subtitle = 'Belum ada pengajuan berisiko yang divalidasi K3.';
      } else {
        emptyColor = Colors.red;
        emptyIcon = Icons.cancel_outlined;
        title = 'Tidak Ada Validasi K3 Ditolak';
        subtitle = 'Belum ada pengajuan berisiko yang ditolak K3.';
      }
    } else {
      emptyColor = Colors.grey;
      emptyIcon = Icons.inbox_outlined;
      title = 'Tidak Ada Data ($roleLabel)';
      subtitle = searchQuery.isNotEmpty
          ? 'Tidak ada hasil untuk "$searchQuery"'
          : 'Semua pengajuan telah diproses';
    }

    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF1E293B)
                      : (isHSSETab ? emptyColor.withValues(alpha: 0.06) : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isHSSETab ? emptyIcon : Icons.inbox_outlined,
                  size: 36,
                  color: isHSSETab ? emptyColor.withValues(alpha: 0.4) : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================================================================
  // 🔥 APPROVAL CARD
  // ===================================================================
  Widget _buildApprovalCard(Map<String, dynamic> data) {
    final isUrgent = data['urgensi'] == 'kritis';
    final isOverride = data['is_override'] ?? false;
    final isWeekend = data['jenis_lembur'] == 'hari_libur';
    final isPendingHsse = data['is_pending_hsse'] == true;
    final isFlaggedForHsse = data['is_flagged_for_hsse'] == true;
    final isHsseValidated = data['is_hsse_validated'] == true;

    final docStatus = data['status']?.toString() ?? '';
    final isCanceled = _excludedStatuses.contains(docStatus);

    final riskLevel = data['risk_level']?.toString() ?? '';
    final riskFactors = (data['risk_factors'] as List?)?.cast<String>() ?? [];

    final lokasiData = data['lokasi'];
    final lokasiMap = lokasiData is Map<String, dynamic> ? lokasiData : <String, dynamic>{};
    final isOutside = lokasiMap['is_outside_radius'] == true;
    final lokasiString = _getLokasiSingkat(lokasiMap);

    final groupId = data['group_id'] ?? '';

    final totalBiaya = _getBiayaAsli(data);
    final totalMitra = data['total_mitra'] ?? 0;

    final namaMitra = _getNamaMitra(data);
    final fungsiMitra = _getFungsiMitra(data);

    final detailMitra = data['detail_mitra'] as List?;
    final mitraNames = detailMitra?.map((m) => m['nama'] ?? m['nama_mitra'] ?? '?').toList() ?? [];

    final tanggalStr = _formatTanggal(data);
    final formattedBiaya = _formatBiaya(totalBiaya);

    final statusDisplay = isHSSETab
        ? _getHsseStatusDisplay(data)
        : (isCanceled ? 'Dibatalkan' : _getStatusLabel(status));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(groupId),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isCanceled
                ? Border.all(color: Colors.grey.withValues(alpha: 0.5), width: 1)
                : isUrgent
                    ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1.5)
                    : isOverride
                        ? Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1)
                        : isPendingHsse || isFlaggedForHsse
                            ? Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 1)
                            : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Opacity(
            opacity: isCanceled ? 0.6 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // HEADER ROW
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            isCanceled ? Colors.grey : _getFungsiColor(fungsiMitra),
                            (isCanceled ? Colors.grey : _getFungsiColor(fungsiMitra)).withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          namaMitra.isNotEmpty && namaMitra != '-'
                              ? namaMitra[0].toUpperCase()
                              : 'M',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  namaMitra,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                                    decoration: isCanceled ? TextDecoration.lineThrough : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCanceled)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'BATAL',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              if (isUrgent && !isCanceled)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'URGENT',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              if ((isPendingHsse || isFlaggedForHsse) && !isCanceled)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'K3',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            fungsiMitra != '-' ? _getFungsiLabel(fungsiMitra) : data['pengawas_fungsi']?.toString() ?? '-',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isCanceled ? Colors.grey : _getStatusColor(status)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCanceled ? Icons.cancel : _getStatusIcon(status),
                            color: isCanceled ? Colors.grey : _getStatusColor(status),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusDisplay,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: isCanceled ? Colors.grey : _getStatusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Risk level indicator
                if ((isPendingHsse || isFlaggedForHsse) && riskLevel.isNotEmpty && !isCanceled) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRiskColor(riskLevel).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getRiskColor(riskLevel).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 12, color: _getRiskColor(riskLevel)),
                        const SizedBox(width: 4),
                        Text(
                          'Risk: ${riskLevel.toUpperCase()}',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _getRiskColor(riskLevel),
                          ),
                        ),
                        if (riskFactors.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              riskFactors.take(2).join(', '),
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                color: _getRiskColor(riskLevel).withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // INFO GRID
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInfoItem(
                            Icons.calendar_today_rounded,
                            tanggalStr,
                            isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                          ),
                          const SizedBox(height: 6),
                          _buildInfoItem(
                            Icons.access_time_rounded,
                            '${data['jam_mulai']} - ${data['jam_selesai']}',
                            isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInfoItem(
                            Icons.account_balance_wallet_rounded,
                            formattedBiaya,
                            isCanceled ? Colors.grey : const Color(0xFF10B981),
                            isBold: true,
                          ),
                          const SizedBox(height: 6),
                          _buildInfoItem(
                            Icons.people_outline_rounded,
                            '$totalMitra mitra • ${(data['total_jam_desimal'] ?? 0).toStringAsFixed(1)} jam',
                            isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // TAGS
                if ((isWeekend || isOverride || isOutside || lokasiString.isNotEmpty || isHsseValidated) && !isCanceled) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (isHsseValidated)
                        _buildTag('Validasi K3', Colors.purple, Icons.verified_user),
                      if (isWeekend)
                        _buildTag('Hari Libur', Colors.purple, Icons.event_busy),
                      if (isOverride)
                        _buildTag('Override', Colors.orange, Icons.warning_amber_rounded),
                      if (isOutside)
                        _buildTag('Luar Radius', Colors.deepOrange, Icons.location_off_rounded),
                      if (lokasiString.isNotEmpty)
                        _buildTag(lokasiString, isOutside ? Colors.deepOrange : Colors.blue,
                            isOutside ? Icons.location_off_rounded : Icons.location_on_rounded),
                    ],
                  ),
                ],

                // MITRA NAMES
                if (mitraNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people_rounded, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          mitraNames.take(2).join(', ') +
                              (mitraNames.length > 2 ? ' +${mitraNames.length - 2} lainnya' : ''),
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============== INFO ITEM ==============
  Widget _buildInfoItem(IconData icon, String text, Color color, {bool isBold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ============== TAG ==============
  Widget _buildTag(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 9, color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ============== HELPER METHODS ==============
  Color _getStatusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'pending_hsse':
        return Colors.deepOrange;
      case 'manager_approved':
        return Colors.blue;
      case 'disetujui':
        return const Color(0xFF10B981);
      case 'ditolak':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String s) {
    switch (s) {
      case 'pending':
        return Icons.hourglass_bottom_rounded;
      case 'pending_hsse':
        return Icons.health_and_safety;
      case 'manager_approved':
        return Icons.thumb_up_rounded;
      case 'disetujui':
        return Icons.check_circle_rounded;
      case 'ditolak':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
      case 'tinggi':
        return Colors.deepOrange;
      case 'medium':
      case 'sedang':
        return Colors.orange;
      case 'low':
      case 'rendah':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getFungsiLabel(String? f) {
    switch (f?.toLowerCase()) {
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
        return f ?? 'Unknown';
    }
  }

  Color _getFungsiColor(String? fungsi) {
    switch (fungsi?.toLowerCase()) {
      case 'operation':
        return const Color(0xFF1976D2);
      case 'maintenance':
        return const Color(0xFFFF9800);
      case 'hsse':
        return const Color(0xFF9C27B0);
      case 'gpr':
        return const Color(0xFFEF4444);
      case 'bs':
        return const Color(0xFF795548);
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _getLokasiSingkat(Map<String, dynamic>? lokasi) {
    if (lokasi == null || lokasi.isEmpty) return '';

    final candidates = [
      lokasi['nama_lokasi']?.toString(),
      lokasi['alamat']?.toString(),
      lokasi['nama']?.toString(),
      lokasi['lokasi_nama']?.toString(),
      lokasi['site_name']?.toString(),
      lokasi['area']?.toString(),
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) {
        if (candidate.length > 25) {
          return '${candidate.substring(0, 22)}...';
        }
        return candidate;
      }
    }

    return '';
  }
}