import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/services/notification_service.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final _notifService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  static const _primaryColor = Color(0xFF1B6EF3);
  static const _dangerColor = Color(0xFFEF4444);
  static const _textPrimary = Color(0xFF1E293B);
  static const _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _notifications = await _notifService.getNotificationsOnce(uid, limit: 50);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _notifService.markAllAsRead(uid);
    await _load();
  }

  Future<void> _onTapNotif(Map<String, dynamic> notif) async {
    if (notif['isRead'] != true) {
      await _notifService.markAsRead(notif['id']);
      setState(() => notif['isRead'] = true);
    }
    // TODO: kalau tiap type notifikasi ada tujuan halaman beda,
    // tambahkan navigasi berdasarkan notif['type'] / notif['data'] di sini.
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return DateFormat('d MMM yyyy', 'id_ID').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: _textPrimary),
        title: const Text(
          'Notifikasi',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed:
                _notifications.any((n) => n['isRead'] != true) ? _markAllRead : null,
            child: const Text('Tandai semua dibaca'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _notifications.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _buildItem(_notifications[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey[350]),
          const SizedBox(height: 12),
          Text('Belum ada notifikasi', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> notif) {
    final bool isRead = notif['isRead'] == true;
    return InkWell(
      onTap: () => _onTapNotif(notif),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isRead ? null : Border.all(color: _primaryColor.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: 10),
              decoration: BoxDecoration(
                color: isRead ? Colors.transparent : _dangerColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif['title'] ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      color: _textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif['body'] ?? '',
                    style: const TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(notif['createdAt'] as DateTime?),
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
