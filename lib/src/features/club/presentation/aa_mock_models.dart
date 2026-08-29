class AaMockPackage {
  const AaMockPackage({
    required this.seat,
    required this.name,
    required this.remaining,
    required this.priceMinor,
    required this.available,
    required this.contents,
    this.ruleSummary = '系统随机分桌 · 本人一席',
    this.posterAsset,
    this.suggestedPackagePriceMinor,
    this.originalPriceMinor,
    this.partySize = 1,
  });

  final String seat;
  final String name;
  final String remaining;
  final int priceMinor;
  final bool available;
  final List<String> contents;
  final String ruleSummary;
  final String? posterAsset;
  final int? suggestedPackagePriceMinor;
  final int? originalPriceMinor;
  final int partySize;

  String get priceYuan => (priceMinor / 100).toStringAsFixed(0);

  AaMockPackage copyWith({int? priceMinor, bool? available}) => AaMockPackage(
    seat: seat,
    name: name,
    remaining: remaining,
    priceMinor: priceMinor ?? this.priceMinor,
    available: available ?? this.available,
    contents: contents,
    ruleSummary: ruleSummary,
    posterAsset: posterAsset,
    suggestedPackagePriceMinor: suggestedPackagePriceMinor,
    originalPriceMinor: originalPriceMinor,
    partySize: partySize,
  );
}

const aaMockPackages = <AaMockPackage>[
  AaMockPackage(
    seat: 'V5',
    name: '3880卡座套餐',
    remaining: '4/10',
    priceMinor: 26800,
    available: true,
    contents: [
      '瑞典绝对伏特加 700ml x 4瓶',
      '草莓利口酒 700ml x 2瓶',
      'NFC橙汁 350ml x 24瓶',
      '雪碧 350ml x 8瓶',
      '小吃 小份 x 1份',
      '水果 小份 x 1份',
    ],
    posterAsset: 'assets/legacy/aa/package_3880_v1.png',
    suggestedPackagePriceMinor: 388000,
    originalPriceMinor: 38800,
    partySize: 10,
  ),
  AaMockPackage(
    seat: 'A8',
    name: '经典派对套餐',
    remaining: '6/8',
    priceMinor: 28800,
    available: true,
    contents: ['芝华士 12 年 700ml × 1', '精选软饮 × 8', '时令果盘 × 2', '精致小吃 × 2'],
  ),
  AaMockPackage(
    seat: 'A10',
    name: '限定香槟套餐',
    remaining: '已满',
    priceMinor: 38800,
    available: false,
    contents: ['精选香槟 750ml × 2', '精选软饮 × 10', '时令果盘 × 2', '精致小吃 × 3'],
  ),
];

String formatAaMoney(int minor) => '¥${(minor / 100).toStringAsFixed(2)}';
