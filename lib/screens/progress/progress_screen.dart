import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/progress_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_tile.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final textTheme = Theme.of(context).textTheme;
    final totalWords = progress.entries.fold<int>(0, (sum, e) => sum + e.newWords);
    final totalChallenges =
        progress.entries.fold<int>(0, (sum, e) => sum + e.challengesCompleted);
    final totalSeconds =
        progress.entries.fold<int>(0, (sum, e) => sum + e.speakingTimeSeconds);
    final totalMinutes = (totalSeconds / 60).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.pine800, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Text('\u{1F525}', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Text(
                  '${progress.streak}-day streak',
                  style: textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 19),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StatRow(
            tiles: [
              StatTile(value: '${totalMinutes}m', label: 'Speaking time'),
              StatTile(value: '$totalChallenges', label: 'Challenges'),
              StatTile(value: '$totalWords', label: 'New words'),
            ],
          ),
        ],
      ),
    );
  }
}
