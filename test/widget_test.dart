import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ride_sharing_app/features/auth/presentation/auth_landing_page.dart';

void main() {
  testWidgets('Auth landing screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthLandingPage()));

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('I am a Customer'), findsOneWidget);
    expect(find.text('I am a Rider'), findsOneWidget);
  });
}
