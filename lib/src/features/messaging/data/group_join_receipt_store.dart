import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An account-scoped receipt is a lookup hint, never membership authority.
/// QR codes and application notes are deliberately not retained here.
class GroupJoinReceiptStore {
  GroupJoinReceiptStore(String account, {FlutterSecureStorage? storage})
    : _key = 'kingclub.chat.group-join-receipts.$account',
      _storage = storage ?? const FlutterSecureStorage();

  final String _key;
  final FlutterSecureStorage _storage;
  static final _locks = <String, Future<void>>{};

  Future<T> _exclusive<T>(Future<T> Function() work) async {
    final result = (_locks[_key] ?? Future<void>.value()).then((_) => work());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _locks[_key] = tail;
    try {
      return await result;
    } finally {
      if (identical(_locks[_key], tail)) _locks.remove(_key);
    }
  }

  Future<Map<String, dynamic>> _read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<String?> application(String groupId) => _exclusive(() async {
    final value = (await _read())[groupId];
    return value is String &&
            RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
                .hasMatch(value)
        ? value
        : null;
  });

  Future<void> save(String groupId, String applicationId) =>
      _exclusive(() async {
        final entries = await _read();
        entries.remove(groupId);
        entries[groupId] = applicationId;
        while (entries.length > 200) {
          entries.remove(entries.keys.first);
        }
        await _storage.write(key: _key, value: jsonEncode(entries));
      });

  Future<void> forget(String groupId, String applicationId) =>
      _exclusive(() async {
        final entries = await _read();
        if (entries[groupId] != applicationId) return;
        entries.remove(groupId);
        await _storage.write(key: _key, value: jsonEncode(entries));
      });
}
