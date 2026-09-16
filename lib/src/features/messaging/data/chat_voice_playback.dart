import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';

import '../../../core/media/media_cache.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import 'messaging_repository.dart';

abstract class ChatVoiceOutput {
  Future<void> play(String path);
  Future<void> stop();
  Future<void> dispose();
  Stream<void> get completed;
}

class NativeChatVoiceOutput implements ChatVoiceOutput {
  final AudioPlayer _player = AudioPlayer();
  @override
  Future<void> play(String path) => _player.play(DeviceFileSource(path));
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
  @override
  Stream<void> get completed => _player.onPlayerComplete;
}

typedef VoiceFileLoader = Future<File> Function(
  String url,
  String account,
  String fileId,
  Map<String, String> headers,
);

/// One output per conversation; every tap authorizes before touching cached audio.
class ChatVoicePlayback extends ChangeNotifier with WidgetsBindingObserver {
  ChatVoicePlayback({
    ChatVoiceOutput? output,
    VoiceFileLoader? loadFile,
    Future<void> Function(String account, String fileId)? evictFile,
    Stream<Map<String, dynamic>>? events,
    MediaCache? mediaStore,
  }) : _output = output ?? NativeChatVoiceOutput(),
       _mediaStore = mediaStore ?? MediaCache.shared,
       _loadFile = loadFile ?? _cached,
       _evictFile = evictFile ?? _evictCached {
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      stop();
    });
    _events = (events ?? KingclubRealtime.shared.events).listen((event) {
      final data = event['data'];
      final eventGroup = data is Map ? data['groupId'] : null;
      final eventConversation = data is Map ? data['conversationId'] : null;
      if ((event['eventType'] == 'chat.settings.changed' ||
              event['eventType'] == 'chat.relationship.changed') &&
          eventConversation is String &&
          eventConversation.isNotEmpty &&
          (_playingGroup ||
              (_conversationId != null &&
                  eventConversation != _conversationId))) {
        return;
      }
      if ((event['eventType'] == 'chat.group.changed' ||
              event['eventType'] == 'chat.group.read') &&
          eventGroup is String &&
          eventGroup.isNotEmpty &&
          (!_playingGroup || (_groupId != null && eventGroup != _groupId))) {
        return;
      }
      if (event['eventType'] == 'chat.group.read') {
        unawaited(_recheckPermission());
        return;
      }
      if ([
        'chat.settings.changed',
        'chat.group.changed',
        'chat.relationship.changed',
        'connection.ready',
      ].contains(event['eventType'])) {
        stop();
      }
    });
    _complete = _output.completed.listen(
      (_) {
        if (!_disposed && _playingGeneration == _generation) {
          _playingGeneration = null;
          activeId = null;
          loading = false;
          notifyListeners();
        }
      },
      onError: (Object _, StackTrace _) {
        if (_disposed ||
            _playingGeneration == null ||
            _playingGeneration != _generation) {
          return;
        }
        unawaited(stop());
        error = '语音播放中断，请重试';
        notifyListeners();
      },
    );
  }
  static Future<File> _cached(
    String url,
    String account,
    String fileId,
    Map<String, String> headers,
  ) => MediaCache.shared.get(
    url,
    scope: 'member:$account',
    contentKey: 'chat-voice:$account:$fileId',
    kind: MediaKind.audio,
    headers: headers,
  );
  static Future<void> _evictCached(String account, String fileId) =>
      MediaCache.shared.evict(
        scope: 'member:$account',
        contentKey: 'chat-voice:$account:$fileId',
        kind: MediaKind.audio,
      );
  final Future<void> Function(String, String) _evictFile;
  final ChatVoiceOutput _output;
  final MediaCache _mediaStore;
  final VoiceFileLoader _loadFile;
  StreamSubscription<void>? _session, _complete;
  StreamSubscription<Map<String, dynamic>>? _events;
  Future<void> _operations = Future.value();
  bool _invalid = false, _disposed = false;
  int _generation = 0;
  int? _playingGeneration;
  MessagingRepository? _repository;
  int? _checkingGeneration;
  int _permissionRevision = 0;
  bool _playingGroup = false;
  String? _groupId, _conversationId;
  String? activeId, error;
  bool loading = false;
  Future<void> _serialize(Future<void> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.catchError((Object _) {});
    return next;
  }

  // The legacy group.read event also represents hide/settings changes.
  // Re-authorize without cutting off audio for an ordinary read receipt.
  Future<void> _recheckPermission() async {
    final repository = _repository, message = activeId;
    final generation = _generation;
    if (_disposed || _invalid || repository == null || message == null) {
      return;
    }
    _permissionRevision++;
    if (_checkingGeneration == generation) return;
    _checkingGeneration = generation;
    final group = _playingGroup;
    try {
      while (!_disposed &&
          !_invalid &&
          generation == _generation &&
          activeId == message) {
        final revision = _permissionRevision;
        final result = await repository.voiceMedia(message, group: group);
        if (result['messageId'] != message || result['voice'] is! Map) {
          throw const FormatException('Invalid voice permission');
        }
        // A hide/settings event may have arrived after this request took its
        // server snapshot. Check again instead of trusting that stale grant.
        if (revision == _permissionRevision) break;
      }
    } catch (_) {
      if (!_disposed && generation == _generation) await stop();
    } finally {
      if (_checkingGeneration == generation) _checkingGeneration = null;
    }
  }

  Future<void> stop() async {
    _generation++;
    _playingGeneration = null;
    activeId = null;
    loading = false;
    if (!_disposed) notifyListeners();
    await _serialize(_output.stop).catchError((Object _) {});
  }

  Future<void> toggle(
    MessagingRepository repository,
    String messageId, {
    bool group = false,
    String? groupId,
    String? conversationId,
    String? assetId,
  }) async {
    if (_disposed || _invalid) return;
    if (activeId == messageId) {
      await stop();
      return;
    }
    final stoppingGeneration = _generation + 1;
    await stop();
    if (_disposed || _invalid || stoppingGeneration != _generation) return;
    final generation = ++_generation;
    _repository = repository;
    _playingGroup = group;
    _groupId = groupId;
    _conversationId = conversationId;
    activeId = messageId;
    loading = true;
    error = null;
    notifyListeners();
    bool current() => !_disposed && !_invalid && generation == _generation;
    try {
      final localKey =
          assetId != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(assetId)
          ? 'chat-voice-asset:$assetId'
          : null;
      if (localKey != null) {
        File? local;
        try {
          local = await _mediaStore.cached(
            scope: 'member:${repository.account}',
            contentKey: localKey,
            kind: MediaKind.audio,
          );
        } on StateError {
          // Not downloaded on this device yet.
        } on FileSystemException {
          // A concurrent explicit cleanup can remove a saved file.
        }
        if (!current()) return;
        if (local != null) {
          final path = local.path;
          await _serialize(() async {
            if (!current()) return;
            _playingGeneration = generation;
            try {
              await _output.play(path);
            } catch (_) {
              try {
                await _output.stop();
              } catch (_) {}
              await _mediaStore.evict(
                scope: 'member:${repository.account}',
                contentKey: localKey,
                kind: MediaKind.audio,
              );
              rethrow;
            }
          });
          if (!current()) return;
          loading = false;
          notifyListeners();
          return;
        }
      }
      final result = await repository.voiceMedia(messageId, group: group);
      if (!current()) return;
      final media = Map<String, dynamic>.from(result['voice'] as Map);
      final fileId = media['fileId'], duration = media['durationMs'];
      final token = (media['headers'] as Map?)?['authorization'];
      if (result['messageId'] != messageId ||
          media['path'] !=
              '/kingclub/${group ? 'group-chat-voice' : 'chat-voice'}/$messageId' ||
          fileId is! String ||
          !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(fileId) ||
          duration is! int ||
          duration < 1000 ||
          duration > 60500 ||
          media['contentType'] != 'audio/mp4' ||
          token is! String ||
          !token.startsWith('Bearer ')) {
        throw const FormatException('语音授权无效');
      }
      final file = await _loadFile(
        "${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}${media['path']}",
        repository.account,
        fileId,
        {'authorization': token},
      );
      if (!current()) return;
      if (localKey != null) {
        await _mediaStore.importFile(
          file,
          scope: 'member:${repository.account}',
          contentKey: localKey,
          kind: MediaKind.audio,
        );
        if (!current()) return;
      }
      await _serialize(() async {
        if (current()) {
          _playingGeneration = generation;
          try {
            await _output.play(file.path);
          } catch (_) {
            // Stop a partially started native player before forgetting its file.
            try {
              await _output.stop();
            } catch (_) {}
            try {
              await _evictFile(repository.account, fileId);
            } catch (_) {}
            rethrow;
          }
        }
      });
      if (!current()) return;
      loading = false;
      notifyListeners();
    } catch (failure) {
      if (current()) {
        _playingGeneration = null;
        activeId = null;
        loading = false;
        error = _isNetworkFailure(failure)
            ? '网络连接失败，请联网后点击语音重试'
            : '语音暂不可播放，请重试';
        notifyListeners();
      }
    }
  }

  static bool _isNetworkFailure(Object failure) {
    if (failure is SocketException || failure is TimeoutException) return true;
    if (failure is AuthFailure) return failure.code == 'NETWORK_ERROR';
    if (failure is DioException) {
      return switch (failure.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => true,
        _ => false,
      };
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) stop();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _session?.cancel();
    _events?.cancel();
    _complete?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _serialize(() async {
      try {
        await _output.stop();
      } finally {
        await _output.dispose();
      }
    }).catchError((Object _) {});
    super.dispose();
  }
}
