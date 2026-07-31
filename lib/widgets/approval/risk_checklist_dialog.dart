// lib/widgets/approval/risk_checklist_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RiskChecklistDialog extends StatefulWidget {
  final Function(String notes) onApprove;

  const RiskChecklistDialog({
    super.key,
    required this.onApprove,
  });

  @override
  State<RiskChecklistDialog> createState() => _RiskChecklistDialogState();
}

class _RiskChecklistDialogState extends State<RiskChecklistDialog> {
  // 🔥 Static constants
  static const Color _primaryColor = Color(0xFF9C27B0);
  
  // 🔥 Checklist K3 Esensial (fleksibel, HSSE bisa menambahkan catatan spesifik)
  static const List<_ChecklistItem> _checklistItems = [
    _ChecklistItem(
      key: 'apd',
      label: 'APD Lengkap Sesuai Jenis Pekerjaan',
      icon: Icons.health_and_safety,
    ),
    _ChecklistItem(
      key: 'izin',
      label: 'Izin Kerja & Dokumen K3 Lengkap',
      icon: Icons.assignment_turned_in,
    ),
    _ChecklistItem(
      key: 'safety_briefing',
      label: 'Safety Briefing / Toolbox Meeting',
      icon: Icons.campaign,
    ),
    _ChecklistItem(
      key: 'area_aman',
      label: 'Area Kerja Aman & Rambu K3 Terpasang',
      icon: Icons.signpost,
    ),
    _ChecklistItem(
      key: 'darurat',
      label: 'Peralatan Darurat & P3K Siap',
      icon: Icons.emergency,
    ),
    _ChecklistItem(
      key: 'pengawas',
      label: 'Pengawas K3 / Safety Officer Standby',
      icon: Icons.supervisor_account,
    ),
  ];

  final Map<String, bool> _checklist = {};
  final TextEditingController _notesController = TextEditingController();
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    // Initialize all checklist to false
    for (final item in _checklistItems) {
      _checklist[item.key] = false;
    }
  }

  bool get _allChecked => _checklist.values.every((v) => v);
  int get _checkedCount => _checklist.values.where((v) => v).length;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: _buildHeader(),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                _buildInfoBanner(),
                const SizedBox(height: 16),
                
                // Progress Indicator
                _buildProgressIndicator(),
                const SizedBox(height: 16),
                
                // Checklist Title
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.checklist_rounded, size: 20, color: _primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Checklist K3 Esensial',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'HSSE dapat menyesuaikan poin K3 tambahan di catatan',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Checklist Items
                ..._checklistItems.map((item) => _buildChecklistItem(item)),
                
                const SizedBox(height: 20),
                
                // Divider
                const Divider(),
                const SizedBox(height: 12),
                
                // Notes Field - DIPERBESAR & DIPENTINGKAN
                _buildNotesSection(),
                
                // Error Message
                if (_showError) ...[
                  const SizedBox(height: 8),
                  _buildErrorMessage(),
                ],
              ],
            ),
          ),
          actions: _buildActions(),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        );
      },
    );
  }

  // ============== HEADER ==============
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primaryColor, Color(0xFF6A1B9A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.verified_user, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Approval HSSE',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Verifikasi K3 oleh HSSE Officer',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        // Close button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close, size: 16, color: Colors.grey[500]),
            ),
          ),
        ),
      ],
    );
  }

  // ============== INFO BANNER ==============
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: _primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Checklist ini bersifat esensial. Tambahkan catatan untuk poin K3 spesifik sesuai kondisi lapangan.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: _primaryColor,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== PROGRESS INDICATOR ==============
  Widget _buildProgressIndicator() {
    final progress = _checklistItems.isEmpty ? 0.0 : _checkedCount / _checklistItems.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Progress: $_checkedCount/${_checklistItems.length} item',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _allChecked ? Colors.green : _primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _allChecked ? Colors.green : _primaryColor,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ============== CHECKLIST ITEM ==============
  Widget _buildChecklistItem(_ChecklistItem item) {
    final isChecked = _checklist[item.key] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isChecked ? _primaryColor.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isChecked
            ? Border.all(color: _primaryColor.withValues(alpha: 0.2))
            : Border.all(color: Colors.grey[200]!),
      ),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: (value) {
          setState(() {
            _checklist[item.key] = value ?? false;
            if (_allChecked) _showError = false;
          });
        },
        title: Row(
          children: [
            Icon(
              item.icon,
              size: 18,
              color: isChecked ? _primaryColor : Colors.grey[500],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isChecked
                      ? const Color(0xFF1E293B)
                      : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        activeColor: _primaryColor,
        checkColor: Colors.white,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ============== NOTES SECTION (DIPERBESAR & DIPENTINGKAN) ==============
  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.edit_note, size: 20, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Catatan HSSE Officer',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'WAJIB DIISI',
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Cantumkan poin K3 spesifik sesuai kondisi lapangan',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 5, // 🔥 Diperbesar
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: 'Contoh catatan HSSE:\n'
                  '• Detektor gas H2S berfungsi normal\n'
                  '• Ventilasi area sumur cukup\n'
                  '• Penerangan area kerja 120 lux\n'
                  '• Cuaca cerah, angin tenang\n'
                  '• Tim emergency response siap\n'
                  '• Dll...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[400],
                height: 1.5,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  // ============== ERROR MESSAGE ==============
  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Harap checklist semua item K3 & isi catatan HSSE sebelum menyetujui',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== ACTION BUTTONS ==============
  List<Widget> _buildActions() {
    return [
      // Cancel Button
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[600],
          side: BorderSide(color: Colors.grey[300]!),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          'Batal',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      const SizedBox(width: 12),
      
      // Approve Button
      ElevatedButton.icon(
        onPressed: _allChecked
            ? () {
                final notes = _notesController.text.trim();
                if (notes.isEmpty) {
                  setState(() => _showError = true);
                  return;
                }
                final message = 'Disetujui HSSE\nCatatan K3: $notes';
                widget.onApprove(message);
              }
            : () => setState(() => _showError = true),
        icon: const Icon(Icons.verified_user, size: 20),
        label: Text(
          'Setujui',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _allChecked ? Colors.green : Colors.grey[400],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: _allChecked ? 2 : 0,
        ),
      ),
    ];
  }
}

// 🔥 Helper class untuk checklist items
class _ChecklistItem {
  final String key;
  final String label;
  final IconData icon;

  const _ChecklistItem({
    required this.key,
    required this.label,
    required this.icon,
  });
}