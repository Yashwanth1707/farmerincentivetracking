import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';

import '../models/resource_config.dart';
import '../services/admin_actions.dart';

Future<void> showSmsTemplateDialog(
  BuildContext context,
  WidgetRef ref,
) async {
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
              decoration: const InputDecoration(
                labelText: 'Template Name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: body,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Message Body',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Create'),
        ),
      ],
    ),
  );

  if (saved == true && context.mounted) {
    await postAction(
      context,
      ref,
      ApiEndpoints.smsTemplates,
      ResourceConfigs.sms,
      'Template created',
      data: {
        'name': name.text.trim(),
        'body': body.text.trim(),
      },
    );
  }

  name.dispose();
  body.dispose();
}