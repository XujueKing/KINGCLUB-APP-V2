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

  Future<Map<String, int>> _confirmed() async {
    final raw = await _storage.read(key: '$_key.confirmed');
    return raw == null ? {} : Map<String, int>.from(jsonDecode(raw) as Map);
  }

  /// Local display state survives successful delivery of the read receipt.
  /// Pending intents stay separate so recovery does not resend confirmed reads.
  Future<Map<String, int>> displayWatermarks() => _exclusive(() async {
    final values = await _confirmed();
    for (final entry in (await _read()).entries) {
      if (entry.value > (values[entry.key] ?? 0)) {
        values[entry.key] = entry.value;
      }
    }
    return values;
  });

  Future<bool> put(String peer, int sequence) => _exclusive(() async {
    if (account.isEmpty || peer.isEmpty || sequence <= 0) {
      throw ArgumentError('Invalid read watermark');
    }
    final values = await _read();
    if ((values[peer] ?? 0) >= sequence) return false;
    values[peer] = sequence;
    await _storage.write(key: _key, value: jsonEncode(values));
    return true;
  });

  Future<void> acknowledge(String peer, int sequence) => _exclusive(() async {
    final values = await _read();
    final pending = values[peer];
    if (pending == null || pending > sequence) return;
    final confirmed = await _confirmed();
    if (pending > (confirmed[peer] ?? 0)) {
      confirmed[peer] = pending;
      // Save the display watermark first. A crash can leave a redundant intent,
      // but must never erase both the pending and confirmed read positions.
      await _storage.write(
        key: '$_key.confirmed',
        value: jsonEncode(confirmed),
      );
    }
    values.remove(peer);
    await _storage.write(key: _key, value: jsonEncode(values));
  });
}
