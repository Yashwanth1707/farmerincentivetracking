import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_data_table.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/stat_card.dart';

typedef JsonMap = Map<String, dynamic>;

final dashboardDataProvider = FutureProvider.autoDispose<JsonMap>((ref) async {
  final response = await DioClient().get(ApiEndpoints.dashboardStats);
  if (response.statusCode == 200 && response.data['success'] == true) {
    return _asMap(response.data['data']);
  }
  throw Exception(response.data['message'] ?? 'Unable to load dashboard');
});

class ApiDashboardScreen extends ConsumerWidget {
  const ApiDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardDataProvider);
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        title: 'Dashboard unavailable',
        message: error.toString(),
        onRetry: () => ref.invalidate(dashboardDataProvider),
      ),
      data: (stats) {
        final farmers = _asMap(stats['farmers']);
        final payments = _asMap(stats['payments']);
        final batches = _asMap(stats['batches']);
        final recentBatches = _asList(stats['recentBatches']);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PageHero(
                title: 'Dashboard',
                subtitle:
                    'Live operating view across farmers, payments, batches, and TDS.',
                icon: Icons.dashboard_rounded,
              ),
              const SizedBox(height: 16),
              StatCardGrid(
                cards: [
                  StatCard(
                    label: 'Active Farmers',
                    value: Formatters.number(farmers['active']),
                    icon: Icons.people_rounded,
                    subtitle:
                        '${Formatters.number(farmers['total'])} total profiles',
                  ),
                  StatCard(
                    label: 'Net Payments',
                    value: Formatters.compactCurrency(payments['totalNet']),
                    icon: Icons.payments_rounded,
                    iconColor: AppColors.accentDeep,
                    subtitle:
                        '${Formatters.number(payments['total'])} payment records',
                  ),
                  StatCard(
                    label: 'Approved Batches',
                    value: Formatters.number(batches['approved']),
                    icon: Icons.verified_rounded,
                    iconColor: AppColors.success,
                    subtitle:
                        '${Formatters.number(batches['pending'])} pending',
                  ),
                  StatCard(
                    label: 'TDS Decisions',
                    value: Formatters.number(stats['pendingTds']),
                    icon: Icons.percent_rounded,
                    iconColor: AppColors.warning,
                    subtitle: 'Pending review',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Recent Batches',
                icon: Icons.inventory_2_rounded,
                child: _SimpleTable(
                  rows: recentBatches,
                  columns: const [
                    ColumnSpec('batchNumber', 'Batch'),
                    ColumnSpec('financialYear.yearLabel', 'FY'),
                    ColumnSpec('status', 'Status', status: true),
                    ColumnSpec('totalFarmers', 'Farmers'),
                    ColumnSpec('totalNetAmount', 'Net', currency: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ResourceListScreen extends ConsumerWidget {
  final ResourceConfig config;

  const ResourceListScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _resourceProvider(config);
    final result = ref.watch(provider);

    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        title: '${config.title} unavailable',
        message: error.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (rows) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHero(
              title: config.title,
              subtitle: config.subtitle,
              icon: config.icon,
              trailing: config.primaryAction == null
                  ? null
                  : FilledButton.icon(
                      onPressed: () => config.primaryAction!(context, ref),
                      icon: Icon(config.primaryActionIcon),
                      label: Text(config.primaryActionLabel),
                    ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: config.sectionTitle,
              icon: config.icon,
              child: _SimpleTable(
                rows: rows,
                columns: config.columns,
                rowActions: config.rowActions,
                emptyTitle: config.emptyTitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final _farmerId = TextEditingController();
  final _batchId = TextEditingController();
  final _financialYearId = TextEditingController();
  final _client = DioClient();
  bool _loading = false;
  JsonMap? _result;
  String? _error;

  @override
  void dispose() {
    _farmerId.dispose();
    _batchId.dispose();
    _financialYearId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHero(
            title: 'Reports',
            subtitle:
                'Run farmer ledger, payment register, batch, FY, and TDS reports.',
            icon: Icons.assessment_rounded,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Report Inputs',
            icon: Icons.tune_rounded,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Input(
                    width: 260,
                    controller: _farmerId,
                    label: 'Farmer internal ID'),
                _Input(width: 260, controller: _batchId, label: 'Batch ID'),
                _Input(
                    width: 260,
                    controller: _financialYearId,
                    label: 'Financial Year ID'),
                FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _run(ApiEndpoints.reportPaymentRegister),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Payment Register'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _run(ApiEndpoints.reportFarmerLedger(
                          _farmerId.text.trim())),
                  icon: const Icon(Icons.person_rounded),
                  label: const Text('Farmer Ledger'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _run(
                          ApiEndpoints.reportBatchReport(_batchId.text.trim())),
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: const Text('Batch Report'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _run(ApiEndpoints.reportFyReport(
                          _financialYearId.text.trim())),
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('FY Report'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _run(ApiEndpoints.reportTdsReport(
                          _financialYearId.text.trim())),
                  icon: const Icon(Icons.percent_rounded),
                  label: const Text('TDS Report'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            _ErrorState(title: 'Report failed', message: _error!, compact: true)
          else if (_result != null)
            _SectionCard(
              title: 'Report Result',
              icon: Icons.data_object_rounded,
              child: _JsonPreview(value: _result!),
            ),
        ],
      ),
    );
  }

  Future<void> _run(String endpoint) async {
    if (endpoint.endsWith('/')) {
      setState(
          () => _error = 'Enter the required ID before running this report.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final response = await _client.get(endpoint);
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() => _result = _asMap(response.data['data']));
      } else {
        setState(() => _error =
            response.data['message']?.toString() ?? 'Unable to run report');
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _client = DioClient();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final provider = _resourceProvider(ResourceConfigs.settings);
    final result = ref.watch(provider);

    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        title: 'Settings unavailable',
        message: error.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (rows) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHero(
              title: 'Settings',
              subtitle:
                  'Maintain payment, TDS, and notification configuration.',
              icon: Icons.settings_rounded,
              trailing: FilledButton.icon(
                onPressed: _saving ? null : () => _openEdit(context, rows),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Edit Settings'),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Configuration',
              icon: Icons.list_alt_rounded,
              child: _SimpleTable(
                rows: rows,
                columns: const [
                  ColumnSpec('key', 'Key'),
                  ColumnSpec('value', 'Value'),
                  ColumnSpec('category', 'Category'),
                  ColumnSpec('updatedAt', 'Updated', date: true),
                ],
                emptyTitle: 'No settings found',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context, List<JsonMap> rows) async {
    final controllers = {
      for (final row in rows)
        row['key'].toString():
            TextEditingController(text: row['value']?.toString() ?? ''),
    };

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Settings'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: controllers.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(labelText: entry.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'settings': {
          for (final entry in controllers.entries)
            entry.key: entry.value.text.trim(),
        },
      };
      final response = await _client.put(ApiEndpoints.settings, data: payload);
      if (!context.mounted) return;
      if (response.statusCode == 200 && response.data['success'] == true) {
        AppSnackbar.success(context, 'Settings updated');
        ref.invalidate(_resourceProvider(ResourceConfigs.settings));
      } else {
        AppSnackbar.error(
            context,
            response.data['message']?.toString() ??
                'Unable to update settings');
      }
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.toString());
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      if (mounted) setState(() => _saving = false);
    }
  }
}

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final client = DioClient();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHero(
            title: 'Change Password',
            subtitle: 'Update the password for your current session.',
            icon: Icons.lock_reset_rounded,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Security',
            icon: Icons.password_rounded,
            child: SizedBox(
              width: 520,
              child: Column(
                children: [
                  TextField(
                      controller: current,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Current password')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: next,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'New password')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: confirm,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Confirm new password')),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (next.text != confirm.text) {
                          AppSnackbar.error(context,
                              'New password and confirmation do not match');
                          return;
                        }
                        final response = await client.post(
                          ApiEndpoints.changePassword,
                          data: {
                            'currentPassword': current.text,
                            'newPassword': next.text,
                          },
                        );
                        if (context.mounted &&
                            response.data['success'] == true) {
                          AppSnackbar.success(context, 'Password changed');
                          context.goNamed(RouteNames.dashboard);
                        } else if (context.mounted) {
                          AppSnackbar.error(
                              context,
                              response.data['message']?.toString() ??
                                  'Unable to change password');
                        }
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResourceConfig {
  final String title;
  final String subtitle;
  final String sectionTitle;
  final IconData icon;
  final String endpoint;
  final List<ColumnSpec> columns;
  final String emptyTitle;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final void Function(BuildContext context, WidgetRef ref)? primaryAction;
  final List<RowAction> rowActions;

  const ResourceConfig({
    required this.title,
    required this.subtitle,
    required this.sectionTitle,
    required this.icon,
    required this.endpoint,
    required this.columns,
    this.emptyTitle = 'No records found',
    this.primaryActionLabel = 'Add',
    this.primaryActionIcon = Icons.add_rounded,
    this.primaryAction,
    this.rowActions = const [],
  });
}

class ResourceConfigs {
  static final ResourceConfig users = ResourceConfig(
    title: 'Users',
    subtitle: 'Admin-only user and role administration.',
    sectionTitle: 'System Users',
    icon: Icons.manage_accounts_rounded,
    endpoint: ApiEndpoints.users,
    primaryActionLabel: 'Add User',
    primaryAction: _showUserDialog,
    columns: const [
      ColumnSpec('username', 'Username'),
      ColumnSpec('fullName', 'Full Name'),
      ColumnSpec('email', 'Email'),
      ColumnSpec('role', 'Role', status: true),
      ColumnSpec('isActive', 'Active'),
    ],
  );

  static final ResourceConfig financialYears = ResourceConfig(
    title: 'Financial Years',
    subtitle: 'Open, review, and close financial year windows.',
    sectionTitle: 'Year Windows',
    icon: Icons.calendar_month_rounded,
    endpoint: ApiEndpoints.financialYears,
    primaryActionLabel: 'Add FY',
    primaryAction: _showFinancialYearDialog,
    columns: const [
      ColumnSpec('yearLabel', 'Year'),
      ColumnSpec('startDate', 'Start', date: true),
      ColumnSpec('endDate', 'End', date: true),
      ColumnSpec('isActive', 'Active'),
      ColumnSpec('isClosed', 'Closed'),
    ],
  );

  static final ResourceConfig payments = ResourceConfig(
    title: 'Payments',
    subtitle: 'Import payment files and preview incentive calculations.',
    sectionTitle: 'Payment Operations',
    icon: Icons.payments_rounded,
    endpoint: ApiEndpoints.batches,
    primaryActionLabel: 'Upload Excel',
    primaryActionIcon: Icons.upload_file_rounded,
    primaryAction: (context, ref) => context.goNamed(RouteNames.paymentUpload),
    columns: const [
      ColumnSpec('batchNumber', 'Batch'),
      ColumnSpec('financialYear.yearLabel', 'FY'),
      ColumnSpec('status', 'Status', status: true),
      ColumnSpec('totalFarmers', 'Farmers'),
      ColumnSpec('totalGrossAmount', 'Gross', currency: true),
      ColumnSpec('totalNetAmount', 'Net', currency: true),
    ],
  );

  static final ResourceConfig batches = ResourceConfig(
    title: 'Batches',
    subtitle: 'Review, approve, reject, and export payment batches.',
    sectionTitle: 'Payment Batches',
    icon: Icons.inventory_2_rounded,
    endpoint: ApiEndpoints.batches,
    rowActions: [
      RowAction('Approve', Icons.verified_rounded, (context, ref, row) async {
        await _postAction(
            context,
            ref,
            ApiEndpoints.batchApprove(row['id'].toString()),
            ResourceConfigs.batches,
            'Batch approved');
      }),
      RowAction('Reject', Icons.cancel_rounded, (context, ref, row) async {
        await _postAction(
          context,
          ref,
          ApiEndpoints.batchReject(row['id'].toString()),
          ResourceConfigs.batches,
          'Batch rejected',
          data: {'reason': 'Rejected from frontend'},
        );
      }),
    ],
    columns: const [
      ColumnSpec('batchNumber', 'Batch'),
      ColumnSpec('financialYear.yearLabel', 'FY'),
      ColumnSpec('status', 'Status', status: true),
      ColumnSpec('totalFarmers', 'Farmers'),
      ColumnSpec('totalTdsAmount', 'TDS', currency: true),
      ColumnSpec('totalNetAmount', 'Net', currency: true),
    ],
  );

  static final ResourceConfig tds = ResourceConfig(
    title: 'TDS Tracking',
    subtitle: 'Monitor batches and payments that may require TDS decisions.',
    sectionTitle: 'TDS Sensitive Batches',
    icon: Icons.percent_rounded,
    endpoint: ApiEndpoints.batches,
    columns: const [
      ColumnSpec('batchNumber', 'Batch'),
      ColumnSpec('status', 'Status', status: true),
      ColumnSpec('totalGrossAmount', 'Gross', currency: true),
      ColumnSpec('totalTdsAmount', 'TDS', currency: true),
      ColumnSpec('totalNetAmount', 'Net', currency: true),
    ],
  );

  static final ResourceConfig sms = ResourceConfig(
    title: 'SMS',
    subtitle: 'Manage notification templates and delivery history.',
    sectionTitle: 'Templates',
    icon: Icons.sms_rounded,
    endpoint: ApiEndpoints.smsTemplates,
    primaryActionLabel: 'New Template',
    primaryAction: _showSmsTemplateDialog,
    columns: const [
      ColumnSpec('name', 'Template'),
      ColumnSpec('body', 'Message'),
      ColumnSpec('createdAt', 'Created', date: true),
    ],
  );

  static final ResourceConfig smsLogs = ResourceConfig(
    title: 'SMS Logs',
    subtitle: 'Audit SMS delivery attempts and provider status.',
    sectionTitle: 'Delivery Logs',
    icon: Icons.mark_chat_read_rounded,
    endpoint: ApiEndpoints.smsLogs,
    columns: const [
      ColumnSpec('farmer.name', 'Farmer'),
      ColumnSpec('phone', 'Phone'),
      ColumnSpec('status', 'Status', status: true),
      ColumnSpec('message', 'Message'),
      ColumnSpec('createdAt', 'Sent', date: true),
    ],
  );

  static final ResourceConfig auditLogs = ResourceConfig(
    title: 'Audit Logs',
    subtitle: 'Trace changes made across sensitive system records.',
    sectionTitle: 'Activity',
    icon: Icons.history_rounded,
    endpoint: ApiEndpoints.auditLogs,
    columns: const [
      ColumnSpec('action', 'Action', status: true),
      ColumnSpec('entity', 'Entity'),
      ColumnSpec('entityId', 'Entity ID'),
      ColumnSpec('user.fullName', 'User'),
      ColumnSpec('createdAt', 'When', date: true),
    ],
  );

  static final ResourceConfig settings = ResourceConfig(
    title: 'Settings',
    subtitle: 'System settings.',
    sectionTitle: 'Settings',
    icon: Icons.settings_rounded,
    endpoint: ApiEndpoints.settings,
    columns: const [
      ColumnSpec('key', 'Key'),
      ColumnSpec('value', 'Value'),
      ColumnSpec('category', 'Category'),
    ],
  );
}

final _resourceProvider = FutureProvider.autoDispose
    .family<List<JsonMap>, ResourceConfig>((ref, config) async {
  final response = await DioClient().get(
    config.endpoint,
    queryParameters: {'page': 1, 'limit': 50},
  );
  if (response.statusCode != 200 || response.data['success'] != true) {
    throw Exception(
        response.data['message'] ?? 'Unable to load ${config.title}');
  }
  return _extractRows(response.data['data']);
});

class _SimpleTable extends StatelessWidget {
  final List<JsonMap> rows;
  final List<ColumnSpec> columns;
  final List<RowAction> rowActions;
  final String emptyTitle;

  const _SimpleTable({
    required this.rows,
    required this.columns,
    this.rowActions = const [],
    this.emptyTitle = 'No records found',
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _EmptyState(title: emptyTitle);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        ),
        columns: [
          for (final column in columns) DataColumn(label: Text(column.label)),
          if (rowActions.isNotEmpty) const DataColumn(label: Text('Actions')),
        ],
        rows: rows.map((row) {
          return DataRow(
            cells: [
              for (final column in columns)
                DataCell(_CellValue(column: column, row: row)),
              if (rowActions.isNotEmpty)
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: rowActions
                        .map(
                          (action) => Consumer(
                            builder: (context, ref, _) => IconButton(
                              tooltip: action.label,
                              onPressed: () =>
                                  action.onPressed(context, ref, row),
                              icon: Icon(action.icon),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _CellValue extends StatelessWidget {
  final ColumnSpec column;
  final JsonMap row;

  const _CellValue({required this.column, required this.row});

  @override
  Widget build(BuildContext context) {
    final value = _valueAt(row, column.field);
    if (column.status) {
      return StatusBadge(status: value?.toString() ?? '-');
    }
    if (column.currency) {
      return Text(Formatters.currency(value));
    }
    if (column.date) {
      return Text(Formatters.date(value));
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Text(
        value?.toString() ?? '-',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class ColumnSpec {
  final String field;
  final String label;
  final bool status;
  final bool currency;
  final bool date;

  const ColumnSpec(
    this.field,
    this.label, {
    this.status = false,
    this.currency = false,
    this.date = false,
  });
}

class RowAction {
  final String label;
  final IconData icon;
  final Future<void> Function(BuildContext context, WidgetRef ref, JsonMap row)
      onPressed;

  const RowAction(this.label, this.icon, this.onPressed);
}

class _PageHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const _PageHero({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.accentSoft,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  const _ErrorState({
    required this.title,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error, size: 42),
            const SizedBox(height: 8),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;

  const _EmptyState({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded,
                size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final double width;
  final TextEditingController controller;
  final String label;

  const _Input(
      {required this.width, required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label)),
    );
  }
}

class _JsonPreview extends StatelessWidget {
  final JsonMap value;

  const _JsonPreview({required this.value});

  @override
  Widget build(BuildContext context) {
    return SelectableText(value.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n'));
  }
}

Future<void> _showUserDialog(BuildContext context, WidgetRef ref) async {
  final fields = {
    'username': TextEditingController(),
    'email': TextEditingController(),
    'password': TextEditingController(),
    'fullName': TextEditingController(),
    'phone': TextEditingController(),
  };
  var role = 'OPERATOR';

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add User'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final entry in fields.entries) ...[
                  TextField(
                    controller: entry.value,
                    obscureText: entry.key == 'password',
                    decoration: InputDecoration(
                        labelText: Formatters.capitalize(entry.key)),
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const ['ADMIN', 'OPERATOR', 'VIEWER']
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) => setState(() => role = value ?? role),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create')),
        ],
      ),
    ),
  );

  if (saved == true && context.mounted) {
    final payload = {
      for (final entry in fields.entries) entry.key: entry.value.text.trim(),
      'role': role
    };
    await _postAction(
        context, ref, ApiEndpoints.users, ResourceConfigs.users, 'User created',
        data: payload);
  }
  for (final controller in fields.values) {
    controller.dispose();
  }
}

Future<void> _showFinancialYearDialog(
    BuildContext context, WidgetRef ref) async {
  final year = TextEditingController(text: Formatters.currentFinancialYear);
  final start = TextEditingController(text: '${DateTime.now().year}-04-01');
  final end = TextEditingController(text: '${DateTime.now().year + 1}-03-31');

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Financial Year'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: year,
                decoration: const InputDecoration(labelText: 'Year label')),
            const SizedBox(height: 12),
            TextField(
                controller: start,
                decoration: const InputDecoration(
                    labelText: 'Start date (YYYY-MM-DD)')),
            const SizedBox(height: 12),
            TextField(
                controller: end,
                decoration:
                    const InputDecoration(labelText: 'End date (YYYY-MM-DD)')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create')),
      ],
    ),
  );

  if (saved == true && context.mounted) {
    await _postAction(
      context,
      ref,
      ApiEndpoints.financialYears,
      ResourceConfigs.financialYears,
      'Financial year created',
      data: {
        'yearLabel': year.text.trim(),
        'startDate': start.text.trim(),
        'endDate': end.text.trim()
      },
    );
  }
  year.dispose();
  start.dispose();
  end.dispose();
}

Future<void> _showSmsTemplateDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final body = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New SMS Template'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Template name')),
            const SizedBox(height: 12),
            TextField(
              controller: body,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Message body'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create')),
      ],
    ),
  );
  if (saved == true && context.mounted) {
    await _postAction(
      context,
      ref,
      ApiEndpoints.smsTemplates,
      ResourceConfigs.sms,
      'Template created',
      data: {'name': name.text.trim(), 'body': body.text.trim()},
    );
  }
  name.dispose();
  body.dispose();
}

Future<void> _postAction(
  BuildContext context,
  WidgetRef ref,
  String endpoint,
  ResourceConfig config,
  String successMessage, {
  JsonMap? data,
}) async {
  try {
    final response = await DioClient().post(endpoint, data: data ?? const {});
    if (!context.mounted) return;
    if ((response.statusCode == 200 || response.statusCode == 201) &&
        response.data['success'] == true) {
      AppSnackbar.success(context, successMessage);
      ref.invalidate(_resourceProvider(config));
    } else {
      AppSnackbar.error(
          context, response.data['message']?.toString() ?? 'Action failed');
    }
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error.toString());
  }
}

List<JsonMap> _extractRows(dynamic value) {
  if (value is List) {
    return value.whereType<Map>().map((item) => JsonMap.from(item)).toList();
  }
  if (value is Map) {
    final map = JsonMap.from(value);
    final rows = <JsonMap>[];
    for (final entry in map.entries) {
      if (entry.value is Map) {
        rows.add({'category': entry.key, ...JsonMap.from(entry.value as Map)});
      } else if (entry.value is List) {
        rows.addAll((entry.value as List)
            .whereType<Map>()
            .map((item) => JsonMap.from(item)));
      } else {
        rows.add(
            {'key': entry.key, 'value': entry.value, 'category': 'General'});
      }
    }
    return rows;
  }
  return const [];
}

JsonMap _asMap(dynamic value) {
  if (value is Map) return JsonMap.from(value);
  return const {};
}

List<JsonMap> _asList(dynamic value) {
  if (value is List) {
    return value.whereType<Map>().map((item) => JsonMap.from(item)).toList();
  }
  return const [];
}

dynamic _valueAt(dynamic source, String path) {
  dynamic current = source;
  for (final part in path.split('.')) {
    if (current is Map) {
      current = current[part];
    } else {
      return null;
    }
  }
  return current;
}
