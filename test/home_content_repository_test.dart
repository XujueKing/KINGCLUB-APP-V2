import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/home/data/home_content_repository.dart';

Map<String, dynamic> homeFixture({
  String ref = 'fixture',
  String mode = 'article',
}) => {
  'contentRef': ref,
  'placement': 'card',
  'mode': mode,
  'revision': 2,
  'liked': false,
  'likeCount': 7,
  'document': {
    'titles': {
      for (final l in ['zh-CN', 'zh-TW', 'en', 'th']) l: 'Fixture title',
    },
    'descriptions': {
      for (final l in ['zh-CN', 'zh-TW', 'en', 'th']) l: 'Fixture body',
    },
    'cover': 'assets/legacy/home/legacy_poster_handsome.webp',
    'aspectRatio': .75,
    'video': mode == 'video' ? 'https://example.invalid/movie.mp4' : null,
    'authorName': 'Fixture author',
    'authorAvatar': null,
  },
};
Map<String, dynamic> homeSession(String id) => {
  'account': {'userAccount': 'fixture-member'},
  'sessionId': id,
  'apiKeyId': 'fixture-key',
  'apiKey': 'fixture-secret',
};
Map<String, dynamic> envelope(Map<String, dynamic> result) => {
  'result': result,
};
void main() {
  test(
    'detail background accepts editor hex colours with a legacy default',
    () {
      expect(HomeContent.parse(homeFixture()).backgroundColor, 0xFF000000);
      for (final hex in ['#FFFFFF', '#934Ab2']) {
        final row = homeFixture();
        (row['document'] as Map)['backgroundColor'] = hex;
        expect(
          HomeContent.parse(row).backgroundColor,
          0xFF000000 | int.parse(hex.substring(1), radix: 16),
        );
      }
      final row = homeFixture();
      (row['document'] as Map)['backgroundColor'] = 'url(private)';
      expect(() => HomeContent.parse(row), throwsA(isA<AuthFailure>()));
    },
  );

  test(
    'city echo, duplicate refs, private media and missing video are rejected',
    () async {
      var result = <String, dynamic>{
        'cityCode': '430200',
        'items': [homeFixture()],
      };
      final repository = HomeContentRepository(
        readSession: () async => homeSession('first'),
        request: (id, params, session) async => envelope(result),
      );
      expect((await repository.list('430200')).single.likeCount, 7);
      result = {
        'cityCode': '430100',
        'items': [homeFixture()],
      };
      await expectLater(repository.list('430200'), throwsA(isA<AuthFailure>()));
      result = {
        'cityCode': '430200',
        'items': [homeFixture(), homeFixture()],
      };
      await expectLater(repository.list('430200'), throwsA(isA<AuthFailure>()));
      for (final url in [
        'http://example.invalid/image',
        'https://example.invalid/image?access_token=secret',
        'https://user:password@example.invalid/image',
      ]) {
        final row = homeFixture();
        (row['document'] as Map)['cover'] = url;
        expect(() => HomeContent.parse(row), throwsA(isA<AuthFailure>()));
      }
      final video = homeFixture(mode: 'video');
      (video['document'] as Map)['video'] = null;
      expect(() => HomeContent.parse(video), throwsA(isA<AuthFailure>()));
    },
  );
  test('late data from a replaced session cannot be displayed', () async {
    var session = homeSession('first');
    final pending = Completer<Map<String, dynamic>>();
    final repository = HomeContentRepository(
      readSession: () async => session,
      request: (id, params, actor) => pending.future,
    );
    final request = repository.list('430200');
    await Future<void>.delayed(Duration.zero);
    session = homeSession('second');
    pending.complete(
      envelope({
        'cityCode': '430200',
        'items': [homeFixture()],
      }),
    );
    await expectLater(request, throwsA(isA<AuthFailure>()));
  });
  test(
    'likes send desired state and current city, never a client member id',
    () async {
      final calls = <Map<String, dynamic>>[];
      final repository = HomeContentRepository(
        readSession: () async => homeSession('first'),
        request: (id, params, actor) async {
          expect(id, 'K261002001971');
          calls.add(params);
          return envelope({
            'contentRef': 'fixture',
            'liked': params['liked'],
            'likeCount': params['liked'] == true ? 8 : 7,
          });
        },
      );
      final item = HomeContent.parse(homeFixture());
      expect(await repository.like(item, true, '430200'), (
        count: 8,
        liked: true,
      ));
      expect(await repository.like(item, false, '430200'), (
        count: 7,
        liked: false,
      ));
      expect(calls, [
        {'contentRef': 'fixture', 'liked': true, 'cityCode': '430200'},
        {'contentRef': 'fixture', 'liked': false, 'cityCode': '430200'},
      ]);
      expect(
        item.liked,
        false,
      ); // Only confirmed UI updates change displayed state.
    },
  );
}
