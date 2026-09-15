import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_frame.dart';

class _Bridge {
  _Bridge(DynamicLibrary library)
    : requestAddress = library
          .lookup<
            NativeFunction<Pointer<Utf8> Function(Pointer<Uint8>, UintPtr)>
          >('kingclub_novorudp_request')
          .address,
      releaseAddress = library
          .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>(
            'kingclub_novorudp_free',
          )
          .address,
      identity = library
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
  _Bridge.fromAddresses(this.requestAddress, this.releaseAddress)
    : identity = ((_, _) => throw StateError('Identity import unavailable')),
      request =
          Pointer<
                NativeFunction<Pointer<Utf8> Function(Pointer<Uint8>, UintPtr)>
              >.fromAddress(requestAddress)
              .asFunction<Pointer<Utf8> Function(Pointer<Uint8>, int)>(),
      release =
          Pointer<NativeFunction<Void Function(Pointer<Utf8>)>>.fromAddress(
            releaseAddress,
          ).asFunction<void Function(Pointer<Utf8>)>();
  final int requestAddress, releaseAddress;
  _NativePacketWorker? _worker;
  Future<Map<String, dynamic>> background(
    String op,
    int handle,
    Map<String, dynamic> fields,
  ) => (_worker ??= _NativePacketWorker(
    requestAddress,
    releaseAddress,
  )).call(op, handle, fields);
  void stopWorker() => _worker?.close();
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

class NovoRudpNatProbe {
  NovoRudpNatProbe._(this._owner, Map<String, dynamic> packet)
    : _encoded = jsonEncode(packet);
  final NovoRudpSecureSession _owner;
  final String _encoded;
  Map<String, dynamic> get packet =>
      jsonDecode(_encoded) as Map<String, dynamic>;
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
  final _senders = <NovoRudpRepairSender>{};

  NovoRudpRepairSender createRepairSender({
    required BigInt streamId,
    required BigInt objectId,
    required int fragments,
  }) {
    _owner._checkHandle(_owner, _handle);
    final result = _owner._bridge.call('sender', _handle, {
      'stream': streamId.toString(),
      'object': objectId.toString(),
      'expected': fragments,
    });
    final handle = result['handle'] as int;
    _owner._handles.add(handle);
    final sender = NovoRudpRepairSender._(this, handle);
    _senders.add(sender);
    return sender;
  }

  Future<Map<String, dynamic>> seal(NovoRudpFrame frame) async {
    _owner._checkHandle(_owner, _handle);
    final bytes = await frame.encode();
    _owner._checkHandle(_owner, _handle);
    final result = await _owner._bridge.background('seal', _handle, {
      'frame': bytes,
    });
    _owner._checkHandle(_owner, _handle);
    return result['envelope'] as Map<String, dynamic>;
  }

  Future<NovoRudpFrame> open(Map<String, dynamic> envelope) async {
    _owner._checkHandle(_owner, _handle);
    final result = await _owner._bridge.background('open', _handle, {
      'envelope': envelope,
    });
    _owner._checkHandle(_owner, _handle);
    final frame = await NovoRudpFrame.decode(
      Uint8List.fromList((result['frame'] as List).cast<int>()),
    );
    _owner._checkHandle(_owner, _handle);
    return frame;
  }

  void close() {
    for (final sender in _senders.toList()) {
      sender.close();
    }
    _owner._close(_handle);
  }
}

/// Upstream ACK-driven repair planning for one transfer. Only pass frames from
/// an authenticated secure lane; frame checksums are not authentication.
/// Returned plans are not delivery receipts or an implemented retry scheduler.
class NovoRudpRepairSender {
  NovoRudpRepairSender._(this._channel, this._handle);
  final NovoRudpSecureChannel _channel;
  final int _handle;
  Future<dynamic> acceptAuthenticatedAck(NovoRudpFrame frame) async {
    final owner = _channel._owner;
    owner._checkHandle(owner, _channel._handle);
    owner._checkHandle(owner, _handle);
    final bytes = await frame.encode();
    owner._checkHandle(owner, _channel._handle);
    owner._checkHandle(owner, _handle);
    final result = await owner._bridge.background('repairAck', _handle, {
      'frame': bytes,
    });
    owner._checkHandle(owner, _channel._handle);
    owner._checkHandle(owner, _handle);
    return result['decision'];
  }

  void close() {
    _channel._senders.remove(this);
    _channel._owner._close(_handle);
  }
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

  /// Only sign challenges received from our authenticated binding endpoint.
  /// The native method signs a fixed domain and includes this identity's key.
  Uint8List bindingProof({required Uint8List scope, required Uint8List nonce}) {
    _check();
    if (scope.length != 32 || nonce.length != 32) {
      throw ArgumentError('Invalid device binding challenge');
    }
    final result = _bridge.call('bindingProof', _identity, {
      'scope': scope,
      'nonce': nonce,
    });
    return Uint8List.fromList((result['signature'] as List).cast<int>())
        .asUnmodifiableView();
  }

  Map<String, dynamic> signBootstrapManifest(Map<String, dynamic> manifest) {
    _check();
    return _bridge.call('signBootstrap', _identity, {
          'manifest': manifest,
        })['manifest']
        as Map<String, dynamic>;
  }

