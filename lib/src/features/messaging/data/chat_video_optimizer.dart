import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

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

  Future<File> prepare(File source, {void Function(double)? onProgress}) async {
    _check();
    if (_prepared != null) return _prepared!;
    if (!_supported || await source.length() < 4 * 1024 * 1024) return source;
    final sink = const DartSha256().newHashSink();
    sink.add(utf8.encode('$account\u0000'));
    try {
      await for (final bytes in source.openRead()) {
        _check();
        sink.add(bytes);
      }
    } finally {
      sink.close();
    }
    _key = (await sink.hash()).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    _check();
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
    _disposed = true;
    _progressTimer?.cancel();
    _progressTimer = null;
    if (_supported) _invoke('cancel', {'id': _id}).catchError((_) => null);
  }
}
