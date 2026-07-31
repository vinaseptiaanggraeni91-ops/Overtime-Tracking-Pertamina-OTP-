// ============================================================
// FILE : lib/dashboard/superadmin/settings/notification_preferences_screen.dart
// Ini yang dibuka dari menu "Notifikasi & Alert" di settings_screen.dart
// route: '/settings/notifications'
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Daftar jenis notifikasi — harus sinkron dengan `notificationTypes`
/// di notification_service.dart
const Map<String, String> _notificationTypeLabels = {
  'lembur_submitted': 'Pengajuan Lembur Baru',
  'lembur_approved': 'Lembur Disetujui',
  'lembur_rejected': 'Lembur Ditolak',
  'lembur_assignment': 'Penugasan Mitra',
  'spkl_ready': 'SPKL Siap',
  'absensi_reminder': 'Pengingat Absensi',
  'check_in': 'Check In',
  'check_out': 'Check Out',
  'lembur_completed': 'Lembur Selesai',
  'lembur_confirmed': 'Lembur Dikonfirmasi',
  'general': 'Notifikasi Umum',
  'hsse_risk_validation': 'Validasi Risiko HSSE',
};

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  bool _saving = false;

  // Channel
  bool _pushEnabled = true;
  bool _inAppEnabled = true;

  // Suara
  bool _soundEnabled = true;

  // Per jenis notifikasi (default semua true)
  late Map<String, bool> _typeToggles;

  @override
  void initState() {
    super.initState();
    _typeToggles = {for (final k in _notificationTypeLabels.keys) k: true};
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await _firestore
          .collection('notification_preferences')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _pushEnabled = data['pushEnabled'] ?? true;
        _inAppEnabled = data['inAppEnabled'] ?? true;
        _soundEnabled = data['soundEnabled'] ?? true;
        final types = data['types'] as Map<String, dynamic>?;
        if (types != null) {
          for (final key in _typeToggles.keys) {
            _typeToggles[key] = types[key] ?? true;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Gagal load preferensi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePreferences() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await _firestore.collection('notification_preferences').doc(uid).set({
        'pushEnabled': _pushEnabled,
        'inAppEnabled': _inAppEnabled,
        'soundEnabled': _soundEnabled,
        'types': _typeToggles,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferensi notifikasi tersimpan'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        title: Text(
          'Notifikasi & Alert',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3C72)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                _sectionLabel('Suara & Channel'),
                const SizedBox(height: 10),
                _card([
                  _switchTile(
                    title: 'Suara Notifikasi',
                    subtitle: 'Bunyikan suara saat notifikasi masuk',
                    value: _soundEnabled,
                    onChanged: (v) => setState(() => _soundEnabled = v),
                  ),
                  const Divider(height: 1),
                  _switchTile(
                    title: 'Push Notification',
                    subtitle: 'Notifikasi muncul walau aplikasi tertutup',
                    value: _pushEnabled,
                    onChanged: (v) => setState(() => _pushEnabled = v),
                  ),
                  const Divider(height: 1),
                  _switchTile(
                    title: 'Notifikasi Dalam Aplikasi',
                    subtitle: 'Tampilkan di lonceng notifikasi dalam app',
                    value: _inAppEnabled,
                    onChanged: (v) => setState(() => _inAppEnabled = v),
                  ),
                ]),
                const SizedBox(height: 28),
                _sectionLabel('Jenis Notifikasi'),
                const SizedBox(height: 10),
                _card(
                  _notificationTypeLabels.entries
                      .map((entry) => Column(
                            children: [
                              _switchTile(
                                title: entry.value,
                                value: _typeToggles[entry.key] ?? true,
                                onChanged: (v) =>
                                    setState(() => _typeToggles[entry.key] = v),
                              ),
                              if (entry.key != _notificationTypeLabels.keys.last)
                                const Divider(height: 1),
                            ],
                          ))
                      .toList(),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _savePreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3C72),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Simpan Preferensi',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: children),
      );

  Widget _switchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1E293B),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            )
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF1E3C72),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    );
  }
}
