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

  static Future<void>? _mutation;
  Future<T> _exclusive<T>(Future<T> Function() work) async {
    final result = (_mutation ?? Future<void>.value()).then((_) => work());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _mutation = tail;
    try {
      return await result;
    } finally {
      if (identical(_mutation, tail)) _mutation = null;
    }
  }

  Future<void> saveSession(Map<String, dynamic> value) =>
      _exclusive(() => _save(value));

  Future<bool> saveSessionIfCurrent(
    Map<String, dynamic> expected,
    Map<String, dynamic> value,
  ) => _exclusive(() async {
    if (!_sameRevision(await readSession(), expected)) return false;
    await _save(value);
    return true;
  });

  /// Membership reads may finish after a refresh-token rotation. Apply only
  /// their profile fields to the current session, never the old token snapshot.
  Future<bool> saveMembershipIfCurrent(
    Map<String, dynamic> expected, {
    required Map<String, dynamic> account,
    required Map<String, dynamic> membership,
  }) => _exclusive(() async {
    final current = await readSession();
    if (!_sameCredentials(current, expected) ||
        account['userAccount'] !=
            (current!['account'] as Map?)?['userAccount']) {
      return false;
    }
    await _save({...current, 'account': account, 'membership': membership});
    return true;
  });

  static bool _sameCredentials(
    Map<String, dynamic>? a,
    Map<String, dynamic> b,
  ) {
    if (a == null) return false;
    for (final key in ['sessionId', 'apiKeyId', 'apiKey']) {
      final value = a[key];
      if (value is! String || value.isEmpty || value != b[key]) return false;
    }
    return (a['account'] as Map?)?['userAccount'] ==
        (b['account'] as Map?)?['userAccount'];
  }

  /// An old request cannot replace or revoke a renewed session, even when
  /// the server retains the session ID and API key during token rotation.
  static bool _sameRevision(
    Map<String, dynamic>? current,
    Map<String, dynamic> expected,
  ) {
    if (!_sameCredentials(current, expected)) return false;
    for (final field in [
      'refreshToken',
      'refreshTokenVersion',
      'expiresAt',
      'refreshExpiresAt',
    ]) {
      if (current![field] != expected[field]) return false;
    }
    return true;
  }

  Future<void> _save(Map<String, dynamic> value) async {
    final previous = await readSession();
    final changed = !_sameBinding(previous, value);
    if (changed) {
      MemberQrMemory.clear();
      await MediaCache.shared.cancelPending();
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

  Future<bool> clearSessionIfCurrent(Map<String, dynamic> expected) =>
      _exclusive(() async {
        if (!_sameRevision(await readSession(), expected)) return false;
        await _clear();
        return true;
      });

  Future<void> clearSession() => _exclusive(_clear);

  Future<void> _clear() async {
    MemberQrMemory.clear();
    await _storage.delete(key: _sessionKey);
    changes.add(null);
    try {
      await MediaCache.shared.cancelPending();
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
