import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/login_screen.dart';

/// Navigation helper functions used by all scaffold variants
int _getSelectedIndex(BuildContext context) {
  final location = GoRouterState.of(context).matchedLocation;

  if (location.startsWith('/dashboard')) return 0;
  if (location.startsWith('/farmers')) return 1;
  if (location.startsWith('/payments')) return 2;
  if (location.startsWith('/reports')) return 3;

  // All remaining routes map to "More"
  return 4;
}

void _navigateToIndex(BuildContext context, int index) {
  switch (index) {
    case 0:
      context.goNamed(RouteNames.dashboard);
      break;

    case 1:
      context.goNamed(RouteNames.farmers);
      break;

    case 2:
      context.goNamed(RouteNames.payments);
      break;

    case 3:
      context.goNamed(RouteNames.reports);
      break;
    case 4:
      _showMoreNavigation(context); // <-- ADD IT HERE
      break;
  }
}

int _getMobileSelectedIndex(BuildContext context) {
  final location = GoRouterState.of(context).matchedLocation;
  if (location.startsWith('/dashboard')) return 0;
  if (location.startsWith('/farmers')) return 1;
  if (location.startsWith('/payments')) return 2;
  if (location.startsWith('/reports')) return 3;
  return 4;
}

void _showMoreNavigation(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          _MoreTile(
              icon: Icons.inventory_2_rounded,
              label: AppStrings.batches,
              route: RouteNames.batches),
          _MoreTile(
              icon: Icons.percent_rounded,
              label: AppStrings.tds,
              route: RouteNames.tds),
          _MoreTile(
              icon: Icons.message_rounded,
              label: AppStrings.sms,
              route: RouteNames.sms),
          _MoreTile(
              icon: Icons.history_rounded,
              label: AppStrings.auditLogs,
              route: RouteNames.auditLogs),
          _MoreTile(
              icon: Icons.calendar_month_rounded,
              label: AppStrings.financialYears,
              route: RouteNames.financialYears),
          _MoreTile(
              icon: Icons.people_outline_rounded,
              label: AppStrings.users,
              route: RouteNames.users),
          _MoreTile(
              icon: Icons.settings_rounded,
              label: AppStrings.settings,
              route: RouteNames.settings),
        ],
      ),
    ),
  );
}

void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            try {
              await DioClient().post(ApiEndpoints.logout);
            } finally {
              if (context.mounted) {
                context.goNamed(RouteNames.login);
              }
            }
          },
          child: const Text('Logout'),
        ),
      ],
    ),
  );
}

/// Responsive scaffold that shows sidebar on desktop and bottom nav on mobile
class ResponsiveScaffold extends StatelessWidget {
  final Widget child;

  const ResponsiveScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return _DesktopScaffold(child: child);
        }

        if (constraints.maxWidth >= 768) {
          return _TabletScaffold(child: child);
        }

        return _MobileScaffold(child: child);
      },
    );
  }
}

/// Desktop layout - sidebar navigation
class _DesktopScaffold extends StatelessWidget {
  final Widget child;

  const _DesktopScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SizedBox.expand(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sidebar
              SizedBox(
                width: 88,
                child: NavigationRail(
                  selectedIndex: _getSelectedIndex(context),
                  onDestinationSelected: (index) =>
                      _navigateToIndex(context, index),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: colorScheme.surface,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.agriculture_rounded,
                          size: 40,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'FIMS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: _navDestinations(context),
                  trailing: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      tooltip: 'Logout',
                      onPressed: () => _showLogoutDialog(context),
                    ),
                  ),
                ),
              ),

              // Vertical divider
              const VerticalDivider(width: 1),

              // Main content area
              Expanded(
                child: Column(
                  children: [
                    // Top bar
                    _TopBar(),
                    // Content

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SizedBox.expand(
                          child: child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tablet layout - collapsed sidebar
class _TabletScaffold extends StatelessWidget {
  final Widget child;

  const _TabletScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SizedBox.expand(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 72,
                child: NavigationRail(
                  selectedIndex: _getSelectedIndex(context),
                  onDestinationSelected: (index) =>
                      _navigateToIndex(context, index),
                  labelType: NavigationRailLabelType.none,
                  backgroundColor: colorScheme.surface,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Icon(
                      Icons.agriculture_rounded,
                      size: 32,
                      color: colorScheme.primary,
                    ),
                  ),
                  destinations: _navDestinations(context),
                  trailing: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () => _showLogoutDialog(context),
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mobile layout - bottom navigation
class _MobileScaffold extends StatelessWidget {
  final Widget child;

  const _MobileScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appShortName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getMobileSelectedIndex(context),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.goNamed(RouteNames.dashboard);
              break;
            case 1:
              context.goNamed(RouteNames.farmers);
              break;
            case 2:
              context.goNamed(RouteNames.payments);
              break;
            case 3:
              context.goNamed(RouteNames.reports);
              break;
            case 4:
              _showMoreNavigation(context);
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_rounded),
            label: 'Farmers',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_rounded),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        context.goNamed(route);
      },
    );
  }
}

/// Top bar with breadcrumbs and user info


class _TopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    final userName =
        authState.user?['fullName'] ??
        authState.user?['username'] ??
        'User';

    final role = authState.user?['role'] ?? '';

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 64,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Expanded(child: _Breadcrumb()),

            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.person_rounded,
                color: colorScheme.primary,
              ),
            ),

            const SizedBox(width: 8),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  role,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Breadcrumb navigation component
class _Breadcrumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).matchedLocation;
    final segments = location.split('/').where((s) => s.isNotEmpty).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Icon(
            Icons.home_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            'Home',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          for (final segment in segments) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              segment.replaceAll('-', ' '),
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: segment == segments.last
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

List<NavigationRailDestination> _navDestinations(BuildContext context) {
  return const [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_rounded),
      label: Text("Dashboard"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_rounded),
      label: Text("Farmers"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.payments_rounded),
      label: Text("Payments"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.assessment_rounded),
      label: Text("Reports"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.more_horiz),
      label: Text("More"),
    ),
  ];
}
