import 'chat_video.dart';

import 'dart:async';

import 'chat_read_outbox.dart';
import 'conversation_read_projection.dart';
import 'chat_avatar_snapshot.dart';
import 'authenticated_chat_api.dart';
import 'novorudp_binding_runtime.dart';
import 'chat_location.dart';
import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';

typedef ChatApiCall = Future<Map<String, dynamic>> Function(
  String interfaceId,
  Map<String, dynamic> params,
);

/// All requests are bound to the account which opened this repository.
class MessagingRepository {
  static final _relationshipChanges =
      StreamController<({String account, String? peer})>.broadcast();
  static Stream<String?> relationshipChanges(String account) =>
      _relationshipChanges.stream
          .where((event) => event.account == account)
          .map((event) => event.peer);
  void _relationshipChanged([String? peer]) =>
      _relationshipChanges.add((account: account, peer: peer));

  static final _remarkChanges =
      StreamController<({String account, String peer})>.broadcast();
  static Stream<String> remarkChanges(String account) => _remarkChanges.stream
      .where((event) => event.account == account)
      .map((event) => event.peer);
  static final _readChanges = StreamController<String>.broadcast();
  static Stream<String> readChanges(String account) =>
      _readChanges.stream.where((changedAccount) => changedAccount == account);

  MessagingRepository({
    required this.account,
    required this.call,
    this.persistHistory = false,
    ChatReadOutbox? readOutbox,
    ChatReadOutbox? groupReadOutbox,
    DateTime Function()? readRetryClock,
  }) : _readRetryClock = readRetryClock ?? DateTime.now,
       readOutbox =
           readOutbox ?? (persistHistory ? ChatReadOutbox(account) : null),
       groupReadOutbox =
           groupReadOutbox ??
           (persistHistory ? ChatReadOutbox(account, group: true) : null) {
    if (this.readOutbox != null &&
            (this.readOutbox!.account != account || this.readOutbox!.group) ||
        this.groupReadOutbox != null &&
            (this.groupReadOutbox!.account != account ||
                !this.groupReadOutbox!.group)) {
      throw ArgumentError('Read outbox belongs to another account');
    }
  }

  final ChatReadOutbox? readOutbox;
  final ChatReadOutbox? groupReadOutbox;
  final DateTime Function() _readRetryClock;
  final _readRetryAfter = <(bool, String), ({int sequence, DateTime after})>{};

  final bool persistHistory;

  final String account;
  final ChatApiCall call;

  Future<Map<String, dynamic>> avatarProfile(String peer) {
    Future<Map<String, dynamic>> fetch() => peer == account
        ? call('K260912000501', {})
        : call('K260913000612', {'peer': peer});
    return persistHistory
        ? ChatAvatarSnapshot().load(account, peer, fetch)
        : fetch();
  }

  static Future<MessagingRepository> open() async {
    final store = SecureSessionStore();
    final session = await store.readSession();
    final account = (session?['account'] as Map?)?['userAccount'];
    if (session == null || account is! String || account.isEmpty) {
      throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    }
    final client = KingclubSecureClient(kingclubApiBaseUrl);
    final repository = MessagingRepository(
      account: account,
      persistHistory: true,
      call: AuthenticatedChatApi(
        account: account,
        sessionId: session['sessionId'] as String,
        client: client,
        store: store,
      ).call,
    );
    NovoRudpBindingRuntime.start(repository);
    return repository;
  }

  Future<Map<String, dynamic>> sendText({
    required String peer,
    required String clientMessageId,
    required String text,
    String? replyToMessageId,
  }) => call('K260913000601', {
    'recipient': peer,
    'clientMessageId': clientMessageId,
    'text': text,
    'replyToMessageId': ?replyToMessageId,
  });
  Future<Map<String, dynamic>> sendImage({
    required String peer,
    required String clientMessageId,
    required String assetId,
  }) => call('K260913000632', {
    'recipient': peer,
    'clientMessageId': clientMessageId,
    'assetId': assetId,
  });
  Future<Map<String, dynamic>> sendLocation({
    required String peer,
    required String clientMessageId,
    required ChatLocation location,
  }) => call('K260913000641', {
    'recipient': peer,
    'clientMessageId': clientMessageId,
    'location': location.toJson(),
  });
  Future<Map<String, dynamic>> sendFile({
    required String peer,
    required String clientMessageId,
    required String assetId,
  }) => call('K260914000651', {
    'recipient': peer,
    'clientMessageId': clientMessageId,
    'assetId': assetId,
  });
  Future<Map<String, dynamic>> sendVideo({
    required String peer,
    required String clientMessageId,
    required String assetId,
  }) => call('K260915000665', {
    'recipient': peer,
    'clientMessageId': clientMessageId,
    'assetId': assetId,
  });
  Future<Map<String, dynamic>> sendVoice({
    required String peer,
    required String clientMessageId,
    required String assetId,
  }) => call('K260913000637', {
    'recipient': peer,
    'clientMessageId': clientMessageId,
    'assetId': assetId,
  });
  Future<ChatVideo> prepareVideo(String sourceAssetId) async =>
      ChatVideo.fromPrepared(
        await call('K260915000669', {'sourceAssetId': sourceAssetId}),
      );
  Future<Map<String, dynamic>> videoMedia(
    String messageId, {
    bool group = false,
    bool preferHevc = false,
  }) => call(group ? 'K260915000668' : 'K260915000667', {
    'messageId': messageId,
    if (preferHevc) 'preferHevc': true,
  });
  Future<Map<String, dynamic>> imageMedia(
    String messageId, {
    bool group = false,
  }) =>
      call(group ? 'K260913000635' : 'K260913000633', {'messageId': messageId});
  Future<Map<String, dynamic>> fileMedia(
    String messageId, {
    bool group = false,
  }) =>
      call(group ? 'K260914000654' : 'K260914000652', {'messageId': messageId});

