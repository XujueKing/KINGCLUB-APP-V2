import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ChatOutbox {
  Future<List<Map<String, dynamic>>> read();
  Future<void> put(Map<String, dynamic> message);
  Future<void> remove(String clientMessageId);
}

/// Small pending message/reference queue, encrypted by the platform secure storage.
/// Per-account serialization prevents two open conversations overwriting it.
class SecureChatOutbox implements ChatOutbox {
  SecureChatOutbox(String account, {FlutterSecureStorage? storage})
    : _key = 'kingclub.chat.outbox.$account',
      _storage = storage ?? const FlutterSecureStorage();
  final String _key;
  final FlutterSecureStorage _storage;
  static final _locks = <String, Future<void>>{};

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _locks[_key] ?? Future<void>.value();
    final result = previous.then((_) => action());
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

  Future<List<Map<String, dynamic>>> _read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> read() => _exclusive(_read);
  @override
  Future<void> put(Map<String, dynamic> message) => _exclusive(() async {
    final items = await _read();
    items.removeWhere(
      (item) => item['clientMessageId'] == message['clientMessageId'],
    );
    if (items.length >= 200) throw StateError('待发送消息较多，请先处理失败消息');
    items.add(message);
    await _storage.write(key: _key, value: jsonEncode(items));
  });
  @override
  Future<void> remove(String clientMessageId) => _exclusive(() async {
    final items = await _read();
    items.removeWhere((item) => item['clientMessageId'] == clientMessageId);
    await _storage.write(key: _key, value: jsonEncode(items));
  });
}
