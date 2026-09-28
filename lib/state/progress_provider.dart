import 'package:flutter/foundation.dart';

import '../data/progress_repository.dart';
import '../models/progress_entry.dart';

class ProgressProvider extends ChangeNotifier {
  ProgressProvider(this._repository);

  final ProgressRepository _repository;
  List<ProgressEntry> _entries = const [];
  int _streak = 0;

  List<ProgressEntry> get entries => _entries;
  int get streak => _streak;

  Future<void> load() async {
    _entries = await _repository.loadAll();
    _streak = await _repository.currentStreak();
    notifyListeners();
  }

  Future<void> recordSession({
    int speakingTimeSeconds = 0,
    int challengesCompleted = 0,
    int newWords = 0,
  }) async {
    await _repository.recordSession(
      date: _todayString(),
      speakingTimeSeconds: speakingTimeSeconds,
      challengesCompleted: challengesCompleted,
      newWords: newWords,
    );
    await load();
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
