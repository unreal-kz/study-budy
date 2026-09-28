import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One "number over label" stat block, used in the Progress and Profile
/// stat rows (e.g. speaking time, challenges completed, new words).
class StatTile extends StatelessWidget {
  const StatTile({required this.value, required this.label, super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(fontSize: 20, color: AppColors.pine800),
            ),
            const SizedBox(height: 2),
            Text(label, style: textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// A row of [StatTile]s spaced evenly, each wrapped in [Expanded] by the
/// tile itself so callers just supply the list.
class StatRow extends StatelessWidget {
  const StatRow({required this.tiles, super.key});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 10));
      children.add(tiles[i]);
    }
    return Row(children: children);
  }
}
