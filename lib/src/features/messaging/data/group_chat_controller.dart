import 'chat_location.dart';
import 'chat_session_controller.dart';
import 'messaging_repository.dart';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/auth_repository.dart';
import 'chat_outbox.dart';
import 'group_chat_repository.dart';

class GroupChatController extends ChatSessionController {
  GroupChatController({
    required this.repository,
    required this.groupId,
    required this.outbox,
  });
  final GroupChatRepository repository;
  @override
  MessagingRepository get messaging => repository.messaging;
  @override
  String get conversationId => groupId;
  final _settings = <String, dynamic>{};
  final _memberNames = <String, String>{};
  bool _membersLoaded = false;
  int _memberGeneration = 0;
  String? _groupName;
  @override
  Map<String, dynamic> get settings => {
    ..._settings,
    'readSequence': readSequence,
    'groupName': _groupName,
  };
  @override
  void resetVisibleHistory() => clearVisibleHistory();
  final String groupId;
  final ChatOutbox outbox;
  final _confirmed = <String, Map<String, dynamic>>{};
  final _pending = <String, Map<String, dynamic>>{};
  final _sending = <String>{};
  Future<void>? _syncing;
  bool _disposed = false;
  int _historyGeneration = 0;
  int _lastSynced = 0;
  int? _oldest;
  @override
  bool hasOlder = false;
  bool hasAccess = false;
  bool _syncAgain = false;
  @override
  String? error;
  int readSequence = 0;
  int _readRequested = 0;

