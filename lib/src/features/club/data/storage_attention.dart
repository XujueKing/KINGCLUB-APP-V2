import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/session/secure_session_store.dart';
import 'storage_repository.dart';

/// Storage visibility is independent of whether a system message was read.
class StorageAttention extends ChangeNotifier {
  StorageAttention(
    this.repository, {
    Future<String?> Function()? account,
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
  }) : account = account ?? _account,
       read = read ?? ((key) => const FlutterSecureStorage().read(key: key)),
       write =
           write ??
           ((key, value) =>
               const FlutterSecureStorage().write(key: key, value: value));
  final StorageRepository repository;
  final Future<String?> Function() account;
  final Future<String?> Function(String) read;
  final Future<void> Function(String, String) write;
  static Future<String?> _account() async =>
      (await SecureSessionStore().readSession())?['account']?['userAccount']
          as String?;
  String? _owner;
  Set<String> _seen = {};
  List<StorageItem> _items = [];
  int _epoch = 0;
  bool _disposed = false;
  bool get unread => _items.any((item) => !_seen.contains(_fingerprint(item)));
  String _fingerprint(StorageItem item) => jsonEncode([
    item.ref,
    item.quantity,
    item.remainingPercent,
    item.status,
    item.storedAt,
  ]);
  String _key(String owner) => 'kingclub.storage.viewed.$owner';
  void reset() {
    _epoch++;
    _owner = null;
    _seen = {};
    _items = [];
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final generation = ++_epoch;
    try {
      final owner = await account();
      if (_disposed || generation != _epoch) return;
      if (owner == null) {
        reset();
        return;
      }
      final saved = await read(_key(owner));
      final items = await repository.list();
      if (_disposed || generation != _epoch || await account() != owner) return;
      _owner = owner;
      _seen = saved == null
          ? {}
          : (jsonDecode(saved) as List).cast<String>().toSet();
      _items = items;
      notifyListeners();
    } catch (_) {
      /* Retain the last known dot on transient network errors. */
    }
  }

  Future<void> viewed(List<StorageItem> items) async {
    final generation = ++_epoch;
    try {
      final owner = await account();
      if (_disposed || generation != _epoch || owner == null) return;
      if (_owner != null && _owner != owner) return;
      final seen = items.map(_fingerprint).toSet();
      await write(_key(owner), jsonEncode(seen.toList()));
      if (_disposed || generation != _epoch || await account() != owner) return;
      _owner = owner;
      _items = items;
      _seen = seen;
      notifyListeners();
    } catch (_) {
      /* A failed read/write must not falsely acknowledge new storage. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}
