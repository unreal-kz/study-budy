import 'package:flutter/material.dart';

import '../../data/seed_repository.dart';
import '../../models/community_group.dart';
import '../../theme/app_theme.dart';

const _groupVisuals = {
  'movies': (icon: Icons.movie_outlined, color: Color(0xFFC4634B), bg: Color(0xFFFBE7E3)),
  'travel': (icon: Icons.public, color: Color(0xFF3E6FC4), bg: Color(0xFFE2ECFB)),
  'study-tips': (icon: Icons.menu_book_outlined, color: Color(0xFFC6952C), bg: Color(0xFFFBF1D0)),
  'games': (icon: Icons.sports_esports_outlined, color: Color(0xFF7A3E77), bg: Color(0xFFF4E3F3)),
  'speaking-club': (icon: Icons.mic_none, color: AppColors.green600, bg: Color(0xFFE4EFEA)),
};

const _defaultVisual = (icon: Icons.groups_outlined, color: AppColors.neutral500, bg: AppColors.neutral100);

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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: FutureBuilder<List<CommunityGroup>>(
        future: _groups,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final groups = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final group = groups[index];
              final visual = _groupVisuals[group.id] ?? _defaultVisual;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral200, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: visual.bg, borderRadius: BorderRadius.circular(14)),
                      child: Icon(visual.icon, color: visual.color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.name, style: textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            '${group.memberCount} members · ${group.description}',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
