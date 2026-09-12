import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../media/media_cache.dart';

class SecureSessionStore {
  static final changes = StreamController<void>.broadcast();
  SecureSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _deviceKey = 'kingclub.device.id';
  static const _sessionKey = 'kingclub.auth.session';
  final FlutterSecureStorage _storage;

  Future<String> deviceId() async {
    final current = await _storage.read(key: _deviceKey);
    if (current != null && current.length >= 8) return current;
    final created = 'android_${const Uuid().v4().replaceAll('-', '_')}';
    await _storage.write(key: _deviceKey, value: created);
    return created;
  }

  Future<void> saveSession(Map<String, dynamic> value) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(value));
    changes.add(null);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
    changes.add(null);
    try {
      await MediaCache.shared.clear(privateOnly: true);
    } catch (_) {
      /* Credentials are already revoked locally. */
    }
  }

  Future<Map<String, dynamic>?> readSession() async {
    final value = await _storage.read(key: _sessionKey);
    if (value == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(value) as Map);
    } catch (_) {
      await _storage.delete(key: _sessionKey);
      return null;
    }
  }
}
