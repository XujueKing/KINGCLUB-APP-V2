import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Presentation only. Membership and message access remain server-authoritative.
class GroupDirectoryStore {
  GroupDirectoryStore(String account, {FlutterSecureStorage? storage})
    : _key = 'kingclub.chat.joined-groups.v1.$account',
      _storage = storage ?? const FlutterSecureStorage();

  final String _key;
  final FlutterSecureStorage _storage;

  Future<List<Map<String, dynamic>>> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.length > 512000) return [];
    return parse(jsonDecode(raw));
  }

  Future<void> save(List<Map<String, dynamic>> items) => _storage.write(
    key: _key,
    value: jsonEncode(parse(items.take(1000).toList())),
  );

  static List<Map<String, dynamic>> parse(Object? value) {
    if (value is! List) throw const FormatException('群列表格式无效');
    return value.map((item) {
      if (item is! Map ||
          item['groupId'] is! String ||
          (item['groupId'] as String).isEmpty ||
          (item['groupId'] as String).length > 128 ||
          item['groupName'] is! String ||
          (item['groupName'] as String).length > 100 ||
          item['memberCount'] is! int ||
          (item['memberCount'] as int) < 0) {
        throw const FormatException('群列表格式无效');
      }
      return <String, dynamic>{
        'groupId': item['groupId'],
        'groupName': item['groupName'],
        'memberCount': item['memberCount'],
      };
    }).toList();
  }
}
