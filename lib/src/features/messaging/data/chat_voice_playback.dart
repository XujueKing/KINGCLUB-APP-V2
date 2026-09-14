import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../core/media/media_cache.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
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
    Stream<Map<String, dynamic>>? events,
  }) : _output = output ?? NativeChatVoiceOutput(),
       _loadFile = loadFile ?? _cached {
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      stop();
    });
    _events = (events ?? KingclubRealtime.shared.events).listen((event) {
      final data = event['data'];
      final eventGroup = data is Map ? data['groupId'] : null;
      if ((event['eventType'] == 'chat.group.changed' ||
              event['eventType'] == 'chat.group.read') &&
          eventGroup is String &&
          eventGroup.isNotEmpty &&
          (!_playingGroup || (_groupId != null && eventGroup != _groupId))) {
        return;
      }
      if ([
        'chat.settings.changed',
        'chat.group.changed',
        'chat.group.read',
        'chat.relationship.changed',
        'connection.ready',
      ].contains(event['eventType'])) {
        stop();
      }
    });
    _complete = _output.completed.listen((_) {
      if (!_disposed) {
        activeId = null;
        loading = false;
        notifyListeners();
      }
    });
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
  final ChatVoiceOutput _output;
  final VoiceFileLoader _loadFile;
  StreamSubscription<void>? _session, _complete;
  StreamSubscription<Map<String, dynamic>>? _events;
  Future<void> _operations = Future.value();
  bool _invalid = false, _disposed = false;
  int _generation = 0;
  bool _playingGroup = false;
  String? _groupId;
  String? activeId, error;
  bool loading = false;
  Future<void> _serialize(Future<void> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.catchError((Object _) {});
    return next;
  }

  Future<void> stop() async {
    _generation++;
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
  }) async {
    if (_disposed || _invalid) return;
    if (activeId == messageId) {
      await stop();
      return;
    }
    await stop();
    if (_disposed || _invalid) return;
    final generation = ++_generation;
    _playingGroup = group;
    _groupId = groupId;
    activeId = messageId;
    loading = true;
    error = null;
    notifyListeners();
    bool current() => !_disposed && !_invalid && generation == _generation;
    try {
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
      await _serialize(() async {
        if (current()) await _output.play(file.path);
      });
      if (!current()) return;
      loading = false;
      notifyListeners();
    } catch (_) {
      if (current()) {
        activeId = null;
        loading = false;
        error = '语音暂不可播放，请重试';
        notifyListeners();
      }
    }
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
