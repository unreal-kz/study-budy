import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/progress_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('recordSession creates a new entry for a new date', () async {
    final repo = ProgressRepository();
    await repo.recordSession(date: '2026-09-28', newWords: 2);
    final entries = await repo.loadAll();
    expect(entries, hasLength(1));
    expect(entries.first.newWords, 2);
  });

  test('recordSession accumulates onto the same date', () async {
    final repo = ProgressRepository();
    await repo.recordSession(date: '2026-09-28', newWords: 2);
    await repo.recordSession(date: '2026-09-28', newWords: 3);
    final entries = await repo.loadAll();
    expect(entries, hasLength(1));
    expect(entries.first.newWords, 5);
  });

  test('currentStreak is 0 when today has no entry', () async {
    final repo = ProgressRepository();
    await repo.recordSession(date: '2026-09-20', newWords: 1);
    final streak = await repo.currentStreak(today: DateTime(2026, 9, 28));
    expect(streak, 0);
  });

  test('currentStreak counts consecutive days ending today', () async {
    final repo = ProgressRepository();
    await repo.recordSession(date: '2026-09-26', newWords: 1);
    await repo.recordSession(date: '2026-09-27', newWords: 1);
    await repo.recordSession(date: '2026-09-28', newWords: 1);
    final streak = await repo.currentStreak(today: DateTime(2026, 9, 28));
    expect(streak, 3);
  });

  test('currentStreak stops at a gap and does not overcount across it', () async {
    final repo = ProgressRepository();
    await repo.recordSession(date: '2026-09-24', newWords: 1); // gap here
    await repo.recordSession(date: '2026-09-27', newWords: 1);
    await repo.recordSession(date: '2026-09-28', newWords: 1);
    final streak = await repo.currentStreak(today: DateTime(2026, 9, 28));
    expect(streak, 2); // only the 27th and 28th, the 24th is across the gap
  });
}
