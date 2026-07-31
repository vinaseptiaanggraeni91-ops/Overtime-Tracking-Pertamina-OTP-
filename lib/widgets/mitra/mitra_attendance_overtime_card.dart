import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/mitra_service.dart';
import '../../core/services/overtime_absensi_service.dart' show OvertimeAbsensiService;
import '../../core/services/overtime_history_service.dart';
import '../../core/services/live_location_service.dart';
import '/widgets/absensi/absensi_dialog.dart';

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
  
  // ═══════════════════════════════════════════════════════
  // 🔥 STATE BARU - KONSISTEN DENGAN ABSENSI PAGE
  // ═══════════════════════════════════════════════════════
  bool _canCheckOutNow = false;
  String _countdownText = '';
  bool _isCheckInTimeValid = false;
  bool _isLate = false;            // 🔥 Status terlambat
  String _lateMessage = '';        // 🔥 Pesan keterlambatan
  String _checkInWindowText = '';  // 🔥 Teks jendela check-in
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ═══════════════════════════════════════════════════════
  // 🔥 CONSTANTS - KONSISTEN DENGAN ABSENSI PAGE
  // ═══════════════════════════════════════════════════════
  static const Duration _checkinEarlyWindow = Duration(minutes: 10);
  static const Duration _checkoutEarlyWindow = Duration(minutes: 30);
  static const Duration _absensiNormalWindow = Duration(minutes: 30);
  static const Duration _gracePeriod = Duration(days: 3);

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
    _updateTimeBasedStatus();
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateTimeBasedStatus(),
    );
    _countdownTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        _updateTimeBasedStatus();
        _updateCountdown();
      },
    );
    _updateCountdown();
  }

  @override
  void didUpdateWidget(MitraAttendanceOvertimeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCheckedIn != widget.isCheckedIn || 
        oldWidget.overtime != widget.overtime) {
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

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 UPDATE STATUS WAKTU - KONSISTEN
  // ═══════════════════════════════════════════════════════
  void _updateTimeBasedStatus() {
    if (!mounted) return;
    final now = DateTime.now();
    _isCheckInTimeValid = _calculateCheckInValidity();
    _canCheckOutNow = _calculateCanCheckOut(now);
    _isLate = _calculateIsLate(now);
    _updateCheckInWindowText();
    _updateCountdown();
    if (mounted) setState(() {});
  }

  /// 🔥 Check-in valid: 10 menit SEBELUM jam mulai sampai 30 menit SETELAH jam selesai
  bool _calculateCheckInValidity() {
    if (widget.overtime == null) return false;
    
    final jamMulai = widget.overtime!['jam_mulai']?.toString() ?? '19:00';
    final jamSelesai = widget.overtime!['jam_selesai']?.toString() ?? '22:00';
    final now = DateTime.now();
    
    final partsMulai = jamMulai.split(':');
    final partsSelesai = jamSelesai.split(':');
    if (partsMulai.length != 2 || partsSelesai.length != 2) return false;
    
    final mulaiHour = int.tryParse(partsMulai[0]) ?? 19;
    final mulaiMinute = int.tryParse(partsMulai[1]) ?? 0;
    final selesaiHour = int.tryParse(partsSelesai[0]) ?? 22;
    final selesaiMinute = int.tryParse(partsSelesai[1]) ?? 0;
    
    // 🔥 Check-in start: 10 menit sebelum jam mulai (KONSISTEN)
    final checkInStart = DateTime(now.year, now.month, now.day, mulaiHour, mulaiMinute)
        .subtract(_checkinEarlyWindow);
    
    // 🔥 Batas normal: 30 menit setelah jam selesai
    final jamSelesaiTime = DateTime(now.year, now.month, now.day, selesaiHour, selesaiMinute);
    final batasNormal = jamSelesaiTime.add(_absensiNormalWindow);
    
    return (now.isAfter(checkInStart) || now.isAtSameMomentAs(checkInStart)) &&
           now.isBefore(batasNormal);
  }

  /// 🔥 Check-out valid: 30 menit SEBELUM jam selesai
  bool _calculateCanCheckOut(DateTime now) {
    if (!widget.isCheckedIn || widget.isCheckedOut || widget.overtime == null) {
      return false;
    }
    
    final jamSelesai = widget.overtime!['jam_selesai']?.toString() ?? '22:00';
    final parts = jamSelesai.split(':');
    if (parts.length != 2) return false;
    
    final hour = int.tryParse(parts[0]) ?? 22;
    final minute = int.tryParse(parts[1]) ?? 0;
    
    // 🔥 Check-out start: 30 menit sebelum jam selesai (KONSISTEN)
    final checkOutStart = DateTime(now.year, now.month, now.day, hour, minute)
        .subtract(_checkoutEarlyWindow);
    
    // 🔥 Check-out end: 30 menit setelah jam selesai
    final checkOutEnd = DateTime(now.year, now.month, now.day, hour, minute)
        .add(_absensiNormalWindow);
    
    return now.isAfter(checkOutStart) && now.isBefore(checkOutEnd);
  }

  /// 🔥 Deteksi keterlambatan: sudah lewat 30 menit setelah jam selesai
  bool _calculateIsLate(DateTime now) {
    if (widget.overtime == null) return false;
    if (widget.isCheckedIn) return false; // Kalau udah check-in, nggak terlambat
    
    final jamSelesai = widget.overtime!['jam_selesai']?.toString() ?? '22:00';
    final parts = jamSelesai.split(':');
    if (parts.length != 2) return false;
    
    final hour = int.tryParse(parts[0]) ?? 22;
    final minute = int.tryParse(parts[1]) ?? 0;
    
    final jamSelesaiTime = DateTime(now.year, now.month, now.day, hour, minute);
    final batasNormal = jamSelesaiTime.add(_absensiNormalWindow);
    final batasExpired = jamSelesaiTime.add(_gracePeriod);
    
    final isLate = now.isAfter(batasNormal) && now.isBefore(batasExpired);
    final isExpired = now.isAfter(batasExpired);
    
    if (isExpired) {
      _lateMessage = '⏰ Sudah kadaluarsa (>3 hari)';
    } else if (isLate) {
      final diff = batasExpired.difference(now);
      final hoursLeft = diff.inHours;
      _lateMessage = '⚠️ Terlambat! Konfirmasi sebelum ${hoursLeft}j lagi';
    }
    
    return isLate || isExpired;
  }

  /// 🔥 Teks jendela check-in
  void _updateCheckInWindowText() {
    if (widget.overtime == null) {
      _checkInWindowText = '';
      return;
    }
    
    final now = DateTime.now();
    final jamMulai = widget.overtime!['jam_mulai']?.toString() ?? '19:00';
    final parts = jamMulai.split(':');
    if (parts.length != 2) {
      _checkInWindowText = '';
      return;
    }
    
    final hour = int.tryParse(parts[0]) ?? 19;
    final minute = int.tryParse(parts[1]) ?? 0;
    
    final checkInStart = DateTime(now.year, now.month, now.day, hour, minute)
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

  /// 🔥 Update countdown check-out
  void _updateCountdown() {
    if (!widget.isCheckedIn || widget.isCheckedOut || widget.overtime == null) {
      _countdownText = '';
      return;
    }
    
    final now = DateTime.now();
    final jamSelesai = widget.overtime!['jam_selesai']?.toString() ?? '22:00';
    final parts = jamSelesai.split(':');
    if (parts.length != 2) {
      _countdownText = '';
      return;
    }
    
    final hour = int.tryParse(parts[0]) ?? 22;
    final minute = int.tryParse(parts[1]) ?? 0;
    final jamSelesaiTime = DateTime(now.year, now.month, now.day, hour, minute);
    
    // 🔥 Check-out start: 30 menit sebelum jam selesai (KONSISTEN)
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

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 NAVIGASI KE /mitra-absensi (LANGSUNG)
  // ═══════════════════════════════════════════════════════
  void _navigateToAbsensiPage() {
    if (!mounted) return;
    // 🔥 LANGSUNG arahkan ke absensi page, tanpa delay
    context.push('/mitra-absensi');
  }

  /// 🔥🔥🔥 HANDLE CHECK-OUT
  Future<void> _handleCheckOut() async {
    if (!_canCheckOutNow) {
      _showSnackBar('⚠️ Belum waktunya check-out. Tunggu hingga 30 menit sebelum jam selesai.', false);
      return;
    }
    
    setState(() => _isLoadingAction = true);
    
    try {
      final overtimeItem = await OvertimeHistoryService().getOvertimeById(widget.overtime!['id']);
      if (overtimeItem == null) {
        if (mounted) _showSnackBar('Data lembur tidak ditemukan', false);
        return;
      }
      
      final statusCheck = await _absensiService.cekStatusKeterlambatan(widget.overtime!['id']);
      if (statusCheck['isAlreadyResolved'] == true) {
        if (mounted) _showSnackBar('Absensi sudah diproses sebelumnya', false);
        return;
      }
      
      // 🔥 Cek apakah lembur dibatalkan
      if (statusCheck['isCancelled'] == true) {
        if (mounted) {
          _showSnackBar('⚠️ Lembur telah dibatalkan oleh pengawas', false);
          widget.onCheckOut(); // Trigger refresh
          _navigateToAbsensiPage();
        }
        return;
      }
      
      final absensiSuccess = await AbsensiDialog.show(context, overtimeItem);
      if (absensiSuccess == true && mounted) {
        await LiveLocationService().stopTracking();
        
        final result = await _absensiService.submitCheckOut(
          docId: widget.overtime!['id'],
          userId: overtimeItem.mitraId ?? '',
          userName: widget.userName,
          fotoUrl: overtimeItem.checkInFotoUrl ?? '',
        );
        
        if (result['success'] == true && mounted) {
          widget.onCheckOut();
          _showSnackBar(
            '✅ Check-out berhasil! Total: ${(result['totalJamReal'] as num?)?.toStringAsFixed(1) ?? '0'} jam',
            true,
          );
          // 🔥 LANGSUNG NAVIGASI KE ABSENSI PAGE
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

  /// 🔥🔥🔥 HANDLE CHECK-IN (LANGSUNG KE ABSENSI PAGE)
  void _handleCheckIn() {
    widget.onCheckIn();
    // 🔥 LANGSUNG arahkan ke absensi page
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
                  color: Colors.white.withValues(alpha: 0.2),
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

  // ═══════════════════════════════════════════════════════
  // 🔥🔥🔥 BUILD OVERTIME CARD - DENGAN STATUS TERLAMBAT
  // ═══════════════════════════════════════════════════════
  Widget _buildOvertimeCheckCard() {
    final overtime = widget.overtime!;
    final jamMulai = overtime['jam_mulai']?.toString() ?? '19:00';
    final jamSelesai = overtime['jam_selesai']?.toString() ?? '22:00';
    final durasi = _service.formatDuration(jamMulai, jamSelesai);
    final isHoliday = overtime['is_holiday'] == true;
    final estimatedIncome = _service.estimateIncomeFromSchedule(jamMulai, jamSelesai, isHoliday: isHoliday);
    
    // 🔥 Tentukan warna card berdasarkan status
    final List<Color> cardColors;
    final String titleText;
    final IconData titleIcon;
    
    if (widget.isCheckedIn) {
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
              color: cardColors.first.withValues(alpha: 0.3),
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
                // ═══════════════════════════════════════
                // ROW UTAMA
                // ═══════════════════════════════════════
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
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
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _buildActionButtonByStatus(),
                  ],
                ),
                
                // ═══════════════════════════════════════
                // 🔥 STATUS BAR - CHECK-IN WINDOW / LATE
                // ═══════════════════════════════════════
                if (!widget.isCheckedIn && _isLate) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200.withValues(alpha: 0.5)),
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
                ] else if (!widget.isCheckedIn && _checkInWindowText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
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
                ] else if (!widget.isCheckedIn && widget.canCheckIn && _isCheckInTimeValid) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔥 ACTION BUTTON BY STATUS
  // ═══════════════════════════════════════════════════════
  Widget _buildActionButtonByStatus() {
    // 🔥 CHECKED IN - TAMPILKAN CHECK-OUT JIKA SUDAH WAKTUNYA
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
      // 🔥 Countdown check-out
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
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
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      );
    }
    
    // 🔥 CHECK-IN TERSEDIA
    if (widget.canCheckIn && _isCheckInTimeValid) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: _buildActionButton(
          _isLate ? 'Konfirmasi' : 'Check In',
          _isLate ? Icons.warning_amber_rounded : Icons.login_rounded,
          _isLate ? const Color(0xFFFF6D00) : const Color(0xFF43A047),
          _isLoadingAction,
          _handleCheckIn, // 🔥 LANGSUNG KE ABSENSI PAGE
        ),
      );
    }
    
    // 🔥 BELUM WAKTUNYA
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _checkInWindowText.isNotEmpty 
                  ? _checkInWindowText 
                  : 'Mulai ${widget.formattedCheckInTime}',
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label, IconData icon, Color color, bool isLoading, VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  isLoading ? 'Memproses...' : label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 JADWAL MENDATANG (TETAP SAMA)
  // ============================================================
  Widget _buildFutureScheduleCard(List<Map<String, dynamic>> futureSchedules) {
    final hasManySchedules = futureSchedules.length > 2;
    final displaySchedules = _showUpcomingExpanded ? futureSchedules : futureSchedules.take(2).toList();
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.scale(scale: 0.95 + (0.05 * value), child: Opacity(opacity: value, child: child));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFF6A1B9A).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
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
                                child: Text('Jadwal Mendatang', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.visible, maxLines: 1),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.yellowAccent.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
                                child: Text('${futureSchedules.length}', style: const TextStyle(fontSize: 10, color: Color(0xFF4A148C), fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Persiapkan diri untuk lembur berikutnya! 💪', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontStyle: FontStyle.italic), maxLines: 3, overflow: TextOverflow.visible),
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
                          child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                ...displaySchedules.asMap().entries.map((entry) => _buildScheduleItem(entry.value, entry.key)),
                if (hasManySchedules) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _showUpcomingExpanded = !_showUpcomingExpanded),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_showUpcomingExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 20),
                            const SizedBox(width: 8),
                            Text(_showUpcomingExpanded ? 'Sembunyikan' : 'Lihat ${futureSchedules.length - 2} jadwal lainnya', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule, int index) {
    final date = schedule['date']?.toString() ?? '';
    final jamMulai = schedule['jam_mulai']?.toString() ?? '--:--';
    final jamSelesai = schedule['jam_selesai']?.toString() ?? '--:--';
    final description = schedule['description']?.toString() ?? '';
    final status = schedule['status']?.toString() ?? 'scheduled';
    final int daysLeft = _calculateDaysLeft(date);
    final bool isTomorrow = daysLeft == 1;
    final Color statusColor = status == 'in_progress' ? const Color(0xFFFF6B35) : status == 'completed' ? const Color(0xFF00C853) : const Color(0xFFFFAB40);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 60, decoration: BoxDecoration(gradient: LinearGradient(colors: [statusColor, statusColor.withValues(alpha: 0.5)], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.2), maxLines: 3, overflow: TextOverflow.visible)),
                      if (isTomorrow) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6D00), Color(0xFFFFAB40)]), borderRadius: BorderRadius.circular(8)), child: const Text('BESOK', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Wrap(
                  spacing: 10, runSpacing: 6,
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.access_time_rounded, size: 12, color: Colors.white60), const SizedBox(width: 4), Text('$jamMulai - $jamSelesai', style: const TextStyle(fontSize: 11, color: Colors.white70))])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_today_rounded, size: 11, color: Colors.white60), const SizedBox(width: 4), Text(date, style: const TextStyle(fontSize: 11, color: Colors.white70))])),
                    if (daysLeft > 0 && daysLeft <= 7) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.yellowAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Text('$daysLeft hari lagi', style: TextStyle(fontSize: 9, color: Colors.yellowAccent.withValues(alpha: 0.9), fontWeight: FontWeight.w600))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _calculateDaysLeft(String dateStr) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final scheduleDate = DateFormat('dd MMM yyyy', 'id_ID').parse(dateStr);
      final scheduleDay = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);
      return scheduleDay.difference(today).inDays;
    } catch (e) {
      return 999;
    }
  }
}