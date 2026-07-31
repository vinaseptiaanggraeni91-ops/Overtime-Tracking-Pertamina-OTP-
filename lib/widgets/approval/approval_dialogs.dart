// lib/widgets/approval/manager/approval_dialogs.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/overtime_rate_service.dart';

// ================================================
// APPROVAL APPROVE DIALOG
// ================================================
class ApprovalApproveDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> mitraList;
  final Function(String notes) onConfirm;
  final bool isSuperadmin; // ✅ PARAMETER BARU

  const ApprovalApproveDialog({
    super.key,
    required this.data,
    required this.mitraList,
    required this.onConfirm,
    this.isSuperadmin = false, // ✅ Default false
  });

  @override
  State<ApprovalApproveDialog> createState() => _ApprovalApproveDialogState();
}

class _ApprovalApproveDialogState extends State<ApprovalApproveDialog> {
  final TextEditingController _catatanController = TextEditingController();

  // 🔥 STATIC CACHE
  static final _rateService = OvertimeRateService();
  static final Map<String, String> _fungsiLabelCache = {};

  // ✅ GETTER ROLE LABEL
  String get _roleLabel => widget.isSuperadmin ? 'Superadmin' : 'Manager';

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final isUrgent = widget.data['urgensi'] == 'kritis';
    final isOverride = widget.data['is_override'] ?? false;
    final isWeekend = widget.data['jenis_lembur'] == 'hari_libur';

    final lokasiData = widget.data['lokasi'];
    final lokasiMap = lokasiData is Map<String, dynamic> ? lokasiData : <String, dynamic>{};
    final isOutsideRadius = lokasiMap['is_outside_radius'] == true;
    final lokasiString = _getLokasiSingkat(lokasiMap);

