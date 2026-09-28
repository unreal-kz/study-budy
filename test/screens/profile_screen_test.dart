// test/screens/profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/profile_repository.dart';
import 'package:study_budy/screens/profile/profile_screen.dart';
import 'package:study_budy/state/profile_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders the profile name and level', (tester) async {
    final provider = ProfileProvider(ProfileRepository());
    await provider.load();
    await provider.completeOnboarding(name: 'Daryn', level: 'B1');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daryn'), findsOneWidget);
    expect(find.textContaining('B1'), findsOneWidget);
  });
}
