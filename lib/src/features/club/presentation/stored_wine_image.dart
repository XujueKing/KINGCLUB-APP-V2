import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../../../core/media/cached_media_svg.dart';
import '../data/storage_repository.dart';

class StoredWineImage extends StatelessWidget {
  const StoredWineImage({
    super.key,
    required this.item,
    this.thumbnail = false,
    this.width,
    this.height,
  });
  final StorageItem item;
  final bool thumbnail;
  final double? width, height;
  @override
  Widget build(BuildContext context) {
    final material = item.bottleMaterial;
    Widget fallback() => Image.asset(
      thumbnail ? item.thumbnail : item.image,
      fit: BoxFit.contain,
    );
    if (material == null) {
      return SizedBox(width: width, height: height, child: fallback());
    }
    final role = thumbnail ? 'thumbnail' : 'image';
    return SizedBox(
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final bodyHeight = math.min(
            box.maxHeight,
            box.maxWidth / material.imageAspectRatio,
          );
          return Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              StoredWineBacking(item: item, bodyHeight: bodyHeight),
              CachedMediaImage(
                material.files[role]!,
                private: true,
                contentKey: material.cacheKey(role),
                fit: BoxFit.contain,
                keepSameImageOnRefresh: true,
                errorBuilder: (context, error, stack) => fallback(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class StoredWineBacking extends StatelessWidget {
  const StoredWineBacking({
    super.key,
    required this.item,
    required this.bodyHeight,
    this.reverse = false,
  });
  final StorageItem item;
  final double bodyHeight;
  final bool reverse;
  @override
  Widget build(BuildContext context) {
    final material = item.bottleMaterial!;
    final role = reverse ? 'backFrame' : 'frame';
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, bodyHeight * .505),
          child: Container(
            width: bodyHeight * material.imageAspectRatio * 1.48,
            height: bodyHeight * .088,
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(bodyHeight),
            ),
          ),
        ),
        Center(
          child: OverflowBox(
            maxHeight: bodyHeight * 1.08,
            maxWidth: bodyHeight * 1.08 * material.aspectRatio,
            child: SizedBox(
              height: bodyHeight * 1.08,
              width: bodyHeight * 1.08 * material.aspectRatio,
              child: CachedMediaSvg(
                material.files[role]!,
                contentKey: material.cacheKey(role),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
