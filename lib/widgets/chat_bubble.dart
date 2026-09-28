import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A single chat message bubble, right-aligned and dark for the current
/// user, left-aligned and light for the other party. Shared by the AI Buddy
/// and Buddy Chat screens so both threads look identical.
class ChatBubble extends StatelessWidget {
  const ChatBubble({required this.text, required this.isMine, super.key});

  final String text;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMine ? AppColors.pine800 : AppColors.neutral150,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Text(
          text,
          style: textTheme.bodyMedium?.copyWith(color: isMine ? Colors.white : AppColors.pine900),
        ),
      ),
    );
  }
}
