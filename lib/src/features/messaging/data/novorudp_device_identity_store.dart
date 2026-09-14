import 'dart:convert';
import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_secure_session.dart';

class NovoRudpDeviceIdentityStore {
  NovoRudpDeviceIdentityStore({
    FlutterSecureStorage? storage,
    SecureSessionStore? sessions,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(
               storageNamespace: 'kingclub_novorudp_identity',
               resetOnError: false,
             ),
             iOptions: IOSOptions(
               accountName: 'kingclub_novorudp_identity',
               accessibility: KeychainAccessibility.unlocked_this_device,
               synchronizable: false,
             ),
           ),
       _sessions = sessions ?? SecureSessionStore();
  final FlutterSecureStorage _storage;
  final SecureSessionStore _sessions;
  static Future<void> _tail = Future<void>.value();

  Future<NovoRudpSecureSession> open({
    required String account,
    required DynamicLibrary library,
  }) {
    final generation = MemberQrMemory.generation;
    final result = _tail.then((_) => _open(account, library, generation));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _checkGeneration(int generation) {
    if (generation != MemberQrMemory.generation) throw StateError('登录状态已变化');
  }

  Future<void> _check(String account, int generation) async {
    _checkGeneration(generation);
    final current = await _sessions.readSession();
    _checkGeneration(generation);
    if (account.isEmpty ||
        (current?['account'] as Map?)?['userAccount'] != account ||
        current?['sessionId'] is! String) {
      throw StateError('网络身份不属于当前登录账号');
    }
  }

  Future<NovoRudpSecureSession> _open(
    String account,
    DynamicLibrary library,
    int generation,
  ) async {
    await _check(account, generation);
    final device = await _sessions.deviceId();
    _checkGeneration(generation);
    final digest = await const DartSha256().hash(
      utf8.encode(
        jsonEncode(['kingclub-network-identity-v1', account, device]),
      ),
    );
    _checkGeneration(generation);
    final key =
        'identity.v1.${digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    final stored = await _storage.read(key: key);
    await _check(account, generation);
    Uint8List? seed;
    try {
      if (stored == null) {
        final random = Random.secure();
        seed = Uint8List.fromList(
          List.generate(32, (_) => random.nextInt(256)),
        );
        await _storage.write(
          key: key,
          value: jsonEncode({'version': 1, 'seed': base64UrlEncode(seed)}),
        );
      } else {
        try {
          final value = jsonDecode(stored);
          if (value is! Map ||
              value['version'] != 1 ||
              value['seed'] is! String ||
              (value['seed'] as String).length > 48) {
            throw const FormatException();
          }
          seed = base64Url.decode(value['seed'] as String);
          if (seed.length != 32) throw const FormatException();
        } catch (_) {
          throw StateError('设备网络身份无法读取，请恢复或重新绑定');
        }
      }
      await _check(account, generation);
      return NovoRudpSecureSession.fromSeed(library: library, seed: seed);
    } finally {
      seed?.fillRange(0, seed.length, 0);
    }
  }
}
