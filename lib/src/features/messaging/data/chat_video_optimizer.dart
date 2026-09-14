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

  Future<File> prepare(File source) async {
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
    if (_supported) _invoke('cancel', {'id': _id}).catchError((_) => null);
  }
}
