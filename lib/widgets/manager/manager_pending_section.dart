import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Premium Manager Pending Section dengan pemisahan Pending vs Pending HSSE
class ManagerPendingSection extends StatefulWidget {
  final List<Map<String, dynamic>> pendingList;
  final String Function(dynamic) getTimeAgo;
  final Future<void> Function(Map<String, dynamic>) onApprove;
  final Future<void> Function(Map<String, dynamic>) onReject;

  final bool isHSSEManager;
  final bool showRiskIndicator;
  final bool enableSwipeActions;
  final bool showDetailedInfo;
  final int maxItemsToShow;
  final String? emptyStateMessage;
  final String? emptyStateIcon;
  final VoidCallback? onViewAll;
  final Function(Map<String, dynamic>)? onItemTap;
  final Function(Map<String, dynamic>)? onRiskTap;
  final String? filterRiskLevel;

  final List<Map<String, dynamic>>? hssePendingList;
  final bool showHSSESection;

  final Color? customPrimaryColor;
  final Color? customCardColor;
  final double? customBorderRadius;
  final bool compactMode;
  final bool showApproveAll;
  final bool showRejectAll;
  final Widget? customHeader;
  final Widget? customFooter;

  const ManagerPendingSection({
    super.key,
    required this.pendingList,
    required this.getTimeAgo,
    required this.onApprove,
    required this.onReject,
    this.isHSSEManager = false,
    this.showRiskIndicator = true,
    this.enableSwipeActions = true,
    this.showDetailedInfo = true,
    this.maxItemsToShow = 5,
    this.emptyStateMessage,
    this.emptyStateIcon,
    this.onViewAll,
    this.onItemTap,
    this.onRiskTap,
    this.filterRiskLevel,
    this.hssePendingList,
    this.showHSSESection = false,
    this.customPrimaryColor,
    this.customCardColor,
    this.customBorderRadius,
    this.compactMode = false,
    this.showApproveAll = false,
    this.showRejectAll = false,
    this.customHeader,
    this.customFooter,
  });

  @override
  State<ManagerPendingSection> createState() => _ManagerPendingSectionState();
}

