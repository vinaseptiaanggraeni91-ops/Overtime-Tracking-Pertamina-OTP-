import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';

import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/overtime_approval_service.dart';
import 'core/services/overtime_rate_service.dart';
import 'core/services/spkl_generator_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/network_service.dart';
import 'core/controllers/approval_controller.dart';

import 'widgets/network/network_popup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Handler notifikasi background
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  // Inisialisasi Network Service
  NetworkService();

  runApp(const MyApp());
}

/// ======================================================
/// APP INITIALIZER
/// Dipanggil sekali untuk inisialisasi Push Notification
/// ======================================================
class AppInitializer extends StatefulWidget {
  final Widget child;

  const AppInitializer({
    super.key,
    required this.child,
  });

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;

    _initialized = true;

    Future.microtask(() async {
      await context.read<PushNotificationService>().initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter();

    return MultiProvider(
      providers: [
        // ================= FIREBASE =================
        Provider<FirebaseAuth>(
          create: (_) => FirebaseAuth.instance,
        ),

        Provider<FirebaseFirestore>(
          create: (_) => FirebaseFirestore.instance,
        ),

        // ================= SERVICES =================
        Provider<SpklGeneratorService>(
          create: (_) => SpklGeneratorService(),
        ),

        Provider<NotificationService>(
          create: (_) => NotificationService(),
        ),

        Provider<PushNotificationService>(
          create: (_) => PushNotificationService(),
        ),

        Provider<OvertimeRateService>(
          create: (_) => OvertimeRateService(),
        ),

        Provider<NetworkService>.value(
          value: NetworkService(),
        ),

        Provider<OvertimeApprovalService>(
          create: (context) => OvertimeApprovalService(
            firestore: context.read<FirebaseFirestore>(),
            auth: context.read<FirebaseAuth>(),
            notificationService: context.read<NotificationService>(),
          ),
        ),

        // ================= CONTROLLER =================
        ChangeNotifierProvider<ApprovalController>(
          create: (context) => ApprovalController(
            auth: context.read<FirebaseAuth>(),
            firestore: context.read<FirebaseFirestore>(),
            approvalService: context.read<OvertimeApprovalService>(),
            rateService: context.read<OvertimeRateService>(),
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Aplikasi OTP',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter.router,

        builder: (context, child) {
          return AppInitializer(
            child: NetworkPopup(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },

        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        supportedLocales: const [
          Locale('id', 'ID'),
          Locale('en', 'US'),
        ],

        locale: const Locale('id', 'ID'),

        theme: ThemeData(
          fontFamily: 'Poppins',
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: false,

          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3C72),
          ),

          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E3C72),
            foregroundColor: Colors.white,
            elevation: 0,
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3C72),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}