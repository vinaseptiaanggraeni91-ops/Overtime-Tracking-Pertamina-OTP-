import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// AUTH
import '../../screens/welcome_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/register_screen.dart';
import '../../screens/reset_password_screen.dart';
import '../../screens/reset_password_confirm_screen.dart';
import '../../screens/profile_menu_screen.dart';

// SUPERADMIN
import '../../dashboard/superadmin/superadmin_dashboard.dart';
import '../../dashboard/superadmin/user_management.dart';
import '../../dashboard/superadmin/help_desk_admin_screen.dart';
import '../../dashboard/superadmin/settings/settings_screen.dart';
import '../../dashboard/superadmin/settings/notification_preferences_screen.dart';
import '../../dashboard/superadmin/settings/overtime_rates_screen.dart';
import '../../dashboard/superadmin/settings/about_app_screen.dart';
import '../../dashboard/superadmin/laporan_screen.dart';
import '../../dashboard/superadmin/system_logs_screen.dart';
import '../../dashboard/superadmin/admin_approval_screen.dart';
import '../../dashboard/superadmin/master_pekerja_screen.dart';

// MANAGER
import '../../dashboard/manager/manager_dashboard.dart';
import '../../dashboard/manager/location_menu_screen.dart';
import '../../dashboard/manager/member_detail_screen.dart';
import '../../dashboard/manager/approval_lembur_screen.dart';

// PENGAWAS
import '../../dashboard/pengawas/pengawas_dashboard.dart';
import '../../dashboard/pengawas/ajukan_lembur_screen.dart';
import '../../screens/my_team/my_team_screen.dart';

// MITRA
import '../../dashboard/mitra/mitra_dashboard.dart';
import '../../dashboard/mitra/absensi_history_screen.dart';
import '../../dashboard/mitra/jadwal_lembur_screen.dart';
import '../../dashboard/mitra/absensi_page.dart';
import '../../dashboard/mitra/pendapatan_screen.dart';

// SHARED
import '../../screens/overtime_history_screen.dart';

// SERVICES
import '../services/auth_service.dart';

class AppRouter {
  final AuthService _authService = AuthService();

