import 'package:flutter/material.dart';

import 'package:fims_frontend/core/utils/formatters.dart';
import 'package:fims_frontend/shared/widgets/app_data_table.dart';

import '../models/column_spec.dart';
import '../utils/json_helpers.dart';

typedef JsonMap = Map<String, dynamic>;

class CellValue extends StatelessWidget {
  final ColumnSpec column;
  final JsonMap row;

  const CellValue({
    super.key,
    required this.column,
    required this.row,
  });

  @override
  Widget build(BuildContext context) {
    final value = valueAt(row, column.field);

    if (column.status) {
      return StatusBadge(
        status: value?.toString() ?? '-',
      );
    }

    if (column.currency) {
      return Text(
        Formatters.currency(value),
      );
    }

    if (column.date) {
      return Text(
        Formatters.date(value),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 280,
      ),
      child: Text(
        value?.toString() ?? '-',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
