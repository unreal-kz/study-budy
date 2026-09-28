import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/challenges.dart';
import '../../state/progress_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${progress.streak}-day streak',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text("Today's Challenge", style: Theme.of(context).textTheme.titleMedium),
          Text(challengeForDate(DateTime.now())),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/find-a-buddy'),
            child: const Text('Find a Buddy'),
          ),
        ],
      ),
    );
  }
}
