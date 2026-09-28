class Profile {
  const Profile({
    required this.name,
    required this.level,
    this.onboardingComplete = false,
  });

  final String name;
  final String level; // 'A1' | 'A2' | 'B1' | 'B2'
  final bool onboardingComplete;

  static const empty = Profile(name: '', level: 'A1', onboardingComplete: false);

  Profile copyWith({String? name, String? level, bool? onboardingComplete}) => Profile(
        name: name ?? this.name,
        level: level ?? this.level,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'level': level,
        'onboardingComplete': onboardingComplete,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String,
        level: json['level'] as String,
        onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      );
}
