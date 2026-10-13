import 'package:flutter/material.dart';

/// The Study Buddy mark (two speech bubbles and sparks) on a transparent
/// background, rendered from `design/brand/logo_mark.svg`.
///
/// Regenerate the PNGs with `scripts/brand/build_brand_assets.py`.
class BrandLogo extends StatelessWidget {
  const BrandLogo({this.size = 96, super.key});

  /// Asset path of the 1x image; Flutter picks `2.0x/` and `3.0x/` by DPR.
  static const assetPath = 'assets/brand/logo_mark.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      semanticLabel: 'Study Buddy logo',
    );
  }
}
