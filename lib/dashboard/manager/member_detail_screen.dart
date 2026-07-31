// lib/dashboard/manager/member_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class MemberDetailScreen extends StatefulWidget {
  final String? memberId;
  final Map<String, dynamic>? memberData;

  const MemberDetailScreen({
    super.key,
    this.memberId,
    this.memberData,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  Map<String, dynamic> _member = {};
  String _memberId = '';
  bool _isLoading = true;
  int totalHariKerja = 0;
  bool isLoadingHariKerja = true;
  bool _isOnline = false;
  String _lastActiveText = 'Offline';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.memberData != null) {
      _member = widget.memberData!;
      _memberId = widget.memberId ?? widget.memberData!['id'] ?? widget.memberData!['userId'] ?? '';
      _updateOnlineStatus();
      setState(() {
        _isLoading = false;
      });
      _fetchTotalHariKerja();
    } else if (widget.memberId != null) {
      _memberId = widget.memberId!;
      _fetchMemberData();
    } else {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _member = args['member'] as Map<String, dynamic>? ?? {};
        _memberId = args['memberId'] as String? ?? _member['id'] ?? _member['userId'] ?? '';
        _updateOnlineStatus();
        setState(() {
          _isLoading = false;
        });
        _fetchTotalHariKerja();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateOnlineStatus() {
    final lastActive = _member['last_active'] ?? _member['lastActive'] ?? _member['timestamp'] ?? _member['last_seen'];
    
    if (lastActive != null) {
      try {
        DateTime? lastActiveTime;
        if (lastActive is DateTime) {
          lastActiveTime = lastActive;
        } else if (lastActive is Timestamp) {
          lastActiveTime = lastActive.toDate();
        }
        
        if (lastActiveTime != null) {
          final diff = DateTime.now().difference(lastActiveTime);
          if (diff.inMinutes < 10) {
            _isOnline = true;
            _lastActiveText = 'Online';
            return;
          }
          _isOnline = false;
          _lastActiveText = _formatLastActive(lastActiveTime);
          return;
        }
      } catch (_) {}
    }
    
    _isOnline = false;
    _lastActiveText = 'Offline';
  }

  String _formatLastActive(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}m lalu';
    return '${(diff.inDays / 30).floor()}bl lalu';
  }

  Future<void> _fetchMemberData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_memberId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _member = doc.data() ?? {};
          _member['id'] = doc.id;
          _updateOnlineStatus();
          _isLoading = false;
        });
        _fetchTotalHariKerja();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e')),
        );
      }
    }
  }

  Future<void> _fetchTotalHariKerja() async {
    if (_memberId.isEmpty) {
      setState(() {
        isLoadingHariKerja = false;
      });
      return;
    }

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('lembur')
          .where('jenis_lembur', isEqualTo: 'hari_kerja')
          .where('pengawas_id', isEqualTo: _memberId)
          .get();

      if (mounted) {
        setState(() {
          totalHariKerja = snapshot.docs.length;
          isLoadingHariKerja = false;
        });
      }
    } catch (e) {
      try {
        final QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('lembur')
            .where('jenis_lembur', isEqualTo: 'hari_kerja')
            .where('mitra_id', isEqualTo: _memberId)
            .get();

        if (mounted) {
          setState(() {
            totalHariKerja = snapshot.docs.length;
            isLoadingHariKerja = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            isLoadingHariKerja = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Detail Member'),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String namaLengkap = _member['nama'] ?? _member['nama_lengkap'] ?? 'Nama Member';
    final String initial = namaLengkap.isNotEmpty ? namaLengkap[0].toUpperCase() : '?';
    final String role = _member['role'] ?? _member['user_role'] ?? '-';
    final String fungsi = _member['fungsi'] ?? _member['fungsi_label'] ?? '-';
    final String email = _member['email'] ?? '-';
    final String phone = _member['phone'] ?? _member['no_hp'] ?? '-';
    final String id = _memberId.isNotEmpty ? _memberId : (_member['id'] ?? '-');
    final int totalLembur = _member['totalLembur'] ?? _member['total_lembur'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Detail Member',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Card Utama
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isOnline
                                ? [const Color(0xFF1565C0), const Color(0xFF42A5F5)]
                                : [Colors.grey.shade400, Colors.grey.shade500],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isOnline ? const Color(0xFF1565C0) : Colors.grey)
                                  .withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Status indicator
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              if (_isOnline)
                                BoxShadow(
                                  color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Nama
                  Text(
                    namaLengkap,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Role
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: _isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isOnline ? 'Online' : _lastActiveText,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Informasi Personal Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_outline, color: Color(0xFF1565C0), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Informasi Personal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(Icons.email_outlined, 'Email', email),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.work_outline, 'Fungsi', fungsi),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.phone_outlined, 'Phone', phone),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.badge_outlined, 'Member ID', id),
                  if (_member['last_active'] != null || _member['lastActive'] != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      Icons.access_time_rounded, 
                      'Terakhir Aktif', 
                      _formatLastActive(
                        _member['last_active'] is DateTime 
                            ? _member['last_active'] 
                            : _member['lastActive'] is DateTime 
                                ? _member['lastActive'] 
                                : DateTime.now()
                      )
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Statistik Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, color: Color(0xFF1565C0), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Statistik',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          icon: Icons.timer_outlined,
                          value: '$totalLembur',
                          label: 'Jam Lembur',
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatBox(
                          icon: Icons.calendar_month_outlined,
                          value: isLoadingHariKerja ? '...' : '$totalHariKerja',
                          label: 'Hari Kerja',
                          color: const Color(0xFF42A5F5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF1565C0), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF757575),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}