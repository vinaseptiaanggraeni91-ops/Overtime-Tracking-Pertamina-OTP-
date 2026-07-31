import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/core/services/overtime_rate_service.dart';

class ApprovalCard extends StatelessWidget {
  static final _rateService = OvertimeRateService();
  static final _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
  static final _dateTimeFormatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  static final Map<String, Color> _fungsiColorCache = {};
  static final Map<String, String> _fungsiLabelCache = {};

  final Map<String, dynamic> data;
  final String groupId;
  final bool isBulkMode;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(String, bool) onSelectionChanged;

  const ApprovalCard({
    super.key,
    required this.data,
    required this.groupId,
    required this.isBulkMode,
    required this.isSelected,
    required this.onTap,
    required this.onSelectionChanged,
  });

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color riskyColor = Color(0xFFDC2626);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color successColor = Color(0xFF10B981);

  // ===================================================================
  // 🔥 FORMAT RUPIAH TANPA PEMBULATAN (HARGA ASLI)
  // ===================================================================
  static String _formatRupiahAsli(double value) {
    if (value == 0) return 'Rp 0';

    final intPart = value.floor();
    final decPart = value - intPart;

    final formattedInt = intPart.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    if (decPart > 0) {
      final decStr = (decPart * 1000).round().toString().padLeft(3, '0');
      final trimmedDec = decStr.replaceAll(RegExp(r'0+$'), '');
      if (trimmedDec.isEmpty) {
        return 'Rp $formattedInt';
      }
      return 'Rp $formattedInt,$trimmedDec';
    }

    return 'Rp $formattedInt';
  }

