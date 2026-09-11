import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

enum MediaKind { image, video }

/// Persistent, bounded media cache. URLs (including signed query strings) are
/// never written to disk. Private media must use an account-specific scope.
class MediaCache {
  MediaCache({
    Future<Directory> Function()? directory,
    Dio? dio,
    this.imageBudget = 200 * 1024 * 1024,
    this.videoBudget = 800 * 1024 * 1024,
  }) : _directory =
           directory ??
           (() async => Directory(
             '${(await getApplicationCacheDirectory()).path}/media-cache-v1',
           )),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 60),
             ),
           );
  static final shared = MediaCache();
  final Future<Directory> Function() _directory;
  final Dio _dio;
  final int imageBudget, videoBudget;
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
    final uri = Uri.parse(url);
    if (uri.scheme != 'https') throw const FormatException('媒体地址必须使用HTTPS');
    final key = await _hash('$scope|${kind.name}|${contentKey ?? url}');
    return _pending.putIfAbsent(key, () async {
      try {
        return await _load(key, url, scope, kind, headers);
      } finally {
        _pending.remove(key);
      }
    });
  }

  Future<File> _load(
    String key,
    String url,
    String scope,
    MediaKind kind,
    Map<String, String>? headers,
  ) async {
    final generation = _generation;
    final root = await _directory();
    final dir = Directory(
      '${root.path}/${scope == 'public' ? 'public' : 'private'}/${await _hash(scope)}/${kind.name}',
    );
    await dir.create(recursive: true);
    final extension = kind == MediaKind.video ? '.mp4' : '.media';
    final file = File('${dir.path}/$key$extension');
    if (await file.exists() && await file.length() > 0) {
      await file.setLastModified(DateTime.now());
      return file;
    }
    final temp = File('${file.path}.part');
    final cancel = CancelToken();
    _downloads.add(cancel);
    final limit = kind == MediaKind.image
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
      await temp.rename(file.path);
      await _trim(root, kind, except: file.path);
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
    final budget = kind == MediaKind.image ? imageBudget : videoBudget;
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

  Future<void> clear({bool privateOnly = false}) async {
    _generation++;
    for (final cancel in _downloads.toList()) {
      cancel.cancel('清理缓存');
    }
    await Future.wait(
      _pending.values.toList().map((future) async {
        try {
          await future;
        } catch (_) {}
      }),
    );
    final root = await _directory();
    final target = privateOnly ? Directory('${root.path}/private') : root;
    if (await target.exists()) await target.delete(recursive: true);
  }
}
