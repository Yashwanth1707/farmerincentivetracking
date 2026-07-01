import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/stat_card.dart';

import '../providers/resource_provider.dart';
import '../utils/json_helpers.dart';
import '../widgets/page_hero.dart';
import '../widgets/section_card.dart';
import '../widgets/simple_table.dart';
import '../models/column_spec.dart';
import '../widgets/error_state.dart';

class ApiDashboardScreen extends ConsumerWidget {
  const ApiDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardDataProvider);

    return data.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),

      error: (error, _) => ErrorState(
        title: 'Dashboard unavailable',
        message: error.toString(),
        onRetry: () => ref.invalidate(dashboardDataProvider),
      ),

      data: (stats) {
        final farmers = asMap(stats['farmers']);
        final payments = asMap(stats['payments']);
        final batches = asMap(stats['batches']);
        final recentBatches = asList(stats['recentBatches']);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHero(
                title: 'Dashboard',
                subtitle:
                    'Live operating view across farmers, payments, batches, and TDS.',
                icon: Icons.dashboard_rounded,
              ),

              const SizedBox(height: 16),

              StatCardGrid(
                cards: [
                  StatCard(
                    label: 'Active Farmers',
                    value: Formatters.number(farmers['active']),
                    icon: Icons.people_rounded,
                    subtitle:
                        '${Formatters.number(farmers['total'])} total profiles',
                  ),

                  StatCard(
                    label: 'Net Payments',
                    value: Formatters.compactCurrency(
                      payments['totalNet'],
                    ),
                    icon: Icons.payments_rounded,
                    iconColor: AppColors.accentDeep,
                    subtitle:
                        '${Formatters.number(payments['total'])} payment records',
                  ),

                  StatCard(
                    label: 'Approved Batches',
                    value: Formatters.number(
                      batches['approved'],
                    ),
                    icon: Icons.verified_rounded,
                    iconColor: AppColors.success,
                    subtitle:
                        '${Formatters.number(batches['pending'])} pending',
                  ),

                  StatCard(
                    label: 'TDS Decisions',
                    value: Formatters.number(
                      stats['pendingTds'],
                    ),
                    icon: Icons.percent_rounded,
                    iconColor: AppColors.warning,
                    subtitle: 'Pending review',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              SectionCard(
                title: 'Recent Batches',
                icon: Icons.inventory_2_rounded,
                child: SimpleTable(
                  rows: recentBatches,
                  columns: const [
                    ColumnSpec(
                      'batchNumber',
                      'Batch',
                    ),
                    ColumnSpec(
                      'financialYear.yearLabel',
                      'FY',
                    ),
                    ColumnSpec(
                      'status',
                      'Status',
                      status: true,
                    ),
                    ColumnSpec(
                      'totalFarmers',
                      'Farmers',
                    ),
                    ColumnSpec(
                      'totalNetAmount',
                      'Net',
                      currency: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}