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
    'bottle_01': 0.294287,
    'bottle_02': 0.328648,
    'bottle_03': 0.319417,
    'bottle_04': 0.367694,
    'bottle_05': 0.340565,
    'bottle_06': 0.385352,
    'bottle_07': 0.339056,
    'bottle_08': 0.302546,
    'bottle_09': 0.324926,
    'bottle_10': 0.344611,
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
      ]);
}
