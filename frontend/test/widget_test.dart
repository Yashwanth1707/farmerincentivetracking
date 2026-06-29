import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fims_frontend/app.dart';

void main() {
  testWidgets('FIMS App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FimsApp(),
      ),
    );

    // Verify the app starts at the login page
    expect(find.text('Login'), findsOneWidget);
  });
}
