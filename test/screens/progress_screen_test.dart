import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/progress_repository.dart';
import 'package:study_budy/screens/progress/progress_screen.dart';
import 'package:study_budy/state/progress_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders streak and recorded sessions', (tester) async {
    final provider = ProgressProvider(ProgressRepository());
    await provider.load();
    await provider.recordSession(speakingTimeSeconds: 90, newWords: 4, challengesCompleted: 1);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ProgressScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1-day streak'), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets); // new words shown somewhere
  });
}
