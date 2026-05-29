import 'package:flutter_test/flutter_test.dart';

import 'package:lw006_flutter/main.dart';

void main() {
  testWidgets('App launches scan page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('DEVICE('), findsOneWidget);
  });
}
