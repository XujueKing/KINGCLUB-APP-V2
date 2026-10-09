import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/storage_repository.dart';

void main() {
  Map<String, dynamic> material([String token = 'signed']) => {
    'storeRef': 'store-a',
    'version': 'png-contour-v1',
    'sourceSha256': 'a' * 64,
    'aspectRatio': .4,
    'imageAspectRatio': .3,
    'files': {
      for (final role in [
        'image',
        'thumbnail',
        'mask',
        'outline',
        'frame',
        'backFrame',
      ])
        role: '/attachments/12345678-1234-1234-1234-123456789abc?token=$token',
    },
  };
  StorageBottleMaterial? parse(
    Map<String, dynamic> value, [
    String store = 'store-a',
  ]) => StorageBottleMaterial.parse(
    value,
    store,
    mediaBaseUrl: 'https://example.test/kingclub-v2',
  );
  test('source PNG, thumbnail and contours keep origin and stable cache identities', () {
    final first = parse(material())!, renewed = parse(material('renewed'))!;
    expect(
      first.files['image'],
      startsWith('https://example.test/kingclub-v2/attachments/'),
    );
    expect(first.files['image'], isNot(renewed.files['image']));
    expect(first.cacheKey('image'), renewed.cacheKey('image'));
    expect(first.cacheKey('image'), isNot(first.cacheKey('thumbnail')));
  });
  test('wrong store and malformed or cross-origin links are rejected', () {
    expect(parse(material(), 'store-b'), isNull);
    for (final link in [
      'https://evil.test/image.png',
      '//evil.test/image.png',
      '/attachments/12345678-1234-1234-1234-123456789abc?token=x&token=y',
      '/attachments/12345678-1234-1234-1234-123456789abc?token=x#fragment',
    ]) {
      final value = material();
      (value['files'] as Map)['image'] = link;
      expect(parse(value), isNull);
    }
    expect(parse({...material(), 'imageAspectRatio': double.nan}), isNull);
    expect(parse({...material(), 'version': 'unknown'}), isNull);
  });
  test('older storage records retain bundled bottles and pickup state', () {
    final item = StorageItem.fromJson({
      'itemRef': 'item',
      'name': 'Wine',
      'assetKey': 'chivas',
      'category': 'wine',
      'quantity': 1,
      'remainingPercent': 25,
      'status': 'available',
      'canPickup': true,
    });
    expect(item.image, endsWith('CHIVAS12.png'));
    expect(item.bottleMaterial, isNull);
    expect(item.canPickup, isTrue);
    expect(item.remainingPercent, 25);
  });
}
