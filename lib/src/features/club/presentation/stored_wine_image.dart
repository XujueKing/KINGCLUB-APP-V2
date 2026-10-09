import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../../../core/media/cached_media_svg.dart';
import '../data/storage_repository.dart';
import 'bottle_material_image.dart';

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
    return BottleVisualBacking(
      reference: item.ref,
      bodyHeight: bodyHeight,
      bodyWidth: bodyHeight * material.imageAspectRatio,
      frameAspectRatio: material.aspectRatio,
      bodyBounds: material.bodyBounds,
      reverse: reverse,
      backing: CachedMediaSvg(
        material.files[role]!,
        contentKey: material.cacheKey(role),
      ),
    );
  }
}
