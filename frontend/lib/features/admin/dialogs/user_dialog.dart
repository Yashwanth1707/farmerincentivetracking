import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/formatters.dart';

import '../models/resource_config.dart';
import '../services/admin_actions.dart';

Future<void> showUserDialog(
  BuildContext context,
  WidgetRef ref,
) async {
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
      builder: (context, setState) {
        return AlertDialog(
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
                        labelText:
                            Formatters.capitalize(entry.key),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                    ),
                    items: const [
                      'ADMIN',
                      'OPERATOR',
                      'VIEWER',
                    ]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        role = value ?? role;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    ),
  );

  if (saved == true && context.mounted) {
    final payload = {
      for (final entry in fields.entries)
        entry.key: entry.value.text.trim(),
      'role': role,
    };

    await postAction(
      context,
      ref,
      ApiEndpoints.users,
      ResourceConfigs.users,
      'User created',
      data: payload,
    );
  }

  for (final controller in fields.values) {
    controller.dispose();
  }
}