  @override
  List<Map<String, dynamic>> get messages {
    final confirmed = _confirmed.values.toList()
      ..sort((a, b) => (a['sequence'] as num).compareTo(b['sequence'] as num));
    final acknowledged = confirmed
        .where((m) => m['sender'] == repository.account)
        .map((m) => m['clientMessageId'])
        .toSet();
    return [
      ...confirmed.map(
        (m) => {...m, 'senderName': _memberNames[m['sender']] ?? m['sender']},
      ),
      ..._pending.values.where(
        (m) => !acknowledged.contains(m['clientMessageId']),
      ),
    ];
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Future<void> initialize() async {
    try {
      for (final message in await outbox.read()) {
        if (message['groupId'] == groupId) {
          _pending[message['clientMessageId'] as String] = message;
        }
      }
      _changed();
      await synchronize();
      await retryQueued();
    } catch (e) {
      if (e is AuthFailure && e.code == 'CHAT_GROUP_ACCESS_DENIED') {
        _confirmed.clear();
        hasAccess = false;
        _lastSynced = 0;
        _oldest = null;
        hasOlder = false;
      }
      error = e.toString();
      _changed();
    }
  }

  @override
  Future<void> synchronize() {
    final active = _syncing;
    if (active != null) {
      _syncAgain = true;
      return active;
    }
    final generation = _historyGeneration;
    return _syncing = _drainSync(generation).whenComplete(() {
      if (generation == _historyGeneration) _syncing = null;
    });
  }

  Future<void> _drainSync(int generation) async {
    do {
      _syncAgain = false;
      await _synchronize(generation);
    } while (!_disposed && generation == _historyGeneration && _syncAgain);
  }

  Future<void> _synchronize(int generation) async {
    try {
      bool more;
      do {
        final initial = _lastSynced == 0;
        final result = await repository.history(
          groupId,
          after: initial ? null : _lastSynced,
        );
        if (_disposed || generation != _historyGeneration) return;
        await _merge(result, generation);
        if (_disposed || generation != _historyGeneration) return;
        final rows = result['messages'] as List;
        if (rows.isNotEmpty) {
          _lastSynced = (rows.last['sequence'] as num).toInt();
          _oldest ??= (rows.first['sequence'] as num).toInt();
        }
        if (initial) hasOlder = result['hasMore'] == true;
        more = !initial && result['hasMore'] == true && rows.isNotEmpty;
      } while (more && !_disposed);
      hasAccess = true;
      error = null;
      _changed();
      await _loadMemberNames(generation);
    } catch (e) {
      if (_disposed || generation != _historyGeneration) return;
      if (e is AuthFailure && e.code == 'CHAT_GROUP_ACCESS_DENIED') {
        _confirmed.clear();
        hasAccess = false;
        _lastSynced = 0;
        _oldest = null;
        hasOlder = false;
      }
      error = e.toString();
      _changed();
    }
  }

  Future<void> _loadMemberNames(int generation) async {
    if (_membersLoaded || _disposed) return;
    final memberGeneration = _memberGeneration;
    try {
      final result = await repository.details(groupId);
      if (_disposed ||
          generation != _historyGeneration ||
          memberGeneration != _memberGeneration ||
          !hasAccess) {
        return;
      }
      _groupName = result['groupName'] as String?;
      _memberNames.clear();
      for (final raw in result['members'] as List) {
        final member = raw as Map;
        _memberNames[member['account'] as String] =
            member['nickname'] as String;
      }
      _membersLoaded = true;
      _changed();
    } catch (_) {
      // Sender accounts remain visible while a member lookup is unavailable.
      // History authorization is checked independently on every synchronization.
    }
  }

  @override
  Future<void> loadOlder() async {
    if (!hasOlder || _oldest == null || _disposed) return;
    final generation = _historyGeneration;
    try {
      final result = await repository.history(groupId, before: _oldest);
      if (_disposed || generation != _historyGeneration) return;
      await _merge(result, generation);
      if (_disposed || generation != _historyGeneration) return;
      final rows = result['messages'] as List;
      if (rows.isNotEmpty) _oldest = (rows.first['sequence'] as num).toInt();
      hasOlder = result['hasMore'] == true;
      _changed();
    } catch (e) {
      if (_disposed || generation != _historyGeneration) return;
      if (e is AuthFailure && e.code == 'CHAT_GROUP_ACCESS_DENIED') {
        _confirmed.clear();
        hasAccess = false;
        _lastSynced = 0;
        _oldest = null;
        hasOlder = false;
      }
      error = e.toString();
      _changed();
    }
  }

  Future<void> _merge(Map<String, dynamic> result, int generation) async {
    readSequence = (result['readSequence'] as num).toInt();
    _settings
      ..clear()
      ..addAll(
        Map<String, dynamic>.from(result['settings'] as Map? ?? const {}),
      );
    final hidden = (_settings['hiddenThrough'] as num?)?.toInt() ?? 0;
    _confirmed.removeWhere(
      (_, message) => (message['sequence'] as num).toInt() <= hidden,
    );
    for (final raw in result['messages'] as List) {
      if (_disposed || generation != _historyGeneration) return;
      await _acknowledge(Map<String, dynamic>.from(raw as Map));
    }
  }

  Future<void> _acknowledge(Map<String, dynamic> message) async {
    if (message['groupId'] != groupId) {
      throw const FormatException('Wrong group message');
    }
    final id = message['messageId'] as String;
    if ((message['sequence'] as num).toInt() >
        ((_settings['hiddenThrough'] as num?)?.toInt() ?? 0)) {
      _confirmed[id] = {...message, 'status': 'sent'};
    }
    if (message['sender'] == repository.account) {
      final clientId = message['clientMessageId'] as String;
      if (_pending.containsKey(clientId)) {
        await outbox.remove(clientId);
        _pending.remove(clientId);
      }
    }
  }

  @override
  Future<void> send(String text, {VoidCallback? onQueued}) async {
    text = text.trim();
    if (text.isEmpty || _disposed) return;
    if (!hasAccess) throw StateError('请先确认群聊访问权限');
    if (text.length > 4000) throw StateError('文字最多4000字');
    final id = const Uuid().v4();
    final message = <String, dynamic>{
      'clientMessageId': id,
      'groupId': groupId,
      'sender': repository.account,
      'text': text,
      'createdDate': DateTime.now().toUtc().toIso8601String(),
      'status': 'queued',
    };
    await outbox.put(message);
    if (_disposed) return;
    _pending[id] = message;
    _changed();
    onQueued?.call();
    await retry(id);
  }

  @override
  Future<void> sendImage(String assetId, {VoidCallback? onQueued}) async {
    if (_disposed) return;
    if (!hasAccess) throw StateError('请先确认群聊访问权限');
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(assetId)) {
      throw ArgumentError('图片上传结果无效');
    }
    final id = const Uuid().v4();
    final message = <String, dynamic>{
      'clientMessageId': id,
      'groupId': groupId,
      'sender': repository.account,
      'messageType': 'image',
      'imageAssetId': assetId,
      'text': '[图片]',
      'createdDate': DateTime.now().toUtc().toIso8601String(),
      'status': 'queued',
    };
    await outbox.put(message);
    if (_disposed) return;
    _pending[id] = message;
    _changed();
    onQueued?.call();
    await retry(id);
  }

  @override
  Future<void> sendLocation(
    ChatLocation location, {
    VoidCallback? onQueued,
  }) async {
    if (_disposed) return;
    if (!hasAccess) throw StateError('请先确认群聊访问权限');
    final id = const Uuid().v4();
    final message = <String, dynamic>{
      'clientMessageId': id,
      'groupId': groupId,
      'sender': repository.account,
      'messageType': 'location',
      'location': location.toJson(),
      'text': '[位置]',
      'createdDate': DateTime.now().toUtc().toIso8601String(),
      'status': 'queued',
    };
    await outbox.put(message);
    if (_disposed) return;
    _pending[id] = message;
    _changed();
    onQueued?.call();
    await retry(id);
  }

