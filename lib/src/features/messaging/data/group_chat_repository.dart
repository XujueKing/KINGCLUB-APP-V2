import 'package:cryptography/cryptography.dart';

import 'chat_location.dart';

import 'dart:convert';

import 'group_request_store.dart';
import 'group_join_receipt_store.dart';

import 'messaging_repository.dart';

/// Uses the authenticated account-bound client, never a caller supplied owner.
class GroupChatRepository {
  GroupChatRepository(this.messaging, {GroupRequestStore? requestStore})
    : _requestStore = requestStore ?? GroupRequestStore(messaging.account),
      _joinReceipts = GroupJoinReceiptStore(messaging.account);
  final GroupJoinReceiptStore _joinReceipts;
  final GroupRequestStore _requestStore;
  final MessagingRepository messaging;
  String get account => messaging.account;
  String? _createRequestId;
  bool _creating = false;
  bool _joining = false;
  bool _transferring = false;
  String? _transferRequestId;

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
    final fingerprint = jsonEncode({
      'operation': 'create',
      'name': name,
      'members': selected,
    });
    _creating = true;
    try {
      _createRequestId = await _requestStore.identity(fingerprint);
      final result = await messaging.call('K260913000617', {
        'requestId': _createRequestId,
        'name': name,
        'members': selected,
      });
      if (result['groupId'] is! String ||
          (result['groupId'] as String).isEmpty) {
        throw const FormatException('Invalid group acknowledgement');
      }
      await _requestStore.acknowledge(fingerprint, _createRequestId!);
      _createRequestId = null;
      return result;
    } finally {
      _creating = false;
    }
  }

  Future<Map<String, dynamic>> list({String? before, int limit = 50}) =>
      messaging.call('K260913000618', {'before': ?before, 'limit': limit});
  Future<Map<String, dynamic>> applyToGroup({
    required String groupId,
    required String code,
    required String note,
  }) async {
    if (_joining) {
      throw StateError('正在提交入群申请');
    }
    note = note.trim();
    if (!RegExp(r'^KC:G:[0-9A-F]{32}$').hasMatch(code) || note.length > 200) {
      throw ArgumentError('入群申请无效');
    }
    _joining = true;
    try {
      final digest = await Sha256().hash(
        utf8.encode(jsonEncode([groupId, code, note])),
      );
      final fingerprint = 'group-join-v1:${base64UrlEncode(digest.bytes)}';
      final id = await _requestStore.identity(fingerprint);
      final result = await messaging.call('K260914000658', {
        'requestId': id,
        'code': code,
        'note': note,
      });
      final status = result['status'];
      if (result['groupId'] != groupId ||
          result['changed'] is! bool ||
          !const [
            'pending',
            'accepted',
            'rejected',
            'canceled',
            'expired',
            'already_member',
          ].contains(status) ||
          (status != 'already_member' &&
              (result['applicationId'] is! String ||
                  !RegExp(
                    r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
                  ).hasMatch(result['applicationId'] as String)))) {
        throw const FormatException('入群申请回执无效');
      }
      if (result['applicationId'] is String) {
        await _joinReceipts.save(groupId, result['applicationId'] as String);
      }
      await _requestStore.acknowledge(fingerprint, id);
      return result;
    } finally {
      _joining = false;
    }
  }

  Future<String?> savedJoinApplication(String groupId) =>
      _joinReceipts.application(groupId);

  Future<String> cancelApplication({
    required String groupId,
    required String applicationId,
  }) async {
    final result = await messaging.call('K260916000685', {
      'groupId': groupId,
      'applicationId': applicationId,
    });
    if (result['groupId'] != groupId ||
        result['applicationId'] != applicationId ||
        result['changed'] is! bool ||
        !['canceled', 'expired'].contains(result['status'])) {
      throw const FormatException('撤回申请结果无效');
    }
    return result['status'] as String;
  }

  Future<void> forgetJoinApplication(String groupId, String applicationId) =>
      _joinReceipts.forget(groupId, applicationId);

  Future<String> ownApplicationStatus({
    required String groupId,
    required String applicationId,
  }) async {
    final result = await messaging.call('K260916000684', {
      'groupId': groupId,
      'applicationId': applicationId,
    });
    if (result['groupId'] != groupId ||
        result['applicationId'] != applicationId ||
        result['changed'] != false ||
        !const [
          'pending',
          'accepted',
          'rejected',
          'canceled',
          'expired',
        ].contains(result['status'])) {
      throw const FormatException('入群申请状态无效');
    }
    return result['status'] as String;
  }

  Future<Map<String, dynamic>> joinApplications(
    String groupId, {
    String? before,
    int limit = 50,
  }) => messaging.call('K260914000659', {
    'groupId': groupId,
    'before': ?before,
    'limit': limit,
  });

  Future<Map<String, dynamic>> reviewApplication({
    required String groupId,
    required String applicationId,
    required bool accept,
    required int membershipVersion,
  }) async {
    final result = await messaging.call('K260914000660', {
      'groupId': groupId,
      'applicationId': applicationId,
      'action': accept ? 'accept' : 'reject',
      'membershipVersion': membershipVersion,
    });
    if (result['groupId'] != groupId ||
        result['applicationId'] != applicationId ||
        result['changed'] is! bool ||
        ![
          accept ? 'accepted' : 'rejected',
          'expired',
        ].contains(result['status'])) {
      throw const FormatException('入群审核回执无效');
    }
    return result;
  }

  Future<Map<String, dynamic>> previewQr(String code) =>
      messaging.call('K260914000657', {'code': code});

  Future<Map<String, dynamic>> issueQr(String groupId) =>
      messaging.call('K260914000656', {'groupId': groupId});

  Future<Map<String, dynamic>> details(String groupId) =>
      messaging.call('K260913000619', {'groupId': groupId});
  Future<Map<String, dynamic>> sendImage({
    required String groupId,
    required String clientMessageId,
    required String assetId,
  }) => messaging.call('K260913000634', {
    'groupId': groupId,
    'clientMessageId': clientMessageId,
    'assetId': assetId,
  });
  Future<Map<String, dynamic>> sendLocation({
    required String groupId,
    required String clientMessageId,
    required ChatLocation location,
  }) => messaging.call('K260913000642', {
    'groupId': groupId,
    'clientMessageId': clientMessageId,
    'location': location.toJson(),
  });
  Future<Map<String, dynamic>> sendFile({
    required String groupId,
    required String clientMessageId,
    required String assetId,
  }) => messaging.call('K260914000653', {
    'groupId': groupId,
    'clientMessageId': clientMessageId,
    'assetId': assetId,
  });
  Future<Map<String, dynamic>> sendVideo({
    required String groupId,
    required String clientMessageId,
    required String assetId,
  }) => messaging.call('K260915000666', {
    'groupId': groupId,
    'clientMessageId': clientMessageId,
    'assetId': assetId,
  });
  Future<Map<String, dynamic>> sendVoice({
    required String groupId,
    required String clientMessageId,
    required String assetId,
  }) => messaging.call('K260913000639', {
    'groupId': groupId,
    'clientMessageId': clientMessageId,
    'assetId': assetId,
  });
  Future<Map<String, dynamic>> sendText({
    required String groupId,
    required String clientMessageId,
    required String text,
    String? replyToMessageId,
  }) => messaging.call('K260913000620', {
    'groupId': groupId,
    'clientMessageId': clientMessageId,
    'text': text,
    'replyToMessageId': ?replyToMessageId,
  });
  Future<Map<String, dynamic>> history(
    String groupId, {
    String? query,
    int? before,
    int? after,
    int limit = 50,
  }) {
    if (before != null && after != null) {
      throw ArgumentError('Choose one history direction');
    }
    return messaging.call('K260913000621', {
      'groupId': groupId,
      'query': ?query,
      'before': ?before,
      'after': ?after,
      'limit': limit,
    });
  }

  Future<Map<String, dynamic>> settings(
    String groupId, {
    bool? muted,
    bool? pinned,
    bool? hide,
  }) => messaging.call('K260913000623', {
    'groupId': groupId,
    'muted': ?muted,
    'pinned': ?pinned,
    'hide': ?hide,
  });
  Future<Map<String, dynamic>> announcement(
    String groupId, {
    required String text,
    required int expectedVersion,
    required int membershipVersion,
  }) => messaging.call('K260914000655', {
    'groupId': groupId,
    'text': text.trim(),
    'expectedVersion': expectedVersion,
    'membershipVersion': membershipVersion,
  });

  Future<Map<String, dynamic>> rename(
    String groupId,
    String name,
    int expectedVersion,
  ) => messaging.call('K260913000624', {
    'groupId': groupId,
    'name': name.trim(),
    'expectedVersion': expectedVersion,
  });

  Future<Map<String, dynamic>> depart(
    String groupId, {
    required bool dissolve,
    required int membershipVersion,
  }) => messaging.call('K260913000625', {
    'groupId': groupId,
    'action': dissolve ? 'dissolve' : 'leave',
    'membershipVersion': membershipVersion,
  });

  Future<Map<String, dynamic>> transfer(
    String groupId,
    String target,
    int expectedVersion,
  ) async {
    if (_transferring) throw StateError('正在转让群主');
    if (target.isEmpty || target == account) throw ArgumentError('请选择其他群成员');
    final fingerprint = jsonEncode([
      'transfer',
      groupId,
      target,
      expectedVersion,
    ]);
    _transferring = true;
    try {
      _transferRequestId = await _requestStore.identity(fingerprint);
      final result = await messaging.call('K260913000626', {
        'groupId': groupId,
        'target': target,
        'expectedVersion': expectedVersion,
        'requestId': _transferRequestId,
      });
      if (result['groupId'] != groupId ||
          result['ownerAccount'] != target ||
          result['metadataVersion'] is! num) {
        throw const FormatException('转让结果无效');
      }
      await _requestStore.acknowledge(fingerprint, _transferRequestId!);
      _transferRequestId = null;
      return result;
    } finally {
      _transferring = false;
    }
  }

  Future<Map<String, dynamic>> manageMember(
    String groupId,
    String target, {
    required String action,
    required int expectedVersion,
    required int membershipVersion,
  }) => messaging.call('K260913000627', {
    'groupId': groupId,
    'target': target,
    'action': action,
    'expectedVersion': expectedVersion,
    'membershipVersion': membershipVersion,
  });

  final _inviting = <String>{};
  Future<Map<String, dynamic>> invite(String groupId, String target) async {
    if (target.isEmpty || target == account) throw ArgumentError('请选择其他好友');
    final fingerprint = jsonEncode(['invite', groupId, target]);
    if (!_inviting.add(fingerprint)) throw StateError('正在发送邀请');
    try {
      final requestId = await _requestStore.identity(fingerprint);
      final result = await messaging.call('K260913000628', {
        'groupId': groupId,
        'target': target,
        'requestId': requestId,
      });
      if (result['groupId'] != groupId ||
          result['target'] != target ||
          result['invitationId'] is! String ||
          ![
            'pending',
            'accepted',
            'rejected',
            'expired',
            'canceled',
          ].contains(result['status'])) {
        throw const FormatException('邀请结果无效');
      }
      await _requestStore.acknowledge(fingerprint, requestId);
      return result;
    } finally {
      _inviting.remove(fingerprint);
    }
  }

  Future<Map<String, dynamic>> invitations({String? before}) =>
      messaging.call('K260913000629', {'before': ?before, 'limit': 50});
  Future<Map<String, dynamic>> respondInvitation(
    String groupId,
    String invitationId, {
    required bool accept,
  }) async {
    final result = await messaging.call('K260913000630', {
      'groupId': groupId,
      'invitationId': invitationId,
      'action': accept ? 'accept' : 'reject',
    });
    if (result['groupId'] != groupId ||
        result['invitationId'] != invitationId ||
        result['changed'] is! bool ||
        !['accepted', 'rejected', 'expired'].contains(result['status'])) {
      throw const FormatException('邀请处理结果无效');
    }
    return result;
  }

  Future<Map<String, dynamic>> markRead(String groupId, int sequence) =>
      messaging.markGroupRead(groupId, sequence);
}
