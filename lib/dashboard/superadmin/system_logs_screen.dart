import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:go_router/go_router.dart';

// Import widget terpisah
import '../../widgets/log/log_category_tabs.dart';
import '../../widgets/log/log_filter_bar.dart';
import '../../widgets/log/log_search_bar.dart';
import '../../widgets/log/log_card.dart';
import '../../widgets/log/log_grid_card.dart';
import '../../widgets/log/log_detail_sheet.dart';
import '../../widgets/log/log_empty_state.dart';
import '../../widgets/log/log_loading_indicator.dart';
import '../../widgets/log/log_app_bar.dart';
import '../../widgets/log/log_header.dart';
import '../../widgets/bottom_nav/superadmin_bottom_nav.dart';

var logger = Logger();

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen>
    with TickerProviderStateMixin {
  
  // ==================== FIREBASE INSTANCES ====================
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ==================== USER DATA ====================
  String? _userRole;
  
  bool get isSuperadmin => _userRole == 'superadmin';
  
  // ==================== LOG DATA ====================
  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  
  // Log categories
  final Map<String, String> _logCategories = {
    'all': 'Semua',
    'system': 'Sistem',
    'user': 'User',
    'overtime': 'Lembur',
    'absensi': 'Absensi',
    'broadcast': 'Broadcast',
    'login': 'Login',
    'audit': 'Audit',
  };
  
  // Filter states
  String _selectedCategory = 'all';
  DateTimeRange? _selectedDateRange;
  String _selectedLevel = 'all';
  String _searchQuery = '';
  String _selectedUser = 'all';
  
  // ==================== UI STATE ====================
  bool isLoading = true;
  bool isDarkMode = false;
  bool isGridView = false;
  final int _itemsPerPage = 30;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  
  // Statistics
  Map<String, int> _logStats = {};
  Map<String, int> _topUsers = {};
  
  // Search debounce
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Colors
  final Color primaryBlue = const Color(0xFF1E3C72);
  final Color accentBlue = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreData();
    }
  }
  
  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _userRole = userData['role'] ?? 'mitra';
      }
      
      if (!isSuperadmin && mounted) {
        context.pop();
        _showErrorSnackbar('Akses ditolak. Hanya Superadmin yang dapat mengakses halaman ini.');
        return;
      }
      
      await _loadLogs();
      await _loadStatistics();
      
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      logger.e('Error loading user data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackbar('Gagal memuat data user');
      }
    }
  }
  
  Future<void> _loadLogs({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _allLogs.clear();
        _filteredLogs.clear();
        _lastDocument = null;
        _hasMoreData = true;
        _isLoadingMore = false;
      });
    }
    
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('system_logs');
      
      if (_selectedDateRange != null) {
        query = query
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
            .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end));
      }
      
      query = query.orderBy('timestamp', descending: true);
      
      if (_lastDocument != null && !refresh) {
        query = query.startAfterDocument(_lastDocument!);
      }
      
      final snapshot = await query.limit(_itemsPerPage).get();
      
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _hasMoreData = snapshot.docs.length >= _itemsPerPage;
        
        final newLogs = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
            'timestamp_local': (data['timestamp'] as Timestamp?)?.toDate(),
          };
        }).toList();
        
        setState(() {
          _allLogs.addAll(newLogs);
          _applyFilters();
        });
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      logger.e('Error loading logs: $e');
    }
  }
  
  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData || _lastDocument == null) return;
    setState(() => _isLoadingMore = true);
    await _loadLogs();
    if (mounted) setState(() => _isLoadingMore = false);
  }
  
  Future<void> _loadStatistics() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1);
      
      final snapshot = await _firestore
          .collection('system_logs')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfMonth))
          .get();
      
      final Map<String, int> stats = {};
      final Map<String, int> topUsers = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final type = data['type'] ?? 'unknown';
        final user = data['user'] ?? 'system';
        
        String category = _getCategoryFromType(type);
        stats[category] = (stats[category] ?? 0) + 1;
        
        if (user != 'system' && user != null && user.toString().isNotEmpty) {
          topUsers[user.toString()] = (topUsers[user] ?? 0) + 1;
        }
      }
      
      if (mounted) {
        setState(() {
          _logStats = stats;
          _topUsers = Map.fromEntries(
            topUsers.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
          );
        });
      }
    } catch (e) {
      logger.e('Error loading statistics: $e');
    }
  }
  
  String _getCategoryFromType(String type) {
    if (type.contains('user') || type.contains('login') || type.contains('logout')) return 'user';
    if (type.contains('overtime') || type.contains('lembur')) return 'overtime';
    if (type.contains('absensi')) return 'absensi';
    if (type.contains('broadcast')) return 'broadcast';
    if (type.contains('error')) return 'error';
    if (type.contains('audit')) return 'audit';
    return 'system';
  }
  
  String _getLevelFromType(String type) {
    if (type.contains('error')) return 'error';
    if (type.contains('warning')) return 'warning';
    if (type.contains('success') || type.contains('approved') || type.contains('completed')) return 'success';
    if (type.contains('debug')) return 'debug';
    return 'info';
  }
  
  void _applyFilters() {
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        if (_selectedCategory != 'all') {
          final logCategory = _getCategoryFromType(log['type'] ?? '');
          if (logCategory != _selectedCategory) return false;
        }
        
        if (_selectedLevel != 'all') {
          final logLevel = _getLevelFromType(log['type'] ?? '');
          if (logLevel != _selectedLevel) return false;
        }
        
        if (_selectedUser != 'all') {
          final logUser = log['user'] ?? 'system';
          if (logUser.toString() != _selectedUser) return false;
        }
        
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final description = (log['description'] ?? '').toString().toLowerCase();
          final user = (log['user'] ?? '').toString().toLowerCase();
          final type = (log['type'] ?? '').toString().toLowerCase();
          
          if (!description.contains(query) && !user.contains(query) && !type.contains(query)) {
            return false;
          }
        }
        
        return true;
      }).toList();
    });
  }
  
  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
      _allLogs.clear();
      _lastDocument = null;
      _hasMoreData = true;
    });
    await Future.wait([
      _loadLogs(refresh: true),
      _loadStatistics(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }
  
  // ==================== EXPORT FUNCTIONS ====================
  Future<void> _exportToExcel() async {
    try {
      _showInfoSnackbar('Menyiapkan data untuk export...');
      
      if (_filteredLogs.isEmpty) {
        _showErrorSnackbar('Tidak ada data untuk diexport');
        return;
      }
      
      var excelFile = excel.Excel.createExcel();
      var sheet = excelFile['System_Logs'];
      
      final headers = [
        'No', 'Waktu', 'Tipe', 'Level', 'User', 'User Role',
        'Target User', 'Session ID', 'Deskripsi', 'Data'
      ];
      sheet.appendRow(headers.map((h) => excel.TextCellValue(h)).toList());
      
      for (var i = 0; i < _filteredLogs.length; i++) {
        final log = _filteredLogs[i];
        final timestamp = log['timestamp_local'] as DateTime?;
        
        sheet.appendRow([
          excel.TextCellValue((i + 1).toString()),
          excel.TextCellValue(timestamp != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp) : '-'),
          excel.TextCellValue(log['type'] ?? '-'),
          excel.TextCellValue(_getLevelFromType(log['type'] ?? '')),
          excel.TextCellValue(log['user'] ?? 'system'),
          excel.TextCellValue(log['user_role'] ?? '-'),
          excel.TextCellValue(log['target_user'] ?? '-'),
          excel.TextCellValue(log['session_id'] ?? '-'),
          excel.TextCellValue(log['description'] ?? '-'),
          excel.TextCellValue(log['data'] != null ? log['data'].toString() : '-'),
        ]);
      }
      
      final dir = await getTemporaryDirectory();
      final fileName = 'System_Logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(excelFile.encode()!);
      
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Data Log Sistem',
        ),
      );
      
      _showSuccessSnackbar('File Excel berhasil dibuat');
    } catch (e) {
      _showErrorSnackbar('Gagal export ke Excel: ${e.toString()}');
    }
  }
  
  Future<void> _exportToPDF() async {
    try {
      _showInfoSnackbar('Menyiapkan PDF...');
      
      final pdf = pw.Document();
      
      pw.Font? ttf;
      pw.Font? boldTtf;
      try {
        final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        ttf = pw.Font.ttf(fontData);
        final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        boldTtf = pw.Font.ttf(boldFontData);
      } catch (e) {
        ttf = pw.Font.helvetica();
        boldTtf = pw.Font.helveticaBold();
      }
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            children: [
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Laporan Log Sistem',
                  style: pw.TextStyle(font: boldTtf, fontSize: 24),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Periode: ${_selectedDateRange != null ? "${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}" : "Semua Waktu"}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.Text(
                'Total Data: ${_filteredLogs.length}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
            ],
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: pw.TextStyle(font: ttf, fontSize: 10),
            ),
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: ['No', 'Waktu', 'Tipe', 'User', 'Deskripsi'],
              data: List.generate(_filteredLogs.length.clamp(0, 30).toInt(), (index) {
                final log = _filteredLogs[index];
                final timestamp = log['timestamp_local'] as DateTime?;
                return [
                  (index + 1).toString(),
                  timestamp != null ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp) : '-',
                  log['type'] ?? '-',
                  log['user'] ?? 'system',
                  (log['description'] ?? '').length > 50 
                      ? '${log['description'].substring(0, 50)}...' 
                      : (log['description'] ?? '-'),
                ];
              }),
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
              headerStyle: pw.TextStyle(font: boldTtf, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellHeight: 25,
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
            ),
            pw.SizedBox(height: 30),
            pw.Text('Ringkasan Statistik:', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      for (var entry in _logStats.entries.take(5))
                        pw.Text('${_logCategories[entry.key] ?? entry.key}: ${entry.value}',
                            style: pw.TextStyle(font: ttf, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      
      final dir = await getTemporaryDirectory();
      final fileName = 'System_Logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Laporan Log Sistem',
        ),
      );
      
      _showSuccessSnackbar('File PDF berhasil dibuat');
    } catch (e) {
      _showErrorSnackbar('Gagal export ke PDF: ${e.toString()}');
    }
  }
  
  Future<void> _clearOldLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Log Lama', style: GoogleFonts.poppins()),
        content: Text(
          'Anda akan menghapus semua log yang berusia lebih dari 30 hari. Tindakan ini tidak dapat dibatalkan. Lanjutkan?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Hapus', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      _showInfoSnackbar('Menghapus log lama...');
      
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await _firestore
          .collection('system_logs')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(500)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      _showSuccessSnackbar('Berhasil menghapus ${snapshot.docs.length} log lama');
      await _refreshData();
    } catch (e) {
      _showErrorSnackbar('Gagal menghapus log: $e');
    }
  }
  
  // ==================== BUILD UI ====================
  @override
  Widget build(BuildContext context) {
    if (!isSuperadmin && !isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Log Sistem')),
        body: const Center(child: Text('Akses ditolak. Hanya Superadmin.')),
      );
    }
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF5F9FF),
      appBar: _buildAppBar(),
      body: isLoading
          ? const LogLoadingIndicator(accentBlue: Color(0xFF1976D2))
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: accentBlue,
              backgroundColor: Colors.white,
              // 🔥 PERBAIKAN: Gunakan SafeArea + LayoutBuilder untuk menghindari overflow
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // 🔥 PERBAIKAN: Gunakan SliverToBoxAdapter dengan batasan ukuran
                        SliverToBoxAdapter(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: constraints.maxHeight * 0.5, // Maks 50% tinggi layar
                            ),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    LogHeader(
                                      primaryBlue: primaryBlue,
                                      totalLogs: _filteredLogs.length,
                                    ),
                                    // 🔥 PERBAIKAN: Category tabs dengan padding lebih kecil
                                    _buildCategoryTabs(),
                                    // 🔥 PERBAIKAN: Filter bar compact
                                    _buildFilterBarCompact(),
                                    // 🔥 PERBAIKAN: Search bar compact
                                    _buildSearchBarCompact(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 🔥 PERBAIKAN: Empty state atau list log
                        if (_filteredLogs.isEmpty)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: constraints.maxHeight * 0.4,
                              child: LogEmptyState(
                                accentBlue: accentBlue,
                                onRefresh: _refreshData,
                              ),
                            ),
                          )
                        else if (isGridView)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80), // 🔥 Bottom padding untuk FAB
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.85,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final log = _filteredLogs[index];
                                  return LogGridCard(
                                    log: log,
                                    getLevelFromType: _getLevelFromType,
                                    onTap: () => _showLogDetail(log),
                                  );
                                },
                                childCount: _filteredLogs.length,
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80), // 🔥 Bottom padding untuk FAB
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final log = _filteredLogs[index];
                                  return LogCard(
                                    log: log,
                                    getLevelFromType: _getLevelFromType,
                                    getCategoryFromType: _getCategoryFromType,
                                    primaryBlue: primaryBlue,
                                    onTap: () => _showLogDetail(log),
                                  );
                                },
                                childCount: _filteredLogs.length,
                              ),
                            ),
                          ),
                        // 🔥 Loading more indicator
                        if (_isLoadingMore)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                          ),
                        // 🔥 PERBAIKAN: Extra bottom padding untuk FAB
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 20),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.small( // 🔥 PERBAIKAN: Gunakan small FAB
        onPressed: _showDateRangePicker,
        backgroundColor: accentBlue,
        child: const Icon(Icons.date_range, color: Colors.white, size: 20),
      ),
      bottomNavigationBar: SuperAdminBottomNav(
        currentIndex: 2,
      ),
    );
  }
  
  // 🔥 PERBAIKAN: AppBar yang lebih compact
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryBlue,
      elevation: 0,
      title: Text(
        'Log Sistem',
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // 🔥 PERBAIKAN: PopupMenu sebagai pengganti multiple icon buttons
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
          offset: const Offset(0, 45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                _refreshData();
                break;
              case 'excel':
                _exportToExcel();
                break;
              case 'pdf':
                _exportToPDF();
                break;
              case 'clear':
                _clearOldLogs();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 10),
                  Text('Refresh', style: GoogleFonts.poppins(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'excel',
              child: Row(
                children: [
                  Icon(Icons.table_chart, size: 20, color: Colors.green[700]),
                  const SizedBox(width: 10),
                  Text('Export Excel', style: GoogleFonts.poppins(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, size: 20, color: Colors.red[700]),
                  const SizedBox(width: 10),
                  Text('Export PDF', style: GoogleFonts.poppins(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep, size: 20, color: Colors.orange[700]),
                  const SizedBox(width: 10),
                  Text('Hapus Log Lama', style: GoogleFonts.poppins(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // 🔥 PERBAIKAN: Category tabs yang lebih compact untuk mobile
  Widget _buildCategoryTabs() {
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _logCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final entry = _logCategories.entries.elementAt(index);
          final isSelected = _selectedCategory == entry.key;
          final count = _logStats[entry.key] ?? 0;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = entry.key;
                _applyFilters();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isSelected ? primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? primaryBlue : Colors.grey.shade300,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.value,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.3) : primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  // 🔥 PERBAIKAN: Filter bar compact
  Widget _buildFilterBarCompact() {
    return Container(
      height: 36,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          // Level filter
          Expanded(
            child: _buildCompactDropdown(
              value: _selectedLevel,
              hint: 'Level',
              items: {
                'all': 'Semua Level',
                'info': 'Info',
                'success': 'Success',
                'warning': 'Warning',
                'error': 'Error',
              },
              onChanged: (value) {
                setState(() {
                  _selectedLevel = value!;
                  _applyFilters();
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          // User filter
          Expanded(
            child: _buildCompactDropdown(
              value: _selectedUser,
              hint: 'User',
              items: {
                'all': 'Semua User',
                ...Map.fromEntries(
                  _topUsers.entries.take(10).map((e) => MapEntry(e.key, e.key))
                ),
              },
              onChanged: (value) {
                setState(() {
                  _selectedUser = value!;
                  _applyFilters();
                });
              },
            ),
          ),
          if (_selectedDateRange != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() => _selectedDateRange = null);
                _refreshData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, size: 14, color: Colors.red.shade400),
                    const SizedBox(width: 2),
                    Text(
                      'Reset',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // 🔥 PERBAIKAN: Dropdown compact
  Widget _buildCompactDropdown({
    required String value,
    required String hint,
    required Map<String, String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.containsKey(value) ? value : 'all',
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey.shade600),
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade800),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(8),
          items: items.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(
                entry.value,
                style: GoogleFonts.poppins(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
  
  // 🔥 PERBAIKAN: Search bar compact
  Widget _buildSearchBarCompact() {
    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (query) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 500), () {
            setState(() {
              _searchQuery = query;
              _applyFilters();
            });
          });
        },
        style: GoogleFonts.poppins(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Cari log...',
          hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.search, color: Colors.grey.shade500, size: 18),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _applyFilters();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.close, color: Colors.grey.shade500, size: 18),
                  ),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: InputBorder.none,
        ),
      ),
    );
  }
  
  void _showLogDetail(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => LogDetailSheet(
        log: log,
        getLevelFromType: _getLevelFromType,
        primaryBlue: primaryBlue,
      ),
    );
  }
  
  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      await _refreshData();
    }
  }
  
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 12))),
      ]),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }
  
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 12))),
      ]),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }
  
  void _showInfoSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 12))),
      ]),
      backgroundColor: accentBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }
}