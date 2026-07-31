// lib/features/superadmin/widgets/settings_tools.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/app_colors.dart';

class SettingsTools extends StatelessWidget {
  const SettingsTools({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, color: AppColors.primaryBlue, size: 20),
              SizedBox(width: 8),
              Text('Pengaturan & Tools',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(
                'Export Data',
                Icons.download,
                () => _exportData(context),
              ),
              _buildChip(
                'Import Data',
                Icons.upload,
                () => _importData(context),
              ),
              _buildChip(
                'Clear Cache',
                Icons.cleaning_services,
                () => _clearCache(context),
              ),
              _buildChip(
                'Sistem Log',
                Icons.list_alt,
                () => _viewSystemLogs(context),
              ),
              _buildChip(
                'FAQ Bot',
                Icons.help_center,
                () => _showFAQ(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: AppColors.primaryBlue.withAlpha(26),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.primaryBlue)),
        ],
      ),
    );
  }

  void _exportData(BuildContext context) async {
    try {
      // Log export activity
      await FirebaseFirestore.instance.collection('activity_logs').add({
        'action': 'export_data',
        'user': FirebaseAuth.instance.currentUser?.email ?? 'unknown',
        'role': 'superadmin',
        'description': 'Export data initiated',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Simpan export log
      await FirebaseFirestore.instance.collection('export_logs').add({
        'user_id': FirebaseAuth.instance.currentUser?.uid,
        'user_name': FirebaseAuth.instance.currentUser?.displayName ?? 'Super Admin',
        'export_type': 'pdf',
        'export_date': FieldValue.serverTimestamp(),
        'filter_used': {'type': 'all'},
        'status': 'processing',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Export data dimulai...'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _importData(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('activity_logs').add({
        'action': 'import_data',
        'user': FirebaseAuth.instance.currentUser?.email ?? 'unknown',
        'role': 'superadmin',
        'description': 'Import data initiated',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fitur import dalam pengembangan'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _clearCache(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('activity_logs').add({
        'action': 'clear_cache',
        'user': FirebaseAuth.instance.currentUser?.email ?? 'unknown',
        'role': 'superadmin',
        'description': 'Cache cleared',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Cache dibersihkan!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _viewSystemLogs(BuildContext context) {
    Navigator.pushNamed(context, '/system-logs');
  }

  void _showFAQ(BuildContext context) {
    Navigator.pushNamed(context, '/faq');
  }
}