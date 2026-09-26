import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

/// Android capture lifetime. Starting media is still authorized by the call owner.
class CallForegroundLease {
  CallForegroundLease({
    bool? supported,
    Future<void> Function(String, Map<String, dynamic>)? invoke,
  }) : _supported = supported ?? Platform.isAndroid,
       _invoke = invoke ?? _native;

  static const _channel = MethodChannel('kingclub/call-foreground');
  static Future<void> _native(String method, Map<String, dynamic> args) =>
      _channel.invokeMethod<void>(method, args);
  final bool _supported;
  final Future<void> Function(String, Map<String, dynamic>) _invoke;
  final String _id = const Uuid().v4();
  bool _closed = false, _requested = false;
  bool _started = false;
  bool get isActive => _supported && _started && !_closed;
  Future<void>? _starting;

  Future<void> start({required bool video}) {
    if (_closed) return Future.error(StateError('Call capture closed'));
    return _starting ??= _start(video);
  }

  Future<void> _start(bool video) async {
    if (!_supported) return;
    _requested = true;
    try {
      await _invoke('start', {'id': _id, 'video': video});
      if (_closed) throw StateError('Call capture closed');
      _started = true;
    } catch (_) {
      await _invoke('stop', {'id': _id});
      rethrow;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_supported && _requested) await _invoke('stop', {'id': _id});
  }
}
