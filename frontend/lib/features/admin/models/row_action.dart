import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef JsonMap = Map<String, dynamic>;

class RowAction {
  final String label;
  final IconData icon;

  final Future<void> Function(
    BuildContext context,
    WidgetRef ref,
    JsonMap row,
  ) onPressed;

  const RowAction(
    this.label,
    this.icon,
    this.onPressed,
  );
}
