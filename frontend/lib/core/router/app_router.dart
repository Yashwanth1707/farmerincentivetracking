import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/responsive_scaffold.dart';

// Global key for scaffold messaging
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Auth state provider
final authStateProvider = StateProvider<bool>((ref) => false);

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

/// Temporary placeholder screen - will be replaced with actual screens
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _PlaceholderScreen({
    Key? key,
    required this.title,
    this.subtitle,
  }) : super(key: key);

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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            Text(
              '🚧 Under Construction',
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
        builder: (context, state) => const _PlaceholderScreen(title: 'Login'),
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
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Dashboard'),
          ),
          GoRoute(
            path: '/farmers',
            name: RouteNames.farmers,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Farmers'),
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
                const _PlaceholderScreen(title: 'Users'),
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
                const _PlaceholderScreen(title: 'Financial Years'),
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
                const _PlaceholderScreen(title: 'Payments'),
            routes: [
              GoRoute(
                path: 'upload',
                name: RouteNames.paymentUpload,
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Upload Payments'),
              ),
            ],
          ),
          GoRoute(
            path: '/batches',
            name: RouteNames.batches,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Batches'),
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
                const _PlaceholderScreen(title: 'TDS Tracking'),
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
                const _PlaceholderScreen(title: 'SMS Module'),
            routes: [
              GoRoute(
                path: 'logs',
                name: RouteNames.smsLogs,
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'SMS Logs'),
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            name: RouteNames.reports,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Reports'),
            routes: [
              GoRoute(
                path: ':type',
                name: RouteNames.reportDetail,
                builder: (context, state) =>
                    _PlaceholderScreen(title: 'Report: ${state.pathParameters['type'] ?? ''}'),
              ),
            ],
          ),
          GoRoute(
            path: '/audit-logs',
            name: RouteNames.auditLogs,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Audit Logs'),
          ),
          GoRoute(
            path: '/settings',
            name: RouteNames.settings,
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Settings'),
            routes: [
              GoRoute(
                path: 'change-password',
                name: RouteNames.changePassword,
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Change Password'),
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