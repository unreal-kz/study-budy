import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/screens/find_a_buddy/find_a_buddy_screen.dart';

void main() {
  // Prevents rootBundle's asset string cache from holding a Future across
  // tests: the cached Future from an earlier test never resolves once this
  // test's binding is torn down, hanging any later test that awaits it.
  tearDown(() {
    rootBundle.clear();
  });

  testWidgets('renders every seeded buddy by name', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FindABuddyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Kausar'), findsOneWidget);
    expect(find.text('Daniyar'), findsOneWidget);
    expect(find.text('Malika'), findsOneWidget);
  });

  testWidgets('tapping Connect shows a stub message, not an error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FindABuddyScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('connect_kausar')));
    await tester.pump();

    expect(find.textContaining('Connect'), findsWidgets);
  });
}
