import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/home/data/home_city_catalog.dart';
import 'package:kingclub/src/features/profile_settings/presentation/profile_location.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HomeCityCatalog catalog;
  setUpAll(() async => catalog = await HomeCityCatalog.load());

  test('located city shows its province even when browsing another city', () {
    expect(
      profileLocationLabel({
        'locatedCityCode': '430200',
        'browsingCityCode': '310000',
      }, catalog),
      '湖南省 · 株洲市',
    );
    expect(
      profileLocationLabel({'locatedCityCode': '430211'}, catalog),
      '湖南省 · 株洲市',
    );
  });
  test(
    'municipalities and international cities do not duplicate their name',
    () {
      expect(
        profileLocationLabel({'locatedCityCode': '310101'}, catalog),
        '上海市',
      );
      final bangkok = catalog.named('曼谷')!;
      expect(
        profileLocationLabel({'locatedCityCode': bangkok.code}, catalog),
        '曼谷',
      );
    },
  );
  test('keeps saved profile location when no located city is available', () {
    expect(profileLocationLabel({'locationCity': '株洲市'}, catalog), '湖南省 · 株洲市');
    expect(
      profileLocationLabel({'locationCity': '湖南省 · 株洲市'}, catalog),
      '湖南省 · 株洲市',
    );
    expect(
      profileLocationLabel({
        'locatedCityCode': 'unknown',
        'locationCity': '株洲市',
      }, catalog),
      '湖南省 · 株洲市',
    );
  });
  test('manual browsing selection alone never fabricates a location tag', () {
    HomeCitySession.current = catalog.byCode['430200'];
    addTearDown(() => HomeCitySession.current = null);
    expect(
      profileLocationLabel({'browsingCityCode': '430200'}, catalog),
      isNull,
    );
    expect(profileLocationLabel({'locationCity': '  '}, catalog), isNull);
  });
}
