import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/session/secure_session_store.dart';
import '../../../core/media/media_cache.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'chat_image_uploader.dart';
import 'messaging_repository.dart';

/// Copies an authorized source into an independently owned upload. Source
/// message IDs/grants are never placed in the destination message or outbox.
class ChatImageForwarder {
  ChatImageForwarder({
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
  final Future<UploadedChatImage> Function(Uint8List)? upload;
  final MediaCache? mediaStore;
  Uint8List? _sourceBytes;
  StreamSubscription<void>? _session;
  ChatImageUploader? _uploader;
  final _cancel = CancelToken();
  UploadedChatImage? _prepared;
  bool _closed = false, _busy = false;
  void _check() {
    if (_closed) throw StateError('图片转发已结束');
  }

  Future<UploadedChatImage> prepare() async {
    _check();
    if (_prepared != null) return _prepared!;
    if (_busy) throw StateError('正在准备图片');
    _busy = true;
    try {
      final result = await repository.imageMedia(messageId, group: group);
      _check();
      final image = result['image'];
      final path =
          '/kingclub/${group ? 'group-chat-image' : 'chat-image'}/$messageId/image';
      if (result['messageId'] != messageId ||
          image is! Map ||
          image['path'] != path ||
          image['fileId'] is! String ||
          image['headers'] is! Map ||
          image['headers']['authorization'] is! String ||
          !(image['headers']['authorization'] as String).startsWith(
            'Bearer ',
          )) {
        throw const FormatException('图片授权无效');
      }
      final response = await _dio.get<ResponseBody>(
        path,
        cancelToken: _cancel,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          headers: {'authorization': image['headers']['authorization']},
        ),
      );
      _check();
      if (response.statusCode != 200 || response.data == null) {
        throw StateError('图片读取失败');
      }
      const maxBytes = 20 * 1024 * 1024;
      final declared = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      if (declared != null && (declared <= 0 || declared > maxBytes)) {
        throw StateError('图片大小无效');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.data!.stream) {
        _check();
        if (bytes.length + chunk.length > maxBytes) {
          throw StateError('图片超过20MB');
        }
        bytes.add(chunk);
      }
      _check();
      if (bytes.isEmpty || (declared != null && declared != bytes.length)) {
        throw StateError('图片未完整下载');
      }
      final data = bytes.takeBytes();
      if (upload != null) {
        _prepared = await upload!(data);
      } else {
        final uploader = _uploader ?? await ChatImageUploader.open(repository);
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

  Future<void> acknowledgeQueued({String? clientMessageId}) async {
    _check();
    final bytes = _sourceBytes;
    if (clientMessageId != null && bytes != null) {
      await (mediaStore ?? MediaCache.shared).importBytes(
        bytes,
        scope: 'member:${repository.account}',
        contentKey: 'chat-image-sent:$clientMessageId',
        kind: MediaKind.image,
      );
      if (_closed) {
        await (mediaStore ?? MediaCache.shared).evict(
          scope: 'member:${repository.account}',
          contentKey: 'chat-image-sent:$clientMessageId',
          kind: MediaKind.image,
        );
      }
      _check();
    }
    _sourceBytes = null;
    final image = _prepared;
    if (image != null) await _uploader?.acknowledgeQueued(image);
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _prepared = null;
    _sourceBytes = null;
    _cancel.cancel('image forwarding closed');
    _session?.cancel();
    _uploader?.dispose();
    _dio.close(force: true);
  }
}