  Map<String, dynamic> validateBootstrapManifest(
    Map<String, dynamic> manifest, {
    required Set<String> trustedSignerPeerIds,
    required int minimumSignatures,
  }) {
    _check();
    return _bridge.call('validateBootstrap', _identity, {
      'manifest': manifest,
      'trustedPeers': trustedSignerPeerIds.toList(),
      'minimum': minimumSignatures,
    });
  }

  /// Signs a short-lived advertisement only; does not start a relay or publish it.
  Map<String, dynamic> signRelayRecord({
    required String recordId,
    required int sequence,
    required List<Map<String, dynamic>> endpoints,
  }) {
    _check();
    return _bridge.call('relayRecord', _identity, {
          'recordId': recordId,
          'sequence': sequence,
          'endpoints': endpoints,
        })['record']
        as Map<String, dynamic>;
  }

  Map<String, dynamic> validateRelayRecord(
    Map<String, dynamic> record, {
    required String expectedPeer,
  }) {
    _check();
    return _bridge.call('validateRelay', _identity, {
          'record': record,
          'expectedPeer': expectedPeer,
        })['record']
        as Map<String, dynamic>;
  }

  NovoRudpNatProbe natProbe({String? targetPeer}) {
    _check();
    final value = _bridge.call('natProbe', _identity, {
      'targetPeer': targetPeer,
    });
    return NovoRudpNatProbe._(this, value['packet'] as Map<String, dynamic>);
  }

  Map<String, dynamic> respondNat(
    Map<String, dynamic> packet, {
    required String expectedPeer,
    required String observedEndpoint,
  }) {
    _check();
    return _bridge.call('natRespond', _identity, {
          'packet': packet,
          'expectedPeer': expectedPeer,
          'observedEndpoint': observedEndpoint,
        })['packet']
        as Map<String, dynamic>;
  }

  String validateNat(
    NovoRudpNatProbe probe,
    Map<String, dynamic> packet, {
    required String expectedPeer,
  }) {
    _check();
    if (!identical(probe._owner, this)) {
      throw StateError('Wrong NAT probe owner');
    }
    return _bridge.call('natValidate', _identity, {
          'request': probe.packet,
          'packet': packet,
          'expectedPeer': expectedPeer,
        })['endpoint']
        as String;
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
    _bridge.stopWorker();
    for (final handle in _handles.toList()) {
      try {
        _close(handle);
      } catch (_) {
        /* Fail closed; continue releasing other objects. */
      }
    }
  }
}

// One serialized native packet worker per login owner. Native handles remain
// process-local and are protected by the Rust bridge mutex. Only entry-point
// addresses and bounded protocol messages cross this same-process boundary.
class _NativePacketWorker {
  _NativePacketWorker(int request, int release) {
    _responses.listen((value) {
      if (value is SendPort) {
        _commands = value;
        if (_closed) value.send(null);
        if (!_ready.isCompleted) _ready.complete();
      } else if (value == null) {
        _finish();
      } else if (!_closed) {
        final response = value as List;
        final pending = _pending.remove(response[0]);
        if (response[1] == true) {
          pending?.complete(Map<String, dynamic>.from(response[2] as Map));
        } else {
          pending?.completeError(StateError(response[2] as String));
        }
      }
    });
    _errors.listen((_) => _finish());
    Isolate.spawn(
      _nativePacketMain,
      [_responses.sendPort, request, release],
      onExit: _responses.sendPort,
      onError: _errors.sendPort,
    ).then((_) {}, onError: (Object _) => _finish());
  }
  final _responses = ReceivePort(), _errors = ReceivePort();
  final _ready = Completer<void>();
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  SendPort? _commands;
  bool _closed = false;
  int _sequence = 0, _waiting = 0;

  Future<Map<String, dynamic>> call(
    String op,
    int handle,
    Map<String, dynamic> fields,
  ) async {
    if (_closed) throw StateError('Native packet worker closed');
    if (_waiting >= 64) throw StateError('Native packet queue full');
    _waiting++;
    try {
      await _ready.future;
      if (_closed) throw StateError('Native packet worker closed');
      final id = ++_sequence;
      final result = Completer<Map<String, dynamic>>();
      _pending[id] = result;
      _commands!.send([id, op, handle, fields]);
      return await result.future;
    } finally {
      _waiting--;
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final pending in _pending.values) {
      pending.completeError(StateError('Native packet worker closed'));
    }
    _pending.clear();
    // Graceful shutdown lets native allocations finish their finally cleanup.
    // A worker still starting receives this stop as soon as it announces ready.
    _commands?.send(null);
  }

  void _finish() {
    close();
    if (!_ready.isCompleted) _ready.complete();
    _responses.close();
    _errors.close();
  }
}

void _nativePacketMain(List<Object> startup) {
  final replies = startup[0] as SendPort;
  final bridge = _Bridge.fromAddresses(startup[1] as int, startup[2] as int);
  final commands = ReceivePort();
  replies.send(commands.sendPort);
  commands.listen((value) {
    if (value == null) {
      commands.close();
      return;
    }
    final request = value as List;
    try {
      final result = bridge.call(
        request[1] as String,
        request[2] as int,
        Map<String, dynamic>.from(request[3] as Map),
      );
      replies.send([request[0], true, result]);
    } catch (error) {
      replies.send([
        request[0],
        false,
        error is StateError ? error.message : 'Native packet operation failed',
      ]);
    }
  });
}
