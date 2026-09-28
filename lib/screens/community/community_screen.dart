import 'package:flutter/material.dart';

import '../../data/seed_repository.dart';
import '../../models/community_group.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late Future<List<CommunityGroup>> _groups;

  @override
  void initState() {
    super.initState();
    _groups = SeedRepository().loadCommunityGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: FutureBuilder<List<CommunityGroup>>(
        future: _groups,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final groups = snapshot.data!;
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                title: Text(group.name),
                subtitle: Text('${group.memberCount} members · ${group.description}'),
              );
            },
          );
        },
      ),
    );
  }
}
