class Buddy {
  const Buddy({
    required this.id,
    required this.name,
    required this.level,
    required this.city,
    required this.interests,
  });

  final String id;
  final String name;
  final String level;
  final String city;
  final List<String> interests;

  factory Buddy.fromJson(Map<String, dynamic> json) => Buddy(
        id: json['id'] as String,
        name: json['name'] as String,
        level: json['level'] as String,
        city: json['city'] as String,
        interests: (json['interests'] as List).cast<String>(),
      );
}
