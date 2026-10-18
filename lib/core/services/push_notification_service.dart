// ============================================================
// FILE : lib/core/services/push_notification_service.dart
// Terima push notification (FCM) + tampilkan dengan suara lewat
// flutter_local_notifications.
// ============================================================

import 'dart:convert';
import 'dart:io'; // ⬅️ TAMBAHKAN INI
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

/// Handler ini WAJIB top-level function (bukan method di class),
/// dipanggil sistem saat notifikasi masuk ketika app di-background/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 [Background] Notifikasi masuk: ${message.messageId}');
  // Nggak perlu nampilin manual di sini — FCM notification payload
  // otomatis ditampilkan sistem Android/iOS saat app di background.
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ⬇️ GANTI NAMA CHANNEL ID (WAJIB UNTUK RESET)
  static const String _channelId = 'overtime_notifications_v2';
  static const String _channelName = 'Notifikasi Lembur';
  static const String _channelDescription =
      'Notifikasi approval, absensi, dan alert sistem lembur';

  /// Panggil ini SEKALI di main.dart setelah Firebase.initializeApp(),
  /// dan juga setelah user berhasil login.
  Future<void> initialize(BuildContext context) async {
    if (_initialized) return;
    _initialized = true;

    // 🔑 TAMBAHKAN: Request POST_NOTIFICATIONS untuk Android 13+
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      debugPrint('🔔 Android notification permission granted: $granted');
    }

    // 1) Minta izin notifikasi (wajib di Android 13+ dan iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('🔔 Izin notifikasi: ${settings.authorizationStatus}');

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2) Setup local notifications (buat nampilin + custom sound saat app di foreground)
    await _setupLocalNotifications(context);

    // 3) Simpan/refresh FCM token user ke Firestore
    await _registerToken();
    _messaging.onTokenRefresh.listen((newToken) => _saveToken(newToken));

    // 4) Handler saat notifikasi masuk ketika app TERBUKA (foreground)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5) Handler saat user TAP notifikasi (app di background, lalu dibuka)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigateFromNotification(context, message.data);
    });

    // 6) Kalau app dibuka DARI KEADAAN TERTUTUP lewat notifikasi
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _navigateFromNotification(context, initialMessage.data);
    }
  }

  /// Digunakan setelah user login agar token terbaru langsung tersimpan.
  Future<void> refreshToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribe topic: $topic');
    } catch (e) {
      debugPrint('❌ Subscribe topic gagal: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribe topic: $topic');
    } catch (e) {
      debugPrint('❌ Unsubscribe topic gagal: $e');
    }
  }

  // ⬇️ TAMBAHKAN TEST METHOD
  Future<void> testLocalNotification() async {
    debugPrint('🧪 Test local notification...');
    
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: '🔔 TEST SUARA',
      body: 'Kalau muncul & bersuara berarti BERHASIL!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'overtime_notifications_v2',
          'Notifikasi Lembur',
          channelDescription: 'Notifikasi approval, absensi, dan alert sistem lembur',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
          presentBadge: true,
        ),
      ),
    );
    
    debugPrint('🧪 Test local notification terkirim!');
  }

  // =========================================================
  // SETUP LOCAL NOTIFICATIONS (channel + suara)
  // =========================================================
  Future<void> _setupLocalNotifications(BuildContext context) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Di versi 22.0.1, initialize menerima named parameter 'settings'
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          _navigateFromNotification(context, data);
        }
      },
    );

    // Buat notification channel Android dengan suara default sistem.
    // ⬇️ PAKAI Importance.max SUPAYA HEADS-UP & SUARA KERAS
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,  // ⬅️ GANTI DARI HIGH KE MAX
      playSound: true,
      enableVibration: true,       // ⬅️ TAMBAHKAN VIBRASI
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // =========================================================
  // TAMPILKAN NOTIFIKASI SAAT APP TERBUKA (FOREGROUND)
  // =========================================================
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Cek preferensi user dulu sebelum nampilin
    final type = message.data['type'] as String?;
    final allowed = await _isTypeEnabled(type);
    if (!allowed) {
      debugPrint('🔕 Notifikasi type "$type" di-mute user, skip.');
      return;
    }

    final notification = message.notification;
    if (notification == null) return;

    // Di versi 22.0.1, show() menggunakan named parameters
    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,    // ⬅️ MAX
          priority: Priority.high,
          playSound: true,
          enableVibration: true,         // ⬅️ TAMBAHKAN
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,            // ⬅️ TAMBAHKAN
          presentBadge: true,            // ⬅️ TAMBAHKAN
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // =========================================================
  // NAVIGASI SAAT NOTIFIKASI DI-TAP
  // =========================================================
  void _navigateFromNotification(BuildContext context, Map<String, dynamic> data) {
    final route = data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      context.push(route);
    }
  }

  // =========================================================
  // SIMPAN FCM TOKEN KE FIRESTORE (users/{uid}.fcmToken)
  // =========================================================
  Future<void> _registerToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    debugPrint('📱 FCM Token: $token');       // ⬅️ TAMBAHKAN LOG
    debugPrint('👤 User ID: $uid');           // ⬅️ TAMBAHKAN LOG
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ FCM token tersimpan');
    } catch (e) {
      debugPrint('❌ Gagal simpan FCM token: $e');
    }
  }

  /// Panggil ini saat user LOGOUT, biar device yang sudah logout
  /// nggak lagi kebagian notifikasi punya orang lain.
  Future<void> clearToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
      await _messaging.deleteToken();
      _initialized = false;
    } catch (e) {
      debugPrint('❌ Gagal hapus FCM token: $e');
    }
  }

  Future<bool> _isTypeEnabled(String? type) async {
    if (type == null) return true;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return true;

    try {
      final doc = await _firestore
          .collection('notification_preferences')
          .doc(uid)
          .get();

      if (!doc.exists) return true; // default: semua nyala

      final data = doc.data()!;
      final soundEnabled = data['soundEnabled'] ?? true;
      final typeEnabled = (data['types'] as Map<String, dynamic>?)?[type] ?? true;

      return soundEnabled && typeEnabled;
    } catch (e) {
      debugPrint('⚠️ Gagal cek preferensi notifikasi: $e');
      return true; // fallback: tetap tampilkan kalau gagal cek
    }
  }
}