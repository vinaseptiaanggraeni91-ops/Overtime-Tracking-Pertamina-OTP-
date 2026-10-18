import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/mitra_service.dart';
import '../../core/services/overtime_absensi_service.dart' show OvertimeAbsensiService;
import '../../core/services/live_location_service.dart';
import '../absensi/absensi_dialog.dart';
import '../../core/services/overtime_history_service.dart';

class MitraAttendanceOvertimeCard extends StatefulWidget {
  final Map<String, dynamic>? attendanceData;
  final Map<String, dynamic>? overtime;
  final List<Map<String, dynamic>>? upcomingSchedules;
  final bool isCheckedIn;
  final bool isCheckedOut;
  final bool canCheckIn;
  final String formattedCheckInTime;
  final String userName;
  final Map<String, dynamic> overtimeSettings;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback? onViewAllSchedules;

  const MitraAttendanceOvertimeCard({
    super.key,
    this.attendanceData,
    this.overtime,
    this.upcomingSchedules,
    required this.isCheckedIn,
    required this.isCheckedOut,
    required this.canCheckIn,
    required this.formattedCheckInTime,
    required this.userName,
    required this.overtimeSettings,
    required this.onCheckIn,
    required this.onCheckOut,
    this.onViewAllSchedules,
  });

  @override
  State<MitraAttendanceOvertimeCard> createState() =>
      _MitraAttendanceOvertimeCardState();
}

