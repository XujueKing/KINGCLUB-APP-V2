import 'package:flutter/material.dart';

/// Bundled, compressed legacy artwork, decoded only at its display resolution.
/// AssetImage/ResizeImage reuse Flutter's image cache across list and detail views.
class LegacyHomeImage extends StatelessWidget {
  const LegacyHomeImage(
    this.asset, {
    super.key,
    this.fit = BoxFit.cover,
    this.height,
    this.cacheWidth,
  });

  final String asset;
  final BoxFit fit;
  final double? height;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Image.asset(
        asset,
        fit: fit,
        height: height,
        cacheWidth:
            cacheWidth ??
            (constraints.maxWidth.isFinite
                ? (constraints.maxWidth *
                          MediaQuery.devicePixelRatioOf(context))
                      .ceil()
                : null),
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
