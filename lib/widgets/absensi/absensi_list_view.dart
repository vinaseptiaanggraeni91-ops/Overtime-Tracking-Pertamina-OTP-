// lib/widgets/absensi/absensi_list_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ✅ GANTI: Import dari absensi service (sudah include OvertimeHistory)
import '/core/services/overtime_absensi_service.dart';
import '/widgets/absensi/absensi_detail_content.dart';

class AbsensiListView extends StatefulWidget {
  final String userRole;
  final String? userFungsi;
  final String? userId;
  final String selectedBulan;
  final String selectedStatus;
  final String searchQuery;
  final String? lemburIdHighlight;

  const AbsensiListView({
    super.key,
    required this.userRole,
    this.userFungsi,
    this.userId,
    required this.selectedBulan,
    required this.selectedStatus,
    this.searchQuery = '',
    this.lemburIdHighlight,
  });

  @override
  State<AbsensiListView> createState() => _AbsensiListViewState();
}

class _AbsensiListViewState extends State<AbsensiListView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OvertimeAbsensiService _absensiService = OvertimeAbsensiService();

  // 🔥 Cache untuk TenggatInfo biar nggak fetch terus
  final Map<String, TenggatInfo> _tenggatCache = {};
  Timer? _cacheCleanupTimer;

  @override
  void initState() {
    super.initState();
    // Bersihkan cache setiap 5 menit
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _tenggatCache.clear();
    });
  }

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    super.dispose();
  }

  Stream<List<OvertimeHistory>> _getLemburMitraStream() {
    Query<Map<String, dynamic>> query =
        _firestore.collection('lembur_mitra');

    if (widget.userRole == 'mitra' && widget.userId != null) {
      query = query.where('mitra_id', isEqualTo: widget.userId);
    } else if (widget.userRole == 'pengawas' && widget.userId != null) {
      query = query.where('diajukan_oleh_id', isEqualTo: widget.userId);
    } else if (widget.userRole == 'manager' &&
        widget.userFungsi != null &&
        widget.userFungsi!.isNotEmpty) {
      query = query.where('pengawas_fungsi', isEqualTo: widget.userFungsi);
    }

    if (widget.selectedBulan.isNotEmpty) {
      query = query.where('tahun_bulan', isEqualTo: widget.selectedBulan);
    }

    query = query.orderBy('tanggal', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => OvertimeHistory.fromFirestore(doc))
          .toList();
    });
  }

  // FIX: Helper methods untuk TenggatInfo
  bool _getButuhPerhatian(TenggatInfo info) {
    return info.canConfirm || (info.isLate && !info.isExpired);
  }

  Color _getWarnaIndikator(TenggatInfo info) {
    if (info.isExpired) return const Color(0xFF9E9E9E);
    if (info.canConfirm) return Colors.orange;
    if (info.isLate) return Colors.orange;
    if (info.isNormal) return const Color(0xFF66BB6A);
    return Colors.orange;
  }

  IconData _getIconStatus(TenggatInfo info) {
    if (info.isExpired) return Icons.timer_off_rounded;
    if (info.canConfirm) return Icons.warning_amber_rounded;
    if (info.isLate) return Icons.warning_amber_rounded;
    if (info.isNormal) return Icons.timer_rounded;
    return Icons.timer;
  }

  String _getSisaWaktuSingkat(TenggatInfo info) {
    if (info.canConfirm) return 'Konfirmasi';
    if (info.isLate) return 'Terlambat';
    return 'Normal';
  }

  Color _getWarnaBackground(TenggatInfo info) {
    if (info.canConfirm) return const Color(0xFFFFF3E0);
    if (info.isLate) return const Color(0xFFFFF8E1);
    if (info.isNormal) return Colors.white;
    return Colors.white;
  }

  Color _getWarnaBorder(TenggatInfo info) {
    if (info.canConfirm) return Colors.orange;
    if (info.isLate) return Colors.orange.shade300;
    return Colors.transparent;
  }

  String _getEmojiStatus(TenggatInfo info) {
    if (info.isExpired) return '💀';
    if (info.canConfirm) return '⚠️';
    if (info.isLate) return '⏰';
    if (info.isNormal) return '✅';
    return '📋';
  }

  String _getAksiLabel(TenggatInfo info) {
    if (info.isExpired) return 'Expired';
    if (info.canConfirm) return 'Konfirmasi';
    if (info.isLate) return 'Segera';
    return 'Normal';
  }

  String _getBatasExpiredFormatted(TenggatInfo info) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(info.batasExpired);
    } catch (e) {
      return info.batasExpired.toString();
    }
  }

  String _getBatasNormalJam(TenggatInfo info) {
    try {
      return DateFormat('HH:mm').format(info.batasNormal);
    } catch (e) {
      return '--:--';
    }
  }

  String _getBatasExpiredJam(TenggatInfo info) {
    try {
      return DateFormat('HH:mm').format(info.batasExpired);
    } catch (e) {
      return '--:--';
    }
  }

  String _getLevelPrioritas(TenggatInfo info) {
    if (info.isExpired) return 'Kritis';
    if (info.canConfirm) return 'Tinggi';
    if (info.isLate) return 'Sedang';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OvertimeHistory>>(
      stream: _getLemburMitraStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allData = snapshot.data ?? [];

        // Dedup by ID
        final seen = <String>{};
        final deduped = allData.where((e) => seen.add(e.id)).toList();

        List<OvertimeHistory> filtered = deduped;

        // Filter status absensi
        if (widget.selectedStatus == 'belum_absen') {
          filtered = filtered
              .where((e) =>
                  (e.status == 'disetujui' || e.status == 'approved') &&
                  (e.absensiStatus == 'belum_absen'))
              .toList();
        } else if (widget.selectedStatus == 'sudah_absen') {
          filtered = filtered
              .where((e) =>
                  e.absensiStatus == 'check_in' ||
                  e.absensiStatus == 'check_out' ||
                  e.absensiStatus == 'selesai' ||
                  e.absensiStatus == 'sudah_absen')
              .toList();
        } else if (widget.selectedStatus == 'kadaluarsa') {
          filtered = filtered
              .where((e) => e.status == 'kadaluarsa' || e.absensiStatus == 'expired')
              .toList();
        } else if (widget.selectedStatus == 'urgent') {
          // 🔥 Filter urgent: yang belum absen & mendekati tenggat
          filtered = filtered.where((e) {
            if (e.status != 'disetujui' && e.status != 'approved') return false;
            if (e.absensiStatus != 'belum_absen') return false;
            
            // Cek dari cache atau hitung manual
            final tenggat = _tenggatCache[e.id];
            if (tenggat != null) {
              // FIX: Gunakan helper method
              return _getButuhPerhatian(tenggat);
            }
            return false;
          }).toList();
        }

        // Filter search (client-side)
        if (widget.searchQuery.isNotEmpty) {
          final q = widget.searchQuery.toLowerCase();
          filtered = filtered.where((e) {
            final nama = (e.namaMitra ?? '').toLowerCase();
            final pengawas = (e.namaPengawas ?? '').toLowerCase();
            final tanggalStr =
                DateFormat('dd MMM yyyy', 'id_ID').format(e.tanggal).toLowerCase();
            return nama.contains(q) ||
                   pengawas.contains(q) ||
                   tanggalStr.contains(q) ||
                   e.jamMulai.contains(q) ||
                   e.jamSelesai.contains(q);
          }).toList();
        }

        // 🔥 Sort: yang urgent di atas
        filtered.sort((a, b) {
          final ta = _tenggatCache[a.id];
          final tb = _tenggatCache[b.id];
          final pa = ta?.prioritas ?? 99;
          final pb = tb?.prioritas ?? 99;
          return pa.compareTo(pb);
        });

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada data absensi',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return _AbsensiCard(
              overtime: item,
              tenggatInfo: _tenggatCache[item.id], // 🔥 Pass dari cache
              absensiService: _absensiService,
              onTenggatLoaded: (info) {
                // 🔥 Update cache saat tenggat info loaded
                if (info != null && mounted) {
                  setState(() {
                    _tenggatCache[item.id] = info;
                  });
                }
              },
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => AbsensiDetailContent(overtime: item),
                );
              },
              highlight: item.id == widget.lemburIdHighlight,
            );
          },
        );
      },
    );
  }
}

