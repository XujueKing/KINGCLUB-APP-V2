import 'chat_session_controller.dart';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/auth_repository.dart';
import 'chat_outbox.dart';
import 'messaging_repository.dart';

class DirectChatController extends ChatSessionController {
  DirectChatController({
    required this.repository,
    required this.peer,
    required this.outbox,
  });
  final MessagingRepository repository;
  @override
  MessagingRepository get messaging => repository;
  final String peer;
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
  @override
  String? conversationId;
  @override
  String? error;
  Map<String, dynamic> permission = {};
  @override
  Map<String, dynamic> settings = {};
  int peerReadSequence = 0;
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
      ...confirmed,
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
        if (message['recipient'] == peer) {
          _pending[message['clientMessageId'] as String] = message;
        }
      }
      _changed();
      await synchronize();
      await retryQueued();
    } catch (e) {
      error = e.toString();
      _changed();
    }
  }

  @override
  Future<void> synchronize() {
    final active = _syncing;
    if (active != null) return active;
    final generation = _historyGeneration;
    return _syncing = _synchronize(generation).whenComplete(() {
      if (generation == _historyGeneration) _syncing = null;
    });
  }

  Future<void> _synchronize(int generation) async {
    try {
      bool more;
      do {
        final initial = _lastSynced == 0;
        final result = await repository.history(
          peer,
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
      error = null;
      _changed();
    } catch (e) {
      if (_disposed || generation != _historyGeneration) return;
      error = e.toString();
      _changed();
    }
  }

  @override
  Future<void> loadOlder() async {
    if (!hasOlder || _oldest == null || _disposed) return;
    final generation = _historyGeneration;
    try {
      final result = await repository.history(peer, before: _oldest);
      if (_disposed || generation != _historyGeneration) return;
      await _merge(result, generation);
      if (_disposed || generation != _historyGeneration) return;
      final rows = result['messages'] as List;
      if (rows.isNotEmpty) _oldest = (rows.first['sequence'] as num).toInt();
      hasOlder = result['hasMore'] == true;
      _changed();
    } catch (e) {
      if (_disposed || generation != _historyGeneration) return;
      error = e.toString();
      _changed();
    }
  }

  Future<void> _merge(Map<String, dynamic> result, int generation) async {
    conversationId = result['conversationId'] as String;
    permission = Map<String, dynamic>.from(result['sendPermission'] as Map);
    settings = Map<String, dynamic>.from(result['settings'] as Map);
    peerReadSequence = (result['peerReadSequence'] as num).toInt();
    for (final raw in result['messages'] as List) {
      if (_disposed || generation != _historyGeneration) return;
      await _acknowledge(Map<String, dynamic>.from(raw as Map));
    }
  }

  Future<void> _acknowledge(Map<String, dynamic> message) async {
    final id = message['messageId'] as String;
    _confirmed[id] = {...message, 'status': 'sent'};
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
    if (text.length > 4000) throw StateError('文字最多4000字');
    final id = const Uuid().v4();
    final message = <String, dynamic>{
      'clientMessageId': id,
      'recipient': peer,
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

  /// Queue the owned, completed upload reference; credentials/bytes never enter
  /// the secure message queue. Network retries reuse this message identifier.
  Future<void> sendImage(String assetId, {VoidCallback? onQueued}) async {
    if (_disposed) return;
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(assetId)) {
      throw ArgumentError('图片上传结果无效');
    }
    final id = const Uuid().v4();
    final message = <String, dynamic>{
      'clientMessageId': id,
      'recipient': peer,
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
  Future<void> retryQueued() async {
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
      if (kind != null && kind != 'text' && kind != 'image') {
        throw const FormatException('不支持的待发送消息类型');
      }
      final result = kind == 'image'
          ? await repository.sendImage(
              peer: peer,
              clientMessageId: id,
              assetId: pending['imageAssetId'] as String,
            )
          : await repository.sendText(
              peer: peer,
              clientMessageId: id,
              text: pending['text'] as String,
            );
      if (_disposed) return;
      final received = Map<String, dynamic>.from(result['message'] as Map);
      if (received['clientMessageId'] != id ||
          received['sender'] != repository.account ||
          received['recipient'] != peer ||
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
      await repository.markRead(peer, sequence);
    } catch (_) {
      if (_readRequested == sequence) _readRequested = previous;
    }
  }

  /// Called only after the server has committed the owner's hide cursor.
  @override
  void resetVisibleHistory() {
    _historyGeneration++;
    _syncing = null;
    _confirmed.clear();
    _lastSynced = 0;
    _oldest = null;
    hasOlder = false;
    _changed();
  }
}
