import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';

/// Android NSD discovery. Never interprets a LAN advertisement as a friend or
/// trusted identity. A separate confirmed key exchange must precede chat.
class NearbyLanDiscovery {
  NearbyLanDiscovery._() {
    _platform.receiveBroadcastStream().listen(
      (value) {
        if (value is! Map) return;
        if (value['state'] == 'ready') {
          if (!_ready.isCompleted) _ready.complete();
          return;
        }
        if (value['id'] != _id || _id == null) return;
        if (_generation != MemberQrMemory.generation) {
          unawaited(stop());
          return;
        }
        final event = Map<String, dynamic>.from(value);
        if (event['state'] == 'found') {
          final host = event['host'], port = event['port'];
          if (host is! String ||
              InternetAddress.tryParse(host) == null ||
              port is! int ||
              port < 1 ||
              port > 65535) {
            return;
          }
        }
        _events.add(event);
        if (event['state'] == 'stopped') _id = null;
      },
      onError: (Object error, StackTrace stack) {
         _platformError = error;
      if (!_ready.isCompleted) _ready.complete();
        if (_id != null) _events.addError(error, stack);
        unawaited(stop());
      },
    );
    SecureSessionStore.changes.stream.listen((_) => unawaited(stop()));
  }
  static final instance = NearbyLanDiscovery._();
  static const _channel = MethodChannel('kingclub/nearby-lan');
  static const _platform = EventChannel('kingclub/nearby-lan-events');
  final _ready = Completer<void>();
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Object? _platformError;
  int _epoch = 0;
  String? _id;
  int _generation = 0;
  bool _starting = false;
  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> start({required int boundUdpPort}) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Android LAN discovery only');
    }
    if (boundUdpPort < 1 || boundUdpPort > 65535) {
      throw ArgumentError('Invalid bound UDP port');
    }
    if (_starting || _id != null) throw StateError('Discovery already running');
    _starting = true;
    final generation = MemberQrMemory.generation;
    final epoch = ++_epoch;
    final id = const Uuid().v4().replaceAll('-', '');
    try {
      await _ready.future.timeout(const Duration(seconds: 3));
      if (_platformError != null) throw StateError('Discovery platform unavailable');
      if (epoch != _epoch) throw StateError('Discovery cancelled');
      if (generation != MemberQrMemory.generation) {
        throw StateError('Session changed');
      }
      _generation = generation;
      _id = id;
      await _channel.invokeMethod<void>('start', {
        'id': id,
        'port': boundUdpPort,
      });
      if (_id != id || generation != MemberQrMemory.generation) {
        throw StateError('Discovery cancelled');
      }
    } catch (_) {
      if (_id == id) await stop();
      rethrow;
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    _epoch++;
    final id = _id;
    _id = null;
    if (id == null) return;
    try {
      await _channel.invokeMethod<void>('stop', {'id': id});
    } on PlatformException {
      /* Native activity lifecycle also stops discovery. */
    }
  }
}
