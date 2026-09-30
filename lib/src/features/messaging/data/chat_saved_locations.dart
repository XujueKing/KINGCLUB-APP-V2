import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'chat_location.dart';

/// Account-scoped on-device bookmarks; no message text or sender metadata.
class ChatSavedLocations {
  ChatSavedLocations(this.account, [FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final String account;
  final FlutterSecureStorage _storage;
  String get _key => 'kingclub.savedLocations.${Uri.encodeComponent(account)}';
  Future<List<ChatLocation>> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('收藏数据无效');
    return decoded
        .map(ChatLocation.tryParse)
        .whereType<ChatLocation>()
        .toList();
  }

  Future<void> save(List<ChatLocation> places) async {
    if (account.isEmpty) throw StateError('尚未登录');
    if (places.length > 200) throw StateError('最多收藏200个地点');
    await _storage.write(
      key: _key,
      value: jsonEncode(places.map((p) => p.toJson()).toList()),
    );
  }
}
