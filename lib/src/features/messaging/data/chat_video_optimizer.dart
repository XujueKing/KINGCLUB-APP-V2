import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cryptography/dart.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'chat_video_canonical_source.dart';

/// Produces a private upload copy. Original bytes remain the retry source.
class ChatVideoOptimizer {
  ChatVideoOptimizer({
    required this.account,
    bool? supported,
    Future<String?> Function(String, Map<String, dynamic>)? invoke,
  }) : _supported = supported ?? Platform.isAndroid,
       _invoke = invoke ?? _call;
  static const _channel = MethodChannel('kingclub/chat-video-upload');
  static Future<String?> _call(String method, Map<String, dynamic> args) =>
      _channel.invokeMethod<String>(method, args);
  final String account;
  final bool _supported;
  final Future<String?> Function(String, Map<String, dynamic>) _invoke;
  final _id = const Uuid().v4();
  String? _key;
  File? _prepared;
  bool _disposed = false;
  Timer? _progressTimer;
  final _canonical = ChatVideoCanonicalSource();

  Future<File> prepare(File source, {void Function(double)? onProgress}) async {
    final optimized = await _optimize(source, onProgress: onProgress);
    final result = await _canonical.prepare(optimized);
    _check();
    return result;
  }

  Future<File> _optimize(
    File source, {
    void Function(double)? onProgress,
  }) async {
    _check();
    if (!_supported) return source;
    final sourceLength = await source.length();
    _check();
    if (sourceLength < 4 * 1024 * 1024) {
      _prepared = null;
      _key = null;
      return source;
    }
    // Revalidate actual content, even when a file's path and size are unchanged.
    final sourceKey = await _hashInBackground(source.path, account);
    _check();
    if (sourceKey != _key) _prepared = null;
    _key = sourceKey;
    final prepared = _prepared;
    if (prepared != null) {
      var available = false;
      try {
        available = await prepared.length() > 0;
      } on FileSystemException {
        // Temporary upload copies may be evicted while a failed send waits.
      }
      _check();
      if (available) return prepared;
      _prepared = null;
    }
    String? path;
    var observing = true, polling = false;
    var lastProgress = -1;
    if (onProgress != null) {
      _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (
        _,
      ) async {
        if (!observing || _disposed || polling) return;
        polling = true;
        try {
          final value = int.tryParse(
            await _invoke('progress', {'id': _id}) ?? '',
          );
          if (observing &&
              !_disposed &&
              value != null &&
              value >= 0 &&
              value <= 100 &&
              value > lastProgress) {
            lastProgress = value;
            onProgress(value / 100);
          }
        } catch (_) {
          // A missing progress estimate must not interrupt the actual export.
        } finally {
          polling = false;
        }
      });
    }
    try {
      path = await _invoke('prepare', {
        'id': _id,
        'key': _key,
        'path': source.path,
      });
    } on MissingPluginException {
      // Platforms without the bridge keep the existing server processing flow.
    } on PlatformException {
      // Unsupported device encoders must not prevent sending the original.
    } finally {
      observing = false;
      _progressTimer?.cancel();
      _progressTimer = null;
    }
    _check();
    final candidate = path == null ? source : File(path);
    if (path != null &&
        (!await candidate.exists() ||
            await candidate.length() <= 0 ||
            await candidate.length() >= await source.length())) {
      return source;
    }
    _prepared = candidate;
    return candidate;
  }

  Future<void> acknowledgeQueued() async {
    await _canonical.close();
    if (_key != null) {
      try {
        await _invoke('release', {'key': _key});
      } catch (_) {}
    }
  }

  void _check() {
    if (_disposed) throw StateError('视频处理已取消');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _progressTimer?.cancel();
    _progressTimer = null;
    unawaited(_canonical.close().catchError((Object _) {}));
    if (_supported) _invoke('cancel', {'id': _id}).catchError((_) => null);
  }
}

Future<String> _hashInBackground(String path, String account) =>
    Isolate.run(() async {
      final sink = const DartSha256().newHashSink();
      sink.add(utf8.encode('video-upload-hardware-v4:$account\u0000'));
      try {
        await for (final bytes in File(path).openRead()) {
          sink.add(bytes);
        }
      } finally {
        sink.close();
      }
      return (await sink.hash()).bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
    });
