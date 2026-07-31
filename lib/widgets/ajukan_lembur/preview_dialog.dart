// lib/widgets/ajukan_lembur/preview_dialog.dart
import 'package:flutter/material.dart';

class PreviewDialog extends StatelessWidget {
  final String? namaPengawas;
  final String? fungsiPengawas;
  final List<Map<String, dynamic>> validMiras;
  final DateTime? tanggalLembur;
  final DateTime? tanggalSelesai;      // 🔥 BARU: Rentang akhir
  final TimeOfDay? jamMulai;
  final TimeOfDay? jamSelesai;
  final double totalJam;
  final bool isMultiDay;               // 🔥 BARU: Flag multi-hari
  final bool isOvernight;              // 🔥 BARU: Flag lintas malam
  final String locationType;
  final String? selectedAddress;
  final TextEditingController rtController;
  final TextEditingController rwController;
  final String urgensi;
  final double biayaLemburPerMitra;
  final double totalBiayaLembur;
  final String alasan;
  final String Function(TimeOfDay) formatTime;
  final String Function(DateTime) formatTanggal;
  final String Function(double) formatRupiah;
  final VoidCallback onConfirmed;

  const PreviewDialog({
    super.key,
    this.namaPengawas,
    this.fungsiPengawas,
    required this.validMiras,
    this.tanggalLembur,
    this.tanggalSelesai,          // 🔥 BARU
    this.jamMulai,
    this.jamSelesai,
    required this.totalJam,
    this.isMultiDay = false,      // 🔥 BARU
    this.isOvernight = false,     // 🔥 BARU
    required this.locationType,
    this.selectedAddress,
    required this.rtController,
    required this.rwController,
    required this.urgensi,
    required this.biayaLemburPerMitra,
    required this.totalBiayaLembur,
    required this.alasan,
    required this.formatTime,
    required this.formatTanggal,
    required this.formatRupiah,
    required this.onConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final isWeekend = tanggalLembur != null &&
        (tanggalLembur!.weekday == DateTime.saturday ||
            tanggalLembur!.weekday == DateTime.sunday);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.preview_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Pratinjau Pengajuan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pastikan semua data sudah benar sebelum mengajukan',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                  // 🔥 BADGE: Weekend / Multi-Day / Overnight
                  if (isWeekend || isMultiDay || isOvernight) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        if (isWeekend)
                          _buildHeaderBadge(
                            icon: Icons.beach_access_rounded,
                            label: 'Hari Libur',
                            color: Colors.orange,
                          ),
                        if (isMultiDay)
                          _buildHeaderBadge(
                            icon: Icons.date_range_rounded,
                            label: 'Multi-Hari',
                            color: Colors.purple,
                          ),
                        if (isOvernight)
                          _buildHeaderBadge(
                            icon: Icons.nights_stay_rounded,
                            label: 'Lintas Malam',
                            color: const Color(0xFF7B1FA2),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informasi Pengawas
                    _buildSection(
                      icon: Icons.person_rounded,
                      title: 'Informasi Pengawas',
                      color: const Color(0xFF1976D2),
                      children: [
                        _buildInfoRow('Nama', namaPengawas ?? '-'),
                        _buildInfoRow(
                          'Fungsi',
                          fungsiPengawas?.toUpperCase() ?? '-',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    // Mitra
                    _buildSection(
                      icon: Icons.people_rounded,
                      title: 'Mitra Lembur (${validMiras.length} orang)',
                      color: const Color(0xFF4CAF50),
                      children: validMiras.asMap().entries.map((entry) {
                        final index = entry.key;
                        final mitra = entry.value;
                        return _buildInfoRow(
                          '${index + 1}. ${mitra['nama_lengkap'] ?? '-'}',
                          mitra['fungsi']?.toString().toUpperCase() ?? '-',
                          isMitra: true,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    
                    // 🔥 WAKTU LEMBUR (UPDATED!)
                    _buildSection(
                      icon: Icons.schedule_rounded,
                      title: 'Waktu Lembur',
                      color: isMultiDay || isOvernight 
                          ? Colors.purple 
                          : const Color(0xFFFF9800),
                      children: [
                        // 🔥 TANGGAL: Single atau Rentang
                        if (isMultiDay && tanggalLembur != null && tanggalSelesai != null) ...[
                          _buildInfoRow(
                            'Tanggal Mulai',
                            formatTanggal(tanggalLembur!),
                          ),
                          _buildInfoRow(
                            'Tanggal Selesai',
                            formatTanggal(tanggalSelesai!),
                            valueColor: Colors.purple,
                          ),
                          _buildInfoRow(
                            'Total Hari',
                            '${tanggalSelesai!.difference(tanggalLembur!).inDays + 1} hari',
                            valueColor: Colors.purple,
                            isBold: true,
                          ),
                        ] else ...[
                          _buildInfoRow(
                            'Tanggal',
                            tanggalLembur != null
                                ? formatTanggal(tanggalLembur!)
                                : '-',
                          ),
                        ],
                        // 🔥 JAM
                        _buildInfoRow(
                          'Jam',
                          '${jamMulai != null ? formatTime(jamMulai!) : '--:--'} → ${jamSelesai != null ? formatTime(jamSelesai!) : '--:--'}${isOvernight ? ' (+1 hari)' : ''}',
                        ),
                        _buildInfoRow(
                          'Durasi',
                          '${totalJam.toStringAsFixed(1)} jam',
                        ),
                        _buildInfoRow(
                          'Jenis',
                          isMultiDay 
                              ? 'Campuran (Hari Kerja & Libur)' 
                              : isWeekend 
                                  ? 'Hari Libur' 
                                  : 'Hari Kerja',
                          valueColor: isMultiDay 
                              ? Colors.purple 
                              : isWeekend 
                                  ? Colors.orange 
                                  : Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    // Lokasi
                    _buildSection(
                      icon: Icons.location_on_rounded,
                      title: 'Lokasi Lembur',
                      color: const Color(0xFFE91E63),
                      children: [
                        _buildInfoRow(
                          'Tipe',
                          locationType == 'kantor' ? 'Kantor PGE' : 'Proyek/Lapangan',
                        ),
                        _buildInfoRow(
                          'Alamat',
                          selectedAddress ?? '-',
                        ),
                        if (rtController.text.isNotEmpty)
                          _buildInfoRow(
                            'RT/RW',
                            '${rtController.text}/${rwController.text}',
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    // Urgensi
                    _buildSection(
                      icon: Icons.warning_rounded,
                      title: 'Tingkat Urgensi',
                      color: urgensi == 'normal' ? Colors.blue : Colors.red,
                      children: [
                        _buildInfoRow(
                          'Tingkat',
                          urgensi == 'normal' ? 'NORMAL' : 'TINGGI',
                          valueColor: urgensi == 'normal' ? Colors.blue : Colors.red,
                          isBold: true,
                        ),
                        _buildInfoRow(
                          'Lokasi',
                          urgensi == 'normal' ? 'Dalam Kantor' : 'Lapangan/Proyek',
                        ),
                        _buildInfoRow(
                          'Proses',
                          urgensi == 'normal'
                              ? 'Antrian normal (1-2 hari)'
                              : 'Prioritas (1-4 jam)',
                          valueColor: Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    // Rincian Biaya
                    _buildSection(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Rincian Biaya Lembur',
                      color: const Color(0xFF6A1B9A),
                      children: [
                        _buildInfoRow(
                          'Biaya per Mitra',
                          formatRupiah(biayaLemburPerMitra),
                        ),
                        _buildInfoRow(
                          'Jumlah Mitra',
                          '${validMiras.length} orang',
                        ),
                        if (isMultiDay)
                          _buildInfoRow(
                            'Catatan',
                            'Biaya dihitung per hari (weekday/weekend)',
                            valueColor: Colors.purple,
                          ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1),
                        ),
                        _buildInfoRow(
                          'TOTAL BIAYA LEMBUR',
                          formatRupiah(totalBiayaLembur),
                          isBold: true,
                          valueColor: const Color(0xFF6A1B9A),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    // Alasan
                    _buildSection(
                      icon: Icons.description_rounded,
                      title: 'Alasan Lembur',
                      color: const Color(0xFF607D8B),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            alasan,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Warning untuk lokasi di luar radius
                    if (locationType == 'proyek') ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Pengajuan lembur di luar kantor memerlukan verifikasi lokasi dan persetujuan khusus dari Manager.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // 🔥 Warning Multi-Day
                    if (isMultiDay) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.purple.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Lembur multi-hari akan dicatat per tanggal dan biaya dihitung sesuai rate weekday/weekend masing-masing hari.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple.shade800,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: Color(0xFF1976D2)),
                      ),
                      child: const Text(
                        'KEMBALI',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: onConfirmed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFF1976D2).withValues(alpha: 0.3),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'AJUKAN LEMBUR',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 BADGE DI HEADER
  Widget _buildHeaderBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    bool isMitra = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isMitra ? Colors.black87 : Colors.grey.shade600,
                fontWeight: isMitra ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? (isBold ? const Color(0xFF1976D2) : Colors.black87),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}