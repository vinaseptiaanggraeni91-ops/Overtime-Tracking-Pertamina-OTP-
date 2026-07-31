// lib/widgets/log/log_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final String Function(String) getLevelFromType;
  final String Function(String) getCategoryFromType;
  final Color primaryBlue;
  final VoidCallback onTap;

  final Map<String, Color> _levelColors = const {
    'info': Color(0xFF2196F3),
    'warning': Color(0xFFFF9800),
    'error': Color(0xFFF44336),
    'success': Color(0xFF4CAF50),
    'debug': Color(0xFF9C27B0),
  };

  final Map<String, IconData> _categoryIcons = {
    'system': Icons.computer,
    'user': Icons.people,
    'overtime': Icons.work_history,
    'absensi': Icons.camera_alt,
    'broadcast': Icons.campaign,
    'backup': Icons.backup,
    'export_import': Icons.file_download,
    'error': Icons.error,
    'login': Icons.login,
    'audit': Icons.history,
  };

  LogCard({
    super.key,
    required this.log,
    required this.getLevelFromType,
    required this.getCategoryFromType,
    required this.primaryBlue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = log['timestamp_local'] as DateTime?;
    final type = log['type'] ?? 'system';
    final level = getLevelFromType(type);
    final levelColor = _levelColors[level] ?? Colors.grey;
    final user = log['user'] ?? 'system';
    final description = log['description'] ?? 'No description';
    final targetUser = log['target_user'];
    final sessionId = log['session_id'];
    final category = getCategoryFromType(type);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // ========== ICON ==========
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _categoryIcons[category] ?? Icons.info,
                      color: levelColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ========== MIDDLE: TYPE & DESCRIPTION ==========
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              type.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: levelColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: levelColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                level,
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  color: levelColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.poppins(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // ========== RIGHT: TIME & USER ==========
                  // 🔥 FIX: Pakai ConstrainedBox biar ga overflow
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 100, // Batasi lebar maksimal
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timestamp != null
                              ? DateFormat('HH:mm:ss').format(timestamp)
                              : '-',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: primaryBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // ========== TARGET & SESSION ==========
              if (targetUser != null || sessionId != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (targetUser != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Target: $targetUser',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (sessionId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Session: ${sessionId.length > 8 ? '${sessionId.substring(0, 8)}...' : sessionId}',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}