import 'package:flutter/material.dart';

/// Pagination widget for data tables
class Paginator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  const Paginator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    this.pageSizeOptions = const [10, 20, 50, 100],
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final startItem = totalItems == 0 ? 0 : (currentPage * pageSize) + 1;
    final endItem = ((currentPage + 1) * pageSize).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Page size selector
          Row(
            children: [
              Text(
                'Rows per page:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: pageSize,
                    isDense: true,
                    items: pageSizeOptions.map((size) {
                      return DropdownMenuItem(
                        value: size,
                        child: Text(size.toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) onPageSizeChanged(value);
                    },
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Item count
          Text(
            '$startItem–$endItem of $totalItems',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          // Navigation buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // First page
              IconButton(
                icon: const Icon(Icons.first_page_rounded),
                onPressed: currentPage > 0 ? () => onPageChanged(0) : null,
                visualDensity: VisualDensity.compact,
                tooltip: 'First page',
              ),
              // Previous page
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                visualDensity: VisualDensity.compact,
                tooltip: 'Previous page',
              ),
              // Next page
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: currentPage < totalPages - 1
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                visualDensity: VisualDensity.compact,
                tooltip: 'Next page',
              ),
              // Last page
              IconButton(
                icon: const Icon(Icons.last_page_rounded),
                onPressed: currentPage < totalPages - 1
                    ? () => onPageChanged(totalPages - 1)
                    : null,
                visualDensity: VisualDensity.compact,
                tooltip: 'Last page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Page jump dialog
class PageJumpDialog extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const PageJumpDialog({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: '${currentPage + 1}');

    return AlertDialog(
      title: const Text('Go to page'),
      content: SizedBox(
        width: 200,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Page 1-$totalPages',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final page = int.tryParse(controller.text);
            if (page != null && page >= 1 && page <= totalPages) {
              Navigator.of(context).pop(page - 1);
            }
          },
          child: const Text('Go'),
        ),
      ],
    );
  }
}

