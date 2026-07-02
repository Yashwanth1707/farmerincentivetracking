import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fims_frontend/shared/widgets/responsive_scaffold.dart';
import 'package:fims_frontend/features/payments/payment_upload_screen.dart';
import 'package:fims_frontend/features/auth/login_screen.dart';
import 'package:fims_frontend/features/farmers/farmers_screen.dart';
import 'package:fims_frontend/features/admin/models/resource_config.dart';
import 'package:fims_frontend/features/admin/screens/change_password_screen.dart';
import 'package:fims_frontend/features/admin/screens/reports_screen.dart';
import 'package:fims_frontend/features/admin/screens/resource_list_screen.dart';
import 'package:fims_frontend/features/admin/screens/settings_screen.dart';
import 'package:fims_frontend/features/dashboard/dashboard_screen.dart';

// Global key for scaffold messaging
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// User role provider
final userRoleProvider = StateProvider<String?>((ref) => null);

/// Route names for navigation
class RouteNames {
  static const String login = 'login';
  static const String forgotPassword = 'forgot-password';
  static const String resetPassword = 'reset-password';

  // Main shell routes
  static const String dashboard = 'dashboard';
  static const String farmers = 'farmers';
  static const String farmerDetail = 'farmer-detail';
  static const String farmerCreate = 'farmer-create';
  static const String farmerEdit = 'farmer-edit';
  static const String users = 'users';
  static const String userCreate = 'user-create';
  static const String userEdit = 'user-edit';
  static const String financialYears = 'financial-years';
  static const String financialYearCreate = 'financial-year-create';
  static const String financialYearEdit = 'financial-year-edit';
  static const String payments = 'payments';
  static const String paymentUpload = 'payment-upload';
  static const String batches = 'batches';
  static const String batchDetail = 'batch-detail';
  static const String tds = 'tds';
  static const String tdsHistory = 'tds-history';
  static const String sms = 'sms';
  static const String smsLogs = 'sms-logs';
  static const String reports = 'reports';
  static const String reportDetail = 'report-detail';
  static const String auditLogs = 'audit-logs';
  static const String settings = 'settings';
  static const String changePassword = 'change-password';
}

/// Simple route fallback for utility auth screens that are not backend-backed yet.
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 64,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              'Under Construction',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: true,
    navigatorKey: GlobalKey<NavigatorState>(),
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: RouteNames.forgotPassword,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Forgot Password'),
      ),
      GoRoute(
        path: '/reset-password',
        name: RouteNames.resetPassword,
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Reset Password'),
      ),
      ShellRoute(
        builder: (context, state, child) => ResponsiveScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: RouteNames.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/farmers',
            name: RouteNames.farmers,
            builder: (context, state) => const FarmersScreen(),
            routes: [
              GoRoute(
                path: 'create',
                name: RouteNames.farmerCreate,
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Create Farmer'),
              ),
              GoRoute(
                path: ':id',
                name: RouteNames.farmerDetail,
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Farmer Detail'),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: RouteNames.farmerEdit,
                    builder: (context, state) =>
                        const _PlaceholderScreen(title: 'Edit Farmer'),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/users',
            name: RouteNames.users,
            builder: (context, state) =>
                ResourceListScreen(config: ResourceConfigs.users),
            routes: [
              GoRoute(
                path: 'create',
                name: RouteNames.userCreate,
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Create User'),
              ),
              GoRoute(
                path: ':id/edit',
                name: RouteNames.userEdit,
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Edit User'),
              ),
            ],
          ),
          GoRoute(
            path: '/financial-years',
            name: RouteNames.financialYears,
            builder: (context, state) =>
                ResourceListScreen(config: ResourceConfigs.financialYears),
            routes: [
              GoRoute(
                path: 'create',
                name: RouteNames.financialYearCreate,
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Create Financial Year'),
              ),
              GoRoute(
                path: ':id/edit',
                name: RouteNames.financialYearEdit,
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Edit Financial Year'),
              ),
            ],
          ),
          GoRoute(
            path: '/payments',
            name: RouteNames.payments,
            builder: (context, state) =>
                ResourceListScreen(config: ResourceConfigs.payments),
            routes: [
              GoRoute(
                path: 'upload',
                name: RouteNames.paymentUpload,
                builder: (context, state) => const PaymentUploadScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/batches',
            name: RouteNames.batches,
            builder: (context, state) =>
                ResourceListScreen(config: ResourceConfigs.batches),
            routes: [
              GoRoute(
                path: ':id',
                name: RouteNames.batchDetail,
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Batch Detail'),
              ),
            ],
          ),
          GoRoute(
            path: '/tds',
            name: RouteNames.tds,
            builder: (context, state) =>
                ResourceListScreen(config: ResourceConfigs.tds),
            routes: [
              GoRoute(
                path: 'history',
                name: RouteNames.tdsHistory,
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'TDS History'),
              ),
            ],
          ),
          GoRoute(
            path: '/sms',
            name: RouteNames.sms,
            builder: (context, state) =>
                ResourceListScreen(config: ResourceConfigs.sms),
            routes: [
              GoRoute(
                path: 'logs',
                name: RouteNames.smsLogs,
                builder: (context, state) =>
                    ResourceListScreen(config: ResourceConfigs.smsLogs),
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            name: RouteNames.reports,
            builder: (context, state) => const ReportsScreen(),
            routes: [
              GoRoute(
                path: ':type',
                name: RouteNames.reportDetail,
                builder: (context, state) => _PlaceholderScreen(
                    title: 'Report: ${state.pathParameters['type'] ?? ''}'),
              ),
            ],
          ),
          GoRoute(
            path: '/audit-logs',
            name: RouteNames.auditLogs,
            builder: (context, state) =>
                ResourceListScreen(config: ResourceConfigs.auditLogs),
          ),
          GoRoute(
            path: '/settings',
            name: RouteNames.settings,
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'change-password',
                name: RouteNames.changePassword,
                builder: (context, state) => const ChangePasswordScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        const _PlaceholderScreen(title: '404 - Page Not Found'),
  );
});
