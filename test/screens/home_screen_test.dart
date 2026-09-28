import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/challenges.dart';
import 'package:study_budy/data/progress_repository.dart';
import 'package:study_budy/screens/home/home_screen.dart';
import 'package:study_budy/state/progress_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('challengeForDate is stable for the same date', () {
    final date = DateTime(2026, 9, 28);
    expect(challengeForDate(date), challengeForDate(date));
  });

  testWidgets('renders streak and today\'s challenge', (tester) async {
    final progressProvider = ProgressProvider(ProgressRepository());
    await progressProvider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: progressProvider,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('0-day streak'), findsOneWidget);
    expect(find.text(challengeForDate(DateTime.now())), findsOneWidget);
  });
}
