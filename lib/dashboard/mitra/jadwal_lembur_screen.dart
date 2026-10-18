import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:table_calendar/table_calendar.dart';
import '/core/services/overtime_history_service.dart';
import '/core/services/overtime_rate_service.dart';
import '/widgets/bottom_nav/app_bottom_nav.dart';

var logger = Logger();

class JadwalLemburScreen extends StatefulWidget {
  const JadwalLemburScreen({super.key});

  @override
  State<JadwalLemburScreen> createState() => _JadwalLemburScreenState();
}

class _JadwalLemburScreenState extends State<JadwalLemburScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OvertimeHistoryService _historyService = OvertimeHistoryService();
  final OvertimeRateService _rateService = OvertimeRateService();

  // ==================== ANIMATION ====================
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ==================== USER DATA ====================
  Map<String, dynamic>? userData;
  String? userId;
  String? userRole;
  String? userName;
  String? userFungsi;

  // ==================== CALENDAR DATA ====================
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<OvertimeEvent>> _events = {};
  Set<DateTime> _holidays = {};

  // ==================== OVERTIME DATA ====================
  List<OvertimeHistory> allOvertime = [];
  List<OvertimeHistory> filteredOvertime = [];
  Map<String, List<OvertimeHistory>> overtimeByDate = {};

  // ==================== UI STATE ====================
  bool isLoading = true;
  bool isRefreshing = false;
  String searchQuery = '';
  String executionFilter = 'semua';

  // ==================== STREAM SUBSCRIPTIONS ====================
  StreamSubscription? _overtimeSubscription;

  // ==================== ROLE PERMISSIONS ====================
  bool get isMitra => userRole == 'mitra';
  bool get isPengawas => userRole == 'pengawas';
  bool get isManager => userRole == 'manager';
  bool get isSuperAdmin => userRole == 'superadmin';

  // ==================== NAV INDEX ====================
  int _getNavIndex() {
    if (userFungsi == 'hsse') return 1;
    switch (userRole) {
      case 'superadmin':
      case 'manager':
        return 1;
      case 'pengawas':
      case 'mitra':
        return 2;
      default:
        return 0;
    }
  }

  // ==================== STATISTICS ====================
  int get totalOvertime => allOvertime.length;
  int get pendingOvertime => allOvertime.where((e) => e.status == 'pending').length;
  int get approvedOvertime => allOvertime.where((e) => e.status == 'disetujui').length;
  int get completedOvertime => allOvertime.where((e) => e.status == 'selesai').length;

  // ==================== INDONESIAN HOLIDAYS ====================
  final Map<int, List<Map<String, String>>> _indonesianHolidays = {
    2024: [
      {'date': '2024-01-01', 'name': '🎉 Tahun Baru'},
      {'date': '2024-02-08', 'name': '✨ Isra Miraj'},
      {'date': '2024-04-10', 'name': '🌙 Idul Fitri'},
      {'date': '2024-05-01', 'name': '👷 Hari Buruh'},
      {'date': '2024-08-17', 'name': '🇮🇩 HUT RI'},
      {'date': '2024-12-25', 'name': '🎄 Natal'},
    ],
    2025: [
      {'date': '2025-01-01', 'name': '🎉 Tahun Baru'},
      {'date': '2025-03-31', 'name': '🌙 Idul Fitri'},
      {'date': '2025-05-01', 'name': '👷 Hari Buruh'},
      {'date': '2025-08-17', 'name': '🇮🇩 HUT RI'},
      {'date': '2025-12-25', 'name': '🎄 Natal'},
    ],
    2026: [
      {'date': '2026-01-01', 'name': '🎉 Tahun Baru'},
      {'date': '2026-05-01', 'name': '👷 Hari Buruh'},
      {'date': '2026-08-17', 'name': '🇮🇩 HUT RI'},
      {'date': '2026-12-25', 'name': '🎄 Natal'},
    ],
  };

  // ==================== INIT STATE ====================
  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    
    // Setup animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _overtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() => userId = user.uid);
      try {
        final doc = await _firestore.collection('users').doc(userId).get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            userData = data;
            userRole = data['role'] ?? 'mitra';
            userName = data['nama_lengkap'] ?? data['email']?.split('@')[0] ?? 'Pengguna';
            userFungsi = data['fungsi'];
          });
        }
      } catch (e) {
        logger.e('Error loading user data: $e');
        setState(() {
          userRole = 'mitra';
          userName = 'Mitra';
        });
      }
    }
    _setupRealTimeListeners();
    await _loadOvertimeData();
    _initCalendarEvents();
    setState(() => isLoading = false);
  }

  void _setupRealTimeListeners() {
    if (userId == null || userRole == null) return;
    _overtimeSubscription?.cancel();
    try {
      _overtimeSubscription = _historyService
          .getOvertimeHistoryStream(
            userRole: userRole!,
            userFungsi: userFungsi,
            userId: userId,
          )
          .listen((overtimeList) {
        _processOvertimeList(overtimeList);
      });
    } catch (e) {
      logger.e('Error setting up overtime listener: $e');
    }
  }

  void _processOvertimeList(List<OvertimeHistory> overtimeList) {
    final Map<String, List<OvertimeHistory>> byDate = {};
    for (var overtime in overtimeList) {
      final dateKey = DateFormat('yyyy-MM-dd').format(overtime.tanggal);
      if (!byDate.containsKey(dateKey)) byDate[dateKey] = [];
      byDate[dateKey]!.add(overtime);
    }
    if (mounted) {
      setState(() {
        allOvertime = overtimeList;
        overtimeByDate = byDate;
        _applyFilters();
        _updateCalendarEvents();
      });
    }
  }

  Future<void> _loadOvertimeData() async {
    if (userId == null || userRole == null) return;
    setState(() => isLoading = true);
    try {
      final overtimeList = await _historyService
          .getOvertimeHistoryStream(
            userRole: userRole!,
            userFungsi: userFungsi,
            userId: userId,
          )
          .first;
      _processOvertimeList(overtimeList);
    } catch (e) {
      logger.e('Error loading overtime: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _initCalendarEvents() {
    _loadHolidays();
    _updateCalendarEvents();
  }

  void _loadHolidays() {
    final now = DateTime.now();
    final currentYear = now.year;
    final Set<DateTime> holidays = {};
    for (int year = currentYear; year <= currentYear + 5; year++) {
      if (_indonesianHolidays.containsKey(year)) {
        for (var holiday in _indonesianHolidays[year]!) {
          try {
            final parts = holiday['date']!.split('-');
            if (parts.length == 3) {
              holidays.add(DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])));
            }
          } catch (_) {}
        }
      }
    }
    setState(() => _holidays = holidays);
  }

  void _updateCalendarEvents() {
    final Map<DateTime, List<OvertimeEvent>> events = {};
    for (var overtime in allOvertime) {
      final dateKey = DateTime(overtime.tanggal.year, overtime.tanggal.month, overtime.tanggal.day);
      if (!events.containsKey(dateKey)) events[dateKey] = [];
      events[dateKey]!.add(OvertimeEvent(
        id: overtime.id,
        title: overtime.namaMitra ?? 'Lembur',
        jamMulai: overtime.jamMulai,
        jamSelesai: overtime.jamSelesai,
        status: _getExecutionStatus(overtime),
      ));
    }
    setState(() => _events = events);
  }

  bool _isHoliday(DateTime date) {
    return _holidays.contains(DateTime(date.year, date.month, date.day));
  }

  String? _getHolidayName(DateTime date) {
    final year = date.year;
    if (_indonesianHolidays.containsKey(year)) {
      for (var holiday in _indonesianHolidays[year]!) {
        try {
          final parts = holiday['date']!.split('-');
          if (parts.length == 3) {
            final hDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            if (hDate.year == date.year && hDate.month == date.month && hDate.day == date.day) {
              return holiday['name'];
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  String _getExecutionStatus(OvertimeHistory overtime) {
    final status = overtime.status.toLowerCase();
    final now = DateTime.now();
    if (status == 'dibatalkan') return 'dibatalkan';
    if (status == 'ditolak') return 'ditolak';
    if (status == 'selesai') return 'completed';
    if (status == 'disetujui') {
      final isUpcoming = overtime.tanggal.isAfter(now);
      final isPast = overtime.tanggal.isBefore(DateTime(now.year, now.month, now.day));
      if (isUpcoming) return 'upcoming';
      if (isPast) return overtime.absensiStatus == 'selesai' ? 'completed' : 'late';
      return 'today_ongoing';
    }
    return status;
  }

  void _applyFilters() {
    List<OvertimeHistory> filtered = List.from(allOvertime);
    if (executionFilter != 'semua') {
      filtered = filtered.where((item) {
        final execStatus = _getExecutionStatus(item);
        switch (executionFilter) {
          case 'upcoming': return execStatus == 'upcoming';
          case 'completed': return execStatus == 'completed';
          case 'late': return execStatus == 'late';
          case 'ongoing': return execStatus == 'today_ongoing';
          case 'cancelled': return execStatus == 'dibatalkan';
          default: return false;
        }
      }).toList();
    }
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final nama = item.namaMitra?.toLowerCase() ?? '';
        final fungsi = item.fungsiMitra?.toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return nama.contains(query) || fungsi.contains(query);
      }).toList();
    }
    setState(() => filteredOvertime = filtered);
  }

  Future<void> _refreshData() async {
    setState(() => isRefreshing = true);
    await _loadOvertimeData();
    setState(() => isRefreshing = false);
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(color == Colors.green ? Icons.check_circle : Icons.info_outline,
                color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 13))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getCurrentDate() => DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now());

  // ==================== MAIN BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      appBar: _buildAppBar(),
      bottomNavigationBar: userRole != null
          ? AppBottomNav(userRole: userRole!, currentIndex: _getNavIndex())
          : null,
      body: isLoading
          ? _buildLoadingScreen()
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF1A2B4C),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 16),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      _buildCalendarCard(),
                      const SizedBox(height: 20),
                      _buildSearchAndFilter(),
                      const SizedBox(height: 16),
                      _buildSectionHeader(),
                      const SizedBox(height: 12),
                      filteredOvertime.isEmpty
                          ? _buildEmptyState()
                          : _buildOvertimeList(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 Jadwal Lembur',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          Text(
            _getCurrentDate(),
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A2B4C),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refreshData,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ==================== WELCOME CARD ====================
  Widget _buildWelcomeCard() {
    String greeting = 'Selamat Datang';
    String subtitle = 'Pantau jadwal lembur Anda';
    IconData icon = Icons.waving_hand_rounded;
    Color color1 = const Color(0xFF6366F1);
    Color color2 = const Color(0xFF8B5CF6);

    if (isPengawas) {
      greeting = 'Halo, Pengawas';
      subtitle = 'Kelola jadwal lembur tim Anda';
      icon = Icons.visibility_rounded;
      color1 = const Color(0xFF0D47A1);
      color2 = const Color(0xFF1976D2);
    } else if (isManager) {
      greeting = 'Halo, Manager';
      subtitle = 'Monitor & setujui pengajuan lembur';
      icon = Icons.manage_accounts_rounded;
      color1 = const Color(0xFF1B5E20);
      color2 = const Color(0xFF388E3C);
    } else if (isSuperAdmin) {
      greeting = 'Halo, Admin';
      subtitle = 'Kontrol penuh sistem lembur';
      icon = Icons.admin_panel_settings_rounded;
      color1 = const Color(0xFF4A148C);
      color2 = const Color(0xFF7B1FA2);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color1.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATS GRID ====================
  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('📋 Total', totalOvertime, const Color(0xFF6366F1))),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('⏳ Pending', pendingOvertime, const Color(0xFFF59E0B))),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('✅ Selesai', completedOvertime, const Color(0xFF10B981))),
      ],
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CALENDAR CARD ====================
  Widget _buildCalendarCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          TableCalendar<OvertimeEvent>(
            firstDay: DateTime(2024),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => _isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) => setState(() => _calendarFormat = format),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                final dateKey = DateFormat('yyyy-MM-dd').format(selectedDay);
                filteredOvertime = overtimeByDate[dateKey] ?? [];
              });
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, date, _) {
                final isHoliday = _isHoliday(date);
                final hasEvent = (_events[date] ?? []).isNotEmpty;
                final isSelected = _isSameDay(date, _selectedDay);
                final isToday = _isSameDay(date, DateTime.now());

                return Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : isHoliday
                            ? Colors.red.shade50
                            : isToday
                                ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                                : null,
                    borderRadius: BorderRadius.circular(14),
                    border: isToday && !isSelected
                        ? Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 2)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '${date.day}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : isHoliday
                                    ? Colors.red
                                    : Colors.grey[700],
                          ),
                        ),
                      ),
                      if (hasEvent && !isSelected)
                        Positioned(
                          bottom: 4,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B35),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6B35).withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            eventLoader: (date) => _events[date] ?? [],
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              titleTextStyle: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
              leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF6366F1), size: 28),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6366F1), size: 28),
              formatButtonTextStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              formatButtonDecoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500]),
              weekendStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red[300]),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _legendItem(const Color(0xFFFF6B35), 'Ada Lembur'),
              _legendItem(Colors.red.shade400, 'Hari Libur'),
              _legendItem(const Color(0xFF6366F1), 'Hari Ini'),
              _legendItem(const Color(0xFF10B981), 'Selesai'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  // ==================== SEARCH & FILTER ====================
  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.grey.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: TextField(
            onChanged: (value) {
              setState(() => searchQuery = value);
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: '🔍 Cari mitra atau fungsi...',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1)),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20, color: Colors.grey),
                      onPressed: () {
                        setState(() => searchQuery = '');
                        _applyFilters();
                      },
                    )
                  : null,
              border: InputBorder.none,
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ),
        const SizedBox(height: 10),
        // Filter chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterChip('📋 Semua', 'semua'),
              _buildFilterChip('📅 Mendatang', 'upcoming'),
              _buildFilterChip('✅ Selesai', 'completed'),
              _buildFilterChip('⚠️ Terlambat', 'late'),
              _buildFilterChip('🔄 Berlangsung', 'ongoing'),
              _buildFilterChip('🚫 Dibatalkan', 'cancelled'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = executionFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            executionFilter = selected ? 'semua' : value;
            _applyFilters();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6366F1) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? const Color(0xFF6366F1) : Colors.grey.shade200,
            ),
            boxShadow: selected
                ? [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== SECTION HEADER ====================
  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '📋 Daftar Lembur',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${filteredOvertime.length} Data',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6366F1),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== OVERTIME LIST ====================
  Widget _buildOvertimeList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredOvertime.length,
      itemBuilder: (context, index) {
        final overtime = filteredOvertime[index];
        return _buildOvertimeCard(overtime, index);
      },
    );
  }

  Widget _buildOvertimeCard(OvertimeHistory overtime, int index) {
    final execStatus = _getExecutionStatus(overtime);
    final color = _getStatusColor(execStatus);
    final icon = _getStatusIcon(execStatus);
    final label = _getStatusLabel(execStatus);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () => _showOvertimeDetail(overtime),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Icon(icon, color: color, size: 26)),
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
                          child: Text(
                            overtime.namaMitra ?? 'Mitra',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM yyyy', 'id_ID').format(overtime.tanggal),
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          '${overtime.jamMulai} - ${overtime.jamSelesai}',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.06), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          Text(
            '📭 Tidak Ada Jadwal Lembur',
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada jadwal lembur yang tersedia\nuntuk tanggal yang dipilih',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==================== LOADING SCREEN ====================
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Color(0xFF6366F1),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Memuat jadwal lembur...',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ==================== OVERTIME DETAIL BOTTOM SHEET ====================
  void _showOvertimeDetail(OvertimeHistory overtime) {
    final execStatus = _getExecutionStatus(overtime);
    final color = _getStatusColor(execStatus);
    final isHoliday = _isHoliday(overtime.tanggal);
    final holidayName = _getHolidayName(overtime.tanggal);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(_getStatusIcon(execStatus), color: color, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Detail Lembur',
                                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                              Text(overtime.namaMitra ?? '-',
                                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(_getStatusLabel(execStatus),
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Info cards
                    _buildDetailCard([
                      _detailItem('📅 Tanggal', DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(overtime.tanggal)),
                      if (isHoliday) _detailItem('🎉 Hari Libur', holidayName ?? ''),
                      _detailItem('⏰ Waktu', '${overtime.jamMulai} - ${overtime.jamSelesai} WIB'),
                      _detailItem('⏱️ Durasi', '${overtime.totalJam.toStringAsFixed(1)} Jam'),
                    ]),
                    const SizedBox(height: 12),
                    _buildDetailCard([
                      _detailItem('💰 Biaya', _rateService.formatRupiah(overtime.estimasiBiayaPerMitra)),
                      if (overtime.namaPengawas != null)
                        _detailItem('👤 Pengawas', overtime.namaPengawas!),
                      if (overtime.fungsiMitra != null)
                        _detailItem('🏢 Fungsi', overtime.fungsiMitra!),
                    ]),
                    const SizedBox(height: 20),
                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: Text('Tutup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }

  // ==================== HELPERS ====================
  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming': return const Color(0xFF6366F1);
      case 'completed': return const Color(0xFF10B981);
      case 'late': return const Color(0xFFEF4444);
      case 'today_ongoing': return const Color(0xFF8B5CF6);
      case 'pending': return const Color(0xFFF59E0B);
      case 'disetujui': return const Color(0xFF3B82F6);
      case 'ditolak': return const Color(0xFFEF4444);
      case 'dibatalkan': return const Color(0xFF94A3B8);
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'upcoming': return Icons.event_available_rounded;
      case 'completed': return Icons.check_circle_rounded;
      case 'late': return Icons.warning_amber_rounded;
      case 'today_ongoing': return Icons.access_time_rounded;
      case 'pending': return Icons.pending_rounded;
      case 'disetujui': return Icons.thumb_up_rounded;
      case 'ditolak': return Icons.cancel_rounded;
      case 'dibatalkan': return Icons.block_rounded;
      default: return Icons.info_rounded;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'upcoming': return 'Mendatang';
      case 'completed': return 'Selesai';
      case 'late': return 'Terlambat';
      case 'today_ongoing': return 'Berlangsung';
      case 'pending': return 'Menunggu';
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      case 'dibatalkan': return 'Dibatalkan';
      default: return status;
    }
  }
}

// ==================== OVERTIME EVENT CLASS ====================
class OvertimeEvent {
  final String id;
  final String title;
  final String jamMulai;
  final String jamSelesai;
  final String status;

  OvertimeEvent({
    required this.id,
    required this.title,
    required this.jamMulai,
    required this.jamSelesai,
    required this.status,
  });
}