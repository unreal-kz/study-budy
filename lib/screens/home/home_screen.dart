import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/challenges.dart';
import '../../state/profile_provider.dart';
import '../../state/progress_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/initial_avatar.dart';
import '../../widgets/streak_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final profile = context.watch<ProfileProvider>().profile;
    final textTheme = Theme.of(context).textTheme;
    final firstName = profile.name.isEmpty ? 'there' : profile.name.split(' ').first;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              InitialAvatar(
                initial: profile.name.isEmpty ? '?' : profile.name[0].toUpperCase(),
                color: AppColors.gold500,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hi, $firstName \u{1F44B}', style: textTheme.titleLarge),
                    Text('Ready to speak today?', style: textTheme.bodyMedium?.copyWith(color: AppColors.neutral500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreakCard(streakDays: progress.streak),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warnBg,
              border: Border.all(color: AppColors.warnBorder),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.gold500, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.track_changes, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text("Today's Challenge", style: textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(challengeForDate(DateTime.now()), style: textTheme.bodyMedium),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold500),
                    onPressed: () => context.go('/ai-buddy'),
                    child: const Text('Start Now →'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/find-a-buddy'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutral200, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.groups, color: AppColors.pine800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Find a Buddy', style: textTheme.titleMedium)),
                  const Icon(Icons.chevron_right, color: AppColors.neutral400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.neutral100, borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '"Progress happens outside your comfort zone."',
                    style: textTheme.titleSmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.neutral500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
