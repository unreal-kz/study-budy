import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/data/seed_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadBuddies() parses all seeded buddies', () async {
    final buddies = await SeedRepository().loadBuddies();
    expect(buddies, hasLength(5));
    expect(buddies.first.name, 'Kausar');
    expect(buddies.first.interests, contains('Movies'));
  });

  test('loadCommunityGroups() parses all seeded groups', () async {
    final groups = await SeedRepository().loadCommunityGroups();
    expect(groups, hasLength(5));
    expect(groups.map((g) => g.id), contains('speaking-club'));
  });

  test('loadBuddyChatDemo() parses the seeded conversation', () async {
    final demo = await SeedRepository().loadBuddyChatDemo();
    expect(demo, isNotEmpty);
    expect(demo.first.sender, 'buddy');
  });
}
