/// Display the saved activity requirements. Eligibility and prices are decided
/// by the server using the member profile again at payment time.
const togetherStarSigns = [
  '白羊座',
  '金牛座',
  '双子座',
  '巨蟹座',
  '狮子座',
  '处女座',
  '天秤座',
  '天蝎座',
  '射手座',
  '摩羯座',
  '水瓶座',
  '双鱼座',
];

const togetherChineseZodiacs = [
  '鼠',
  '牛',
  '虎',
  '兔',
  '龙',
  '蛇',
  '马',
  '羊',
  '猴',
  '鸡',
  '狗',
  '猪',
];

String togetherRuleSummary(Map rules) {
  final parts = <String>[];
  int? integer(String key, int min, int max) {
    final value = rules[key];
    if (value == null) return null;
    if (value is! int || value < min || value > max) {
      throw const FormatException('Invalid activity rule');
    }
    return value;
  }

  final min = integer('minAge', 18, 120);
  final max = integer('maxAge', 18, 120);
  if (min != null && max != null && min > max) {
    throw const FormatException('Invalid age range');
  }
  if (min != null && max != null) {
    parts.add('$min—$max周岁');
  } else if (min != null) {
    parts.add('年满$min周岁');
  } else if (max != null) {
    parts.add('不超过$max周岁');
  }
  final extra = rules['overageCentsPerYear'];
  if (extra != null) {
    if (max == null ||
        extra is! String ||
        !RegExp(r'^(0|[1-9][0-9]{0,7})$').hasMatch(extra)) {
      throw const FormatException('Invalid age surcharge');
    }
    parts.add('超龄每岁加¥${(int.parse(extra) / 100).toStringAsFixed(2)}');
  }
  for (final entry in {
    'minimumMaleScore': '男士',
    'minimumFemaleScore': '女士',
  }.entries) {
    final score = rules[entry.key];
    if (score == null) continue;
    if (score is! num || !score.isFinite || score < 0 || score > 100) {
      throw const FormatException('Invalid appearance score');
    }
    final text = score == score.roundToDouble()
        ? score.toInt().toString()
        : score.toString();
    parts.add('${entry.value}颜值$text分起');
  }
  final experience = integer('minimumExperience', 0, 1000000000);
  if (experience != null) parts.add('会员经验$experience起');
  final signs = rules['excludedStarSigns'];
  if (signs != null) {
    if (signs is! List ||
        signs.length > 12 ||
        signs.any((s) => !togetherStarSigns.contains(s))) {
      throw const FormatException('Invalid star signs');
    }
    if (signs.isNotEmpty) parts.add('不接受${signs.toSet().join('、')}');
  }
  final animals = rules['excludedChineseZodiacs'];
  if (animals != null) {
    if (animals is! List ||
        animals.length > 12 ||
        animals.any((s) => !togetherChineseZodiacs.contains(s))) {
      throw const FormatException('Invalid Chinese zodiacs');
    }
    if (animals.isNotEmpty) parts.add('不接受属${animals.toSet().join('、')}（按农历年）');
  }
  return parts.join(' · ');
}
