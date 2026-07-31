import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/core/services/report_service.dart';
import '/widgets/bottom_nav/app_bottom_nav.dart'; // ← TAMBAHKAN INI

// ============================================================================
// 🎨 PGE KAMOJANG COLOR SYSTEM - ENHANCED
// ============================================================================
class PGEColors {
  static const primary = Color(0xFF003D7A);
  static const primaryDark = Color(0xFF002548);
  static const primaryLight = Color(0xFFE8F0FE);
  static const secondary = Color(0xFFFF6B35);
  static const secondaryLight = Color(0xFFFFF0E8);
  static const success = Color(0xFF27AE60);
  static const warning = Color(0xFFF2994A);
  static const danger = Color(0xFFEB5757);
  static const info = Color(0xFF2F80ED);
  static const bg = Color(0xFFF8F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const divider = Color(0xFFF0F0F5);
  static const geothermal = Color(0xFF00897B);
  static const geothermalLight = Color(0xFFE0F2F1);
  static const steam = Color(0xFFF5F5F5);
  static const cardGradient1 = Color(0xFF667eea);
  static const cardGradient2 = Color(0xFF764ba2);
  static const gold = Color(0xFFFFD700);
  static const silver = Color(0xFFC0C0C0);
  static const bronze = Color(0xFFCD7F32);
}

// ============================================================================
// 📱 REPORT PAGE - PGE KAMOJANG V7 ULTIMATE MOBILE UI
// ============================================================================

class ReportPage extends StatefulWidget {
  final String userRole;
  final String? userFungsi;
  final String? userId;
  final String? userName;

  const ReportPage({
    super.key,
    required this.userRole,
    this.userFungsi,
    this.userId,
    this.userName,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ReportService _reportService = ReportService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  StreamSubscription<List<LaporanItem>>? _subscription;

  String _selectedBulan = 'semua';
  String _selectedStatus = 'semua';
  String _selectedAbsensi = 'semua';
  String? _selectedPaidFilter;
  String _searchQuery = '';
  int _selectedTabIndex = 0;

  List<LaporanItem> _items = [];
  List<LaporanItem> _filteredItems = [];
  LaporanSummary _summary = LaporanSummary.empty();
  List<String> _bulanOptions = ['semua'];
  bool _isLoading = true;
  bool _isExporting = false;
  bool _showSearchBar = false;

  String _actualUserRole = '';
  bool _isLoadingRole = true;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isSuperadmin {
    if (_actualUserRole.isNotEmpty) {
      final role = _actualUserRole.toLowerCase();
      return role == 'superadmin' ||
          role == 'super_admin' ||
          role == 'admin' ||
          role == 'administrator';
    }
    final role = widget.userRole.toLowerCase();
    return role == 'superadmin' ||
        role == 'super_admin' ||
        role == 'admin' ||
        role == 'administrator';
  }

  int get _unpaidCount => _items.where((i) => !i.isPaid).length;
  int get _bisaDibayarCount =>
      _items.where((i) => !i.isPaid && i.memenuhiSyaratBayar).length;
  bool get _hasBisaDibayar => _bisaDibayarCount > 0;

  double get _totalJamSelesai => _items
      .where((i) => i.status == 'selesai' || i.absensiStatus == 'selesai' || i.absensiStatus == 'selesai_terlambat')
      .fold<double>(0, (sum, i) => sum + i.totalJam);

  double get _totalPendapatanDibayar => _items
      .where((i) => i.isPaid)
      .fold<double>(0, (sum, i) => sum + i.biayaAktual);

  double get _totalPendapatanBelum => _items
      .where((i) => !i.isPaid && i.memenuhiSyaratBayar)
      .fold<double>(0, (sum, i) => sum + i.biayaAktual);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    _getUserRoleFromFirestore();
    _loadInitialData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startStream();
    }
  }

