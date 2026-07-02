import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fims_frontend/core/network/api_endpoints.dart';
import 'package:fims_frontend/core/network/dio_client.dart';

import '../providers/resource_provider.dart';
import '../utils/report_view_utils.dart';

import '../widgets/page_hero.dart';
import '../widgets/section_card.dart';
import '../widgets/error_state.dart';

typedef JsonMap = Map<String, dynamic>;

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String? _selectedBatchId;
  String? _selectedFinancialYearId;
  bool _querySelectionsApplied = false;

  final _farmerSearchController = TextEditingController();

  JsonMap? _selectedFarmer;

  final _client = DioClient();

  bool _loading = false;

  ReportViewModel? _viewModel;

  String? _error;

  @override
  void dispose() {
    _farmerSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_querySelectionsApplied) return;

    final query = GoRouterState.of(context).uri.queryParameters;
    _selectedBatchId = query['batchId'];
    _selectedFinancialYearId = query['financialYearId'];
    _querySelectionsApplied = true;
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
          else if (_viewModel != null)
            SectionCard(
              title: 'Report Result',
              icon: Icons.data_object_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _viewModel!.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _downloadExcel,
                        icon: const Icon(Icons.file_download_rounded),
                        label: const Text('Export Excel'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _downloadPdf,
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Export PDF'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _viewModel!.metrics.map((metric) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(metric.label, style: Theme.of(context).textTheme.labelMedium),
                            const SizedBox(height: 4),
                            Text(metric.value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ..._viewModel!.sections.map((section) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(section.title, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            if (section.rows.isEmpty)
                              Text('No rows available', style: Theme.of(context).textTheme.bodyMedium)
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: section.rows.first.keys
                                      .map((key) => DataColumn(label: Text(_formatHeader(key))))
                                      .toList(),
                                  rows: section.rows.map((row) {
                                    return DataRow(
                                      cells: row.entries.map((entry) {
                                        return DataCell(Text(_formatValue(entry.value)));
                                      }).toList(),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      )),
                ],
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
      _viewModel = null;
    });

    try {
      final response = await _client.get(endpoint);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final payload = response.data['data'];
        setState(() {
          _viewModel = buildReportViewModel(payload);
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

  Future<void> _downloadExcel() async {
    if (_viewModel == null) return;
    try {
      final response = await _client.post(
        ApiEndpoints.reportExportExcel,
        data: {
          'data': _viewModel!.exportRows,
          'sheetName': _viewModel!.title,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        final bytes = response.data is Uint8List
            ? response.data as Uint8List
            : response.data is List<int>
                ? Uint8List.fromList(response.data as List<int>)
                : Uint8List.fromList(utf8.encode(response.data.toString()));
        await FileSaver.instance.saveFile(name: '${_viewModel!.title.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}.xlsx', bytes: bytes);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_viewModel == null) return;
    try {
      final headers = _viewModel!.sections.isNotEmpty && _viewModel!.sections.first.rows.isNotEmpty
          ? _viewModel!.sections.first.rows.first.keys.toList()
          : const <String>[];
      final rows = _viewModel!.sections.isNotEmpty
          ? _viewModel!.sections.first.rows.map((row) => row.values.toList()).toList()
          : const <List<dynamic>>[];
      final response = await _client.post(
        ApiEndpoints.reportExportPdf,
        data: {
          'title': _viewModel!.title,
          'headers': headers,
          'rows': rows,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        final bytes = response.data is Uint8List
            ? response.data as Uint8List
            : response.data is List<int>
                ? Uint8List.fromList(response.data as List<int>)
                : Uint8List.fromList(utf8.encode(response.data.toString()));
        await FileSaver.instance.saveFile(name: '${_viewModel!.title.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}.pdf', bytes: bytes);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  String _formatHeader(String key) {
    return key.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}').splitMapJoin(
      RegExp(r'[_\-]'),
      onMatch: (match) => ' ',
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is DateTime) return value.toLocal().toString();
    if (value is List || value is Map) return value.toString();
    return value.toString();
  }
}
