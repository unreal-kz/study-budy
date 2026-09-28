import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/seed_repository.dart';
import '../../models/buddy.dart';

class FindABuddyScreen extends StatefulWidget {
  const FindABuddyScreen({super.key});

  @override
  State<FindABuddyScreen> createState() => _FindABuddyScreenState();
}

class _FindABuddyScreenState extends State<FindABuddyScreen> {
  late Future<List<Buddy>> _buddies;

  @override
  void initState() {
    super.initState();
    _buddies = SeedRepository().loadBuddies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a Buddy')),
      body: FutureBuilder<List<Buddy>>(
        future: _buddies,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final buddies = snapshot.data!;
          return ListView.builder(
            itemCount: buddies.length,
            itemBuilder: (context, index) {
              final buddy = buddies[index];
              return ListTile(
                title: Text(buddy.name),
                subtitle: Text('${buddy.level} · ${buddy.city}'),
                onTap: () => context.push('/buddy-chat/${buddy.id}'),
                trailing: TextButton(
                  key: Key('connect_${buddy.id}'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Connect request sent to ${buddy.name}!')),
                    );
                  },
                  child: const Text('Connect'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
