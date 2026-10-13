// test/screens/onboarding_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/profile_repository.dart';
import 'package:study_budy/screens/onboarding/onboarding_screen.dart';
import 'package:study_budy/state/profile_provider.dart';
import 'package:study_budy/widgets/brand_logo.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('header shows the brand logo, not the SB placeholder tile', (tester) async {
    final profileProvider = ProfileProvider(ProfileRepository());
    await profileProvider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: profileProvider,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );

    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('SB'), findsNothing);
    expect(find.text('Study Buddy'), findsOneWidget);
  });
}
