import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';

class KeychainFixture extends FlutterSecureStorage {
  KeychainFixture({this.device = false});
  final bool device;
  bool migrated = false;
  int legacyReads = 0;
  String get value => device
      ? 'fixture-existing-device'
      : jsonEncode({'sessionId': 'fixture-session'});

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
    expect(key, device ? 'kingclub.device.id' : 'kingclub.auth.session');
    if (iOptions?.accessibility ==
        KeychainAccessibility.first_unlock_this_device) {
      return migrated ? value : null;
    }
    legacyReads++;
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final device in [false, true]) {
    test('upgrades legacy key protection in place (device=$device)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final storage = KeychainFixture(device: device);
      final methods = <String>[];
      const channel = MethodChannel('kingclub/system-calls');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.arguments, isNull);
            expect(call.method, 'prepareCredentials');
            methods.add(call.method);
            storage.migrated = true;
            return true;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final store = SecureSessionStore(storage);
      if (device) {
        expect(await store.deviceId(), 'fixture-existing-device');
        expect(await store.deviceId(), 'fixture-existing-device');
      } else {
        expect((await store.readSession())?['sessionId'], 'fixture-session');
        expect((await store.readSession())?['sessionId'], 'fixture-session');
      }
      expect(storage.legacyReads, 1);
      expect(methods, ['prepareCredentials']);
    });
  }
}
