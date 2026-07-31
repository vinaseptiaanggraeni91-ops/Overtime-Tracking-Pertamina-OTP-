// lib/dashboard/mitra/jadwal_lembur_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:table_calendar/table_calendar.dart';
import '/core/services/overtime_service.dart';
import '/widgets/bottom_nav/app_bottom_nav.dart';

var logger = Logger();

class JadwalLemburScreen extends StatefulWidget {
  const JadwalLemburScreen({super.key});

  @override
  State<JadwalLemburScreen> createState() => _JadwalLemburScreenState();
}

class _JadwalLemburScreenState extends State<JadwalLemburScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OvertimeService _overtimeService = OvertimeService();

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
  OvertimeHistory? selectedOvertime;
  String searchQuery = '';
  String filterStatus = 'semua';
  String executionFilter = 'semua';
  DateTime? filterStartDate;
  DateTime? filterEndDate;

  // ==================== TIMER ====================
  Timer? _clockTimer;

  // ==================== RATES ====================
  Map<String, dynamic>? _rates;

  // ==================== STREAM SUBSCRIPTIONS ====================
  StreamSubscription? _overtimeSubscription;

  // ==================== ROLE PERMISSIONS ====================
  bool get isMitra => userRole == 'mitra';
  bool get isPengawas => userRole == 'pengawas';
  bool get isManager => userRole == 'manager';
  bool get isSuperAdmin => userRole == 'superadmin';

  bool get canSeeAllOvertime => isPengawas || isManager || isSuperAdmin;
  bool get canApproveOvertime => isPengawas || isManager || isSuperAdmin;
  bool get canCreateOvertime => isPengawas || isManager || isSuperAdmin;
  bool get canCancelOvertime => isSuperAdmin || isPengawas || isManager;
  bool get canRestoreOvertime => isSuperAdmin;

  // ==================== NAV INDEX DETEKSI ROLE ====================
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

  // ==================== FILTERED DATA ====================
  List<OvertimeHistory> get displayedOvertime {
    List<OvertimeHistory> result = List.from(filteredOvertime);
    if (searchQuery.isNotEmpty) {
      result = result.where((item) {
        final nama = item.namaMitra?.toLowerCase() ?? '';
        final fungsi = item.fungsiMitra?.toLowerCase() ?? '';
        final pengawas = item.namaPengawas?.toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return nama.contains(query) || fungsi.contains(query) || pengawas.contains(query);
      }).toList();
    }
    return result;
  }

  // ==================== STATISTICS ====================
  int get totalOvertime => allOvertime.length;
  int get pendingOvertime => allOvertime.where((e) => e.status == 'pending').length;
  int get approvedOvertime => allOvertime.where((e) => e.status == 'disetujui').length;
  int get completedOvertime => allOvertime.where((e) => e.status == 'selesai').length;

  // ==================== INDONESIAN HOLIDAYS ====================
  final Map<int, List<Map<String, String>>> _indonesianHolidays = {
    2024: [
      {'date': '2024-01-01', 'name': 'Tahun Baru'},
      {'date': '2024-02-08', 'name': 'Isra Miraj'},
      {'date': '2024-04-10', 'name': 'Idul Fitri'},
      {'date': '2024-05-01', 'name': 'Hari Buruh'},
      {'date': '2024-08-17', 'name': 'HUT RI'},
      {'date': '2024-12-25', 'name': 'Natal'},
    ],
    2025: [
      {'date': '2025-01-01', 'name': 'Tahun Baru'},
      {'date': '2025-03-31', 'name': 'Idul Fitri'},
      {'date': '2025-05-01', 'name': 'Hari Buruh'},
      {'date': '2025-08-17', 'name': 'HUT RI'},
      {'date': '2025-12-25', 'name': 'Natal'},
    ],
    2026: [
      {'date': '2026-01-01', 'name': 'Tahun Baru'},
      {'date': '2026-05-01', 'name': 'Hari Buruh'},
      {'date': '2026-08-17', 'name': 'HUT RI'},
      {'date': '2026-12-25', 'name': 'Natal'},
    ],
  };

  // ==================== INIT STATE ====================
  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadUserData();
    _loadRates();
    _startClockTimer();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _overtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRates() async {
    try {
      _rates = await _overtimeService.loadOvertimeRates();
      if (mounted) setState(() {});
    } catch (e) {
      logger.e('Error loading rates: $e');
    }
  }

  void _startClockTimer() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
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
        } else {
          setState(() {
            userRole = 'mitra';
            userName = 'Mitra';
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
      _overtimeSubscription = _overtimeService
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
        _applyAllFilters();
        _updateCalendarEvents();
      });
    }
  }

  Future<void> _loadOvertimeData() async {
    if (userId == null || userRole == null) return;
    setState(() => isLoading = true);
    try {
      final overtimeList = await _overtimeService
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
        status: _getOvertimeExecutionStatus(overtime),
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

  String _getOvertimeExecutionStatus(OvertimeHistory overtime) {
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

  String _getExecutionStatusText(String executionStatus) {
    switch (executionStatus) {
      case 'upcoming': return 'Mendatang';
      case 'completed': return 'Selesai';
      case 'late': return 'Terlambat';
      case 'today_ongoing': return 'Berlangsung';
      case 'pending': return 'Menunggu';
      case 'disetujui': return 'Disetujui';
      case 'ditolak': return 'Ditolak';
      case 'dibatalkan': return 'Dibatalkan';
      default: return executionStatus;
    }
  }

  Color _getExecutionStatusColor(String executionStatus) {
    switch (executionStatus) {
      case 'upcoming': return const Color(0xFF4A90D9);
      case 'completed': return const Color(0xFF2ECC71);
      case 'late': return const Color(0xFFE74C3C);
      case 'today_ongoing': return const Color(0xFF9B59B6);
      case 'pending': return const Color(0xFFF39C12);
      case 'disetujui': return const Color(0xFF3498DB);
      case 'ditolak': return const Color(0xFFE74C3C);
      case 'dibatalkan': return const Color(0xFF95A5A6);
      default: return Colors.grey;
    }
  }

  IconData _getExecutionStatusIcon(String executionStatus) {
    switch (executionStatus) {
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

  void _applyAllFilters() {
    List<OvertimeHistory> filtered = List.from(allOvertime);
    if (filterStatus != 'semua') {
      filtered = filtered.where((item) => item.status == filterStatus).toList();
    }
    if (executionFilter != 'semua') {
      filtered = filtered.where((item) {
        final execStatus = _getOvertimeExecutionStatus(item);
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
    if (filterStartDate != null) {
      filtered = filtered.where((item) => item.tanggal.isAfter(filterStartDate!.subtract(const Duration(days: 1)))).toList();
    }
    if (filterEndDate != null) {
      filtered = filtered.where((item) => item.tanggal.isBefore(filterEndDate!.add(const Duration(days: 1)))).toList();
    }
    setState(() => filteredOvertime = filtered);
  }

  Future<void> _refreshData() async {
    setState(() => isRefreshing = true);
    await _loadOvertimeData();
    await _loadRates();
    setState(() => isRefreshing = false);
  }

  Future<void> _approveOvertime(String overtimeId) async {
    try {
      await _overtimeService.updateOvertimeStatus(docId: overtimeId, status: 'disetujui');
      if (mounted) {
        _showSnackbar('Lembur berhasil disetujui ✅', Colors.green);
        _refreshData();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnackbar('Gagal menyetujui lembur', Colors.red);
    }
  }

  Future<void> _rejectOvertime(String overtimeId) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.cancel_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text('Tolak Pengajuan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Berikan alasan penolakan', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tulis alasan...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: Text('Tolak', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _overtimeService.updateOvertimeStatus(
        docId: overtimeId,
        status: 'ditolak',
        note: controller.text.isNotEmpty ? controller.text : null,
      );
      if (mounted) {
        _showSnackbar('Lembur berhasil ditolak', Colors.orange);
        _refreshData();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnackbar('Gagal menolak lembur', Colors.red);
    }
  }

  void _showOvertimeDetail(OvertimeHistory overtime) {
    final executionStatus = _getOvertimeExecutionStatus(overtime);
    final isHoliday = _isHoliday(overtime.tanggal);
    final holidayName = _getHolidayName(overtime.tanggal);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const _DragHandle(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildDetailHeader(overtime, executionStatus),
                    const SizedBox(height: 24),
                    _buildDetailInfo(overtime, isHoliday, holidayName),
                    const SizedBox(height: 20),
                    if (canApproveOvertime && overtime.status == 'pending')
                      _buildApprovalActions(overtime.id),
                    const SizedBox(height: 16),
                    _buildCloseButton(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailHeader(OvertimeHistory overtime, String executionStatus) {
    final color = _getExecutionStatusColor(executionStatus);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(_getExecutionStatusIcon(executionStatus), color: color, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detail Lembur',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A2B4C),
                ),
              ),
              Text(
                overtime.namaMitra ?? 'Mitra',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // FIX 1: Menggunakan Flexible untuk mencegah overflow di detail header
        Flexible(
          child: _buildStatusBadge(executionStatus),
        ),
      ],
    );
  }

  Widget _buildDetailInfo(OvertimeHistory overtime, bool isHoliday, String? holidayName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _detailRow(Icons.calendar_today_rounded, 'Tanggal', _overtimeService.formatTanggal(overtime.tanggal)),
          if (isHoliday) _detailRow(Icons.celebration_rounded, 'Hari Libur', holidayName ?? '', color: Colors.red),
          _detailRow(Icons.access_time_rounded, 'Waktu', '${overtime.jamMulai} - ${overtime.jamSelesai} WIB'),
          _detailRow(Icons.timer_rounded, 'Total Jam', '${overtime.totalJam.toStringAsFixed(1)} Jam'),
          _detailRow(Icons.monetization_on_rounded, 'Estimasi Biaya', _overtimeService.formatRupiah(overtime.estimasiBiayaPerMitra)),
          if (overtime.namaPengawas != null && overtime.namaPengawas!.isNotEmpty)
            _detailRow(Icons.person_rounded, 'Pengawas', overtime.namaPengawas!),
        ],
      ),
    );
  }

  Widget _buildApprovalActions(String overtimeId) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _approveOvertime(overtimeId),
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            label: Text('Setujui', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _rejectOvertime(overtimeId),
            icon: const Icon(Icons.cancel_rounded, size: 20),
            label: Text('Tolak', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCloseButton() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.close_rounded, size: 18),
      label: Text('Tutup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey,
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? color}) {
    final c = color ?? const Color(0xFF1A2B4C);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: c),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getExecutionStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getExecutionStatusIcon(status), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _getExecutionStatusText(status),
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getCurrentTime() => DateFormat('HH:mm:ss').format(DateTime.now());
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
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRoleInfoCard(),
                    const SizedBox(height: 16),
                    _buildStatsCard(),
                    const SizedBox(height: 16),
                    _buildCalendar(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildFilterChips(),
                    const SizedBox(height: 16),
                    _buildSectionHeader(),
                    const SizedBox(height: 12),
                    displayedOvertime.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: displayedOvertime.length,
                            itemBuilder: (context, index) =>
                                _buildOvertimeCard(displayedOvertime[index]),
                          ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jadwal Lembur',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            _getCurrentDate(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A2B4C),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16),
              const SizedBox(width: 6),
              Text(
                _getCurrentTime(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleInfoCard() {
    String roleText = userRole ?? 'Mitra';
    IconData roleIcon = Icons.person_rounded;
    Color gradientColor1 = const Color(0xFF1A2B4C);
    Color gradientColor2 = const Color(0xFF2C3E6B);

    if (isPengawas) {
      roleIcon = Icons.visibility_rounded;
      gradientColor1 = const Color(0xFF0D47A1);
      gradientColor2 = const Color(0xFF1976D2);
    } else if (isManager) {
      roleIcon = Icons.manage_accounts_rounded;
      gradientColor1 = const Color(0xFF1B5E20);
      gradientColor2 = const Color(0xFF388E3C);
    } else if (isSuperAdmin) {
      roleIcon = Icons.admin_panel_settings_rounded;
      gradientColor1 = const Color(0xFF4A148C);
      gradientColor2 = const Color(0xFF7B1FA2);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientColor1, gradientColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradientColor1.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(roleIcon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _statItem('Total', totalOvertime, const Color(0xFF1A2B4C), Icons.event_rounded),
          _statDivider(),
          _statItem('Pending', pendingOvertime, const Color(0xFFF39C12), Icons.pending_rounded),
          _statDivider(),
          _statItem('Disetujui', approvedOvertime, const Color(0xFF3498DB), Icons.thumb_up_rounded),
          _statDivider(),
          _statItem('Selesai', completedOvertime, const Color(0xFF2ECC71), Icons.check_circle_rounded),
        ],
      ),
    );
  }

  Widget _statItem(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[200],
    );
  }

  Widget _buildCalendar() {
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
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
                final isSelected = isSameDay(date, _selectedDay);
                final isToday = isSameDay(date, DateTime.now());
                
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
                            : hasEvent
                                ? const Color(0xFFFF6B35).withValues(alpha: 0.08)
                                : isToday
                                    ? const Color(0xFF1A2B4C).withValues(alpha: 0.06)
                                    : null,
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: const Color(0xFF1A2B4C).withValues(alpha: 0.3),
                            width: 1.5,
                          )
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
                                    : hasEvent
                                        ? const Color(0xFFFF6B35)
                                        : Colors.grey[800],
                          ),
                        ),
                      ),
                      if (hasEvent && !isSelected)
                        Positioned(
                          bottom: 3,
                          right: 3,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6B35),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              todayBuilder: (context, date, _) {
                final isSelected = isSameDay(date, _selectedDay);
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
                        : const Color(0xFF1A2B4C).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: const Color(0xFF1A2B4C).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF1A2B4C),
                      ),
                    ),
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
                color: const Color(0xFF1A2B4C),
              ),
              leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1A2B4C)),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1A2B4C)),
              formatButtonTextStyle: GoogleFonts.poppins(fontSize: 12),
              formatButtonDecoration: BoxDecoration(
                color: const Color(0xFF1A2B4C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _legendItem(const Color(0xFFFF6B35), 'Ada Lembur'),
              _legendItem(Colors.red, 'Hari Libur'),
              _legendItem(const Color(0xFF1A2B4C), 'Hari Ini'),
              _legendItem(Colors.green, 'Selesai'),
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Cari mitra, fungsi, atau pengawas...',
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1A2B4C)),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () => setState(() => searchQuery = ''),
                )
              : null,
          border: InputBorder.none,
        ),
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'label': '📋 Semua', 'value': 'semua'},
      {'label': '📅 Mendatang', 'value': 'upcoming'},
      {'label': '✅ Selesai', 'value': 'completed'},
      {'label': '⚠️ Terlambat', 'value': 'late'},
      {'label': '🔄 Berlangsung', 'value': 'ongoing'},
      {'label': '🚫 Dibatalkan', 'value': 'cancelled'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final value = filter['value']!;
          final selected = executionFilter == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                filter['label']!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? Colors.white : Colors.grey[700],
                ),
              ),
              selected: selected,
              onSelected: (s) => setState(() {
                executionFilter = s ? value : 'semua';
                _applyAllFilters();
              }),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF1A2B4C),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: selected ? const Color(0xFF1A2B4C) : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              '📋 Daftar Lembur',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A2B4C),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2B4C).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${displayedOvertime.length} Data',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A2B4C),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOvertimeCard(OvertimeHistory overtime) {
    final executionStatus = _getOvertimeExecutionStatus(overtime);
    final color = _getExecutionStatusColor(executionStatus);
    
    return GestureDetector(
      onTap: () => _showOvertimeDetail(overtime),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    _getExecutionStatusIcon(executionStatus),
                    color: color,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                              color: const Color(0xFF1A2B4C),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // FIX 2: Menggunakan Flexible untuk mencegah overflow di card
                        Flexible(
                          child: _buildStatusBadge(executionStatus),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _overtimeService.formatTanggal(overtime.tanggal),
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${overtime.jamMulai} - ${overtime.jamSelesai}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          Text(
            'Tidak Ada Jadwal Lembur',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A2B4C),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Belum ada jadwal lembur yang tersedia',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF1A2B4C),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat data jadwal lembur...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== DRAG HANDLE WIDGET ====================
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

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