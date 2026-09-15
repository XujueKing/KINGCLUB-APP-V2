import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';

/// Stores only an immutable image ID, never a profile or a media access grant.
class ChatAvatarSnapshot {
  ChatAvatarSnapshot({
    FlutterSecureStorage? storage,
    Future<Map<String, dynamic>?> Function()? session,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _session = session ?? SecureSessionStore().readSession;

  final FlutterSecureStorage _storage;
  final Future<Map<String, dynamic>?> Function() _session;
  static final _revisions = <String, int>{};
  static final _settled = <String, int>{};
  static final _writes = <String, Future<void>>{};

  Future<Map<String, dynamic>> load(
    String viewer,
    String peer,
    Future<Map<String, dynamic>> Function() fetch,
  ) async {
    final key = 'kingclub.avatar-id.${jsonEncode([viewer, peer])}';
    final revision = (_revisions[key] ?? 0) + 1;
    _revisions[key] = revision;
    final initial = await _session();
    bool same(Map<String, dynamic>? current) =>
        initial?['sessionId'] != null &&
        current?['sessionId'] == initial?['sessionId'] &&
        (current?['account'] as Map?)?['userAccount'] == viewer;
    Future<bool> active() async {
      final current = await _session();
      // Starting another page's request is not a revocation. Only a newer
      // completed authorization decision can supersede this response.
      return (_settled[key] ?? 0) <= revision && same(current);
    }

    Future<void> save(String? id) async {
      final write = (_writes[key] ?? Future<void>.value()).then((_) async {
        if (!await active()) return;
        if (id == null) {
          await _storage.delete(key: key);
        } else {
          await _storage.write(key: key, value: id);
        }
      });
      final tail = write.catchError((Object _) {});
      _writes[key] = tail;
      await tail;
      if (identical(_writes[key], tail)) _writes.remove(key);
    }

    try {
      final profile = await fetch();
      if (!await active()) {
        throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
      }
      _settled[key] = revision;
      final avatar = profile['avatar'];
      final id = avatar is Map ? avatar['fileId'] : null;
      final path = avatar is Map ? avatar['path'] : null;
      final valid =
          id is String &&
          RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(id) &&
          path is String &&
          (viewer == peer
              ? RegExp(
                  r'^/attachments/[A-Za-z0-9_-]+\?token=[A-Za-z0-9%._~-]+$',
                ).hasMatch(path)
              : path.startsWith('/kingclub/profile-media/') &&
                    !path.contains('..') &&
                    !path.contains('?') &&
                    !path.contains('#'));
      await save(valid ? id : null);
      if (!await active()) {
        throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
      }
      return profile;
    } on AuthFailure catch (error) {
      if (!await active()) rethrow;
      if (error.code != 'NETWORK_ERROR') {
        _settled[key] = revision;
        await save(null);
        rethrow;
      }
      String? id;
      try {
        id = await _storage.read(key: key);
      } catch (_) {
        rethrow;
      }
      if (!await active() ||
          id == null ||
          !RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(id)) {
        rethrow;
      }
      return {
        'avatar': {'fileId': id, 'cacheOnly': true},
      };
    }
  }
}
