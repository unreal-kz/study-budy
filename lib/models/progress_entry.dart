class ProgressEntry {
  const ProgressEntry({
    required this.date,
    this.speakingTimeSeconds = 0,
    this.challengesCompleted = 0,
    this.newWords = 0,
  });

  final String date; // 'yyyy-MM-dd'
  final int speakingTimeSeconds;
  final int challengesCompleted;
  final int newWords;

  ProgressEntry copyWith({
    int? speakingTimeSeconds,
    int? challengesCompleted,
    int? newWords,
  }) =>
      ProgressEntry(
        date: date,
        speakingTimeSeconds: speakingTimeSeconds ?? this.speakingTimeSeconds,
        challengesCompleted: challengesCompleted ?? this.challengesCompleted,
        newWords: newWords ?? this.newWords,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'speakingTimeSeconds': speakingTimeSeconds,
        'challengesCompleted': challengesCompleted,
        'newWords': newWords,
      };

  factory ProgressEntry.fromJson(Map<String, dynamic> json) => ProgressEntry(
        date: json['date'] as String,
        speakingTimeSeconds: json['speakingTimeSeconds'] as int? ?? 0,
        challengesCompleted: json['challengesCompleted'] as int? ?? 0,
        newWords: json['newWords'] as int? ?? 0,
      );
}
