import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/formatters.dart';

import '../models/resource_config.dart';
import '../services/admin_actions.dart';

Future<void> showFinancialYearDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final year = TextEditingController(
    text: Formatters.currentFinancialYear,
  );

  final start = TextEditingController(
    text: '${DateTime.now().year}-04-01',
  );

  final end = TextEditingController(
    text: '${DateTime.now().year + 1}-03-31',
  );

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
              decoration: const InputDecoration(
                labelText: 'Year Label',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: start,
              decoration: const InputDecoration(
                labelText: 'Start Date (YYYY-MM-DD)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: end,
              decoration: const InputDecoration(
                labelText: 'End Date (YYYY-MM-DD)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Create'),
        ),
      ],
    ),
  );

  if (saved == true && context.mounted) {
    await postAction(
      context,
      ref,
      ApiEndpoints.financialYears,
      ResourceConfigs.financialYears,
      'Financial year created',
      data: {
        'yearLabel': year.text.trim(),
        'startDate': start.text.trim(),
        'endDate': end.text.trim(),
      },
    );
  }

  year.dispose();
  start.dispose();
  end.dispose();
}