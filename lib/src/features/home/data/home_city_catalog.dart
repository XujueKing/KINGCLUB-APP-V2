import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lpinyin/lpinyin.dart';

class HomeCity {
  const HomeCity({
    required this.code,
    required this.name,
    required this.shortName,
    required this.pinyin,
    this.country,
  });
  final String code, name, shortName, pinyin;
  final String? country;
  bool get international =>
      code.startsWith('INT_') ||
      {'71', '81', '82'}.contains(code.substring(0, 2));
  String get letter => pinyin.isEmpty || !RegExp(r'^[a-zA-Z]').hasMatch(pinyin)
      ? '#'
      : pinyin[0].toUpperCase();
  bool matches(String query) {
    final q = query.trim().toLowerCase().replaceAll(' ', '');
    return name.toLowerCase().contains(q) ||
        shortName.toLowerCase().contains(q) ||
        pinyin.startsWith(q) ||
        (country?.toLowerCase().contains(q) ?? false);
  }

  factory HomeCity.parse(Map<String, dynamic> row) {
    final name = row['name'] as String;
    final translated = const {
      'Bangkok': '曼谷',
      'Singapore': '新加坡',
      'Tokyo': '东京',
      'Seoul': '首尔',
      'London': '伦敦',
      'Paris': '巴黎',
      'New York City': '纽约',
      'Dubai': '迪拜',
    }[name];
    final pinyin = row['pinyin'] as String? ?? '';
    return HomeCity(
      code: row['code'] as String,
      name: translated ?? name,
      shortName: translated ?? row['shortName'] as String,
      pinyin: pinyin.isNotEmpty
          ? pinyin
          : PinyinHelper.getPinyinE(
              name,
              separator: '',
              format: PinyinFormat.WITHOUT_TONE,
            ).toLowerCase(),
      country: row['country'] as String?,
    );
  }
}

class HomeCityCatalog {
  HomeCityCatalog(this.cities) : byCode = {for (final c in cities) c.code: c};
  final List<HomeCity> cities;
  final Map<String, HomeCity> byCode;
  static Future<HomeCityCatalog>? _loading;
  static Future<HomeCityCatalog> load() => _loading ??= _load();
  static Future<HomeCityCatalog> _load() async {
    final lists = await Future.wait([
      rootBundle.loadString('assets/legacy/profile/city_regions.json'),
      rootBundle.loadString('assets/legacy/profile/international_cities.json'),
    ]);
    return HomeCityCatalog([
      for (final text in lists)
        for (final row in jsonDecode(text) as List)
          HomeCity.parse(Map<String, dynamic>.from(row as Map)),
    ]);
  }

  HomeCity? named(String? name) {
    if (name == null) return null;
    final text = name.split(' · ').last;
    for (final c in cities) {
      if (c.name == text || c.shortName == text) return c;
    }
    return null;
  }

  HomeCity parent(HomeCity city) {
    if (city.code.startsWith('INT_') || city.code.endsWith('0000')) return city;
    final municipality = '${city.code.substring(0, 2)}0000';
    if ({'110000', '120000', '310000', '500000'}.contains(municipality)) {
      return byCode[municipality]!;
    }
    return byCode['${city.code.substring(0, 4)}00'] ?? city;
  }

  List<HomeCity> related(HomeCity city) {
    if (city.code.startsWith('INT_')) return [];
    final p = parent(city);
    final prefix = p.code.endsWith('0000')
        ? p.code.substring(0, 2)
        : p.code.substring(0, 4);
    return cities
        .where((c) => c.code.startsWith(prefix) && !c.code.endsWith('00'))
        .toList();
  }

  List<HomeCity> popular(bool international) {
    final names = international
        ? ['香港', '澳门', '台北', '曼谷', '新加坡', '东京', '首尔', '巴黎']
        : [
            '上海',
            '北京',
            '广州',
            '杭州',
            '成都',
            '深圳',
            '苏州',
            '南京',
            '重庆',
            '西安',
            '长沙',
            '天津',
            '三亚',
            '厦门',
            '武汉',
            '无锡',
          ];
    return [for (final name in names) ?named(name)];
  }

  List<HomeCity> search(String query, bool international) =>
      cities
          .where(
            (c) =>
                c.international == international &&
                (query.isNotEmpty
                    ? c.matches(query)
                    : c.code.startsWith('INT_') ||
                          !c.code.endsWith('0000') ||
                          c.international ||
                          {
                            '110000',
                            '120000',
                            '310000',
                            '500000',
                          }.contains(c.code)),
          )
          .toList()
        ..sort((a, b) => a.pinyin.compareTo(b.pinyin));
}

/// This is device-local browsing history, never a fabricated list of visits.
class HomeCityHistory {
  const HomeCityHistory();
  static const _storage = FlutterSecureStorage();
  Future<List<String>> read() async {
    try {
      final raw = await _storage.read(key: 'kingclub.home.city-history.v1');
      return raw == null
          ? []
          : (jsonDecode(raw) as List).whereType<String>().take(8).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> remember(String code) async {
    final codes = [
      code,
      ...(await read()).where((c) => c != code),
    ].take(8).toList();
    try {
      await _storage.write(
        key: 'kingclub.home.city-history.v1',
        value: jsonEncode(codes),
      );
    } catch (_) {}
  }
}
