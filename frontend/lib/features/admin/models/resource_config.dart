import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fims_frontend/core/network/api_endpoints.dart';
import '../services/admin_actions.dart';
import 'column_spec.dart';
import 'row_action.dart';
import '../dialogs/user_dialog.dart';
import '../dialogs/financial_year_dialog.dart';
import '../dialogs/sms_template_dialog.dart';

typedef JsonMap = Map<String, dynamic>;

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

  final void Function(
    BuildContext context,
    WidgetRef ref,
  )? primaryAction;

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
  /// USERS
  static final ResourceConfig users = ResourceConfig(
    title: 'Users',
    subtitle: 'Admin-only user and role administration.',
    sectionTitle: 'System Users',
    icon: Icons.manage_accounts_rounded,
    endpoint: ApiEndpoints.users,
    primaryActionLabel: 'Add User',
    primaryAction: showUserDialog,
    columns: const [
      ColumnSpec('username', 'Username'),
      ColumnSpec('fullName', 'Full Name'),
      ColumnSpec('email', 'Email'),
      ColumnSpec(
        'role',
        'Role',
        status: true,
      ),
      ColumnSpec('isActive', 'Active'),
    ],
  );

  /// FINANCIAL YEARS
  static final ResourceConfig financialYears = ResourceConfig(
    title: 'Financial Years',
    subtitle: 'Open, review, and close financial year windows.',
    sectionTitle: 'Year Windows',
    icon: Icons.calendar_month_rounded,
    endpoint: ApiEndpoints.financialYears,
    primaryActionLabel: 'Add FY',
    primaryAction: showFinancialYearDialog,
    columns: const [
      ColumnSpec('yearLabel', 'Year'),
      ColumnSpec(
        'startDate',
        'Start',
        date: true,
      ),
      ColumnSpec(
        'endDate',
        'End',
        date: true,
      ),
      ColumnSpec('isActive', 'Active'),
      ColumnSpec('isClosed', 'Closed'),
    ],
  );

  /// PAYMENTS
  static final ResourceConfig payments = ResourceConfig(
    title: 'Payments',
    subtitle: 'Import payment files and preview incentive calculations.',
    sectionTitle: 'Payment Operations',
    icon: Icons.payments_rounded,
    endpoint: ApiEndpoints.batches,
    primaryActionLabel: 'Upload Excel',
    primaryActionIcon: Icons.upload_file_rounded,
    primaryAction: null,
    columns: const [
      ColumnSpec('batchNumber', 'Batch'),
      ColumnSpec(
        'financialYear.yearLabel',
        'FY',
      ),
      ColumnSpec(
        'status',
        'Status',
        status: true,
      ),
      ColumnSpec('totalFarmers', 'Farmers'),
      ColumnSpec(
        'totalGrossAmount',
        'Gross',
        currency: true,
      ),
      ColumnSpec(
        'totalNetAmount',
        'Net',
        currency: true,
      ),
    ],
  );

  /// BATCHES
  static final ResourceConfig batches = ResourceConfig(
    title: 'Batches',
    subtitle: 'Review, approve, reject, and export payment batches.',
    sectionTitle: 'Payment Batches',
    icon: Icons.inventory_2_rounded,
    endpoint: ApiEndpoints.batches,
    rowActions: [
      RowAction(
        'Approve',
        Icons.verified_rounded,
        (context, ref, row) async {
          await postAction(
            context,
            ref,
            ApiEndpoints.batchApprove(row['id'].toString()),
            ResourceConfigs.batches,
            'Batch approved',
          );
        },
      ),
      RowAction(
        'Reject',
        Icons.cancel_rounded,
        (context, ref, row) async {
          await postAction(
            context,
            ref,
            ApiEndpoints.batchReject(row['id'].toString()),
            ResourceConfigs.batches,
            'Batch rejected',
            data: {
              'reason': 'Rejected from frontend',
            },
          );
        },
      ),
    ],
    columns: const [
      ColumnSpec('batchNumber', 'Batch'),
      ColumnSpec(
        'financialYear.yearLabel',
        'FY',
      ),
      ColumnSpec(
        'status',
        'Status',
        status: true,
      ),
      ColumnSpec('totalFarmers', 'Farmers'),
      ColumnSpec(
        'totalTdsAmount',
        'TDS',
        currency: true,
      ),
      ColumnSpec(
        'totalNetAmount',
        'Net',
        currency: true,
      ),
    ],
  );

  /// TDS
  static final ResourceConfig tds = ResourceConfig(
    title: 'TDS Tracking',
    subtitle: 'Monitor batches and payments that may require TDS decisions.',
    sectionTitle: 'TDS Sensitive Batches',
    icon: Icons.percent_rounded,
    endpoint: ApiEndpoints.batches,
    columns: const [
      ColumnSpec('batchNumber', 'Batch'),
      ColumnSpec(
        'status',
        'Status',
        status: true,
      ),
      ColumnSpec(
        'totalGrossAmount',
        'Gross',
        currency: true,
      ),
      ColumnSpec(
        'totalTdsAmount',
        'TDS',
        currency: true,
      ),
      ColumnSpec(
        'totalNetAmount',
        'Net',
        currency: true,
      ),
    ],
  );

  /// SMS
  static final ResourceConfig sms = ResourceConfig(
    title: 'SMS',
    subtitle: 'Manage notification templates and delivery history.',
    sectionTitle: 'Templates',
    icon: Icons.sms_rounded,
    endpoint: ApiEndpoints.smsTemplates,
    primaryActionLabel: 'New Template',
    primaryAction: showSmsTemplateDialog,
    columns: const [
      ColumnSpec('name', 'Template'),
      ColumnSpec('body', 'Message'),
      ColumnSpec(
        'createdAt',
        'Created',
        date: true,
      ),
    ],
  );

  /// SMS LOGS
  static final ResourceConfig smsLogs = ResourceConfig(
    title: 'SMS Logs',
    subtitle: 'Audit SMS delivery attempts and provider status.',
    sectionTitle: 'Delivery Logs',
    icon: Icons.mark_chat_read_rounded,
    endpoint: ApiEndpoints.smsLogs,
    columns: const [
      ColumnSpec('farmer.name', 'Farmer'),
      ColumnSpec('phone', 'Phone'),
      ColumnSpec(
        'status',
        'Status',
        status: true,
      ),
      ColumnSpec('message', 'Message'),
      ColumnSpec(
        'createdAt',
        'Sent',
        date: true,
      ),
    ],
  );

  /// AUDIT LOGS
  static final ResourceConfig auditLogs = ResourceConfig(
    title: 'Audit Logs',
    subtitle: 'Trace changes made across sensitive system records.',
    sectionTitle: 'Activity',
    icon: Icons.history_rounded,
    endpoint: ApiEndpoints.auditLogs,
    columns: const [
      ColumnSpec(
        'action',
        'Action',
        status: true,
      ),
      ColumnSpec('entity', 'Entity'),
      ColumnSpec('entityId', 'Entity ID'),
      ColumnSpec('user.fullName', 'User'),
      ColumnSpec(
        'createdAt',
        'When',
        date: true,
      ),
    ],
  );

  /// SETTINGS
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
