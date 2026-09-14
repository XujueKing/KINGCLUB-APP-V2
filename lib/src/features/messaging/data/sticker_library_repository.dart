import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:dio/dio.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'messaging_repository.dart';

final _assetPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

class StickerPack {
  StickerPack(this.name, List<String> assets)
    : assets = List.unmodifiable(assets);
  final String name;
  final List<String> assets;
  Map<String, dynamic> toJson() => {'name': name, 'images': assets};
}

class StickerLibrarySnapshot {
  StickerLibrarySnapshot(this.revision, List<StickerPack> packs)
    : packs = List.unmodifiable(packs);
  final int revision;
  final List<StickerPack> packs;
  factory StickerLibrarySnapshot.parse(Map<String, dynamic> data) {
    final revision = data['revision'], raw = data['packs'];
    if (revision is! int ||
        revision < 0 ||
        revision > 2147483647 ||
        raw is! List ||
        raw.isEmpty ||
        raw.length > 20) {
      throw const FormatException('表情库数据无效');
    }
    var count = 0;
    final packs = <StickerPack>[];
    for (final item in raw) {
      if (item is! Map) throw const FormatException('表情分类无效');
      final name = item['name'], images = item['images'];
      if (name is! String ||
          name.trim().isEmpty ||
          name.length > 20 ||
          images is! List ||
          images.length > 200) {
        throw const FormatException('表情分类无效');
      }
      final assets = <String>[];
      for (final asset in images) {
        if (asset is! String || !_assetPattern.hasMatch(asset)) {
          throw const FormatException('表情图片无效');
        }
        assets.add(asset);
      }
      count += assets.length;
      if (count > 500) throw const FormatException('表情数量过多');
      packs.add(StickerPack(name, assets));
    }
    return StickerLibrarySnapshot(revision, packs);
  }
}

/// Account-bound cloud protocol. Local library reconciliation belongs to caller.
class StickerLibraryRepository {
  StickerLibraryRepository(this.messaging, {Dio? dio})
    : _dio =
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
  final MessagingRepository messaging;
  final Dio _dio;
  final int _generation = MemberQrMemory.generation;
  final _downloads = <CancelToken>{};
  StreamSubscription<void>? _session;
  bool _disposed = false;
  void _check() {
    if (_disposed || _generation != MemberQrMemory.generation) {
      throw StateError('登录状态已变化');
    }
  }

  Future<StickerLibrarySnapshot> read() async {
    _check();
    final result = await messaging.call('K260915000676', {'action': 'read'});
    _check();
    return StickerLibrarySnapshot.parse(result);
  }

  Future<StickerLibrarySnapshot> write(
    int revision,
    List<StickerPack> packs,
  ) async {
    final raw = packs.map((p) => p.toJson()).toList();
    StickerLibrarySnapshot.parse({'revision': revision, 'packs': raw});
    if (revision >= 2147483647) throw const FormatException('表情版本已达上限');
    _check();
    final result = await messaging.call('K260915000676', {
      'action': 'write',
      'revision': revision,
      'packs': raw,
    });
    _check();
    final saved = StickerLibrarySnapshot.parse(result);
    if (saved.revision != revision + 1 ||
        jsonEncode(saved.packs.map((p) => p.toJson()).toList()) !=
            jsonEncode(raw)) {
      throw const FormatException('表情保存回执不符');
    }
    return saved;
  }

  Future<Uint8List> download(String assetId) async {
    _check();
    if (!_assetPattern.hasMatch(assetId)) throw const FormatException('表情图片无效');
    final grant = await messaging.call('K260915000677', {'assetId': assetId});
    _check();
    final size = grant['size'],
        digest = grant['sha256'],
        headers = grant['headers'];
    final token = headers is Map ? headers['authorization'] : null;
    final path = '/kingclub/sticker-image/$assetId';
    if (grant['assetId'] != assetId ||
        grant['path'] != path ||
        size is! int ||
        size < 1 ||
        size > 20 * 1024 * 1024 ||
        digest is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        token is! String ||
        !token.startsWith('Bearer ') ||
        token.contains('\r') ||
        token.contains('\n')) {
      throw const FormatException('表情下载授权无效');
    }
    final cancel = CancelToken();
    _downloads.add(cancel);
    try {
      final response = await _dio.get<ResponseBody>(
        path,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          headers: {'authorization': token},
        ),
      );
      _check();
      if (response.statusCode != 200 || response.data == null) {
        throw const FormatException('表情下载失败');
      }
      final output = BytesBuilder(copy: false);
      final hash = const DartSha256().newHashSink();
      var count = 0;
      try {
        await for (final chunk in response.data!.stream) {
          _check();
          count += chunk.length;
          if (count > size) throw const FormatException('表情大小不符');
          hash.add(chunk);
          output.add(chunk);
        }
      } finally {
        hash.close();
      }
      final actual = (await hash.hash()).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      _check();
      if (count != size || actual != digest) {
        throw const FormatException('表情完整性校验失败');
      }
      return output.takeBytes();
    } finally {
      _downloads.remove(cancel);
      cancel.cancel();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _session?.cancel();
    for (final cancel in _downloads) {
      cancel.cancel();
    }
    _downloads.clear();
    _dio.close(force: true);
  }
}
