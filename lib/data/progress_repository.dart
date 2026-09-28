import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress_entry.dart';

class ProgressRepository {
  static const _key = 'progress_daily';

  Future<List<ProgressEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    return raw
        .map((s) => ProgressEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> recordSession({
    required String date,
    int speakingTimeSeconds = 0,
    int challengesCompleted = 0,
    int newWords = 0,
  }) async {
    final entries = await loadAll();
    final index = entries.indexWhere((e) => e.date == date);
    if (index == -1) {
      entries.add(ProgressEntry(
        date: date,
        speakingTimeSeconds: speakingTimeSeconds,
        challengesCompleted: challengesCompleted,
        newWords: newWords,
      ));
    } else {
      final existing = entries[index];
      entries[index] = existing.copyWith(
        speakingTimeSeconds: existing.speakingTimeSeconds + speakingTimeSeconds,
        challengesCompleted: existing.challengesCompleted + challengesCompleted,
        newWords: existing.newWords + newWords,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// Consecutive days of activity ending today (0 if today has no entry).
  Future<int> currentStreak({DateTime? today}) async {
    final entries = await loadAll();
    final byDate = {for (final e in entries) e.date: e};
    var cursor = _dateOnly(today ?? DateTime.now());
    var streak = 0;
    while (byDate.containsKey(_formatDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
