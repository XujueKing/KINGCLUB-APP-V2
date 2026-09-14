import 'member_qr_memory.dart';

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
    final previous = await readSession();
    final changed = !_sameBinding(previous, value);
    if (changed) {
      MemberQrMemory.clear();
    } else {
      MemberQrMemory.clearPresentation();
    }
    await _storage.write(key: _sessionKey, value: jsonEncode(value));
    if (changed) changes.add(null);
  }

  // Refreshing profile data on app resume is not a new login. Keep active
  // media drafts and uploads bound until credentials or access actually change.
  static bool _sameBinding(Map<String, dynamic>? a, Map<String, dynamic> b) {
    if (a == null) return false;
    for (final key in ['sessionId', 'apiKeyId', 'apiKey']) {
      final value = a[key];
      if (value is! String || value.isEmpty || value != b[key]) return false;
    }
    final oldAccount = a['account'], newAccount = b['account'];
    if (oldAccount is! Map || newAccount is! Map) return false;
    final account = oldAccount['userAccount'];
    if (account is! String ||
        account.isEmpty ||
        account != newAccount['userAccount'] ||
        oldAccount['accountStatus'] != newAccount['accountStatus']) {
      return false;
    }
    final oldMembership = a['membership'], newMembership = b['membership'];
    if (oldMembership is! Map || newMembership is! Map) return false;
    return oldMembership['status'] == newMembership['status'] &&
        oldMembership['registrationStatus'] ==
            newMembership['registrationStatus'];
  }

  Future<void> clearSession() async {
    MemberQrMemory.clear();
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
      MemberQrMemory.clear();
      await _storage.delete(key: _sessionKey);
      return null;
    }
  }
}
