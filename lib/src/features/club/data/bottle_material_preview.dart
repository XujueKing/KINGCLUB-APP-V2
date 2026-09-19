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
      );
  static const directory = 'assets/commerce/bottle_preview';
  @override
  String get image => '$directory/$assetKey.png';
  @override
  String get thumbnail => '$directory/${assetKey}_thumb.png';
  String get mask => '$directory/${assetKey}_mask.svg';
  String get outline => '$directory/${assetKey}_outline.svg';
  String get frame => '$directory/${assetKey}_frame.svg';
  BottlePreviewItem atLevel(double value) =>
      BottlePreviewItem(assetKey, name, level: value.clamp(0, 100));
}

class BottleMaterialPreviewRepository extends PreviewStorageRepository {
  BottleMaterialPreviewRepository()
    : super(const [
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
