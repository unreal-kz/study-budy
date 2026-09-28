import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// AI Buddy's inline grammar-correction card, shown under an assistant
/// message that includes a [correction] for something the user wrote.
class CorrectionCard extends StatelessWidget {
  const CorrectionCard({required this.correction, this.explanation, super.key});

  final String correction;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('ai_feedback_card'),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.84),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        border: Border.all(color: AppColors.warnBorder, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✅', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                'Nice try — quick correction',
                style: textTheme.labelMedium?.copyWith(color: AppColors.warnText, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Correction: $correction', style: textTheme.bodyMedium),
          if (explanation != null) ...[
            const SizedBox(height: 8),
            Text(
              explanation!,
              style: textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
