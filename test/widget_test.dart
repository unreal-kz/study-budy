// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:study_budy/main.dart';
import 'package:study_budy/state/progress_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App loads and shows onboarding when not onboarded', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StudyBudyApp());
    await tester.pumpAndSettle();

    // Verify that the onboarding screen is shown
    expect(find.text('Welcome to Study Buddy'), findsOneWidget);
  });

  testWidgets('progress updates do not reset navigation to Home', (WidgetTester tester) async {
    await tester.pumpWidget(const StudyBudyApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('onboarding_name')), 'Daryn');
    await tester.tap(find.byKey(const Key('onboarding_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    expect(find.text('Community'), findsWidgets);

    final progressProvider = Provider.of<ProgressProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    await progressProvider.recordSession(newWords: 1);
    await tester.pumpAndSettle();

    expect(find.text('Community'), findsWidgets);
  });
}
