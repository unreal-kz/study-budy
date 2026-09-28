import 'package:flutter/material.dart';

import '../models/buddy.dart';
import '../theme/app_theme.dart';
import 'initial_avatar.dart';

/// Deterministic avatar colour per buddy id so the same person always gets
/// the same colour across screens, without storing it in the model.
Color avatarColorForId(String id) {
  const palette = [
    AppColors.gold500,
    AppColors.pine800,
    AppColors.green600,
    Color(0xFF7A3E77),
    Color(0xFFC4633D),
  ];
  return palette[id.hashCode.abs() % palette.length];
}

/// Row card for a buddy in the Find a Buddy list: avatar, name, level/city,
/// interest chips, and a Connect action.
class BuddyCard extends StatelessWidget {
  const BuddyCard({
    required this.buddy,
    required this.onTap,
    required this.onConnect,
    super.key,
  });

  final Buddy buddy;
  final VoidCallback onTap;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: Key('buddy_card_${buddy.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral200, width: 1.5),
        ),
        child: Row(
          children: [
            InitialAvatar(
              initial: buddy.name.isEmpty ? '?' : buddy.name[0].toUpperCase(),
              color: avatarColorForId(buddy.id),
              size: 52,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(buddy.name, style: textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('${buddy.level} · ${buddy.city}', style: textTheme.bodySmall),
                  if (buddy.interests.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final interest in buddy.interests)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.neutral100,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              interest,
                              style: textTheme.labelMedium?.copyWith(fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: Key('connect_${buddy.id}'),
              onPressed: onConnect,
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}