  Future<void> _getUserRoleFromFirestore() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        setState(() => _isLoadingRole = false);
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _actualUserRole = data['role']?.toString() ?? '';
          _isLoadingRole = false;
        });
      } else {
        setState(() => _isLoadingRole = false);
      }
    } catch (e) {
      setState(() => _isLoadingRole = false);
      debugPrint('❌ Error get role: $e');
    }
  }

  Future<void> _loadInitialData() async {
    await _loadBulanOptions();
    _startStream();
  }

  Future<void> _loadBulanOptions() async {
    try {
      final options = await _reportService.getBulanTersedia();
      if (mounted) {
        setState(() {
          _bulanOptions = options;
          if (options.length > 1) _selectedBulan = options[1];
        });
      }
    } catch (e) {
      debugPrint('Error load bulan: $e');
    }
  }

  void _startStream() {
    _subscription?.cancel();
    if (!mounted) return;
    setState(() => _isLoading = true);

    _subscription = _reportService
        .getLaporanStream(
          userRole: widget.userRole,
          userId: widget.userId,
          userFungsi: widget.userFungsi,
          bulan: _selectedBulan,
          statusFilter: _selectedStatus,
          absensiFilter: _selectedAbsensi,
          isPaidFilter:
              _selectedPaidFilter == null ? null : _selectedPaidFilter == 'true',
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        )
        .listen((items) {
      if (mounted) {
        setState(() {
          _items = items;
          _filteredItems = items;
          _isLoading = false;
        });
        _loadSummary();
      }
    }, onError: (e) {
      debugPrint('Stream error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Gagal memuat data', isError: true);
      }
    });
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await _reportService.getLaporanSummary(
        userRole: widget.userRole,
        userId: widget.userId,
        userFungsi: widget.userFungsi,
        bulan: _selectedBulan,
      );
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      debugPrint('Summary error: $e');
    }
  }

  // ═══════════════════════════════════════════════════
  // 🧭 NAVIGATION INDEX
  // ═══════════════════════════════════════════════════
  
  /// Mendapatkan index navigasi untuk bottom nav
  int _getNavIndex() {
    // Sesuaikan dengan index menu Laporan di AppBottomNav
    // 0 = Home/Dashboard
    // 1 = Riwayat Lembur  
    // 2 = Laporan (halaman ini)
    // 3 = Approval (jika ada)
    // 4 = Profile
    return 2;
  }

  // ═══════════════════════════════════════════════════
  // 💰 PAYMENT FUNCTIONS
  // ═══════════════════════════════════════════════════

  Future<void> _tandaiDibayar(LaporanItem item) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final validasi = await _reportService.validasiPembayaran(item.id);

    if (validasi['valid'] != true) {
      if (!mounted) return;

      final isTerlambat = item.absensiStatus == 'selesai_terlambat' ||
          validasi['detail']?['absensi_status'] == 'selesai_terlambat';
      final hasAlasanKeterlambatan = (validasi['detail']?['alasan_keterlambatan'] != null &&
              validasi['detail']?['alasan_keterlambatan']?.toString().isNotEmpty == true) ??
          false;
      final hasDokumentasi = validasi['detail']?['has_foto_check_in'] == true ||
          validasi['detail']?['has_foto_check_out'] == true;

      await showDialog(
        context: context,
        builder: (ctx) => _buildValidationDialog(item, validasi, isTerlambat, hasAlasanKeterlambatan, hasDokumentasi),
      );
      return;
    }

    final isTerlambat = item.absensiStatus == 'selesai_terlambat';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmPaymentDialog(item, isTerlambat),
    );

    if (confirm != true || !mounted) return;
    setState(() => _isLoading = true);
    final result = await _reportService.tandaiSudahDibayar(
      laporanId: item.id,
      adminId: user.uid,
      adminName: user.displayName ?? 'Superadmin',
    );
    if (mounted) {
      _showSnackBar(
        result['success'] == true
            ? '✅ Pembayaran kepada ${item.namaMitra} telah diproses'
            : '❌ ${result['message']}',
        isError: result['success'] != true,
      );
      if (result['success'] == true) _startStream();
    }
  }

  Widget _buildValidationDialog(LaporanItem item, Map<String, dynamic> validasi, 
      bool isTerlambat, bool hasAlasanKeterlambatan, bool hasDokumentasi) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PGEColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: PGEColors.danger, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '⚠️ Belum Bisa Dibayar',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: PGEColors.textPrimary),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [PGEColors.warning.withOpacity(0.1), PGEColors.warning.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PGEColors.warning.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: PGEColors.primaryLight,
                        child: Text(
                          (item.namaMitra ?? 'U').substring(0, 1).toUpperCase(),
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: PGEColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.namaMitra ?? "Unknown",
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: PGEColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.biayaFormatted,
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: PGEColors.primary),
                  ),
                  if (isTerlambat) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: PGEColors.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: PGEColors.warning.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 14, color: PGEColors.warning),
                          const SizedBox(width: 4),
                          Text(
                            'Terlambat - Syarat khusus berlaku',
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: PGEColors.warning),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PGEColors.info.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PGEColors.info.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: PGEColors.info),
                      const SizedBox(width: 6),
                      Text(
                        isTerlambat ? 'Syarat Lembur Terlambat' : 'Persyaratan yang Belum Terpenuhi',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: PGEColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isTerlambat) ...[
                    _buildSyaratRow('Dokumentasi/Bukti', hasDokumentasi),
                    _buildSyaratRow('Alasan Keterlambatan', hasAlasanKeterlambatan),
                    if (!hasDokumentasi || !hasAlasanKeterlambatan) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: PGEColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '💡 Untuk lembur terlambat, tidak diperlukan dokumentasi check-in/check-out. '
                          'Cukup unggah bukti/dokumentasi dan berikan alasan keterlambatan.',
                          style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.info, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ] else ...[
                    ...((validasi['syarat_kurang'] as List<dynamic>?)?.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: PGEColors.danger.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 12, color: PGEColors.danger),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.toString(),
                              style: GoogleFonts.poppins(fontSize: 11, color: PGEColors.danger, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )) ?? []),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Mengerti', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildConfirmPaymentDialog(LaporanItem item, bool isTerlambat) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [PGEColors.success.withOpacity(0.2), PGEColors.success.withOpacity(0.1)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments_rounded, color: PGEColors.success, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            'Konfirmasi Pembayaran',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: PGEColors.textPrimary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PGEColors.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PGEColors.success.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: PGEColors.success),
                  const SizedBox(width: 6),
                  Text(
                    isTerlambat ? 'Syarat terlambat terpenuhi ✅' : 'Semua persyaratan terpenuhi ✅',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: PGEColors.success),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PGEColors.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PGEColors.border),
              ),
              child: Column(
                children: [
                  _buildConfirmRow('👤 Mitra', item.namaMitra ?? '-'),
                  _buildConfirmRow('📅 Tanggal', item.tanggalFormatted),
                  _buildConfirmRow('⏰ Jam Lembur', '${item.jamMulai} - ${item.jamSelesai}'),
                  _buildConfirmRow('⏱️ Durasi', item.durasiFormatted),
                  if (isTerlambat) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PGEColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PGEColors.warning.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, size: 14, color: PGEColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Lembur TERLAMBAT - Tanpa check-in/out',
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: PGEColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 20),
                  _buildConfirmRow('💰 Pendapatan', item.biayaFormatted, isHighlight: true),
                  _buildConfirmRow('📈 Rate/Jam', item.ratePerJamFormatted),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Batal', style: GoogleFonts.poppins(fontSize: 13)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('✅ Tandai Dibayar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: PGEColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildSyaratRow(String label, bool terpenuhi) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: terpenuhi ? PGEColors.success.withOpacity(0.1) : PGEColors.danger.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              terpenuhi ? Icons.check_circle : Icons.cancel,
              size: 14,
              color: terpenuhi ? PGEColors.success : PGEColors.danger,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: terpenuhi ? PGEColors.success : PGEColors.danger,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: terpenuhi ? PGEColors.success.withOpacity(0.1) : PGEColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              terpenuhi ? '✅' : '❌',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _batalkanPembayaran(LaporanItem item) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PGEColors.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.undo_rounded, color: PGEColors.danger, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              'Batalkan Pembayaran',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: PGEColors.textPrimary),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PGEColors.bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildConfirmRow('👤 Mitra', item.namaMitra ?? '-'),
              _buildConfirmRow('💰 Pendapatan', item.biayaFormatted, isHighlight: true),
              if (item.paidByName != null) _buildConfirmRow('👨‍💼 Dibayar oleh', item.paidByName!),
              if (item.paidAt != null)
                _buildConfirmRow('📅 Tgl Bayar', DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(item.paidAt!)),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Tidak', style: GoogleFonts.poppins(fontSize: 13)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Batalkan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PGEColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _isLoading = true);
    final result = await _reportService.batalkanPembayaran(
      laporanId: item.id,
      adminId: user.uid,
    );
    if (mounted) {
      _showSnackBar(
        result['success'] == true ? '✅ Tanda pembayaran telah dibatalkan' : '❌ ${result['message']}',
        isError: result['success'] != true,
      );
      if (result['success'] == true) _startStream();
    }
  }

  Future<void> _tandaiSemuaDibayar() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Memeriksa persyaratan...',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: PGEColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mohon tunggu sebentar',
                  style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.textHint),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    int memenuhiSyarat = 0;
    int tidakMemenuhi = 0;
    int terlambatCount = 0;
    final List<String> masalahList = [];

    for (final item in _items.where((i) => !i.isPaid)) {
      final validasi = await _reportService.validasiPembayaran(item.id);
      if (validasi['valid'] == true) {
        memenuhiSyarat++;
        if (item.absensiStatus == 'selesai_terlambat') terlambatCount++;
      } else {
        tidakMemenuhi++;
        if (masalahList.length < 5) {
          masalahList.add('${item.namaMitra}: ${(validasi['syarat_kurang'] as List?)?.join(", ") ?? "tidak memenuhi syarat"}');
        }
      }
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (memenuhiSyarat == 0) {
      await _showNoEligibleDialog(masalahList);
      return;
    }

    final confirm = await _showBatchConfirmDialog(memenuhiSyarat, tidakMemenuhi, terlambatCount);
    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    final result = await _reportService.tandaiSemuaDibayar(
      adminId: user.uid,
      adminName: user.displayName ?? 'Superadmin',
      bulan: _selectedBulan,
    );
    if (mounted) {
      _showSnackBar(result['message'] ?? '', isError: result['success'] != true);
      _startStream();
    }
  }

  Future<void> _showNoEligibleDialog(List<String> masalahList) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PGEColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: PGEColors.danger, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '⚠️ Tidak Ada yang Memenuhi Syarat',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PGEColors.info.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PGEColors.info.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Syarat Pembayaran:',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: PGEColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoBullet('Lembur NORMAL: Status disetujui, check-in & check-out lengkap, foto bukti'),
                    _buildInfoBullet('Lembur TERLAMBAT: Dokumentasi/bukti & alasan keterlambatan'),
                  ],
                ),
              ),
              if (masalahList.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...masalahList.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, size: 14, color: PGEColors.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(m, style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.danger)),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Mengerti', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12, color: PGEColors.info)),
          Expanded(
            child: Text(text, style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showBatchConfirmDialog(int memenuhiSyarat, int tidakMemenuhi, int terlambatCount) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [PGEColors.success.withOpacity(0.2), PGEColors.success.withOpacity(0.1)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: PGEColors.success, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              '✅ Tandai Semua Dibayar',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PGEColors.bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tandai laporan yang MEMENUHI SYARAT sebagai sudah dibayar?',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: PGEColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildBatchStatRow('📊 Memenuhi syarat', '$memenuhiSyarat laporan', PGEColors.success),
              if (terlambatCount > 0)
                _buildBatchStatRow('⏰ Termasuk terlambat', '$terlambatCount laporan', PGEColors.warning),
              _buildBatchStatRow('⚠️ Tidak memenuhi', '$tidakMemenuhi laporan (akan dilewati)', PGEColors.danger),
              _buildBatchStatRow('📅 Periode', ReportService.formatBulanLabel(_selectedBulan), PGEColors.info),
              _buildBatchStatRow(
                '💰 Estimasi dibayar',
                ReportService.formatRupiah(
                  _items.where((i) => !i.isPaid && i.memenuhiSyaratBayar).fold<double>(0, (s, i) => s + i.biayaAktual),
                ),
                PGEColors.primary,
              ),
              if (tidakMemenuhi > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PGEColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: PGEColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$tidakMemenuhi laporan akan DILEWATI',
                          style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Batal', style: GoogleFonts.poppins(fontSize: 13)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle, size: 18),
            label: Text('Bayar $memenuhiSyarat Laporan', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: PGEColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.poppins(fontSize: 11, color: PGEColors.textSecondary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 11, color: PGEColors.textHint)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: isHighlight ? 16 : 12,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                color: isHighlight ? PGEColors.success : PGEColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoPreview(String? imageUrl, String title) {
    if (imageUrl == null || imageUrl.isEmpty) {
      _showSnackBar('Foto tidak tersedia', isError: true);
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(title, style: GoogleFonts.poppins(fontSize: 14)),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: Hero(
              tag: 'photo_${imageUrl.hashCode}',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white54, size: 48),
                        SizedBox(height: 8),
                        Text('Gagal memuat gambar', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 📄 EXPORT PDF - ENHANCED
  // ═══════════════════════════════════════════════════

  Future<void> _exportPDF() async {
    setState(() => _isExporting = true);
    try {
      final pdf = pw.Document();
      final items = _filteredItems;
      final groupedItems = <String, List<LaporanItem>>{};
      for (final item in items) {
        final dateKey = DateFormat('yyyy-MM-dd').format(item.tanggal);
        groupedItems.putIfAbsent(dateKey, () => []).add(item);
      }
      final sortedDates = groupedItems.keys.toList()..sort();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        header: (context) => _buildPdfHeader(context),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          _buildPdfTitleSection(),
          pw.SizedBox(height: 16),
          _buildPdfFilterInfo(),
          pw.SizedBox(height: 12),
          _buildPdfSummaryBox(items),
          pw.SizedBox(height: 20),
          for (final date in sortedDates) ...[
            _buildPdfDateHeader(date, groupedItems[date]!),
            _buildPdfDetailTable(groupedItems[date]!),
            pw.SizedBox(height: 12),
          ],
          pw.SizedBox(height: 10),
          _buildPdfSignatureSection(),
        ],
      ));

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Laporan_Lembur_PGE_Kamojang_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
      if (mounted) _showSnackBar('✅ PDF laporan siap dibagikan');
    } catch (e) {
      if (mounted) _showSnackBar('Gagal export: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.Widget _buildPdfHeader(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blue900, width: 2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 55,
            height: 55,
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [PdfColors.blue900, PdfColors.blue700],
              ),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Center(
              child: pw.Text(
                'PGE',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PT PERTAMINA GEOTHERMAL ENERGY',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  'AREA KAMOJANG',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'LAPORAN LEMBUR & PENDAPATAN MITRA',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.blue200),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'Kode: FRM-PGE-KMJ-001',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Rev: 01',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Dicetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          ),
          pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          ),
          pw.Text(
            'Confidential - PGE Kamojang',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTitleSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.blue50, PdfColors.blue100],
        ),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RINGKASAN LAPORAN',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(child: _pdfInfoItem('Periode', ReportService.formatBulanLabel(_selectedBulan))),
              pw.Expanded(child: _pdfInfoItem('Total Laporan', '${_items.length}')),
              pw.Expanded(
                child: _pdfInfoItem(
                  'Status',
                  _selectedStatus == 'semua' ? 'Semua' : _selectedStatus,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfInfoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfFilterInfo() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey200),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Filter: ${_selectedStatus} | ${_selectedAbsensi}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Dibuat oleh: ${widget.userName ?? "System"}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummaryBox(List<LaporanItem> items) {
    final totalPendapatan = items.fold<double>(0, (sum, item) => sum + item.biayaAktual);
    final totalJam = items.fold<double>(0, (sum, item) => sum + item.totalJam);
    final sudahDibayar = items.where((i) => i.isPaid).length;
    final belumDibayar = items.where((i) => !i.isPaid).length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(colors: [PdfColors.blue800, PdfColors.blue900]),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _pdfSummaryItem('Total Pendapatan', ReportService.formatRupiah(totalPendapatan), PdfColors.orange200),
          _pdfSummaryItem('Total Jam', totalJam.toStringAsFixed(1), PdfColors.blue100),
          _pdfSummaryItem('Sudah Dibayar', '$sudahDibayar', PdfColors.green200),
          _pdfSummaryItem('Belum Dibayar', '$belumDibayar', PdfColors.yellow200),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        ),
        pw.SizedBox(height: 3),
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: color)),
      ],
    );
  }

  pw.Widget _buildPdfDateHeader(String dateKey, List<LaporanItem> items) {
    final date = DateFormat('yyyy-MM-dd').parse(dateKey);
    final formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          pw.Icon(pw.IconData(0xe610), size: 14, color: PdfColors.blue900),
          pw.SizedBox(width: 8),
          pw.Text(
            formattedDate,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
          pw.Spacer(),
          pw.Text(
            '${items.length} laporan',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.blue700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfDetailTable(List<LaporanItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(20),
        1: pw.FixedColumnWidth(60),
        2: pw.FixedColumnWidth(38),
        3: pw.FixedColumnWidth(38),
        4: pw.FixedColumnWidth(48),
        5: pw.FixedColumnWidth(48),
        6: pw.FixedColumnWidth(48),
        7: pw.FixedColumnWidth(24),
        8: pw.FixedColumnWidth(24),
        9: pw.FixedColumnWidth(32),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue200),
          children: [
            _pdfTblHdr('No'),
            _pdfTblHdr('Nama Mitra'),
            _pdfTblHdr('Jam'),
            _pdfTblHdr('Durasi'),
            _pdfTblHdr('Check-In'),
            _pdfTblHdr('Check-Out'),
            _pdfTblHdr('Pendapatan'),
            _pdfTblHdr('Foto'),
            _pdfTblHdr('Bayar'),
            _pdfTblHdr('Status'),
          ],
        ),
        ...items.asMap().entries.map((e) {
          final i = e.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: e.key.isEven ? PdfColors.white : PdfColors.grey100),
            children: [
              _pdfTblCell('${e.key + 1}', align: pw.TextAlign.center),
              _pdfTblCell(i.namaMitra ?? '-'),
              _pdfTblCell('${i.jamMulai}-${i.jamSelesai}', fontSize: 6),
              _pdfTblCell(i.totalJam.toStringAsFixed(1), align: pw.TextAlign.center),
              _pdfTblCell(i.checkInFormatted, align: pw.TextAlign.center),
              _pdfTblCell(i.checkOutFormatted, align: pw.TextAlign.center),
              _pdfTblCell(i.biayaFormatted),
              _pdfTblCell(
                (i.checkInFotoUrl != null && i.checkInFotoUrl!.isNotEmpty) ? '✓' : '-',
                align: pw.TextAlign.center,
                color: PdfColors.green700,
              ),
              _pdfTblCell(
                i.isPaid ? '✅' : '❌',
                align: pw.TextAlign.center,
                color: i.isPaid ? PdfColors.green700 : PdfColors.red700,
              ),
              _pdfTblCell(i.statusLabel, align: pw.TextAlign.center, fontSize: 6),
            ],
          );
        }),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _pdfTblCell('', colSpan: 3),
            _pdfTblCell('Subtotal', fontWeight: pw.FontWeight.bold),
            _pdfTblCell('', colSpan: 2),
            _pdfTblCell(
              ReportService.formatRupiah(items.fold<double>(0, (sum, item) => sum + item.biayaAktual)),
              fontWeight: pw.FontWeight.bold,
            ),
            _pdfTblCell('', colSpan: 3),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfTblHdr(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
      textAlign: pw.TextAlign.center,
      maxLines: 1,
      overflow: pw.TextOverflow.clip,
    ),
  );

  pw.Widget _pdfTblCell(String text, {
    pw.TextAlign? align,
    pw.FontWeight? fontWeight,
    double fontSize = 7,
    PdfColor? color,
    int colSpan = 1,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight ?? pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
        textAlign: align ?? pw.TextAlign.left,
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  pw.Widget _buildPdfSignatureSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 30),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildPdfSignatureBox('Disiapkan oleh,', widget.userName ?? 'Superadmin', 'Superadmin / Admin'),
          _buildPdfSignatureBox('Diperiksa oleh,', '(...........................)', 'Supervisor'),
          _buildPdfSignatureBox('Disetujui oleh,', '(...........................)', 'Manager'),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSignatureBox(String label, String name, String position) {
    return pw.Container(
      width: 150,
      child: pw.Column(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 40),
          pw.Container(
            width: 120,
            child: pw.Divider(color: PdfColors.black, thickness: 0.5),
          ),
          pw.SizedBox(height: 4),
          pw.Text(name, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          pw.Text(position, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 🔥🔥🔥 UI BUILD - V7 ULTIMATE MOBILE UI
  // ═══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PGEColors.bg,
      appBar: _buildAppBar(),
      // ═══════════════════════════════════════════════════
      // ✅ BOTTOM NAVIGATION BAR DITAMBAHKAN
      // ═══════════════════════════════════════════════════
      bottomNavigationBar: (widget.userRole.isNotEmpty || _actualUserRole.isNotEmpty)
          ? AppBottomNav(
              userRole: widget.userRole.isNotEmpty ? widget.userRole : _actualUserRole,
              currentIndex: _getNavIndex(),
            )
          : null,
      body: _isLoadingRole
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: PGEColors.primary),
                  SizedBox(height: 12),
                  Text('Memuat data pengguna...', style: TextStyle(fontSize: 12, color: PGEColors.textSecondary)),
                ],
              ),
            )
          : _isExporting
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(color: PGEColors.primary, strokeWidth: 3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Menyusun Laporan PDF...',
                        style: GoogleFonts.poppins(fontSize: 13, color: PGEColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PGE Kamojang - Laporan Lembur & Pendapatan',
                        style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.textHint),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildHeaderSummary(),
                    if (_showSearchBar) _buildSearchBar(),
                    _buildFilterSection(),
                    Expanded(child: _buildContent()),
                  ],
                ),
      floatingActionButton: _buildDynamicFAB(),
      // ⬇️ HAPUS bottomNavigationBar: _buildBottomBar() yang lama
    );
  }