    final mitraCount = widget.mitraList.length;
    final totalBiaya = (widget.data['estimasi_biaya_total'] ?? 0).toDouble();
    final biayaPerMitra = mitraCount > 0 ? totalBiaya / mitraCount : 0.0;
    final totalJam = (widget.data['total_jam_desimal'] ?? 0).toDouble();

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 16,
        vertical: 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isUrgent || isOverride || isOutsideRadius || isWeekend)
                      _buildWarningSection(isUrgent, isOverride, isOutsideRadius, isWeekend, lokasiString),

                    // ✅ Info box dengan role label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: Colors.green[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Anda akan menyetujui pengajuan lembur ini sebagai $_roleLabel',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildSectionTitle('Ringkasan Pengajuan'),
                    const SizedBox(height: 8),
                    _buildInfoCard([
                      _buildInfoRow('Pengawas', widget.data['nama_pengawas'] ?? '-', Icons.person_outline, Colors.blue),
                      _buildInfoRow('Fungsi', _getFungsiLabelCached(widget.data['pengawas_fungsi']), Icons.business_outlined, Colors.indigo),
                      _buildInfoRow('Mitra', '$mitraCount orang', Icons.people_outline, Colors.purple),
                      _buildInfoRow('Jam', '${totalJam.toStringAsFixed(1)} jam', Icons.timer_outlined, Colors.teal),
                      if (lokasiString.isNotEmpty)
                        _buildInfoRow('Lokasi', lokasiString, Icons.location_on_outlined, Colors.deepOrange),
                    ]),

                    const SizedBox(height: 10),

                    _buildBiayaCard(totalBiaya, biayaPerMitra, mitraCount),

                    if (mitraCount > 0 && mitraCount <= 5) ...[
                      const SizedBox(height: 10),
                      _buildMitraList(),
                    ],

                    const SizedBox(height: 12),

                    _buildSectionTitle('Catatan Approval'),
                    const SizedBox(height: 8),
                    _buildCatatanField(),
                  ],
                ),
              ),
            ),

            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ============== HEADER ==============
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Setujui Pengajuan',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B)),
                ),
                // ✅ Subtitle role
                Text(
                  'Sebagai $_roleLabel',
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[500]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== WARNING SECTION ==============
  Widget _buildWarningSection(bool isUrgent, bool isOverride, bool isOutsideRadius, bool isWeekend, String lokasiString) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          if (isUrgent)
            _buildWarningItem(icon: Icons.warning_rounded, color: Colors.red, title: 'Pengajuan KRITIS!', message: 'Ditandai sebagai urgent/kritis'),
          if (isOverride)
            _buildWarningItem(icon: Icons.warning_amber_rounded, color: Colors.orange, title: 'Melebihi Batas!', message: 'Total jam melebihi 60 jam/bulan'),
          if (isWeekend)
            _buildWarningItem(icon: Icons.event_busy_rounded, color: Colors.purple, title: 'Hari Libur!', message: 'Lembur pada hari libur'),
          if (isOutsideRadius)
            _buildWarningItem(icon: Icons.location_off_rounded, color: Colors.deepOrange, title: 'Luar Radius!', message: 'Lokasi: $lokasiString'),
        ],
      ),
    );
  }

  Widget _buildWarningItem({
    required IconData icon, required Color color, required String title, required String message,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                Text(message, style: GoogleFonts.poppins(fontSize: 9, color: color.withValues(alpha: 0.75))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============== SECTION TITLE ==============
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 3, height: 14,
            decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        ],
      ),
    );
  }

  // ============== INFO CARD ==============
  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 13, color: iconColor),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF334155)),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ============== BIAYA CARD ==============
  Widget _buildBiayaCard(double totalBiaya, double biayaPerMitra, int mitraCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _buildCostRow('Biaya per Mitra', _rateService.formatRupiahCompact(biayaPerMitra)),
          const SizedBox(height: 6),
          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 6),
          _buildCostRow('Total ($mitraCount mitra)', _rateService.formatRupiahCompact(totalBiaya), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 11 : 10,
              color: Colors.white.withValues(alpha: isTotal ? 1 : 0.75),
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: GoogleFonts.poppins(fontSize: isTotal ? 16 : 12, fontWeight: FontWeight.w700, color: isTotal ? const Color(0xFFFCD34D) : Colors.white)),
      ],
    );
  }

  // ============== MITRA LIST ==============
  Widget _buildMitraList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Daftar Mitra (${widget.mitraList.length})'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: widget.mitraList.map((mitra) {
              final nama = mitra['nama_mitra'] ?? '?';
              final fungsi = _getFungsiLabelCached(mitra['fungsi_mitra']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Center(
                        child: Text(nama[0].toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(nama, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF334155)), overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(3)),
                      child: Text(fungsi, style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey[600])),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ============== CATATAN FIELD ==============
  Widget _buildCatatanField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextFormField(
        controller: _catatanController,
        maxLines: 2,
        style: GoogleFonts.poppins(fontSize: 11),
        decoration: InputDecoration(
          hintText: 'Tambahkan catatan ($_roleLabel)...',
          hintStyle: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(10),
        ),
      ),
    );
  }

  // ============== ACTION BUTTONS ==============
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1))),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Batal', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: () => widget.onConfirm(_catatanController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_rounded, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Setujui ($_roleLabel)', // ✅ Label dinamis
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== HELPERS ==============
  String _getLokasiSingkat(Map<String, dynamic>? lokasi) {
    if (lokasi == null || lokasi.isEmpty) return '';
    if (lokasi['nama_lokasi']?.toString().isNotEmpty == true) {
      final nama = lokasi['nama_lokasi'].toString();
      return nama.length > 15 ? '${nama.substring(0, 15)}...' : nama;
    }
    if (lokasi['alamat']?.toString().isNotEmpty == true) {
      final alamat = lokasi['alamat'].toString();
      return alamat.length > 15 ? '${alamat.substring(0, 15)}...' : alamat;
    }
    return '';
  }

  String _getFungsiLabelCached(String? f) {
    final key = f?.toLowerCase() ?? 'default';
    return _fungsiLabelCache[key] ??= _computeFungsiLabel(key);
  }

  String _computeFungsiLabel(String fungsi) {
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

// ================================================
// APPROVAL REJECT DIALOG
// ================================================
class ApprovalRejectDialog extends StatefulWidget {
  final Function(String notes) onConfirm;
  final bool isSuperadmin; // ✅ PARAMETER BARU

  const ApprovalRejectDialog({
    super.key,
    required this.onConfirm,
    this.isSuperadmin = false, // ✅ Default false
  });

  @override
  State<ApprovalRejectDialog> createState() => _ApprovalRejectDialogState();
}

class _ApprovalRejectDialogState extends State<ApprovalRejectDialog> {
  final TextEditingController _alasanController = TextEditingController();
  String? _errorText;

  // ✅ GETTER ROLE LABEL
  String get _roleLabel => widget.isSuperadmin ? 'Superadmin' : 'Manager';

  @override
  void dispose() {
    _alasanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1))),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.cancel_rounded, color: Colors.red, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tolak Pengajuan',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B)),
                        ),
                        // ✅ Subtitle role
                        Text(
                          'Sebagai $_roleLabel',
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                        child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[500]),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_rounded, size: 16, color: Colors.red[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Pengajuan yang ditolak tidak dapat diproses kembali',
                              style: GoogleFonts.poppins(fontSize: 10, color: Colors.red[600], fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Alasan Penolakan', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 3),
                    Text('Jelaskan secara detail mengapa ditolak', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _errorText != null ? Colors.red : Colors.grey[200]!),
                      ),
                      child: TextFormField(
                        controller: _alasanController,
                        maxLines: 4,
                        autofocus: true,
                        style: GoogleFonts.poppins(fontSize: 11),
                        decoration: InputDecoration(
                          hintText: 'Tulis alasan penolakan ($_roleLabel)...',
                          hintStyle: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                        onChanged: (value) {
                          if (_errorText != null && value.trim().isNotEmpty) {
                            setState(() => _errorText = null);
                          }
                        },
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.error_outline, size: 12, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(_errorText!, style: GoogleFonts.poppins(fontSize: 9, color: Colors.red, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1))),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Batal', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_alasanController.text.trim().isEmpty) {
                              setState(() => _errorText = 'Alasan penolakan wajib diisi');
                              return;
                            }
                            widget.onConfirm(_alasanController.text.trim());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.close_rounded, size: 16),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Tolak ($_roleLabel)', // ✅ Label dinamis
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
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
}