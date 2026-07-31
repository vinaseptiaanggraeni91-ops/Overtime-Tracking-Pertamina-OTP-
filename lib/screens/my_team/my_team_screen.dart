// lib/features/my_team/my_team_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/services/my_team_service.dart';
import '../../widgets/bottom_nav/app_bottom_nav.dart';
import '../../widgets/my_team/team_helpers.dart';
import 'member_detail_screen.dart';

class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});

  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen>
    with SingleTickerProviderStateMixin {
  final MyTeamService _teamService = MyTeamService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _userRole;
  String? _userFungsi;
  String _searchQuery = '';
  bool _isLoading = true;
  String _sortBy = 'name';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final data = userDoc.data();
      setState(() {
        _userRole = data?['role']?.toString().toLowerCase();
        _userFungsi = data?['fungsi']?.toString().toLowerCase();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: _isLoading
          ? _buildShimmer()
          : _userRole == null || _userFungsi == null
              ? _buildError()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        _buildAppBar(),
                        Expanded(
                          child: CustomScrollView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(child: _buildSearchBar()),
                              _buildTeamList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: AppBottomNav(
        userRole: _userRole ?? 'karyawan',
        currentIndex: 0,
      ),
    );
  }

  // ========== APP BAR ==========

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20, right: 20, bottom: 22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tim', style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 2),
                Text(
                  '${TeamHelpers.getRoleLabel(_userRole!)} • ${TeamHelpers.getFungsiLabel(_userFungsi!)}',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _userRole![0].toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== SEARCH BAR ==========

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari anggota tim...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1976D2)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _showSortOptions,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _sortBy == 'name'
                      ? [Colors.white, Colors.white]
                      : [const Color(0xFF1976D2), const Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.filter_list_rounded,
                color: _sortBy == 'name' ? const Color(0xFF1976D2) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== SORT ==========

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Urutkan Berdasarkan', style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 24),
            _sortItem('name', 'Nama A-Z', Icons.sort_by_alpha_rounded),
            _sortItem('status', 'Status Aktif', Icons.online_prediction_rounded),
            _sortItem('recent', 'Terbaru Login', Icons.access_time_rounded),
          ],
        ),
      ),
    );
  }

  Widget _sortItem(String value, String title, IconData icon) {
    final selected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() => _sortBy = value);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1976D2).withOpacity(0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? const Color(0xFF1976D2) : Colors.grey),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title, style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 14,
                )),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF1976D2)),
            ],
          ),
        ),
      ),
    );
  }

  // ========== TEAM LIST ==========

  Widget _buildTeamList() {
    return StreamBuilder<List<TeamMember>>(
      stream: _teamService.getTeamMembersStream(
        fungsi: _userFungsi!,
        userRole: _userRole!,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: _emptyState(Icons.error_outline_rounded, 'Gagal memuat anggota tim'),
          );
        }

        List<TeamMember> members = snapshot.data ?? [];

        if (_searchQuery.isNotEmpty) {
          members = members.where((m) =>
            m.namaLengkap.toLowerCase().contains(_searchQuery) ||
            m.email.toLowerCase().contains(_searchQuery) ||
            m.phone.contains(_searchQuery)
          ).toList();
        }

        members = _sortMembers(members);

        if (members.isEmpty) {
          return SliverFillRemaining(
            child: _emptyState(Icons.group_off_rounded, 'Belum ada anggota tim'),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildMemberCard(members[index]),
              childCount: members.length,
            ),
          ),
        );
      },
    );
  }

  List<TeamMember> _sortMembers(List<TeamMember> members) {
    final sorted = List<TeamMember>.from(members);
    switch (_sortBy) {
      case 'name':
        sorted.sort((a, b) => a.namaLengkap.compareTo(b.namaLengkap));
        break;
      case 'status':
        sorted.sort((a, b) {
          final aOnline = _isMemberOnline(a);
          final bOnline = _isMemberOnline(b);
          return (bOnline ? 1 : 0).compareTo(aOnline ? 1 : 0);
        });
        break;
      case 'recent':
        sorted.sort((a, b) {
          final aLogin = a.lastLogin ?? DateTime(2000);
          final bLogin = b.lastLogin ?? DateTime(2000);
          return bLogin.compareTo(aLogin);
        });
        break;
    }
    return sorted;
  }

  // 🔥 PERBAIKAN: Cek status online berdasarkan last_active
  bool _isMemberOnline(TeamMember member) {
    // Jika ada lastLogin dan dalam 10 menit terakhir, anggap online
    if (member.lastLogin != null) {
      final diff = DateTime.now().difference(member.lastLogin!);
      if (diff.inMinutes < 10) {
        return true;
      }
    }
    return false;
  }

  // ========== MEMBER CARD ==========

  Widget _buildMemberCard(TeamMember member) {
    final isOnline = _isMemberOnline(member);
    final statusColor = isOnline ? const Color(0xFF00C853) : Colors.grey;
    final statusText = isOnline ? 'Online' : 'Offline';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: InkWell(
          onTap: () => _navigateToMemberDetail(member),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar dengan status indicator
                Stack(
                  children: [
                    Container(
                      width: 58, height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isOnline
                              ? [const Color(0xFF1976D2), const Color(0xFF1565C0)]
                              : [Colors.grey.shade400, Colors.grey.shade500],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(member.inisial, style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20,
                        )),
                      ),
                    ),
                    // 🔥 Status dot di pojok
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF00C853) : Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            if (isOnline)
                              BoxShadow(
                                color: const Color(0xFF00C853).withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(member.namaLengkap, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusBadge(isOnline, statusText, statusColor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _infoRow(Icons.email_outlined, member.email),
                      const SizedBox(height: 6),
                      _infoRow(Icons.phone_outlined, member.phone.isNotEmpty ? member.phone : '-'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            member.lastLoginFormatted,
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                          ),
                          if (member.role != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: TeamHelpers.getRoleColor(member.role!).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(TeamHelpers.getRoleLabel(member.role!),
                                style: GoogleFonts.poppins(
                                  fontSize: 9, fontWeight: FontWeight.w600,
                                  color: TeamHelpers.getRoleColor(member.role!),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool isOnline, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(text,
            style: GoogleFonts.poppins(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  // ========== NAVIGATE ==========

  void _navigateToMemberDetail(TeamMember member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemberDetailScreen(
          member: member,
          userRole: _userRole ?? 'karyawan',
        ),
      ),
    );
  }

  // ========== SHIMMER ==========

  Widget _buildShimmer() {
    return SafeArea(
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Container(height: 110, decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(28),
            )),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Container(height: 54, decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18),
              ))),
              const SizedBox(width: 12),
              Container(width: 54, height: 54, decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18),
              )),
            ]),
            const SizedBox(height: 20),
            ...List.generate(5, (index) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(22),
              ),
              child: Row(children: [
                Container(width: 58, height: 58, decoration: BoxDecoration(
                  color: Colors.grey.shade200, borderRadius: BorderRadius.circular(18),
                )),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, width: double.infinity, decoration: BoxDecoration(
                      color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8),
                    )),
                    const SizedBox(height: 10),
                    Container(height: 12, width: 180, decoration: BoxDecoration(
                      color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8),
                    )),
                    const SizedBox(height: 10),
                    Container(height: 12, width: 120, decoration: BoxDecoration(
                      color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8),
                    )),
                  ],
                )),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  // ========== EMPTY STATE ==========

  Widget _emptyState(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 18),
            Text(text, textAlign: TextAlign.center, style: GoogleFonts.poppins(
              color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }

  // ========== ERROR STATE ==========

  Widget _buildError() => _emptyState(Icons.error_outline_rounded, 'Gagal memuat data');
}