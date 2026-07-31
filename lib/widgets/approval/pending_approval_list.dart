// lib/widgets/approval/pending_approval_list.dart
// 🔥 FIXED: Support lembur_mitra + NO setState during build + DEBUG LOGGING
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '/core/services/overtime_approval_service.dart';
import '/widgets/approval/approval_card.dart';

class PendingApprovalList extends StatefulWidget {
  final bool isSuperadmin;
  final String? fungsiFilterSuperadmin;
  final String? userFungsi;
  final String? userRole;
  final String searchQuery;
  final bool isBulkMode;
  final Set<String> selectedIds;
  final Function(String) onShowDetail;
  final Function(String, bool) onSelectionChanged;
  final Function(List<Map<String, dynamic>>) onDataLoaded;
  final bool isHSSEManagerMode;

  const PendingApprovalList({
    super.key,
    required this.isSuperadmin,
    this.fungsiFilterSuperadmin,
    this.userFungsi,
    this.userRole,
    required this.searchQuery,
    required this.isBulkMode,
    required this.selectedIds,
    required this.onShowDetail,
    required this.onSelectionChanged,
    required this.onDataLoaded,
    this.isHSSEManagerMode = false,
  });

  @override
  State<PendingApprovalList> createState() => _PendingApprovalListState();
}

