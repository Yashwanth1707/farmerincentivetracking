import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fims_frontend/core/network/api_endpoints.dart';
import 'package:fims_frontend/core/network/dio_client.dart';

class PaymentUploadScreen extends ConsumerStatefulWidget {
  const PaymentUploadScreen({super.key});

  @override
  ConsumerState<PaymentUploadScreen> createState() => _PaymentUploadScreenState();
}

class _PaymentUploadScreenState extends ConsumerState<PaymentUploadScreen> {
  final DioClient _client = DioClient();

  bool isLoading = false;
  String? error;
  String? successMessage;
  int currentStep = 0;

  List<Map<String, dynamic>> financialYears = [];
  List<Map<String, dynamic>> batchOptions = [];
  List<Map<String, dynamic>> previewRows = [];
  List<Map<String, dynamic>> validationErrors = [];
  List<Map<String, dynamic>> summaryChips = [];
  Map<String, dynamic>? processingResult;
  Map<String, double> tdsPercentages = {};

  String? selectedFinancialYearId;
  String? selectedBatchName;

  @override
  void initState() {
    super.initState();
    _loadFinancialYears();
    _loadBatchOptions();
  }

  Future<void> _loadFinancialYears() async {
    try {
      final response = await _client.get(ApiEndpoints.financialYears);
      if (response.statusCode == 200) {
        final payload = response.data is Map ? response.data['data'] : response.data;
        final rows = payload is List ? payload : [];
        setState(() {
          financialYears = rows
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
          if (selectedFinancialYearId == null && financialYears.isNotEmpty) {
            selectedFinancialYearId = financialYears.first['id']?.toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadBatchOptions() async {
    try {
      final response = await _client.get('${ApiEndpoints.payments}/batch-options');
      if (response.statusCode == 200) {
        final payload = response.data is Map ? response.data['data'] : response.data;
        final rows = payload is List ? payload : [];
        setState(() {
          batchOptions = rows
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
          if (batchOptions.isNotEmpty) {
            final existingSelection = selectedBatchName;
            final hasSelection = batchOptions.any((option) => option['value']?.toString() == existingSelection);
            if (!hasSelection) {
              selectedBatchName = batchOptions.first['value']?.toString();
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _downloadSampleFile(String endpoint, String fileName) async {
    try {
      final response = await _client.get(
        endpoint,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        final bytes = response.data is Uint8List
            ? response.data as Uint8List
            : response.data is List<int>
                ? Uint8List.fromList(response.data as List<int>)
                : Uint8List.fromList(utf8.encode(response.data.toString()));
        await FileSaver.instance.saveFile(name: fileName, bytes: bytes);
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _uploadExcel() async {
    if (selectedFinancialYearId == null) {
      setState(() => error = 'Select a financial year first.');
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
      successMessage = null;
      validationErrors = [];
      previewRows = [];
      summaryChips = [];
      processingResult = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      final pickedFile = result?.files.single;
      if (pickedFile == null) {
        setState(() => isLoading = false);
        return;
      }

      if (pickedFile.bytes == null && pickedFile.path == null) {
        setState(() {
          isLoading = false;
          error = 'The selected file could not be read.';
        });
        return;
      }

      final response = await _client.uploadFile(
        ApiEndpoints.paymentsUpload,
        filePath: pickedFile.path,
        bytes: pickedFile.bytes,
        fileName: pickedFile.name,
        extraFields: {'financialYearId': selectedFinancialYearId!},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final parsed = data['parsed'] as Map<String, dynamic>? ?? {};
        final preview = data['preview'] as Map<String, dynamic>? ?? {};
        final parsedRows = (preview['results'] as List<dynamic>? ?? [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        final errors = (parsed['errors'] as List<dynamic>? ?? [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        final summary = parsed['summary'] as Map<String, dynamic>? ?? {};

        setState(() {
          isLoading = false;
          previewRows = parsedRows;
          validationErrors = errors;
          summaryChips = [
            {'label': 'Total', 'value': '${summary['totalRecords'] ?? 0}'},
            {'label': 'Valid', 'value': '${summary['successfullyValidated'] ?? 0}'},
            {'label': 'Failed', 'value': '${summary['failedRecords'] ?? 0}'},
            {'label': 'Duplicate IDs', 'value': '${summary['duplicateFarmerIds'] ?? 0}'},
          ];
          if (errors.isEmpty && parsedRows.isNotEmpty) {
            successMessage = 'Upload validated successfully. Continue to batch selection.';
            currentStep = 2;
          } else {
            error = 'Validation needs attention before processing can continue.';
          }
        });
      } else {
        setState(() {
          isLoading = false;
          error = response.data['message'] ?? 'Upload failed';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _processPayments() async {
    if (previewRows.isEmpty || selectedBatchName == null) {
      setState(() => error = 'Upload a valid file and select a batch first.');
      return;
    }

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm payment processing'),
        content: Text(
          'You are about to process payment for ${previewRows.length} farmers. This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Process Payment')),
        ],
      ),
    );

    if (shouldProceed != true) {
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await _client.post(
        '${ApiEndpoints.payments}/confirm',
        data: {
          'previewResults': previewRows,
          'financialYearId': selectedFinancialYearId,
          'batchName': selectedBatchName,
          'tdsPercentages': {
            for (final entry in tdsPercentages.entries) entry.key: entry.value,
          },
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          isLoading = false;
          processingResult = response.data['data'];
          currentStep = 4;
          successMessage = 'Payment batch created successfully.';
        });
      } else {
        setState(() {
          isLoading = false;
          error = response.data['message'] ?? 'Processing failed';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _downloadPreviewReport() async {
    try {
      final response = await _client.post(
        '${ApiEndpoints.payments}/preview-report',
        data: {'previewResults': previewRows},
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        final bytes = response.data is Uint8List
            ? response.data as Uint8List
            : response.data is List<int>
                ? Uint8List.fromList(response.data as List<int>)
                : Uint8List.fromList(utf8.encode(response.data.toString()));
        await FileSaver.instance.saveFile(name: 'payment_preview.xlsx', bytes: bytes);
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _showTdsDialog() async {
    double selectedRate = 0;
    final hasCustomValue = tdsPercentages.isNotEmpty;
    if (hasCustomValue) {
      selectedRate = tdsPercentages.values.first;
    }

    final formKey = GlobalKey<FormFieldState<String>>();
    final customController = TextEditingController(text: selectedRate > 0 ? selectedRate.toString() : '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        String selectedMode = 'default';
        return AlertDialog(
          title: const Text('TDS confirmation'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Apply a TDS percentage to all farmers flagged for TDS.'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMode,
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('Use suggested rate')),
                    DropdownMenuItem(value: '1', child: Text('1%')),
                    DropdownMenuItem(value: '2', child: Text('2%')),
                    DropdownMenuItem(value: '5', child: Text('5%')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom')),
                  ],
                  onChanged: (value) {
                    selectedMode = value ?? 'default';
                    formKey.currentState?.didChange(value);
                  },
                  decoration: const InputDecoration(labelText: 'TDS %'),
                ),
                const SizedBox(height: 12),
                if (selectedMode == 'custom')
                  TextField(
                    controller: customController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Custom percentage'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                double rate = 0;
                switch (selectedMode) {
                  case '1':
                    rate = 1;
                    break;
                  case '2':
                    rate = 2;
                    break;
                  case '5':
                    rate = 5;
                    break;
                  case 'custom':
                    rate = double.tryParse(customController.text) ?? 0;
                    break;
                  default:
                    rate = 0;
                }
                Navigator.pop(context, {'rate': rate});
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    final rate = (result['rate'] as double?) ?? 0;
    if (rate <= 0) {
      setState(() => error = 'Please choose a valid TDS percentage.');
      return;
    }

    setState(() {
      for (final row in previewRows) {
        if (row['tdsApplicable'] == true) {
          tdsPercentages[row['farmerId']?.toString() ?? ''] = rate;
        }
      }
      successMessage = 'TDS percentage applied to ${tdsPercentages.length} farmers.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tdsRows = previewRows.where((row) => row['tdsApplicable'] == true).toList();
    final totalFarmers = previewRows.length;
    final totalGross = previewRows.fold<double>(0, (sum, row) => sum + (double.tryParse(row['grossAmount']?.toString() ?? '0') ?? 0));
    final totalTds = previewRows.fold<double>(0, (sum, row) => sum + (double.tryParse(row['tdsAmount']?.toString() ?? '0') ?? 0));
    final totalNet = previewRows.fold<double>(0, (sum, row) => sum + (double.tryParse(row['netAmount']?.toString() ?? '0') ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Processing Wizard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Process incentive payments through a guided workflow',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                ),
              ),
            if (successMessage != null)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(successMessage!),
                ),
              ),
            const SizedBox(height: 16),
            Stepper(
              currentStep: currentStep,
              onStepTapped: (index) => setState(() => currentStep = index),
              controlsBuilder: (context, details) {
                final isLast = details.stepIndex == 4;
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (details.stepIndex > 0)
                        OutlinedButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                      if (!isLast)
                        FilledButton(
                          onPressed: details.onStepContinue,
                          child: const Text('Continue'),
                        ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('1. Download Sample Files'),
                  content: _buildStepOne(context),
                  isActive: currentStep >= 0,
                ),
                Step(
                  title: const Text('2. Upload & Validate Excel'),
                  content: _buildStepTwo(context),
                  isActive: currentStep >= 1,
                ),
                Step(
                  title: const Text('3. Select Batch & Review Data'),
                  content: _buildStepThree(context),
                  isActive: currentStep >= 2,
                ),
                Step(
                  title: const Text('4. TDS Confirmation'),
                  content: _buildStepFour(context, tdsRows),
                  isActive: currentStep >= 3,
                ),
                Step(
                  title: const Text('5. Final Preview & Process'),
                  content: _buildStepFive(context, totalFarmers, totalGross, totalTds, totalNet, tdsRows),
                  isActive: currentStep >= 4,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepOne(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Use the sample templates to guide the upload format.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => _downloadSampleFile(ApiEndpoints.paymentsSampleExcel, 'sample_payment_input.xlsx'),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download Sample Input Excel'),
            ),
            OutlinedButton.icon(
              onPressed: () => _downloadSampleFile(ApiEndpoints.paymentsSampleOutput, 'sample_payment_output.xlsx'),
              icon: const Icon(Icons.download_done_rounded),
              label: const Text('Download Sample Output Report'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepTwo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedFinancialYearId,
          items: financialYears.map((year) {
            return DropdownMenuItem<String>(
              value: year['id']?.toString(),
              child: Text(year['yearLabel']?.toString() ?? 'Financial Year'),
            );
          }).toList(),
          onChanged: (value) => setState(() => selectedFinancialYearId = value),
          decoration: const InputDecoration(labelText: 'Financial Year'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isLoading ? null : _uploadExcel,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Upload Excel'),
        ),
        if (isLoading) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
        if (summaryChips.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: summaryChips.map((item) => _SummaryChip(label: item['label'], value: item['value'])).toList()),
        ],
        if (validationErrors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Validation issues', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...validationErrors.map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('- ${error['message'] ?? 'Invalid record'}'),
              )),
        ],
      ],
    );
  }

  Widget _buildStepThree(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedBatchName,
          items: batchOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option['value']?.toString(),
              child: Text(option['label']?.toString() ?? 'Batch'),
            );
          }).toList(),
          onChanged: (value) => setState(() => selectedBatchName = value),
          decoration: const InputDecoration(labelText: 'Select Payment Batch'),
        ),
        const SizedBox(height: 16),
        if (previewRows.isEmpty)
          Text('Upload an Excel file first to see the mapped preview.', style: Theme.of(context).textTheme.bodyMedium)
        else ...[
          Text('Mapped payment preview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Farmer ID')),
                DataColumn(label: Text('Farmer Name')),
                DataColumn(label: Text('Village')),
                DataColumn(label: Text('Acres')),
                DataColumn(label: Text('Gross')),
                DataColumn(label: Text('Prev FY')),
                DataColumn(label: Text('Total FY')),
                DataColumn(label: Text('TDS')),
                DataColumn(label: Text('Net')),
              ],
              rows: previewRows.map((row) {
                return DataRow(cells: [
                  DataCell(Text(row['farmerId']?.toString() ?? '')),
                  DataCell(Text(row['farmerName']?.toString() ?? '')),
                  DataCell(Text(row['village']?.toString() ?? '')),
                  DataCell(Text(row['areaInAcres']?.toString() ?? '')),
                  DataCell(Text(row['grossAmount']?.toString() ?? '')),
                  DataCell(Text(row['previousYearIncentive']?.toString() ?? '')),
                  DataCell(Text(row['totalYearlyIncentive']?.toString() ?? '')),
                  DataCell(Text(row['tdsApplicable'] == true ? 'YES' : 'NO')),
                  DataCell(Text(row['netAmount']?.toString() ?? '')),
                ]);
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepFour(BuildContext context, List<Map<String, dynamic>> tdsRows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tdsRows.isEmpty)
          const Text('No farmer crossed the annual threshold, so no TDS confirmation is required.')
        else ...[
          Text('${tdsRows.length} farmers need TDS review.', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _showTdsDialog,
            icon: const Icon(Icons.percent_rounded),
            label: const Text('Apply TDS Percentage'),
          ),
          const SizedBox(height: 12),
          Text('Current TDS rates: ${tdsPercentages.isEmpty ? "not set" : tdsPercentages.values.join(', ')}', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }

  Widget _buildStepFive(BuildContext context, int totalFarmers, double totalGross, double totalTds, double totalNet, List<Map<String, dynamic>> tdsRows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryChip(label: 'Farmers', value: '$totalFarmers'),
            _SummaryChip(label: 'Gross', value: '₹${totalGross.toStringAsFixed(2)}'),
            _SummaryChip(label: 'TDS', value: '₹${totalTds.toStringAsFixed(2)}'),
            _SummaryChip(label: 'Net', value: '₹${totalNet.toStringAsFixed(2)}'),
            _SummaryChip(label: 'TDS Farmers', value: '${tdsRows.length}'),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _downloadPreviewReport,
              icon: const Icon(Icons.table_chart_rounded),
              label: const Text('Download Output Report'),
            ),
            FilledButton.icon(
              onPressed: isLoading ? null : _processPayments,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Process Payment'),
            ),
          ],
        ),
        if (processingResult != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment completed', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Batch: ${processingResult?['batch']?['batchNumber'] ?? selectedBatchName}'),
                  Text('Farmers: ${processingResult?['totalFarmers'] ?? 0}'),
                  Text('Net Amount: ₹${(processingResult?['totalNetAmount'] ?? 0).toString()}'),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

