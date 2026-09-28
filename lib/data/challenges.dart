const List<String> dailyChallenges = [
  'Speak for 60 seconds about your weekend.',
  'Describe your favorite meal to a friend.',
  'Explain why you are learning English.',
  'Talk about a movie you watched recently.',
  'Describe your hometown to a visitor.',
  'Talk about your plans for next week.',
  'Explain how to make your favorite dish.',
];

String challengeForDate(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
  return dailyChallenges[dayOfYear % dailyChallenges.length];
}
