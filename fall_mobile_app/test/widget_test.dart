import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fall_mobile_app/main.dart';

void main() {
  testWidgets('Fall detection app loads successfully', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FallSenseApp());

    // Verify app loads
    expect(find.byType(FallSenseApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
