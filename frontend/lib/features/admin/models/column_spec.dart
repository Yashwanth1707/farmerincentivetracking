class ColumnSpec {
  final String field;
  final String label;
  final bool status;
  final bool currency;
  final bool date;

  const ColumnSpec(
    this.field,
    this.label, {
    this.status = false,
    this.currency = false,
    this.date = false,
  });
}
