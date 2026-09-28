import 'package:flutter/material.dart';

/// Circular avatar showing a single initial on a solid colour background,
/// used for buddies and the current user wherever there is no profile photo.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    required this.initial,
    required this.color,
    this.size = 48,
    super.key,
  });

  final String initial;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontSize: size * 0.36,
            ),
      ),
    );
  }
}
