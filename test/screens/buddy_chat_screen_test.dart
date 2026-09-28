import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/screens/find_a_buddy/buddy_chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the seeded demo conversation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BuddyChatScreen(buddyId: 'kausar')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('How was your day?'), findsOneWidget);
  });
}
