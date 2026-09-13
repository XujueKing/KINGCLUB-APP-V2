import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'messaging_repository.dart';

/// Uses the authenticated account-bound client, never a caller supplied owner.
class GroupChatRepository {
  GroupChatRepository(this.messaging);
  final MessagingRepository messaging;
  String get account => messaging.account;
  String? _createFingerprint, _createRequestId;
  bool _creating = false;

  Future<Map<String, dynamic>> create({
    required String name,
    required Iterable<String> members,
  }) async {
    if (_creating) throw StateError('正在创建群聊');
    final selected = members.toSet().toList()..sort();
    name = name.trim();
    if (name.isEmpty ||
        name.length > 64 ||
        selected.isEmpty ||
        selected.length > 199 ||
        selected.contains(account)) {
      throw ArgumentError('请选择1至199位好友，并填写群名称');
    }
    final fingerprint = jsonEncode({'name': name, 'members': selected});
    if (_createFingerprint != fingerprint) {
      _createFingerprint = fingerprint;
      _createRequestId = const Uuid().v4();
    }
    _creating = true;
    try {
      final result = await messaging.call('K260913000617', {
        'requestId': _createRequestId,
        'name': name,
        'members': selected,
      });
      if (result['groupId'] is! String ||
          (result['groupId'] as String).isEmpty) {
        throw const FormatException('Invalid group acknowledgement');
      }
      _createFingerprint = null;
      _createRequestId = null;
      return result;
    } finally {
      _creating = false;
    }
  }

  Future<Map<String, dynamic>> list({String? before, int limit = 50}) =>
      messaging.call('K260913000618', {'before': ?before, 'limit': limit});
  Future<Map<String, dynamic>> details(String groupId) =>
      messaging.call('K260913000619', {'groupId': groupId});
  Future<Map<String, dynamic>> sendText({
    required String groupId,
    required String clientMessageId,
    required String text,
  }) => messaging.call('K260913000620', {
    'groupId': groupId,
    'clientMessageId': clientMessageId,
    'text': text,
  });
  Future<Map<String, dynamic>> history(
    String groupId, {
    int? before,
    int? after,
    int limit = 50,
  }) {
    if (before != null && after != null) {
      throw ArgumentError('Choose one history direction');
    }
    return messaging.call('K260913000621', {
      'groupId': groupId,
      'before': ?before,
      'after': ?after,
      'limit': limit,
    });
  }

  Future<Map<String, dynamic>> markRead(String groupId, int sequence) =>
      messaging.call('K260913000622', {
        'groupId': groupId,
        'sequence': sequence,
      });
}
