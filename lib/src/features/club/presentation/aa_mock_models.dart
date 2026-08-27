class AaMockPackage {
  const AaMockPackage({
    required this.seat,
    required this.name,
    required this.remaining,
    required this.priceMinor,
    required this.available,
    required this.contents,
    this.ruleSummary = '系统随机分桌 · 本人一席',
  });

  final String seat;
  final String name;
  final String remaining;
  final int priceMinor;
  final bool available;
  final List<String> contents;
  final String ruleSummary;

  String get priceYuan => (priceMinor / 100).toStringAsFixed(0);

  AaMockPackage copyWith({int? priceMinor, bool? available}) => AaMockPackage(
    seat: seat,
    name: name,
    remaining: remaining,
    priceMinor: priceMinor ?? this.priceMinor,
    available: available ?? this.available,
    contents: contents,
    ruleSummary: ruleSummary,
  );
}

const aaMockPackages = <AaMockPackage>[
  AaMockPackage(
    seat: 'A6',
    name: '微醺畅饮套餐',
    remaining: '4/6',
    priceMinor: 19800,
    available: true,
    contents: ['绝对伏特加 700ml × 1', '精选软饮 × 6', '时令果盘 × 1', '精致小吃 × 2'],
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
