class ReportMetric {
  final String label;
  final String value;
  const ReportMetric({required this.label, required this.value});
}

class ReportSection {
  final String title;
  final List<Map<String, dynamic>> rows;
  const ReportSection({required this.title, required this.rows});
}

class ReportViewModel {
  final String title;
  final List<ReportMetric> metrics;
  final List<ReportSection> sections;
  final List<Map<String, dynamic>> exportRows;

  const ReportViewModel({
    required this.title,
    required this.metrics,
    required this.sections,
    required this.exportRows,
  });
}

ReportViewModel buildReportViewModel(dynamic payload) {
  if (payload is Map<String, dynamic>) {
    final map = Map<String, dynamic>.from(payload);
    final title = (map['title'] ?? map['financialYear']?['yearLabel'] ?? 'Report').toString();

    final metrics = <ReportMetric>[];
    if (map['financialYear'] is Map) {
      final fy = Map<String, dynamic>.from(map['financialYear'] as Map);
      metrics.add(ReportMetric(label: 'Financial Year', value: fy['yearLabel']?.toString() ?? '-'));
    }

    if (map['totals'] is Map) {
      final totals = Map<String, dynamic>.from(map['totals'] as Map);
      metrics.add(ReportMetric(label: 'Total Payments', value: totals['totalPayments']?.toString() ?? '0'));
      metrics.add(ReportMetric(label: 'Gross Amount', value: '₹${totals['totalGross']?.toString() ?? '0'}'));
      metrics.add(ReportMetric(label: 'TDS Amount', value: '₹${totals['totalTds']?.toString() ?? '0'}'));
      metrics.add(ReportMetric(label: 'Net Amount', value: '₹${totals['totalNet']?.toString() ?? '0'}'));
      metrics.add(ReportMetric(label: 'Unique Farmers', value: totals['uniqueFarmers']?.toString() ?? '0'));
    }

    final sections = <ReportSection>[];
    if (map['batches'] is List && (map['batches'] as List).isNotEmpty) {
      sections.add(ReportSection(
        title: 'Batches',
        rows: (map['batches'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      ));
    }
    if (map['payments'] is List && (map['payments'] as List).isNotEmpty) {
      sections.add(ReportSection(
        title: 'Payments',
        rows: (map['payments'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      ));
    }
    if (map['tdsRecords'] is List && (map['tdsRecords'] as List).isNotEmpty) {
      sections.add(ReportSection(
        title: 'TDS Records',
        rows: (map['tdsRecords'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      ));
    }
    if (map['records'] is List && (map['records'] as List).isNotEmpty) {
      sections.add(ReportSection(
        title: 'Records',
        rows: (map['records'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      ));
    }

    if (sections.isEmpty) {
      sections.add(ReportSection(title: 'Data', rows: [map]));
    }

    return ReportViewModel(
      title: title,
      metrics: metrics,
      sections: sections,
      exportRows: sections.expand((section) => section.rows).toList(),
    );
  }

  if (payload is List) {
    final rows = payload
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    return ReportViewModel(
      title: 'Report',
      metrics: const [],
      sections: [ReportSection(title: 'Rows', rows: rows)],
      exportRows: rows,
    );
  }

  return const ReportViewModel(
    title: 'Report',
    metrics: [],
    sections: [],
    exportRows: [],
  );
}