class _ManagerPendingSectionState extends State<ManagerPendingSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _showHSSESectionLocal = false;
  final Map<String, bool> _expandedItems = {};

  // ═══════════════════════════════════════════════════════════════
  // 🔥 DEFINISI STATUS - PENTING UNTUK AKURASI
  // ═══════════════════════════════════════════════════════════════

  /// Status yang DI-EXCLUDE dari tampilan pending (sudah selesai diproses)
  static const List<String> _excludedStatuses = [
    'dibatalkan', 'cancelled', 'canceled',
    'ditolak', 'rejected',
    'selesai', 'completed',
    'disetujui', 'approved',
    'kadaluarsa',
  ];

  /// Status yang MASUK ke pending HSSE (BUKAN pending biasa)
  static const List<String> _hssePendingStatuses = [
    'pending_hsse',
    'manager_approval_pending_hsse',
    'manager_approved_pending_hsse',
  ];

  /// Status yang MASUK ke pending biasa (hanya 'pending' murni)
  static const String _regularPendingStatus = 'pending';

  // ═══════════════════════════════════════════════════════════════
  // 🔥 HELPER METHODS - DETEKSI STATUS
  // ═══════════════════════════════════════════════════════════════

  bool _isExcluded(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase().trim();
    return _excludedStatuses.contains(status);
  }

  bool _isCancelled(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase().trim();
    return status == 'dibatalkan' || status == 'cancelled' || status == 'canceled';
  }

  bool _isRejected(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase().trim();
    return status == 'ditolak' || status == 'rejected';
  }

  bool _isCompleted(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase().trim();
    return status == 'selesai' || status == 'completed' || 
           status == 'disetujui' || status == 'approved';
  }

  /// 🔥 DETEKSI APAKAH INI PENDING HSSE (berdasarkan status)
  bool _isPendingHSSE(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase().trim();
    return _hssePendingStatuses.contains(status);
  }

  /// 🔥 DETEKSI APAKAH INI PENDING BIASA (berdasarkan status)
  bool _isPendingRegular(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase().trim();
    return status == _regularPendingStatus;
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 GETTER UNTUK LIST YANG DIPISAH
  // ═══════════════════════════════════════════════════════════════

  /// List pending BIASA (status = 'pending' saja)
  List<Map<String, dynamic>> get _regularPendingItems {
    return widget.pendingList
        .where((item) => _isPendingRegular(item) && !_isExcluded(item))
        .toList();
  }

  /// List pending HSSE (status = 'pending_hsse', dll)
  List<Map<String, dynamic>> get _hssePendingItems {
    return widget.pendingList
        .where((item) => _isPendingHSSE(item) && !_isExcluded(item))
        .toList();
  }

  /// List yang di-exclude (dibatalkan, ditolak, selesai)
  List<Map<String, dynamic>> get _excludedItems {
    return widget.pendingList.where((item) => _isExcluded(item)).toList();
  }

  int get _regularCount => _regularPendingItems.length;
  int get _hsseCount => _hssePendingItems.length;
  int get _excludedCount => _excludedItems.length;
  int get _cancelledCount => _excludedItems.where((item) => _isCancelled(item)).length;
  int get _rejectedCount => _excludedItems.where((item) => _isRejected(item)).length;
  int get _completedCount => _excludedItems.where((item) => _isCompleted(item)).length;

  // Untuk sorting regular pending
  List<Map<String, dynamic>> get _sortedRegularList {
    final sorted = List<Map<String, dynamic>>.from(_regularPendingItems);
    sorted.sort((a, b) {
      final dateA = _getOvertimeDate(a);
      final dateB = _getOvertimeDate(b);
      final priorityA = _getDatePriority(dateA);
      final priorityB = _getDatePriority(dateB);
      
      if (priorityA != priorityB) return priorityB.compareTo(priorityA);
      
      final riskA = _getRiskPriority(a['risk_level']?.toString() ?? '');
      final riskB = _getRiskPriority(b['risk_level']?.toString() ?? '');
      if (riskA != riskB) return riskB.compareTo(riskA);
      
      return _getOvertimeDuration(b).compareTo(_getOvertimeDuration(a));
    });
    
    // Filter by risk level jika ada
    if (widget.filterRiskLevel != null) {
      final filter = widget.filterRiskLevel!.toLowerCase();
      return sorted.where((item) {
        final risk = item['risk_level']?.toString().toLowerCase() ?? '';
        if (filter == 'high' || filter == 'tinggi') {
          return risk.contains('high') || risk.contains('tinggi');
        } else if (filter == 'medium' || filter == 'sedang') {
          return risk.contains('medium') || risk.contains('sedang');
        } else if (filter == 'low' || filter == 'rendah') {
          return risk.contains('low') || risk.contains('rendah');
        }
        return true;
      }).toList();
    }
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _showHSSESectionLocal = widget.showHSSESection || widget.isHSSEManager;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 DATA EXTRACTION HELPERS
  // ═══════════════════════════════════════════════════════════════

  String _getMitraName(Map<String, dynamic> data) {
    return data['nama_mitra']?.toString() ??
        data['mitra_nama']?.toString() ??
        data['nama_lengkap']?.toString() ??
        data['pengawas_nama']?.toString() ??
        data['nama_pengawas']?.toString() ??
        data['nama']?.toString() ??
        data['name']?.toString() ??
        'Unknown';
  }

  String? _getMitraPhotoUrl(Map<String, dynamic> data) {
    return data['photo_url']?.toString() ??
        data['mitra_photo_url']?.toString() ??
        data['avatar']?.toString();
  }

  DateTime? _getOvertimeDate(Map<String, dynamic> data) {
    try {
      if (data['tanggal_lembur'] is Timestamp) {
        return (data['tanggal_lembur'] as Timestamp).toDate();
      }
      if (data['tanggal'] is Timestamp) {
        return (data['tanggal'] as Timestamp).toDate();
      }
      if (data['created_at'] is Timestamp) {
        return (data['created_at'] as Timestamp).toDate();
      }
      
      final dateStr = data['tanggal_lembur']?.toString() ??
          data['tanggal']?.toString() ??
          data['date']?.toString() ??
          data['created_at']?.toString() ??
          data['submitted_at']?.toString();
      
      if (dateStr != null && dateStr.isNotEmpty) {
        return DateTime.tryParse(dateStr);
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }
    return null;
  }

  double _getOvertimeDuration(Map<String, dynamic> data) {
    final duration = data['total_jam_desimal'] ?? 
                     data['total_jam'] ?? 
                     data['durasi_jam'] ?? 
                     data['duration_hours'] ?? 
                     0;
    if (duration is num) return duration.toDouble();
    if (duration is String) return double.tryParse(duration) ?? 0;
    return 0;
  }

  String _formatOvertimeDate(DateTime? date) {
    if (date == null) return '-';
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Hari ini';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (date.day == tomorrow.day && date.month == tomorrow.month && date.year == tomorrow.year) {
      return 'Besok';
    }
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return months[month - 1];
  }

  int _getDatePriority(DateTime? date) {
    if (date == null) return 0;
    final now = DateTime.now();
    final difference = date.difference(now);
    if (difference.isNegative) return 999;
    if (difference.inHours <= 24) return 100;
    if (difference.inDays <= 3) return 50;
    if (difference.inDays <= 7) return 25;
    return 10;
  }

  int _getRiskPriority(String riskLevel) {
    final lower = riskLevel.toLowerCase();
    if (lower.contains('high') || lower.contains('tinggi')) return 3;
    if (lower.contains('medium') || lower.contains('sedang')) return 2;
    if (lower.contains('low') || lower.contains('rendah')) return 1;
    return 0;
  }

  bool get _hasHSSEPending => _hsseCount > 0;
  bool get _hasRegularPending => _regularCount > 0;
  bool get _hasAnyContent => _hasRegularPending || _hasHSSEPending;
  bool get _isMobile => MediaQuery.of(context).size.width < 430;

  // ═══════════════════════════════════════════════════════════════
  // 🔥 BUILD METHOD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.customPrimaryColor ?? const Color(0xFF1E3C72);
    
    final regularDisplay = _sortedRegularList.take(widget.maxItemsToShow).toList();
    final hsseDisplay = _hssePendingItems.take(widget.maxItemsToShow).toList();
    final hasMoreRegular = _sortedRegularList.length > widget.maxItemsToShow;
    final hasMoreHSSE = _hssePendingItems.length > widget.maxItemsToShow;

    final showHSSESection = _hasHSSEPending && _showHSSESectionLocal;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: EdgeInsets.all(widget.compactMode ? 10 : 14),
          decoration: BoxDecoration(
            color: widget.customCardColor ?? Colors.white,
            borderRadius: BorderRadius.circular(widget.customBorderRadius ?? 20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              if (_hasHSSEPending)
                BoxShadow(
                  color: const Color(0xFFFF3B3B).withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
            ],
            border: _hasHSSEPending
                ? Border.all(
                    color: const Color(0xFFFF3B3B).withValues(alpha: 0.3),
                    width: 1.5,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              if (widget.customHeader != null)
                widget.customHeader!
              else
                _buildDefaultHeader(primaryColor),

              // 🔥 STATUS INFO BAR - Menampilkan data yang di-exclude
              if (_excludedCount > 0) ...[
                const SizedBox(height: 6),
                _buildStatusInfoBar(),
              ],

              // 🔥 BAGIAN PENDING HSSE (DIPISAH - DI ATAS)
              if (showHSSESection) ...[
                const SizedBox(height: 8),
                _buildHSSESectionHeader(primaryColor),
                const SizedBox(height: 4),
                if (hsseDisplay.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...List.generate(hsseDisplay.length, (index) {
                    return _buildPendingItem(
                      context,
                      hsseDisplay[index],
                      primaryColor,
                      index,
                      isHSSEItem: true,
                    );
                  }),
                  if (hasMoreHSSE)
                    _buildViewMoreButton(
                      primaryColor,
                      count: _hssePendingItems.length - widget.maxItemsToShow,
                      isHSSE: true,
                    ),
                ],
                // Divider antara HSSE dan Regular
                if (hsseDisplay.isNotEmpty && regularDisplay.isNotEmpty)
                  _buildSectionDivider('Pengajuan Reguler (Menunggu Persetujuan)'),
              ],

              SizedBox(height: widget.compactMode ? 6 : 10),

              // 🔥 EMPTY STATE
              if (!_hasAnyContent)
                _buildEmptyState()
              else ...[
                // 🔥 BAGIAN PENDING BIASA (DI BAWAH)
                if (regularDisplay.isNotEmpty) ...[
                  ...List.generate(regularDisplay.length, (index) {
                    return _buildPendingItem(
                      context,
                      regularDisplay[index],
                      primaryColor,
                      index,
                      isHSSEItem: false,
                    );
                  }),
                  if (hasMoreRegular)
                    _buildViewMoreButton(
                      primaryColor,
                      count: _sortedRegularList.length - widget.maxItemsToShow,
                      isHSSE: false,
                    ),
                ],
              ],

              if (widget.customFooter != null) widget.customFooter!,
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 STATUS INFO BAR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStatusInfoBar() {
    final parts = <String>[];
    if (_cancelledCount > 0) parts.add('$_cancelledCount dibatalkan');
    if (_rejectedCount > 0) parts.add('$_rejectedCount ditolak');
    if (_completedCount > 0) parts.add('$_completedCount selesai');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.withValues(alpha: 0.08), Colors.grey.withValues(alpha: 0.03)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.filter_list_rounded, color: Colors.grey, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                children: [
                  TextSpan(
                    text: parts.join(', '),
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[700]),
                  ),
                  const TextSpan(text: ' — sudah selesai diproses'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 HEADER (DENGAN INFORMASI PENDING HSSE vs BIASA)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDefaultHeader(Color primaryColor) {
    final highRiskCount = _sortedRegularList
        .where((item) {
          final risk = item['risk_level']?.toString().toLowerCase() ?? '';
          return risk.contains('high') || risk.contains('tinggi');
        })
        .length;

    final urgentCount = _sortedRegularList.where((item) {
      final date = _getOvertimeDate(item);
      if (date == null) return false;
      return date.difference(DateTime.now()).inHours <= 24;
    }).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Icon
          if (_hasHSSEPending)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.15),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B3B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF3B3B).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.security_rounded, color: Color(0xFFFF3B3B), size: 20),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.pending_actions_rounded, color: primaryColor, size: 20),
            ),
          
          SizedBox(width: widget.compactMode ? 8 : 10),
          
          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      _hasHSSEPending ? '⚠️ Persetujuan & Validasi K3' : 'Menunggu Persetujuan',
                      style: TextStyle(
                        fontSize: widget.compactMode ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A2B4C),
                      ),
                    ),
                    // 🔥 Badge HSSE
                    if (_hasHSSEPending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B3B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_hsseCount K3 PENDING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    // 🔥 Badge Regular Pending
                    if (_hasRegularPending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_regularCount PENDING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    // 🔥 Badge Urgent
                    if (urgentCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B3B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded, color: Colors.white, size: 9),
                            const SizedBox(width: 2),
                            Text(
                              '$urgentCount URGENT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                // 🔥 SUBTITLE DENGAN INFO LENGKAP
                Text(
                  _buildSubtitle(),
                  style: TextStyle(
                    fontSize: widget.compactMode ? 10 : 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          
          // Toggle HSSE section
          if (_hasHSSEPending)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showHSSESectionLocal = !_showHSSESectionLocal;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _showHSSESectionLocal
                      ? const Color(0xFFFF3B3B).withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _showHSSESectionLocal ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18,
                  color: _showHSSESectionLocal ? const Color(0xFFFF3B3B) : Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 🔥 Build subtitle dengan info pending biasa vs HSSE
  String _buildSubtitle() {
    final parts = <String>[];
    
    if (_hasRegularPending) {
      parts.add('$_regularCount pengajuan menunggu persetujuan');
    }
    if (_hasHSSEPending) {
      parts.add('$_hsseCount perlu validasi K3');
    }
    if (_excludedCount > 0) {
      parts.add('$_excludedCount sudah diproses');
    }
    
    return parts.join(' • ');
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 HSSE SECTION HEADER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHSSESectionHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withValues(alpha: 0.15),
            const Color(0xFFFF3B3B).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B3B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF3B3B).withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Color(0xFFFF3B3B),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '⚠️ Pengajuan Perlu Validasi K3',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_hsseCount pengajuan dengan status pending HSSE memerlukan tindakan Anda',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: const Color(0xFFFF3B3B),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: widget.onViewAll ?? () => context.push('/approval'),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'VALIDASI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 SECTION DIVIDER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSectionDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 PENDING ITEM CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPendingItem(
    BuildContext context,
    Map<String, dynamic> lembur,
    Color primaryColor,
    int index, {
    bool isHSSEItem = false,
  }) {
    final riskLevel = lembur['risk_level']?.toString().toLowerCase() ?? '';
    final isHighRisk = riskLevel.contains('high') || riskLevel.contains('tinggi');
    final isMediumRisk = riskLevel.contains('medium') || riskLevel.contains('sedang');
    
    final itemId = lembur['id']?.toString() ??
        lembur['uid']?.toString() ??
        lembur['group_id']?.toString() ??
        index.toString();
    final isExpanded = _expandedItems[itemId] ?? false;

    final overtimeDate = _getOvertimeDate(lembur);
    final duration = _getOvertimeDuration(lembur);
    final formattedDate = _formatOvertimeDate(overtimeDate);
    final isUrgent = overtimeDate != null && 
        overtimeDate.difference(DateTime.now()).inHours <= 24;

    // Warna berdasarkan tipe
    Color riskColor;
    if (isHSSEItem) {
      riskColor = const Color(0xFFFF6B35); // Orange untuk HSSE
    } else if (isUrgent) {
      riskColor = const Color(0xFFFF3B3B); // Merah untuk urgent
    } else if (isHighRisk) {
      riskColor = const Color(0xFFFF3B3B);
    } else if (isMediumRisk) {
      riskColor = const Color(0xFFFF9500);
    } else {
      riskColor = primaryColor;
    }

    final borderColor = riskColor;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, animation, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation)),
          child: Opacity(opacity: animation, child: child),
        );
      },
      child: GestureDetector(
        onTap: widget.onItemTap != null ? () => widget.onItemTap!(lembur) : null,
        child: Container(
          margin: EdgeInsets.only(bottom: widget.compactMode ? 6 : 8),
          decoration: BoxDecoration(
            color: riskColor.withValues(alpha: isHSSEItem ? 0.08 : 0.05),
            borderRadius: BorderRadius.circular(widget.compactMode ? 10 : 12),
            border: Border.all(
              color: borderColor.withValues(alpha: isHSSEItem ? 0.5 : 0.3),
              width: isHSSEItem || isUrgent ? 1.5 : 1,
            ),
            boxShadow: (isHSSEItem || isUrgent)
                ? [
                    BoxShadow(
                      color: riskColor.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              // Banner untuk HSSE / Urgent
              if (isHSSEItem || isUrgent)
                _buildUrgentBanner(
                  riskColor,
                  isHSSEItem: isHSSEItem,
                  isUrgent: isUrgent && !isHSSEItem,
                ),
              
              Padding(
                padding: EdgeInsets.all(widget.compactMode ? 8 : 10),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        _buildUserAvatar(lembur, riskColor, isHSSEItem || isUrgent || isHighRisk),
                        SizedBox(width: widget.compactMode ? 8 : 10),
                        
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Nama + Badges
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    _getMitraName(lembur),
                                    style: TextStyle(
                                      fontSize: widget.compactMode ? 11 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A2B4C),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Badge HSSE
                                  if (isHSSEItem)
                                    _buildStatusBadge(
                                      'K3',
                                      const Color(0xFFFF6B35),
                                    ),
                                  // Badge Risk
                                  if (!isHSSEItem && widget.showRiskIndicator && (isHighRisk || isMediumRisk))
                                    _buildStatusBadge(
                                      isHighRisk ? 'HIGH' : 'MED',
                                      riskColor,
                                    ),
                                  // Badge Urgent
                                  if (isUrgent && !isHSSEItem)
                                    _buildStatusBadge(
                                      'URGENT',
                                      const Color(0xFFFF3B3B),
                                    ),
                                ],
                              ),
                              
                              SizedBox(height: widget.compactMode ? 2 : 4),
                              
                              // Info baris kedua
                              _buildItemInfoRow(
                                formattedDate: formattedDate,
                                duration: duration,
                                fungsi: lembur['pengawas_fungsi']?.toString(),
                                isUrgent: isUrgent,
                              ),
                              
                              // Expanded info
                              if (widget.showDetailedInfo && isExpanded)
                                _buildExpandedInfo(lembur, riskColor, overtimeDate, duration),
                            ],
                          ),
                        ),
                        
                        // Tombol Tinjau
                        _buildReviewButton(riskColor, lembur, isHSSEItem),
                      ],
                    ),
                    
                    // Toggle expand
                    if (widget.showDetailedInfo)
                      GestureDetector(
                        onTap: () => setState(() {
                          _expandedItems[itemId] = !isExpanded;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                              Text(
                                isExpanded ? 'Sembunyikan' : 'Detail',
                                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildItemInfoRow({
    required String formattedDate,
    required double duration,
    String? fungsi,
    bool isUrgent = false,
  }) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        // Tanggal
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: widget.compactMode ? 10 : 11,
              color: isUrgent ? const Color(0xFFFF3B3B) : Colors.grey[500],
            ),
            const SizedBox(width: 2),
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: widget.compactMode ? 9 : 10,
                color: isUrgent ? const Color(0xFFFF3B3B) : Colors.grey[600],
                fontWeight: isUrgent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
        // Durasi
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: widget.compactMode ? 10 : 11,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 2),
            Text(
              '${duration.toStringAsFixed(1)} jam',
              style: TextStyle(
                fontSize: widget.compactMode ? 9 : 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        // Fungsi
        if (fungsi != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _getFungsiColor(fungsi).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getFungsiLabel(fungsi),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: _getFungsiColor(fungsi),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUrgentBanner(
    Color riskColor, {
    bool isHSSEItem = false,
    bool isUrgent = false,
  }) {
    final icon = isHSSEItem 
        ? Icons.health_and_safety_rounded 
        : Icons.warning_amber_rounded;
    
    final text = isHSSEItem 
        ? '⚠️ Perlu Validasi K3 - Status: pending_hsse'
        : '⚡ URGENT - Perlu ditinjau segera';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [riskColor.withValues(alpha: 0.3), riskColor.withValues(alpha: 0.1)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: riskColor, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: riskColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> lembur, Color riskColor, bool isHighRisk) {
    final photoUrl = _getMitraPhotoUrl(lembur);
    final name = _getMitraName(lembur);
    
    return Container(
      width: widget.compactMode ? 32 : 36,
      height: widget.compactMode ? 32 : 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isHighRisk
              ? [riskColor.withValues(alpha: 0.3), riskColor.withValues(alpha: 0.1)]
              : [riskColor.withValues(alpha: 0.2), riskColor.withValues(alpha: 0.05)],
        ),
        border: Border.all(
          color: riskColor.withValues(alpha: isHighRisk ? 0.5 : 0.3),
          width: isHighRisk ? 2 : 1.5,
        ),
      ),
      child: photoUrl != null && photoUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitials(name, riskColor),
              ),
            )
          : _buildInitials(name, riskColor),
    );
  }

  Widget _buildInitials(String name, Color color) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: TextStyle(
          color: color,
          fontSize: widget.compactMode ? 12 : 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildExpandedInfo(
    Map<String, dynamic> lembur,
    Color riskColor,
    DateTime? overtimeDate,
    double duration,
  ) {
    final isMobile = _isMobile;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(isMobile ? 10 : 8),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            Icons.calendar_today_rounded,
            'Tanggal',
            overtimeDate != null 
                ? '${overtimeDate.day} ${_getMonthName(overtimeDate.month)} ${overtimeDate.year}'
                : '-',
            isMobile: isMobile,
          ),
          _buildInfoRow(
            Icons.timer_rounded,
            'Durasi',
            '${duration.toStringAsFixed(1)} jam',
            isMobile: isMobile,
          ),
          _buildInfoRow(
            Icons.person_outline,
            'Fungsi',
            _getFungsiLabel(lembur['pengawas_fungsi']?.toString()),
            isMobile: isMobile,
          ),
          _buildInfoRow(
            Icons.location_on_outlined,
            'Lokasi',
            lembur['lokasi']?['alamat']?.toString() ?? lembur['lokasi']?.toString() ?? '-',
            isMobile: isMobile,
          ),
          _buildInfoRow(
            Icons.description_outlined,
            'Keterangan',
            lembur['keterangan']?.toString() ?? lembur['alasan']?.toString() ?? '-',
            isMobile: isMobile,
          ),
          // 🔥 TAMPILKAN STATUS ASLI (untuk debugging & kejelasan)
          _buildInfoRow(
            Icons.info_outline,
            'Status',
            lembur['status']?.toString() ?? '-',
            isMobile: isMobile,
            valueColor: _isPendingHSSE(lembur) 
                ? const Color(0xFFFF6B35) 
                : _isPendingRegular(lembur) 
                    ? const Color(0xFF1E3C72) 
                    : null,
          ),
          if (widget.isHSSEManager && lembur['risk_level'] != null &&
              lembur['risk_level'].toString().isNotEmpty &&
              lembur['risk_level'].toString().toLowerCase() != 'not set')
            _buildInfoRow(
              Icons.warning_amber_rounded,
              'Risk Level',
              lembur['risk_level'].toString(),
              isMobile: isMobile,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isMobile = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: isMobile ? 13 : 12, color: Colors.grey[500]),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: isMobile ? 70 : 65,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: isMobile ? 11 : 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 11 : 10,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1A2B4C),
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewButton(Color riskColor, Map<String, dynamic> lembur, bool isHSSEItem) {
    final buttonColor = isHSSEItem ? const Color(0xFFFF6B35) : riskColor;
    
    return Material(
      color: buttonColor,
      borderRadius: BorderRadius.circular(widget.compactMode ? 6 : 8),
      child: InkWell(
        onTap: () {
          if (widget.onItemTap != null) {
            widget.onItemTap!(lembur);
          } else {
            context.push('/approval');
          }
        },
        borderRadius: BorderRadius.circular(widget.compactMode ? 6 : 8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compactMode ? 8 : 10,
            vertical: widget.compactMode ? 5 : 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_rounded,
                color: Colors.white,
                size: widget.compactMode ? 12 : 14,
              ),
              SizedBox(width: widget.compactMode ? 2 : 4),
              Text(
                isHSSEItem ? 'VALIDASI' : 'TINJAU',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compactMode ? 9 : 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewMoreButton(
    Color primaryColor, {
    required int count,
    bool isHSSE = false,
  }) {
    final color = isHSSE ? const Color(0xFFFF6B35) : primaryColor;
    
    return Center(
      child: TextButton.icon(
        onPressed: widget.onViewAll ?? () => context.push('/approval'),
        icon: Icon(Icons.arrow_forward_rounded, size: 14, color: color),
        label: Text(
          'Lihat $count lainnya...',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: Colors.green[300],
            ),
            const SizedBox(height: 12),
            Text(
              widget.emptyStateMessage ?? '✅ Tidak ada pengajuan pending\nSemua pengajuan sudah diproses',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 FUNGSI & WARNA HELPERS
  // ═══════════════════════════════════════════════════════════════

  String _getFungsiLabel(String? f) {
    switch (f?.toLowerCase()) {
      case 'operation': return 'Operation';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'Business Support';
      default: return f ?? 'Unknown';
    }
  }

  Color _getFungsiColor(String? fungsi) {
    switch (fungsi?.toLowerCase()) {
      case 'operation': return const Color(0xFF1976D2);
      case 'maintenance': return const Color(0xFFFF9800);
      case 'hsse': return const Color(0xFF9C27B0);
      case 'gpr': return const Color(0xFFEF4444);
      case 'bs': return const Color(0xFF795548);
      default: return const Color(0xFF6366F1);
    }
  }
}