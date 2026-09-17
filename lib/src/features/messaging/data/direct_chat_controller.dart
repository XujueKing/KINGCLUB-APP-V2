import 'dart:async';

import 'chat_message_receipt.dart';

import 'chat_video.dart';
import 'chat_history_store.dart';
import 'chat_location.dart';
import 'chat_session_controller.dart';
import 'chat_message_order.dart';

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
    this.readRelayMessages,
    this.sendRelayText,
    this.preferRelayText,
    this.markRelayRead,
    Stream<String>? relayChanges,
  }) {
    _relayEvents = relayChanges?.listen((member) {
      if (member == peer) unawaited(_refreshRelay());
    });
  }
  final Future<List<Map<String, dynamic>>> Function()? readRelayMessages;
  final Future<bool> Function(String text, String messageId)? sendRelayText;
  final bool Function()? preferRelayText;
  final Future<void> Function(List<String> ids)? markRelayRead;
  bool _markingRelayRead = false;

  Future<void> markRelayVisibleRead() async {
    if (_disposed || _markingRelayRead || markRelayRead == null) return;
    final ids = _relayMessages
        .where((m) => m['sender'] == peer && m['peerRead'] != true)
        .map((m) => m['clientMessageId'] as String)
        .toList();
    if (ids.isEmpty) return;
    _markingRelayRead = true;
    try {
      await markRelayRead!(ids);
      await _refreshRelay();
    } catch (_) {
      // A later visible-frame/scroll event can retry the durable read marker.
    } finally {
      _markingRelayRead = false;
    }
  }

  StreamSubscription<String>? _relayEvents;
  List<Map<String, dynamic>> _relayMessages = [];
  Set<String> _relayPeerRead = {};
  int _relayRead = 0;

  Future<void> _refreshRelay() async {
    if (_disposed || readRelayMessages == null) return;
    final generation = _historyGeneration;
    final read = ++_relayRead;
    try {
      await _historyBarrier;
      if (_disposed || generation != _historyGeneration || read != _relayRead) {
        return;
      }
      final rows = await readRelayMessages!();
      final peerRead = rows
          .where((row) => row['outgoing'] == true && row['read'] == true)
          .map((row) => row['id'] as String)
          .toSet();
      final store = _history;
      if (store != null) {
        final ids = _confirmed.values
            .where((m) => m['sender'] == repository.account)
            .map((m) => m['clientMessageId'] as String)
            .where(
              (id) => RegExp(
                r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
              ).hasMatch(id),
            )
            .toList();
        for (var start = 0; start < ids.length; start += 200) {
          peerRead.addAll(
            await store.nearbyPeerReadIds(
              peer,
              ids.skip(start).take(200).toList(),
            ),
          );
        }
      }
      if (_disposed || generation != _historyGeneration || read != _relayRead) {
        return;
      }
      _relayPeerRead = peerRead;
      _relayMessages = rows
          .where((row) => row['outgoing'] != true || row['delivered'] == true)
          .map(
            (row) => {
              'clientMessageId': row['id'],
              'sender': row['outgoing'] == true ? repository.account : peer,
              'recipient': row['outgoing'] == true ? peer : repository.account,
              'text': row['text'],
              'messageType': 'text',
              'createdDate': DateTime.fromMillisecondsSinceEpoch(
                row['created'] as int,
                isUtc: true,
              ).toIso8601String(),
              'status': 'sent',
              'peerDelivered': row['delivered'] == true,
              'peerRead': row['read'] == true,
            },
          )
          .toList();
      _changed();
    } catch (_) {
      // A relay read cannot take down service history. Never keep a stale
      // snapshot after a failed validation or account change.
      if (!_disposed &&
          generation == _historyGeneration &&
          read == _relayRead) {
        _relayMessages = [];
        _relayPeerRead = {};
        _changed();
      }
    }
  }

  final MessagingRepository repository;
  @override
  MessagingRepository get messaging => repository;
  final String peer;
  final ChatOutbox outbox;
  final Future<ChatHistoryStore> Function()? openHistory;
  ChatHistoryStore? _history;
  Future<void>? _historyReady, _historyBarrier;
  int _diskEpoch = 0;
  int? _historyVersion;
  bool _canHideMessage = false;
  bool _canReply = false;
  @override
  bool get canReply => !_disposed && _canReply;
  final _hiddenMessages = <String, Map<String, dynamic>>{};
  int _hiddenThrough = 0;
  String get _historyKey => 'direct:$peer';

  Future<void> _ensureHistory() => _historyReady ??= _restoreHistory()
      .catchError((Object error, StackTrace stack) {
        _historyReady = null;
        Error.throwWithStackTrace(error, stack);
      });
  Future<void> _restoreHistory() async {
    if (openHistory == null) return;
    final generation = _historyGeneration;
    final store = await openHistory!();
    if (store.account != repository.account) throw StateError('聊天记录账号不符');
    if (_disposed) return;
    _history = store;
    final page = await store.read(_historyKey);
    _diskEpoch = page.epoch;
    _historyVersion = page.historyVersion;
    _hiddenThrough = page.hiddenThrough;
    if (_disposed || generation != _historyGeneration) return;
    final savedRead = page.presentation?['peerReadSequence'];
    final savedConversation = page.presentation?['conversationId'];
    if (savedRead is int &&
        savedRead >= 0 &&
        savedConversation is String &&
        (page.messages.isEmpty ||
            page.messages.first['conversationId'] == savedConversation)) {
      peerReadSequence = savedRead;
      conversationId = savedConversation;
    }
    for (final message in page.messages) {
      _confirmed[message['messageId'] as String] = message;
    }
    _lastSynced = page.cursor;
    if (page.messages.isNotEmpty) {
      _refreshCachedPage = true;
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
  bool _refreshCachedPage = false;
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
  int _readConfirmed = 0;
  final _readsPending = <int>{};

  @override
  List<Map<String, dynamic>> get messages {
    final confirmed =
        _confirmed.values
            .map(
              (message) => {
                ...message,
                if (message['sender'] == repository.account)
                  'peerRead':
                      _relayPeerRead.contains(message['clientMessageId']) ||
                      ((message['sequence'] as num) > 0 &&
                          (message['sequence'] as num) <= peerReadSequence),
              },
            )
            .toList()
          ..sort(
            (a, b) => (a['sequence'] as num).compareTo(b['sequence'] as num),
          );
    final acknowledged = confirmed
        .where((m) => m['sender'] == repository.account)
        .map((m) => m['clientMessageId'])
        .toSet();
    final confirmedKeys = confirmed
        .map((m) => (m['sender'], m['clientMessageId']))
        .toSet();
    final relay =
        _relayMessages
            .where(
              (m) =>
                  !confirmedKeys.contains((m['sender'], m['clientMessageId'])),
            )
            .toList()
          ..sort((a, b) {
            final time = (a['createdDate'] as String).compareTo(
              b['createdDate'] as String,
            );
            if (time != 0) return time;
            final id = (a['clientMessageId'] as String).compareTo(
              b['clientMessageId'] as String,
            );
            return id != 0
                ? id
                : (a['sender'] as String).compareTo(b['sender'] as String);
          });
    final relayOutgoing = relay
        .where((m) => m['sender'] == repository.account)
        .map((m) => m['clientMessageId'])
        .toSet();
    return mergeLocalChatMessages(
      confirmed.where((m) => m['messageType'] != 'hidden'),
      [
        ...relay,
        ..._pending.values
            .where(
              (m) =>
                  !acknowledged.contains(m['clientMessageId']) &&
                  !relayOutgoing.contains(m['clientMessageId']),
            )
            .map(
              (m) => m['peerDelivered'] == true ? {...m, 'status': 'sent'} : m,
            ),
      ],
    );
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_relayEvents?.cancel());
    super.dispose();
  }

  @override
  Future<void> initialize() async {
    try {
      if (_disposed) return;
      for (final message in await outbox.read()) {
        if (_disposed) return;
        if (message['recipient'] == peer) {
          _pending[message['clientMessageId'] as String] = message;
        }
      }
      _changed();
      unawaited(_refreshRelay());
      if (openHistory != null) await _ensureHistory();
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

  Future<bool> _acceptHistoryRevision(Map<String, dynamic> result) async {
    final version = result['historyVersion'];
    // Older deployed servers have no revision yet. Once observed, it is required.
    if (version == null && _historyVersion == null) return true;
    if (version is! int || version < 0 || version > 4294967295) {
      throw const FormatException('Invalid history revision');
    }
    if (_historyVersion != null && version < _historyVersion!) {
      throw StateError('聊天记录已变化，请重新同步');
    }
    if (version == _historyVersion) return true;
    // Advance generation synchronously: previous history and send responses may
    // not restore pre-recall content while the disk invalidation is pending.
    resetVisibleHistory();
    _historyVersion = version;
    final generation = _historyGeneration;
    _historyBarrier = (_historyBarrier ?? Future<void>.value()).then((_) async {
      if (_disposed || generation != _historyGeneration) return;
      if (_history != null) {
        final epoch = await _history!.adoptHistoryVersion(
          _historyKey,
          expectedEpoch: _diskEpoch,
          historyVersion: version,
        );
        if (_disposed || generation != _historyGeneration) return;
        if (epoch == null) throw StateError('聊天记录版本已变化');
        _diskEpoch = epoch;
      }
    });
    await synchronize();
    return false;
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
        if (!await _acceptHistoryRevision(result)) return;
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
      // Refresh additive server metadata without clearing visible cached rows.
      if (_refreshCachedPage &&
          !_disposed &&
          generation == _historyGeneration) {
        final latest = await repository.history(peer);
        if (_disposed || generation != _historyGeneration) return;
        if (!await _acceptHistoryRevision(latest)) return;
        await _merge(latest, generation);
        if (_disposed || generation != _historyGeneration) return;
        _refreshCachedPage = false;
      }
      error = null;
      _changed();
    } catch (e) {
      if (_disposed || generation != _historyGeneration) return;
      // A failed background refresh does not invalidate readable local history.
      // Keep failures from explicit sends, pagination and access checks visible.
      error =
          e is AuthFailure &&
              e.code == 'NETWORK_ERROR' &&
              _confirmed.values.any((row) => row['messageType'] != 'hidden')
          ? null
          : e.toString();
      _changed();
    }
  }

  @override
  Future<void> loadOlder() async {
    if (!hasOlder || _oldest == null || _disposed) return;
    final generation = _historyGeneration;
    final before = _oldest;
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
        }
      }
      // Show cached rows immediately, then refresh the same page from the
      // server. Advancing before first would skip those cached records forever.
      final result = await repository.history(peer, before: before);
      if (_disposed || generation != _historyGeneration) return;
      if (!await _acceptHistoryRevision(result)) return;
      await _merge(result, generation);
      if (_disposed || generation != _historyGeneration) return;
      final rows = result['messages'] as List;
      if (rows.isNotEmpty) _oldest = (rows.first['sequence'] as num).toInt();
      hasOlder = result['hasMore'] == true;
      error = null;
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
        .map((raw) => _preserveHidden(Map<String, dynamic>.from(raw as Map)))
        .toList();
    for (final message in rows) {
      _validatePendingReceipt(message);
    }
    final hidden = (result['settings'] as Map)['hiddenThrough'];
    if (_history != null) {
      if (hidden is! int || hidden < 0) throw StateError('服务端尚未提供聊天记录同步信息');
      final committed = await _history!.commit(
        _historyKey,
        rows,
        expectedEpoch: _diskEpoch,
        historyVersion: _historyVersion,
        hiddenThrough: hidden,
        peerReadSequence: (result['peerReadSequence'] as num).toInt(),
        serverConversationId: result['conversationId'] as String,
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
    final nextConversationId = result['conversationId'] as String;
    final nextPeerRead = (result['peerReadSequence'] as num).toInt();
    // An older-page request can finish after a newer synchronization. Reads
    // cannot be undone by that stale snapshot within the same conversation.
    if (conversationId != nextConversationId ||
        nextPeerRead > peerReadSequence) {
      peerReadSequence = nextPeerRead;
    }
    conversationId = nextConversationId;
    permission = Map<String, dynamic>.from(result['sendPermission'] as Map);
    _canHideMessage = result['canHideMessage'] == true;
    _canReply = result['canReply'] == true;
    settings = Map<String, dynamic>.from(result['settings'] as Map);
    for (final message in rows) {
      if (_disposed || generation != _historyGeneration) return;
      if (hidden is int && (message['sequence'] as int) <= hidden) continue;
      await _acknowledge(message, persist: false);
    }
    unawaited(_refreshRelay());
  }

  Map<String, dynamic> _preserveHidden(Map<String, dynamic> message) {
    final messageId = message['messageId'] as String;
    final previous = _hiddenMessages[messageId] ?? _confirmed[messageId];
    if (message['messageType'] == 'hidden') {
      _hiddenMessages[messageId] = Map<String, dynamic>.from(message);
    } else if (previous?['messageType'] == 'hidden' ||
        previous?['messageType'] == 'recalled') {
      message = Map<String, dynamic>.from(previous!);
      _hiddenMessages[messageId] = message;
    }
    return message;
  }

  void _validatePendingReceipt(Map<String, dynamic> message) {
    if (message['sender'] != repository.account) return;
    final pending = _pending[message['clientMessageId']];
    if (pending != null) validateQueuedMessageReceipt(pending, message);
  }

  Future<void> _acknowledge(
    Map<String, dynamic> message, {
    bool persist = true,
  }) async {
    message = _preserveHidden(message);
    _validatePendingReceipt(message);
    final generation = _historyGeneration;
    if (persist && openHistory != null) {
      await _ensureHistory();
      await _historyBarrier;
      if (_disposed || generation != _historyGeneration) return;
      if (!await _history!.commit(
        _historyKey,
        [message],
        expectedEpoch: _diskEpoch,
        recordOutgoingHead: _pending.containsKey(message['clientMessageId']),
        historyVersion: _historyVersion,
      )) {
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
  Future<void> send(
    String text, {
    VoidCallback? onQueued,
    String? replyToMessageId,
    String? clientMessageId,
  }) async {
    if (replyToMessageId != null &&
        (!canReply ||
            !RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(replyToMessageId))) {
      throw StateError('当前无法引用该消息');
    }
    text = text.trim();
    if (text.isEmpty || _disposed) return;
    if (text.length > 4000) throw StateError('文字最多4000字');
    final id = clientMessageId ?? const Uuid().v4();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw ArgumentError('Invalid message identifier');
    }
    final message = <String, dynamic>{
      'clientMessageId': id,
      'recipient': peer,
      'sender': repository.account,
      'text': text,
      'replyToMessageId': ?replyToMessageId,
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
  Future<void> sendImage(
    String assetId, {
    VoidCallback? onQueued,
    String? clientMessageId,
  }) async {
    if (_disposed) return;
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(assetId)) {
      throw ArgumentError('图片上传结果无效');
    }
    final id = clientMessageId ?? const Uuid().v4();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw ArgumentError('Invalid image message identifier');
    }
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
    String? clientMessageId,
  }) async {
    if (_disposed) return;
    final id = clientMessageId ?? const Uuid().v4();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw ArgumentError('Invalid location message ID');
    }
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
    String? clientMessageId,
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
    final id = clientMessageId ?? const Uuid().v4();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw ArgumentError('文件消息编号无效');
    }
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
    String? clientMessageId,
  }) async {
    if (_disposed) return;
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(assetId)) {
      throw ArgumentError('语音上传结果无效');
    }
    if (durationMs < 1000 || durationMs > 60500) throw ArgumentError('录音时长无效');
    final id = clientMessageId ?? const Uuid().v4();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const FormatException('语音消息编号无效');
    }
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
  Future<void> sendVideo(
    ChatVideo video, {
    VoidCallback? onQueued,
    String? clientMessageId,
  }) async {
    if (_disposed) return;
    final id = clientMessageId ?? const Uuid().v4();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const FormatException('视频消息编号无效');
    }
    final message = <String, dynamic>{
      'clientMessageId': id,
      'recipient': peer,
      'sender': repository.account,
      'messageType': 'video',
      ...video.toMessageFields(),
      'text': '[视频]',
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
    var peerDelivered = pending['peerDelivered'] == true;
    var attemptedPeer = false;
    _pending[id] = {...pending, 'status': 'sending'};
    _changed();
    try {
      final kind = pending['messageType'];
      if (!peerDelivered &&
          sendRelayText != null &&
          preferRelayText?.call() == true &&
          (kind == null || kind == 'text') &&
          pending['replyToMessageId'] == null) {
        attemptedPeer = true;
        try {
          peerDelivered = await sendRelayText!(
            pending['text'] as String,
            id,
          ).timeout(const Duration(seconds: 3));
        } catch (_) {
          // An unavailable peer route must not prevent normal service delivery.
        }
        if (_disposed ||
            historyGeneration != _historyGeneration ||
            !_pending.containsKey(id)) {
          return;
        }
        if (peerDelivered) {
          final delivered = {
            ...pending,
            'status': 'queued',
            'peerDelivered': true,
          };
          await outbox.put(delivered);
          if (!_pending.containsKey(id)) {
            await outbox.remove(id);
            return;
          }
          if (_disposed || historyGeneration != _historyGeneration) return;
          _pending[id] = delivered;
          _changed();
        }
      }
      if (kind != null &&
          kind != 'text' &&
          kind != 'image' &&
          kind != 'voice' &&
          kind != 'video' &&
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
          : kind == 'video'
          ? await repository.sendVideo(
              peer: peer,
              clientMessageId: id,
              assetId: pending['videoAssetId'] as String,
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
              replyToMessageId: pending['replyToMessageId'] as String?,
            );
      if (_disposed) return;
      final received = Map<String, dynamic>.from(result['message'] as Map);
      final recalled = ['recalled', 'hidden'].contains(received['messageType']);
      _validatePendingReceipt(received);
      if (!recalled &&
          pending['replyToMessageId'] != null &&
          (received['reply'] is! Map ||
              (received['reply'] as Map)['messageId'] !=
                  pending['replyToMessageId'])) {
        throw StateError('引用回复回执不一致');
      }
      if (!recalled &&
          kind == 'location' &&
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
      if (!recalled &&
          kind == 'file' &&
          (received['messageType'] != 'file' ||
              [
                'fileAssetId',
                'fileName',
                'fileSize',
                'fileSha256',
              ].any((key) => received[key] != pending[key]))) {
        throw const FormatException('文件回执与发送内容不符');
      }
      if (!recalled &&
          kind == 'video' &&
          (received['messageType'] != 'video' ||
              [
                'videoAssetId',
                'videoDurationMs',
                'videoWidth',
                'videoHeight',
                'videoHasAudio',
              ].any((key) => received[key] != pending[key]))) {
        throw const FormatException('视频回执与发送内容不符');
      }
      if (!recalled &&
          kind == 'voice' &&
          (received['messageType'] != 'voice' ||
              received['voiceAssetId'] != pending['voiceAssetId'] ||
              received['voiceDurationMs'] != pending['voiceDurationMs'])) {
        throw const FormatException('语音回执与发送内容不符');
      }
      if (received['clientMessageId'] != id ||
          received['sender'] != repository.account ||
          received['recipient'] != peer ||
          (!recalled &&
              kind == 'image' &&
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
      if (transient &&
          !peerDelivered &&
          !attemptedPeer &&
          sendRelayText != null &&
          (pending['messageType'] == null ||
              pending['messageType'] == 'text') &&
          pending['replyToMessageId'] == null &&
          historyGeneration == _historyGeneration) {
        try {
          peerDelivered = await sendRelayText!(
            pending['text'] as String,
            id,
          ).timeout(const Duration(seconds: 8));
        } catch (_) {
          // Keep the durable service retry queue if no peer receipt arrives.
        }
      }
      if (_disposed || !_pending.containsKey(id)) {
        return;
      }
      final failed = {
        ...pending,
        'status': transient ? 'queued' : 'failed',
        'error': e.toString(),
        if (peerDelivered) 'peerDelivered': true,
      };
      await outbox.put(failed);
      // History may confirm delivery while the failed-state write is pending.
      // Never resurrect an acknowledged message into the retry queue.
      if (!_pending.containsKey(id)) {
        await outbox.remove(id);
        return;
      }
      if (_disposed) return;
      _pending[id] = failed;
      error = peerDelivered ? null : e.toString();
    } finally {
      _sending.remove(id);
      _changed();
    }
  }

  @override
  bool canHideMessage(String messageId) =>
      !_disposed &&
      _canHideMessage &&
      messages.any((m) => m['messageId'] == messageId && m['status'] == 'sent');

  @override
  Future<void> hideMessage(String messageId) async {
    if (!canHideMessage(messageId)) throw StateError('该消息当前不可删除');
    await repository.call('K260914000663', {
      'peer': peer,
      'messageId': messageId,
    });
    if (_disposed) return;
    final original = _confirmed[messageId];
    if (original != null) {
      _hiddenMessages[messageId] = {
        for (final key in [
          'messageId',
          'conversationId',
          'groupId',
          'sequence',
          'sender',
          'recipient',
          'clientMessageId',
          'createdDate',
        ])
          if (original.containsKey(key)) key: original[key],
        'messageType': 'hidden',
        'text': '',
        'status': 'sent',
      };
    }
    resetVisibleHistory(clearMedia: true, deletedMessageIds: {messageId});
    await synchronize();
  }

  @override
  bool canRecall(String messageId) =>
      _historyVersion != null &&
      !messages.any((m) => m['messageId'] == messageId && m['call'] is Map) &&
      super.canRecall(messageId);

  @override
  Future<void> recall(String messageId) async {
    if (_disposed) return;
    await repository.call('K260914000661', {
      'peer': peer,
      'messageId': messageId,
    });
    if (_disposed) return;
    // Remove stale content immediately after acknowledgement, even if refresh
    // fails. Reconnect will reload the authoritative tombstone.
    resetVisibleHistory(clearMedia: true, deletedMessageIds: {messageId});
    await synchronize();
  }

  @override
  Future<void> markVisibleRead(int sequence) async {
    if (_disposed ||
        sequence <= _readConfirmed ||
        _readsPending.any((pending) => pending >= sequence)) {
      return;
    }
    final generation = _historyGeneration;
    _readsPending.add(sequence);
    try {
      await repository.markRead(peer, sequence);
      if (!_disposed &&
          generation == _historyGeneration &&
          sequence > _readConfirmed) {
        _readConfirmed = sequence;
      }
    } catch (_) {
      // Only successful requests advance the cursor; failed concurrent
      // requests must not leave one another looking acknowledged.
    } finally {
      if (generation == _historyGeneration) _readsPending.remove(sequence);
    }
  }

  /// Called only after the server has committed the owner's hide cursor.
  @override
  void resetVisibleHistory({
    bool hideNearby = false,
    bool clearMedia = false,
    Set<String>? deletedMessageIds,
  }) {
    _historyGeneration++;
    _readConfirmed = 0;
    _readsPending.clear();
    _relayRead++;
    _relayMessages = [];
    _relayPeerRead = {};
    if (openHistory != null) {
      _historyBarrier = (_historyBarrier ?? _ensureHistory()).then((_) async {
        if (_history != null) {
          _diskEpoch = await _history!.clear(
            _historyKey,
            hideNearby: hideNearby,
            deleteMedia: clearMedia,
            deletedMessageIds: deletedMessageIds,
          );
        }
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
