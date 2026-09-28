import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/models/progress_entry.dart';

void main() {
  test('ProgressEntry round-trips through JSON', () {
    const entry = ProgressEntry(
      date: '2026-09-28',
      speakingTimeSeconds: 120,
      challengesCompleted: 1,
      newWords: 3,
    );
    final restored = ProgressEntry.fromJson(entry.toJson());
    expect(restored.date, '2026-09-28');
    expect(restored.speakingTimeSeconds, 120);
    expect(restored.newWords, 3);
  });

  test('copyWith adds to existing counts when given new values', () {
    const entry = ProgressEntry(date: '2026-09-28', newWords: 2);
    final updated = entry.copyWith(newWords: 5);
    expect(updated.newWords, 5);
    expect(updated.date, '2026-09-28');
  });
}
