import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fims_frontend/core/network/api_endpoints.dart';
import 'package:fims_frontend/core/network/dio_client.dart';
import 'package:fims_frontend/shared/widgets/app_snackbar.dart';

import '../models/resource_config.dart';
import '../providers/resource_provider.dart';

import '../widgets/error_state.dart';
import '../widgets/page_hero.dart';
import '../widgets/section_card.dart';
import '../widgets/simple_table.dart';
import '../models/column_spec.dart';  


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends ConsumerState<SettingsScreen> {
  final _client = DioClient();

  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final provider = resourceProvider(
      ResourceConfigs.settings,
    );

    final result = ref.watch(provider);

    return result.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => ErrorState(
        title: 'Settings unavailable',
        message: error.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (rows) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              PageHero(
                title: 'Settings',
                subtitle:
                    'Maintain payment, TDS, and notification configuration.',
                icon: Icons.settings_rounded,
                trailing: FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _openEdit(
                            context,
                            rows,
                          ),
                  icon:
                      const Icon(Icons.tune_rounded),
                  label: const Text(
                    'Edit Settings',
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SectionCard(
                title: 'Configuration',
                icon: Icons.list_alt_rounded,
                child: SimpleTable(
                  rows: rows,
                  columns: const [
                    ColumnSpec(
                      'key',
                      'Key',
                    ),
                    ColumnSpec(
                      'value',
                      'Value',
                    ),
                    ColumnSpec(
                      'category',
                      'Category',
                    ),
                    ColumnSpec(
                      'updatedAt',
                      'Updated',
                      date: true,
                    ),
                  ],
                  emptyTitle:
                      'No settings found',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEdit(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) async {    final controllers = {
      for (final row in rows)
        row['key'].toString(): TextEditingController(
          text: row['value']?.toString() ?? '',
        ),
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
                      padding:
                          const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText: entry.key,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(true),
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

      final response = await _client.put(
        ApiEndpoints.settings,
        data: payload,
      );

      if (!context.mounted) return;

      if (response.statusCode == 200 &&
          response.data['success'] == true) {
        AppSnackbar.success(
          context,
          'Settings updated',
        );

        ref.invalidate(
          resourceProvider(
            ResourceConfigs.settings,
          ),
        );
      } else {
        AppSnackbar.error(
          context,
          response.data['message']?.toString() ??
              'Unable to update settings',
        );
      }
    } catch (error) {
      if (context.mounted) {
        AppSnackbar.error(
          context,
          error.toString(),
        );
      }
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }

      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
