import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dark streak-summary card shown at the top of Home: current streak plus a
/// Mon–Sun row where days at or before [streakDays] (capped at 7) are marked
/// complete. This mirrors the ISO week starting Monday, not calendar dates.
class StreakCard extends StatelessWidget {
  const StreakCard({required this.streakDays, super.key});

  final int streakDays;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final completedDays = streakDays.clamp(0, 7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pine800,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u{1F525}', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streakDays-day streak',
                    style: textTheme.titleMedium?.copyWith(color: Colors.white, fontSize: 17),
                  ),
                  Text(
                    "Keep going, you're doing great!",
                    style: textTheme.bodySmall?.copyWith(color: const Color(0xFFB9CFC8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < _dayLabels.length; i++)
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i < completedDays ? AppColors.green600 : Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: i < completedDays
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _dayLabels[i],
                      style: textTheme.labelSmall?.copyWith(color: const Color(0xFFB9CFC8)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
