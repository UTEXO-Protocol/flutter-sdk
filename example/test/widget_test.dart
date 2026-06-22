import 'package:flutter_test/flutter_test.dart';

import 'package:rgb_sdk_flutter_example/main.dart';

void main() {
  testWidgets('renders native artifact status surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('RGB SDK Flutter'), findsOneWidget);
    expect(find.textContaining('Native artifact:'), findsOneWidget);
  });
}
