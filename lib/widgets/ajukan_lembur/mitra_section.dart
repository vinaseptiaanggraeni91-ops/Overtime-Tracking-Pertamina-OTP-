// lib/widgets/ajukan_lembur/mitra_section.dart
import 'package:flutter/material.dart';
import 'section_card.dart';

class MitraSection extends StatelessWidget {
  final List<Map<String, dynamic>> selectedMiras;
  final List<Map<String, dynamic>> validMiras;
  final List<Map<String, dynamic>> duplicateMiras;
  final Map<String, bool> mitraDuplicateStatus;
  final bool hasDuplicateMitra;
  final bool isCheckingDuplicates;
  final String? fungsiPengawas;
  final DateTime? tanggalLembur;
  final VoidCallback onAddMitra;
  final Function(Map<String, dynamic>) onRemoveMitra;
  final String Function(DateTime) formatTanggal;

  const MitraSection({
    super.key,
    required this.selectedMiras,
    required this.validMiras,
    required this.duplicateMiras,
    required this.mitraDuplicateStatus,
    required this.hasDuplicateMitra,
    required this.isCheckingDuplicates,
    this.fungsiPengawas,
    this.tanggalLembur,
    required this.onAddMitra,
    required this.onRemoveMitra,
    required this.formatTanggal,
  });

  Color _getFungsiColor(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation':
        return const Color(0xFF1976D2);
      case 'maintenance':
        return const Color(0xFFFF9800);
      case 'hsse':
        return const Color(0xFF9C27B0);
      case 'gpr':
        return const Color(0xFFF44336);
      case 'bs':
        return const Color(0xFF795548);
      default:
        return const Color(0xFF607D8B);
    }
  }

  IconData _getFungsiIcon(String fungsi) {
    switch (fungsi.toLowerCase()) {
      case 'operation':
        return Icons.settings_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      case 'hsse':
        return Icons.health_and_safety_rounded;
      case 'gpr':
        return Icons.radar_rounded;
      case 'bs':
        return Icons.business_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return SectionCard(
      title: 'Pilih Mitra Lembur',
      icon: Icons.people_alt_rounded,
      iconColor: const Color(0xFF0D47A1),
      children: [
        // Info jumlah mitra
        if (selectedMiras.isNotEmpty) ...[
          _buildMitraCounter(isSmallScreen),
          const SizedBox(height: 14),
        ],

        // Loading checking
        if (isCheckingDuplicates) ...[
          _buildCheckingIndicator(isSmallScreen),
          const SizedBox(height: 14),
        ],

        // Duplicate warning
        if (hasDuplicateMitra && !isCheckingDuplicates) ...[
          _buildDuplicateWarning(isSmallScreen),
          const SizedBox(height: 14),
        ],

        // Valid mitra list
        if (validMiras.isNotEmpty) ...[
          _buildMitraListHeader(isSmallScreen),
          const SizedBox(height: 10),
          _buildMitraList(isSmallScreen),
          const SizedBox(height: 14),
        ],

        // Add button
        _buildAddMitraButton(isSmallScreen),

        // Empty state
        if (selectedMiras.isEmpty) ...[
          const SizedBox(height: 14),
          _buildEmptyState(isSmallScreen),
        ],
      ],
    );
  }

  Widget _buildMitraCounter(bool isSmallScreen) {
    final totalSelected = selectedMiras.length;
    final totalValid = validMiras.length;
    final totalDuplicate = duplicateMiras.length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 10 : 12,
        vertical: isSmallScreen ? 8 : 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF5F8FF),
            const Color(0xFFE8F0FE),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBBDEFB).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.group_rounded,
              size: 16,
              color: const Color(0xFF1976D2).withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$totalSelected mitra dipilih',
              style: TextStyle(
                fontSize: isSmallScreen ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1565C0),
              ),
            ),
          ),
          // Badges
          if (totalValid > 0)
            _buildMiniBadge(
              '$totalValid valid',
              Colors.green,
              isSmallScreen,
            ),
          if (totalDuplicate > 0) ...[
            const SizedBox(width: 6),
            _buildMiniBadge(
              '$totalDuplicate duplikat',
              Colors.orange,
              isSmallScreen,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String text, MaterialColor color, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 8,
        vertical: isSmallScreen ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isSmallScreen ? 9 : 10,
          fontWeight: FontWeight.w600,
          color: color.shade700,
        ),
      ),
    );
  }

  Widget _buildCheckingIndicator(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              width: isSmallScreen ? 16 : 18,
              height: isSmallScreen ? 16 : 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF1976D2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Memeriksa Duplikasi',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Memastikan mitra belum terdaftar',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 11,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateWarning(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade50,
            Colors.orange.shade100.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: isSmallScreen ? 18 : 20,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duplikasi Terdeteksi',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    Text(
                      '${duplicateMiras.length} mitra sudah terdaftar',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Duplicate list
          ...duplicateMiras.map((mitra) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildDuplicateItem(mitra, isSmallScreen),
          )),
          
          const SizedBox(height: 8),
          
          // Footer info
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Hapus mitra duplikat untuk melanjutkan',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 11,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateItem(Map<String, dynamic> mitra, bool isSmallScreen) {
    final fungsi = mitra['fungsi']?.toString() ?? '';
    final color = _getFungsiColor(fungsi);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: isSmallScreen ? 32 : 36,
            height: isSmallScreen ? 32 : 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                (mitra['nama_lengkap']?.substring(0, 1) ?? 'M').toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mitra['nama_lengkap'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 12,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sudah terdaftar',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Remove button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => onRemoveMitra(mitra),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: isSmallScreen ? 14 : 16,
                  color: Colors.red.shade500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMitraListHeader(bool isSmallScreen) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Mitra Valid (${validMiras.length})',
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: Colors.green.shade800,
          ),
        ),
        const Spacer(),
        if (tanggalLembur != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 10,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  formatTanggal(tanggalLembur!),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMitraList(bool isSmallScreen) {
    return Column(
      children: validMiras.asMap().entries.map((entry) {
        final index = entry.key;
        final mitra = entry.value;
        final isLast = index == validMiras.length - 1;
        
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
          child: _buildMitraItem(mitra, index, isSmallScreen),
        );
      }).toList(),
    );
  }

  Widget _buildMitraItem(Map<String, dynamic> mitra, int index, bool isSmallScreen) {
    final fungsi = mitra['fungsi']?.toString().toLowerCase() ?? '';
    final color = _getFungsiColor(fungsi);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Number badge
          Container(
            width: isSmallScreen ? 20 : 24,
            height: isSmallScreen ? 20 : 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Avatar
          Container(
            width: isSmallScreen ? 38 : 44,
            height: isSmallScreen ? 38 : 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                (mitra['nama_lengkap']?.substring(0, 1) ?? 'M').toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: isSmallScreen ? 16 : 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mitra['nama_lengkap'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _getFungsiIcon(fungsi),
                      size: 12,
                      color: color.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 6 : 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        fungsi.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Remove button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => onRemoveMitra(mitra),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: isSmallScreen ? 16 : 18,
                  color: Colors.red.shade400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMitraButton(bool isSmallScreen) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: fungsiPengawas != null ? onAddMitra : null,
        icon: Icon(
          Icons.person_add_rounded,
          size: isSmallScreen ? 18 : 20,
        ),
        label: Text(
          selectedMiras.isEmpty ? 'Tambah Mitra' : 'Tambah Mitra Lain',
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF0D47A1),
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 12 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: isSmallScreen ? 28 : 32,
              color: Colors.grey.shade400,
            ),
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          Text(
            'Belum ada mitra dipilih',
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan mitra untuk lembur bersama',
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}