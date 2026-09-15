import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_avatar_snapshot.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> session;
  late ChatAvatarSnapshot cache;
  final profile = <String, dynamic>{
    'avatar': {
      'fileId': 'image-1',
      'path': '/kingclub/profile-media/image-1',
      'headers': {'secret': 'not-persisted'},
    },
  };
  Future<Map<String, dynamic>> offline() async =>
      throw const AuthFailure('NETWORK_ERROR', 'offline');
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    session = {
      'sessionId': 'session-a',
      'account': {'userAccount': 'a'},
    };
    cache = ChatAvatarSnapshot(session: () async => session);
  });
  test('own avatar uses owner endpoint and persists no signed URL', () async {
    final calls = <String>[];
    final own = <String, dynamic>{
      'avatar': {
        'fileId': 'own-file',
        'path': '/attachments/own-file?token=private.token',
      },
    };
    final repository = MessagingRepository(
      account: 'a',
      call: (method, params) async {
        calls.add(method);
        if (method == 'K260912000501') {
          expect(params, isEmpty);
          return own;
        }
        expect(params, {'peer': 'peer'});
        return profile;
      },
    );
    await cache.load('a', 'a', () => repository.avatarProfile('a'));
    expect(await cache.load('a', 'a', offline), {
      'avatar': {'fileId': 'own-file', 'cacheOnly': true},
    });
    expect((await const FlutterSecureStorage().readAll()).values, ['own-file']);
    await repository.avatarProfile('peer');
    expect(calls, ['K260912000501', 'K260913000612']);
  });
  test(
    'restart restores only image ID after network error, scoped to viewer',
    () async {
      await cache.load('a', 'peer', () async => profile);
      final values = await const FlutterSecureStorage().readAll();
      expect(values.values, ['image-1']);
      final reopened = ChatAvatarSnapshot(session: () async => session);
      expect(await reopened.load('a', 'peer', offline), {
        'avatar': {'fileId': 'image-1', 'cacheOnly': true},
      });
      session = {
        'sessionId': 'session-b',
        'account': {'userAccount': 'b'},
      };
      await expectLater(
        reopened.load('b', 'peer', offline),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
  for (final removed in [false, true]) {
    test(
      '${removed ? "removed" : "denied"} avatar cannot reappear offline',
      () async {
        await cache.load('a', 'peer', () async => profile);
        if (removed) {
          await cache.load('a', 'peer', () async => {});
        } else {
          await expectLater(
            cache.load(
              'a',
              'peer',
              () async => throw const AuthFailure('ACCESS_DENIED', 'denied'),
            ),
            throwsA(isA<AuthFailure>()),
          );
        }
        await expectLater(
          cache.load('a', 'peer', offline),
          throwsA(isA<AuthFailure>()),
        );
        expect(await const FlutterSecureStorage().readAll(), isEmpty);
      },
    );
  }
  test('account switch discards late authorized response', () async {
    final response = Completer<Map<String, dynamic>>();
    final called = Completer<void>();
    final loading = cache.load('a', 'peer', () {
      called.complete();
      return response.future;
    });
    final check = expectLater(loading, throwsA(isA<AuthFailure>()));
    await called.future;
    session = {
      'sessionId': 'session-b',
      'account': {'userAccount': 'b'},
    };
    response.complete(profile);
    await check;
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });
}
