import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/router/app_router.dart';

/// Navigation helper functions used by all scaffold variants
int _getSelectedIndex(BuildContext context) {
  final location = GoRouterState.of(context).matchedLocation;
  if (location.startsWith('/dashboard')) return 0;
  if (location.startsWith('/farmers')) return 1;
  if (location.startsWith('/payments')) return 2;
  if (location.startsWith('/batches')) return 3;
  if (location.startsWith('/tds')) return 4;
  if (location.startsWith('/sms')) return 5;
  if (location.startsWith('/reports')) return 6;
  if (location.startsWith('/audit-logs')) return 7;
  if (location.startsWith('/financial-years')) return 8;
  if (location.startsWith('/users')) return 9;
  if (location.startsWith('/settings')) return 10;
  return 0;
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
      context.goNamed(RouteNames.batches);
      break;
    case 4:
      context.goNamed(RouteNames.tds);
      break;
    case 5:
      context.goNamed(RouteNames.sms);
      break;
    case 6:
      context.goNamed(RouteNames.reports);
      break;
    case 7:
      context.goNamed(RouteNames.auditLogs);
      break;
    case 8:
      context.goNamed(RouteNames.financialYears);
      break;
    case 9:
      context.goNamed(RouteNames.users);
      break;
    case 10:
      context.goNamed(RouteNames.settings);
      break;
  }
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
  final String? currentRoute;

  const ResponsiveScaffold({
    super.key,
    required this.child,
    this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return _DesktopScaffold(child: child);
        } else if (constraints.maxWidth >= AppConstants.tabletBreakpoint) {
          return _TabletScaffold(child: child);
        } else {
          return _MobileScaffold(child: child);
        }
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
      body: Row(
        children: [
          // Sidebar
          SingleChildScrollView(
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
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<NavigationRailDestination> _navDestinations(BuildContext context) {
    return [
      NavigationRailDestination(
        icon: const Icon(Icons.dashboard_rounded),
        selectedIcon: const Icon(Icons.dashboard_rounded),
        label: const Text(AppStrings.dashboard),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.people_rounded),
        selectedIcon: const Icon(Icons.people_rounded),
        label: const Text(AppStrings.farmers),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.payments_rounded),
        selectedIcon: const Icon(Icons.payments_rounded),
        label: const Text(AppStrings.payments),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.inventory_2_rounded),
        selectedIcon: const Icon(Icons.inventory_2_rounded),
        label: const Text(AppStrings.batches),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.percent_rounded),
        selectedIcon: const Icon(Icons.percent_rounded),
        label: const Text(AppStrings.tds),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.message_rounded),
        selectedIcon: const Icon(Icons.message_rounded),
        label: const Text(AppStrings.sms),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.assessment_rounded),
        selectedIcon: const Icon(Icons.assessment_rounded),
        label: const Text(AppStrings.reports),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.history_rounded),
        selectedIcon: const Icon(Icons.history_rounded),
        label: const Text(AppStrings.auditLogs),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.calendar_month_rounded),
        selectedIcon: const Icon(Icons.calendar_month_rounded),
        label: const Text(AppStrings.financialYears),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.people_outline_rounded),
        selectedIcon: const Icon(Icons.people_outline_rounded),
        label: const Text(AppStrings.users),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_rounded),
        selectedIcon: const Icon(Icons.settings_rounded),
        label: const Text(AppStrings.settings),
      ),
    ];
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
      body: Row(
        children: [
          // Mini sidebar
          NavigationRail(
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
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_rounded),
                label: Text(''),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_rounded),
                label: Text(''),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.payments_rounded),
                label: Text(''),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_rounded),
                label: Text(''),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.percent_rounded),
                label: Text(''),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.message_rounded),
                label: Text(''),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assessment_rounded),
                label: Text(''),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_rounded),
                label: Text(''),
              ),
            ],
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => _showLogoutDialog(context),
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
        selectedIndex: _getSelectedIndex(context),
        onDestinationSelected: (index) =>
            _navigateToIndex(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Farmers',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_rounded),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_rounded),
            selectedIcon: Icon(Icons.assessment_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

/// Top bar with breadcrumbs and user info
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Breadcrumb
          _Breadcrumb(),
          const Spacer(),
          // Financial year selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'FY 2025-26',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // User avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Admin User',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ],
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

    return Row(
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
    );
  }
}
