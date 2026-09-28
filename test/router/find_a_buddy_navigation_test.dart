// test/router/find_a_buddy_navigation_test.dart
//
// Regression test for: Home -> Find a Buddy (and Find a Buddy -> Buddy Chat)
// used context.go(), which replaces the current location instead of pushing
// onto the Navigator stack. On a real Android/iOS device that leaves the
// user stuck with no back button and no way back except killing the app.
// This test exercises the real router (buildRouter()) so a future
// regression back to .go() fails here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/profile_repository.dart';
import 'package:study_budy/data/progress_repository.dart';
import 'package:study_budy/router/app_router.dart';
import 'package:study_budy/state/profile_provider.dart';
import 'package:study_budy/state/progress_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Find a Buddy is pushed, not replaced - a back button appears', (tester) async {
    final profileProvider = ProfileProvider(ProfileRepository());
    await profileProvider.load();
    final progressProvider = ProgressProvider(ProgressRepository());
    await progressProvider.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: profileProvider),
          ChangeNotifierProvider.value(value: progressProvider),
        ],
        child: MaterialApp.router(routerConfig: buildRouter(profileProvider)),
      ),
    );
    await tester.pumpAndSettle();

    // Complete onboarding to reach Home.
    await tester.enterText(find.byKey(const Key('onboarding_name')), 'Daryn');
    await tester.tap(find.byKey(const Key('onboarding_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.text('Find a Buddy'));
    await tester.pumpAndSettle();

    expect(find.text('Find a Buddy'), findsWidgets);
    expect(Navigator.canPop(tester.element(find.byType(Scaffold).last)), isTrue);
    expect(find.byTooltip('Back'), findsOneWidget);
  });
}
