import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';

final paymentUploadControllerProvider = StateNotifierProvider<PaymentUploadController, PaymentUploadState>((ref) {
  return PaymentUploadController(ref);
});

class PaymentUploadState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? uploadResult;
  final List<dynamic> previewRows;
  final Map<String, dynamic>? summary;
  final String? selectedFinancialYearId;

  const PaymentUploadState({
    this.isLoading = false,
    this.error,
    this.uploadResult,
    this.previewRows = const [],
    this.summary,
    this.selectedFinancialYearId,
  });

  PaymentUploadState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? uploadResult,
    List<dynamic>? previewRows,
    Map<String, dynamic>? summary,
    String? selectedFinancialYearId,
  }) {
    return PaymentUploadState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      uploadResult: uploadResult ?? this.uploadResult,
      previewRows: previewRows ?? this.previewRows,
      summary: summary ?? this.summary,
      selectedFinancialYearId: selectedFinancialYearId ?? this.selectedFinancialYearId,
    );
  }
}

class PaymentUploadController extends StateNotifier<PaymentUploadState> {
  PaymentUploadController(this.ref) : super(const PaymentUploadState());

  final Ref ref;
  final DioClient _client = DioClient();

  Future<void> pickAndUploadFile() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final filePath = result.files.single.path!;
      final response = await _client.uploadFile(
        ApiEndpoints.paymentsUpload,
        filePath: filePath,
        extraFields: {'financialYearId': state.selectedFinancialYearId ?? 'demo-fy'},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        state = state.copyWith(
          isLoading: false,
          uploadResult: data,
          previewRows: data['preview']?['results'] ?? [],
          summary: data['parsed']?['summary'] ?? {},
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['message'] ?? 'Upload failed',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFinancialYear(String? value) {
    state = state.copyWith(selectedFinancialYearId: value);
  }

  Future<void> downloadSampleInput() async {
    final response = await _client.get(ApiEndpoints.paymentsUpload.replaceFirst('/upload', '/sample-excel'));
    if (response.statusCode == 200) {
      // Browser download is handled by the backend endpoint in web; for mobile this can be saved locally.
      // The current screen shows the action as available and leaves the file handling to the platform integration.
      return;
    }
  }

  Future<void> downloadSampleOutput() async {
    final response = await _client.get(ApiEndpoints.paymentsUpload.replaceFirst('/upload', '/sample-output'));
    if (response.statusCode == 200) {
      return;
    }
  }
}

class PaymentUploadScreen extends ConsumerWidget {
  const PaymentUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentUploadControllerProvider);
    final controller = ref.read(paymentUploadControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Excel Import & Payment Preview'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import farmers from Excel and review payment preview',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upload Excel file', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Financial Year ID',
                        hintText: 'Use the existing financial year ID from the backend',
                      ),
                      onChanged: controller.setFinancialYear,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: state.isLoading ? null : controller.pickAndUploadFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Excel'),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.isLoading ? null : controller.downloadSampleInput,
                          icon: const Icon(Icons.download),
                          label: const Text('Download Sample Input'),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.isLoading ? null : controller.downloadSampleOutput,
                          icon: const Icon(Icons.download_done),
                          label: const Text('Download Sample Output'),
                        ),
                      ],
                    ),
                    if (state.isLoading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (state.error != null) ...[
                      const SizedBox(height: 12),
                      Text(state.error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (state.summary != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Import Summary', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _SummaryChip(label: 'Total', value: '${state.summary!['totalRecords'] ?? 0}'),
                          _SummaryChip(label: 'Imported', value: '${state.summary!['successfullyValidated'] ?? 0}'),
                          _SummaryChip(label: 'Failed', value: '${state.summary!['failedRecords'] ?? 0}'),
                          _SummaryChip(label: 'Duplicate Farmer IDs', value: '${state.summary!['duplicateFarmerIds'] ?? 0}'),
                          _SummaryChip(label: 'Duplicate Mobile Numbers', value: '${state.summary!['duplicateMobileNumbers'] ?? 0}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (state.previewRows.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment Preview', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Farmer ID')),
                              DataColumn(label: Text('Farmer Name')),
                              DataColumn(label: Text('Village')),
                              DataColumn(label: Text('Bank')),
                              DataColumn(label: Text('IFSC')),
                              DataColumn(label: Text('Account Number')),
                              DataColumn(label: Text('Gross')),
                              DataColumn(label: Text('TDS')),
                              DataColumn(label: Text('Net')),
                            ],
                            rows: state.previewRows.map((row) {
                              final item = row as Map<String, dynamic>;
                              return DataRow(cells: [
                                DataCell(Text(item['farmerId']?.toString() ?? '')),
                                DataCell(Text(item['farmerName']?.toString() ?? '')),
                                DataCell(Text(item['village']?.toString() ?? '')),
                                DataCell(Text(item['bankName']?.toString() ?? '')),
                                DataCell(Text(item['ifscCode']?.toString() ?? '')),
                                DataCell(Text(item['accountNumber']?.toString() ?? '')),
                                DataCell(Text(item['grossAmount']?.toString() ?? '')),
                                DataCell(Text(item['tdsAmount']?.toString() ?? '')),
                                DataCell(Text(item['netAmount']?.toString() ?? '')),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