  @override
  Future<void> sendVoice(
    String assetId,
    int durationMs, {
    VoidCallback? onQueued,
  }) async {
    if (_disposed) return;
    if (!hasAccess) throw StateError('请先确认群聊访问权限');
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(assetId)) {
      throw ArgumentError('语音上传结果无效');
    }
    if (durationMs < 1000 || durationMs > 60500) throw ArgumentError('录音时长无效');
    final id = const Uuid().v4();
    final message = <String, dynamic>{
      'clientMessageId': id,
      'groupId': groupId,
      'sender': repository.account,
      'messageType': 'voice',
      'voiceAssetId': assetId,
      'voiceDurationMs': durationMs,
      'text': '[语音]',
      'createdDate': DateTime.now().toUtc().toIso8601String(),
      'status': 'queued',
    };
    await outbox.put(message);
    if (_disposed) return;
    _pending[id] = message;
    _changed();
    onQueued?.call();
    await retry(id);
  }

  @override
  Future<void> retryQueued() async {
    if (!hasAccess) return;
    for (final message in _pending.values.toList()) {
      if (_disposed) return;
      if (message['status'] == 'queued') {
        await retry(message['clientMessageId'] as String);
      }
    }
  }

  @override
  Future<void> retry(String id) async {
    final pending = _pending[id];
    if (pending == null || _disposed || !_sending.add(id)) return;
    _pending[id] = {...pending, 'status': 'sending'};
    _changed();
    try {
      final kind = pending['messageType'];
      if (kind != null &&
          kind != 'text' &&
          kind != 'image' &&
          kind != 'voice' &&
          kind != 'location') {
        throw const FormatException('不支持的消息类型');
      }
      final result = kind == 'image'
          ? await repository.sendImage(
              groupId: groupId,
              clientMessageId: id,
              assetId: pending['imageAssetId'] as String,
            )
          : kind == 'voice'
          ? await repository.sendVoice(
              groupId: groupId,
              clientMessageId: id,
              assetId: pending['voiceAssetId'] as String,
            )
          : kind == 'location'
          ? await repository.sendLocation(
              groupId: groupId,
              clientMessageId: id,
              location: ChatLocation.fromJson(
                Map<String, dynamic>.from(pending['location'] as Map),
              ),
            )
          : await repository.sendText(
              groupId: groupId,
              clientMessageId: id,
              text: pending['text'] as String,
            );
      if (_disposed) return;
      final received = Map<String, dynamic>.from(result['message'] as Map);
      if (kind == 'location' &&
          (received['messageType'] != 'location' ||
              !ChatLocation.fromJson(
                Map<String, dynamic>.from(received['location'] as Map),
              ).sameAs(
                ChatLocation.fromJson(
                  Map<String, dynamic>.from(pending['location'] as Map),
                ),
              ))) {
        throw const FormatException('位置回执与发送内容不符');
      }
      if (kind == 'voice' &&
          (received['messageType'] != 'voice' ||
              received['voiceAssetId'] != pending['voiceAssetId'] ||
              received['voiceDurationMs'] != pending['voiceDurationMs'])) {
        throw const FormatException('语音回执与发送内容不符');
      }
      if (received['groupId'] != groupId ||
          received['sender'] != repository.account ||
          received['clientMessageId'] != id ||
          (kind == 'image' &&
              (received['messageType'] != 'image' ||
                  received['imageAssetId'] != pending['imageAssetId']))) {
        throw const FormatException('消息回执与发送内容不符');
      }
      await _acknowledge(received);
      error = null;
    } catch (e) {
      if (_disposed || !_pending.containsKey(id)) return;
      final transient = e is AuthFailure && e.code == 'NETWORK_ERROR';
      final failed = {
        ...pending,
        'status': transient ? 'queued' : 'failed',
        'error': e.toString(),
      };
      await outbox.put(failed);
      _pending[id] = failed;
      error = e.toString();
    } finally {
      _sending.remove(id);
      _changed();
    }
  }

  @override
  Future<void> markVisibleRead(int sequence) async {
    if (_disposed || sequence <= _readRequested) return;
    final previous = _readRequested;
    _readRequested = sequence;
    try {
      await repository.markRead(groupId, sequence);
    } catch (_) {
      if (_readRequested == sequence) _readRequested = previous;
    }
  }

  /// Revalidate names after reconnect without discarding loaded message pages.
  void invalidateMemberNames() {
    _memberGeneration++;
    _membersLoaded = false;
    _memberNames.clear();
    _changed();
  }

  /// Clear visible data after membership or session revocation.
  void clearVisibleHistory() {
    _memberGeneration++;
    _memberNames.clear();
    _membersLoaded = false;
    _historyGeneration++;
    _syncing = null;
    _syncAgain = false;
    hasAccess = false;
    _confirmed.clear();
    _lastSynced = 0;
    _oldest = null;
    hasOlder = false;
    _changed();
  }
}
