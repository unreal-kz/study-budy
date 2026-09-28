import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/models/profile.dart';

void main() {
  test('Profile round-trips through JSON', () {
    const profile = Profile(name: 'Daryn', level: 'B1', onboardingComplete: true);
    final restored = Profile.fromJson(profile.toJson());
    expect(restored.name, 'Daryn');
    expect(restored.level, 'B1');
    expect(restored.onboardingComplete, true);
  });

  test('Profile.empty has onboardingComplete false', () {
    expect(Profile.empty.onboardingComplete, false);
  });
}
