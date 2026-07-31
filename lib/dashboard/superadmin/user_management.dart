// lib/features/superadmin/user_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '/core/services/auth_service.dart';
import '../../core/services/superadmin_service.dart';
import '/core/utils/user_helpers.dart';
import '../../widgets/bottom_nav/superadmin_bottom_nav.dart';
import '../../widgets/user_management/user_stats_header.dart';
import '../../widgets/user_management/user_search_bar.dart';
import '../../widgets/user_management/user_filter_panel.dart';
import '../../widgets/user_management/user_card.dart';
import '../../widgets/user_management/user_detail_sheet.dart';
import '../../widgets/user_management/user_form_sheet.dart';
import '../../widgets/user_management/user_delete_dialog.dart';
import '../../widgets/user_management/user_status_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  String? _currentUserRole;
  String? _currentUserId;

  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Filter State
  String _searchQuery = '';
  String _selectedRole = 'Semua';
  String _selectedStatus = 'Semua';
  String _selectedFungsi = 'Semua';
  bool _showFilterPanel = false;

  List<Map<String, dynamic>> _availableWorkers = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    await _getCurrentUser();
    await Future.wait([
      _loadUsers(),
      _loadAvailableWorkers(),
    ]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ================= INIT =================
  Future<void> _getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      final data = await _authService.getUserById(user.uid);
      _currentUserRole = data?['role'];
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _users = await _authService.getAllUsers();
      _applyFilters();
    } catch (e) {
      _showMsg('Gagal memuat data pengguna', true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.reset();
        _animationController.forward();
      }
    }
  }

  Future<void> _loadAvailableWorkers() async {
    try {
      final result = await _dashboardService.getWorkersList(limit: 500);
      _availableWorkers = List<Map<String, dynamic>>.from(result['workers']);
    } catch (e) {
      // Silent fail
    }
  }

  Future<Map<String, dynamic>?> _validateWorkerId(String idPekerja) async {
    if (idPekerja.trim().isEmpty) return null;
    return await _dashboardService.validateWorkerId(idPekerja.trim());
  }

  // ================= PERMISSIONS =================
  bool get canAdd =>
      _currentUserRole == 'superadmin' || _currentUserRole == 'manager';
  bool get canEdit =>
      _currentUserRole == 'superadmin' || _currentUserRole == 'manager';
  bool get canDelete => _currentUserRole == 'superadmin';

  // ================= SNACKBAR =================
  void _showMsg(String msg, [bool isError = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isError ? UserHelpers.accentRed : UserHelpers.accentGreen)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError ? Icons.close_rounded : Icons.check_rounded,
                color: isError ? UserHelpers.accentRed : UserHelpers.accentGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: UserHelpers.textPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: UserHelpers.surfaceWhite,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: UserHelpers.dividerColor),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 4,
      ),
    );
  }

  // ================= FILTER LOGIC =================
  void _onSearch() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final searchMatch = _searchQuery.isEmpty ||
            (user['nama_lengkap']
                    ?.toString()
                    .toLowerCase()
                    .contains(_searchQuery) ==
                true) ||
            (user['email']?.toString().toLowerCase().contains(_searchQuery) ==
                true) ||
            (user['phone']?.toString().toLowerCase().contains(_searchQuery) ==
                true) ||
            (user['id_pekerja']
                    ?.toString()
                    .toLowerCase()
                    .contains(_searchQuery) ==
                true);

        final roleMatch =
            _selectedRole == 'Semua' || user['role'] == _selectedRole;
        final statusMatch = _selectedStatus == 'Semua' ||
            user['status_akun'] == _selectedStatus;
        final fungsiMatch = _selectedFungsi == 'Semua' ||
            user['fungsi'] == _selectedFungsi;

        return searchMatch && roleMatch && statusMatch && fungsiMatch;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedRole = 'Semua';
      _selectedStatus = 'Semua';
      _selectedFungsi = 'Semua';
      _searchController.clear();
      _searchQuery = '';
    });
    _applyFilters();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedRole != 'Semua') count++;
    if (_selectedStatus != 'Semua') count++;
    if (_selectedFungsi != 'Semua') count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  // ================= CRUD OPERATIONS =================
  Future<void> _createUser(Map<String, dynamic> data) async {
    final result = await _authService.createUser(
      nama: data['nama'],
      email: data['email'],
      phone: data['phone'],
      password: data['password'],
      role: data['role'],
      fungsi: data['fungsi'],
      idPekerja: data['id_pekerja'],
    );
    if (result.success) {
      if (mounted) context.pop();
      await _loadUsers();
      _showMsg(result.message);
    } else {
      _showMsg(result.message, true);
    }
  }

  Future<void> _updateUser(Map<String, dynamic> data) async {
    final result = await _authService.updateUser(
      userId: data['id'],
      nama: data['nama'],
      email: data['email'],
      phone: data['phone'],
      password: data['password'],
      role: data['role'],
      fungsi: data['fungsi'],
      idPekerja: data['id_pekerja'],
      sessionId: UserHelpers.generateSessionId(),
    );
    if (result.success) {
      if (mounted) context.pop();
      await _loadUsers();
      _showMsg(result.message);
    } else {
      _showMsg(result.message, true);
    }
  }

  Future<void> _deleteUser(String id, String name) async {
    final confirmed = await UserDeleteDialog.show(context, userName: name);

    if (confirmed != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: UserHelpers.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: UserHelpers.accentRed, strokeWidth: 3),
              const SizedBox(height: 16),
              Text(
                'Menghapus pengguna...',
                style: GoogleFonts.inter(
                    color: UserHelpers.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    final result = await _authService.deleteUser(
      userId: id,
      sessionId: UserHelpers.generateSessionId(),
    );

    if (mounted) context.pop();

    if (result.success) {
      setState(() {
        _users.removeWhere((user) => user['id'] == id);
        _applyFilters();
      });
      _showMsg('Data pengguna berhasil dihapus');
    } else {
      _showMsg(result.message, true);
    }
  }

  Future<void> _toggleUserStatus(
      String id, String currentStatus, String userName) async {
    final isActivating = currentStatus != 'active';

    final confirmed = await UserStatusDialog.show(
      context,
      userName: userName,
      isActivating: isActivating,
    );

    if (confirmed != true) return;

    final newStatus = isActivating ? 'active' : 'inactive';

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: UserHelpers.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: isActivating
                    ? UserHelpers.accentGreen
                    : UserHelpers.accentOrange,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                isActivating
                    ? 'Mengaktifkan pengguna...'
                    : 'Menonaktifkan pengguna...',
                style: GoogleFonts.inter(
                    color: UserHelpers.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    final result = await _authService.toggleUserStatus(
      userId: id,
      newStatus: newStatus,
      sessionId: UserHelpers.generateSessionId(),
    );

    if (mounted) context.pop();

    if (result.success) {
      setState(() {
        final index = _users.indexWhere((user) => user['id'] == id);
        if (index != -1) _users[index]['status_akun'] = newStatus;
        _applyFilters();
      });
      _showMsg(isActivating
          ? 'Akun pengguna berhasil diaktifkan'
          : 'Akun pengguna berhasil dinonaktifkan');
    } else {
      _showMsg(result.message, true);
    }
  }

  // ================= DIALOGS =================
  void _showForm({Map<String, dynamic>? user}) {
    UserFormSheet.show(
      context,
      user: user,
      availableWorkers: _availableWorkers,
      onValidateWorkerId: _validateWorkerId,
      onSubmit: user != null ? _updateUser : _createUser,
    );
  }

  void _showUserDetail(Map<String, dynamic> user) {
    UserDetailSheet.show(
      context,
      user: user,
      canEdit: canEdit,
      isCurrentUser: user['id'] == _currentUserId,
      onEdit: () => _showForm(user: user),
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final activeCount =
        _users.where((e) => e['status_akun'] == 'active').length;
    final inactiveCount =
        _users.where((e) => e['status_akun'] == 'inactive').length;
    final blockedCount =
        _users.where((e) => e['status_akun'] == 'blocked').length;

    return Scaffold(
      backgroundColor: UserHelpers.bgWhite,
      appBar: _buildAppBar(),
      floatingActionButton: canAdd ? _buildFAB() : null,
      body: Column(
        children: [
          UserStatsHeader(
            totalUsers: _users.length,
            activeCount: activeCount,
            inactiveCount: inactiveCount,
            blockedCount: blockedCount,
          ),
          UserSearchBar(
            searchController: _searchController,
            searchQuery: _searchQuery,
            activeFilterCount: _activeFilterCount,
            showFilterPanel: _showFilterPanel,
            onFilterToggle: () =>
                setState(() => _showFilterPanel = !_showFilterPanel),
            onClearSearch: () {
              _searchController.clear();
              _applyFilters();
            },
          ),
          if (_showFilterPanel)
            UserFilterPanel(
              selectedRole: _selectedRole,
              selectedStatus: _selectedStatus,
              selectedFungsi: _selectedFungsi,
              onRoleChanged: (v) {
                setState(() => _selectedRole = v);
                _applyFilters();
              },
              onStatusChanged: (v) {
                setState(() => _selectedStatus = v);
                _applyFilters();
              },
              onFungsiChanged: (v) {
                setState(() => _selectedFungsi = v);
                _applyFilters();
              },
              onReset: _resetFilters,
            ),
          Expanded(child: _buildUserList()),
        ],
      ),
      bottomNavigationBar: const SuperAdminBottomNav(currentIndex: 1),
    );
  }

  // ================= APP BAR - TANPA BACKGROUND PADA ICON BACK & RELOAD =================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      toolbarHeight: 72,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      // ============ BACK BUTTON - TANPA BACKGROUND ============
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, top: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.pop(),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
      // ============ BACKGROUND ============
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E3A8A),
              Color(0xFF3B82F6),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative elements
            Positioned(
              right: -20,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -10,
              bottom: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: 10,
              child: Row(
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.only(left: 4),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2 + (index * 0.15)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
      // ============ TITLE - ICON KELOLA PENGGUNA DENGAN BACKGROUND PERSEGI ============
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon kelola pengguna dengan background persegi
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.manage_accounts_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Teks
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kelola Pengguna',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Manajemen Akun',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w400,
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
      // ============ RELOAD BUTTON - TANPA BACKGROUND ============
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _loadUsers,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= FAB - DESAIN BARU =================
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _showForm(),
      backgroundColor: const Color(0xFF1E40AF),
      icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
      label: Text(
        'Tambah Pengguna',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFF3B82F6),
          width: 1.5,
        ),
      ),
    );
  }

  // ================= USER LIST =================
  Widget _buildUserList() {
    if (_isLoading) return _buildLoadingState();
    if (_filteredUsers.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadUsers,
      color: const Color(0xFF1E40AF),
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _filteredUsers.length,
        itemBuilder: (_, i) => FadeTransition(
          opacity: _fadeAnimation,
          child: UserCard(
            user: _filteredUsers[i],
            canEdit: canEdit,
            canDelete: canDelete,
            isCurrentUser: _filteredUsers[i]['id'] == _currentUserId,
            onTap: () => _showUserDetail(_filteredUsers[i]),
            onEdit: () => _showForm(user: _filteredUsers[i]),
            onToggleStatus: () => _toggleUserStatus(
              _filteredUsers[i]['id'],
              _filteredUsers[i]['status_akun'],
              _filteredUsers[i]['nama_lengkap'] ?? 'Pengguna',
            ),
            onDelete: () => _deleteUser(
              _filteredUsers[i]['id'],
              _filteredUsers[i]['nama_lengkap'] ?? 'Pengguna',
            ),
          ),
        ),
      ),
    );
  }

  // ================= LOADING STATE =================
  Widget _buildLoadingState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 25,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Memuat Data Pengguna',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mohon tunggu sebentar...',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= EMPTY STATE - PERBAIKAN OVERFLOW =================
  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: constraints.maxHeight * 0.05,
            bottom: constraints.maxHeight * 0.1,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ikon yang lebih kecil untuk menghemat space
                Container(
                  padding: EdgeInsets.all(
                    constraints.maxHeight < 200 ? 20 : 30,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF3B82F6).withOpacity(0.08),
                        const Color(0xFF60A5FA).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _searchQuery.isNotEmpty || _activeFilterCount > 0
                        ? Icons.search_off_rounded
                        : Icons.people_outline_rounded,
                    size: constraints.maxHeight < 200 ? 40 : 56,
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                  ),
                ),
                SizedBox(height: constraints.maxHeight < 200 ? 12 : 20),
                // Judul dengan ukuran font responsif
                Text(
                  _searchQuery.isNotEmpty || _activeFilterCount > 0
                      ? 'Tidak Ada Hasil'
                      : 'Belum Ada Pengguna',
                  style: GoogleFonts.inter(
                    fontSize: constraints.maxHeight < 200 ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: constraints.maxHeight < 200 ? 4 : 8),
                // Deskripsi
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _searchQuery.isNotEmpty || _activeFilterCount > 0
                        ? 'Coba sesuaikan kata kunci atau filter yang digunakan'
                        : 'Tambahkan pengguna baru untuk memulai manajemen akun',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: constraints.maxHeight < 200 ? 11 : 12,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_activeFilterCount > 0) ...[
                  SizedBox(height: constraints.maxHeight < 200 ? 12 : 20),
                  ElevatedButton.icon(
                    onPressed: _resetFilters,
                    icon: Icon(
                      Icons.filter_alt_off_rounded,
                      size: constraints.maxHeight < 200 ? 14 : 16,
                    ),
                    label: Text(
                      'Reset Filter',
                      style: TextStyle(
                        fontSize: constraints.maxHeight < 200 ? 11 : 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxHeight < 200 ? 14 : 18,
                        vertical: constraints.maxHeight < 200 ? 8 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}