import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// User-confirmed group operations keep their identity until acknowledged.
/// This journal never executes an operation by itself.
class GroupRequestStore {
  GroupRequestStore(String account, {FlutterSecureStorage? storage})
    : _key = 'kingclub.chat.group-requests.$account',
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
    final value = await _storage.read(key: _key);
    return value == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<String> identity(String fingerprint) => _exclusive(() async {
    final entries = await _read();
    final existing = entries[fingerprint];
    if (existing is String) return existing;
    if (entries.length >= 200) throw StateError('待确认的群操作较多，请先处理已有操作');
    final id = const Uuid().v4();
    entries[fingerprint] = id;
    await _storage.write(key: _key, value: jsonEncode(entries));
    return id;
  });
  Future<void> acknowledge(String fingerprint, String id) =>
      _exclusive(() async {
        final entries = await _read();
        if (entries[fingerprint] != id) return;
        entries.remove(fingerprint);
        await _storage.write(key: _key, value: jsonEncode(entries));
      });
}
