import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fims_frontend/features/farmers/farmers_screen.dart';

void main() {
  testWidgets('viewer role hides farmer management actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FarmersScreen(initialRole: 'VIEWER'),
      ),
    );

    expect(find.text('Add Farmer'), findsNothing);
  });

  testWidgets('admin role shows farmer management actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FarmersScreen(initialRole: 'ADMIN'),
      ),
    );

    expect(find.text('Add Farmer'), findsOneWidget);
  });
}
