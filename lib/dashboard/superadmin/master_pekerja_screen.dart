// lib/features/superadmin/master_pekerja_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/superadmin_service.dart';
import '../../widgets/bottom_nav/superadmin_bottom_nav.dart';

class MasterPekerjaScreen extends StatefulWidget {
  const MasterPekerjaScreen({super.key});

  @override
  State<MasterPekerjaScreen> createState() => _MasterPekerjaScreenState();
}

class _MasterPekerjaScreenState extends State<MasterPekerjaScreen>
    with SingleTickerProviderStateMixin {
  final DashboardService _service = DashboardService();
  final TextEditingController _searchController = TextEditingController();

  // State
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _searchQuery = '';
  String _selectedFungsi = 'Semua';
  String _selectedStatus = 'Semua';

  // Data
  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _filteredWorkers = [];
  Map<String, dynamic> _masterDataStats = {};
  List<String> _fungsiList = [];

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _searchController.addListener(_onSearch);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ==================== DATA LOADING ====================
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _service.loadMasterDataPekerja(),
        _service.getWorkersList(limit: 500),
        _service.getFungsiList(),
      ]);

      _masterDataStats = results[0] as Map<String, dynamic>;

      final workersResult = results[1] as Map<String, dynamic>;
      _workers = List<Map<String, dynamic>>.from(workersResult['workers']);

      _fungsiList = results[2] as List<String>;

      _applyFilters();
    } catch (e) {
      _showSnackBar('Gagal memuat data: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadData();
    _fadeController.reset();
    _fadeController.forward();
    if (mounted) setState(() => _isRefreshing = false);
  }

  // ==================== FILTER & SEARCH ====================
  void _onSearch() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredWorkers = _workers.where((worker) {
        final searchMatch = _searchQuery.isEmpty ||
            (worker['id_pekerja']?.toString().toLowerCase().contains(_searchQuery) == true) ||
            (worker['nama']?.toString().toLowerCase().contains(_searchQuery) == true) ||
            (worker['role']?.toString().toLowerCase().contains(_searchQuery) == true);

        final fungsiMatch = _selectedFungsi == 'Semua' ||
            worker['fungsi']?.toString() == _selectedFungsi;

        final statusMatch = _selectedStatus == 'Semua' ||
            (_selectedStatus == 'Aktif' && (worker['is_active'] == true)) ||
            (_selectedStatus == 'Non-Aktif' && (worker['is_active'] != true));

        return searchMatch && fungsiMatch && statusMatch;
      }).toList();
    });
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedFungsi != 'Semua') count++;
    if (_selectedStatus != 'Semua') count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  // ==================== SNACKBAR ====================
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_rounded : Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
            ],
          ),
          backgroundColor: isError ? Colors.red[700] : Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ==================== ADD WORKER DIALOG ====================
  void _showAddWorkerDialog() {
    final idController = TextEditingController();
    final namaController = TextEditingController();
    String selectedFungsi = 'operation';
    final roleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A5276).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_rounded, color: Color(0xFF1A5276)),
            ),
            const SizedBox(width: 12),
            Text('Tambah Pekerja', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: idController,
                  decoration: InputDecoration(
                    labelText: 'ID Pekerja *',
                    hintText: 'Contoh: P12345',
                    prefixIcon: const Icon(Icons.badge_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: namaController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap *',
                    hintText: 'Masukkan nama lengkap',
                    prefixIcon: const Icon(Icons.person_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: 'operation',
                  decoration: InputDecoration(
                    labelText: 'Fungsi',
                    prefixIcon: const Icon(Icons.work_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'operation', child: Text('Operation')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                    DropdownMenuItem(value: 'hsse', child: Text('HSSE')),
                    DropdownMenuItem(value: 'gpr', child: Text('GPR')),
                    DropdownMenuItem(value: 'bs', child: Text('Business Support')),
                  ],
                  onChanged: (v) => selectedFungsi = v ?? 'operation',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: roleController,
                  decoration: InputDecoration(
                    labelText: 'Role/Jabatan',
                    hintText: 'Contoh: Manager, Supervisor, Staff',
                    prefixIcon: const Icon(Icons.admin_panel_settings_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                try {
                  await _service.addWorker({
                    'id_pekerja': idController.text.trim(),
                    'nama': namaController.text.trim(),
                    'fungsi': selectedFungsi,
                    'role': roleController.text.trim(),
                  });
                  await _loadData();
                  _showSnackBar('Pekerja berhasil ditambahkan');
                } catch (e) {
                  _showSnackBar('Gagal: $e', isError: true);
                }
              }
            },
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Simpan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5276),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EDIT WORKER DIALOG ====================
  void _showEditWorkerDialog(Map<String, dynamic> worker) {
    final idController = TextEditingController(text: worker['id_pekerja']);
    final namaController = TextEditingController(text: worker['nama']);
    String selectedFungsi = worker['fungsi'] ?? 'operation';
    final roleController = TextEditingController(text: worker['role'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Text('Edit Pekerja', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: idController,
                  decoration: InputDecoration(
                    labelText: 'ID Pekerja *',
                    prefixIcon: const Icon(Icons.badge_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: namaController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap *',
                    prefixIcon: const Icon(Icons.person_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedFungsi,
                  decoration: InputDecoration(
                    labelText: 'Fungsi',
                    prefixIcon: const Icon(Icons.work_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'operation', child: Text('Operation')),
                    DropdownMenuItem(value: 'lab', child: Text('Laboratorium')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                    DropdownMenuItem(value: 'hsse', child: Text('HSSE')),
                    DropdownMenuItem(value: 'gpr', child: Text('GPR')),
                    DropdownMenuItem(value: 'bs', child: Text('Business Support')),
                  ],
                  onChanged: (v) => selectedFungsi = v ?? 'operation',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: roleController,
                  decoration: InputDecoration(
                    labelText: 'Role/Jabatan',
                    hintText: 'Contoh: Manager, Supervisor, Staff',
                    prefixIcon: const Icon(Icons.admin_panel_settings_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                try {
                  await _service.updateWorker(worker['id'], {
                    'id_pekerja': idController.text.trim(),
                    'nama': namaController.text.trim(),
                    'fungsi': selectedFungsi,
                    'role': roleController.text.trim(),
                  });
                  await _loadData();
                  _showSnackBar('Pekerja berhasil diupdate');
                } catch (e) {
                  _showSnackBar('Gagal: $e', isError: true);
                }
              }
            },
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DELETE CONFIRMATION ====================
  void _showDeleteConfirmation(Map<String, dynamic> worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Text('Hapus Pekerja', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus pekerja:\n\n${worker['nama']} (${worker['id_pekerja']})?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _service.deleteWorker(worker['id']);
                await _loadData();
                _showSnackBar('Pekerja berhasil dihapus');
              } catch (e) {
                _showSnackBar('Gagal: $e', isError: true);
              }
            },
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Hapus'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== IMPORT RESULT DIALOG ====================
  void _showImportResultDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result['success'] == true ? Icons.check_circle_rounded : Icons.error_rounded,
              color: result['success'] == true ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              result['success'] == true ? 'Import Berhasil' : 'Import Gagal',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultRow('Total Data', '${result['total'] ?? 0}'),
            _buildResultRow('Berhasil Import', '${result['imported'] ?? 0}', Colors.green),
            _buildResultRow('Diupdate', '${result['updated'] ?? 0}', Colors.orange),
            _buildResultRow('Gagal', '${result['failed'] ?? 0}', Colors.red),
            if (result['errors'] != null && (result['errors'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Error:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(result['errors'] as List).take(5).map((e) => Text('• $e', style: const TextStyle(fontSize: 11, color: Colors.red))),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('OK'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5276),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13)),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ],
      ),
    );
  }

  // ==================== IMPORT ====================
  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final extension = result.files.single.extension?.toLowerCase();

      List<Map<String, dynamic>> workers = [];

      if (extension == 'csv') {
        workers = await _parseCsvFile(file);
      } else {
        _showSnackBar('Hanya file CSV yang didukung', isError: true);
        return;
      }

      if (workers.isEmpty) {
        _showSnackBar('Tidak ada data yang bisa diimport', isError: true);
        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF1A5276)),
                const SizedBox(height: 16),
                Text('Mengimport ${workers.length} data...', style: GoogleFonts.poppins(fontSize: 14)),
              ],
            ),
          ),
        ),
      );

      final importResult = await _service.importWorkersBulk(workers);

      if (mounted) {
        Navigator.pop(context);
        _showImportResultDialog(importResult);
      }
    } catch (e) {
      _showSnackBar('Gagal import: $e', isError: true);
    }
  }

  Future<List<Map<String, dynamic>>> _parseCsvFile(File file) async {
    try {
      final csvString = await file.readAsString();
      final lines = csvString.split(RegExp(r'\r?\n'));
      if (lines.isEmpty) return [];

      final headers = _parseCsvLine(lines[0])
          .map((e) => e.trim().toLowerCase().replaceAll('"', ''))
          .toList();

      int idIndex = -1;
      int namaIndex = -1;
      int fungsiIndex = -1;
      int roleIndex = -1;

      for (int i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (h.contains('id') && (h.contains('pekerja') || h.contains('karyawan'))) {
          idIndex = i;
        } else if (h.contains('nama')) {
          namaIndex = i;
        } else if (h.contains('fungsi') || h.contains('divisi') || h.contains('unit')) {
          fungsiIndex = i;
        } else if (h.contains('role') || h.contains('jabatan') || h.contains('posisi') || h.contains('departemen') || h.contains('dept') || h.contains('bagian')) {
          roleIndex = i;
        }
      }

      if (idIndex == -1) idIndex = 0;
      if (namaIndex == -1) namaIndex = 1;
      if (fungsiIndex == -1) fungsiIndex = 2;
      if (roleIndex == -1) roleIndex = 3;

      List<Map<String, dynamic>> workers = [];

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final row = _parseCsvLine(line);
        if (row.length < 2) continue;

        final idPekerja = idIndex < row.length ? row[idIndex].trim().replaceAll('"', '') : '';
        final nama = namaIndex < row.length ? row[namaIndex].trim().replaceAll('"', '') : '';
        if (idPekerja.isEmpty && nama.isEmpty) continue;

        workers.add({
          'id_pekerja': idPekerja,
          'nama': nama,
          'fungsi': fungsiIndex < row.length
              ? row[fungsiIndex].trim().replaceAll('"', '').toLowerCase()
              : 'operation',
          'role': roleIndex < row.length
              ? row[roleIndex].trim().replaceAll('"', '')
              : '',
          'is_active': true,
        });
      }

      return workers;
    } catch (e) {
      _showSnackBar('Gagal parse CSV: $e', isError: true);
      return [];
    }
  }

  List<String> _parseCsvLine(String line) {
    List<String> result = [];
    StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    result.add(current.toString().trim());
    return result;
  }

  // ==================== EXPORT ====================
  Future<void> _exportToCsv() async {
    try {
      final data = await _service.exportWorkers();
      if (data.isEmpty) {
        _showSnackBar('Tidak ada data untuk diexport', isError: true);
        return;
      }

      StringBuffer csv = StringBuffer();
      csv.writeln('ID Pekerja,Nama,Fungsi,Role,Status');

      for (var row in data) {
        csv.writeln(
          '"${row['ID Pekerja'] ?? ''}",'
          '"${row['Nama'] ?? ''}",'
          '"${row['Fungsi'] ?? ''}",'
          '"${row['Role'] ?? row['Departemen'] ?? ''}",'
          '"${row['Status'] ?? ''}"',
        );
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/master_pekerja_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csv.toString());

      if (mounted) {
        _showSnackBar('✅ Data berhasil diexport!');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File: $filePath', style: const TextStyle(fontSize: 11)),
            backgroundColor: Colors.green[800],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackBar('Gagal export: $e', isError: true);
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'import',
            backgroundColor: Colors.green[700],
            onPressed: _importFromFile,
            tooltip: 'Import CSV',
            child: const Icon(Icons.upload_file_rounded, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add',
            backgroundColor: const Color(0xFF1A5276),
            onPressed: _showAddWorkerDialog,
            tooltip: 'Tambah Pekerja',
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF1A5276),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildCompactHeader(statusBarHeight),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FadeTransition(opacity: _fadeAnimation, child: _buildStatsCards()),
                  const SizedBox(height: 14),
                  _buildSearchAndFilter(),
                  const SizedBox(height: 14),
                  _buildWorkerList(),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SuperAdminBottomNav(currentIndex: 2),
    );
  }

  // ==================== HEADER - COMPACT / MINIMALIS ====================
  Widget _buildCompactHeader(double statusBarHeight) {
    final activeWorkers = _masterDataStats['activeWorkers'] ?? 0;
    final inactiveWorkers = _masterDataStats['inactiveWorkers'] ?? 0;

    return SliverAppBar(
      pinned: true,
      snap: false,
      floating: false,
      expandedHeight: 0,
      toolbarHeight: 64,
      backgroundColor: const Color(0xFF0D3B5C),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
        onPressed: () => context.pop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.badge_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Master Pekerja',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  _buildStatusDot(Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '$activeWorkers aktif',
                    style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusDot(Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '$inactiveWorkers non-aktif',
                    style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        _buildHeaderActionButton(
          icon: _isRefreshing ? null : Icons.refresh_rounded,
          widget: _isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : null,
          onPressed: _isRefreshing ? null : _refreshData,
        ),
        _buildHeaderActionButton(
          icon: Icons.download_rounded,
          onPressed: _exportToCsv,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildStatusDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    IconData? icon,
    Widget? widget,
    VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: widget ??
            Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        splashRadius: 20,
        tooltip: icon == Icons.refresh_rounded ? 'Refresh' : 'Export CSV',
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== STATS CARDS ====================
  Widget _buildStatsCards() {
    final total = _masterDataStats['totalWorkers'] ?? 0;
    final active = _masterDataStats['activeWorkers'] ?? 0;
    final inactive = _masterDataStats['inactiveWorkers'] ?? 0;
    final fungsiCount = _masterDataStats['workerFungsiCount'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.people_rounded,
            label: 'Total',
            value: '$total',
            color: const Color(0xFF1A5276),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_rounded,
            label: 'Aktif',
            value: '$active',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.cancel_rounded,
            label: 'Non-Aktif',
            value: '$inactive',
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.work_rounded,
            label: 'Fungsi',
            value: '$fungsiCount',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari ID Pekerja, Nama, atau Role...',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () => _searchController.clear(),
                    )
                  : _activeFilterCount > 0
                      ? Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A5276).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_activeFilterCount',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF1A5276),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const SizedBox(width: 4),
              _buildFilterDropdown(
                value: _selectedFungsi,
                items: ['Semua', ..._fungsiList],
                onChanged: (v) {
                  setState(() => _selectedFungsi = v ?? 'Semua');
                  _applyFilters();
                },
              ),
              const SizedBox(width: 8),
              _buildFilterDropdown(
                value: _selectedStatus,
                items: const ['Semua', 'Aktif', 'Non-Aktif'],
                onChanged: (v) {
                  setState(() => _selectedStatus = v ?? 'Semua');
                  _applyFilters();
                },
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.green),
                label: Text(
                  'Import CSV',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: Colors.green[50],
                onPressed: _importFromFile,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700]),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item, style: const TextStyle(fontSize: 11)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildWorkerList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFF1A5276)),
        ),
      );
    }

    if (_filteredWorkers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.badge_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                _workers.isEmpty ? 'Belum ada data pekerja' : 'Tidak ditemukan',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _workers.isEmpty ? 'Tambahkan atau import data pekerja' : 'Coba ubah filter pencarian',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
              ),
              if (_workers.isEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _importFromFile,
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Import CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _showAddWorkerDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah Manual'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5276),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            '${_filteredWorkers.length} pekerja ditemukan',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        ..._filteredWorkers.map((worker) => _WorkerCard(
              worker: worker,
              onTap: () => _showWorkerDetail(worker),
              onEdit: () => _showEditWorkerDialog(worker),
              onDelete: () => _showDeleteConfirmation(worker),
              onToggle: () async {
                await _service.toggleWorkerStatus(
                  worker['id'],
                  !(worker['is_active'] ?? true),
                );
                await _loadData();
              },
            )),
      ],
    );
  }

  void _showWorkerDetail(Map<String, dynamic> worker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.42,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A5276).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, size: 32, color: Color(0xFF1A5276)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker['nama'] ?? '-',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          'ID: ${worker['id_pekerja'] ?? '-'}',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (worker['is_active'] ?? true) ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (worker['is_active'] ?? true) ? 'Aktif' : 'Non-Aktif',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: (worker['is_active'] ?? true) ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildDetailRow('ID Pekerja', worker['id_pekerja'] ?? '-', Icons.badge_rounded),
                  _buildDetailRow('Nama Lengkap', worker['nama'] ?? '-', Icons.person_rounded),
                  _buildDetailRow('Fungsi', worker['fungsi'] ?? '-', Icons.work_rounded),
                  _buildDetailRow('Role/Jabatan', worker['role'] ?? '-', Icons.admin_panel_settings_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ==================== STAT CARD ====================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ==================== WORKER CARD ====================
class _WorkerCard extends StatelessWidget {
  final Map<String, dynamic> worker;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _WorkerCard({
    required this.worker,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = worker['is_active'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A5276).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (worker['nama']?.toString() ?? '?')[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A5276),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker['nama'] ?? '-',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${worker['id_pekerja'] ?? '-'} • ${worker['fungsi'] ?? '-'}',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (worker['role'] != null && worker['role'].toString().isNotEmpty)
                      Text(
                        '${worker['role']}',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xFF1A5276),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: 42,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isActive ? Colors.green : Colors.grey[300],
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_rounded, size: 16, color: Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}