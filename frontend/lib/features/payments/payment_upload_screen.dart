import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fims_frontend/core/network/api_endpoints.dart';
import 'package:fims_frontend/core/network/dio_client.dart';

class PaymentUploadScreen extends ConsumerStatefulWidget {
  const PaymentUploadScreen({super.key});

  @override
  ConsumerState<PaymentUploadScreen> createState() =>
      _PaymentUploadScreenState();
}

class _PaymentUploadScreenState extends ConsumerState<PaymentUploadScreen> {
  final DioClient _client = DioClient();

  final _paymentDateController = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final _schemeController = TextEditingController(text: 'Farmer Incentive');
  final _customTdsController = TextEditingController();

  bool isLoading = false;
  String? error;
  String? successMessage;
  int currentStep = 0;

  List<JsonMap> financialYears = [];
  List<JsonMap> batchOptions = [];
  List<JsonMap> uploadedRows = [];
  List<JsonMap> mappedFarmers = [];
  List<JsonMap> missingFarmers = [];
  List<JsonMap> duplicateRows = [];
  List<JsonMap> invalidRows = [];
  JsonMap summary = {};
  JsonMap? processingResult;

  final Set<String> newlyCreatedFarmerIds = {};
  final Map<String, double> tdsPercentages = {};

  String? selectedFinancialYearId;
  String? selectedBatchName;
  String tdsMode = 'default';
  double defaultTdsRate = 0;

  @override
  void initState() {
    super.initState();
    _loadFinancialYears();
    _loadBatchOptions();
  }

  @override
  void dispose() {
    _paymentDateController.dispose();
    _schemeController.dispose();
    _customTdsController.dispose();
    super.dispose();
  }

