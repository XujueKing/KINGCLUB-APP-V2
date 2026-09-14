import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_member_avatar.dart';

void main() {
  test('late failed request cannot evict a replacement profile', () async {
    final cache = <String, Future<Map<String, dynamic>>>{};
    final old = Completer<Map<String, dynamic>>();
    final first = cachedChatAvatarProfile(cache, 'friend', () => old.future);
    final failed = expectLater(first, throwsStateError);
    cache.clear();
    final next = cachedChatAvatarProfile(
      cache,
      'friend',
      () async => {'name': 'current'},
    );
    old.completeError(StateError('old network failure'));
    await failed;
    expect(await next, {'name': 'current'});
    expect(identical(cache['friend'], next), isTrue);
  });
  test('one in-flight request is shared and failures are retryable', () async {
    final cache = <String, Future<Map<String, dynamic>>>{};
    int requests = 0;
    Future<Map<String, dynamic>> load() async {
      requests++;
      throw StateError('offline');
    }

    final first = cachedChatAvatarProfile(cache, 'friend', load);
    expect(
      identical(first, cachedChatAvatarProfile(cache, 'friend', load)),
      isTrue,
    );
    await expectLater(first, throwsStateError);
    expect(cache, isEmpty);
    expect(
      await cachedChatAvatarProfile(cache, 'friend', () async => {'ok': true}),
      {'ok': true},
    );
    expect(requests, 1);
  });
}
