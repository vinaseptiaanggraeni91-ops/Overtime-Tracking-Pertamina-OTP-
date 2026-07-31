// lib/features/pengawas/lembur/widgets/mitra_selection_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class MitraSelectionDialog extends StatefulWidget {
  final String fungsi;
  final List<String> selectedIds;

  const MitraSelectionDialog({
    super.key,
    required this.fungsi,
    required this.selectedIds,
  });

  @override
  State<MitraSelectionDialog> createState() => _MitraSelectionDialogState();
}

class _MitraSelectionDialogState extends State<MitraSelectionDialog>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _mitras = [];
  List<Map<String, dynamic>> _recommendedMitras = [];
  List<String> _selectedIds = [];
  bool _isLoading = true;
  bool _isLoadingRecommendations = true;
  bool _hasError = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _activeTab = 'semua';
  
  late TabController _tabController;
  final FocusNode _searchFocusNode = FocusNode();
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.selectedIds);
    _searchController = TextEditingController(text: _searchQuery);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTab = _tabController.index == 0 ? 'semua' : 'rekomendasi';
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadMitras(),
      _loadRecommendedMitras(),
    ]);
  }

  // ==================== LOAD MITRAS ====================
  Future<void> _loadMitras() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    
    try {
      Query query = _firestore
          .collection('users')
          .where('role', isEqualTo: 'mitra')
          .where('status_akun', isEqualTo: 'active');
      
      if (widget.fungsi.isNotEmpty) {
        query = query.where('fungsi', isEqualTo: widget.fungsi);
      }
      
      final snapshot = await query
          .orderBy('nama_lengkap')
          .limit(100)
          .get();

      if (!mounted) return;

      setState(() {
        _mitras = snapshot.docs.map((doc) {
          // 🔥 PERBAIKAN: Cast doc.data() to Map
          final data = Map<String, dynamic>.from(doc.data() as Map);
          return {
            'id': doc.id,
            'nama_lengkap': (data['nama_lengkap'] ?? 'Tanpa Nama').toString(),
            'fungsi': (data['fungsi'] ?? '').toString(),
            'no_hp': (data['no_hp'] ?? data['phone'] ?? '').toString(),
            'email': (data['email'] ?? '').toString(),
          };
        }).toList();
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase error loading mitras: ${e.code} - ${e.message}');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = _getFirebaseErrorMessage(e);
      });
    } catch (e) {
      debugPrint('❌ Error loading mitras: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Gagal memuat data mitra. Silakan coba lagi.';
      });
    }
  }

  // ==================== LOAD REKOMENDASI ====================
  Future<void> _loadRecommendedMitras() async {
    setState(() => _isLoadingRecommendations = true);
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() => _isLoadingRecommendations = false);
        return;
      }

      QuerySnapshot? snapshot;
      
      try {
        snapshot = await _firestore
            .collection('lembur_mitra')
            .where('pengawas_id', isEqualTo: currentUser.uid)
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();
      } catch (e) {
        debugPrint('⚠️ Gagal ambil dari lembur_mitra, coba pengajuan_lembur');
        try {
          snapshot = await _firestore
              .collection('pengajuan_lembur')
              .where('pengawas_id', isEqualTo: currentUser.uid)
              .orderBy('created_at', descending: true)
              .limit(50)
              .get();
        } catch (e2) {
          debugPrint('❌ Gagal ambil rekomendasi: $e2');
        }
      }

      if (!mounted) return;

      if (snapshot == null || snapshot.docs.isEmpty) {
        setState(() => _isLoadingRecommendations = false);
        return;
      }

      final Map<String, Map<String, dynamic>> mitraFrequency = {};

      for (var doc in snapshot.docs) {
        // 🔥 PERBAIKAN: Cast doc.data() to Map
        final data = Map<String, dynamic>.from(doc.data() as Map);
        
        final mitraId = data['mitra_id'];
        final namaMitra = data['nama_mitra'];
        
        if (mitraId != null && namaMitra != null) {
          final fungsiMitra = (data['fungsi_mitra'] ?? '').toString();
          
          if (widget.fungsi.isEmpty || fungsiMitra == widget.fungsi) {
            _addToFrequency(
              mitraFrequency, 
              mitraId.toString(), 
              namaMitra.toString(), 
              fungsiMitra,
            );
          }
        }
        
        final detailMitra = data['detail_mitra'];
        if (detailMitra is List) {
          for (var dm in detailMitra) {
            if (dm is Map) {
              final dmData = Map<String, dynamic>.from(dm);
              final dmId = dmData['id'];
              final dmNama = dmData['nama'];
              final dmFungsi = (dmData['fungsi'] ?? '').toString();
              
              if (dmId != null && dmNama != null &&
                  (widget.fungsi.isEmpty || dmFungsi == widget.fungsi)) {
                _addToFrequency(
                  mitraFrequency, 
                  dmId.toString(), 
                  dmNama.toString(), 
                  dmFungsi,
                );
              }
            }
          }
        }
      }

      List<Map<String, dynamic>> recommendations = mitraFrequency.values.toList();
      recommendations.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      if (!mounted) return;
      
      setState(() {
        _recommendedMitras = recommendations.take(10).toList();
        _isLoadingRecommendations = false;
      });
      
    } catch (e) {
      debugPrint('❌ Error loading recommended mitras: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingRecommendations = false;
        _recommendedMitras = [];
      });
    }
  }

  void _addToFrequency(
    Map<String, Map<String, dynamic>> frequency,
    String mitraId,
    String namaMitra,
    String fungsiMitra,
  ) {
    if (frequency.containsKey(mitraId)) {
      frequency[mitraId]!['count'] = (frequency[mitraId]!['count'] as int) + 1;
    } else {
      frequency[mitraId] = {
        'id': mitraId,
        'nama_lengkap': namaMitra,
        'fungsi': fungsiMitra,
        'count': 1,
      };
    }
  }

  String _getFirebaseErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Tidak memiliki akses ke data mitra.';
      case 'unavailable':
        return 'Layanan sedang tidak tersedia. Coba lagi nanti.';
      case 'deadline-exceeded':
        return 'Koneksi timeout. Periksa koneksi internet Anda.';
      default:
        return 'Terjadi kesalahan: ${e.message}';
    }
  }

  // ==================== FILTERS ====================
  List<Map<String, dynamic>> get _filteredMitras {
    if (_searchQuery.isEmpty) return _mitras;
    final query = _searchQuery.toLowerCase();
    return _mitras.where((mitra) {
      final nama = (mitra['nama_lengkap'] ?? '').toString().toLowerCase();
      final email = (mitra['email'] ?? '').toString().toLowerCase();
      return nama.contains(query) || email.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredRecommendedMitras {
    if (_searchQuery.isEmpty) return _recommendedMitras;
    final query = _searchQuery.toLowerCase();
    return _recommendedMitras.where((mitra) {
      final nama = (mitra['nama_lengkap'] ?? '').toString().toLowerCase();
      return nama.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _displayList {
    return _activeTab == 'rekomendasi' 
        ? _filteredRecommendedMitras 
        : _filteredMitras;
  }

  bool get _isCurrentTabLoading {
    return _activeTab == 'rekomendasi' ? _isLoadingRecommendations : _isLoading;
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            if (_selectedIds.isNotEmpty) _buildSelectedCount(),
            _buildTabSelector(),
            Expanded(child: _buildContent()),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.people_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Pilih Mitra/TAD",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.fungsi.isNotEmpty 
                      ? 'Fungsi: ${_getFungsiLabel(widget.fungsi)}' 
                      : 'Semua fungsi',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SEARCH BAR ====================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        focusNode: _searchFocusNode,
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: "Cari nama atau email mitra...",
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF718096), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _searchFocusNode.unfocus();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  // ==================== SELECTED COUNT ====================
  Widget _buildSelectedCount() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF1976D2), size: 18),
            const SizedBox(width: 8),
            Text(
              "${_selectedIds.length} mitra dipilih",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF1976D2),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _selectedIds.clear()),
              child: Text(
                "Hapus Semua",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF1976D2),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TAB SELECTOR ====================
  Widget _buildTabSelector() {
    if (_recommendedMitras.isEmpty && !_isLoadingRecommendations) {
      return const SizedBox(height: 8);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(3),
          labelColor: const Color(0xFF1976D2),
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: "Semua Mitra"),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 14),
                  SizedBox(width: 4),
                  Text("Rekomendasi"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CONTENT ====================
  Widget _buildContent() {
    if (_hasError) return _buildErrorState();
    if (_isCurrentTabLoading) return _buildLoadingState();

    final displayList = _displayList;
    if (displayList.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final mitra = displayList[index];
        final isSelected = _selectedIds.contains(mitra['id']);
        final showStar = _activeTab == 'rekomendasi';
        return _buildMitraItem(mitra, isSelected, showStar: showStar);
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1976D2), strokeWidth: 2.5),
            SizedBox(height: 16),
            Text('Memuat data mitra...', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty 
                  ? Icons.search_off_rounded 
                  : _activeTab == 'rekomendasi'
                      ? Icons.history_rounded
                      : Icons.people_outline_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? "Mitra tidak ditemukan"
                  : _activeTab == 'rekomendasi'
                      ? "Belum ada riwayat mitra"
                      : "Tidak ada mitra tersedia",
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Coba kata kunci lain"
                  : _activeTab == 'rekomendasi'
                      ? "Mitra yang sering dipakai akan muncul di sini"
                      : "Pastikan sudah ada mitra terdaftar di fungsi ini",
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MITRA ITEM ====================
  Widget _buildMitraItem(
    Map<String, dynamic> mitra, 
    bool isSelected, {
    bool showStar = false,
  }) {
    final fungsiColor = _getFungsiColor((mitra['fungsi'] ?? '').toString());
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(mitra['id']);
              } else {
                _selectedIds.add(mitra['id'].toString());
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? const Color(0xFF1976D2).withValues(alpha: 0.5) 
                    : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                _buildAvatar(mitra, fungsiColor, showStar),
                const SizedBox(width: 12),
                _buildMitraInfo(mitra, fungsiColor, showStar),
                const SizedBox(width: 8),
                _buildCheckbox(isSelected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> mitra, Color fungsiColor, bool showStar) {
    final initial = (mitra['nama_lengkap']?.toString().isNotEmpty == true)
        ? mitra['nama_lengkap'].toString()[0].toUpperCase()
        : 'M';
    
    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: fungsiColor.withValues(alpha: 0.15),
          radius: 22,
          child: Text(
            initial,
            style: TextStyle(
              color: fungsiColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        if (showStar && mitra['count'] != null)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.star_rounded, size: 10, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildMitraInfo(Map<String, dynamic> mitra, Color fungsiColor, bool showStar) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (mitra['nama_lengkap'] ?? 'Tanpa Nama').toString(),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: const Color(0xFF1A2332),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: fungsiColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getFungsiLabel((mitra['fungsi'] ?? '').toString()),
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: fungsiColor,
                  ),
                ),
              ),
              if (showStar && mitra['count'] != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.history_rounded, size: 10, color: Colors.grey.shade500),
                const SizedBox(width: 2),
                Text(
                  "${mitra['count']}x",
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(bool isSelected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xFF1976D2) : Colors.grey.shade400,
          width: 2,
        ),
        color: isSelected ? const Color(0xFF1976D2) : Colors.transparent,
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : null,
    );
  }

  // ==================== ACTION BUTTONS ====================
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  "Batal",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () {
                        final selectedMitras = _mitras
                            .where((m) => _selectedIds.contains(m['id']))
                            .toList();
                        Navigator.pop(context, selectedMitras);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _selectedIds.isEmpty ? "Pilih Mitra" : "Simpan (${_selectedIds.length})",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _selectedIds.isEmpty ? Colors.grey.shade500 : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPERS ====================
  Color _getFungsiColor(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation': return const Color(0xFF1976D2);
      case 'maintenance': return const Color(0xFFFF9800);
      case 'hsse': return const Color(0xFF9C27B0);
      case 'gpr': return const Color(0xFFF44336);
      case 'bs': return const Color(0xFF795548);
      default: return const Color(0xFF757575);
    }
  }

  String _getFungsiLabel(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation': return 'Operasional';
      case 'lab': return 'Lab';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'Business Support';
      default: return fungsi;
    }
  }
}