  // ===================================================================
  // 🔥 NORMALISASI TANGGAL
  // ===================================================================
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      return null;
    } catch (e) {
      debugPrint('❌ ApprovalCard._parseDate error: $value → $e');
      return null;
    }
  }

  static String _formatTanggal(Map<String, dynamic> data) {
    final dateFieldCandidates = [
      'tanggal_formatted', 'tanggal', 'tanggal_lembur',
      'tgl_lembur', 'tanggal_pengajuan', 'tgl_pengajuan', 'created_at',
    ];

    for (final field in dateFieldCandidates) {
      final value = data[field];
      if (value is String && value.isNotEmpty) {
        if (value.contains(RegExp(r'[A-Za-z]'))) return value;
        final parsed = _parseDate(value);
        if (parsed != null) return _dateFormatter.format(parsed);
      }
      final parsed = _parseDate(value);
      if (parsed != null) return _dateFormatter.format(parsed);
    }

    final submittedAt = _parseDate(data['submitted_at']);
    if (submittedAt != null) return _dateFormatter.format(submittedAt);
    return '-';
  }

  static String _formatJamKerja(Map<String, dynamic> data) {
    final jamMulai = data['jam_mulai']?.toString() ?? '';
    final jamSelesai = data['jam_selesai']?.toString() ?? '';
    if (jamMulai.isNotEmpty && jamSelesai.isNotEmpty) {
      return '$jamMulai - $jamSelesai';
    }
    if (jamMulai.isNotEmpty) return jamMulai;

    final startTime = data['start_time']?.toString() ?? data['waktu_mulai']?.toString() ?? '';
    final endTime = data['end_time']?.toString() ?? data['waktu_selesai']?.toString() ?? '';
    if (startTime.isNotEmpty && endTime.isNotEmpty) return '$startTime - $endTime';
    return '-';
  }

  // ===================================================================
  // 🔥🔥🔥 FORMAT BIAYA - FIXED: SUPPORT lembur_mitra 🔥🔥🔥
  // ===================================================================
  static String _formatBiaya(Map<String, dynamic> data) {
    // 1️⃣ Cek display field (dari normalisasi PendingApprovalList)
    final displayField = data['estimasi_biaya_total_display']?.toString();
    if (displayField != null && displayField.isNotEmpty && displayField != 'Rp 0') {
      return displayField;
    }

    // 2️⃣ Ambil nilai ASLI dari berbagai field (pengajuan_lembur & lembur_mitra)
    double biaya = 0.0;

    // 🔥 Daftar field biaya (prioritas: pengajuan_lembur dulu, lalu lembur_mitra)
    final rawValue = data['estimasi_biaya_total_raw'] ??
        data['estimasi_biaya_total'] ??          // pengajuan_lembur
        data['estimasi_biaya'] ??                // ✅ lembur_mitra
        data['estimasi_biaya_per_mitra'] ??      // ✅ lembur_mitra
        data['total_biaya'] ??
        data['biaya_total'] ??
        data['biaya'] ??
        0;

    if (rawValue is double) {
      biaya = rawValue;
    } else if (rawValue is int) {
      biaya = rawValue.toDouble();
    } else if (rawValue is num) {
      biaya = rawValue.toDouble();
    } else if (rawValue is String) {
      biaya = double.tryParse(rawValue) ?? 0.0;
    }

    // 3️⃣ Format tanpa pembulatan
    final result = _formatRupiahAsli(biaya);
    debugPrint('💰 Format biaya: raw=$rawValue → biaya=$biaya → result=$result');
    return result;
  }

  // ===================================================================
  // 🔥 FORMAT NAMA - FIXED: SUPPORT lembur_mitra
  // ===================================================================
  static String _getNamaPengawas(Map<String, dynamic> data) {
    return data['nama_pengawas']?.toString() ??
        data['pengawas_nama_lengkap']?.toString() ??
        data['nama_mitra']?.toString() ??         // ✅ lembur_mitra
        data['mitra_nama']?.toString() ??         // ✅ lembur_mitra
        data['diajukan_oleh_nama']?.toString() ?? // ✅ lembur_mitra
        data['nama_lengkap']?.toString() ??
        data['nama']?.toString() ??
        'Unknown';
  }

  static String _formatTotalMitra(Map<String, dynamic> data) {
    final total = data['total_mitra'] ??
        data['jumlah_mitra'] ??
        data['mitra_count'] ??
        1;
    try {
      final count = total is int ? total : int.tryParse(total.toString()) ?? 1;
      return '$count Mitra';
    } catch (e) {
      return '1 Mitra';
    }
  }

  // ===================================================================
  // BUILD
  // ===================================================================
  @override
  Widget build(BuildContext context) {
    final isUrgent = data['urgensi'] == 'kritis' || data['urgensi'] == 'critical';
    final isOverride = data['is_override'] ?? false;
    final isWeekend = data['jenis_lembur'] == 'hari_libur';
    final isOutside = data['lokasi']?['is_outside_radius'] ?? false;

    final isNeedHSSE = data['requires_hsse_approval'] == true ||
        data['need_hsse_confirmation'] == true ||
        data['status'] == 'pending_hsse';

    final riskLevel = data['risk_level']?.toString().toLowerCase() ?? '';
    final isHighRisk = riskLevel == 'high' || riskLevel == 'critical' || riskLevel == 'tinggi';
    final isRisky = isNeedHSSE && isHighRisk;

    // 🔥 GUNAKAN FUNGSI NORMALISASI
    final formattedTanggal = _formatTanggal(data);
    final formattedJam = _formatJamKerja(data);
    final formattedBiaya = _formatBiaya(data);       // ✅ SUDAH FIX
    final formattedMitra = _formatTotalMitra(data);
    final namaPengawas = _getNamaPengawas(data);     // ✅ SUDAH FIX

    // 🎨 ACCENT COLOR
    final Color accentColor = isRisky
        ? const Color(0xFFDC2626)
        : isNeedHSSE
            ? const Color(0xFFF59E0B)
            : isUrgent
                ? const Color(0xFFEF4444)
                : getFungsiColor(data['pengawas_fungsi']);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (isBulkMode) {
                  onSelectionChanged(groupId, !isSelected);
                } else {
                  onTap();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? accentColor
                        : Colors.grey.withValues(alpha: 0.12),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: isSelected ? 0.12 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // LEFT ACCENT BAR
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 5,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                          ),
                          gradient: LinearGradient(
                            colors: [accentColor, accentColor.withValues(alpha: 0.15)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // CONTENT
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER: Avatar + Nama + Badges
                          Row(
                            children: [
                              _buildAvatar(accentColor, isRisky),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      namaPengawas,  // ✅ SUDAH FIX
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildFungsiChip(data['pengawas_fungsi']),
                                        const SizedBox(width: 6),
                                        if (isRisky) _buildMiniBadge('HIGH RISK', riskyColor),
                                        if (isNeedHSSE && !isRisky) _buildMiniBadge('K3', Colors.orange),
                                        if (isUrgent && !isNeedHSSE) _buildMiniBadge('URGENT', Colors.red),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isBulkMode)
                                _buildBulkCheckbox(accentColor)
                              else
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.chevron_right_rounded, color: Colors.grey[350], size: 20),
                                ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // BODY: Info Chips
                          Row(
                            children: [
                              _buildInfoChip(Icons.calendar_today_rounded, formattedTanggal, const Color(0xFF3B82F6)),
                              const SizedBox(width: 8),
                              _buildInfoChip(Icons.access_time_rounded, formattedJam, const Color(0xFF8B5CF6)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildInfoChip(Icons.people_rounded, formattedMitra, const Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              _buildInfoChip(Icons.receipt_long_rounded, formattedBiaya, const Color(0xFFF59E0B)),
                            ],
                          ),

                          // TAGS
                          if (isWeekend || isOverride || isOutside) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (isWeekend) _buildTag('Hari Libur', Colors.purple, Icons.event_busy),
                                if (isOverride) _buildTag('Override', Colors.orange, Icons.warning_amber_rounded),
                                if (isOutside) _buildTag('Luar Radius', Colors.deepOrange, Icons.location_off),
                              ],
                            ),
                          ],

                          // ALASAN
                          if ((data['alasan']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline, size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      data['alasan'] ?? '',
                                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B), height: 1.4),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // SELECTED OVERLAY
                    if (isSelected)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildAvatar(Color accentColor, bool isRisky) {
    final nama = _getNamaPengawas(data);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.2),
            accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: isRisky
            ? Icon(Icons.health_and_safety_rounded, color: accentColor, size: 20)
            : Text(
                nama.isNotEmpty ? nama[0].toUpperCase() : 'U',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
      ),
    );
  }

  Widget _buildFungsiChip(String? fungsi) {
    final color = getFungsiColor(fungsi);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        getFungsiLabel(fungsi).toUpperCase(),
        style: GoogleFonts.poppins(fontSize: 9, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildMiniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.poppins(fontSize: 8, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.poppins(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBulkCheckbox(Color accentColor) {
    return GestureDetector(
      onTap: () => onSelectionChanged(groupId, !isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? accentColor : Colors.grey.shade300, width: 2),
          color: isSelected ? accentColor : Colors.transparent,
        ),
        child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
      ),
    );
  }

  // ==================== CACHED UTILS ====================

  static Color getFungsiColor(String? fungsi) {
    final key = fungsi?.toLowerCase() ?? 'default';
    return _fungsiColorCache[key] ??= _computeFungsiColor(key);
  }

  static Color _computeFungsiColor(String fungsi) {
    switch (fungsi) {
      case 'operation': return const Color(0xFF1976D2);
      case 'maintenance': return const Color(0xFFFF9800);
      case 'hsse': return const Color(0xFF9C27B0);
      case 'gpr': return const Color(0xFFEF4444);
      case 'bs': return const Color(0xFF795548);
      default: return const Color(0xFF6366F1);
    }
  }

  static String getFungsiLabel(String? fungsi) {
    final key = fungsi?.toLowerCase() ?? 'default';
    return _fungsiLabelCache[key] ??= _computeFungsiLabel(key);
  }

  static String _computeFungsiLabel(String fungsi) {
    switch (fungsi) {
      case 'operation': return 'Operation';
      case 'maintenance': return 'Maintenance';
      case 'hsse': return 'HSSE';
      case 'gpr': return 'GPR';
      case 'bs': return 'Business Support';
      default: return fungsi.isNotEmpty ? fungsi : 'Unknown';
    }
  }
}