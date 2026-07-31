// lib/widgets/mitra/mitra_history_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/overtime_rate_service.dart';

class MitraHistoryCard extends StatefulWidget {
  final List<Map<String, dynamic>> historyList;
  final VoidCallback onViewAll;

  const MitraHistoryCard({
    super.key,
    required this.historyList,
    required this.onViewAll,
  });

  @override
  State<MitraHistoryCard> createState() => _MitraHistoryCardState();
}

class _MitraHistoryCardState extends State<MitraHistoryCard> {
  final OvertimeRateService _rateService = OvertimeRateService();
  Map<String, dynamic>? _rates;
  bool _isLoadingRates = true;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    try {
      final rates = await _rateService.loadOvertimeRates();
      if (mounted) {
        setState(() {
          _rates = rates;
          _isLoadingRates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRates = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hitung total pendapatan dari riwayat
    double totalIncome = 0;
    for (var h in widget.historyList) {
      totalIncome += _calculateIncome(h);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withAlpha(10),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 HEADER
          _buildHeader(totalIncome),
          
          const SizedBox(height: 14),

          // 🔥 LIST HISTORY
          ...widget.historyList.take(3).map((history) => _buildHistoryItem(history)),

          // 🔥 VIEW MORE (jika > 3)
          if (widget.historyList.length > 3) ...[
            const SizedBox(height: 8),
            _buildViewMoreButton(),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════
  Widget _buildHeader(double totalIncome) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1565C0).withAlpha(25),
                const Color(0xFF42A5F5).withAlpha(15),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.work_history_rounded,
            size: 20,
            color: Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '💼 Aktivitas Lembur',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2B4C),
                ),
              ),
              if (totalIncome > 0)
                Text(
                  _rateService.formatRupiahCompact(totalIncome),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E20),
                  ),
                ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onViewAll,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Semua',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 9,
                    color: Color(0xFF1565C0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // HISTORY ITEM - FIXED OVERFLOW
  // ═══════════════════════════════════════════════
  Widget _buildHistoryItem(Map<String, dynamic> history) {
    final date = history['date']?.toString() ?? '';
    final jamMulai = history['jam_mulai']?.toString() ?? '--:--';
    final jamSelesai = history['jam_selesai']?.toString() ?? '--:--';
    final status = history['status']?.toString() ?? 'pending';
    
    // 🔥 Hitung income dari OvertimeRateService
    final income = _calculateIncome(history);
    
    // 🔥 Hitung durasi
    final durasi = _calculateDuration(jamMulai, jamSelesai);

    // Status config
    final config = _getStatusConfig(status);
    final Color configColor = config['color'] as Color;
    final IconData configIcon = config['icon'] as IconData;
    final String configLabel = config['label'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: configColor.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: configColor.withAlpha(25)),
      ),
      child: Row(
        children: [
          // 🔥 STATUS ICON (kecil)
          Icon(configIcon, size: 20, color: configColor),
          const SizedBox(width: 10),
          
          // 🔥 INFO TENGAH (Expanded - flexible)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Jam + Durasi
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$jamMulai - $jamSelesai',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2B4C),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (durasi.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          durasi,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // Tanggal
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF90A4AE),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 🔥 PENDAPATAN + STATUS (kanan - fixed width)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nominal
              Text(
                _rateService.formatRupiahCompact(income),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 3),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: configColor.withAlpha(180),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  configLabel,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // VIEW MORE BUTTON
  // ═══════════════════════════════════════════════
  Widget _buildViewMoreButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onViewAll,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Lihat ${widget.historyList.length - 3} lainnya',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // HELPER: Calculate Income from OvertimeRateService
  // ═══════════════════════════════════════════════
  double _calculateIncome(Map<String, dynamic> history) {
    // Jika sudah ada income dari data, pakai itu
    if (history['income'] != null) {
      return (history['income'] as num).toDouble();
    }

    // Jika tidak ada, hitung dari OvertimeRateService
    if (_rates == null) return 0;

    try {
      final jamMulai = history['jam_mulai']?.toString() ?? '';
      final jamSelesai = history['jam_selesai']?.toString() ?? '';
      
      if (jamMulai.isEmpty || jamSelesai.isEmpty) return 0;

      // Hitung total jam
      final partsMulai = jamMulai.split(':');
      final partsSelesai = jamSelesai.split(':');
      
      if (partsMulai.length != 2 || partsSelesai.length != 2) return 0;

      final mulaiMinutes = (int.tryParse(partsMulai[0]) ?? 0) * 60 + (int.tryParse(partsMulai[1]) ?? 0);
      var selesaiMinutes = (int.tryParse(partsSelesai[0]) ?? 0) * 60 + (int.tryParse(partsSelesai[1]) ?? 0);
      
      if (selesaiMinutes <= mulaiMinutes) selesaiMinutes += 24 * 60;
      
      final totalMinutes = selesaiMinutes - mulaiMinutes;
      final totalHours = totalMinutes / 60.0;

      // Cek apakah hari libur
      final isHoliday = history['is_holiday'] == true || 
                        history['holiday'] == true ||
                        (history['date']?.toString().contains('Sabtu') ?? false) ||
                        (history['date']?.toString().contains('Minggu') ?? false);

      // Hitung biaya
      return _rateService.calculateOvertimeCost(
        totalHours: totalHours,
        isHoliday: isHoliday,
        rates: _rates!,
      );
    } catch (e) {
      return 0;
    }
  }

  // ═══════════════════════════════════════════════
  // HELPER: Calculate Duration
  // ═══════════════════════════════════════════════
  String _calculateDuration(String jamMulai, String jamSelesai) {
    try {
      final partsMulai = jamMulai.split(':');
      final partsSelesai = jamSelesai.split(':');
      
      if (partsMulai.length != 2 || partsSelesai.length != 2) return '';

      final mulaiMinutes = (int.tryParse(partsMulai[0]) ?? 0) * 60 + (int.tryParse(partsMulai[1]) ?? 0);
      var selesaiMinutes = (int.tryParse(partsSelesai[0]) ?? 0) * 60 + (int.tryParse(partsSelesai[1]) ?? 0);
      
      if (selesaiMinutes <= mulaiMinutes) selesaiMinutes += 24 * 60;
      
      final totalMinutes = selesaiMinutes - mulaiMinutes;
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      
      if (hours > 0 && minutes > 0) return '${hours}j ${minutes}m';
      if (hours > 0) return '${hours}j';
      if (minutes > 0) return '${minutes}m';
      return '';
    } catch (_) {
      return '';
    }
  }

  // ═══════════════════════════════════════════════
  // HELPER: Status Config
  // ═══════════════════════════════════════════════
  Map<String, dynamic> _getStatusConfig(String status) {
    // 🔥 PERBAIKAN: Gunakan variabel 'configs' bukan 'constructors'
    final Map<String, Map<String, dynamic>> configs = {
      'approved': {
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF00C853),
        'label': 'Disetujui',
      },
      'selesai': {
        'icon': Icons.task_alt_rounded,
        'color': const Color(0xFF1B5E20),
        'label': 'Selesai',
      },
      'rejected': {
        'icon': Icons.cancel_rounded,
        'color': const Color(0xFFE53935),
        'label': 'Ditolak',
      },
      'pending': {
        'icon': Icons.schedule_rounded,
        'color': const Color(0xFFFFAB40),
        'label': 'Pending',
      },
      'in_progress': {
        'icon': Icons.play_circle_rounded,
        'color': const Color(0xFF2196F3),
        'label': 'Aktif',
      },
    };
    
    return Map<String, dynamic>.from(configs[status] ?? configs['pending']!);
  }

  // ═══════════════════════════════════════════════
  // HELPER: Format Date
  // ═══════════════════════════════════════════════
  String _formatDate(String dateStr) {
    try {
      final formats = ['dd MMM yyyy', 'yyyy-MM-dd', 'dd/MM/yyyy', 'dd-MM-yyyy'];
      
      for (var format in formats) {
        try {
          final date = DateFormat(format, 'id_ID').parse(dateStr);
          final now = DateTime.now();
          final difference = now.difference(date);

          if (difference.inDays == 0) return 'Hari ini';
          if (difference.inDays == 1) return 'Kemarin';
          if (difference.inDays < 7) return '${difference.inDays} hari lalu';
          return DateFormat('dd MMM yyyy', 'id_ID').format(date);
        } catch (_) {}
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }
}