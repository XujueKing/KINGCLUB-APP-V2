import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/bottle_material_preview.dart';

/// Ratios measured from legacy vodka.png and W_K23500000002_BJ/A.
/// The background SVG includes an ellipse 217.2 x 40.08 around a 146 x 453 bottle.
class BottleMaterialBacking extends StatelessWidget {
  const BottleMaterialBacking({
    super.key,
    required this.item,
    required this.bodyHeight,
    required this.bodyWidth,
    this.reverse = false,
  });
  final BottlePreviewItem item;
  final double bodyHeight, bodyWidth;
  final bool reverse;
  static const shadowWidthRatio = 217.2 / 146;
  static const shadowHeightRatio = 40.08 / 453;
  static const shadowCenterOffsetRatio = 7.46 / 453;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final shadowWidth = bodyWidth * shadowWidthRatio;
      final shadowHeight = bodyHeight * shadowHeightRatio;
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top:
                (box.maxHeight + bodyHeight) / 2 +
                bodyHeight * shadowCenterOffsetRatio -
                shadowHeight / 2,
            left: (box.maxWidth - shadowWidth) / 2,
            child: Container(
              key: ValueKey('bottle-ground-${item.ref}'),
              width: shadowWidth,
              height: shadowHeight,
              decoration: BoxDecoration(
                color: reverse
                    ? const Color(0x33000000)
                    : const Color(0x4D000000),
                borderRadius: BorderRadius.all(
                  Radius.elliptical(shadowWidth / 2, shadowHeight / 2),
                ),
              ),
            ),
          ),
          Center(
            child: OverflowBox(
              maxHeight: bodyHeight * 1.08,
              maxWidth: bodyHeight * 1.08 * item.aspectRatio,
              child: SvgPicture.asset(
                reverse ? item.backFrame : item.frame,
                key: ValueKey('bottle-backing-${item.ref}'),
                height: bodyHeight * 1.08,
                width: bodyHeight * 1.08 * item.aspectRatio,
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Legacy PNGs already contain their backing. Only new transparent images use this.
class BottleMaterialImage extends StatelessWidget {
  const BottleMaterialImage({
    super.key,
    required this.item,
    this.thumbnail = false,
  });
  final BottlePreviewItem item;
  final bool thumbnail;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final rawAspect = (item.aspectRatio * 1080 - 80) / 1000;
      final imageHeight = math.min(box.maxHeight, box.maxWidth / rawAspect);
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: BottleMaterialBacking(
              item: item,
              bodyHeight: imageHeight,
              bodyWidth: imageHeight * rawAspect,
            ),
          ),
          Image.asset(
            thumbnail ? item.thumbnail : item.image,
            width: box.maxWidth,
            height: box.maxHeight,
            fit: BoxFit.contain,
          ),
        ],
      );
    },
  );
}