class _MitraAttendanceOvertimeCardState
    extends State<MitraAttendanceOvertimeCard>
    with SingleTickerProviderStateMixin {

  final _service = MitraService();
  final _absensiService = OvertimeAbsensiService();

  bool _isLoadingAction = false;
  bool _showUpcomingExpanded = false;
  Timer? _statusCheckTimer;
  Timer? _countdownTimer;

  bool _canCheckOutNow = false;
  String _countdownText = '';
  bool _isCheckInTimeValid = false;
  bool _isLate = false;
  String _lateMessage = '';
  String _checkInWindowText = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Duration _checkinEarlyWindow = Duration(minutes: 10);
  static const Duration _checkoutEarlyWindow = Duration(minutes: 30);
  static const Duration _absensiNormalWindow = Duration(minutes: 30);
  static const Duration _gracePeriod = Duration(days: 3);

  // 🔥 CACHE: Hindari parsing berulang
  int? _cachedMulaiHour;
  int? _cachedMulaiMinute;
  int? _cachedSelesaiHour;
  int? _cachedSelesaiMinute;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _cacheOvertimeTimes();
    _updateTimeBasedStatus();
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (!mounted) {
          _statusCheckTimer?.cancel();
          return;
        }
        _updateTimeBasedStatus();
      },
    );
    _countdownTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) {
          _countdownTimer?.cancel();
          return;
        }
        _updateTimeBasedStatus();
        _updateCountdown();
      },
    );
    _updateCountdown();
  }

  @override
  void didUpdateWidget(MitraAttendanceOvertimeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🔥 Deteksi perubahan status check-out, absensi, dan data overtime
    if (oldWidget.isCheckedOut != widget.isCheckedOut ||
        oldWidget.isCheckedIn != widget.isCheckedIn ||
        oldWidget.overtime?['absensi_status'] != widget.overtime?['absensi_status'] ||
        oldWidget.overtime?['status'] != widget.overtime?['status'] ||
        oldWidget.overtime != widget.overtime) {
      _cacheOvertimeTimes(); // Refresh cache
      _updateTimeBasedStatus();
      _updateCountdown();
    }
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // 🔥 Cache waktu untuk hindari parsing berulang
  void _cacheOvertimeTimes() {
    final overtime = widget.overtime;
    if (overtime == null) {
      _cachedMulaiHour = null;
      _cachedMulaiMinute = null;
      _cachedSelesaiHour = null;
      _cachedSelesaiMinute = null;
      return;
    }

    final jamMulai = overtime['jam_mulai']?.toString() ?? '19:00';
    final jamSelesai = overtime['jam_selesai']?.toString() ?? '22:00';

    final partsMulai = jamMulai.split(':');
    if (partsMulai.length == 2) {
      _cachedMulaiHour = int.tryParse(partsMulai[0]) ?? 19;
      _cachedMulaiMinute = int.tryParse(partsMulai[1]) ?? 0;
    }

    final partsSelesai = jamSelesai.split(':');
    if (partsSelesai.length == 2) {
      _cachedSelesaiHour = int.tryParse(partsSelesai[0]) ?? 22;
      _cachedSelesaiMinute = int.tryParse(partsSelesai[1]) ?? 0;
    }
  }

  // 🔥 Helper: Cek apakah lembur sudah selesai
  bool get _isOvertimeCompleted {
    if (widget.isCheckedOut) return true;
    final absensiStatus = widget.overtime?['absensi_status']?.toString() ?? '';
    final status = widget.overtime?['status']?.toString() ?? '';
    return absensiStatus == 'selesai' ||
           absensiStatus == 'selesai_terlambat' ||
           status == 'selesai' ||
           status == 'completed';
  }

  void _updateTimeBasedStatus() {
    if (!mounted) return;
    
    // 🔥🔥🔥 PERBAIKAN: Jika sudah selesai, reset semua status & jangan kalkulasi
    if (_isOvertimeCompleted) {
      _isCheckInTimeValid = false;
      _canCheckOutNow = false;
      _isLate = false;
      _lateMessage = '';
      _checkInWindowText = '';
      _countdownText = '';
      if (mounted) setState(() {});
      return;
    }
    
    final now = DateTime.now();
    _isCheckInTimeValid = _calculateCheckInValidity();
    _canCheckOutNow = _calculateCanCheckOut(now);
    _isLate = _calculateIsLate(now);
    _updateCheckInWindowText();
    _updateCountdown();
    if (mounted) setState(() {});
  }

  bool _calculateCheckInValidity() {
    if (widget.overtime == null) return false;
    if (_cachedMulaiHour == null || _cachedSelesaiHour == null) return false;

    final now = DateTime.now();
    final checkInStart = DateTime(now.year, now.month, now.day, _cachedMulaiHour!, _cachedMulaiMinute!)
        .subtract(_checkinEarlyWindow);
    final jamSelesaiTime = DateTime(now.year, now.month, now.day, _cachedSelesaiHour!, _cachedSelesaiMinute!);
    final batasNormal = jamSelesaiTime.add(_absensiNormalWindow);

    return (now.isAfter(checkInStart) || now.isAtSameMomentAs(checkInStart)) &&
        now.isBefore(batasNormal);
  }

  bool _calculateCanCheckOut(DateTime now) {
    if (!widget.isCheckedIn || widget.isCheckedOut || widget.overtime == null) {
      return false;
    }
    if (_cachedSelesaiHour == null) return false;

    final checkOutStart = DateTime(now.year, now.month, now.day, _cachedSelesaiHour!, _cachedSelesaiMinute!)
        .subtract(_checkoutEarlyWindow);
    final checkOutEnd = DateTime(now.year, now.month, now.day, _cachedSelesaiHour!, _cachedSelesaiMinute!)
        .add(_absensiNormalWindow);

    return now.isAfter(checkOutStart) && now.isBefore(checkOutEnd);
  }

  bool _calculateIsLate(DateTime now) {
    // 🔥🔥🔥 PERBAIKAN: Jika sudah check-out atau selesai, TIDAK terlambat
    if (_isOvertimeCompleted) return false;
    if (widget.overtime == null) return false;
    if (widget.isCheckedIn) return false;
    if (_cachedSelesaiHour == null) return false;

    final jamSelesaiTime = DateTime(now.year, now.month, now.day, _cachedSelesaiHour!, _cachedSelesaiMinute!);
    final batasNormal = jamSelesaiTime.add(_absensiNormalWindow);
    final batasExpired = jamSelesaiTime.add(_gracePeriod);

    final isExpired = now.isAfter(batasExpired);
    final isLate = now.isAfter(batasNormal) && now.isBefore(batasExpired);

    if (isExpired) {
      _lateMessage = '⏰ Sudah kadaluarsa (>3 hari)';
    } else if (isLate) {
      final diff = batasExpired.difference(now);
      final hoursLeft = diff.inHours;
      _lateMessage = '⚠️ Terlambat! Konfirmasi sebelum ${hoursLeft}j lagi';
    }

    return isLate || isExpired;
  }

  void _updateCheckInWindowText() {
    if (widget.overtime == null || _isOvertimeCompleted) {
      _checkInWindowText = '';
      return;
    }
    if (_cachedMulaiHour == null) {
      _checkInWindowText = '';
      return;
    }

    final now = DateTime.now();
    final checkInStart = DateTime(now.year, now.month, now.day, _cachedMulaiHour!, _cachedMulaiMinute!)
        .subtract(_checkinEarlyWindow);

    if (now.isBefore(checkInStart)) {
      final diff = checkInStart.difference(now);
      if (diff.inHours > 0) {
        _checkInWindowText = 'Check-in dibuka ${diff.inHours}j ${diff.inMinutes.remainder(60)}m lagi';
      } else {
        _checkInWindowText = 'Check-in dibuka ${diff.inMinutes}m lagi';
      }
    } else {
      _checkInWindowText = '';
    }
  }

  void _updateCountdown() {
    if (!widget.isCheckedIn || widget.isCheckedOut || widget.overtime == null || _isOvertimeCompleted) {
      _countdownText = '';
      return;
    }
    if (_cachedSelesaiHour == null) {
      _countdownText = '';
      return;
    }

    final now = DateTime.now();
    final jamSelesaiTime = DateTime(now.year, now.month, now.day, _cachedSelesaiHour!, _cachedSelesaiMinute!);
    final checkOutStart = jamSelesaiTime.subtract(_checkoutEarlyWindow);
    final difference = checkOutStart.difference(now);

    if (difference.isNegative) {
      _countdownText = '✅ Check-out tersedia sekarang!';
    } else {
      final hours = difference.inHours;
      final minutes = difference.inMinutes.remainder(60);
      if (hours > 0) {
        _countdownText = '⏳ $hours jam $minutes menit lagi';
      } else if (minutes > 0) {
        _countdownText = '⏳ $minutes menit lagi';
      } else {
        _countdownText = '⏳ Sebentar lagi';
      }
    }
  }

  void _navigateToAbsensiPage() {
    if (!mounted) return;
    context.push('/mitra-absensi');
  }

  Future<void> _handleCheckOut() async {
    // 🔥 Cegah double tap
    if (_isLoadingAction) return;
    if (!_canCheckOutNow) {
      _showSnackBar('⚠️ Belum waktunya check-out.', false);
      return;
    }

    final overtime = widget.overtime;
    if (overtime == null) {
      _showSnackBar('Data lembur tidak tersedia', false);
      return;
    }

    setState(() => _isLoadingAction = true);

    try {
      final lemburId = overtime['id']?.toString() ?? '';
      final statusCheck = await _absensiService.cekStatusKeterlambatan(lemburId);

      if (statusCheck['isAlreadyResolved'] == true) {
        if (mounted) _showSnackBar('Absensi sudah diproses sebelumnya', false);
        return;
      }

      if (statusCheck['isCancelled'] == true) {
        if (mounted) {
          _showSnackBar('⚠️ Lembur telah dibatalkan oleh pengawas', false);
          widget.onCheckOut();
          _navigateToAbsensiPage();
        }
        return;
      }

      final absensiSuccess = await AbsensiDialog.show(
        context,
        OvertimeHistory.fromMap(overtime, lemburId),
        isCheckOut: true,
      );

      if (absensiSuccess == true && mounted) {
        await LiveLocationService().stopTracking();

        final userId = overtime['mitra_id']?.toString() ??
            overtime['user_id']?.toString() ?? '';
        final existingFotoUrl = overtime['check_in_foto_url']?.toString() ??
            overtime['check_in_foto']?.toString() ?? '';

        final result = await _absensiService.submitCheckOut(
          docId: lemburId,
          userId: userId,
          userName: widget.userName,
          fotoUrl: existingFotoUrl,
        );

        if (result['success'] == true && mounted) {
          widget.onCheckOut();
          _showSnackBar(
            '✅ Check-out berhasil! Total: ${(result['totalJamReal'] as num?)?.toStringAsFixed(1) ?? '0'} jam',
            true,
          );
          _navigateToAbsensiPage();
        } else {
          if (mounted) _showSnackBar(result['message'] ?? 'Gagal check-out', false);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Gagal check-out: $e', false);
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  void _handleCheckIn() {
    widget.onCheckIn();
    _navigateToAbsensiPage();
  }

  void _showSnackBar(String message, bool success) {
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.2),
                ),
              ),
            ],
          ),
          backgroundColor: success ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).size.height * 0.12),
          duration: const Duration(seconds: 4),
          elevation: 8,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final futureSchedules = widget.upcomingSchedules
            ?.where((s) => _calculateDaysLeft(s['date']?.toString() ?? '') > 0)
            .toList() ?? [];

    if (widget.overtime == null && futureSchedules.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (widget.overtime != null) _buildOvertimeCheckCard(),
        if (futureSchedules.isNotEmpty) ...[
          if (widget.overtime != null) const SizedBox(height: 16),
          _buildFutureScheduleCard(futureSchedules),
        ],
      ],
    );
  }

  Widget _buildOvertimeCheckCard() {
    final overtime = widget.overtime!;
    final jamMulai = overtime['jam_mulai']?.toString() ?? '19:00';
    final jamSelesai = overtime['jam_selesai']?.toString() ?? '22:00';
    final durasi = _service.formatDuration(jamMulai, jamSelesai);
    final isHoliday = overtime['is_holiday'] == true;
    final estimatedIncome = _service.estimateIncomeFromSchedule(jamMulai, jamSelesai, isHoliday: isHoliday);

    final List<Color> cardColors;
    final String titleText;
    final IconData titleIcon;

    // 🔥🔥🔥 PERBAIKAN: Cek completed DULU sebelum status lainnya
    if (_isOvertimeCompleted) {
      cardColors = [const Color(0xFF1B5E20), const Color(0xFF2E7D32), const Color(0xFF43A047)];
      titleText = '✅ Lembur Selesai';
      titleIcon = Icons.check_circle_rounded;
    } else if (widget.isCheckedIn) {
      cardColors = [const Color(0xFFB71C1C), const Color(0xFFE53935), const Color(0xFFEF5350)];
      titleText = 'Sedang Lembur';
      titleIcon = Icons.logout_rounded;
    } else if (_isLate) {
      cardColors = [const Color(0xFFE65100), const Color(0xFFFF6D00), const Color(0xFFFF9100)];
      titleText = '⚠️ Lembur Terlambat';
      titleIcon = Icons.warning_amber_rounded;
    } else {
      cardColors = [const Color(0xFF1B5E20), const Color(0xFF2E7D32), const Color(0xFF43A047)];
      titleText = 'Lembur Hari Ini';
      titleIcon = Icons.login_rounded;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cardColors.first.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: cardColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(titleIcon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$jamMulai - $jamSelesai ($durasi)',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // 🔥 Jika selesai, tampilkan badge tanpa action button
                    if (_isOvertimeCompleted)
                      _buildCompletedBadge()
                    else
                      _buildActionButtonByStatus(),
                  ],
                ),
                // 🔥 Jika selesai, tampilkan info pendapatan
                if (_isOvertimeCompleted && estimatedIncome > 0)
                  _buildCompletedIncomeBar(estimatedIncome),
                // Status bar untuk kondisi lain
                if (!_isOvertimeCompleted && !widget.isCheckedIn && _isLate)
                  _buildLateStatusBar(),
                if (!_isOvertimeCompleted && !widget.isCheckedIn && !_isLate && _checkInWindowText.isNotEmpty)
                  _buildCheckInWindowBar(estimatedIncome),
                if (!_isOvertimeCompleted && !widget.isCheckedIn && !_isLate && _checkInWindowText.isEmpty && widget.canCheckIn && _isCheckInTimeValid)
                  _buildReadyBar(estimatedIncome),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 Badge untuk lembur selesai
  Widget _buildCompletedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text(
            'SELESAI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 Info pendapatan untuk lembur selesai
  Widget _buildCompletedIncomeBar(double estimatedIncome) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.monetization_on, color: Colors.yellowAccent, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Estimasi Pendapatan:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const Spacer(),
            Text(
              _service.formatRupiahCompact(estimatedIncome),
              style: const TextStyle(
                color: Colors.yellowAccent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLateStatusBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _lateMessage,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInWindowBar(double estimatedIncome) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _checkInWindowText,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
            if (estimatedIncome > 0)
              Text(
                _service.formatRupiahCompact(estimatedIncome),
                style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyBar(double estimatedIncome) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '✅ Check-in tersedia sekarang!',
                style: TextStyle(color: Colors.greenAccent, fontSize: 11),
              ),
            ),
            if (estimatedIncome > 0)
              Text(
                _service.formatRupiahCompact(estimatedIncome),
                style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonByStatus() {
    if (widget.isCheckedIn) {
      if (_canCheckOutNow) {
        return ScaleTransition(
          scale: _pulseAnimation,
          child: _buildActionButton(
            'Check Out',
            Icons.logout_rounded,
            const Color(0xFFE53935),
            _isLoadingAction,
            _handleCheckOut,
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_bottom_rounded, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _countdownText.isNotEmpty ? _countdownText : 'Menunggu...',
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis, // 🔥 Perbaikan: ellipsis
              ),
            ),
          ],
        ),
      );
    }

    if (widget.canCheckIn && _isCheckInTimeValid) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: _buildActionButton(
          _isLate ? 'Konfirmasi' : 'Check In',
          _isLate ? Icons.warning_amber_rounded : Icons.login_rounded,
          _isLate ? const Color(0xFFFF6D00) : const Color(0xFF43A047),
          _isLoadingAction,
          _handleCheckIn,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _checkInWindowText.isNotEmpty ? _checkInWindowText : 'Mulai ${widget.formattedCheckInTime}',
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis, // 🔥 Perbaikan: ellipsis
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, bool isLoading, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else
                Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  isLoading ? 'Memproses...' : label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFutureScheduleCard(List<Map<String, dynamic>> futureSchedules) {
    final hasManySchedules = futureSchedules.length > 2;
    final maxDisplay = 10; // 🔥 Batasi maksimal tampilan
    final displaySchedules = _showUpcomingExpanded 
        ? futureSchedules.take(maxDisplay).toList() 
        : futureSchedules.take(2).toList();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A1B9A).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFutureScheduleHeader(futureSchedules),
                const SizedBox(height: 16),
                ...displaySchedules.asMap().entries.map(
                      (entry) => _buildScheduleItem(entry.value),
                    ),
                if (hasManySchedules) ...[
                  const SizedBox(height: 8),
                  _buildExpandButton(futureSchedules),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFutureScheduleHeader(List<Map<String, dynamic>> futureSchedules) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.event_rounded, color: Colors.yellowAccent, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Jadwal Mendatang',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis, // 🔥 Perbaikan
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.yellowAccent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${futureSchedules.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF4A148C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Persiapkan diri untuk lembur berikutnya! 💪',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis, // 🔥 Perbaikan
              ),
            ],
          ),
        ),
        if (widget.onViewAllSchedules != null) ...[
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onViewAllSchedules,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExpandButton(List<Map<String, dynamic>> futureSchedules) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _showUpcomingExpanded = !_showUpcomingExpanded;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _showUpcomingExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _showUpcomingExpanded ? 'Sembunyikan' : 'Lihat ${futureSchedules.length - 2} jadwal lainnya',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    final date = schedule['date']?.toString() ?? '';
    final jamMulai = schedule['jam_mulai']?.toString() ?? '--:--';
    final jamSelesai = schedule['jam_selesai']?.toString() ?? '--:--';
    final description = schedule['description']?.toString() ?? '';
    final status = schedule['status']?.toString() ?? 'scheduled';
    final int daysLeft = _calculateDaysLeft(date);
    final bool isTomorrow = daysLeft == 1;
    final Color statusColor = status == 'in_progress'
        ? const Color(0xFFFF6B35)
        : status == 'completed'
            ? const Color(0xFF00C853)
            : const Color(0xFFFFAB40);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor, statusColor.withOpacity(0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          description,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis, // 🔥 Perbaikan
                        ),
                      ),
                      if (isTomorrow)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: const Text(
                            'BESOK',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _buildInfoChip(Icons.access_time_rounded, '$jamMulai - $jamSelesai'),
                    _buildInfoChip(Icons.calendar_today_rounded, date),
                    if (daysLeft > 0 && daysLeft <= 7)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.yellowAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$daysLeft hari lagi',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.yellowAccent.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white60),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  int _calculateDaysLeft(String dateStr) {
    try {
      if (dateStr.isEmpty) return 999;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // 🔥 Coba beberapa format tanggal
      DateTime? scheduleDate;
      final formats = ['dd MMM yyyy', 'yyyy-MM-dd', 'dd/MM/yyyy'];
      for (final fmt in formats) {
        try {
          scheduleDate = DateFormat(fmt, 'id_ID').parse(dateStr);
          break;
        } catch (_) {}
      }
      
      if (scheduleDate == null) return 999;
      final scheduleDay = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);
      return scheduleDay.difference(today).inDays;
    } catch (e) {
      debugPrint('❌ Error parsing date: $dateStr -> $e');
      return 999;
    }
  }
}