class _PendingApprovalListState extends State<PendingApprovalList> {
  final _approvalService = OvertimeApprovalService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  String _lastSearchQuery = '';
  bool _hasLoaded = false;
  bool _isApplyingFilter = false;
  List<Map<String, dynamic>>? _pendingStreamData;

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color hsseColor = Color(0xFF9C27B0);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);

  // 🔥 FORMATTER
  static final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
  static final DateFormat _dateTimeFormatter =
      DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // ✅ STATUS YANG VALID UNTUK PENDING
  static const List<String> _validPendingStatuses = [
    'pending',
    'pending_hsse',
    'manager_approval_pending_hsse',
    'manager_approved_pending_hsse',
  ];

  // ✅ STATUS YANG HARUS DIEXCLUDE
  static const List<String> _excludedStatuses = [
    'dibatalkan',
    'canceled',
    'draft',
  ];

  // ===================================================================
  // 🔥 NORMALISASI TANGGAL
  // ===================================================================
  String? _normalizeDate(dynamic value, {bool withTime = false}) {
    if (value == null) return null;
    try {
      DateTime dateTime;
      if (value is Timestamp) {
        dateTime = value.toDate();
      } else if (value is DateTime) {
        dateTime = value;
      } else if (value is String) {
        dateTime = DateTime.parse(value);
      } else if (value is int || value is double) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
      } else {
        return null;
      }
      return withTime
          ? _dateTimeFormatter.format(dateTime)
          : _dateFormatter.format(dateTime);
    } catch (e) {
      debugPrint('❌ Error normalizing date: $value → $e');
      return null;
    }
  }

  // ===================================================================
  // 🔥🔥🔥 NORMALISASI RECORD - SUPPORT lembur_mitra
  // ===================================================================
  Map<String, dynamic> _normalizeRecord(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);

    // NORMALISASI TANGGAL
    final dateFields = [
      'tanggal', 'tanggal_lembur', 'created_at', 'updated_at',
      'approved_at', 'rejected_at', 'start_date', 'end_date',
      'submitted_at', 'tanggal_pengajuan', 'tgl_lembur', 'tgl_pengajuan',
    ];

    for (final field in dateFields) {
      if (normalized.containsKey(field) && normalized[field] != null) {
        final originalValue = normalized[field];
        normalized['_raw_$field'] = originalValue;
        final withTime = field.contains('_at') ||
            field == 'updated_at' ||
            field == 'created_at';
        final formatted =
            _normalizeDate(originalValue, withTime: withTime);
        if (formatted != null) {
          normalized[field] = formatted;
          normalized['${field}_formatted'] = formatted;
        } else {
          normalized[field] = '-';
        }
      }
    }

    // NORMALISASI BIAYA
    final biayaFields = [
      'estimasi_biaya_total', 'estimasi_biaya_per_mitra', 'estimasi_biaya',
      'biaya_total', 'biaya_per_mitra', 'total_biaya',
      'total_biaya_lembur', 'biaya_lembur', 'total_biaya_mitra',
      'estimasi_biaya_mitra',
    ];

    double biayaFinal = 0.0;

    for (final field in biayaFields) {
      if (normalized.containsKey(field) && normalized[field] != null) {
        final originalValue = normalized[field];
        double biayaAsli = 0.0;
        if (originalValue is int) {
          biayaAsli = originalValue.toDouble();
        } else if (originalValue is double) {
          biayaAsli = originalValue;
        } else if (originalValue is num) {
          biayaAsli = originalValue.toDouble();
        } else if (originalValue is String) {
          biayaAsli = double.tryParse(originalValue) ?? 0.0;
        }

        if (biayaAsli > 0) {
          normalized['${field}_raw'] = biayaAsli;
          normalized['${field}_display'] =
              _currencyFormatter.format(biayaAsli);
          if (biayaAsli > biayaFinal) {
            biayaFinal = biayaAsli;
          }
        }
      }
    }

    if (biayaFinal > 0) {
      normalized['estimasi_biaya_total'] = biayaFinal;
      normalized['estimasi_biaya_total_raw'] = biayaFinal;
      normalized['estimasi_biaya_total_display'] =
          _currencyFormatter.format(biayaFinal);
    }

    // NORMALISASI NAMA
    if ((normalized['nama_pengawas'] == null ||
            normalized['nama_pengawas'].toString().isEmpty) &&
        (normalized['nama_mitra'] != null ||
            normalized['diajukan_oleh_nama'] != null)) {
      normalized['nama_pengawas'] = normalized['nama_mitra']?.toString() ??
          normalized['mitra_nama']?.toString() ??
          normalized['diajukan_oleh_nama']?.toString() ??
          normalized['nama_lengkap']?.toString() ??
          'Unknown';
    }

    // NORMALISASI FLAG TRANSISI HSSE
    final status = normalized['status']?.toString() ?? '';
    final isForwarded =
        status == 'pending_hsse' && normalized['approved_by_name'] != null;
    normalized['is_forwarded_to_hsse'] = isForwarded;
    normalized['is_pending_hsse'] = isForwarded;

    return normalized;
  }

  // ===================================================================
  // 🔥 HANDLER STREAM DATA - SAFE (NO setState during build)
  // ===================================================================
  void _processStreamData(List<Map<String, dynamic>> newData) {
    debugPrint('🔵 STREAM RECEIVED: ${newData.length} records');

    if (newData.isEmpty) {
      debugPrint('⚠️ STREAM EMPTY!');
      if (mounted) {
        setState(() {
          _allData = [];
          _filteredData = [];
          _hasLoaded = true;
        });
      }
      return;
    }

    // Filter excluded
    final filteredData = newData.where((data) {
      final status = data['status']?.toString() ?? '';
      return !_excludedStatuses.contains(status);
    }).toList();

    final normalizedData = filteredData.map(_normalizeRecord).toList();

    debugPrint('🔵 AFTER PROCESS: ${normalizedData.length} records');

    if (normalizedData.isNotEmpty) {
      final sample = normalizedData.first;
      debugPrint('🔍 SAMPLE: ${sample['group_id']} | ${sample['status']} | ${sample['pengawas_fungsi']}');
    }

    if (mounted) {
      setState(() {
        _allData = List.from(normalizedData);
        _hasLoaded = true;
      });
      debugPrint('✅ _allData UPDATED: ${_allData.length} items');
      _applyFilter();
      widget.onDataLoaded(_allData);
    }
  }

  // ===================================================================
  // GETTERS
  // ===================================================================
  bool get _isHSSEManager {
    if (widget.isHSSEManagerMode) return true;
    if (widget.isSuperadmin) return false;
    final role = widget.userRole?.toLowerCase() ?? '';
    final fungsi = widget.userFungsi?.toLowerCase() ?? '';
    if (fungsi == 'hsse') return true;
    if (role == 'manager_hsse') return true;
    return false;
  }

  bool get _isManagerFungsi {
    if (widget.isSuperadmin) return false;
    if (_isHSSEManager) return false;
    return widget.userRole == 'manager' &&
        widget.userFungsi != null &&
        widget.userFungsi!.isNotEmpty;
  }

  // ===================================================================
  // LIFECYCLE
  // ===================================================================
  @override
  void didUpdateWidget(PendingApprovalList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _lastSearchQuery = widget.searchQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyFilter();
      });
    }
    if (oldWidget.fungsiFilterSuperadmin != widget.fungsiFilterSuperadmin) {
      _hasLoaded = false;
      _allData = [];
      _filteredData = [];
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 PendingApprovalList INIT | superadmin=${widget.isSuperadmin} | role=${widget.userRole}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugManualQuery();
      _debugDirectQuery();
    });
  }

  // ===================================================================
  // FILTER
  // ===================================================================
  void _applyFilter() {
    if (_isApplyingFilter) return;
    _isApplyingFilter = true;

    List<Map<String, dynamic>> result;

    if (widget.searchQuery.isEmpty) {
      result = List.from(_allData);
    } else {
      final query = widget.searchQuery.toLowerCase();
      result = _allData.where((data) {
        final nama = (data['nama_pengawas'] ?? data['nama_mitra'] ?? '')
            .toString().toLowerCase();
        final groupId = (data['group_id'] ?? '').toString().toLowerCase();
        final fungsi = (data['pengawas_fungsi'] ?? '').toString().toLowerCase();
        final tanggal = (data['tanggal'] ?? '').toString().toLowerCase();
        final lokasi = (data['lokasi']?['alamat'] ?? '').toString().toLowerCase();
        return nama.contains(query) ||
            groupId.contains(query) ||
            fungsi.contains(query) ||
            tanggal.contains(query) ||
            lokasi.contains(query);
      }).toList();
    }

    _isApplyingFilter = false;

    if (mounted) {
      setState(() {
        _filteredData = result;
      });
      debugPrint('🔍 Filter result: ${_filteredData.length} items');
    }
  }

  // ===================================================================
  // STREAM
  // ===================================================================
  Stream<List<Map<String, dynamic>>> _getStream() {
    debugPrint('🌊 _getStream() | superadmin=${widget.isSuperadmin} | hsse=$_isHSSEManager');

    if (widget.isSuperadmin) {
      return _approvalService.getApprovalListForSuperadmin(
        status: 'pending',
        fungsiFilter: widget.fungsiFilterSuperadmin,
      );
    }

    if (_isHSSEManager) {
      return _approvalService.getHssePendingList(
        fungsiFilter: widget.fungsiFilterSuperadmin,
      );
    }

    return _approvalService.getPendingWithTransitionForManager(
      fungsiManager: widget.userFungsi ?? '',
      searchQuery: widget.searchQuery.isNotEmpty ? widget.searchQuery : null,
    );
  }

  // ===================================================================
  // DEBUG MANUAL QUERY
  // ===================================================================
  void _debugManualQuery() {
    debugPrint('📊 DEBUG MANUAL QUERY START');

    _firestore
        .collection('lembur_mitra')
        .where('status', whereIn: _validPendingStatuses)
        .limit(5)
        .get()
        .then((snapshot) {
      debugPrint('📊 lembur_mitra: ${snapshot.docs.length} docs');
      for (final doc in snapshot.docs) {
        final data = doc.data();
        debugPrint('   ✅ ${doc.id}: status=${data['status']}, fungsi=${data['pengawas_fungsi']}');
      }
    }).catchError((e) => debugPrint('❌ lembur_mitra error: $e'));

    _firestore
        .collection('pengajuan_lembur')
        .where('status', whereIn: _validPendingStatuses)
        .limit(5)
        .get()
        .then((snapshot) {
      debugPrint('📊 pengajuan_lembur: ${snapshot.docs.length} docs');
      for (final doc in snapshot.docs) {
        final data = doc.data();
        debugPrint('   ✅ ${doc.id}: status=${data['status']}, fungsi=${data['pengawas_fungsi']}');
      }
    }).catchError((e) => debugPrint('❌ pengajuan_lembur error: $e'));

    debugPrint('📊 DEBUG MANUAL QUERY END');
  }

  // ===================================================================
  // DIRECT QUERY TEST
  // ===================================================================
  void _debugDirectQuery() {
    debugPrint('🔴 DIRECT QUERY TEST START');

    // Test: whereIn + orderBy (query bermasalah)
    _firestore
        .collection('lembur_mitra')
        .where('status', whereIn: ['pending', 'pending_hsse'])
        .orderBy('created_at', descending: true)
        .limit(5)
        .get()
        .then((snap) {
      debugPrint('🔴 [whereIn+orderBy]: ${snap.docs.length} docs');
      for (var doc in snap.docs) {
        final d = doc.data();
        debugPrint('   ✅ ${doc.id}: status=${d['status']}, fungsi=${d['pengawas_fungsi']}');
      }
    }).catchError((e) {
      debugPrint('❌ [whereIn+orderBy] ERROR: $e');
      if (e is FirebaseException) {
        debugPrint('❌ Code: ${e.code} | Message: ${e.message}');
      }
    });

    // Test: isEqualTo (harusnya OK)
    _firestore
        .collection('lembur_mitra')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .limit(5)
        .get()
        .then((snap) {
      debugPrint('🔴 [isEqualTo pending]: ${snap.docs.length} docs');
      for (var doc in snap.docs) {
        final d = doc.data();
        debugPrint('   ✅ ${doc.id}: status=${d['status']}, fungsi=${d['pengawas_fungsi']}');
      }
    }).catchError((e) => debugPrint('❌ [isEqualTo] error: $e'));

    _firestore
        .collection('lembur_mitra')
        .where('status', isEqualTo: 'pending_hsse')
        .orderBy('created_at', descending: true)
        .limit(5)
        .get()
        .then((snap) {
      debugPrint('🔴 [isEqualTo pending_hsse]: ${snap.docs.length} docs');
      for (var doc in snap.docs) {
        final d = doc.data();
        debugPrint('   ✅ ${doc.id}: status=${d['status']}, fungsi=${d['pengawas_fungsi']}');
      }
    }).catchError((e) => debugPrint('❌ [isEqualTo pending_hsse] error: $e'));

    debugPrint('🔴 DIRECT QUERY TEST END');
  }

  // ===================================================================
  // HELPER
  // ===================================================================
  bool _listsEqual(
      List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['group_id'] != b[i]['group_id']) return false;
    }
    return true;
  }

  // ===================================================================
  // BUILD - SAFE (NO setState during build)
  // ===================================================================
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getStream(),
      builder: (context, snapshot) {
        // ✅ Handle loading
        if (snapshot.connectionState == ConnectionState.waiting && !_hasLoaded) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isHSSEManager ? hsseColor : primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isHSSEManager ? 'Memuat pengajuan K3...' : 'Memuat pengajuan...',
                  style: GoogleFonts.poppins(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
          );
        }

        // ✅ Handle error
        if (snapshot.hasError) {
          debugPrint('❌ Stream error: ${snapshot.error}');
          return _buildErrorState(snapshot.error.toString());
        }

        // ✅ Handle data - TUNDA ke next frame untuk hindari setState during build
        if (snapshot.hasData && snapshot.data != null) {
          final newData = snapshot.data!;
          // Cek apakah data benar-benar baru
          if (!_hasLoaded || !_listsEqual(_allData, newData)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _processStreamData(newData);
            });
          }
        }

        // ✅ Show empty state
        if (_filteredData.isEmpty && _allData.isEmpty && _hasLoaded) {
          return _buildEmptyState();
        }

        // ✅ Loading intermediate
        if (_filteredData.isEmpty && _allData.isNotEmpty) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                _isHSSEManager ? hsseColor : primaryColor,
              ),
            ),
          );
        }

        // ✅ Main content
        return Column(
          children: [
            if (_isManagerFungsi && _filteredData.isNotEmpty)
              _buildManagerFungsiInfoHeader(),
            if (_isHSSEManager && _filteredData.isNotEmpty)
              _buildHSSEInfoHeader(),
            if (widget.isSuperadmin && _filteredData.isNotEmpty)
              _buildSuperadminInfoHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _filteredData.length,
                itemBuilder: (context, index) {
                  final data = _filteredData[index];
                  final groupId = data['group_id'] ?? '';
                  return ApprovalCard(
                    data: data,
                    groupId: groupId,
                    isBulkMode: widget.isBulkMode,
                    isSelected: widget.selectedIds.contains(groupId),
                    onTap: () => widget.onShowDetail(groupId),
                    onSelectionChanged: widget.onSelectionChanged,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ===================================================================
  // ✅ SUPERADMIN INFO HEADER
  // ===================================================================
  Widget _buildSuperadminInfoHeader() {
    Map<String, int> perFungsi = {};
    int totalPending = _filteredData.length;

    for (final data in _filteredData) {
      final fungsi = data['pengawas_fungsi']?.toString().toLowerCase() ?? 'unknown';
      perFungsi[fungsi] = (perFungsi[fungsi] ?? 0) + 1;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.06),
            primaryColor.withValues(alpha: 0.02)
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Superadmin • $totalPending Pengajuan',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lintas semua fungsi',
                      style: GoogleFonts.poppins(fontSize: 10, color: textSecondary),
                    ),
                  ],
                ),
              ),
              if (widget.fungsiFilterSuperadmin != null &&
                  widget.fungsiFilterSuperadmin!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Filter: ${widget.fungsiFilterSuperadmin!.toUpperCase()}',
                    style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: Colors.orange),
                  ),
                ),
            ],
          ),
          if (perFungsi.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: perFungsi.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${entry.key.toUpperCase()}: ${entry.value}',
                    style: GoogleFonts.poppins(
                        fontSize: 9, fontWeight: FontWeight.w500,
                        color: textSecondary),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ===================================================================
  // MANAGER FUNGSI INFO HEADER
  // ===================================================================
  Widget _buildManagerFungsiInfoHeader() {
    int pendingBaru = 0;
    int menungguHSSE = 0;

    for (final data in _filteredData) {
      final status = data['status']?.toString() ?? '';
      if (status == 'pending') {
        pendingBaru++;
      } else if (status == 'pending_hsse') {
        menungguHSSE++;
      }
    }

    if (menungguHSSE == 0 && pendingBaru == _filteredData.length) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.06),
            primaryColor.withValues(alpha: 0.02)
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fact_check_rounded, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_filteredData.length} Pengajuan Perlu Ditinjau',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12, runSpacing: 4,
                  children: [
                    _buildStatusChip('Baru', pendingBaru, Colors.orange),
                    if (menungguHSSE > 0)
                      _buildStatusChip('Menunggu HSSE', menungguHSSE, successColor),
                  ],
                ),
              ],
            ),
          ),
          if (menungguHSSE > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: successColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 14, color: successColor),
                  const SizedBox(width: 4),
                  Text('$menungguHSSE',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: successColor)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text('$label: $count',
            style: GoogleFonts.poppins(
                fontSize: 11, color: textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ===================================================================
  // HSSE INFO HEADER
  // ===================================================================
  Widget _buildHSSEInfoHeader() {
    int flaggedCount = 0;
    Map<String, int> perFungsi = {};

    for (final data in _filteredData) {
      final status = data['status']?.toString() ?? '';
      final fungsi = data['pengawas_fungsi']?.toString() ?? 'unknown';
      if (status == 'pending_hsse') flaggedCount++;
      perFungsi[fungsi] = (perFungsi[fungsi] ?? 0) + 1;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          hsseColor.withValues(alpha: 0.08),
          hsseColor.withValues(alpha: 0.03)
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hsseColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: hsseColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.health_and_safety, color: hsseColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'K3 Lintas Fungsi • ${_filteredData.length} pengajuan',
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: hsseColor),
                ),
              ),
              if (flaggedCount > 0)
                _buildMiniBadge('K3', flaggedCount, Colors.orange),
            ],
          ),
          if (perFungsi.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: perFungsi.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                      '${entry.key.toUpperCase()}: ${entry.value}',
                      style: GoogleFonts.poppins(
                          fontSize: 9, fontWeight: FontWeight.w500,
                          color: textSecondary)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text('$label:$count',
          style: GoogleFonts.poppins(
              fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ===================================================================
  // ERROR & EMPTY STATE
  // ===================================================================
  Widget _buildErrorState(String errorMessage) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.error_outline, size: 32,
                  color: Colors.red.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Text('Gagal Memuat Data',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: textSecondary)),
            const SizedBox(height: 6),
            Text(
              _isHSSEManager
                  ? 'Tidak dapat mengambil pengajuan K3.'
                  : 'Tidak dapat mengambil data.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _hasLoaded = false;
                    _allData = [];
                    _filteredData = [];
                  });
                }
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: Text('Coba Lagi',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isHSSEManager ? hsseColor : primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: (_isHSSEManager ? hsseColor : primaryColor)
                    .withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _isHSSEManager ? Icons.health_and_safety : Icons.inbox_outlined,
                size: 36,
                color: (_isHSSEManager ? hsseColor : primaryColor)
                    .withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isHSSEManager ? 'Tidak Ada Pengajuan K3' : 'Tidak Ada Pengajuan',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              _isHSSEManager
                  ? 'Semua pengajuan berisiko telah divalidasi.\nData akan muncul saat ada pengajuan baru yang memerlukan review K3.'
                  : 'Semua pengajuan telah diproses.\nData akan muncul saat ada pengajuan baru.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
            ),
            if (widget.fungsiFilterSuperadmin != null &&
                widget.fungsiFilterSuperadmin!.isNotEmpty &&
                widget.fungsiFilterSuperadmin != 'semua') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_alt, size: 12, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                        'Filter: ${widget.fungsiFilterSuperadmin!.toUpperCase()}',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: Colors.orange,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}