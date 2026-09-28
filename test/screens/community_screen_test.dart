import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/screens/community/community_screen.dart';

void main() {
  testWidgets('renders every seeded community group', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Movies & TV Shows'), findsOneWidget);
    expect(find.text('Speaking Club'), findsOneWidget);
  });
}