  GoRouter get router => GoRouter(
        redirect: _guardAuth,
        errorBuilder: (context, state) => Scaffold(
          appBar: AppBar(
            title: const Text('Halaman Tidak Ditemukan'),
            backgroundColor: Colors.red,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Route "${state.uri}" tidak terdaftar',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
        routes: [
          // ============================================================
          // 🔓 PUBLIC ROUTES (Tidak memerlukan login)
          // ============================================================
          GoRoute(
            path: '/',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: '/welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const RegisterScreen(),
          ),
          
          GoRoute(
          path: '/reset-password',
          builder: (context, state) {
            final oobCode = state.uri.queryParameters['oobCode'] ?? '';
            return ResetPasswordConfirmScreen(oobCode: oobCode);
          },
        ),


          GoRoute(
          // Layar "kirim email reset" (yang lama, sudah disederhanakan)
          path: '/reset-password-request',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            return ResetPasswordScreen(initialEmail: email);
          },
        ),

          GoRoute(
            path: '/superadmin-dashboard',
            builder: (context, state) => const SuperAdminDashboard(),
          ),
          GoRoute(
            path: '/riwayat-absensi',
            builder: (context, state) => const AbsensiHistoryScreen(),
          ),
          GoRoute(
            path: '/user-management',
            builder: (context, state) => const UserManagementScreen(),
          ),
          GoRoute(
            path: '/help-desk-admin',
            builder: (context, state) => const HelpDeskAdminScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/overtime-rates',
            builder: (context, state) => const OvertimeRatesScreen(),
          ),
          GoRoute(
            path: '/settings/about-app',
            builder: (context, state) => const AboutAppScreen(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final userRole = extra?['userRole'] as String? ?? '';
              final userFungsi = extra?['userFungsi'] as String?;
              final userId = extra?['userId'] as String?;
              
              return ReportPage(
                userRole: userRole,
                userFungsi: userFungsi,
                userId: userId,
              );
            },
          ),
          GoRoute(
            path: '/system-logs',
            builder: (context, state) => const SystemLogsScreen(),
          ),
          GoRoute(
            path: '/admin/approval',
            builder: (context, state) => const ApprovalLemburScreen(),
          ),
          GoRoute(
            path: '/approval',
            builder: (context, state) => const ManagerApprovalLemburScreen(),
          ),
          GoRoute(
            path: '/superadmin/master-pekerja',
            builder: (context, state) => const MasterPekerjaScreen(),
          ),
          GoRoute(
            path: '/income',
            builder: (context, state) => const PendapatanScreen(),
          ),

          // ============================================================
          // 📊 MANAGER ROUTES
          // ============================================================
          GoRoute(
            path: '/manager-dashboard',
            builder: (context, state) => const ManagerDashboard(),
          ),
          GoRoute(
            path: '/overtime-data',
            builder: (context, state) => const OvertimeHistoryScreen(),
          ),
          GoRoute(
            path: '/location-monitoring',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final userRole = extra?['userRole'] as String? ?? 'manager';
              return LocationMenuScreen(userRole: userRole);
            },
          ),
          GoRoute(
            path: '/member-detail/:memberId',
            builder: (context, state) {
              final memberId = state.pathParameters['memberId'] ?? '';
              final extra = state.extra as Map<String, dynamic>?;
              return MemberDetailScreen(
                memberId: memberId,
                memberData: extra?['member'],
              );
            },
          ),

          GoRoute(
            path: '/pengawas-dashboard',
            builder: (context, state) => const PengawasDashboard(),
          ),
          GoRoute(
            path: '/ajukan-lembur',
            builder: (context, state) => const AjukanLemburPage(),
          ),
          GoRoute(
            path: '/my-team',
            builder: (context, state) => const MyTeamScreen(),
          ),

          GoRoute(
            path: '/mitra-dashboard',
            builder: (context, state) => const MitraDashboard(),
          ),
          GoRoute(
            path: '/riwayat-absensi',
            builder: (context, state) => const OvertimeHistoryScreen(),
          ),
          GoRoute(
            path: '/jadwal-lembur',
            builder: (context, state) => const JadwalLemburScreen(),
          ),
          GoRoute(
            path: '/mitra-absensi',
            name: 'mitra-absensi',
            builder: (context, state) => const AbsensiPage(),
          ),
          
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings/notifications',
            builder: (context, state) => const NotificationPreferencesScreen(),
          ),
        ],
      );

  // ============================================================
  // 🛡️ GUARD / MIDDLEWARE
  // ============================================================
  Future<String?> _guardAuth(
    BuildContext context, GoRouterState state) async {

  // Ambil path tanpa query parameter
  String cleanRoute = state.uri.path;

  // Hilangkan trailing slash jika ada
  if (cleanRoute.endsWith('/') && cleanRoute != '/') {
    cleanRoute = cleanRoute.substring(0, cleanRoute.length - 1);
  }

  debugPrint('GoRouter URI  : ${state.uri}');
  debugPrint('GoRouter PATH : $cleanRoute');

  const publicRoutes = [
    '/',
    '/welcome',
    '/login',
    '/register',
    '/reset-password',
    '/reset-password-request',
  ];

  if (publicRoutes.contains(cleanRoute)) {
    if (_authService.isLoggedIn) {
      final role = await _authService.getUserRole();
      if (role != null) {
        return _authService.getDashboardPath(role);
      }
    }
    return null;
  }

  if (!_authService.isLoggedIn) {
    return '/login';
  }

  final validationResult = await _authService.validateAccess();
  if (validationResult != null) {
    return validationResult;
  }

    // Ambil role user
    final role = await _authService.getUserRole();

    if (role != null) {
      // ============================================================
      // 🚫 CEK AKSES BERDASARKAN ROLE
      // ============================================================
      
      // Mapping route prefix ke role yang diizinkan
      final routeRoleMap = {
        '/superadmin': 'superadmin',
        '/manager': 'manager',
        '/pengawas': 'pengawas',
        '/mitra': 'mitra',
      };

      // Cek apakah route membutuhkan role tertentu
      for (final entry in routeRoleMap.entries) {
        if (cleanRoute.startsWith(entry.key) && role != entry.value) {
          // Jika role tidak sesuai, redirect ke dashboard role tersebut
          return _authService.getDashboardPath(role);
        }
      }

      // ============================================================
      // 🚫 ROUTE KHUSUS ADMIN (Superadmin & Manager)
      // ============================================================
      const adminOnlyRoutes = [
        '/user-management',
        '/help-desk-admin',
        '/settings',
        '/settings/overtime-rates',
        '/reports-audit',
        '/system-logs',
        '/admin/approval',
        '/faq/add',
        '/faq/edit',
      ];

      if (adminOnlyRoutes.any((route) => cleanRoute.startsWith(route)) &&
          !['superadmin', 'manager'].contains(role)) {
        return _authService.getDashboardPath(role);
      }

      // ============================================================
      // 🚫 ROUTE KHUSUS SUPERADMIN
      // ============================================================
      const superAdminOnlyRoutes = [
        '/settings',
        '/settings/overtime-rates',
        '/system-logs',
      ];

      if (superAdminOnlyRoutes.contains(cleanRoute) && role != 'superadmin') {
        return _authService.getDashboardPath(role);
      }

      // ============================================================
      // ✅ SHARED ROUTES (Bisa diakses semua role)
      // ============================================================
      const sharedRoutes = [
        '/profile',
        '/faq',
        '/chat',
        '/overtime-data',
        '/location-monitoring',
      ];

      if (sharedRoutes.any((route) => cleanRoute.startsWith(route))) {
        return null; // Diizinkan
      }

      // ============================================================
      // 🚫 ROUTE KHUSUS MITRA
      // ============================================================
      if (cleanRoute.startsWith('/mitra-absensi') && role != 'mitra') {
        return _authService.getDashboardPath(role);
      }
    }

    // Jika semua validasi lolos, izinkan akses
    return null;
  }
}