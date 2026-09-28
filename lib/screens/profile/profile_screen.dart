import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/profile_provider.dart';
import '../../state/progress_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/initial_avatar.dart';
import '../../widgets/stat_tile.dart';
import '../onboarding/onboarding_screen.dart' show levelLabels;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final progress = context.watch<ProgressProvider>();
    final textTheme = Theme.of(context).textTheme;
    final totalWords = progress.entries.fold<int>(0, (sum, e) => sum + e.newWords);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: const BoxDecoration(
              color: AppColors.pine800,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
            ),
            child: Column(
              children: [
                InitialAvatar(
                  initial: profile.name.isEmpty ? '?' : profile.name[0].toUpperCase(),
                  color: AppColors.gold500,
                  size: 76,
                ),
                const SizedBox(height: 12),
                Text(profile.name, style: textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 19)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    levelLabels[profile.level] ?? profile.level,
                    style: textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: StatRow(
              tiles: [
                StatTile(value: '${progress.streak}', label: 'Day streak'),
                StatTile(value: '$totalWords', label: 'New words'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
