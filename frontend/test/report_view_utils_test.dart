import 'package:flutter_test/flutter_test.dart';
import 'package:fims_frontend/features/admin/utils/report_view_utils.dart';

void main() {
  group('buildReportViewModel', () {
    test('builds sections and metrics from a financial year payload', () {
      final model = buildReportViewModel({
        'financialYear': {'yearLabel': '2024-25'},
        'totals': {
          'totalPayments': 3,
          'totalGross': 15000,
        },
        'batches': [
          {'batchNumber': 'B1', 'status': 'PAID'},
        ],
      });

      expect(model.metrics.any((metric) => metric.label == 'Financial Year'), isTrue);
      expect(model.metrics.any((metric) => metric.label == 'Total Payments'), isTrue);
      expect(model.sections.length, 1);
      expect(model.sections.first.title, 'Batches');
      expect(model.sections.first.rows.length, 1);
    });

    test('normalizes a simple list payload into one section', () {
      final model = buildReportViewModel([
        {'farmerId': 'F1', 'name': 'Asha'},
      ]);

      expect(model.sections.length, 1);
      expect(model.sections.first.rows.length, 1);
      expect(model.sections.first.rows.first['farmerId'], 'F1');
    });
  });
}
