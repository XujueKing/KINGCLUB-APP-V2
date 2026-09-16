import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

enum MediaKind { image, video, audio }

/// Persistent media store. URLs (including signed query strings) are
/// never written to disk. Private media must use an account-specific scope.
class MediaCache {
  MediaCache({
    Future<Directory> Function()? directory,
    Dio? dio,
    this.imageBudget = 200 * 1024 * 1024,
    this.videoBudget = 800 * 1024 * 1024,
    this.audioBudget = 100 * 1024 * 1024,
    this.retainMedia = true,
  }) : _directory = directory ?? _persistentDirectory,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 60),
             ),
           );
  static final shared = MediaCache();
  static Future<Directory>? _openingDirectory;
  static Future<Directory> _persistentDirectory() =>
      _openingDirectory ??= (() async {
        try {
          final root = Directory(
            '${(await getApplicationSupportDirectory()).path}/media-store-v1',
          );
          final legacy = Directory(
            '${(await getApplicationCacheDirectory()).path}/media-cache-v1',
          );
          if (!await root.exists() && await legacy.exists()) {
            await root.parent.create(recursive: true);
            await legacy.rename(root.path);
          }
          return root;
        } catch (_) {
          _openingDirectory = null;
          rethrow;
        }
      })();
  final Future<Directory> Function() _directory;
  final Dio _dio;
  final int imageBudget, videoBudget, audioBudget;
  final bool retainMedia;
  final Map<String, Future<File>> _pending = {};
  final Set<CancelToken> _downloads = {};
  int _generation = 0;
  Future<String> _hash(String value) async =>
      (await Sha256().hash(utf8.encode(value))).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

  Future<File> get(
    String url, {
    required String scope,
    String? contentKey,
    MediaKind kind = MediaKind.image,
    Map<String, String>? headers,
  }) async {
    final generation = _generation;
    final uri = Uri.parse(url);
    if (uri.scheme != 'https') throw const FormatException('媒体地址必须使用HTTPS');
    final key = await _hash('$scope|${kind.name}|${contentKey ?? url}');
    if (generation != _generation) throw StateError('Cache request cancelled');
    final result = await _pending.putIfAbsent(key, () async {
      try {
        return await _load(key, url, scope, kind, headers, generation);
      } finally {
        _pending.remove(key);
      }
    });
    if (generation != _generation) throw StateError('Cache request cancelled');
    return result;
  }

  /// Read an existing image only; an offline descriptor is not a download grant.
  Future<File> cachedImage({
    required String scope,
    required String contentKey,
  }) => cached(scope: scope, contentKey: contentKey, kind: MediaKind.image);

  /// Retain a local source atomically without deleting the source file.
  Future<File> importFile(
    File source, {
    required String scope,
    required String contentKey,
    required MediaKind kind,
  }) async {
    final generation = _generation;
    final key = await _hash('$scope|${kind.name}|$contentKey');
    if (generation != _generation) throw StateError('媒体保存已取消');
    final result = await _pending.putIfAbsent(key, () async {
      File? temp;
      try {
        final root = await _directory();
        final extension = switch (kind) {
          MediaKind.image => '.media',
          MediaKind.audio => '.m4a',
          MediaKind.video => '.mp4',
        };
        final file = File(
          '${root.path}/${scope == 'public' ? 'public' : 'private'}/${await _hash(scope)}/${kind.name}/$key$extension',
        );
        if (generation != _generation) throw StateError('媒体保存已取消');
        if (await file.exists() && await file.length() > 0) return file;
        await file.parent.create(recursive: true);
        temp = File('${file.path}.part');
        await source.copy(temp.path);
        if (generation != _generation || await temp.length() == 0) {
          throw StateError('媒体保存未完成');
        }
        await temp.rename(file.path);
        if (!retainMedia) await _trim(root, kind, except: file.path);
        return file;
      } finally {
        if (temp != null && await temp.exists()) await temp.delete();
        _pending.remove(key);
      }
    });
    if (generation != _generation) throw StateError('媒体保存已取消');
    return result;
  }

  /// Local-only read; never fetches a URL or stores an authorization token.
  Future<File> cached({
    required String scope,
    required String contentKey,
    required MediaKind kind,
  }) async {
    final generation = _generation;
    final key = await _hash('$scope|${kind.name}|$contentKey');
    final root = await _directory();
    final extension = switch (kind) {
      MediaKind.image => '.media',
      MediaKind.audio => '.m4a',
      MediaKind.video => '.mp4',
    };
    final file = File(
      '${root.path}/${scope == 'public' ? 'public' : 'private'}/${await _hash(scope)}/${kind.name}/$key$extension',
    );
    if (!await file.exists() ||
        await file.length() == 0 ||
        generation != _generation) {
      throw StateError('媒体尚未保存在本机');
    }
    return file;
  }

  /// Forget one immutable media object after a decoder rejects it. Scope and
  /// content identity are hashed; callers cannot supply a filesystem path.
  Future<void> evict({
    required String scope,
    required String contentKey,
    required MediaKind kind,
  }) async {
    final generation = _generation;
    final key = await _hash('$scope|${kind.name}|$contentKey');
    try {
      await _pending[key];
    } catch (_) {}
    if (generation != _generation) return;
    final root = await _directory();
    final extension = switch (kind) {
      MediaKind.video => '.mp4',
      MediaKind.audio => '.m4a',
      MediaKind.image => '.media',
    };
    final file = File(
      '${root.path}/${scope == 'public' ? 'public' : 'private'}/${await _hash(scope)}/${kind.name}/$key$extension',
    );
    if (generation != _generation) return;
    if (await file.exists()) await file.delete();
  }

  /// Derivatives share image eviction and account cleanup with other media.
  /// The caller must have a current authorization before requesting a poster.
  Future<File> videoPoster(
    String url, {
    required String scope,
    required String contentKey,
    required Future<Uint8List?> Function(File) decode,
    Map<String, String>? headers,
  }) async {
    if (Uri.parse(url).scheme != 'https') {
      throw const FormatException('媒体地址必须使用HTTPS');
    }
    final generation = _generation;
    final key = await _hash('$scope|poster-v1|$contentKey');
    return _pending.putIfAbsent(key, () async {
      File? temp;
      try {
        final root = await _directory();
        final dir = Directory(
          '${root.path}/${scope == 'public' ? 'public' : 'private'}/${await _hash(scope)}/image',
        );
        if (generation != _generation) throw StateError('缓存请求已取消');
        await dir.create(recursive: true);
        final poster = File('${dir.path}/$key.media');
        if (await poster.exists() && await poster.length() > 0) {
          await poster.setLastModified(DateTime.now());
          if (generation != _generation) throw StateError('缓存请求已取消');
          return poster;
        }
        final source = await get(
          url,
          scope: scope,
          contentKey: contentKey,
          kind: MediaKind.video,
          headers: headers,
        );
        if (generation != _generation) throw StateError('缓存请求已取消');
        final bytes = await decode(source);
        if (generation != _generation) throw StateError('缓存请求已取消');
        if (bytes == null || bytes.isEmpty || bytes.length > 1024 * 1024) {
          throw StateError('无法生成视频预览');
        }
        temp = File('${poster.path}.part');
        await temp.writeAsBytes(bytes, flush: true);
        if (generation != _generation) throw StateError('缓存请求已取消');
        await temp.rename(poster.path);
        if (!retainMedia) {
          await _trim(root, MediaKind.image, except: poster.path);
        }
        return poster;
      } finally {
        _pending.remove(key);
        if (temp != null && await temp.exists()) await temp.delete();
      }
    });
  }

  Future<File> _load(
    String key,
    String url,
    String scope,
    MediaKind kind,
    Map<String, String>? headers,
    int generation,
  ) async {
    final root = await _directory();
    if (generation != _generation) throw StateError('Cache request cancelled');
    final dir = Directory(
      '${root.path}/${scope == 'public' ? 'public' : 'private'}/${await _hash(scope)}/${kind.name}',
    );
    if (generation != _generation) throw StateError('Cache request cancelled');
    await dir.create(recursive: true);
    if (generation != _generation) throw StateError('Cache request cancelled');
    final extension = switch (kind) {
      MediaKind.video => '.mp4',
      MediaKind.audio => '.m4a',
      MediaKind.image => '.media',
    };
    final file = File('${dir.path}/$key$extension');
    if (await file.exists() && await file.length() > 0) {
      await file.setLastModified(DateTime.now());
      if (generation != _generation) {
        throw StateError('Cache request cancelled');
      }
      return file;
    }
    final temp = File('${file.path}.part');
    final cancel = CancelToken();
    _downloads.add(cancel);
    final limit = kind == MediaKind.audio
        ? 2 * 1024 * 1024
        : kind == MediaKind.image
        ? 20 * 1024 * 1024
        : 200 * 1024 * 1024;
    try {
      await _dio.download(
        url,
        temp.path,
        cancelToken: cancel,
        options: Options(headers: headers, followRedirects: false),
        onReceiveProgress: (received, total) {
          if (received > limit || total > limit) cancel.cancel('媒体超出缓存单文件上限');
        },
      );
      if (generation != _generation ||
          !await temp.exists() ||
          await temp.length() == 0) {
        throw StateError('缓存请求已取消');
      }
      if (await temp.length() > limit) {
        throw StateError('媒体超出缓存单文件上限');
      }
      await temp.rename(file.path);
      if (!retainMedia) await _trim(root, kind, except: file.path);
      return file;
    } finally {
      _downloads.remove(cancel);
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<void> _trim(
    Directory root,
    MediaKind kind, {
    required String except,
  }) async {
    final files = await _files(root);
    final entries = <(File, FileStat)>[];
    var bytes = 0;
    for (final file in files.where(
      (f) => f.parent.path.endsWith(kind.name) && !f.path.endsWith('.part'),
    )) {
      final stat = await file.stat();
      bytes += stat.size;
      entries.add((file, stat));
    }
    entries.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    final budget = switch (kind) {
      MediaKind.image => imageBudget,
      MediaKind.video => videoBudget,
      MediaKind.audio => audioBudget,
    };
    for (final entry in entries) {
      if (bytes <= budget) break;
      if (entry.$1.path == except) continue;
      try {
        await entry.$1.delete();
        bytes -= entry.$2.size;
      } on FileSystemException {
        /* Concurrent eviction. */
      }
    }
  }

  Future<List<File>> _files(Directory root) async {
    if (!await root.exists()) return [];
    return root
        .list(recursive: true, followLinks: false)
        .where((f) => f is File)
        .cast<File>()
        .toList();
  }

  Future<int> sizeBytes() async {
    var total = 0;
    for (final file in await _files(await _directory())) {
      try {
        total += await file.length();
      } on FileSystemException {
        /* Evicted. */
      }
    }
    return total;
  }

  /// End work bound to an old session without deleting that account's media.
  Future<void> cancelPending() async {
    _generation++;
    for (final cancel in _downloads.toList()) {
      cancel.cancel('媒体请求已取消');
    }
    await Future.wait(
      _pending.values.toList().map((future) async {
        try {
          await future;
        } catch (_) {}
      }),
    );
  }

  Future<void> clear({bool privateOnly = false}) async {
    await cancelPending();
    final root = await _directory();
    final target = privateOnly ? Directory('${root.path}/private') : root;
    if (await target.exists()) await target.delete(recursive: true);
  }
}
