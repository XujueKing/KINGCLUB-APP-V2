import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Per-account read watermarks. Acknowledging an older request must
/// never erase a newer watermark written by another page/recovery worker.
class ChatReadOutbox {
  ChatReadOutbox(
    this.account, {
    this.group = false,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final String account;
  final bool group;
  final FlutterSecureStorage _storage;
  String get _key => group
      ? 'kingclub.chat.group-read-outbox.$account'
      : 'kingclub.chat.read-outbox.$account';
  static final _locks = <String, Future<void>>{};

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final result = (_locks[_key] ?? Future<void>.value()).then((_) => action());
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

  Future<Map<String, int>> _read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return {};
    return Map<String, int>.from(jsonDecode(raw) as Map);
  }

  Future<Map<String, int>> read() => _exclusive(_read);

  Future<void> put(String peer, int sequence) => _exclusive(() async {
    if (account.isEmpty || peer.isEmpty || sequence <= 0) {
      throw ArgumentError('Invalid read watermark');
    }
    final values = await _read();
    if ((values[peer] ?? 0) >= sequence) return;
    values[peer] = sequence;
    await _storage.write(key: _key, value: jsonEncode(values));
  });

  Future<void> acknowledge(String peer, int sequence) => _exclusive(() async {
    final values = await _read();
    final pending = values[peer];
    if (pending == null || pending > sequence) return;
    values.remove(peer);
    await _storage.write(key: _key, value: jsonEncode(values));
  });
}
