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
import '/widgets/bottom_nav/app_bottom_nav.dart';

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
// 📱 REPORT PAGE - PGE KAMOJANG V8 PROFESSIONAL
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
      .where((i) =>
          i.status == 'selesai' ||
          i.absensiStatus == 'selesai' ||
          i.absensiStatus == 'selesai_terlambat' ||
          i.absensiStatus == 'selesai_terlambat_checkout')
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

  int _getNavIndex() {
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
          item.absensiStatus == 'selesai_terlambat_checkout' ||
          validasi['detail']?['absensi_status'] == 'selesai_terlambat' ||
          validasi['detail']?['absensi_status'] == 'selesai_terlambat_checkout';
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

    final isTerlambat = item.absensiStatus == 'selesai_terlambat' ||
        item.absensiStatus == 'selesai_terlambat_checkout';
    final basisPembayaran = await showDialog<String>(
      context: context,
      builder: (ctx) => _buildConfirmPaymentDialog(item, isTerlambat),
    );

    if (basisPembayaran == null || !mounted) return; // user tekan Batal
    setState(() => _isLoading = true);
    final result = await _reportService.tandaiSudahDibayar(
      laporanId: item.id,
      adminId: user.uid,
      adminName: user.displayName ?? 'Superadmin',
      basisPembayaran: basisPembayaran, // 'aktual' atau 'pengajuan'
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
    final biayaAktual = item.biayaAktual;
    final biayaPengajuan = (item.ratePerJam > 0 && item.totalJam > 0)
        ? item.ratePerJam * item.totalJam
        : biayaAktual;

    String basisTerpilih = 'aktual'; // default

    return StatefulBuilder(
      builder: (context, setDialogState) {
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
              const SizedBox(height: 4),
              Text(
                item.namaMitra ?? '-',
                style: GoogleFonts.poppins(fontSize: 12, color: PGEColors.textSecondary),
              ),
              if (isTerlambat) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: PGEColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PGEColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 12, color: PGEColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        'Lembur TERLAMBAT',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: PGEColors.warning),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBasisOption(
                setDialogState: setDialogState,
                groupValue: basisTerpilih,
                value: 'aktual',
                onChanged: (v) => basisTerpilih = v,
                label: 'Sesuai Durasi Aktual',
                subtitle: 'Dari check-in/check-out (${item.durasiRealFormatted})',
                nominal: biayaAktual,
              ),
              const SizedBox(height: 8),
              _buildBasisOption(
                setDialogState: setDialogState,
                groupValue: basisTerpilih,
                value: 'pengajuan',
                onChanged: (v) => basisTerpilih = v,
                label: 'Sesuai Pengajuan',
                subtitle: 'Dari jam yang diajukan (${item.durasiFormatted})',
                nominal: biayaPengajuan,
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, null),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Batal', style: GoogleFonts.poppins(fontSize: 13)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, basisTerpilih),
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
      },
    );
  }

  // 🔥 Baris opsi radio + preview nominal untuk dialog konfirmasi bayar
  Widget _buildBasisOption({
    required StateSetter setDialogState,
    required String groupValue,
    required String value,
    required ValueChanged<String> onChanged,
    required String label,
    required String subtitle,
    required double nominal,
  }) {
    final isSelected = groupValue == value;
    return InkWell(
      onTap: () => setDialogState(() => onChanged(value)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? PGEColors.primaryLight : PGEColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? PGEColors.primary : PGEColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) => setDialogState(() => onChanged(v!)),
              activeColor: PGEColors.primary,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: PGEColors.textPrimary)),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 10, color: PGEColors.textSecondary)),
                ],
              ),
            ),
            Text(
              ReportService.formatRupiah(nominal),
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: PGEColors.primary),
            ),
          ],
        ),
      ),
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
        if (item.absensiStatus == 'selesai_terlambat' ||
            item.absensiStatus == 'selesai_terlambat_checkout') terlambatCount++;
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
  // 📄 EXPORT PDF - PROFESSIONAL PERTAMINA STYLE
  // ═══════════════════════════════════════════════════

  Future<void> _exportPDF() async {
    setState(() => _isExporting = true);
    try {
      final pdf = pw.Document();
      final items = _filteredItems;

      // Group by date
      final groupedItems = <String, List<LaporanItem>>{};
      for (final item in items) {
        final dateKey = DateFormat('yyyy-MM-dd').format(item.tanggal);
        groupedItems.putIfAbsent(dateKey, () => []).add(item);
      }
      final sortedDates = groupedItems.keys.toList()..sort();

      // Calculate totals
      final totalPendapatan = items.fold<double>(0, (sum, i) => sum + i.biayaAktual);
      final totalJam = items.fold<double>(0, (sum, i) => sum + i.totalJam);
      final sudahDibayar = items.where((i) => i.isPaid).length;
      final belumDibayar = items.where((i) => !i.isPaid).length;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => _buildPdfHeader(context),
          footer: (context) => _buildPdfFooter(context),
          build: (context) => [
            // Title Section
            _buildPdfTitle(),
            pw.SizedBox(height: 24),

            // Summary Cards
            _buildPdfSummaryCards(totalPendapatan, totalJam, sudahDibayar, belumDibayar),
            pw.SizedBox(height: 30),

            // Section: Detail Laporan
            _buildPdfSectionHeader('DETAIL LAPORAN LEMBUR'),
            pw.SizedBox(height: 12),
            _buildPdfInfoBar(),
            pw.SizedBox(height: 16),

            // Table for each date
            for (final date in sortedDates) ...[
              _buildPdfDateHeader(date, groupedItems[date]!),
              _buildPdfTable(groupedItems[date]!),
              pw.SizedBox(height: 8),
            ],

            pw.SizedBox(height: 20),

            // Grand Total
            _buildPdfGrandTotal(items),

            pw.SizedBox(height: 40),

            // Signature Section
            _buildPdfSignature(),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Laporan_Lembur_PGE_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
      if (mounted) _showSnackBar('✅ PDF laporan berhasil dibuat');
    } catch (e) {
      if (mounted) _showSnackBar('Gagal export: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ═══════════════════════════════════════════════════
  // PDF HEADER - PROFESSIONAL PERTAMINA
  // ═══════════════════════════════════════════════════

  pw.Widget _buildPdfHeader(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo PERTAMINA PGE
          pw.Container(
            width: 120,
            height: 45,
            decoration: pw.BoxDecoration(
              color: PdfColors.blue900,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: 24,
                  height: 24,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'P',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PERTAMINA',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.Text(
                      'GEOTHERMAL ENERGY',
                      style: pw.TextStyle(
                        fontSize: 5.5,
                        color: PdfColors.blue200,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          // Vertical divider
          pw.Container(
            width: 1,
            height: 35,
            color: PdfColors.grey400,
          ),
          pw.SizedBox(width: 20),
          // Company info
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'PT PERTAMINA GEOTHERMAL ENERGY Tbk',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Area Kamojang - West Java',
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          // Document info
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Doc. No: FRM-HRD-001',
                  style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Rev: 02',
                  style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PDF FOOTER
  // ═══════════════════════════════════════════════════

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Confidential - For Internal Use Only',
            style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
          ),
          pw.Row(
            children: [
              pw.Text(
                'Page ',
                style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
              ),
              pw.Text(
                '${context.pageNumber}',
                style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              ),
              pw.Text(
                ' of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
              ),
            ],
          ),
          pw.Text(
            'Printed: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PDF TITLE
  // ═══════════════════════════════════════════════════

  pw.Widget _buildPdfTitle() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.blue100, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'LAPORAN LEMBUR & PENDAPATAN MITRA',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            width: 60,
            height: 2,
            color: PdfColors.orange600,
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _pdfLabelValue('Periode', ReportService.formatBulanLabel(_selectedBulan)),
              pw.SizedBox(width: 40),
              _pdfLabelValue('Total Laporan', '${_filteredItems.length}'),
              pw.SizedBox(width: 40),
              _pdfLabelValue('Dibuat Oleh', widget.userName ?? 'System'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfLabelValue(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // PDF SUMMARY CARDS
  // ═══════════════════════════════════════════════════

  pw.Widget _buildPdfSummaryCards(double totalPendapatan, double totalJam, int sudahDibayar, int belumDibayar) {
    return pw.Row(
      children: [
        _buildSummaryCard(
          'Total Pendapatan',
          ReportService.formatRupiah(totalPendapatan),
          PdfColors.blue800,
          PdfColors.blue50,
        ),
        pw.SizedBox(width: 10),
        _buildSummaryCard(
          'Total Jam Kerja',
          '${totalJam.toStringAsFixed(1)} Jam',
          PdfColors.blue700,
          PdfColors.blue50,
        ),
        pw.SizedBox(width: 10),
        _buildSummaryCard(
          'Sudah Dibayar',
          '$sudahDibayar Laporan',
          PdfColors.green700,
          PdfColors.green50,
        ),
        pw.SizedBox(width: 10),
        _buildSummaryCard(
          'Belum Dibayar',
          '$belumDibayar Laporan',
          PdfColors.orange700,
          PdfColors.orange50,
        ),
      ],
    );
  }

  pw.Widget _buildSummaryCard(String title, String value, PdfColor textColor, PdfColor bgColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: textColor, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PDF SECTION HEADER
  // ═══════════════════════════════════════════════════

  pw.Widget _buildPdfSectionHeader(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 3,
          height: 16,
          color: PdfColors.blue800,
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // PDF INFO BAR
  // ═══════════════════════════════════════════════════

  pw.Widget _buildPdfInfoBar() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'Filter: ',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'Status: ${_selectedStatus == 'semua' ? 'All' : _selectedStatus}',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
          pw.SizedBox(width: 16),
          pw.Text(
            'Absensi: ${_selectedAbsensi == 'semua' ? 'All' : _selectedAbsensi}',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
          if (_selectedPaidFilter != null) ...[
            pw.SizedBox(width: 16),
            pw.Text(
              'Pembayaran: ${_selectedPaidFilter == 'true' ? 'Sudah Dibayar' : 'Belum Dibayar'}',
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PDF DATE HEADER
  // ═══════════════════════════════════════════════════

  pw.Widget _buildPdfDateHeader(String dateKey, List<LaporanItem> items) {
    final date = DateFormat('yyyy-MM-dd').parse(dateKey);
    final formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.biayaAktual);

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12, bottom: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            formattedDate,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Text(
            '${items.length} laporan',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.blue700),
          ),
          pw.Spacer(),
          pw.Text(
            'Subtotal: ${ReportService.formatRupiah(subtotal)}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PDF TABLE - PROFESSIONAL MINIMALIST
  // ═══════════════════════════════════════════════════

  pw.Widget _buildPdfTable(List<LaporanItem> items) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.3),
        ),
        columnWidths: const {
          0: pw.FixedColumnWidth(25),
          1: pw.FixedColumnWidth(75),
          2: pw.FixedColumnWidth(55),
          3: pw.FixedColumnWidth(40),
          4: pw.FixedColumnWidth(70),
          5: pw.FixedColumnWidth(70),
          6: pw.FixedColumnWidth(80),
          7: pw.FixedColumnWidth(55),
        },
        children: [
          // Header
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue800,
            ),
            children: [
              _pdfTableHeader('No'),
              _pdfTableHeader('Nama Mitra'),
              _pdfTableHeader('Jam Lembur'),
              _pdfTableHeader('Durasi'),
              _pdfTableHeader('Check-In'),
              _pdfTableHeader('Check-Out'),
              _pdfTableHeader('Pendapatan'),
              _pdfTableHeader('Status'),
            ],
          ),
          // Data rows
          ...items.asMap().entries.map((entry) {
            final i = entry.value;
            final isEven = entry.key.isEven;

            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: isEven ? PdfColors.white : PdfColors.grey50,
              ),
              children: [
                _pdfTableCell('${entry.key + 1}', align: pw.TextAlign.center, isBold: false),
                _pdfTableCell(i.namaMitra ?? '-', isBold: true),
                _pdfTableCell('${i.jamMulai} - ${i.jamSelesai}', fontSize: 8),
                _pdfTableCell(i.totalJam.toStringAsFixed(1), align: pw.TextAlign.center),
                _pdfTableCell(
                  i.checkInTime != null
                      ? DateFormat('HH:mm').format(i.checkInTime!)
                      : '-',
                  align: pw.TextAlign.center,
                  fontSize: 8,
                ),
                _pdfTableCell(
                  i.checkOutTime != null
                      ? DateFormat('HH:mm').format(i.checkOutTime!)
                      : '-',
                  align: pw.TextAlign.center,
                  fontSize: 8,
                ),
                _pdfTableCell(
                  i.biayaFormatted,
                  color: PdfColors.blue900,
                  isBold: true,
                  fontSize: 9,
                ),
                _pdfTableCell(
                  i.isPaid ? 'SUDAH DIBAYAR' : 'BELUM',
                  align: pw.TextAlign.center,
                  color: i.isPaid ? PdfColors.green700 : PdfColors.orange700,
                  isBold: true,
                  fontSize: 7,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _pdfTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfTableCell(
    String text, {
    pw.TextAlign? align,
    bool isBold = false,
    double fontSize = 9,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
        textAlign: align ?? pw.TextAlign.left,
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PDF GRAND TOTAL
  // ═══════════════════════════════════════════════════

  pw.Widget _buildPdfGrandTotal(List<LaporanItem> items) {
    final totalPendapatan = items.fold<double>(0, (sum, i) => sum + i.biayaAktual);
    final totalJam = items.fold<double>(0, (sum, i) => sum + i.totalJam);
    final sudahDibayar = items.where((i) => i.isPaid).length;
    final belumDibayar = items.where((i) => !i.isPaid).length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue800,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _grandTotalItem('GRAND TOTAL', ReportService.formatRupiah(totalPendapatan)),
          pw.Container(width: 1, height: 30, color: PdfColors.grey400),
          _grandTotalItem('Total Jam', '${totalJam.toStringAsFixed(1)} Jam'),
          pw.Container(width: 1, height: 30, color: PdfColors.grey400),
          _grandTotalItem('Dibayar', '$sudahDibayar'),
          pw.Container(width: 1, height: 30, color: PdfColors.grey400),
          _grandTotalItem('Belum', '$belumDibayar'),
        ],
      ),
    );
  }

  pw.Widget _grandTotalItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 7, color: PdfColors.blue100),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7, color: PdfColors.blue200),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // PDF SIGNATURE
  // ═══════════════════════════════════════════════════

  pw.Widget _buildPdfSignature() {
    final now = DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now());

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Kamojang, $now',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.black),
              ),
            ],
          ),
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signatureBox('Disiapkan Oleh,', widget.userName ?? '_________________', 'Admin / PIC'),
              _signatureBox('Diperiksa Oleh,', '_________________', 'Supervisor'),
              _signatureBox('Disetujui Oleh,', '_________________', 'Manager'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _signatureBox(String label, String name, String position) {
    return pw.Container(
      width: 140,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 40),
          pw.Container(
            width: 100,
            child: pw.Divider(color: PdfColors.black, thickness: 0.5),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            name,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            position,
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 🔥🔥🔥 UI BUILD - V8 PROFESSIONAL
  // ═══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PGEColors.bg,
      appBar: _buildAppBar(),
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

  Widget _buildHeaderStat(String value, String label) {
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
      title: Text(
        '📊 Laporan Lembur',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Colors.white,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: PGEColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
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
  // FILTER SECTION
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
        ['semua', 'selesai', 'selesai_terlambat', 'selesai_terlambat_checkout', 'check_in', 'belum_absen', 'tidak_lembur', 'expired'],
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
  // CONTENT TABS
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
    final isTerlambat = item.absensiStatus == 'selesai_terlambat' ||
        item.absensiStatus == 'selesai_terlambat_checkout';

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chip(Icons.timer_rounded, item.durasiFormatted, PGEColors.warning),
                        _chip(item.absensiIcon, item.absensiLabel, item.absensiColor),
                        _chip(Icons.person, item.fungsiMitra ?? '-', PGEColors.info),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
            if (item.absensiStatus == 'selesai_terlambat' ||
                item.absensiStatus == 'selesai_terlambat_checkout') ...[
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

  // ─── TAB 2: RINGKASAN ───

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

  // ─── TAB 3: ANALYTICS ───

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
      final absensiSelesai = i.absensiStatus == 'selesai' ||
          i.absensiStatus == 'selesai_terlambat' ||
          i.absensiStatus == 'selesai_terlambat_checkout';
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
  // DETAIL SHEET
  // ═══════════════════════════════════════════════════

  void _showDetailSheet(LaporanItem item) {
    final isTerlambat = item.absensiStatus == 'selesai_terlambat' ||
        item.absensiStatus == 'selesai_terlambat_checkout';
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              Text(
                                item.namaMitra ?? 'Unknown',
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: PGEColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.tanggalFormatted,
                                style: GoogleFonts.poppins(fontSize: 11, color: PGEColors.textHint),
                              ),
                              if (item.absensiStatus != 'selesai' || !tampilkanPendapatan) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (item.absensiStatus != 'selesai')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: item.absensiColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: item.absensiColor.withOpacity(0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(item.absensiIcon, size: 11, color: item.absensiColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.absensiLabel.replaceAll(RegExp(r'[^\x00-\x7F]'), '').trim(),
                                              style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: item.absensiColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (!tampilkanPendapatan)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: PGEColors.danger.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: PGEColors.danger.withOpacity(0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.error_outline_rounded, size: 11, color: PGEColors.danger),
                                            const SizedBox(width: 4),
                                            Text(
                                              'BELUM MEMENUHI SYARAT',
                                              style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: PGEColors.danger,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                Flexible(
                                  child: Text(
                                    '⚠️ Belum Memenuhi',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: PGEColors.danger,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Pendapatan belum dapat ditampilkan karena persyaratan belum terpenuhi:',
                              style: GoogleFonts.poppins(fontSize: 11, color: PGEColors.textSecondary),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            ...item.syaratBelumTerpenuhi.map((syarat) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.cancel, size: 16, color: PGEColors.danger),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      syarat,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: PGEColors.danger,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
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
                    _buildDetailSection('Informasi Lembur', [
                      _dRow('👤 Mitra', item.namaMitra ?? '-'),
                      _dRow('🏢 Fungsi', item.fungsiMitra ?? '-'),
                      _dRow('👨‍💼 Pengawas', item.namaPengawas ?? '-'),
                      _dRow('⏰ Jam', '${item.jamMulai} - ${item.jamSelesai}'),
                      _dRow('📊 Durasi', item.durasiFormatted),
                      _dRow('📋 Absensi', item.absensiLabel),
                    ]),
                    const SizedBox(height: 16),
                    if (item.absensiStatus == 'tidak_lembur' ||
                        item.absensiStatus == 'expired' ||
                        item.absensiStatus == 'belum_absen') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: item.absensiColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: item.absensiColor.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: item.absensiColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item.absensiIcon, color: item.absensiColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.absensiStatus == 'tidak_lembur'
                                    ? 'Mitra tidak melaksanakan lembur pada laporan ini.'
                                    : item.absensiStatus == 'expired'
                                        ? 'Waktu absensi telah kedaluwarsa sebelum diselesaikan.'
                                        : 'Mitra belum melakukan absensi untuk lembur ini.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: PGEColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (!isTerlambat) ...[
                      _buildDetailSection('Detail Absensi', [
                        _dRow('🟢 Check-In', _formatFullDateTime(item.checkInTime)),
                        _dRow('🔴 Check-Out', _formatFullDateTime(item.checkOutTime)),
                      ]),
                      if (item.checkInFotoUrl != null && item.checkInFotoUrl!.isNotEmpty)
                        _buildPhotoPreviewCard('Foto Check-In', item.checkInFotoUrl!, PGEColors.success),
                      if (item.checkOutFotoUrl != null && item.checkOutFotoUrl!.isNotEmpty)
                        _buildPhotoPreviewCard('Foto Check-Out', item.checkOutFotoUrl!, PGEColors.danger),
                    ] else ...[
                      _buildDetailSection(
                        item.absensiStatus == 'selesai_terlambat_checkout'
                            ? 'Info Terlambat Checkout'
                            : 'Info Terlambat',
                        [
                          if (item.checkInTime != null)
                            _dRow('🟢 Check-In', _formatFullDateTime(item.checkInTime)),
                          if (item.checkOutTime != null)
                            _dRow('🔴 Check-Out', _formatFullDateTime(item.checkOutTime)),
                          _dRow('📸 Dokumentasi', (item.checkInFotoUrl != null || item.checkOutFotoUrl != null) ? 'Tersedia' : 'Tidak ada'),
                          _dRow('📝 Alasan', item.keterlambatanAlasan ?? item.alasan ?? '-'),
                        ],
                      ),
                      if (item.checkInFotoUrl != null && item.checkInFotoUrl!.isNotEmpty)
                        _buildPhotoPreviewCard('Foto Check-In', item.checkInFotoUrl!, PGEColors.warning),
                      if (item.checkOutFotoUrl != null && item.checkOutFotoUrl!.isNotEmpty)
                        _buildPhotoPreviewCard('Foto Check-Out', item.checkOutFotoUrl!, PGEColors.warning),
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