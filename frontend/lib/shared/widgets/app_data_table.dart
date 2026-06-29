import 'package:flutter/material.dart';

/// Column definition for the data table
class DataColumnConfig {
  final String header;
  final String field;
  final double? flex;
  final bool sortable;
  final Widget Function(dynamic value, dynamic row)? cellBuilder;
  final MainAxisAlignment? alignment;

  const DataColumnConfig({
    required this.header,
    required this.field,
    this.flex,
    this.sortable = true,
    this.cellBuilder,
    this.alignment,
  });
}

/// Reusable data table widget with sorting, pagination, and empty state
class AppDataTable extends StatelessWidget {
  final List<DataColumnConfig> columns;
  final List<dynamic> data;
  final String? sortColumn;
  final bool sortAscending;
  final ValueChanged<String>? onSort;
  final Widget? emptyState;
  final Widget? header;
  final Widget? footer;
  final bool showHeader;
  final bool isLoading;
  final String? rowIdField;
  final void Function(dynamic row)? onRowTap;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.data,
    this.sortColumn,
    this.sortAscending = true,
    this.onSort,
    this.emptyState,
    this.header,
    this.footer,
    this.showHeader = true,
    this.isLoading = false,
    this.rowIdField,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.isEmpty) {
      return emptyState ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No data available',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'There are no records to display.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) header!,
        if (showHeader) ...[
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: columns.map((column) {
                final isSorted = sortColumn == column.field;
                return Expanded(
                  flex: column.flex?.toInt() ?? 1,
                  child: InkWell(
                    onTap: column.sortable
                        ? () => onSort?.call(column.field)
                        : null,
                    child: Row(
                      mainAxisAlignment:
                          column.alignment ?? MainAxisAlignment.start,
                      children: [
                        Text(
                          column.header,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSorted
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (column.sortable) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isSorted
                                ? (sortAscending
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded)
                                : Icons.unfold_more_rounded,
                            size: 14,
                            color: isSorted
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        Expanded(
          child: ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
            itemBuilder: (context, index) {
              final row = data[index];
              return InkWell(
                onTap: onRowTap != null ? () => onRowTap!(row) : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? Colors.transparent
                        : colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.15),
                  ),
                  child: Row(
                    children: columns.map((column) {
                      final value = _getNestedValue(row, column.field);
                      return Expanded(
                        flex: column.flex?.toInt() ?? 1,
                        child: column.cellBuilder != null
                            ? column.cellBuilder!(value, row)
                            : _defaultCell(context, value),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
        if (footer != null) footer!,
      ],
    );
  }

  Widget _defaultCell(BuildContext context, dynamic value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (value == null) {
      return Text(
        '-',
        style: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
      );
    }

    return Text(
      value.toString(),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Get nested value from a map using dot notation (e.g., "user.name")
  dynamic _getNestedValue(dynamic obj, String field) {
    if (obj == null) return null;
    final parts = field.split('.');
    dynamic current = obj;
    for (final part in parts) {
      if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
      if (current == null) return null;
    }
    return current;
  }
}

/// Status badge widget
class StatusBadge extends StatelessWidget {
  final String status;
  final double? fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.backgroundColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: config.backgroundColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: config.backgroundColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: config.backgroundColor,
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'completed':
      case 'success':
      case 'paid':
        return _StatusConfig(backgroundColor: const Color(0xFF43A047));
      case 'pending':
      case 'processing':
        return _StatusConfig(backgroundColor: const Color(0xFFFFA000));
      case 'inactive':
      case 'rejected':
      case 'failed':
      case 'cancelled':
        return _StatusConfig(backgroundColor: const Color(0xFFE53935));
      case 'draft':
        return _StatusConfig(backgroundColor: const Color(0xFF757575));
      case 'partial':
        return _StatusConfig(backgroundColor: const Color(0xFF1E88E5));
      default:
        return _StatusConfig(backgroundColor: const Color(0xFF1E88E5));
    }
  }
}

class _StatusConfig {
  final Color backgroundColor;
  const _StatusConfig({required this.backgroundColor});
}
