// lib/widgets/ajukan_lembur/waktu_section.dart
import 'package:flutter/material.dart';
import 'section_card.dart';

class WaktuSection extends StatelessWidget {
  // 🔥 DATA — Sekarang pakai rentang tanggal
  final DateTime? tanggalMulai;
  final DateTime? tanggalSelesai;
  final TimeOfDay? jamMulai;
  final TimeOfDay? jamSelesai;
  final double totalJam;
  
  // 🔥 FLAGS untuk UI
  final bool isMultiDay;
  final bool isOvernight;

  // 🔥 CALLBACKS — Update untuk rentang
  final Function(DateTime?) onTanggalMulaiChanged;
  final Function(DateTime?) onTanggalSelesaiChanged;
  final Function(TimeOfDay) onJamMulaiChanged;
  final Function(TimeOfDay) onJamSelesaiChanged;
  final VoidCallback onClear;
  
  // 🔥 FORMATTERS
  final String Function(TimeOfDay) formatTime;
  final String Function(DateTime) formatTanggal;
  
  // 🔥 HOLIDAY CHECKERS
  final bool Function(DateTime)? isHoliday;
  final Map<DateTime, String>? holidays;

  const WaktuSection({
    super.key,
    this.tanggalMulai,
    this.tanggalSelesai,
    this.jamMulai,
    this.jamSelesai,
    required this.totalJam,
    this.isMultiDay = false,
    this.isOvernight = false,
    required this.onTanggalMulaiChanged,
    required this.onTanggalSelesaiChanged,
    required this.onJamMulaiChanged,
    required this.onJamSelesaiChanged,
    required this.onClear,
    required this.formatTime,
    required this.formatTanggal,
    this.isHoliday,
    this.holidays,
  });

  // ==================== COMPUTED ====================
  bool get _hasTanggalMulai => tanggalMulai != null;
  bool get _hasTanggalSelesai => tanggalSelesai != null;
  bool get _hasWaktu => jamMulai != null && jamSelesai != null;
  bool get _isComplete => _hasTanggalMulai && _hasTanggalSelesai && _hasWaktu;

