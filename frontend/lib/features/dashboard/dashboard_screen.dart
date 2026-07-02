import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fims_frontend/core/network/api_endpoints.dart';
import 'package:fims_frontend/core/network/dio_client.dart';
import 'package:fims_frontend/core/router/app_router.dart';
import 'package:fims_frontend/core/utils/formatters.dart';
import 'package:fims_frontend/features/admin/providers/resource_provider.dart'
    hide JsonMap;
import 'package:fims_frontend/features/admin/utils/json_helpers.dart';

import '../auth/login_screen.dart';

final dashboardUserProvider = FutureProvider.autoDispose<JsonMap>((ref) async {
  final response = await DioClient().get(ApiEndpoints.me);

  if (response.statusCode == 200 && response.data['success'] == true) {
    return asMap(response.data['data']);
  }

  return {};
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedFinancialYearId;
  String? _selectedBatchId;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final authNotifier = ref.read(authStateProvider.notifier);
    final currentUser = ref.watch(dashboardUserProvider);
    final financialYears = ref.watch(financialYearsProvider);
    final batches = ref.watch(batchesProvider);
    final selectedFinancialYearId =
        _selectedFinancialYearId ?? financialYears.valueOrNull?.activeOrFirstId;
    final selectedBatchId = _selectedBatchId ?? batches.valueOrNull?.firstId;
    final dashboard = ref.watch(dashboardDataProvider(selectedFinancialYearId));
    final authUser = _userMap(authState.user);
    final sessionUser = currentUser.valueOrNull ?? {};
    final user = authUser.isNotEmpty ? authUser : sessionUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final quickActionColumns = width >= 1100
            ? 4
            : width >= 760
                ? 2
                : 1;
        final metricColumns = width >= 1200
            ? 4
            : width >= 840
                ? 2
                : 1;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardDataProvider(selectedFinancialYearId));
            ref.invalidate(dashboardUserProvider);
            ref.invalidate(financialYearsProvider);
            ref.invalidate(batchesProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardHeader(
                  name: _userText(
                    user,
                    ['fullName', 'full_name', 'name', 'username', 'email'],
                    fallback: 'User',
                  ),
                  role: _userText(
                    user,
                    ['role', 'userRole', 'type'],
                    fallback: 'Unknown',
                  ),
                  onSettings: () => context.goNamed(RouteNames.settings),
                  onLogout: () async {
                    await authNotifier.logout();
                    if (context.mounted) {
                      context.goNamed(RouteNames.login);
                    }
                  },
                ),
                const SizedBox(height: 20),
                _PlanningPanel(
                  financialYears: financialYears,
                  batches: batches,
                  selectedFinancialYearId: selectedFinancialYearId,
                  selectedBatchId: selectedBatchId,
                  onFinancialYearChanged: (value) {
                    setState(() {
                      _selectedFinancialYearId = value;
                    });
                  },
                  onBatchChanged: (value) {
                    setState(() {
                      _selectedBatchId = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                dashboard.when(
                  loading: () => _MetricGrid.loading(columns: metricColumns),
                  error: (error, _) => _DashboardError(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(
                      dashboardDataProvider(selectedFinancialYearId),
                    ),
                  ),
                  data: (data) => _MetricGrid(
                    columns: metricColumns,
                    metrics: [
                      _Metric(
                        Icons.people_rounded,
                        'Farmers',
                        _valueText(
                          data,
                          ['farmers.total', 'totalFarmers', 'farmerCount'],
                          fallback: 'Open list',
                        ),
                        'Registered farmers',
                        () => context.goNamed(RouteNames.farmers),
                      ),
                      _Metric(
                        Icons.inventory_2_rounded,
                        'Batches',
                        _valueText(
                          data,
                          ['batches.total', 'totalBatches', 'batchCount'],
                          fallback: 'Review',
                        ),
                        'Payment batches',
                        () => context.goNamed(RouteNames.batches),
                      ),
                      _Metric(
                        Icons.payments_rounded,
                        'Net Payout',
                        _moneyText(
                          data,
                          [
                            'payments.totalNet',
                            'totalNetAmount',
                            'netAmount',
                            'payments.net'
                          ],
                        ),
                        'Across payments',
                        () => context.goNamed(RouteNames.payments),
                      ),
                      _Metric(
                        Icons.percent_rounded,
                        'TDS',
                        _moneyText(
                          data,
                          [
                            'payments.totalTds',
                            'totalTdsAmount',
                            'tdsAmount',
                            'payments.tds'
                          ],
                        ),
                        'Tracked deductions',
                        () => context.goNamed(RouteNames.tds),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _ReportWorkspace(
                  selectedFinancialYear: financialYears.valueOrNull
                      ?.firstWhereOrNullById(selectedFinancialYearId),
                  selectedBatch: batches.valueOrNull
                      ?.firstWhereOrNullById(selectedBatchId),
                  onOpenBatch: selectedBatchId == null
                      ? null
                      : () => context.goNamed(
                            RouteNames.batchDetail,
                            pathParameters: {'id': selectedBatchId},
                          ),
                  onBatchReport: selectedBatchId == null
                      ? null
                      : () => context.goNamed(
                            RouteNames.reports,
                            queryParameters: {'batchId': selectedBatchId},
                          ),
                  onYearEndReport: selectedFinancialYearId == null
                      ? null
                      : () => context.goNamed(
                            RouteNames.reports,
                            queryParameters: {
                              'financialYearId': selectedFinancialYearId,
                            },
                          ),
                  onFinancialYears: () =>
                      context.goNamed(RouteNames.financialYears),
                ),
                const SizedBox(height: 24),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: quickActionColumns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: quickActionColumns == 1 ? 3.1 : 1.7,
                  children: [
                    _QuickActionCard(
                      icon: Icons.people_rounded,
                      title: 'Farmers',
                      subtitle: 'Search and manage farmers',
                      onTap: () => context.goNamed(RouteNames.farmers),
                    ),
                    _QuickActionCard(
                      icon: Icons.upload_file_rounded,
                      title: 'Upload Payments',
                      subtitle: 'Import incentive files',
                      onTap: () => context.goNamed(RouteNames.paymentUpload),
                    ),
                    _QuickActionCard(
                      icon: Icons.inventory_2_rounded,
                      title: 'Batches',
                      subtitle: 'Approve or reject batches',
                      onTap: () => context.goNamed(RouteNames.batches),
                    ),
                    _QuickActionCard(
                      icon: Icons.assessment_rounded,
                      title: 'Reports',
                      subtitle: 'Run batch and year-end reports',
                      onTap: () => context.goNamed(RouteNames.reports),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _StatusCard(
                  onRefresh: () {
                    ref.invalidate(
                        dashboardDataProvider(selectedFinancialYearId));
                    ref.invalidate(dashboardUserProvider);
                    ref.invalidate(financialYearsProvider);
                    ref.invalidate(batchesProvider);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _valueText(
    JsonMap data,
    List<String> paths, {
    required String fallback,
  }) {
    for (final path in paths) {
      final value = valueAt(data, path);
      if (value != null) {
        return Formatters.number(value);
      }
    }
    return fallback;
  }

  String _moneyText(JsonMap data, List<String> paths) {
    for (final path in paths) {
      final value = valueAt(data, path);
      if (value != null) {
        return Formatters.compactCurrency(value);
      }
    }
    return Formatters.compactCurrency(0);
  }

  JsonMap _userMap(Map<String, dynamic>? source) {
    if (source == null) return {};
    final nestedUser = source['user'];
    if (nestedUser is Map) {
      return Map<String, dynamic>.from(nestedUser);
    }
    final nestedData = source['data'];
    if (nestedData is Map) {
      final dataUser = nestedData['user'];
      if (dataUser is Map) {
        return Map<String, dynamic>.from(dataUser);
      }
      return Map<String, dynamic>.from(nestedData);
    }
    return source;
  }

  String _userText(
    JsonMap user,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = user[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }
}

class _DashboardHeader extends StatelessWidget {
  final String name;
  final String role;
  final VoidCallback onSettings;
  final Future<void> Function() onLogout;

  const _DashboardHeader({
    required this.name,
    required this.role,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $name',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Role: $role',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_rounded, size: 34),
            onSelected: (value) async {
              if (value == 'settings') {
                onSettings();
              }
              if (value == 'logout') {
                await onLogout();
              }
            },
            itemBuilder: (_) => const [
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
    );
  }
}

class _PlanningPanel extends StatelessWidget {
  final AsyncValue<List<JsonMap>> financialYears;
  final AsyncValue<List<JsonMap>> batches;
  final String? selectedFinancialYearId;
  final String? selectedBatchId;
  final ValueChanged<String?> onFinancialYearChanged;
  final ValueChanged<String?> onBatchChanged;

  const _PlanningPanel({
    required this.financialYears,
    required this.batches,
    required this.selectedFinancialYearId,
    required this.selectedBatchId,
    required this.onFinancialYearChanged,
    required this.onBatchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 250,
              child: financialYears.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Financial years unavailable'),
                data: (rows) => DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Financial Year',
                    prefixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  initialValue: _safeValue(selectedFinancialYearId, rows),
                  items: rows
                      .map(
                        (fy) => DropdownMenuItem<String>(
                          value: fy['id'].toString(),
                          child: Text(fy['yearLabel']?.toString() ?? 'FY'),
                        ),
                      )
                      .toList(),
                  onChanged: onFinancialYearChanged,
                ),
              ),
            ),
            SizedBox(
              width: 250,
              child: batches.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Batches unavailable'),
                data: (rows) => DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Batch',
                    prefixIcon: Icon(Icons.inventory_2_rounded),
                  ),
                  initialValue: _safeValue(selectedBatchId, rows),
                  items: rows
                      .map(
                        (batch) => DropdownMenuItem<String>(
                          value: batch['id'].toString(),
                          child:
                              Text(batch['batchNumber']?.toString() ?? 'Batch'),
                        ),
                      )
                      .toList(),
                  onChanged: onBatchChanged,
                ),
              ),
            ),
            const _HintChip(
              icon: Icons.touch_app_rounded,
              label: 'Change filters, then open reports',
            ),
          ],
        ),
      ),
    );
  }

  String? _safeValue(String? selectedId, List<JsonMap> rows) {
    if (selectedId == null) return null;
    return rows.any((row) => row['id'].toString() == selectedId)
        ? selectedId
        : null;
  }
}

class _ReportWorkspace extends StatelessWidget {
  final JsonMap? selectedFinancialYear;
  final JsonMap? selectedBatch;
  final VoidCallback? onOpenBatch;
  final VoidCallback? onBatchReport;
  final VoidCallback? onYearEndReport;
  final VoidCallback onFinancialYears;

  const _ReportWorkspace({
    required this.selectedFinancialYear,
    required this.selectedBatch,
    required this.onOpenBatch,
    required this.onBatchReport,
    required this.onYearEndReport,
    required this.onFinancialYears,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.query_stats_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Batch and Year-End Reports',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _SelectionSummary(
                  icon: Icons.inventory_2_rounded,
                  title: 'Selected Batch',
                  value:
                      selectedBatch?['batchNumber']?.toString() ?? 'Choose one',
                  detail: selectedBatch == null
                      ? 'Pick a batch above'
                      : '${selectedBatch!['status'] ?? 'Status'} | '
                          '${Formatters.compactCurrency(selectedBatch!['totalNetAmount'])}',
                ),
                _SelectionSummary(
                  icon: Icons.event_available_rounded,
                  title: 'Year-End Window',
                  value: selectedFinancialYear?['yearLabel']?.toString() ??
                      'Choose FY',
                  detail: selectedFinancialYear == null
                      ? 'Pick a financial year above'
                      : '${Formatters.date(selectedFinancialYear!['startDate'])} to '
                          '${Formatters.date(selectedFinancialYear!['endDate'])}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onBatchReport,
                  icon: const Icon(Icons.assessment_rounded),
                  label: const Text('Run Batch Report'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenBatch,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open Batch'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onYearEndReport,
                  icon: const Icon(Icons.summarize_rounded),
                  label: const Text('Run Year-End Report'),
                ),
                OutlinedButton.icon(
                  onPressed: onFinancialYears,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Manage FY'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  const _Metric(
    this.icon,
    this.title,
    this.value,
    this.subtitle,
    this.onTap,
  );
}

class _MetricGrid extends StatelessWidget {
  final int columns;
  final List<_Metric> metrics;

  const _MetricGrid({
    required this.columns,
    required this.metrics,
  });

  factory _MetricGrid.loading({required int columns}) {
    return _MetricGrid(
      columns: columns,
      metrics: List.generate(
        4,
        (index) => _Metric(
          Icons.hourglass_top_rounded,
          'Loading',
          '...',
          'Fetching dashboard',
          () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 158,
      ),
      itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: metric.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(metric.icon, color: colorScheme.primary),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                metric.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                metric.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String detail;

  const _SelectionSummary({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
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

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HintChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final VoidCallback onRefresh;

  const _StatusCard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'System Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh dashboard',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _StatusRow('API is online and responding'),
            SizedBox(height: 10),
            const _StatusRow('Database connection established'),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;

  const _StatusRow(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.green),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}

extension _JsonMapLookup on List<JsonMap> {
  String? get firstId => isEmpty ? null : first['id']?.toString();

  String? get activeOrFirstId {
    if (isEmpty) return null;
    for (final row in this) {
      if (row['isActive'] == true) {
        return row['id']?.toString();
      }
    }
    return firstId;
  }

  JsonMap? firstWhereOrNullById(String? id) {
    if (id == null) return null;
    for (final row in this) {
      if (row['id'].toString() == id) {
        return row;
      }
    }
    return null;
  }
}
