import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/profile_repository.dart';
import 'package:study_budy/state/profile_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('completeOnboarding updates profile and persists it', () async {
    final provider = ProfileProvider(ProfileRepository());
    await provider.load();
    expect(provider.profile.onboardingComplete, false);

    await provider.completeOnboarding(name: 'Daryn', level: 'B1');
    expect(provider.profile.onboardingComplete, true);
    expect(provider.profile.name, 'Daryn');

    final reloaded = ProfileProvider(ProfileRepository());
    await reloaded.load();
    expect(reloaded.profile.name, 'Daryn');
  });
}
