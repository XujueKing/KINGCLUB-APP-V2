import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_device_identity_store.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class Storage extends FlutterSecureStorage {
  final values = <String, String>{};
  int writes = 0;
  bool failWrite = false;
  Completer<void>? reading;
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await reading?.future;
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrite) throw StateError('synthetic secure write failed');
    writes++;
    values[key] = value!;
  }
}

class Sessions extends SecureSessionStore {
  String account = 'synthetic-a', device = 'synthetic-device-1';
  @override
  Future<Map<String, dynamic>?> readSession() async => {
    'account': {'userAccount': account},
    'sessionId': 'synthetic-session',
  };
  @override
  Future<String> deviceId() async => device;
}

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  group(
    'stored seed with real Rust identity derivation',
    () {
      late Storage storage;
      late Sessions sessions;
      late DynamicLibrary library;
      final opened = <NovoRudpSecureSession>[];
      Future<NovoRudpSecureSession> open() async {
        final result = await NovoRudpDeviceIdentityStore(
          storage: storage,
          sessions: sessions,
        ).open(account: sessions.account, library: library);
        opened.add(result);
        return result;
      }

      setUp(() {
        storage = Storage();
        sessions = Sessions();
        library = DynamicLibrary.open(path!);
      });
      tearDown(() {
        for (final item in opened) {
          item.dispose();
        }
        opened.clear();
      });
      test(
        'concurrent stores reuse one persisted identity across new sessions',
        () async {
          final pair = await Future.wait([open(), open()]);
          final peer = pair[0].peerId;
          expect(pair[1].peerId, peer);
          expect(storage.writes, 1);
          pair[0].dispose();
          pair[1].dispose();
          expect((await open()).peerId, peer);
          expect(storage.writes, 1);
        },
      );
      test(
        'different account and device scopes cannot reuse another seed',
        () async {
          final a = (await open()).peerId;
          sessions.account = 'synthetic-b';
          MemberQrMemory.clear();
          final b = (await open()).peerId;
          expect(b, isNot(a));
          sessions.device = 'synthetic-device-2';
          MemberQrMemory.clear();
          expect((await open()).peerId, isNot(b));
          expect(storage.values.length, 3);
          expect(
            storage.values.keys.any((key) => key.contains('synthetic')),
            isFalse,
          );
        },
      );
      test('corrupt saved identity is not silently replaced', () async {
        await open();
        storage.values[storage.values.keys.single] = 'broken';
        await expectLater(open(), throwsStateError);
        expect(storage.writes, 1);
        expect(storage.values.values.single, 'broken');
      });
      test(
        'logout while secure read waits cannot write or return identity',
        () async {
          storage.reading = Completer<void>();
          final pending = open();
          await Future<void>.delayed(Duration.zero);
          MemberQrMemory.clear();
          storage.reading!.complete();
          await expectLater(pending, throwsStateError);
          expect(storage.writes, 0);
        },
      );
      test(
        'failed write does not return an unpersisted identity or block retries',
        () async {
          storage.failWrite = true;
          await expectLater(open(), throwsStateError);
          expect(storage.values, isEmpty);
          storage.failWrite = false;
          expect((await open()).peerId, startsWith('novovm-ed25519:'));
        },
      );
    },
    skip: path == null
        ? 'Set NOVORUDP_NATIVE_LIBRARY to the built native library'
        : false,
  );
}