  Future<Map<String, dynamic>> peerFileAuthority(
    String messageId,
    String peer,
  ) => call('K260916000686', {'messageId': messageId, 'peer': peer});

  Future<Map<String, dynamic>> voiceMedia(
    String messageId, {
    bool group = false,
  }) =>
      call(group ? 'K260913000640' : 'K260913000638', {'messageId': messageId});

  Future<Map<String, dynamic>> setRelationship(
    String peer,
    String action,
  ) async {
    final result = await call('K260913000602', {
      'peer': peer,
      'action': action,
    });
    _relationshipChanged(peer);
    return result;
  }

  Future<Map<String, dynamic>> permission(String peer) =>
      call('K260913000603', {'peer': peer});
  Future<Map<String, dynamic>> history(
    String peer, {
    String? query,
    String? messageType,
    int? before,
    int? after,
    int limit = 50,
  }) {
    if (before != null && after != null) {
      throw ArgumentError('Choose one history direction');
    }
    return call('K260913000604', {
      'peer': peer,
      'query': ?query,
      'messageType': ?messageType,
      'before': ?before,
      'after': ?after,
      'limit': limit,
    });
  }

  Future<Map<String, dynamic>> markRead(String peer, int sequence) async {
    _readRetryAfter.remove((false, peer));
    final queue = readOutbox;
    if (queue != null && await queue.put(peer, sequence)) {
      _readChanges.add(account);
    }
    final result = await call('K260913000605', {
      'peer': peer,
      'sequence': sequence,
    });
    _validateReadAcknowledgement(result, sequence);
    // A cleanup failure must not turn a confirmed read into an API failure.
    try {
      await readOutbox?.acknowledge(peer, sequence);
    } catch (_) {}
    return result;
  }

  Future<void> retryPendingReads({required bool Function() isActive}) async {
    for (final queue in [readOutbox, groupReadOutbox]) {
      if (!isActive()) return;
      if (queue == null) continue;
      final values = await queue.read();
      _readRetryAfter.removeWhere(
        (key, _) => key.$1 == queue.group && !values.containsKey(key.$2),
      );
      for (final entry in values.entries) {
        if (!isActive()) return;
        final key = (queue.group, entry.key);
        final deferred = _readRetryAfter[key];
        if (deferred != null &&
            deferred.sequence == entry.value &&
            _readRetryClock().isBefore(deferred.after)) {
          continue;
        }
        try {
          final result = await call(
            queue.group ? 'K260913000622' : 'K260913000605',
            {
              queue.group ? 'groupId' : 'peer': entry.key,
              'sequence': entry.value,
            },
          );
          if (!isActive()) return;
          _validateReadAcknowledgement(
            result,
            entry.value,
            groupId: queue.group ? entry.key : null,
          );
          _readRetryAfter.remove(key);
          _readChanges.add(account);
          await queue.acknowledge(entry.key, entry.value);
        } on FormatException {
          if (!isActive()) return;
          // A malformed receipt belongs to this intent; it must not starve
          // healthy conversations later in the same recovery pass.
          _readRetryAfter[key] = (
            sequence: entry.value,
            after: _readRetryClock().add(const Duration(minutes: 5)),
          );
        } on AuthFailure catch (error) {
          if (!isActive()) return;
          if (error.code == 'NETWORK_ERROR' ||
              error.code == 'SESSION_CHANGED' ||
              error.code == 'SESSION_EXPIRED') {
            return;
          }
          // Keep rejected intents, but do not hit an unavailable conversation
          // every foreground tick. New reading bypasses this short cooldown.
          _readRetryAfter[key] = (
            sequence: entry.value,
            after: _readRetryClock().add(const Duration(minutes: 5)),
          );
        } catch (_) {
          return;
        }
      }
    }
  }

