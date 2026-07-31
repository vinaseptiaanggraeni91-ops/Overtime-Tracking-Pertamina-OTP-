// lib/pages/manager/my_team_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/manager_service.dart';

class MyTeamPage extends StatefulWidget {
  const MyTeamPage({super.key});

  @override
  State<MyTeamPage> createState() => _MyTeamPageState();
}

class _MyTeamPageState extends State<MyTeamPage> {
  final _service = ManagerService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _teamMembers = [];
  int _onlineMembers = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _service.loadDashboardData();
      if (mounted) {
        setState(() {
          _teamMembers = data.teamMembers;
          _onlineMembers = data.onlineMembers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ✅ Navigasi ke detail member
  void _navigateToMemberDetail(Map<String, dynamic> member) {
    final memberId = member['id']?.toString() ?? member['uid']?.toString() ?? '';
    if (memberId.isNotEmpty) {
      context.push('/member-detail/$memberId', extra: {'member': member});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data member tidak lengkap')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Tim',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3C72)),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadTeamData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTeamData,
                  color: const Color(0xFF1E3C72),
                  child: _teamMembers.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Belum ada anggota tim',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tarik ke bawah untuk memuat ulang',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _teamMembers.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // Header info
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Total Anggota',
                                            style: TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_teamMembers.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withAlpha(40),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8, height: 8,
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$_onlineMembers Online',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final member = _teamMembers[index - 1];
                            final isOnline = member['isOnline'] ?? false;
                            final role = member['role']?.toString() ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(10),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => _navigateToMemberDetail(member),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: const Color(0xFF1E3C72).withAlpha(26),
                                              backgroundImage: (member['photo_url'] != null &&
                                                      member['photo_url'].toString().isNotEmpty)
                                                  ? NetworkImage(member['photo_url'].toString())
                                                  : null,
                                              child: (member['photo_url'] == null ||
                                                      member['photo_url'].toString().isEmpty)
                                                  ? Text(
                                                      (member['nama_lengkap']?.toString() ?? '?')[0].toUpperCase(),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF1E3C72),
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            if (isOnline)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  width: 12, height: 12,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 2),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        // Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                member['nama_lengkap']?.toString() ?? 'Unknown',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                role.isNotEmpty ? role.toUpperCase() : '-',
                                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Status + Arrow
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isOnline
                                                    ? Colors.green.withAlpha(20)
                                                    : Colors.grey.withAlpha(20),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                isOnline ? 'Online' : 'Offline',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isOnline ? Colors.green : Colors.grey,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}