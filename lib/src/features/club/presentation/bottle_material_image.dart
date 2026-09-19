import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/bottle_material_preview.dart';

/// The legacy PNGs already contain a silhouette backing and a ground shadow.
/// Apply those layers only to new transparent product material.
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
      final imageWidth = imageHeight * rawAspect;
      final shadowWidth = imageWidth * 1.25;
      final shadowHeight = imageHeight * .035;
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: (box.maxHeight + imageHeight) / 2 - shadowHeight * .5,
            left: (box.maxWidth - shadowWidth) / 2,
            child: Container(
              key: ValueKey('bottle-ground-${item.ref}'),
              width: shadowWidth,
              height: shadowHeight,
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.all(
                  Radius.elliptical(shadowWidth / 2, shadowHeight / 2),
                ),
              ),
            ),
          ),
          Center(
            child: OverflowBox(
              maxHeight: imageHeight * 1.08,
              maxWidth: imageHeight * 1.08 * item.aspectRatio,
              child: SvgPicture.asset(
                item.frame,
                key: ValueKey('bottle-backing-${item.ref}'),
                height: imageHeight * 1.08,
                width: imageHeight * 1.08 * item.aspectRatio,
              ),
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
