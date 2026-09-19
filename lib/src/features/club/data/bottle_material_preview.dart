import 'storage_repository.dart';

/// Explicit, local-only material review. Never read from or write to a member bag.
class BottlePreviewItem extends StorageItem {
  const BottlePreviewItem(String key, String title, {double level = 50})
    : super(
        ref: key,
        name: title,
        assetKey: key,
        remainingPercent: level,
        canPickup: false,
        expiresAt: '2026-12-20T12:00:00+08:00',
      );
  static const directory = 'assets/commerce/bottle_preview';
  @override
  String get image => '$directory/$assetKey.png';
  @override
  String get thumbnail => '$directory/${assetKey}_thumb.png';
  double get aspectRatio => const <String, double>{
    'bottle_01': 0.294286305459,
    'bottle_02': 0.328432284881,
    'bottle_03': 0.318480917466,
    'bottle_04': 0.364955935718,
    'bottle_05': 0.339786345643,
    'bottle_06': 0.385058682971,
    'bottle_07': 0.338841717642,
    'bottle_08': 0.299801003891,
    'bottle_09': 0.324523409647,
    'bottle_10': 0.344334056564,
    'bottle_11': 0.288803606238,
  }[assetKey]!;
  double get imageAspectRatio => const <String, double>{
    'bottle_01': 0.237829209896,
    'bottle_02': 0.274706867672,
    'bottle_03': 0.263959390863,
    'bottle_04': 0.314152410575,
    'bottle_05': 0.286969253294,
    'bottle_06': 0.335863377609,
    'bottle_07': 0.285949055053,
    'bottle_08': 0.243785084202,
    'bottle_09': 0.270485282418,
    'bottle_10': 0.291880781089,
    'bottle_11': 0.231907894737,
  }[assetKey]!;
  String get mask => '$directory/${assetKey}_mask.svg';
  String get outline => '$directory/${assetKey}_outline.svg';
  String get frame => '$directory/${assetKey}_frame.svg';
  String get backFrame => '$directory/${assetKey}_back_frame.svg';
  BottlePreviewItem atLevel(double value) =>
      BottlePreviewItem(assetKey, name, level: value.clamp(0, 100));
}

/// Existing four materials, shown only in the explicit comparison repository.
class LegacyBottleComparisonItem extends StorageItem {
  const LegacyBottleComparisonItem(
    String key,
    String title, {
    double level = 50,
  }) : super(
         ref: 'legacy-$key',
         name: title,
         assetKey: key,
         remainingPercent: level,
         canPickup: false,
         expiresAt: '2026-12-20T12:00:00+08:00',
       );
  @override
  String get image => assetKey == 'xo'
      ? '${BottlePreviewItem.directory}/legacy_xo.png'
      : super.image;
  @override
  String get thumbnail => assetKey == 'xo'
      ? '${BottlePreviewItem.directory}/legacy_xo_thumb.png'
      : super.thumbnail;
  LegacyBottleComparisonItem atLevel(double value) =>
      LegacyBottleComparisonItem(assetKey, name, level: value.clamp(0, 100));
}

class BottleMaterialPreviewRepository extends PreviewStorageRepository {
  BottleMaterialPreviewRepository()
    : super(const [
        LegacyBottleComparisonItem('xo', '轩尼诗XO · 旧版'),
        LegacyBottleComparisonItem('chivas', '芝华士12年 · 旧版'),
        LegacyBottleComparisonItem('hennessy', '轩尼诗VSOP · 旧版'),
        LegacyBottleComparisonItem('vodka', '瑞典绝对伏特加 · 旧版'),
        BottlePreviewItem('bottle_01', '奔富BIN407'),
        BottlePreviewItem('bottle_02', '巴黎之花特级干型香槟'),
        BottlePreviewItem('bottle_03', '獭祭39 1.8l'),
        BottlePreviewItem('bottle_04', '獭祭39 300ml'),
        BottlePreviewItem('bottle_05', '獭祭39 720ml'),
        BottlePreviewItem('bottle_06', '百富12年'),
        BottlePreviewItem('bottle_07', '酩悦皇室香槟'),
        BottlePreviewItem('bottle_08', '麦卡伦12年'),
        BottlePreviewItem('bottle_09', '麦卡伦LITHA'),
        BottlePreviewItem('bottle_10', '黑桃A黄金香槟'),
        BottlePreviewItem('bottle_11', 'ROOM NO1 草莓利口酒'),
      ]);
}
