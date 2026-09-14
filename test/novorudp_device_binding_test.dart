import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_device_binding.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  group('device binding coordinator with real native identity', () {
    late NovoRudpSecureSession identity;
    late Map<String, dynamic> key, challenge;
    const id = '11111111-1111-4111-8111-111111111111';
    setUp(() {
      identity = NovoRudpSecureSession.fromSeed(
        library: DynamicLibrary.open(path!),
        seed: Uint8List.fromList(List.filled(32, 31)),
      );
      final public = identity.peerId.split(':').last;
      key = {'bindingId': id, 'publicKey': public, 'peerId': identity.peerId};
      challenge = {
        'challengeId': id,
        'publicKey': public,
        'scopeHash': List.filled(32, 'ab').join(),
        'nonce': List.filled(32, 'cd').join(),
        'issuedAt': 1000,
        'expiresAt': 91000,
      };
    });
    tearDown(() => identity.dispose());
    NovoRudpDeviceBinding client(ChatApiCall call) => NovoRudpDeviceBinding(
      messaging: MessagingRepository(account: 'UM_SYNTHETIC', call: call),
      identity: identity,
    );
    test(
      'concurrent registration shares signed request and refreshes directory',
      () async {
        var registered = false, reads = 0, issues = 0, writes = 0;
        final binding = client((api, params) async {
          if (api.endsWith('672')) {
            reads++;
            return {
              'keys': registered ? [key] : [],
              'cacheSeconds': 0,
            };
          }
          if (api.endsWith('670')) {
            issues++;
            return challenge;
          }
          writes++;
          List<int> hex(String s) => [
            for (var i = 0; i < s.length; i += 2)
              int.parse(s.substring(i, i + 2), radix: 16),
          ];
          final public = hex(key['publicKey'] as String);
          expect(
            await Ed25519().verify(
              [
                ...utf8.encode('kingclub-device-binding-v1\u0000'),
                ...hex(challenge['scopeHash'] as String),
                ...hex(challenge['nonce'] as String),
                ...public,
              ],
              signature: Signature(
                hex(params['signature'] as String),
                publicKey: SimplePublicKey(public, type: KeyPairType.ed25519),
              ),
            ),
            true,
          );
          registered = true;
          return key;
        });
        final results = await Future.wait([
          binding.ensureRegistered(),
          binding.ensureRegistered(),
        ]);
        expect(results.map((v) => v.bindingId), [id, id]);
        expect([reads, issues, writes], [1, 1, 1]);
        await binding.ensureRegistered();
        expect([reads, issues, writes], [2, 1, 1]);
      },
    );
    test('uncertain registration retries exactly the pending proof', () async {
      var writes = 0, issues = 0;
      Map<String, dynamic>? previous;
      final binding = client((api, params) async {
        if (api.endsWith('672')) return {'keys': [], 'cacheSeconds': 0};
        if (api.endsWith('670')) {
          issues++;
          return challenge;
        }
        writes++;
        if (previous == null) {
          previous = Map.of(params);
          throw const SocketException('synthetic disconnect');
        }
        expect(params, previous);
        return key;
      });
      await expectLater(
        binding.ensureRegistered(),
        throwsA(isA<SocketException>()),
      );
      expect((await binding.ensureRegistered()).bindingId, id);
      expect([issues, writes], [1, 2]);
    });
    test(
      'wrong challenge key and late result after logout cannot register',
      () async {
        var writes = 0;
        final binding = client((api, params) async {
          if (api.endsWith('672')) return {'keys': [], 'cacheSeconds': 0};
          if (api.endsWith('670')) {
            return {...challenge, 'publicKey': List.filled(64, '0').join()};
          }
          writes++;
          return key;
        });
        await expectLater(binding.ensureRegistered(), throwsFormatException);
        final pending = Completer<Map<String, dynamic>>(),
            entered = Completer<void>();
        final late = client((api, params) async {
          if (api.endsWith('672')) return {'keys': [], 'cacheSeconds': 0};
          if (api.endsWith('670')) {
            entered.complete();
            return pending.future;
          }
          writes++;
          return key;
        });
        final result = late.ensureRegistered();
        await entered.future;
        MemberQrMemory.clear();
        pending.complete(challenge);
        await expectLater(result, throwsStateError);
        expect(writes, 0);
      },
    );
    test('revocation closes native identity immediately and can retry HTTP failure', () async {
      var revokes = 0;
      final binding = client((api, params) async {
        expect(api, 'K260915000673');
        revokes++;
        if (revokes == 1) throw const SocketException('synthetic disconnect');
        return {'revoked': true};
      });
      final record = NetworkDeviceKey.parse(key);
      await expectLater(
        binding.revoke(record),
        throwsA(isA<SocketException>()),
      );
      expect(() => identity.peerId, throwsStateError);
      await binding.revoke(record);
      expect(revokes, 2);
    });
  }, skip: path == null ? 'Set NOVORUDP_NATIVE_LIBRARY' : false);
}
