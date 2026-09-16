import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/session/secure_session_store.dart';
import '../../../core/media/media_cache.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'chat_voice_uploader.dart';
import 'messaging_repository.dart';

/// Copies an authorized source into an independently owned upload. Source
/// message IDs/grants are never placed in the destination message or outbox.
class ChatVoiceForwarder {
  ChatVoiceForwarder({
    required this.repository,
    required this.messageId,
    this.group = false,
    Dio? dio,
    this.upload,
    this.mediaStore,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), ''),
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ) {
    _session = SecureSessionStore.changes.stream.listen((_) => dispose());
  }
  final MessagingRepository repository;
  final String messageId;
  final bool group;
  final Dio _dio;
  final Future<UploadedChatVoice> Function(Uint8List)? upload;
  final MediaCache? mediaStore;
  Uint8List? _sourceBytes;
  StreamSubscription<void>? _session;
  ChatVoiceUploader? _uploader;
  final _cancel = CancelToken();
  UploadedChatVoice? _prepared;
  bool _closed = false, _busy = false;
  void _check() {
    if (_closed) throw StateError('语音转发已结束');
  }

  Future<UploadedChatVoice> prepare() async {
    _check();
    if (_prepared != null) return _prepared!;
    if (_busy) throw StateError('正在准备语音');
    _busy = true;
    try {
      final result = await repository.voiceMedia(messageId, group: group);
      _check();
      final voice = result['voice'];
      final path =
          '/kingclub/${group ? 'group-chat-voice' : 'chat-voice'}/$messageId';
      if (result['messageId'] != messageId ||
          voice is! Map ||
          voice['path'] != path ||
          voice['fileId'] is! String ||
          voice['contentType'] != 'audio/mp4' ||
          voice['durationMs'] is! int ||
          (voice['durationMs'] as int) < 1000 ||
          (voice['durationMs'] as int) > 60500 ||
          voice['headers'] is! Map ||
          voice['headers']['authorization'] is! String ||
          !(voice['headers']['authorization'] as String).startsWith(
            'Bearer ',
          )) {
        throw const FormatException('语音授权无效');
      }
      final response = await _dio.get<ResponseBody>(
        path,
        cancelToken: _cancel,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          headers: {'authorization': voice['headers']['authorization']},
        ),
      );
      _check();
      if (response.statusCode != 200 || response.data == null) {
        throw StateError('语音读取失败');
      }
      const maxBytes = 2 * 1024 * 1024;
      final declared = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      if (declared != null && (declared <= 0 || declared > maxBytes)) {
        throw StateError('语音大小无效');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.data!.stream) {
        _check();
        if (bytes.length + chunk.length > maxBytes) {
          throw StateError('语音超过2MB');
        }
        bytes.add(chunk);
      }
      _check();
      if (bytes.isEmpty || (declared != null && declared != bytes.length)) {
        throw StateError('语音未完整下载');
      }
      final data = bytes.takeBytes();
      if (upload != null) {
        _prepared = await upload!(data);
      } else {
        final uploader = _uploader ?? await ChatVoiceUploader.open(repository);
        if (_closed) {
          uploader.dispose();
          _check();
        }
        _uploader = uploader;
        _prepared = await uploader.upload(data);
      }
      _check();
      _sourceBytes = data;
      return _prepared!;
    } finally {
      _busy = false;
    }
  }

  Future<void> acknowledgeQueued() async {
    _check();
    final voice = _prepared;
    final bytes = _sourceBytes;
    if (voice != null && bytes != null) {
      await (mediaStore ?? MediaCache.shared).importBytes(
        bytes,
        scope: 'member:${repository.account}',
        contentKey: 'chat-voice-asset:${voice.assetId}',
        kind: MediaKind.audio,
      );
      _check();
    }
    _sourceBytes = null;
    if (voice != null) await _uploader?.acknowledgeQueued(voice);
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _prepared = null;
    _sourceBytes = null;
    _cancel.cancel('voice forwarding closed');
    _session?.cancel();
    _uploader?.dispose();
    _dio.close(force: true);
  }
}
