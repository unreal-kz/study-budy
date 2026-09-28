import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/profile_repository.dart';
import 'package:study_budy/models/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load() returns Profile.empty when nothing saved', () async {
    final repo = ProfileRepository();
    final profile = await repo.load();
    expect(profile.onboardingComplete, false);
  });

  test('save() then load() round-trips the profile', () async {
    final repo = ProfileRepository();
    await repo.save(const Profile(name: 'Daryn', level: 'B1', onboardingComplete: true));
    final profile = await repo.load();
    expect(profile.name, 'Daryn');
    expect(profile.level, 'B1');
    expect(profile.onboardingComplete, true);
  });

  test('load() falls back to Profile.empty when stored data is corrupted', () async {
    SharedPreferences.setMockInitialValues({'profile': 'not valid json'});
    final repo = ProfileRepository();
    final profile = await repo.load();
    expect(profile.onboardingComplete, false);
    expect(profile.name, '');
  });
}