  Future<Map<String, dynamic>> markGroupRead(
    String groupId,
    int sequence,
  ) async {
    _readRetryAfter.remove((true, groupId));
    final queue = groupReadOutbox;
    if (queue != null && sequence > 0 && await queue.put(groupId, sequence)) {
      _readChanges.add(account);
    }
    final result = await call('K260913000622', {
      'groupId': groupId,
      'sequence': sequence,
    });
    _validateReadAcknowledgement(result, sequence, groupId: groupId);
    try {
      await queue?.acknowledge(groupId, sequence);
    } catch (_) {}
    return result;
  }

  void _validateReadAcknowledgement(
    Map<String, dynamic> result,
    int requested, {
    String? groupId,
  }) {
    final confirmed = result['readSequence'];
    if (confirmed is! int ||
        confirmed < requested ||
        confirmed < 0 ||
        confirmed > 4294967295 ||
        (groupId != null && result['groupId'] != groupId)) {
      throw const FormatException('已读确认无效，请稍后重试');
    }
  }

  Future<Map<String, dynamic>> settings(
    String peer, {
    bool? muted,
    bool? pinned,
    bool? onlyChat,
    String? remark,
    bool? hide,
  }) async {
    final result = await call('K260913000606', {
      'peer': peer,
      'muted': ?muted,
      'pinned': ?pinned,
      'onlyChat': ?onlyChat,
      'remark': ?remark,
      'hide': ?hide,
    });
    if (remark != null) _remarkChanges.add((account: account, peer: peer));
    return result;
  }

  Future<ConversationReadProjection> pendingReadProjection() async {
    final values = await Future.wait([
      readOutbox?.read() ?? Future.value(<String, int>{}),
      groupReadOutbox?.read() ?? Future.value(<String, int>{}),
    ]);
    return ConversationReadProjection(values[0], values[1]);
  }

  Future<Map<String, dynamic>> conversations({
    int offset = 0,
    int limit = 50,
    List<String>? knownLocalMessageIds,
  }) async {
    final known = knownLocalMessageIds?.map((id) => id.toLowerCase()).toSet();
    if (knownLocalMessageIds != null &&
        (knownLocalMessageIds.length > 200 ||
            known!.any(
              (id) => !RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
              ).hasMatch(id),
            ))) {
      throw ArgumentError('Invalid local message IDs');
    }
    final before = await pendingReadProjection();
    final result = await call('K260913000607', {
      'offset': offset,
      'limit': limit,
      if (known != null) 'knownLocalMessageIds': known.toList(),
    });
    final after = await pendingReadProjection();
    List<Map<String, dynamic>> project(List rows) => after.apply(
      before.apply([
        for (final row in rows) Map<String, dynamic>.from(row as Map),
      ]),
    );
    if (known == null) {
      return {...result, 'items': project(result['items'] as List)};
    }
    final items = result['items'];
    if (items is! List) {
      throw const FormatException('Invalid conversation receipt response');
    }
    final normalized = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map || item['confirmedLocalMessageIds'] is! List) {
        throw const FormatException('Conversation receipt support unavailable');
      }
      final matches = item['confirmedLocalMessageIds'] as List;
      if (matches.length > known.length ||
          matches.any(
            (id) => id is! String || !known.contains(id.toLowerCase()),
          ) ||
          (item['kind'] == 'group' && matches.isNotEmpty)) {
        throw const FormatException('Invalid conversation receipt scope');
      }
      final ids = matches.cast<String>().map((id) => id.toLowerCase()).toSet();
      if (ids.length != matches.length) {
        throw const FormatException('Duplicate conversation receipt');
      }
      normalized.add({
        ...Map<String, dynamic>.from(item),
        'confirmedLocalMessageIds': ids.toList(),
      });
    }
    return {...result, 'items': project(normalized)};
  }

  Future<Map<String, dynamic>> contacts({int offset = 0, int limit = 50}) =>
      call('K260913000608', {'offset': offset, 'limit': limit});
  Future<Map<String, dynamic>> requestFromQr({
    required String code,
    required String requestId,
    String note = '',
  }) async {
    final result = await call('K260913000609', {
      'code': code,
      'requestId': requestId,
      'note': note,
    });
    _relationshipChanged();
    return result;
  }

  Future<Map<String, dynamic>> resolveRequest(
    String requestId, {
    required bool accept,
  }) async {
    final result = await call('K260913000610', {
      'requestId': requestId,
      'accept': accept,
    });
    _relationshipChanged();
    return result;
  }

  Future<Map<String, dynamic>> requests({int offset = 0, int limit = 50}) =>
      call('K260913000611', {'offset': offset, 'limit': limit});
}
