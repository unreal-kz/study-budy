class CommunityGroup {
  const CommunityGroup({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.description,
  });

  final String id;
  final String name;
  final int memberCount;
  final String description;

  factory CommunityGroup.fromJson(Map<String, dynamic> json) => CommunityGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        memberCount: json['memberCount'] as int,
        description: json['description'] as String,
      );
}
