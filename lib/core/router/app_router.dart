import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/enrollment/presentation/screens/enrollment_list_screen.dart';
import '../../features/enrollment/presentation/screens/enroll_student_screen.dart';
import '../../features/enrollment/presentation/screens/consent_screen.dart';
import '../../features/scan/presentation/screens/scan_setup_screen.dart';
import '../../features/scan/presentation/screens/live_scan_screen.dart';
import '../../features/scan/presentation/screens/review_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/reports/presentation/screens/student_report_screen.dart';
import '../../features/manual_override/presentation/screens/manual_attendance_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/privacy_screen.dart';
import '../blocs/auth/auth_bloc.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: _guardRoute,
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      // Enrollment
      GoRoute(
        path: '/enrollment',
        name: 'enrollment',
        builder: (context, state) => const EnrollmentListScreen(),
        routes: [
          GoRoute(
            path: 'consent/:studentId',
            name: 'consent',
            builder: (context, state) => ConsentScreen(
              studentId: state.pathParameters['studentId']!,
            ),
          ),
          GoRoute(
            path: 'enroll/:studentId',
            name: 'enroll',
            builder: (context, state) => EnrollStudentScreen(
              studentId: state.pathParameters['studentId']!,
            ),
          ),
        ],
      ),
      // Scan Flow
      GoRoute(
        path: '/scan',
        name: 'scan',
        builder: (context, state) => const ScanSetupScreen(),
        routes: [
          GoRoute(
            path: 'live/:sessionId',
            name: 'liveScan',
            builder: (context, state) => LiveScanScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
          GoRoute(
            path: 'review/:sessionId',
            name: 'review',
            builder: (context, state) => ReviewScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
        ],
      ),
      // Reports
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
        routes: [
          GoRoute(
            path: 'student/:studentId',
            name: 'studentReport',
            builder: (context, state) => StudentReportScreen(
              studentId: state.pathParameters['studentId']!,
            ),
          ),
        ],
      ),
      // Manual Override
      GoRoute(
        path: '/manual/:sessionId',
        name: 'manual',
        builder: (context, state) => ManualAttendanceScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      // Settings
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
    ],
  );

  static String? _guardRoute(BuildContext context, GoRouterState state) {
    final authState = context.read<AuthBloc>().state;
    final isLoggedIn = authState is AuthAuthenticated;
    final isSplash = state.matchedLocation == '/splash';
    final isLogin = state.matchedLocation == '/login';

    if (isSplash) return null;
    if (!isLoggedIn && !isLogin) return '/login';
    if (isLoggedIn && isLogin) return '/dashboard';
    return null;
  }
}
