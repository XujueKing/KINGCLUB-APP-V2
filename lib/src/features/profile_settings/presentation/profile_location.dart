import '../../home/data/home_city_catalog.dart';

/// Formats the member's reported location, independently of the city selected
/// for browsing home content. No location permission or network request here.
String? profileLocationLabel(
  Map<String, dynamic> profile,
  HomeCityCatalog catalog,
) {
  String label(HomeCity raw) {
    final city = catalog.parent(raw);
    if (!RegExp(r'^\d{6}$').hasMatch(city.code)) return city.name;
    final province = catalog.byCode['${city.code.substring(0, 2)}0000'];
    if (province == null || province.code == city.code) return city.name;
    return '${province.name} · ${city.name}';
  }

  final locatedCode = profile['locatedCityCode'];
  final located = locatedCode is String ? catalog.byCode[locatedCode] : null;
  if (located != null) return label(located);
  final saved = profile['locationCity'];
  if (saved is! String || saved.trim().isEmpty) return null;
  final text = saved.trim();
  final city = catalog.namedCity(text);
  return city == null ? text : label(city);
}