  Future<void> _loadFinancialYears() async {
    try {
      final response = await _client.get(
        ApiEndpoints.financialYears,
        queryParameters: {'page': 1, 'limit': 100},
      );
      if (response.statusCode == 200) {
        final rows = _extractRows(response.data['data']);
        setState(() {
          financialYears = rows;
          selectedFinancialYearId ??= rows.activeOrFirstId;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadBatchOptions() async {
    try {
      final response =
          await _client.get('${ApiEndpoints.payments}/batch-options');
      if (response.statusCode == 200) {
        final rows = _extractRows(response.data['data']);
        setState(() {
          batchOptions = rows;
          selectedBatchName ??=
              rows.isEmpty ? 'Kharif Batch 1' : rows.first['value']?.toString();
        });
      }
    } catch (_) {
      setState(() {
        selectedBatchName ??= 'Kharif Batch 1';
      });
    }
  }

  Future<void> _downloadSampleFile(String endpoint, String fileName) async {
    try {
      setState(() {
        error = null;
        successMessage = null;
      });
      final response = await _client.get(
        endpoint,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: _asBytes(response.data),
        );
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

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      allowMultiple: false,
      withData: kIsWeb,
    );
    final pickedFile = result?.files.single;
    if (pickedFile == null) return;

    setState(() {
      isLoading = true;
      error = null;
      successMessage = null;
      mappedFarmers = [];
      missingFarmers = [];
      duplicateRows = [];
      invalidRows = [];
      uploadedRows = [];
      processingResult = null;
      summary = {};
      newlyCreatedFarmerIds.clear();
      tdsPercentages.clear();
    });

    try {
      final response = await _client.uploadFile(
        ApiEndpoints.paymentsUpload,
        filePath: kIsWeb ? null : pickedFile.path,
        bytes: kIsWeb ? pickedFile.bytes : null,
        fileName: pickedFile.name,
        extraFields: {'financialYearId': selectedFinancialYearId!},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        _applyUploadData(_asMap(response.data['data']));
        setState(() {
          isLoading = false;
          currentStep = missingFarmers.isEmpty ? 3 : 2;
          successMessage =
              '${mappedFarmers.length} farmers mapped successfully.';
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

  Future<void> _refreshMapping() async {
    if (uploadedRows.isEmpty || selectedFinancialYearId == null) return;

    setState(() {
      isLoading = true;
      error = null;
      successMessage = null;
    });

    try {
      final response = await _client.post(
        ApiEndpoints.paymentsPreview,
        data: {
          'validRows': uploadedRows,
          'financialYearId': selectedFinancialYearId,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final preview = _asMap(response.data['data']);
        final data = {
          'mappedFarmers': preview['mappedFarmers'],
          'missingFarmers': preview['missingFarmers'],
          'summary': preview['summary'],
          'parsed': {'validRows': uploadedRows},
          'preview': preview,
        };
        _applyUploadData(data);
        setState(() {
          isLoading = false;
          currentStep = missingFarmers.isEmpty ? 3 : 2;
          successMessage = 'Farmer mapping refreshed.';
        });
      } else {
        setState(() {
          isLoading = false;
          error = response.data['message'] ?? 'Unable to refresh mapping';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  void _applyUploadData(JsonMap data) {
    final parsed = _asMap(data['parsed']);
    final preview = _asMap(data['preview']);
    final previewResults = _extractRows(preview['results']);

    final mapped = _extractRows(data['mappedFarmers']).isNotEmpty
        ? _extractRows(data['mappedFarmers'])
        : previewResults
            .where((row) => row['status'] != 'FARMER_NOT_FOUND')
            .toList();
    final missing = _extractRows(data['missingFarmers']).isNotEmpty
        ? _extractRows(data['missingFarmers'])
        : previewResults
            .where((row) => row['status'] == 'FARMER_NOT_FOUND')
            .toList();

    mappedFarmers = mapped.map((row) {
      final farmerId = row['farmerId']?.toString() ?? '';
      return {
        ...row,
        'source': newlyCreatedFarmerIds.contains(farmerId) ? 'NEW' : 'EXISTING',
      };
    }).toList();
    missingFarmers = missing;
    duplicateRows = _extractRows(data['duplicateRows']);
    invalidRows = _extractRows(data['invalidRows']);
    uploadedRows = _extractRows(parsed['validRows']);
    summary = {
      ..._asMap(parsed['summary']),
      ..._asMap(data['summary']),
    };

    defaultTdsRate = mappedFarmers
        .map((row) => _num(row['suggestedTdsPercentage']))
        .firstWhere((value) => value > 0, orElse: () => 1);
    _recalculateTds();
  }

  Future<void> _showCreateFarmerDialog(JsonMap missing) async {
    final formKey = GlobalKey<FormState>();
    final farmerId =
        TextEditingController(text: missing['farmerId']?.toString());
    final name = TextEditingController();
    final village = TextEditingController();
    final district = TextEditingController();
    final phone = TextEditingController();
    final bankName = TextEditingController();
    final branchName = TextEditingController();
    final accountNumber = TextEditingController();
    final ifscCode = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Missing Farmer'),
        content: SizedBox(
          width: 620,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _dialogField(farmerId, 'Farmer ID', readOnly: true),
                  _dialogField(name, 'Farmer Name', required: true),
                  _dialogField(village, 'Village', required: true),
                  _dialogField(district, 'District', required: true),
                  _dialogField(phone, 'Mobile Number'),
                  _dialogField(bankName, 'Bank Name'),
                  _dialogField(branchName, 'Branch'),
                  _dialogField(accountNumber, 'Account Number'),
                  _dialogField(ifscCode, 'IFSC'),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final response = await _client.post(
                  ApiEndpoints.farmers,
                  data: {
                    'farmerId': farmerId.text.trim(),
                    'name': name.text.trim(),
                    'village': village.text.trim(),
                    'district': district.text.trim(),
                    'phone':
                        phone.text.trim().isEmpty ? null : phone.text.trim(),
                    'bankName': bankName.text.trim().isEmpty
                        ? null
                        : bankName.text.trim(),
                    'branchName': branchName.text.trim().isEmpty
                        ? null
                        : branchName.text.trim(),
                    'accountNumber': accountNumber.text.trim().isEmpty
                        ? null
                        : accountNumber.text.trim(),
                    'ifscCode': ifscCode.text.trim().isEmpty
                        ? null
                        : ifscCode.text.trim(),
                  },
                );

                if (response.statusCode == 201 &&
                    response.data['success'] == true) {
                  newlyCreatedFarmerIds.add(farmerId.text.trim());
                  if (context.mounted) Navigator.pop(context, true);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(response.data['message']?.toString() ??
                          'Unable to create farmer'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Save Farmer'),
          ),
        ],
      ),
    );

    for (final controller in [
      farmerId,
      name,
      village,
      district,
      phone,
      bankName,
      branchName,
      accountNumber,
      ifscCode,
    ]) {
      controller.dispose();
    }

    if (created == true) {
      await _refreshMapping();
    }
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool readOnly = false,
  }) {
    return SizedBox(
      width: 290,
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null
            : null,
      ),
    );
  }

  Future<void> _processPayments() async {
    if (mappedFarmers.isEmpty || selectedBatchName == null) {
      setState(
          () => error = 'Map farmers and select a batch before processing.');
      return;
    }
    if (missingFarmers.isNotEmpty || invalidRows.isNotEmpty) {
      setState(() => error = 'Resolve missing farmers and invalid rows first.');
      return;
    }

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Process payments'),
        content: Text(
          'This will create a payment batch and save ${mappedFarmers.length} payments. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Process Payment'),
          ),
        ],
      ),
    );
    if (shouldProceed != true) return;

    setState(() {
      isLoading = true;
      error = null;
      successMessage = null;
    });

    try {
      final response = await _client.post(
        ApiEndpoints.paymentsConfirm,
        data: {
          'previewResults': mappedFarmers,
          'financialYearId': selectedFinancialYearId,
          'batchName': selectedBatchName,
          'scheme': _schemeController.text.trim(),
          'paymentDate': _paymentDateController.text.trim(),
          'tdsPercentages': tdsPercentages,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          isLoading = false;
          processingResult = _asMap(response.data['data']);
          currentStep = 7;
          successMessage = 'Payment batch processed successfully.';
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

  void _recalculateTds() {
    final selectedRate = _selectedTdsRate;
    mappedFarmers = mappedFarmers.map((row) {
      final gross = _num(row['grossAmount']);
      final previous = _num(row['previousYearIncentive']);
      final currentFyTotal = _num(row['totalYearlyIncentive']);
      final cumulative = currentFyTotal > 0 ? currentFyTotal : previous + gross;
      final tdsApplicable = cumulative >= 100000;
      final rate = tdsApplicable ? selectedRate : 0.0;
      final tdsAmount = tdsApplicable ? _roundMoney(gross * rate / 100) : 0.0;
      final farmerId = row['farmerId']?.toString() ?? '';
      if (tdsApplicable) tdsPercentages[farmerId] = rate;
      return {
        ...row,
        'tdsApplicable': tdsApplicable,
        'tdsPercentage': rate,
        'tdsAmount': tdsAmount,
        'netAmount': _roundMoney(gross - tdsAmount),
        'totalYearlyIncentive': cumulative,
      };
    }).toList();
  }

  double get _selectedTdsRate {
    switch (tdsMode) {
      case '1':
        return 1;
      case '2':
        return 2;
      case '5':
        return 5;
      case 'custom':
        return double.tryParse(_customTdsController.text.trim()) ??
            defaultTdsRate;
      default:
        return defaultTdsRate <= 0 ? 1 : defaultTdsRate;
    }
  }

  Future<void> _downloadPreviewReport() async {
    await _downloadPostReport(
      '${ApiEndpoints.payments}/preview-report',
      {'previewResults': mappedFarmers},
      'payment_report.xlsx',
    );
  }

  Future<void> _downloadFailedRecordsReport() async {
    await _downloadPostReport(
      ApiEndpoints.paymentsImportErrors,
      {
        'errors': [...invalidRows, ...duplicateRows, ...missingFarmers]
      },
      'failed_records_report.xlsx',
    );
  }

  Future<void> _downloadBankFile() async {
    await _downloadPostReport(
      '${ApiEndpoints.payments}/bank-file-preview',
      {'previewResults': mappedFarmers},
      'bank_file.xlsx',
    );
  }

  Future<void> _downloadTdsReport() async {
    await _downloadPostReport(
      '${ApiEndpoints.payments}/tds-report-preview',
      {'previewResults': mappedFarmers},
      'tds_report.xlsx',
    );
  }

  Future<void> _downloadAuditReport() async {
    await _downloadPostReport(
      '${ApiEndpoints.payments}/audit-report-preview',
      {
        'previewResults': mappedFarmers,
        'processingResult': processingResult,
        'financialYearId': selectedFinancialYearId,
        'batchName': selectedBatchName,
      },
      'payment_audit_report.xlsx',
    );
  }

  Future<void> _downloadPostReport(
    String endpoint,
    JsonMap data,
    String fileName,
  ) async {
    try {
      final response = await _client.post(
        endpoint,
        data: data,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: _asBytes(response.data),
        );
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    final tdsRows =
        mappedFarmers.where((row) => row['tdsApplicable'] == true).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Processing Wizard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroPanel(
              totalMapped: mappedFarmers.length,
              missing: missingFarmers.length,
              invalid: invalidRows.length + duplicateRows.length,
              netPayable: totals.net,
            ),
            const SizedBox(height: 16),
            if (error != null) _MessageCard(message: error!, isError: true),
            if (successMessage != null) _MessageCard(message: successMessage!),
            const SizedBox(height: 12),
            Stepper(
              currentStep: currentStep,
              onStepTapped: (index) => setState(() => currentStep = index),
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (details.stepIndex > 0)
                        OutlinedButton.icon(
                          onPressed: details.onStepCancel,
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: const Text('Back'),
                        ),
                      if (details.stepIndex < 7)
                        FilledButton.icon(
                          onPressed: details.onStepContinue,
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text('Continue'),
                        ),
                    ],
                  ),
                );
              },
              onStepContinue: () {
                if (currentStep < 7) setState(() => currentStep += 1);
              },
              onStepCancel: () {
                if (currentStep > 0) setState(() => currentStep -= 1);
              },
              steps: [
                _step('Upload File', _buildUploadFileStep(), 0),
                _step('Map Farmers', _buildMappingStep(), 1),
                _step('Resolve Missing Farmers', _buildMissingStep(), 2),
                _step('Payment Preview', _buildPreviewStep(), 3),
                _step('Batch Selection', _buildBatchStep(), 4),
                _step('TDS Confirmation', _buildTdsStep(tdsRows), 5),
                _step('Process Payment', _buildProcessStep(totals), 6),
                _step(
                    'Reports Generated', _buildReportsStep(totals, tdsRows), 7),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Step _step(String title, Widget content, int index) {
    return Step(
      title: Text(title),
      content: content,
      isActive: currentStep >= index,
      state: currentStep > index ? StepState.complete : StepState.indexed,
    );
  }

  Widget _buildTemplatesStep() {
    return _Section(
      title: 'Download Templates',
      icon: Icons.download_rounded,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: () => _downloadSampleFile(
              ApiEndpoints.paymentsSampleExcel,
              'sample_payment_input.xlsx',
            ),
            icon: const Icon(Icons.table_chart_rounded),
            label: const Text('Download Sample Input Excel'),
          ),
          OutlinedButton.icon(
            onPressed: () => _downloadSampleFile(
              ApiEndpoints.paymentsSampleOutput,
              'sample_payment_output.xlsx',
            ),
            icon: const Icon(Icons.request_page_rounded),
            label: const Text('Download Sample Output Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadFileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTemplatesStep(),
        const SizedBox(height: 12),
        _buildUploadStep(),
      ],
    );
  }

  Widget _buildUploadStep() {
    return _Section(
      title: 'Upload Excel',
      icon: Icons.upload_file_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 340,
            child: DropdownButtonFormField<String>(
              initialValue: selectedFinancialYearId,
              isExpanded: true,
              items: financialYears.map((year) {
                return DropdownMenuItem<String>(
                  value: year['id']?.toString(),
                  child:
                      Text(year['yearLabel']?.toString() ?? 'Financial Year'),
                );
              }).toList(),
              onChanged: (value) =>
                  setState(() => selectedFinancialYearId = value),
              decoration: const InputDecoration(
                labelText: 'Financial Year',
                prefixIcon: Icon(Icons.calendar_month_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isLoading ? null : _uploadExcel,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload .xlsx / .xls'),
          ),
          if (isLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildMappingStep() {
    return _Section(
      title: 'Auto Map Farmers',
      icon: Icons.hub_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryChip(
                  label: 'Mapped Successfully',
                  value: '${mappedFarmers.length}'),
              _SummaryChip(
                  label: 'Missing Farmers', value: '${missingFarmers.length}'),
              _SummaryChip(
                  label: 'Duplicate Rows', value: '${duplicateRows.length}'),
              _SummaryChip(
                  label: 'Invalid Rows', value: '${invalidRows.length}'),
            ],
          ),
          const SizedBox(height: 12),
          if (mappedFarmers.isEmpty)
            const Text('Upload a file to map Farmer IDs to Farmer Master.')
          else
            _SmallRows(
              rows: mappedFarmers.take(6).toList(),
              columns: const ['farmerId', 'farmerName', 'village', 'status'],
            ),
          if (duplicateRows.isNotEmpty || invalidRows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Invalid or duplicate upload rows',
                style: Theme.of(context).textTheme.titleMedium),
            _IssueList(rows: [...duplicateRows, ...invalidRows]),
          ],
        ],
      ),
    );
  }

  Widget _buildMissingStep() {
    return _Section(
      title: 'Resolve Missing Farmers',
      icon: Icons.person_add_alt_1_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (missingFarmers.isEmpty)
            const _EmptyState(
              icon: Icons.verified_rounded,
              text: 'All uploaded Farmer IDs are mapped to Farmer Master.',
            )
          else
            ...missingFarmers.map(
              (row) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person_off_rounded),
                  title: Text(row['farmerId']?.toString() ?? 'Missing Farmer'),
                  subtitle: Text(row['message']?.toString() ??
                      'Farmer ID was not found in master data.'),
                  trailing: FilledButton.icon(
                    onPressed: () => _showCreateFarmerDialog(row),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Farmer'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed:
                uploadedRows.isEmpty || isLoading ? null : _refreshMapping,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Refresh Mapping'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep() {
    return _Section(
      title: 'Payment Preview',
      icon: Icons.fact_check_rounded,
      child: mappedFarmers.isEmpty
          ? const Text('Mapped payment rows will appear here.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Farmer ID')),
                  DataColumn(label: Text('Farmer Name')),
                  DataColumn(label: Text('Village')),
                  DataColumn(label: Text('Bank Details')),
                  DataColumn(label: Text('Gross')),
                  DataColumn(label: Text('Previous FY')),
                  DataColumn(label: Text('Current FY Total')),
                  DataColumn(label: Text('TDS Applicable')),
                  DataColumn(label: Text('TDS Amount')),
                  DataColumn(label: Text('Net Amount')),
                  DataColumn(label: Text('Status')),
                ],
                rows: mappedFarmers.map((row) {
                  return DataRow(cells: [
                    DataCell(Text(row['farmerId']?.toString() ?? '')),
                    DataCell(Text(row['farmerName']?.toString() ?? '')),
                    DataCell(Text(row['village']?.toString() ?? '')),
                    DataCell(Text(_bankDetails(row))),
                    DataCell(Text(_money(row['grossAmount']))),
                    DataCell(Text(_money(row['previousYearIncentive']))),
                    DataCell(Text(_money(row['totalYearlyIncentive']))),
                    DataCell(Text(row['tdsApplicable'] == true ? 'Yes' : 'No')),
                    DataCell(Text(_money(row['tdsAmount']))),
                    DataCell(Text(_money(row['netAmount']))),
                    DataCell(Text(row['source'] == 'NEW' ? 'New' : 'Existing')),
                  ]);
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildBatchStep() {
    return _Section(
      title: 'Batch Selection',
      icon: Icons.inventory_2_rounded,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 320,
            child: DropdownButtonFormField<String>(
              initialValue: selectedBatchName,
              isExpanded: true,
              items: batchOptions.isEmpty
                  ? [
                      const DropdownMenuItem(
                        value: 'Kharif Batch 1',
                        child: Text('Kharif Batch 1'),
                      )
                    ]
                  : batchOptions.map((option) {
                      return DropdownMenuItem<String>(
                        value: option['value']?.toString(),
                        child: Text(option['label']?.toString() ?? 'Batch'),
                      );
                    }).toList(),
              onChanged: (value) => setState(() => selectedBatchName = value),
              decoration: const InputDecoration(
                labelText: 'Select Payment Batch',
                prefixIcon: Icon(Icons.inventory_rounded),
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _paymentDateController,
              decoration: const InputDecoration(
                labelText: 'Payment Date',
                prefixIcon: Icon(Icons.event_rounded),
              ),
            ),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: _schemeController,
              decoration: const InputDecoration(
                labelText: 'Scheme',
                prefixIcon: Icon(Icons.account_tree_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTdsStep(List<JsonMap> tdsRows) {
    return _Section(
      title: 'Automatic TDS',
      icon: Icons.percent_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rule: Previous FY Incentive + Current Upload >= Rs 100,000.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: tdsMode,
                  decoration:
                      const InputDecoration(labelText: 'TDS Percentage'),
                  items: [
                    DropdownMenuItem(
                      value: 'default',
                      child: Text(
                          'Default (${_selectedTdsRate.toStringAsFixed(2)}%)'),
                    ),
                    const DropdownMenuItem(value: '1', child: Text('1%')),
                    const DropdownMenuItem(value: '2', child: Text('2%')),
                    const DropdownMenuItem(value: '5', child: Text('5%')),
                    const DropdownMenuItem(
                        value: 'custom', child: Text('Custom')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      tdsMode = value ?? 'default';
                      _recalculateTds();
                    });
                  },
                ),
              ),
              if (tdsMode == 'custom')
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _customTdsController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Custom %'),
                    onChanged: (_) => setState(_recalculateTds),
                  ),
                ),
              _SummaryChip(label: 'TDS Farmers', value: '${tdsRows.length}'),
              _SummaryChip(label: 'TDS Total', value: _money(_totals.tds)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProcessStep(_Totals totals) {
    return _Section(
      title: 'Final Summary',
      icon: Icons.summarize_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryChip(
                  label: 'Total Uploaded',
                  value: '${summary['totalRecords'] ?? uploadedRows.length}'),
              _SummaryChip(
                  label: 'Existing Farmers',
                  value:
                      '${mappedFarmers.where((row) => row['source'] != 'NEW').length}'),
              _SummaryChip(
                  label: 'Newly Created',
                  value: '${newlyCreatedFarmerIds.length}'),
              _SummaryChip(
                  label: 'Missing Farmers', value: '${missingFarmers.length}'),
              _SummaryChip(
                  label: 'Invalid Rows',
                  value: '${invalidRows.length + duplicateRows.length}'),
              _SummaryChip(label: 'Gross Amount', value: _money(totals.gross)),
              _SummaryChip(label: 'Total TDS', value: _money(totals.tds)),
              _SummaryChip(label: 'Net Payable', value: _money(totals.net)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: isLoading ? null : _processPayments,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Process Payments'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportsStep(_Totals totals, List<JsonMap> tdsRows) {
    return _Section(
      title: 'Reports and Notifications',
      icon: Icons.assignment_turned_in_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (processingResult == null)
            const Text('Process payments to generate the final report set.')
          else
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payments processed',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                        'Batch: ${processingResult?['batch']?['batchNumber'] ?? selectedBatchName}'),
                    Text(
                        'Payments: ${processingResult?['totalFarmers'] ?? mappedFarmers.length}'),
                    Text(
                        'Net Amount: ${_money(processingResult?['totalNetAmount'] ?? totals.net)}'),
                    const SizedBox(height: 8),
                    const Text(
                      'Notifications will be sent using configured SMS/WhatsApp templates.',
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed:
                    mappedFarmers.isEmpty ? null : _downloadPreviewReport,
                icon: const Icon(Icons.assessment_rounded),
                label: const Text('Payment Report'),
              ),
              OutlinedButton.icon(
                onPressed: mappedFarmers.isEmpty ? null : _downloadBankFile,
                icon: const Icon(Icons.account_balance_rounded),
                label: const Text('Bank File'),
              ),
              OutlinedButton.icon(
                onPressed: tdsRows.isEmpty ? null : _downloadTdsReport,
                icon: const Icon(Icons.percent_rounded),
                label: const Text('TDS Report'),
              ),
              OutlinedButton.icon(
                onPressed: invalidRows.isEmpty &&
                        duplicateRows.isEmpty &&
                        missingFarmers.isEmpty
                    ? null
                    : _downloadFailedRecordsReport,
                icon: const Icon(Icons.error_outline_rounded),
                label: const Text('Failed Records Report'),
              ),
              OutlinedButton.icon(
                onPressed:
                    processingResult == null ? null : _downloadAuditReport,
                icon: const Icon(Icons.history_rounded),
                label: const Text('Audit Report'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _Totals get _totals {
    return _Totals(
      gross:
          mappedFarmers.fold(0, (sum, row) => sum + _num(row['grossAmount'])),
      tds: mappedFarmers.fold(0, (sum, row) => sum + _num(row['tdsAmount'])),
      net: mappedFarmers.fold(0, (sum, row) => sum + _num(row['netAmount'])),
    );
  }

  Uint8List _asBytes(dynamic value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return Uint8List.fromList(utf8.encode(value.toString()));
  }

  JsonMap _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  List<JsonMap> _extractRows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((row) => _asMap(row)).toList();
    }
    if (value is Map) {
      final map = _asMap(value);
      if (map['data'] is List) return _extractRows(map['data']);
      if (map['rows'] is List) return _extractRows(map['rows']);
    }
    return [];
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _roundMoney(double value) => (value * 100).roundToDouble() / 100;

  String _money(dynamic value) => 'Rs ${_num(value).toStringAsFixed(2)}';

  String _bankDetails(JsonMap row) {
    final parts = [
      row['bankName'],
      row['branchName'],
      row['ifscCode'],
      row['accountNumber'],
    ]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .map((value) => value.toString())
        .toList();
    return parts.isEmpty ? '-' : parts.join(' | ');
  }
}

typedef JsonMap = Map<String, dynamic>;

class _Totals {
  final double gross;
  final double tds;
  final double net;

  const _Totals({
    required this.gross,
    required this.tds,
    required this.net,
  });
}

class _HeroPanel extends StatelessWidget {
  final int totalMapped;
  final int missing;
  final int invalid;
  final double netPayable;

  const _HeroPanel({
    required this.totalMapped,
    required this.missing,
    required this.invalid,
    required this.netPayable,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 18,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Processing Wizard',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                      'Map farmers, calculate TDS, process payments, and generate reports.'),
                ],
              ),
            ),
            _SummaryChip(label: 'Mapped', value: '$totalMapped'),
            _SummaryChip(label: 'Missing', value: '$missing'),
            _SummaryChip(label: 'Invalid', value: '$invalid'),
            _SummaryChip(
                label: 'Net Payable',
                value: 'Rs ${netPayable.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageCard({
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: isError ? colors.errorContainer : colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color:
                isError ? colors.onErrorContainer : colors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _IssueList extends StatelessWidget {
  final List<JsonMap> rows;

  const _IssueList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows
          .map(
            (row) => ListTile(
              dense: true,
              leading: const Icon(Icons.error_outline_rounded),
              title: Text(row['message']?.toString() ?? 'Invalid row'),
              subtitle: Text(
                'Row ${row['row'] ?? '-'}'
                '${row['field'] == null ? '' : ' | ${row['field']}'}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SmallRows extends StatelessWidget {
  final List<JsonMap> rows;
  final List<String> columns;

  const _SmallRows({
    required this.rows,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns
            .map((column) => DataColumn(label: Text(_title(column))))
            .toList(),
        rows: rows
            .map(
              (row) => DataRow(
                cells: columns
                    .map((column) =>
                        DataCell(Text(row[column]?.toString() ?? '')))
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }

  String _title(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .trim()
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

extension _FinancialYearLookup on List<JsonMap> {
  String? get activeOrFirstId {
    if (isEmpty) return null;
    for (final row in this) {
      if (row['isActive'] == true) return row['id']?.toString();
    }
    return first['id']?.toString();
  }
}
