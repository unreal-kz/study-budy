import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/progress_repository.dart';
import 'package:study_budy/state/progress_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('recordSession updates entries and streak', () async {
    final provider = ProgressProvider(ProgressRepository());
    await provider.load();
    expect(provider.entries, isEmpty);

    await provider.recordSession(speakingTimeSeconds: 30, newWords: 1);
    expect(provider.entries, hasLength(1));
    expect(provider.streak, 1);
  });
}
