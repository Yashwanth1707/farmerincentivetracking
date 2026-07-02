import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/login_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final authNotifier = ref.read(authStateProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int columns;
        if (width >= 1400) {
          columns = 4;
        } else if (width >= 1000) {
          columns = 3;
        } else if (width >= 700) {
          columns = 2;
        } else {
          columns = 1;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${authState.user?['username'] ?? 'User'}!',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Role: ${authState.user?['role'] ?? 'Unknown'}',
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.account_circle, size: 34),
                    onSelected: (value) async {
                      switch (value) {
                        case 'settings':
                          context.goNamed('settings');
                          break;

                        case 'logout':
                          await authNotifier.logout();
                          if (context.mounted) {
                            context.goNamed('login');
                          }
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'profile',
                        child: Text('Profile'),
                      ),
                      PopupMenuItem(
                        value: 'settings',
                        child: Text('Settings'),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'logout',
                        child: Text('Logout'),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 20),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  mainAxisExtent: 170,
                ),
                itemBuilder: (_, index) {
                  final items = [
                    (Icons.people, 'Farmers', () => context.goNamed('farmers')),
                    (
                      Icons.payment,
                      'Payments',
                      () => context.goNamed('payments')
                    ),
                    (
                      Icons.file_copy,
                      'Reports',
                      () => context.goNamed('reports')
                    ),
                    (
                      Icons.settings,
                      'Settings',
                      () => context.goNamed('settings')
                    ),
                  ];

                  return _QuickActionCard(
                    icon: items[index].$1,
                    title: items[index].$2,
                    onTap: items[index].$3,
                  );
                },
              ),

              const SizedBox(height: 32),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'System Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 10),
                          Expanded(child: Text('API is online and responding')),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 10),
                          Expanded(
                              child: Text('Database connection established')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Icon(
                  icon,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
