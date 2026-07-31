// lib/widgets/mitra/mitra_overtime_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/mitra_service.dart';              // ✅ TAMBAHKAN IMPORT INI
import '../../core/services/overtime_history_service.dart';
import '../../core/services/live_location_service.dart';
import '/widgets/absensi/absensi_dialog.dart';

class MitraOvertimeCard extends StatefulWidget {
  final Map<String, dynamic> overtime;
  final bool isCheckedIn;
  final bool isCheckedOut;
  final bool canCheckIn;
  final String formattedCheckInTime;
  final String userName;
  final Map<String, dynamic> overtimeSettings;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  const MitraOvertimeCard({
    super.key,
    required this.overtime,
    required this.isCheckedIn,
    required this.isCheckedOut,
    required this.canCheckIn,
    required this.formattedCheckInTime,
    required this.userName,
    required this.overtimeSettings,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  @override
  State<MitraOvertimeCard> createState() => _MitraOvertimeCardState();
}

class _MitraOvertimeCardState extends State<MitraOvertimeCard> {
  final _service = MitraService();  // ✅ Sekarang MitraService dikenal karena sudah di-import
  bool _isLoadingAction = false;

  Future<void> _handleCheckOut() async {
    setState(() => _isLoadingAction = true);
    try {
      final overtimeItem = await OvertimeHistoryService()
          .getOvertimeById(widget.overtime['id']);
      
      if (overtimeItem == null) {
        if (mounted) _showSnackBar('Data lembur tidak ditemukan', false);
        return;
      }
      
      final absensiSuccess = await AbsensiDialog.show(context, overtimeItem);
      if (absensiSuccess == true && mounted) {
        await LiveLocationService().stopTracking();
        final income = await _service.checkOutLembur(
          widget.overtime['id'],
          widget.userName,
          widget.overtimeSettings,
        );
        if (mounted) {
          widget.onCheckOut();
          _showSnackBar(
            '✅ Check-out! Pendapatan: Rp ${NumberFormat('#,###').format(income)}',
            true,
          );
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Gagal check-out: $e', false);
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  void _showSnackBar(String message, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(success ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 11))),
        ]),
        backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.only(
            left: 12, right: 12, bottom: MediaQuery.of(context).size.height * 0.12),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final jamMulai = widget.overtime['jam_mulai']?.toString() ?? '19:00';
    final jamSelesai = widget.overtime['jam_selesai']?.toString() ?? '22:00';
    final deskripsi = widget.overtime['description']?.toString() ?? 'Lembur Rutin';
    final lokasi = widget.overtime['location']?.toString() ?? 'PLTP Kamojang';

    // Tentukan warna berdasarkan status
    final Color primaryColor;
    final Color secondaryColor;
    final String statusText;
    final IconData statusIcon;

    if (widget.isCheckedOut) {
      primaryColor = Colors.green.shade700;
      secondaryColor = Colors.green.shade500;
      statusText = '✅ Lembur Selesai!';
      statusIcon = Icons.check_circle;
    } else if (widget.isCheckedIn) {
      primaryColor = Colors.orange.shade700;
      secondaryColor = Colors.orange.shade500;
      statusText = 'Sedang Lembur';
      statusIcon = Icons.access_time;
    } else {
      primaryColor = const Color(0xFFFF6B35);
      secondaryColor = const Color(0xFFFF8A5C);
      statusText = '📅 Jadwal Lembur Hari Ini!';
      statusIcon = Icons.notifications_active;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(70),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(60),  // ✅ FIX: Colors.white24 -> Colors.white.withAlpha(60)
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.white.withAlpha(60), blurRadius: 8),
                  ],
                ),
                child: Icon(statusIcon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deskripsi,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Detail waktu & lokasi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Waktu
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$jamMulai - $jamSelesai',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                
                // Action Button
                if (!widget.isCheckedOut) ...[
                  if (widget.isCheckedIn)
                    _buildActionButton(
                      'Check Out',
                      Icons.logout,
                      Colors.red.shade600,
                      _isLoadingAction,
                      _handleCheckOut,
                    )
                  else if (!widget.isCheckedIn && widget.canCheckIn)
                    _buildActionButton(
                      'Check In',
                      Icons.login,
                      Colors.green.shade600,
                      _isLoadingAction,
                      widget.onCheckIn,
                    )
                  else if (!widget.isCheckedIn && !widget.canCheckIn)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Mulai ${widget.formattedCheckInTime}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          
          // Lokasi
          if (lokasi.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white60, size: 14),
                const SizedBox(width: 4),
                Text(
                  lokasi,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Action button builder
  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    bool isLoading,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withAlpha(80), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              isLoading ? 'Proses...' : label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}