Widget _buildHeaderSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [PGEColors.primary, PGEColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: PGEColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Total Pendapatan',
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _selectedBulan == 'semua' ? 'Semua' : ReportService.formatBulanLabel(_selectedBulan),
                          style: GoogleFonts.poppins(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ReportService.formatRupiah(_totalPendapatanDibayar),
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildHeaderStat('${_items.length}', 'Laporan'),
            const SizedBox(width: 6),
            _buildHeaderStat(_totalJamSelesai.toStringAsFixed(1), 'Jam'),
          ],
        ),
      ),
    );
  }

  // PERBAIKAN: Ganti bagian _buildHeaderStat yang bermasalah
Widget _buildHeaderStat(String value, String label) {
    // HAPUS WRAP DAN FLEXIBLE, gunakan Column langsung
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14, 
                fontWeight: FontWeight.w700, 
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9, 
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: PGEColors.surface,
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          setState(() => _searchQuery = v);
          _startStream();
        },
        autofocus: true,
        style: GoogleFonts.poppins(fontSize: 13),
        decoration: InputDecoration(
          hintText: '🔍 Cari mitra, pengawas, atau fungsi...',
          hintStyle: GoogleFonts.poppins(fontSize: 12, color: PGEColors.textHint),
          filled: true,
          fillColor: PGEColors.bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: PGEColors.primary.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: PGEColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: PGEColors.primary, width: 1.5),
          ),
          prefixIcon: const Icon(Icons.search, color: PGEColors.textHint, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _startStream();
                  },
                )
              : null,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      // PERBAIKAN: Gunakan title dengan Flexible dan hilangkan Row yang terlalu sempit
      title: Text(
        '📊 Laporan Lembur',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, 
          fontSize: 15,
          color: Colors.white,
        ),
        overflow: TextOverflow.ellipsis, // Ini mencegah pemotongan paksa
      ),
      backgroundColor: PGEColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0, // Beri ruang lebih untuk title
      leading: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.volcano, size: 16, color: Colors.white),
      ),
      actions: [
        if (_isSuperadmin && _hasBisaDibayar)
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.payments_rounded, size: 20),
                tooltip: 'Kelola Pembayaran ($_bisaDibayarCount bisa dibayar)',
                onPressed: () {
                  _tabController.animateTo(3);
                  setState(() => _selectedTabIndex = 3);
                },
              ),
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: PGEColors.danger,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    '$_bisaDibayarCount',
                    style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        IconButton(
          icon: Icon(_showSearchBar ? Icons.search_off : Icons.search, size: 20),
          tooltip: 'Cari',
          onPressed: () {
            setState(() {
              _showSearchBar = !_showSearchBar;
              if (!_showSearchBar) {
                _searchController.clear();
                _searchQuery = '';
                _startStream();
              }
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
          tooltip: 'Export PDF',
          onPressed: _isExporting ? null : _exportPDF,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (!_isSuperadmin || !_hasBisaDibayar) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PGEColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: PGEColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions, size: 16, color: PGEColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      '$_bisaDibayarCount siap dibayar',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: PGEColors.warning),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _tandaiSemuaDibayar,
              icon: const Icon(Icons.check_circle, size: 16),
              label: Text(
                'Bayar Semua',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PGEColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildDynamicFAB() {
    if (!_isSuperadmin || !_hasBisaDibayar) return null;

    return FloatingActionButton.extended(
      onPressed: () {
        _tabController.animateTo(3);
        setState(() => _selectedTabIndex = 3);
      },
      icon: const Icon(Icons.payments_rounded, size: 18),
      label: Text(
        'Bayar ($_bisaDibayarCount)',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
      ),
      backgroundColor: PGEColors.secondary,
      foregroundColor: Colors.white,
      elevation: 6,
      heroTag: 'btn_bayar_lembur',
    );
  }

  // ═══════════════════════════════════════════════════
  // FILTER SECTION - ENHANCED
  // ═══════════════════════════════════════════════════

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: PGEColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildFilterTab(
                'Periode',
                ReportService.formatBulanLabel(_selectedBulan),
                Icons.calendar_month_rounded,
                _selectedBulan != 'semua',
                PGEColors.primary,
                _showBulanPicker,
              ),
              const SizedBox(width: 8),
              _buildFilterTab(
                'Status',
                _selectedStatus == 'semua' ? 'Semua' : _selectedStatus,
                Icons.filter_list_rounded,
                _selectedStatus != 'semua',
                PGEColors.info,
                _showStatusPicker,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFilterTab(
                'Absensi',
                _selectedAbsensi == 'semua' ? 'Semua' : _selectedAbsensi.replaceAll('_', ' '),
                Icons.fingerprint,
                _selectedAbsensi != 'semua',
                PGEColors.geothermal,
                _showAbsensiPicker,
              ),
              const SizedBox(width: 8),
              if (_isSuperadmin)
                _buildFilterTab(
                  'Bayar',
                  _selectedPaidFilter == null
                      ? 'Semua'
                      : _selectedPaidFilter == 'true'
                          ? '✅ Sudah'
                          : '💰 Belum',
                  Icons.payments_rounded,
                  _selectedPaidFilter != null,
                  _selectedPaidFilter == 'true' ? PGEColors.success : PGEColors.warning,
                  _showPaidPicker,
                )
              else
                const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(
    String label,
    String value,
    IconData icon,
    bool isActive,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.08) : PGEColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color.withOpacity(0.5) : PGEColors.border,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isActive ? color : PGEColors.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(fontSize: 9, color: PGEColors.textHint),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive ? color : PGEColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 16, color: isActive ? color : PGEColors.textHint),
            ],
          ),
        ),
      ),
    );
  }

  void _showBulanPicker() => _showPicker(
        'Pilih Periode Bulan',
        _bulanOptions,
        _selectedBulan,
        formatLabel: ReportService.formatBulanLabel,
        onSelected: (v) {
          setState(() => _selectedBulan = v!);
          _startStream();
        },
      );

  void _showStatusPicker() => _showPicker(
        'Filter Status Laporan',
        ['semua', 'pending', 'disetujui', 'selesai', 'ditolak', 'dibatalkan'],
        _selectedStatus,
        onSelected: (v) {
          setState(() => _selectedStatus = v!);
          _startStream();
        },
      );

  void _showAbsensiPicker() => _showPicker(
        'Filter Status Absensi',
        ['semua', 'selesai', 'selesai_terlambat', 'check_in', 'belum_absen', 'tidak_lembur', 'expired'],
        _selectedAbsensi,
        onSelected: (v) {
          setState(() => _selectedAbsensi = v!);
          _startStream();
        },
      );

  void _showPaidPicker() => _showPicker(
        'Filter Status Pembayaran',
        ['semua', 'true', 'false'],
        _selectedPaidFilter ?? 'semua',
        formatLabel: (v) => v == 'true' ? '✅ Sudah Dibayar' : v == 'false' ? '💰 Belum Dibayar' : 'Semua',
        onSelected: (v) {
          setState(() => _selectedPaidFilter = v == 'semua' ? null : v);
          _startStream();
        },
      );

  void _showPicker(
    String title,
    List<String> items,
    String selected, {
    String Function(String)? formatLabel,
    required Function(String?) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PGEColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: PGEColors.textPrimary),
            ),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      onSelected(item);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatLabel?.call(item) ?? item.replaceAll('_', ' '),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: item == selected ? FontWeight.w700 : FontWeight.w400,
                                color: item == selected ? PGEColors.primary : PGEColors.textSecondary,
                              ),
                            ),
                          ),
                          if (item == selected)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: PGEColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle, color: PGEColors.primary, size: 20),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // CONTENT TABS - V7
  // ═══════════════════════════════════════════════════

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(color: PGEColors.primary, strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat data laporan...',
              style: GoogleFonts.poppins(fontSize: 13, color: PGEColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    switch (_selectedTabIndex) {
      case 0:
        return _buildDataTab();
      case 1:
        return _buildRingkasanTab();
      case 2:
        return _buildAnalyticsTab();
      case 3:
        return _buildBayarTab();
      default:
        return _buildDataTab();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: PGEColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inbox_rounded, size: 56, color: PGEColors.primary.withOpacity(0.5)),
              ),
              const SizedBox(height: 20),
              Text(
                'Tidak ada data laporan',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: PGEColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Silakan ubah filter atau periode bulan\nuntuk menampilkan data',
                style: GoogleFonts.poppins(fontSize: 12, color: PGEColors.textHint),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedBulan = 'semua';
                    _selectedStatus = 'semua';
                    _selectedAbsensi = 'semua';
                    _selectedPaidFilter = null;
                  });
                  _startStream();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Reset Filter', style: GoogleFonts.poppins(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTab() {
    return RefreshIndicator(
      onRefresh: () async => _startStream(),
      color: PGEColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _filteredItems.length,
        itemBuilder: (_, i) => _buildLemburCard(_filteredItems[i]),
      ),
    );
  }

  Widget _buildLemburCard(LaporanItem item) {
    final hasCheckInFoto = item.checkInFotoUrl != null && item.checkInFotoUrl!.isNotEmpty;
    final hasCheckOutFoto = item.checkOutFotoUrl != null && item.checkOutFotoUrl!.isNotEmpty;
    final isTerlambat = item.absensiStatus == 'selesai_terlambat';

    String formatFull(DateTime? dt) {
      if (dt == null) return '-';
      return DateFormat('dd/MM/yy HH:mm').format(dt);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: PGEColors.surface,
      child: InkWell(
        onTap: () => _showDetailSheet(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          item.statusColor.withOpacity(0.2),
                          item.statusColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.work_history_rounded, size: 20, color: item.statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.namaMitra ?? 'Unknown',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: PGEColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isTerlambat) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: PGEColors.warning.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: PGEColors.warning.withOpacity(0.4)),
                                ),
                                child: Text(
                                  'TERLAMBAT',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: PGEColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.tanggalFormatted} · ${item.jamMulai}-${item.jamSelesai}',
                          style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.textHint),
                        ),
                      ],
                    ),
                  ),
                  _buildItemPaymentButton(item),
                ],
              ),
              const SizedBox(height: 12),

              // Absensi Info
              if (!isTerlambat) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildAbsensiBox(
                        label: 'Check-In',
                        time: formatFull(item.checkInTime),
                        hasPhoto: hasCheckInFoto,
                        photoUrl: item.checkInFotoUrl,
                        color: PGEColors.success,
                        icon: Icons.login_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAbsensiBox(
                        label: 'Check-Out',
                        time: formatFull(item.checkOutTime),
                        hasPhoto: hasCheckOutFoto,
                        photoUrl: item.checkOutFotoUrl,
                        color: PGEColors.danger,
                        icon: Icons.logout_rounded,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PGEColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PGEColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.description_rounded, size: 14, color: PGEColors.warning),
                                const SizedBox(width: 4),
                                Text(
                                  'Dokumentasi',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: PGEColors.warning,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.keterlambatanAlasan ?? item.alasan ?? 'Tidak ada alasan',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: PGEColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (hasCheckInFoto || hasCheckOutFoto)
                        GestureDetector(
                          onTap: () => _showPhotoPreview(
                            item.checkInFotoUrl ?? item.checkOutFotoUrl,
                            'Dokumentasi',
                          ),
                          child: Hero(
                            tag: 'photo_${(item.checkInFotoUrl ?? item.checkOutFotoUrl).hashCode}',
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: PGEColors.warning.withOpacity(0.5)),
                                boxShadow: [
                                  BoxShadow(
                                    color: PGEColors.warning.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: CachedNetworkImage(
                                  imageUrl: (item.checkInFotoUrl ?? item.checkOutFotoUrl)!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(
                                    child: Icon(Icons.image, size: 20, color: Colors.grey),
                                  ),
                                  errorWidget: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Footer
              Row(
                children: [
                  _chip(Icons.timer_rounded, item.durasiFormatted, PGEColors.warning),
                  const SizedBox(width: 6),
                  _chip(item.absensiIcon, item.absensiLabel, item.absensiColor),
                  const SizedBox(width: 6),
                  _chip(Icons.person, item.fungsiMitra ?? '-', PGEColors.info),
                  const Spacer(),
                  Text(
                    item.biayaFormatted,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: PGEColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemPaymentButton(LaporanItem item) {
    if (!_isSuperadmin) return _buildStatusBadge(item);

    if (!item.isPaid && !item.memenuhiSyaratBayar) {
      return GestureDetector(
        onTap: () => _showSyaratDialog(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: PGEColors.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PGEColors.warning.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 14, color: PGEColors.warning),
              const SizedBox(width: 4),
              Text(
                'BELUM SYARAT',
                style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: PGEColors.warning),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => item.isPaid ? _batalkanPembayaran(item) : _tandaiDibayar(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.isPaid
                ? [PGEColors.success, PGEColors.success.withOpacity(0.8)]
                : [PGEColors.secondary, PGEColors.secondary.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (item.isPaid ? PGEColors.success : PGEColors.secondary).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.isPaid ? Icons.check_circle : Icons.payments_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              item.isPaid ? 'SUDAH' : 'BAYAR',
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showSyaratDialog(LaporanItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PGEColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber, color: PGEColors.warning, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '⚠️ Belum Memenuhi',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.namaMitra ?? '',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (item.absensiStatus == 'selesai_terlambat') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PGEColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '💡 Untuk lembur TERLAMBAT:\n'
                  '• Tidak perlu check-in & check-out\n'
                  '• Cukup dokumentasi & alasan keterlambatan',
                  style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.info),
                ),
              ),
            ],
            const SizedBox(height: 10),
            ...item.syaratBelumTerpenuhi.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: PGEColors.danger.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12, color: PGEColors.danger),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s, style: GoogleFonts.poppins(fontSize: 11))),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(LaporanItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: item.isPaid ? PGEColors.success.withOpacity(0.1) : PGEColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isPaid ? PGEColors.success.withOpacity(0.4) : PGEColors.warning.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.pembayaranIcon, size: 14, color: item.pembayaranColor),
          const SizedBox(width: 4),
          Text(
            item.isPaid ? 'Dibayar' : 'Belum',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: item.pembayaranColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsensiBox({
    required String label,
    required String time,
    required bool hasPhoto,
    required String? photoUrl,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
              ),
              const Spacer(),
              if (hasPhoto)
                GestureDetector(
                  onTap: () => _showPhotoPreview(photoUrl, 'Foto $label'),
                  child: Hero(
                    tag: 'photo_${photoUrl.hashCode}',
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: CachedNetworkImage(
                          imageUrl: photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Icon(Icons.image, size: 12, color: Colors.grey.shade400),
                          errorWidget: (_, __, ___) => Icon(Icons.broken_image, size: 10, color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Icon(Icons.no_photography, size: 14, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: PGEColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: RINGKASAN ENHANCED ───

  Widget _buildRingkasanTab() {
    final totalPendapatanDibayar = _totalPendapatanDibayar;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Ringkasan Laporan', Icons.analytics_rounded, PGEColors.primary),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _sumCard('Total Laporan', '${_items.length}', Icons.description_rounded, PGEColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _sumCard('Total Jam', '${_totalJamSelesai.toStringAsFixed(1)} jam', Icons.timer_rounded, PGEColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _sumCard(
                  'Sudah Dibayar',
                  '${_items.where((i) => i.isPaid).length}',
                  Icons.check_circle_rounded,
                  PGEColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _sumCard(
                  'Belum Dibayar',
                  '${_items.where((i) => !i.isPaid).length}',
                  Icons.pending_rounded,
                  PGEColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPendapatanCard(totalPendapatanDibayar),
          const SizedBox(height: 20),
          _buildProgressCard(),
          const SizedBox(height: 20),
          _buildSectionHeader('Distribusi Status', Icons.pie_chart_rounded, PGEColors.info),
          const SizedBox(height: 14),
          _buildStatusDistribution(),
        ],
      ),
    );
  }

  Widget _buildPendapatanCard(double totalPendapatanDibayar) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PGEColors.primary, Color(0xFF002548)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: PGEColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total Pendapatan (Sudah Dibayar)',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            ReportService.formatRupiah(totalPendapatanDibayar),
            style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _pendDetail(
                  '✅ Dibayar',
                  _items.where((i) => i.isPaid).fold<double>(0, (s, i) => s + i.biayaAktual),
                  _items.where((i) => i.isPaid).length,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _pendDetail(
                  '💰 Belum',
                  _totalPendapatanBelum,
                  _items.where((i) => !i.isPaid).length,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final progressValue = _items.isNotEmpty
        ? (_items.where((i) => i.isPaid).length / _items.length)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PGEColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PGEColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress Pembayaran',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: PGEColors.textPrimary),
              ),
              Text(
                '${(progressValue * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: PGEColors.success),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: PGEColors.warning.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(PGEColors.success),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _progressLabel('Dibayar', _items.where((i) => i.isPaid).length, PGEColors.success),
              const Spacer(),
              _progressLabel('Belum', _items.where((i) => !i.isPaid).length, PGEColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDistribution() {
    final statusCounts = <String, int>{};
    for (final item in _items) {
      statusCounts[item.statusLabel] = (statusCounts[item.statusLabel] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PGEColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PGEColors.border),
      ),
      child: Column(
        children: statusCounts.entries.map((entry) {
          final percentage = _items.isNotEmpty ? (entry.value / _items.length) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: GoogleFonts.poppins(fontSize: 11, color: PGEColors.textSecondary)),
                    Text(
                      '${entry.value} (${(percentage * 100).toStringAsFixed(1)}%)',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: PGEColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: PGEColors.border,
                    valueColor: AlwaysStoppedAnimation(_getStatusColor(entry.key)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'selesai':
        return PGEColors.success;
      case 'pending':
        return PGEColors.warning;
      case 'ditolak':
      case 'dibatalkan':
        return PGEColors.danger;
      default:
        return PGEColors.info;
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: PGEColors.textPrimary),
        ),
      ],
    );
  }

  Widget _sumCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _pendDetail(String label, double amount, int count) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70)),
        const SizedBox(height: 2),
        Text(
          ReportService.formatRupiah(amount),
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        Text('$count laporan', style: GoogleFonts.poppins(fontSize: 9, color: Colors.white60)),
      ],
    );
  }

  Widget _progressLabel(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $count laporan',
          style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.textSecondary),
        ),
      ],
    );
  }

  // ─── TAB 3: ANALYTICS TAB (NEW) ───

  Widget _buildAnalyticsTab() {
    final mitraStats = _getMitraStats();
    final dailyStats = _getDailyStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Top Mitra', Icons.leaderboard_rounded, PGEColors.secondary),
          const SizedBox(height: 14),
          ...mitraStats.take(5).toList().asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final stat = entry.value;
            return _buildTopMitraCard(rank, stat['name'] as String, stat['total'] as double, stat['count'] as int);
          }),
          const SizedBox(height: 20),
          _buildSectionHeader('Rekap Harian', Icons.calendar_view_week_rounded, PGEColors.geothermal),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PGEColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PGEColors.border),
            ),
            child: Column(
              children: dailyStats.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          entry.key,
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: PGEColors.textPrimary),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: entry.value['percentage'] as double,
                            backgroundColor: PGEColors.border,
                            valueColor: const AlwaysStoppedAnimation(PGEColors.primary),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.value['count']}',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: PGEColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getMitraStats() {
    final Map<String, Map<String, dynamic>> stats = {};
    for (final item in _items) {
      final name = item.namaMitra ?? 'Unknown';
      if (!stats.containsKey(name)) {
        stats[name] = {'name': name, 'total': 0.0, 'count': 0};
      }
      stats[name]!['total'] = (stats[name]!['total'] as double) + item.biayaAktual;
      stats[name]!['count'] = (stats[name]!['count'] as int) + 1;
    }
    final sorted = stats.values.toList()..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return sorted;
  }

  Map<String, Map<String, dynamic>> _getDailyStats() {
    final Map<String, Map<String, dynamic>> stats = {};
    final maxCount = _items.isNotEmpty
        ? _items.fold<int>(0, (max, item) {
            final count = _items.where((i) => i.tanggalFormatted == item.tanggalFormatted).length;
            return count > max ? count : max;
          })
        : 1;

    for (final item in _items) {
      final date = item.tanggalFormatted;
      if (!stats.containsKey(date)) {
        stats[date] = {'count': 0, 'percentage': 0.0};
      }
      stats[date]!['count'] = (stats[date]!['count'] as int) + 1;
      stats[date]!['percentage'] = (stats[date]!['count'] as int) / maxCount;
    }
    return stats;
  }

  Widget _buildTopMitraCard(int rank, String name, double total, int count) {
    Color rankColor;
    IconData rankIcon;
    switch (rank) {
      case 1:
        rankColor = PGEColors.gold;
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = PGEColors.silver;
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = PGEColors.bronze;
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = PGEColors.textHint;
        rankIcon = Icons.star;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PGEColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PGEColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: rank <= 3
                  ? Icon(rankIcon, size: 18, color: rankColor)
                  : Text('$rank', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: rankColor)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: PGEColors.textPrimary)),
                Text('$count laporan', style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.textHint)),
              ],
            ),
          ),
          Text(
            ReportService.formatRupiah(total),
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: PGEColors.primary),
          ),
        ],
      ),
    );
  }

  // ─── TAB 4: PEMBAYARAN ───

  Widget _buildBayarTab() {
    final sudahDikerjakan = _items.where((i) {
      final statusValid = ['disetujui', 'selesai', 'approved'].contains(i.status);
      final absensiSelesai = i.absensiStatus == 'selesai' || i.absensiStatus == 'selesai_terlambat';
      return statusValid && absensiSelesai;
    }).toList();

    final sudah = sudahDikerjakan.where((i) => i.isPaid).toList();
    final belum = sudahDikerjakan.where((i) => !i.isPaid).toList();
    final memenuhi = belum.where((i) => i.memenuhiSyaratBayar).toList();
    final tidakMemenuhi = belum.where((i) => !i.memenuhiSyaratBayar).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bayarSummary(sudah, belum),
        if (belum.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildBayarSectionHeader(
            'Belum Dibayar',
            belum.length,
            memenuhi.length,
            tidakMemenuhi.length,
          ),
          if (_isSuperadmin && memenuhi.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _tandaiSemuaDibayar,
                icon: const Icon(Icons.check_circle, size: 18),
                label: Text(
                  'Bayar ${memenuhi.length} Laporan',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PGEColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
              ),
            ),
          ],
          if (tidakMemenuhi.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PGEColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PGEColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, size: 16, color: PGEColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Belum memenuhi(${tidakMemenuhi.length})',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: PGEColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...tidakMemenuhi.map((item) => _buildLemburCard(item)),
          ],
          if (memenuhi.isNotEmpty && tidakMemenuhi.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PGEColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PGEColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: PGEColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Siap dibayar (${memenuhi.length})',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: PGEColors.success),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...memenuhi.map((item) => _buildLemburCard(item)),
        ],
        if (sudah.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PGEColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PGEColors.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: PGEColors.success, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Sudah Dibayar (${sudah.length})',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: PGEColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...sudah.map((item) => _buildLemburCard(item)),
        ],
        if (sudahDikerjakan.isEmpty) ...[
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'Belum ada lembur yang selesai dikerjakan',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: PGEColors.textHint),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildBayarSectionHeader(String title, int total, int memenuhi, int tidakMemenuhi) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PGEColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PGEColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_rounded, color: PGEColors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title ($total)',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: PGEColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildBayarStatChip('✅ $memenuhi siap', PGEColors.success),
              const SizedBox(width: 8),
              _buildBayarStatChip('⚠️ $tidakMemenuhi belum syarat', PGEColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBayarStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _bayarSummary(List<LaporanItem> sudah, List<LaporanItem> belum) {
    double fold(List<LaporanItem> list) => list.fold<double>(0, (s, i) => s + i.biayaAktual);
    final tSudah = fold(sudah);
    final tBelum = fold(belum);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PGEColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PGEColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PGEColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: PGEColors.success, size: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sudah Dibayar',
                  style: GoogleFonts.poppins(fontSize: 11, color: PGEColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  ReportService.formatRupiah(tSudah),
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: PGEColors.success),
                ),
                Text(
                  '${sudah.length} laporan',
                  style: GoogleFonts.poppins(fontSize: 9, color: PGEColors.textHint),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 80, color: PGEColors.divider),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PGEColors.warning.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pending, color: PGEColors.warning, size: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  'Belum Dibayar',
                  style: GoogleFonts.poppins(fontSize: 11, color: PGEColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  ReportService.formatRupiah(tBelum),
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: PGEColors.warning),
                ),
                Text(
                  '${belum.length} laporan',
                  style: GoogleFonts.poppins(fontSize: 9, color: PGEColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // DETAIL SHEET - ENHANCED
  // ═══════════════════════════════════════════════════

  void _showDetailSheet(LaporanItem item) {
    final isTerlambat = item.absensiStatus == 'selesai_terlambat';
    final tampilkanPendapatan = item.isPaid || item.memenuhiSyaratBayar;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: PGEColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PGEColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with avatar
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                item.statusColor.withOpacity(0.3),
                                item.statusColor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Icon(Icons.work_history_rounded, color: item.statusColor, size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.namaMitra ?? 'Unknown',
                                      style: GoogleFonts.poppins(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: PGEColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isTerlambat) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: PGEColors.warning.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'TERLAMBAT',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: PGEColors.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (!tampilkanPendapatan) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: PGEColors.danger.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'BLM SYARAT',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: PGEColors.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                item.tanggalFormatted,
                                style: GoogleFonts.poppins(fontSize: 11, color: PGEColors.textHint),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: item.statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.statusLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: item.statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // PERBAIKAN: Tambahkan SingleChildScrollView dan batasi teks yang panjang
                    // Di bagian _showDetailSheet, cari Row dengan "Belum Memenuhi Syarat"

                    // GANTI BAGIAN INI (sekitar line 2800-an):
                    if (!tampilkanPendapatan) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              PGEColors.danger.withOpacity(0.1),
                              PGEColors.warning.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PGEColors.danger.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: PGEColors.danger.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.warning_amber_rounded, color: PGEColors.danger, size: 20),
                                ),
                                const SizedBox(width: 10),
                                // PERBAIKAN: Bungkus dengan Flexible/Expanded dan batasi overflow
                                Flexible( // GANTI Expanded JADI Flexible
                                  child: Text(
                                    '⚠️ Belum Memenuhi',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: PGEColors.danger,
                                    ),
                                    maxLines: 2, // TAMBAHKAN maxLines
                                    overflow: TextOverflow.ellipsis, // TAMBAHKAN overflow
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Pendapatan belum dapat ditampilkan karena persyaratan belum terpenuhi:',
                              style: GoogleFonts.poppins(fontSize: 11, color: PGEColors.textSecondary),
                              maxLines: 3, // TAMBAHKAN maxLines
                              overflow: TextOverflow.ellipsis, // TAMBAHKAN overflow
                            ),
                            const SizedBox(height: 10),
                            ...item.syaratBelumTerpenuhi.map((syarat) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.cancel, size: 16, color: PGEColors.danger),
                                  const SizedBox(width: 8),
                                  Flexible( // GANTI Expanded JADI Flexible
                                    child: Text(
                                      syarat,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11, 
                                        fontWeight: FontWeight.w500, 
                                        color: PGEColors.danger,
                                      ),
                                      maxLines: 3, // TAMBAHKAN maxLines
                                      overflow: TextOverflow.ellipsis, // TAMBAHKAN overflow
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Info Section
                    _buildDetailSection('Informasi Lembur', [
                      _dRow('👤 Mitra', item.namaMitra ?? '-'),
                      _dRow('🏢 Fungsi', item.fungsiMitra ?? '-'),
                      _dRow('👨‍💼 Pengawas', item.namaPengawas ?? '-'),
                      _dRow('⏰ Jam', '${item.jamMulai} - ${item.jamSelesai}'),
                      _dRow('📊 Durasi', item.durasiFormatted),
                      _dRow('📋 Absensi', item.absensiLabel),
                    ]),

                    const SizedBox(height: 16),

                    // Absensi Detail
                    if (!isTerlambat) ...[
                      _buildDetailSection('Detail Absensi', [
                        _dRow('🟢 Check-In', _formatFullDateTime(item.checkInTime)),
                        _dRow('🔴 Check-Out', _formatFullDateTime(item.checkOutTime)),
                      ]),
                      if (item.checkInFotoUrl != null && item.checkInFotoUrl!.isNotEmpty)
                        _buildPhotoPreviewCard('Foto Check-In', item.checkInFotoUrl!, PGEColors.success),
                      if (item.checkOutFotoUrl != null && item.checkOutFotoUrl!.isNotEmpty)
                        _buildPhotoPreviewCard('Foto Check-Out', item.checkOutFotoUrl!, PGEColors.danger),
                    ] else ...[
                      _buildDetailSection('Info Terlambat', [
                        _dRow('📸 Dokumentasi', (item.checkInFotoUrl != null || item.checkOutFotoUrl != null) ? 'Tersedia' : 'Tidak ada'),
                        _dRow('📝 Alasan', item.keterlambatanAlasan ?? item.alasan ?? '-'),
                      ]),
                      if (item.checkInFotoUrl != null && item.checkInFotoUrl!.isNotEmpty)
                        _buildPhotoPreviewCard('Dokumentasi', item.checkInFotoUrl!, PGEColors.warning),
                    ],

                    if (tampilkanPendapatan) ...[
                      const SizedBox(height: 16),
                      _buildDetailSection('Pembayaran', [
                        _dRow('💰 Pendapatan', item.biayaFormatted),
                        _dRow('📈 Rate/Jam', item.ratePerJamFormatted),
                        _dRow('💳 Status', item.pembayaranLabel),
                        if (item.paidByName != null) _dRow('✅ Dibayar oleh', item.paidByName!),
                        if (item.paidAt != null) _dRow('📅 Tgl Bayar', _formatFullDateTime(item.paidAt)),
                      ]),
                    ],

                    _dRow('📝 Catatan', item.alasan),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: Row(
                  children: [
                    if (_isSuperadmin && (item.isPaid || item.memenuhiSyaratBayar))
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            item.isPaid ? _batalkanPembayaran(item) : _tandaiDibayar(item);
                          },
                          icon: Icon(item.pembayaranIcon, size: 18),
                          label: Text(
                            item.isPaid ? '❌ Batalkan' : '✅ Bayar',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: item.isPaid ? PGEColors.danger : PGEColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      )
                    else if (_isSuperadmin)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: PGEColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: PGEColors.warning.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 18, color: PGEColors.warning),
                              const SizedBox(width: 8),
                              Text(
                                'Belum Memenuhi',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: PGEColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_isSuperadmin && (item.isPaid || item.memenuhiSyaratBayar))
                      const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Tutup', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PGEColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PGEColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: PGEColors.textPrimary),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPhotoPreviewCard(String label, String imageUrl, Color color) {
    return GestureDetector(
      onTap: () => _showPhotoPreview(imageUrl, label),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Hero(
          tag: 'photo_${imageUrl.hashCode}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(height: 8),
                        Text('Memuat foto...', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  errorWidget: (_, __, ___) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 4),
                        Text('Foto tidak tersedia', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('Tap untuk memperbesar', style: GoogleFonts.poppins(fontSize: 9, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: PGEColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: PGEColors.textPrimary),
          ),
        ),
      ],
    ),
  );

  String _formatFullDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isError ? Icons.error_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? PGEColors.danger : PGEColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}