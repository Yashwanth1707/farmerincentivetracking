import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/column_spec.dart';
import '../models/row_action.dart';
import '../utils/json_helpers.dart';
import 'cell_value.dart';
import 'empty_state.dart';

typedef JsonMap = Map<String, dynamic>;

class SimpleTable extends StatelessWidget {
  final List<JsonMap> rows;
  final List<ColumnSpec> columns;
  final List<RowAction> rowActions;
  final String emptyTitle;

  const SimpleTable({
    super.key,
    required this.rows,
    required this.columns,
    this.rowActions = const [],
    this.emptyTitle = 'No records found',
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return EmptyState(
        title: emptyTitle,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.08),
        ),
        columns: [
          for (final column in columns)
            DataColumn(
              label: Text(column.label),
            ),
          if (rowActions.isNotEmpty)
            const DataColumn(
              label: Text('Actions'),
            ),
        ],
        rows: rows.map((row) {
          return DataRow(
            cells: [
              for (final column in columns)
                DataCell(
                  CellValue(
                    column: column,
                    row: row,
                  ),
                ),
              if (rowActions.isNotEmpty)
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: rowActions.map((action) {
                      return Consumer(
                        builder: (context, ref, _) {
                          return IconButton(
                            tooltip: action.label,
                            icon: Icon(action.icon),
                            onPressed: () {
                              action.onPressed(
                                context,
                                ref,
                                row,
                              );
                            },
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}