import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureSessionStore {
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

  Future<void> saveSession(Map<String, dynamic> value) =>
      _storage.write(key: _sessionKey, value: jsonEncode(value));

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
