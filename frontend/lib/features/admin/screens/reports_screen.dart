import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fims_frontend/core/network/api_endpoints.dart';
import 'package:fims_frontend/core/network/dio_client.dart';

import '../providers/resource_provider.dart';
import '../utils/json_helpers.dart';

import '../widgets/page_hero.dart';
import '../widgets/section_card.dart';
import '../widgets/error_state.dart';
import '../widgets/json_preview.dart';

typedef JsonMap = Map<String, dynamic>;

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String? _selectedBatchId;
  String? _selectedFinancialYearId;

  final _farmerSearchController = TextEditingController();

  JsonMap? _selectedFarmer;

  final _client = DioClient();

  bool _loading = false;

  JsonMap? _result;

  String? _error;

  @override
  void dispose() {
    _farmerSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final financialYears = ref.watch(financialYearsProvider);

    final batches = ref.watch(batchesProvider);

    final farmers = ref.watch(
      farmerSearchProvider(
        _farmerSearchController.text,
      ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: 'Reports',
            subtitle:
                'Run farmer ledger, payment register, batch, FY, and TDS reports.',
            icon: Icons.assessment_rounded,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Report Inputs',
            icon: Icons.tune_rounded,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _farmerSearchController,
                        decoration: const InputDecoration(
                          labelText: 'Search Farmer',
                          hintText: 'Farmer ID / Mobile / Name',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      farmers.when(
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                        data: (rows) {
                          if (rows.isEmpty) {
                            return const SizedBox();
                          }

                          return SizedBox(
                            height: 180,
                            child: ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (_, index) {
                                final farmer = rows[index];

                                return ListTile(
                                  title: Text(
                                    farmer["name"] ?? "",
                                  ),
                                  subtitle: Text(
                                    "${farmer["farmerId"]} • ${farmer["phone"] ?? ""}",
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedFarmer = farmer;

                                      _farmerSearchController.text =
                                          farmer["name"] ?? "";
                                    });
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                financialYears.when(
                  loading: () => const SizedBox(
                    width: 260,
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, __) => const SizedBox(),
                  data: (rows) {
                    return SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Financial Year',
                        ),
                        initialValue: _selectedFinancialYearId,
                        items: rows.map((fy) {
                          return DropdownMenuItem<String>(
                            value: fy['id'].toString(),
                            child: Text(
                              fy['yearLabel'],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFinancialYearId = value;
                          });
                        },
                      ),
                    );
                  },
                ),
                batches.when(
                  loading: () => const SizedBox(
                    width: 260,
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, __) => const SizedBox(),
                  data: (rows) {
                    return SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Batch',
                        ),
                        initialValue: _selectedBatchId,
                        items: rows.map((batch) {
                          return DropdownMenuItem<String>(
                            value: batch['id'].toString(),
                            child: Text(
                              batch['batchNumber'],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBatchId = value;
                          });
                        },
                      ),
                    );
                  },
                ),
                FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _run(
                            ApiEndpoints.reportPaymentRegister,
                          ),
                  icon: const Icon(
                    Icons.receipt_long_rounded,
                  ),
                  label: const Text(
                    'Payment Register',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedFarmer == null
                      ? null
                      : () => _run(
                            ApiEndpoints.reportFarmerLedger(
                              _selectedFarmer!['id'].toString(),
                            ),
                          ),
                  icon: const Icon(
                    Icons.person_rounded,
                  ),
                  label: const Text(
                    'Farmer Ledger',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedBatchId == null
                      ? null
                      : () => _run(
                            ApiEndpoints.reportBatchReport(
                              _selectedBatchId!,
                            ),
                          ),
                  icon: const Icon(
                    Icons.inventory_2_rounded,
                  ),
                  label: const Text(
                    'Batch Report',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedFinancialYearId == null
                      ? null
                      : () => _run(
                            ApiEndpoints.reportFyReport(
                              _selectedFinancialYearId!,
                            ),
                          ),
                  icon: const Icon(
                    Icons.calendar_month_rounded,
                  ),
                  label: const Text(
                    'FY Report',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedFinancialYearId == null
                      ? null
                      : () => _run(
                            ApiEndpoints.reportTdsReport(
                              _selectedFinancialYearId!,
                            ),
                          ),
                  icon: const Icon(
                    Icons.percent_rounded,
                  ),
                  label: const Text(
                    'TDS Report',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ErrorState(
              title: 'Report failed',
              message: _error!,
              compact: true,
            )
          else if (_result != null)
            SectionCard(
              title: 'Report Result',
              icon: Icons.data_object_rounded,
              child: JsonPreview(
                value: _result!,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _run(String endpoint) async {
    if (endpoint.endsWith('/')) {
      setState(() {
        _error = 'Enter the required ID before running this report.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final response = await _client.get(endpoint);

      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _result = asMap(response.data['data']);
        });
      } else {
        setState(() {
          _error =
              response.data['message']?.toString() ?? 'Unable to run report';
        });
      }
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}
