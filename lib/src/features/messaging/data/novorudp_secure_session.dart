import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_frame.dart';

class _Bridge {
  _Bridge(DynamicLibrary library)
    : identity = library
          .lookupFunction<
            Uint64 Function(Pointer<Uint8>, UintPtr),
            int Function(Pointer<Uint8>, int)
          >('kingclub_novorudp_identity'),
      request = library
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Uint8>, UintPtr),
            Pointer<Utf8> Function(Pointer<Uint8>, int)
          >('kingclub_novorudp_request'),
      release = library
          .lookupFunction<
            Void Function(Pointer<Utf8>),
            void Function(Pointer<Utf8>)
          >('kingclub_novorudp_free');
  final int Function(Pointer<Uint8>, int) identity;
  final Pointer<Utf8> Function(Pointer<Uint8>, int) request;
  final void Function(Pointer<Utf8>) release;
  int importSeed(Uint8List seed) {
    if (seed.length != 32) {
      throw ArgumentError('Expected 32-byte identity seed');
    }
    final buffer = calloc<Uint8>(32);
    try {
      buffer.asTypedList(32).setAll(0, seed);
      final handle = identity(buffer, 32);
      if (handle == 0) throw StateError('Native identity unavailable');
      return handle;
    } finally {
      buffer.asTypedList(32).fillRange(0, 32, 0);
      calloc.free(buffer);
    }
  }

  Map<String, dynamic> call(
    String op,
    int handle, [
    Map<String, dynamic> fields = const {},
  ]) {
    final bytes = utf8.encode(
      jsonEncode({...fields, 'op': op, 'handle': handle}),
    );
    if (bytes.length > 16384) throw ArgumentError('Native request too large');
    final input = calloc<Uint8>(bytes.length);
    Pointer<Utf8> output = nullptr;
    try {
      input.asTypedList(bytes.length).setAll(0, bytes);
      output = request(input, bytes.length);
      if (output == nullptr) throw StateError('Native result unavailable');
      final value = jsonDecode(output.toDartString()) as Map<String, dynamic>;
      if (value['ok'] != true) {
        throw StateError(
          value['error'] as String? ?? 'Native operation failed',
        );
      }
      return value['data'] as Map<String, dynamic>;
    } finally {
      if (output != nullptr) release(output);
      input.asTypedList(bytes.length).fillRange(0, bytes.length, 0);
      calloc.free(input);
    }
  }
}

class NovoRudpHandshake {
  NovoRudpHandshake._(this._owner, this._handle, this.offer);
  final NovoRudpSecureSession _owner;
  final int _handle;
  final Map<String, dynamic> offer;
}

class NovoRudpSecureChannel {
  NovoRudpSecureChannel._(this._owner, this._handle, List<int> session)
    : sessionId = Uint8List.fromList(session).asUnmodifiableView();
  final NovoRudpSecureSession _owner;
  final int _handle;
  final Uint8List sessionId;
  Future<Map<String, dynamic>> seal(NovoRudpFrame frame) async {
    _owner._checkHandle(_owner, _handle);
    final bytes = await frame.encode();
    _owner._checkHandle(_owner, _handle);
    return _owner._bridge.call('seal', _handle, {'frame': bytes})['envelope']
        as Map<String, dynamic>;
  }

  Future<NovoRudpFrame> open(Map<String, dynamic> envelope) async {
    _owner._checkHandle(_owner, _handle);
    final result = _owner._bridge.call('open', _handle, {'envelope': envelope});
    final frame = await NovoRudpFrame.decode(
      Uint8List.fromList((result['frame'] as List).cast<int>()),
    );
    _owner._checkHandle(_owner, _handle);
    return frame;
  }

  void close() => _owner._close(_handle);
}

/// Owns all native identities and channels for one login generation.
/// This does not establish the trust binding between a member and expectedPeer.
class NovoRudpSecureSession {
  factory NovoRudpSecureSession.fromSeed({
    required DynamicLibrary library,
    required Uint8List seed,
  }) {
    final bridge = _Bridge(library);
    return NovoRudpSecureSession._(bridge, bridge.importSeed(seed));
  }
  NovoRudpSecureSession._(this._bridge, this._identity) {
    _handles.add(_identity);
    _changes = SecureSessionStore.changes.stream.listen((_) => dispose());
  }
  final _Bridge _bridge;
  final int _identity;
  final int _generation = MemberQrMemory.generation;
  final _handles = <int>{};
  late final StreamSubscription<void> _changes;
  bool _disposed = false;
  void _check() {
    if (_disposed || _generation != MemberQrMemory.generation) {
      dispose();
      throw StateError('Secure session has ended');
    }
  }

  void _checkHandle(NovoRudpSecureSession owner, int handle) {
    _check();
    if (!identical(owner, this) || !_handles.contains(handle)) {
      throw StateError('Native object unavailable');
    }
  }

  String get peerId {
    _check();
    return _bridge.call('public', _identity)['peerId'] as String;
  }

  NovoRudpHandshake start(String expectedPeer) {
    _check();
    final value = _bridge.call('start', _identity, {
      'expectedPeer': expectedPeer,
    });
    final handle = value['handle'] as int;
    _handles.add(handle);
    return NovoRudpHandshake._(
      this,
      handle,
      value['offer'] as Map<String, dynamic>,
    );
  }

  ({NovoRudpSecureChannel channel, Map<String, dynamic> response}) respond(
    Map<String, dynamic> offer, {
    required String expectedPeer,
  }) {
    _check();
    final value = _bridge.call('respond', _identity, {
      'offer': offer,
      'expectedPeer': expectedPeer,
    });
    final handle = value['handle'] as int;
    _handles.add(handle);
    final response = value['response'] as Map<String, dynamic>;
    return (
      channel: NovoRudpSecureChannel._(
        this,
        handle,
        (response['session_id'] as List).cast<int>(),
      ),
      response: response,
    );
  }

  NovoRudpSecureChannel complete(
    NovoRudpHandshake handshake,
    Map<String, dynamic> response,
  ) {
    _checkHandle(handshake._owner, handshake._handle);
    try {
      final value = _bridge.call('complete', handshake._handle, {
        'response': response,
      });
      final handle = value['handle'] as int;
      _handles.add(handle);
      return NovoRudpSecureChannel._(
        this,
        handle,
        (value['sessionId'] as List).cast<int>(),
      );
    } finally {
      _close(handshake._handle);
    }
  }

  void cancel(NovoRudpHandshake handshake) {
    _checkHandle(handshake._owner, handshake._handle);
    _close(handshake._handle);
  }

  void _close(int handle) {
    if (_handles.remove(handle)) _bridge.call('close', handle);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_changes.cancel());
    for (final handle in _handles.toList()) {
      try {
        _close(handle);
      } catch (_) {
        /* Fail closed; continue releasing other objects. */
      }
    }
  }
}
