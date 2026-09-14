import 'chat_history_store.dart';
import 'chat_location.dart';
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
    this.openHistory,
  });
  final MessagingRepository repository;
  @override
  MessagingRepository get messaging => repository;
  final String peer;
  final ChatOutbox outbox;
  final Future<ChatHistoryStore> Function()? openHistory;
  ChatHistoryStore? _history;
  Future<void>? _historyReady, _historyBarrier;
  int _diskEpoch = 0;
  int _hiddenThrough = 0;
  String get _historyKey => 'direct:$peer';

  Future<void> _ensureHistory() => _historyReady ??= _restoreHistory();
  Future<void> _restoreHistory() async {
    if (openHistory == null) return;
    final generation = _historyGeneration;
    final store = await openHistory!();
    if (store.account != repository.account) throw StateError('聊天记录账号不符');
    if (_disposed) return;
    _history = store;
    final page = await store.read(_historyKey);
    _diskEpoch = page.epoch;
    _hiddenThrough = page.hiddenThrough;
    if (_disposed || generation != _historyGeneration) return;
    for (final message in page.messages) {
      _confirmed[message['messageId'] as String] = message;
    }
    _lastSynced = page.cursor;
    if (page.messages.isNotEmpty) {
      _oldest = page.messages.first['sequence'] as int;
      conversationId = page.messages.first['conversationId'] as String?;
      hasOlder = true;
    }
    _changed();
  }

  final _confirmed = <String, Map<String, dynamic>>{};
  final _pending = <String, Map<String, dynamic>>{};
  final _sending = <String>{};
  Future<void>? _syncing;
  bool _disposed = false;
  bool _syncAgain = false;
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
      if (openHistory != null) await _ensureHistory();
      if (_disposed) return;
      for (final message in await outbox.read()) {
        if (_disposed) return;
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
    if (_disposed) return Future<void>.value();
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
      if (openHistory != null) {
        await _ensureHistory();
        await _historyBarrier;
      }
      if (_disposed || generation != _historyGeneration) return;
      bool more;
      do {
        final initial = _lastSynced == 0;
        final result = await repository.history(
          peer,
          after: initial ? null : _lastSynced,
        );
        if (_disposed || generation != _historyGeneration) return;
        await _merge(result, generation, advanceCursor: true);
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
      if (_history != null) {
        await _historyBarrier;
        if (_disposed || generation != _historyGeneration) return;
        final local = await _history!.read(_historyKey, before: _oldest);
        if (_disposed || generation != _historyGeneration) return;
        if (local.epoch != _diskEpoch) {
          resetVisibleHistory();
          return;
        }
        if (local.messages.isNotEmpty) {
          for (final message in local.messages) {
            _confirmed[message['messageId'] as String] = message;
          }
          _oldest = local.messages.first['sequence'] as int;
          _changed();
          return;
        }
      }
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

  Future<void> _merge(
    Map<String, dynamic> result,
    int generation, {
    bool advanceCursor = false,
  }) async {
    final rows = (result['messages'] as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    final hidden = (result['settings'] as Map)['hiddenThrough'];
    if (_history != null) {
      if (hidden is! int || hidden < 0) throw StateError('服务端尚未提供聊天记录同步信息');
      final committed = await _history!.commit(
        _historyKey,
        rows,
        expectedEpoch: _diskEpoch,
        hiddenThrough: hidden,
        cursor: advanceCursor && rows.isNotEmpty
            ? rows.last['sequence'] as int
            : null,
      );
      if (_disposed || generation != _historyGeneration) return;
      if (!committed) {
        resetVisibleHistory();
        throw StateError('聊天记录已清空，请重新同步');
      }
    }
    if (hidden is int) {
      if (hidden > _hiddenThrough) _hiddenThrough = hidden;
      _confirmed.removeWhere(
        (_, message) => (message['sequence'] as int) <= hidden,
      );
    }
    conversationId = result['conversationId'] as String;
    permission = Map<String, dynamic>.from(result['sendPermission'] as Map);
    settings = Map<String, dynamic>.from(result['settings'] as Map);
    peerReadSequence = (result['peerReadSequence'] as num).toInt();
    for (final message in rows) {
      if (_disposed || generation != _historyGeneration) return;
      if (hidden is int && (message['sequence'] as int) <= hidden) continue;
      await _acknowledge(message, persist: false);
    }
  }

  Future<void> _acknowledge(
    Map<String, dynamic> message, {
    bool persist = true,
  }) async {
    final generation = _historyGeneration;
    if (persist && openHistory != null) {
      await _ensureHistory();
      await _historyBarrier;
      if (_disposed || generation != _historyGeneration) return;
      if (!await _history!.commit(_historyKey, [
        message,
      ], expectedEpoch: _diskEpoch)) {
        throw StateError('聊天记录已变化，请重新同步');
      }
      if (_disposed || generation != _historyGeneration) return;
    }
    final id = message['messageId'] as String;
    if ((message['sequence'] as int) > _hiddenThrough) {
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
  @override
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
  Future<void> sendLocation(
    ChatLocation location, {
    VoidCallback? onQueued,
  }) async {
    if (_disposed) return;
    final id = const Uuid().v4();
    final message = <String, dynamic>{
      'clientMessageId': id,
      'recipient': peer,
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
  Future<void> sendFile(
    String assetId,
    String fileName,
    int fileSize,
    String fileSha256, {
    VoidCallback? onQueued,
  }) async {
    if (_disposed) return;
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(assetId)) {
      throw ArgumentError('文件上传结果无效');
    }
    if (fileName.trim().isEmpty ||
        fileName.length > 180 ||
        fileSize < 0 ||
        fileSize > 268435456 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(fileSha256)) {
      throw ArgumentError('文件元数据无效');
    }
    final id = const Uuid().v4();
    final message = <String, dynamic>{
      'clientMessageId': id,
      'recipient': peer,
      'sender': repository.account,
      'messageType': 'file',
      'fileAssetId': assetId,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileSha256': fileSha256,
      'text': '[文件]',
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
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(assetId)) {
      throw ArgumentError('语音上传结果无效');
    }
    if (durationMs < 1000 || durationMs > 60500) throw ArgumentError('录音时长无效');
    final id = const Uuid().v4();
    final message = <String, dynamic>{
      'clientMessageId': id,
      'recipient': peer,
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
    for (final message in _pending.values.toList()) {
      if (_disposed) return;
      if (message['status'] == 'queued') {
        await retry(message['clientMessageId'] as String);
      }
    }
  }

  @override
  Future<void> retry(String id) async {
    final historyGeneration = _historyGeneration;
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
          kind != 'file' &&
          kind != 'location') {
        throw const FormatException('不支持的待发送消息类型');
      }
      final result = kind == 'image'
          ? await repository.sendImage(
              peer: peer,
              clientMessageId: id,
              assetId: pending['imageAssetId'] as String,
            )
          : kind == 'file'
          ? await repository.sendFile(
              peer: peer,
              clientMessageId: id,
              assetId: pending['fileAssetId'] as String,
            )
          : kind == 'voice'
          ? await repository.sendVoice(
              peer: peer,
              clientMessageId: id,
              assetId: pending['voiceAssetId'] as String,
            )
          : kind == 'location'
          ? await repository.sendLocation(
              peer: peer,
              clientMessageId: id,
              location: ChatLocation.fromJson(
                Map<String, dynamic>.from(pending['location'] as Map),
              ),
            )
          : await repository.sendText(
              peer: peer,
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
      if (kind == 'file' &&
          (received['messageType'] != 'file' ||
              [
                'fileAssetId',
                'fileName',
                'fileSize',
                'fileSha256',
              ].any((key) => received[key] != pending[key]))) {
        throw const FormatException('文件回执与发送内容不符');
      }
      if (kind == 'voice' &&
          (received['messageType'] != 'voice' ||
              received['voiceAssetId'] != pending['voiceAssetId'] ||
              received['voiceDurationMs'] != pending['voiceDurationMs'])) {
        throw const FormatException('语音回执与发送内容不符');
      }
      if (received['clientMessageId'] != id ||
          received['sender'] != repository.account ||
          received['recipient'] != peer ||
          (kind == 'image' &&
              (received['messageType'] != 'image' ||
                  received['imageAssetId'] != pending['imageAssetId']))) {
        throw const FormatException('消息回执与发送内容不符');
      }
      if (historyGeneration != _historyGeneration) return;
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
    if (openHistory != null) {
      _historyBarrier = (_historyBarrier ?? _ensureHistory()).then((_) async {
        if (_history != null) _diskEpoch = await _history!.clear(_historyKey);
      });
      // Observe failures even if the caller leaves without another sync.
      _historyBarrier!.catchError((Object e) {
        error = e.toString();
        _changed();
      });
    }
    _syncAgain = false;
    _syncing = null;
    _confirmed.clear();
    _lastSynced = 0;
    _oldest = null;
    hasOlder = false;
    _changed();
  }
}
