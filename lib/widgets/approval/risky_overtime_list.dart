// lib/widgets/approval/risky_overtime_list.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_approval_service.dart';

class RiskyOvertimeList extends StatefulWidget {
  final String searchQuery;
  final String? fungsiFilter;
  final bool isDarkMode;
  final Function(String groupId) onTap;
  final Function(String groupId) onHSSEReview;

  const RiskyOvertimeList({
    super.key,
    required this.searchQuery,
    this.fungsiFilter,
    this.isDarkMode = false,
    required this.onTap,
    required this.onHSSEReview,
  });

  @override
  State<RiskyOvertimeList> createState() => _RiskyOvertimeListState();
}

class _RiskyOvertimeListState extends State<RiskyOvertimeList>
    with AutomaticKeepAliveClientMixin {
  final OvertimeApprovalService _approvalService = OvertimeApprovalService();
  Stream<List<Map<String, dynamic>>>? _stream;

  // ✅ STATUS YANG HARUS DIEXCLUDE
  static const List<String> _excludedStatuses = [
    'dibatalkan',
    'canceled',
    'draft',
  ];

  // ✅ STATUS YANG VALID UNTUK RISKY LIST
  static const List<String> _validRiskyStatuses = [
    'pending',
    'pending_hsse',
    'manager_approval_pending_hsse',
    'manager_approved_pending_hsse',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadStream();
  }

  @override
  void didUpdateWidget(RiskyOvertimeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.fungsiFilter != widget.fungsiFilter) {
      _loadStream();
    }
  }

  void _loadStream() {
    debugPrint('🔄 Loading risky overtime: search="${widget.searchQuery}", fungsi="${widget.fungsiFilter}"');
    _stream = _approvalService.getAllRiskyOvertimeForHSSE(
      searchQuery: widget.searchQuery.isNotEmpty ? widget.searchQuery : null,
      fungsiFilter: widget.fungsiFilter,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingState();
        }

        // Error state
        if (snapshot.hasError) {
          debugPrint('❌ RiskyOvertimeList error: ${snapshot.error}');
          return _buildErrorState(snapshot.error.toString());
        }

        // ✅ FILTER: Exclude status dibatalkan/canceled/draft
        final rawData = snapshot.data ?? [];
        final filteredData = rawData.where((item) {
          final status = item['status']?.toString() ?? '';
          if (_excludedStatuses.contains(status)) {
            debugPrint('⚠️ EXCLUDED from risky list: ${item['group_id']} (status=$status)');
            return false;
          }
          return true;
        }).toList();

        // Empty state
        if (filteredData.isEmpty) {
          return _buildEmptyState();
        }

        debugPrint('✅ RiskyOvertimeList loaded: ${filteredData.length} items (filtered from ${rawData.length}), fungsi=${widget.fungsiFilter ?? "semua"}');

        // Data list
        return RefreshIndicator(
          onRefresh: () async {
            _loadStream();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: filteredData.length,
            itemBuilder: (context, index) {
              final item = filteredData[index];
              return _buildRiskyCard(item, index);
            },
          ),
        );
      },
    );
  }

  // ===================================================================
  // 🔥 CARD WIDGET
  // ===================================================================
  Widget _buildRiskyCard(Map<String, dynamic> item, int index) {
    final groupId = item['group_id']?.toString() ??
        item['id']?.toString() ??
        item['docId']?.toString() ??
        '';

    // ✅ Ambil data
    final namaMitra = _getNamaMitra(item);
    final fungsi = _getFungsi(item);
    final status = item['status']?.toString() ?? '';
    final riskLevel = item['risk_level']?.toString().toLowerCase() ?? 'low';
    final isFlagged = item['is_flagged_for_hsse'] == true;
    final isPendingHSSE = item['is_pending_hsse'] == true;
    final tanggal = _formatTanggal(item['tanggal'] ?? item['tanggal_lembur']);
    final lokasi = _getLokasi(item);
    final estimasiBiaya = _parseDouble(item['estimasi_biaya_total']);
    final totalJam = _parseDouble(item['total_jam_desimal']);
    final riskFactors = (item['risk_factors'] as List?)?.cast<String>() ?? [];

    // ✅ Cek apakah dibatalkan
    final isCanceled = _excludedStatuses.contains(status);

    final riskColor = _getRiskColor(riskLevel);
    final fungsiColor = _getFungsiColor(fungsi);

    debugPrint('📝 Risky Card: groupId=$groupId, namaMitra=$namaMitra, status=$status, isCanceled=$isCanceled');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCanceled
              ? Colors.grey.withValues(alpha: 0.4)
              : isFlagged
                  ? const Color(0xFF9C27B0).withValues(alpha: 0.4)
                  : riskColor.withValues(alpha: 0.3),
          width: isFlagged ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCanceled ? Colors.grey : riskColor).withValues(
                alpha: widget.isDarkMode ? 0.15 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => widget.onTap(groupId),
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: isCanceled ? 0.55 : 1.0, // ✅ Greyed out untuk canceled
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Nama Mitra + Badge
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isCanceled ? Colors.grey : riskColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isCanceled ? Colors.grey : riskColor)
                                  .withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              namaMitra,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                                decoration: isCanceled
                                    ? TextDecoration.lineThrough
                                    : null, // ✅ Coret untuk canceled
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'ID: ${groupId.length > 10 ? '${groupId.substring(0, 10)}...' : groupId}',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ✅ Badge status
                      if (isCanceled)
                        _buildCanceledBadge()
                      else
                        _buildStatusBadge(isPendingHSSE, isFlagged, status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Info grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoChip(
                        Icons.business,
                        fungsi,
                        isCanceled ? Colors.grey : fungsiColor,
                      ),
                      _buildInfoChip(
                        Icons.warning_amber_rounded,
                        _getRiskLabel(riskLevel),
                        isCanceled ? Colors.grey : riskColor,
                      ),
                      _buildInfoChip(
                        Icons.access_time,
                        '${totalJam.toStringAsFixed(1)}j',
                        isCanceled ? Colors.grey : Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Lokasi & Tanggal
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lokasi,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: widget.isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        tanggal,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: widget.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  // Estimasi biaya
                  if (estimasiBiaya > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.monetization_on_outlined,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Estimasi: Rp ${_formatCurrency(estimasiBiaya)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: widget.isDarkMode
                                ? Colors.grey[300]
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Risk factors
                  if (riskFactors.isNotEmpty && !isCanceled) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: riskFactors
                          .map((factor) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.15)),
                                ),
                                child: Text(
                                  factor,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Action buttons
                  if (!isCanceled) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: ElevatedButton.icon(
                              onPressed: () => widget.onHSSEReview(groupId),
                              icon: const Icon(Icons.health_and_safety, size: 16),
                              label: Text(
                                isPendingHSSE ? 'Approve K3' : 'Review K3',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPendingHSSE
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFF9C27B0),
                                foregroundColor: Colors.white,
                                elevation: isPendingHSSE ? 2 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isPendingHSSE) ...[
                          SizedBox(
                            height: 38,
                            width: 38,
                            child: IconButton(
                              onPressed: () => widget.onHSSEReview(groupId),
                              icon: const Icon(Icons.check, size: 18),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green[50],
                                foregroundColor: Colors.green[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        SizedBox(
                          height: 38,
                          width: 38,
                          child: IconButton(
                            onPressed: () => widget.onTap(groupId),
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            style: IconButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // ✅ Tampilkan info canceled
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel_outlined, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            'Pengajuan Dibatalkan',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================================
  // 🔥 BADGE WIDGETS
  // ===================================================================

  /// ✅ Badge untuk pengajuan yang dibatalkan
  Widget _buildCanceledBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel, color: Colors.grey[600], size: 12),
          const SizedBox(width: 4),
          Text(
            'DIBATALKAN',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isPendingHSSE, bool isFlagged, String status) {
    if (isPendingHSSE) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.health_and_safety, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              'PENDING HSSE',
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (isFlagged) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
        ),
        child: Text(
          'PERLU HSSE',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF9C27B0),
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.isNotEmpty ? status.toUpperCase() : 'BERISIKO',
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.orange,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? color.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white : color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 🔥 HELPER METHODS
  // ===================================================================

  String _getNamaMitra(Map<String, dynamic> item) {
    final nama = item['mitra_nama_lengkap']?.toString() ??
        item['mitra_nama']?.toString() ??
        item['nama_mitra']?.toString() ??
        item['mitra_name']?.toString() ??
        item['nama_lengkap']?.toString() ??
        item['nama']?.toString() ??
        item['name']?.toString() ??
        item['user_name']?.toString() ??
        item['username']?.toString() ??
        item['email']?.toString() ??
        '-';

    if (nama == '-') {
      final mitraData = item['mitra_data'] as Map?;
      if (mitraData != null) {
        return mitraData['nama_lengkap']?.toString() ??
            mitraData['nama']?.toString() ??
            mitraData['name']?.toString() ??
            mitraData['email']?.toString() ??
            '-';
      }

      final userData = item['user_data'] as Map?;
      if (userData != null) {
        return userData['nama_lengkap']?.toString() ??
            userData['nama']?.toString() ??
            userData['name']?.toString() ??
            userData['email']?.toString() ??
            '-';
      }

      final createdBy = item['created_by'] as Map?;
      if (createdBy != null) {
        return createdBy['nama']?.toString() ??
            createdBy['name']?.toString() ??
            createdBy['email']?.toString() ??
            '-';
      }

      final diajukanOleh = item['diajukan_oleh'] as Map?;
      if (diajukanOleh != null) {
        return diajukanOleh['nama']?.toString() ??
            diajukanOleh['name']?.toString() ??
            diajukanOleh['email']?.toString() ??
            '-';
      }
    }

    return nama;
  }

  String _getFungsi(Map<String, dynamic> item) {
    return item['mitra_fungsi']?.toString() ??
        item['fungsi_mitra']?.toString() ??
        item['pengawas_fungsi']?.toString() ??
        item['fungsi_pengawas']?.toString() ??
        item['fungsi']?.toString() ??
        item['department']?.toString() ??
        item['departemen']?.toString() ??
        '-';
  }

  String _getLokasi(Map<String, dynamic> item) {
    if (item['lokasi'] is Map) {
      final lokasiMap = item['lokasi'] as Map;
      return lokasiMap['alamat']?.toString() ??
          lokasiMap['address']?.toString() ??
          lokasiMap['nama']?.toString() ??
          lokasiMap['name']?.toString() ??
          'Lokasi tidak tersedia';
    }
    return item['lokasi']?.toString() ??
        item['alamat']?.toString() ??
        item['address']?.toString() ??
        '-';
  }

  // ===================================================================
  // 🔥 LOADING STATE
  // ===================================================================
  Widget _buildLoadingState() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 150,
                    height: 14,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 80,
                    height: 20,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Container(
                      height: 28,
                      margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===================================================================
  // 🔥 EMPTY STATE
  // ===================================================================
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 36,
                color: Colors.green[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Pengajuan Berisiko',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.fungsiFilter != null && widget.fungsiFilter != 'semua'
                  ? 'Tidak ada pengajuan berisiko untuk fungsi ${widget.fungsiFilter}'
                  : 'Semua pengajuan dalam kondisi aman\nTidak ada yang memerlukan review K3',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _loadStream(),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text('Refresh', style: GoogleFonts.poppins(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 🔥 ERROR STATE
  // ===================================================================
  Widget _buildErrorState(String error) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 36, color: Colors.red[400]),
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal Memuat Data',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: widget.isDarkMode ? Colors.white : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _loadStream());
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: Text('Coba Lagi', style: GoogleFonts.poppins(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 🔥 UTILITY
  // ===================================================================
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _formatTanggal(dynamic tanggal) {
    if (tanggal == null) return '-';
    try {
      DateTime date;
      if (tanggal is DateTime) {
        date = tanggal;
      } else if (tanggal is Timestamp) {
        date = tanggal.toDate();
      } else {
        date = DateTime.parse(tanggal.toString());
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return tanggal.toString();
    }
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
      case 'tinggi':
        return const Color(0xFFEF4444);
      case 'medium':
      case 'sedang':
        return const Color(0xFFF59E0B);
      case 'low':
      case 'rendah':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  String _getRiskLabel(String riskLevel) {
    switch (riskLevel) {
      case 'critical':
        return 'Kritis';
      case 'high':
      case 'tinggi':
        return 'Tinggi';
      case 'medium':
      case 'sedang':
        return 'Sedang';
      case 'low':
      case 'rendah':
        return 'Rendah';
      default:
        return riskLevel.toUpperCase();
    }
  }

  Color _getFungsiColor(String fungsi) {
    switch (fungsi.toLowerCase()) {
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
        return const Color(0xFF757575);
    }
  }
}