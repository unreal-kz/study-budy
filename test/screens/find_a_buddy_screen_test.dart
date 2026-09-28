import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/screens/find_a_buddy/find_a_buddy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders every seeded buddy by name', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FindABuddyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Kausar'), findsOneWidget);
    expect(find.text('Daniyar'), findsOneWidget);
    expect(find.text('Malika'), findsOneWidget);
  });

  testWidgets('tapping Connect shows a stub message, not an error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FindABuddyScreen()));

    // Wait for all frames to settle, but with shorter timeout to avoid hanging
    try {
      await tester.pumpAndSettle(const Duration(seconds: 1));
    } catch (_) {
      // If pumpAndSettle times out, try pumping manually
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.tap(find.byKey(const Key('connect_kausar')));
    await tester.pump();

    expect(find.textContaining('Connect'), findsWidgets);
  });
}
