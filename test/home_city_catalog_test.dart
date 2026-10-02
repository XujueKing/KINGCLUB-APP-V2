import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/home/data/home_city_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('only city-level choices appear while location district normalization remains available', () async {
    final catalog = await HomeCityCatalog.load();
    final zhuzhou = catalog.named('株洲')!;
    expect(zhuzhou.code, '430200');
    expect(catalog.related(zhuzhou).map((c) => c.shortName), contains('长沙'));
    expect(catalog.related(zhuzhou).every(catalog.selectable), isTrue);
    expect(catalog.search('tianyuan', false), isEmpty);
    expect(catalog.search('天元区', false), isEmpty);
    expect(catalog.namedCity('天元区')?.code, '430200');
    expect(catalog.search('', false).every(catalog.selectable), isTrue);
    expect(catalog.search('北京市', false).single.code, '110000');
    expect(catalog.parent(catalog.byCode['430211']!).code, '430200');
    expect(catalog.parent(catalog.byCode['310101']!).code, '310000');
    expect(catalog.popular(false), hasLength(16));
    expect(catalog.named('曼谷')!.code, startsWith('INT_'));
    expect(catalog.search('曼谷', true), isNotEmpty);
    expect(catalog.search('株洲', true), isEmpty);
    expect(catalog.byCode.length, catalog.cities.length);
  });
}
