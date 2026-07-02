import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/resource_config.dart';
import '../providers/resource_provider.dart';
import 'package:fims_frontend/core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import '../widgets/error_state.dart';
import '../widgets/page_hero.dart';
import '../widgets/section_card.dart';
import '../widgets/simple_table.dart';

class ResourceListScreen extends ConsumerWidget {
  final ResourceConfig config;

  const ResourceListScreen({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = resourceProvider(config);
    final result = ref.watch(provider);

    return result.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => ErrorState(
        title: '${config.title} unavailable',
        message: error.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (rows) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHero(
                title: config.title,
                subtitle: config.subtitle,
                icon: config.icon,
                trailing: config.primaryAction == null &&
                        config != ResourceConfigs.payments
                    ? null
                    : FilledButton.icon(
                        onPressed: () {
                          if (config.primaryAction != null) {
                            config.primaryAction!(context, ref);
                            return;
                          }

                          if (config == ResourceConfigs.payments) {
                            context.goNamed(RouteNames.paymentUpload);
                          }
                        },
                        icon: Icon(
                          config.primaryActionIcon,
                        ),
                        label: Text(
                          config.primaryActionLabel,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: config.sectionTitle,
                icon: config.icon,
                child: SimpleTable(
                  rows: rows,
                  columns: config.columns,
                  rowActions: config.rowActions,
                  emptyTitle: config.emptyTitle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