// ===========================================================================
// ABSENSI CARD - SUPER COMPLETE VERSION
// ===========================================================================
class _AbsensiCard extends StatefulWidget {
  final OvertimeHistory overtime;
  final VoidCallback onTap;
  final bool highlight;
  final TenggatInfo? tenggatInfo;
  final OvertimeAbsensiService absensiService;
  final Function(TenggatInfo?) onTenggatLoaded;

  const _AbsensiCard({
    required this.overtime,
    required this.onTap,
    this.highlight = false,
    this.tenggatInfo,
    required this.absensiService,
    required this.onTenggatLoaded,
  });

  @override
  State<_AbsensiCard> createState() => _AbsensiCardState();
}

class _AbsensiCardState extends State<_AbsensiCard> {
  TenggatInfo? _tenggatInfo;
  StreamSubscription<TenggatInfo?>? _countdownSub;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tenggatInfo = widget.tenggatInfo;
    
    // 🔥 Load tenggat info jika belum ada
    if (_tenggatInfo == null) {
      _loadTenggatInfo();
    }
    
    // 🔥 Start countdown untuk update real-time
    _startCountdown();
  }

  @override
  void didUpdateWidget(_AbsensiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tenggatInfo != null && widget.tenggatInfo != _tenggatInfo) {
      setState(() {
        _tenggatInfo = widget.tenggatInfo;
      });
    }
  }

  Future<void> _loadTenggatInfo() async {
    final info = await widget.absensiService.getTenggatInfo(widget.overtime.id);
    if (mounted) {
      setState(() {
        _tenggatInfo = info;
      });
      widget.onTenggatLoaded(info);
    }
  }

  void _startCountdown() {
    // Update countdown setiap 30 detik
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      final info = await widget.absensiService.getTenggatInfo(widget.overtime.id);
      if (mounted) {
        setState(() {
          _tenggatInfo = info;
        });
        widget.onTenggatLoaded(info);
      }
    });
  }

  @override
  void dispose() {
    _countdownSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // FIX: Helper methods untuk TenggatInfo di dalam _AbsensiCardState
  Color _getWarnaIndikator(TenggatInfo info) {
    if (info.isExpired) return const Color(0xFF9E9E9E);
    if (info.canConfirm) return Colors.orange;
    if (info.isLate) return Colors.orange;
    if (info.isNormal) return const Color(0xFF66BB6A);
    return Colors.orange;
  }

  IconData _getIconStatus(TenggatInfo info) {
    if (info.isExpired) return Icons.timer_off_rounded;
    if (info.canConfirm) return Icons.warning_amber_rounded;
    if (info.isLate) return Icons.warning_amber_rounded;
    if (info.isNormal) return Icons.timer_rounded;
    return Icons.timer;
  }

  String _getSisaWaktuSingkat(TenggatInfo info) {
    if (info.canConfirm) return 'Konfirmasi';
    if (info.isLate) return 'Terlambat';
    return 'Normal';
  }

  Color _getWarnaBackground(TenggatInfo info) {
    if (info.canConfirm) return const Color(0xFFFFF3E0);
    if (info.isLate) return const Color(0xFFFFF8E1);
    if (info.isNormal) return Colors.white;
    return Colors.white;
  }

  bool _getButuhPerhatian(TenggatInfo info) {
    return info.canConfirm || (info.isLate && !info.isExpired);
  }

  Color _getWarnaBorder(TenggatInfo info) {
    if (info.canConfirm) return Colors.orange;
    if (info.isLate) return Colors.orange.shade300;
    return Colors.transparent;
  }

  String _getEmojiStatus(TenggatInfo info) {
    if (info.isExpired) return '💀';
    if (info.canConfirm) return '⚠️';
    if (info.isLate) return '⏰';
    if (info.isNormal) return '✅';
    return '📋';
  }

  String _getAksiLabel(TenggatInfo info) {
    if (info.isExpired) return 'Expired';
    if (info.canConfirm) return 'Konfirmasi';
    if (info.isLate) return 'Segera';
    return 'Normal';
  }

  String _getBatasExpiredFormatted(TenggatInfo info) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(info.batasExpired);
    } catch (e) {
      return info.batasExpired.toString();
    }
  }

  String _getBatasNormalJam(TenggatInfo info) {
    try {
      return DateFormat('HH:mm').format(info.batasNormal);
    } catch (e) {
      return '--:--';
    }
  }

  String _getBatasExpiredJam(TenggatInfo info) {
    try {
      return DateFormat('HH:mm').format(info.batasExpired);
    } catch (e) {
      return '--:--';
    }
  }

  String _getLevelPrioritas(TenggatInfo info) {
    if (info.isExpired) return 'Kritis';
    if (info.canConfirm) return 'Tinggi';
    if (info.isLate) return 'Sedang';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Gunakan extension dari OvertimeAbsensiService
    final absensiStatus = widget.overtime.absensiStatus;
    final sudahAbsen = absensiStatus == 'check_in' ||
        absensiStatus == 'check_out' ||
        absensiStatus == 'selesai' ||
        absensiStatus == 'sudah_absen';
    final isExpired = widget.overtime.status == 'kadaluarsa' || absensiStatus == 'expired';

    // 🔥 Tentukan warna dan status berdasarkan tenggat info
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (_tenggatInfo != null && !sudahAbsen && !isExpired) {
      // FIX: Gunakan helper methods
      statusColor = _getWarnaIndikator(_tenggatInfo!);
      statusIcon = _getIconStatus(_tenggatInfo!);
      
      if (_tenggatInfo!.isNormal) {
        statusText = 'Absen Normal';
      } else if (_tenggatInfo!.canConfirm) {
        statusText = _getSisaWaktuSingkat(_tenggatInfo!);
      } else {
        statusText = _tenggatInfo!.labelSingkat;
      }
    } else if (isExpired) {
      statusColor = const Color(0xFF9E9E9E);
      statusText = 'Kadaluarsa';
      statusIcon = Icons.timer_off_rounded;
    } else if (!sudahAbsen) {
      statusColor = Colors.orange;
      statusText = 'Belum Absen';
      statusIcon = Icons.pending_actions_rounded;
    } else {
      statusColor = const Color(0xFF66BB6A);
      statusText = 'Sudah Absen';
      statusIcon = Icons.check_circle_rounded;
    }

    // Lokasi singkat
    String lokasiSingkat = 'Kantor PGE';
    if (widget.overtime.lokasi.isNotEmpty) {
      final pilihan = widget.overtime.lokasi['pilihan'] ?? 'kantor';
      if (pilihan == 'kantor') {
        lokasiSingkat = 'Kantor PGE';
      } else if (pilihan == 'proyek') {
        lokasiSingkat = widget.overtime.lokasi['proyek'] ?? 'Proyek';
      } else {
        lokasiSingkat = widget.overtime.lokasi['alamat'] ?? 'Lokasi Lain';
      }
    }

    // 🔥 Card background color based on urgency
    final cardColor = _tenggatInfo != null && !sudahAbsen && !isExpired
        ? _getWarnaBackground(_tenggatInfo!)
        : (widget.highlight ? const Color(0xFFFFF3E0) : Colors.white);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: _tenggatInfo != null && _getButuhPerhatian(_tenggatInfo!) && !sudahAbsen && !isExpired
            ? BorderSide(color: _getWarnaBorder(_tenggatInfo!), width: 1.5)
            : BorderSide.none,
      ),
      color: cardColor,
      elevation: widget.highlight ? 4 : 2,
      shadowColor: (widget.highlight ? Colors.orange : Colors.grey).withValues(alpha: 0.3),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //═══════════════════════════════════════════════════
              // HEADER ROW
              //═══════════════════════════════════════════════════
              Row(
                children: [
                  // Status Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  
                  // Name & Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.overtime.namaMitra ?? 'Mitra',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM yyyy', 'id_ID')
                                  .format(widget.overtime.tanggal),
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_tenggatInfo != null && !sudahAbsen && !isExpired)
                          Text(
                            _getEmojiStatus(_tenggatInfo!),
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (_tenggatInfo != null && !sudahAbsen && !isExpired)
                          const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: GoogleFonts.poppins(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              //═══════════════════════════════════════════════════
              // 🔥 TENGGAT PROGRESS BAR + COUNTDOWN
              //═══════════════════════════════════════════════════
              if (_tenggatInfo != null && !sudahAbsen && !isExpired) ...[
                const SizedBox(height: 12),
                
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _tenggatInfo!.progressPercent,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getWarnaIndikator(_tenggatInfo!),
                    ),
                    minHeight: 6,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Countdown Text
                Row(
                  children: [
                    Icon(
                      _getIconStatus(_tenggatInfo!),
                      size: 14,
                      color: _getWarnaIndikator(_tenggatInfo!),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _tenggatInfo!.isNormal
                            ? 'Sisa waktu absen normal: ${_tenggatInfo!.sisaWaktuFormatted}'
                            : 'Sisa waktu konfirmasi: ${_tenggatInfo!.sisaWaktuFormatted}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getWarnaIndikator(_tenggatInfo!),
                        ),
                      ),
                    ),
                    // Action label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getWarnaIndikator(_tenggatInfo!).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getAksiLabel(_tenggatInfo!),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _getWarnaIndikator(_tenggatInfo!),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Additional info
                if (_tenggatInfo!.isLate && _tenggatInfo!.canConfirm) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Batas konfirmasi: ${_getBatasExpiredFormatted(_tenggatInfo!)}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 14),

              //═══════════════════════════════════════════════════
              // INFO CHIPS
              //═══════════════════════════════════════════════════
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(Icons.access_time,
                      '${widget.overtime.jamMulai} - ${widget.overtime.jamSelesai}'),
                  _chip(Icons.timer,
                      '${widget.overtime.totalJam.toStringAsFixed(1)} jam'),
                  _chip(Icons.location_on, lokasiSingkat),
                  
                  // 🔥 Tenggat info chips
                  if (_tenggatInfo != null && !sudahAbsen && !isExpired) ...[
                    _chip(
                      _tenggatInfo!.isNormal ? Icons.timer : Icons.warning_amber,
                      _tenggatInfo!.isNormal
                          ? 'Batas: ${_getBatasNormalJam(_tenggatInfo!)}'
                          : 'Exp: ${_getBatasExpiredJam(_tenggatInfo!)}',
                      color: _getWarnaIndikator(_tenggatInfo!),
                    ),
                    _chip(
                      Icons.speed,
                      _getLevelPrioritas(_tenggatInfo!),
                      color: _getWarnaIndikator(_tenggatInfo!),
                    ),
                  ],
                  
                  // ✅ absensiWaktu dari extension
                  if (widget.overtime.absensiWaktu != null)
                    _chip(
                      Icons.login,
                      DateFormat('HH:mm').format(widget.overtime.absensiWaktu!),
                    ),
                  if (widget.overtime.namaPengawas != null)
                    _chip(Icons.person, widget.overtime.namaPengawas!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color? color}) {
    final chipColor = color ?? Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: chipColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}