  /// Cek apakah tanggal libur (weekend atau tanggal merah)
  bool _isLibur(DateTime date) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return true;
    }
    if (holidays != null) {
      final normalized = DateTime(date.year, date.month, date.day);
      return holidays!.containsKey(normalized);
    }
    if (isHoliday != null) {
      return isHoliday!(date);
    }
    return false;
  }

  /// Jam minimal lembur (hari kerja: 17:00, libur: 00:00)
  TimeOfDay _getMinJamLembur(DateTime date) {
    if (_isLibur(date)) return const TimeOfDay(hour: 0, minute: 0);
    return const TimeOfDay(hour: 17, minute: 0);
  }

  /// Status warna untuk tanggal (merah/libur/biasa)
  Color _getDateColor(DateTime? date) {
    if (date == null) return const Color(0xFF94A3B8);
    final normalized = DateTime(date.year, date.month, date.day);
    if (holidays != null && holidays!.containsKey(normalized)) {
      return const Color(0xFFE53935);
    }
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return const Color(0xFFFF9800);
    }
    return const Color(0xFF1976D2);
  }

  String _getDateLabel(DateTime? date) {
    if (date == null) return '';
    final normalized = DateTime(date.year, date.month, date.day);
    if (holidays != null && holidays!.containsKey(normalized)) {
      return '🔴 Tanggal Merah';
    }
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return '🟠 Hari Libur';
    }
    return '🔵 Hari Kerja';
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SectionCard(
      title: 'Waktu Lembur',
      icon: Icons.access_time_filled_rounded,
      iconColor: const Color(0xFF2E7D32),
      children: [
        // Info box kontekstual
        _buildTimeInfo(isSmallScreen),
        const SizedBox(height: 16),

        // 🔥 RENTANG TANGGAL (BARU!)
        _buildDateRangeRow(context, isSmallScreen),
        
        if (_hasTanggalMulai) ...[
          const SizedBox(height: 16),
          // 🔥 JAM MULAI & SELESAI
          _buildTimePickerRow(context, isSmallScreen),
        ],

        // 🔥 INDIKATOR MULTI-DAY & OVERNIGHT
        if (_hasWaktu && (isMultiDay || isOvernight)) ...[
          const SizedBox(height: 12),
          _buildSpecialIndicator(isSmallScreen),
        ],

        // Total jam
        if (totalJam > 0) ...[
          const SizedBox(height: 16),
          _buildTimeSummary(isSmallScreen),
        ],

        // Reset button
        if (_hasTanggalMulai) ...[
          const SizedBox(height: 12),
          _buildClearButton(),
        ],
      ],
    );
  }

  // ==================== INFO BOX ====================
  Widget _buildTimeInfo(bool isSmallScreen) {
    String infoText;
    IconData infoIcon;
    Color infoColor;

    if (!_hasTanggalMulai) {
      infoText = 'Pilih rentang tanggal lembur. '
          'Lembur hari kerja minimal pukul 17:00. '
          'Bisa lintas hari sesuai kebutuhan lapangan.';
      infoIcon = Icons.info_outline_rounded;
      infoColor = Colors.green;
    } else if (isMultiDay) {
      infoText = '📅 Lembur multi-hari terdeteksi. '
          'Biaya akan dihitung per hari sesuai rate weekday/weekend.';
      infoIcon = Icons.date_range_rounded;
      infoColor = Colors.purple;
    } else if (isOvernight) {
      infoText = '🌙 Lembur lintas tengah malam. '
          'Jam selesai di hari berikutnya tetap dihitung penuh.';
      infoIcon = Icons.nights_stay_rounded;
      infoColor = const Color(0xFF7B1FA2);
    } else {
      final libur = _isLibur(tanggalMulai!);
      if (libur) {
        infoText = '🎉 Hari Libur. Jam lembur bebas, tidak ada batasan minimal.';
        infoIcon = Icons.beach_access_rounded;
        infoColor = Colors.orange;
      } else {
        infoText = '📅 Hari Kerja. Jam lembur minimal pukul 17:00.';
        infoIcon = Icons.work_rounded;
        infoColor = Colors.blue;
      }
    }

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [infoColor.withOpacity(0.08), infoColor.withOpacity(0.15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: infoColor.withOpacity(0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(infoIcon, size: isSmallScreen ? 16 : 18, color: infoColor),
          ),
          SizedBox(width: isSmallScreen ? 8 : 10),
          Expanded(
            child: Text(
              infoText,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 11,
                color: infoColor.withOpacity(0.85),
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DATE RANGE ROW (BARU!) ====================
  Widget _buildDateRangeRow(BuildContext context, bool isSmallScreen) {
    return Column(
      children: [
        // 🔥 TANGGAL MULAI
        _buildSingleDatePicker(
          context: context,
          label: 'Tanggal Mulai',
          date: tanggalMulai,
          onChanged: (date) {
            onTanggalMulaiChanged(date);
            // Auto-set tanggal selesai = tanggal mulai jika belum di-set
            if (date != null && tanggalSelesai == null) {
              onTanggalSelesaiChanged(date);
            }
            // Jika tanggal selesai < tanggal mulai, reset
            if (date != null && tanggalSelesai != null && tanggalSelesai!.isBefore(date)) {
              onTanggalSelesaiChanged(date);
            }
          },
          isSmallScreen: isSmallScreen,
        ),
        
        // 🔥 DIVIDER DENGAN ICON PANAH
        Padding(
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
          child: Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                decoration: BoxDecoration(
                  color: isMultiDay ? Colors.purple.shade50 : Colors.grey.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isMultiDay ? Colors.purple.shade200 : Colors.grey.shade300,
                  ),
                ),
                child: Icon(
                  Icons.arrow_downward_rounded,
                  size: isSmallScreen ? 14 : 16,
                  color: isMultiDay ? Colors.purple : Colors.grey.shade500,
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
            ],
          ),
        ),
        
        // 🔥 TANGGAL SELESAI
        _buildSingleDatePicker(
          context: context,
          label: isMultiDay ? 'Tanggal Selesai (beda hari)' : 'Tanggal Selesai',
          date: tanggalSelesai,
          onChanged: (date) {
            if (date != null && tanggalMulai != null && date.isBefore(tanggalMulai!)) {
              // Jangan izinkan tanggal selesai < tanggal mulai
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: Text('Tanggal selesai harus ≥ tanggal mulai')),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              return;
            }
            onTanggalSelesaiChanged(date);
          },
          isSmallScreen: isSmallScreen,
          minDate: tanggalMulai, // 🔥 Tidak bisa pilih sebelum tanggal mulai
        ),
      ],
    );
  }

  /// Widget date picker individual
  Widget _buildSingleDatePicker({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required Function(DateTime?) onChanged,
    required bool isSmallScreen,
    DateTime? minDate,
  }) {
    final hasValue = date != null;
    final accentColor = _getDateColor(date);
    final bgColor = hasValue
        ? accentColor.withOpacity(0.06)
        : const Color(0xFFF8FAFC);
    final borderColor = hasValue ? accentColor : const Color(0xFFE2E8F0);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final selectedDate = await showDatePicker(
            context: context,
            initialDate: date ?? (minDate ?? now),
            firstDate: minDate ?? now,
            lastDate: now.add(const Duration(days: 60)),
            helpText: 'Pilih $label',
            cancelText: 'BATAL',
            confirmText: 'PILIH',
            fieldLabelText: label,
            fieldHintText: 'DD/MM/YYYY',
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF1976D2),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1E293B),
                  ),
                  dialogTheme: const DialogThemeData(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                  ),
                ),
                child: child!,
              );
            },
          );
          if (selectedDate != null) onChanged(selectedDate);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: hasValue ? 2 : 1.5),
            boxShadow: hasValue
                ? [BoxShadow(color: accentColor.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                decoration: BoxDecoration(
                  color: hasValue ? accentColor.withOpacity(0.12) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: isSmallScreen ? 20 : 24,
                  color: hasValue ? accentColor : const Color(0xFF94A3B8),
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: hasValue ? accentColor.withOpacity(0.8) : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasValue ? formatTanggal(date) : 'Pilih tanggal',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w700,
                        color: hasValue ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                      ),
                    ),
                    if (hasValue) ...[
                      const SizedBox(height: 2),
                      Text(
                        _getDateLabel(date),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 9 : 10,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedRotation(
                turns: hasValue ? 0.25 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(Icons.chevron_right_rounded,
                    size: 24, color: hasValue ? accentColor : const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== TIME PICKER ROW ====================
  Widget _buildTimePickerRow(BuildContext context, bool isSmallScreen) {
    if (isSmallScreen) {
      return Column(
        children: [
          _buildTimePicker(context: context, label: 'Jam Mulai', time: jamMulai, isJamMulai: true, isSmallScreen: true),
          const SizedBox(height: 12),
          _buildTimePicker(context: context, label: 'Jam Selesai', time: jamSelesai, isJamMulai: false, isSmallScreen: true),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildTimePicker(context: context, label: 'Jam Mulai', time: jamMulai, isJamMulai: true, isSmallScreen: false)),
        const SizedBox(width: 12),
        Expanded(child: _buildTimePicker(context: context, label: 'Jam Selesai', time: jamSelesai, isJamMulai: false, isSmallScreen: false)),
      ],
    );
  }

  Widget _buildTimePicker({
    required BuildContext context,
    required String label,
    required TimeOfDay? time,
    required bool isJamMulai,
    required bool isSmallScreen,
  }) {
    final hasValue = time != null;
    const accentColor = Color(0xFF1976D2);
    final icon = isJamMulai ? Icons.login_rounded : Icons.logout_rounded;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () async {
          if (tanggalMulai == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Pilih tanggal terlebih dahulu')),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            return;
          }

          final now = TimeOfDay.now();
          final libur = _isLibur(tanggalMulai!);
          final minJamLembur = _getMinJamLembur(tanggalMulai!);

          TimeOfDay initialTime;
          if (isJamMulai) {
            initialTime = time ?? (libur ? (now.hour < 8 ? const TimeOfDay(hour: 8, minute: 0) : now) : minJamLembur);
          } else {
            final startHour = jamMulai?.hour ?? now.hour;
            initialTime = time ?? TimeOfDay(hour: (startHour + 1) > 23 ? 23 : startHour + 1, minute: 0);
          }

          final selectedTime = await showTimePicker(
            context: context,
            initialTime: initialTime,
            helpText: 'Pilih $label',
            cancelText: 'BATAL',
            confirmText: 'PILIH',
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF1976D2),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF1E293B),
                ),
                dialogTheme: const DialogThemeData(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                ),
              ),
              child: child!,
            ),
          );

          if (selectedTime == null) return;

          // Validasi jam mulai (hari kerja)
          if (isJamMulai && !libur) {
            final minHour = minJamLembur.hour;
            final minMinute = minJamLembur.minute;
            if (selectedTime.hour < minHour || (selectedTime.hour == minHour && selectedTime.minute < minMinute)) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Jam lembur hari kerja minimal pukul ${minHour.toString().padLeft(2, '0')}:${minMinute.toString().padLeft(2, '0')}'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              onJamMulaiChanged(minJamLembur);
              return;
            }
          }

          // 🔥 VALIDASI OVERNIGHT: Jam selesai BOLEH < jam mulai (lintas hari)
          // Tapi tetap harus masuk akal (tidak sama persis)
          if (!isJamMulai && jamMulai != null) {
            final startTotal = jamMulai!.hour * 60 + jamMulai!.minute;
            final endTotal = selectedTime.hour * 60 + selectedTime.minute;
            
            // 🔥 Jika overnight (end < start), tidak masalah!
            // Hanya warning kalau sama persis
            if (endTotal == startTotal) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Jam selesai tidak boleh sama dengan jam mulai'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
          }

          if (isJamMulai) {
            onJamMulaiChanged(selectedTime);
          } else {
            onJamSelesaiChanged(selectedTime);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 14, vertical: isSmallScreen ? 10 : 12),
          decoration: BoxDecoration(
            color: hasValue ? const Color(0xFFF5F8FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hasValue ? accentColor : const Color(0xFFE2E8F0), width: hasValue ? 2 : 1.5),
            boxShadow: hasValue
                ? [BoxShadow(color: accentColor.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: hasValue ? Colors.blue.shade100 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: isSmallScreen ? 14 : 16, color: hasValue ? accentColor : const Color(0xFF94A3B8)),
              ),
              SizedBox(width: isSmallScreen ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(fontSize: isSmallScreen ? 10 : 11, color: hasValue ? accentColor.withOpacity(0.8) : const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      hasValue ? formatTime(time) : '-- : --',
                      style: TextStyle(fontSize: isSmallScreen ? 13 : 15, fontWeight: FontWeight.w600, color: hasValue ? const Color(0xFF1E293B) : const Color(0xFF94A3B8), fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              if (hasValue)
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 2 : 3),
                  decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded, size: isSmallScreen ? 10 : 12, color: Colors.green.shade700),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SPECIAL INDICATOR (MULTI-DAY / OVERNIGHT) ====================
  Widget _buildSpecialIndicator(bool isSmallScreen) {
    final List<Widget> chips = [];

    if (isMultiDay) {
      chips.add(_buildChip(
        icon: Icons.date_range_rounded,
        label: 'Multi-Hari (${tanggalMulai != null && tanggalSelesai != null ? '${tanggalSelesai!.difference(tanggalMulai!).inDays + 1} hari' : ''})',
        color: Colors.purple,
        isSmallScreen: isSmallScreen,
      ));
    }

    if (isOvernight) {
      chips.add(_buildChip(
        icon: Icons.nights_stay_rounded,
        label: 'Lintas Malam',
        color: const Color(0xFF7B1FA2),
        isSmallScreen: isSmallScreen,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 10 : 12, vertical: isSmallScreen ? 6 : 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.08), color.withOpacity(0.15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isSmallScreen ? 14 : 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TIME SUMMARY ====================
  Widget _buildTimeSummary(bool isSmallScreen) {
    final Color accentColor = isMultiDay
        ? Colors.purple
        : isOvernight
            ? const Color(0xFF7B1FA2)
            : const Color(0xFF2E7D32);

    final List<Color> gradientColors = isMultiDay
        ? [const Color(0xFFF3E5F5), const Color(0xFFE1BEE7)]
        : isOvernight
            ? [const Color(0xFFEDE7F6), const Color(0xFFD1C4E9)]
            : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: accentColor.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.timer_rounded, size: 26, color: accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Durasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accentColor)),
                const SizedBox(height: 4),
                if (jamMulai != null && jamSelesai != null)
                  Text(
                    '${formatTime(jamMulai!)} → ${formatTime(jamSelesai!)}${isOvernight ? ' (+1 hari)' : ''}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor.withOpacity(0.8)),
                  ),
                if (isMultiDay)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${formatTanggal(tanggalMulai!)} → ${formatTanggal(tanggalSelesai!)}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accentColor.withOpacity(0.7)),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(totalJam.toStringAsFixed(1), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: accentColor)),
                Text('JAM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: accentColor.withOpacity(0.7), letterSpacing: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CLEAR BUTTON ====================
  Widget _buildClearButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Reset Waktu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade600,
          side: BorderSide(color: Colors.red.shade300, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.red.shade50,
        ),
        onPressed: onClear,
      ),
    );
  }
}