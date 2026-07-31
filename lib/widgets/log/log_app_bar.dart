import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LogAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Color primaryBlue;
  final VoidCallback onRefresh;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPDF;
  final VoidCallback onClearOldLogs;

  const LogAppBar({
    super.key,
    required this.primaryBlue,
    required this.onRefresh,
    required this.onExportExcel,
    required this.onExportPDF,
    required this.onClearOldLogs,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        'Log Sistem',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: primaryBlue,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: onRefresh,
          tooltip: 'Refresh Data',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'export_excel':
                onExportExcel();
                break;
              case 'export_pdf':
                onExportPDF();
                break;
              case 'clear_old':
                onClearOldLogs();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export_excel',
              child: ListTile(
                leading: Icon(Icons.table_chart, color: Colors.green),
                title: Text('Export ke Excel'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'export_pdf',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('Export ke PDF'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'clear_old',
              child: ListTile(
                leading: Icon(Icons.delete_sweep, color: Colors.orange),
                title: Text('Hapus Log Lama (>30 hari)'),
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}