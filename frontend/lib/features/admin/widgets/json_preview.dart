import 'package:flutter/material.dart';

typedef JsonMap = Map<String, dynamic>;

class JsonPreview extends StatelessWidget {
  final JsonMap value;

  const JsonPreview({
    super.key,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      value.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n'),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}