import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/progress_provider.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final totalWords = progress.entries.fold<int>(0, (sum, e) => sum + e.newWords);
    final totalChallenges =
        progress.entries.fold<int>(0, (sum, e) => sum + e.challengesCompleted);
    final totalSeconds =
        progress.entries.fold<int>(0, (sum, e) => sum + e.speakingTimeSeconds);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${progress.streak}-day streak', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          ListTile(title: const Text('Speaking time'), trailing: Text('${totalSeconds}s')),
          ListTile(title: const Text('Challenges completed'), trailing: Text('$totalChallenges')),
          ListTile(title: const Text('New words'), trailing: Text('$totalWords')),
        ],
      ),
    );
  }
}
