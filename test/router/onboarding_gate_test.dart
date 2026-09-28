// test/router/onboarding_gate_test.dart
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

  testWidgets('redirects to onboarding when profile is not onboarded', (tester) async {
    final profileProvider = ProfileProvider(ProfileRepository());
    await profileProvider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: profileProvider,
        child: MaterialApp.router(routerConfig: buildRouter(profileProvider)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Study Buddy'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_name')), findsOneWidget);
  });

  testWidgets('shows Home once onboarding completes', (tester) async {
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

    await tester.enterText(find.byKey(const Key('onboarding_name')), 'Daryn');
    await tester.tap(find.byKey(const Key('onboarding_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
  });
}
