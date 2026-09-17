import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ChatOutbox {
  Future<List<Map<String, dynamic>>> read();
  Future<void> put(Map<String, dynamic> message);
  Future<void> remove(String clientMessageId);
}

typedef PendingMessageReader = Future<List<Map<String, dynamic>>> Function();

/// Keeps pending references stable while history removes shared media.
/// The reader is lazy so ordinary history writes do not access secure storage.
abstract interface class ProtectedChatOutbox implements ChatOutbox {
  Future<T> protectReferences<T>(
    Future<T> Function(PendingMessageReader read) action,
  );
}

/// Small pending message/reference queue, encrypted by the platform secure storage.
/// Per-account serialization prevents two open conversations overwriting it.
class SecureChatOutbox implements ProtectedChatOutbox {
  SecureChatOutbox(String account, {FlutterSecureStorage? storage})
    : _account = account,
      _key = 'kingclub.chat.outbox.$account',
      _storage = storage ?? const FlutterSecureStorage();
  final String _account;
  static final _removed = StreamController<String>.broadcast();
  static Stream<String> get removedReferences => _removed.stream;
  final String _key;
  final FlutterSecureStorage _storage;
  static final _locks = <String, Future<void>>{};
  static final _sourceReferences =
      <String, Map<Object, Map<String, dynamic>>>{};

  /// Protect a source while it is being retained and handed to the durable
  /// queue. This lease contains metadata only, never source bytes or grants.
  Future<Future<void> Function()> holdMediaSource(
    Map<String, dynamic> message,
  ) async {
    final token = Object();
    await _exclusive(() async {
      (_sourceReferences[_key] ??= {})[token] = {
        'sender': _account,
        for (final field in const [
          'messageType',
          'clientMessageId',
          'voiceAssetId',
          'fileAssetId',
        ])
          if (message[field] != null) field: message[field],
      };
    });
    var released = false;
    return () async {
      if (released) return;
      released = true;
      await _exclusive(() async {
        final references = _sourceReferences[_key];
        references?.remove(token);
        if (references != null && references.isEmpty) {
          _sourceReferences.remove(_key);
        }
      });
      _removed.add(_account);
    };
  }

  Future<List<Map<String, dynamic>>> _readReferences() async => [
    ...await _read(),
    ...?_sourceReferences[_key]?.values,
  ];

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
  Future<T> protectReferences<T>(
    Future<T> Function(PendingMessageReader read) action,
  ) => _exclusive(() => action(_readReferences));

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
  Future<void> remove(String clientMessageId) async {
    await _exclusive(() async {
      final items = await _read();
      items.removeWhere((item) => item['clientMessageId'] == clientMessageId);
      await _storage.write(key: _key, value: jsonEncode(items));
    });
    _removed.add(_account);
  }
}
