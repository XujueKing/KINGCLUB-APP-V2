import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Presentation preference only. Never authorizes a purchase or admission.
class TogetherReadHistory {
  TogetherReadHistory(this.account, [FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final String account;
  final FlutterSecureStorage _storage;
  final _refs = <String>{};
  String get _key => 'kingclub.together.viewed.$account';
  Future<Set<String>> load() async {
    try {
      final raw = await _storage.read(key: _key);
      final value = raw == null ? null : jsonDecode(raw);
      if (value is List) _refs.addAll(value.whereType<String>().take(200));
    } catch (_) {
      /* A missing preference never grants the direct-buy shortcut. */
    }
    return {..._refs};
  }

  Future<void> mark(String ref) async {
    _refs.remove(ref);
    _refs.add(ref);
    while (_refs.length > 200) {
      _refs.remove(_refs.first);
    }
    try {
      await _storage.write(key: _key, value: jsonEncode(_refs.toList()));
    } catch (_) {
      /* Keep session preference. */
    }
  }
}
