import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/session/secure_session_store.dart';
import 'novorudp_file_receiver.dart';
import 'novorudp_frame.dart';
import 'novorudp_frame_link.dart';

/// Receives one independently authorized manifest over a shared secure lane.
/// The verified file remains owned here until close; copy it before closing.
class NovoRudpFileDownload {
  static Future<NovoRudpFileDownload> open({
    required NovoRudpFrameLink link,
    required Directory privateDirectory,
    required BigInt streamId,
    required BigInt objectId,
    required int size,
    required String sha256,
    required bool Function() canReceive,
    Duration deadline = const Duration(minutes: 5),
    Duration idleTimeout = const Duration(seconds: 8),
  }) async {
    if (deadline <= Duration.zero) throw ArgumentError('Invalid deadline');
    if (idleTimeout <= Duration.zero) {
      throw ArgumentError('Invalid idle timeout');
    }
    if (!canReceive()) throw StateError('File access unavailable');
    final receiver = await NovoRudpFileReceiver.create(
      privateDirectory: privateDirectory,
      sessionId: link.channel.sessionId,
      streamId: streamId,
      objectId: objectId,
      size: size,
      sha256: sha256,
    );
    try {
      if (!canReceive()) throw StateError('File access unavailable');
      return NovoRudpFileDownload._(
        link,
        receiver,
        streamId,
        objectId,
        canReceive,
        deadline,
        idleTimeout,
      );
    } catch (_) {
      await receiver.close();
      rethrow;
    }
  }

  NovoRudpFileDownload._(
    this._link,
    this._receiver,
    this._streamId,
    this._objectId,
    this._canReceive,
    Duration deadline,
    this._idleTimeout,
  ) {
    if (_link is NovoRudpRouteObservations) {
      _routeSubscription = (_link as NovoRudpRouteObservations).receivedRoutes
          .listen((event) {
            if (_closed ||
                event.streamId != _streamId ||
                event.objectId != _objectId ||
                (event.kind != NovoRudpFrameKind.data &&
                    event.kind != NovoRudpFrameKind.repair)) {
              return;
            }
            if (event.direct) {
              _udpFrames++;
              _udpBytes += event.bytes;
            } else {
              _relayFrames++;
              _relayBytes += event.bytes;
            }
          });
    }
    _subscription = _link.frames.listen(
      (frame) {
        if (_closed ||
            frame.streamId != _streamId ||
            frame.objectId != _objectId ||
            ![
              NovoRudpFrameKind.data,
              NovoRudpFrameKind.repair,
              NovoRudpFrameKind.done,
            ].contains(frame.kind)) {
          return;
        }
        // Drop overload instead of retaining an unbounded queue of payloads.
        // Sender ACK requests repair dropped data and retry dropped requests.
        if (_queued >= NovoRudpFileReceiver.maxQueuedFragments) return;
        _queued++;
        unawaited(_receive(frame).whenComplete(() => _queued--));
      },
      onError: (Object error) => _fail(error),
      onDone: () => _fail(StateError('File lane closed')),
    );
    _session = SecureSessionStore.changes.stream.listen(
      (_) => _fail(StateError('File session changed')),
    );
    _timer = Timer(
      deadline,
      () => _fail(TimeoutException('File receive deadline')),
    );
    _armIdle();
    // Failure may arrive before the consumer starts awaiting completion.
    unawaited(_done.future.then<void>((_) {}, onError: (Object _) {}));
  }

  final NovoRudpFrameLink _link;
  final NovoRudpFileReceiver _receiver;
  final BigInt _streamId, _objectId;
  final bool Function() _canReceive;
  final _done = Completer<File>();
  StreamSubscription<NovoRudpReceivedRoute>? _routeSubscription;
  int _udpFrames = 0, _udpBytes = 0, _relayFrames = 0, _relayBytes = 0;
  ({int udpFrames, int udpBytes, int relayFrames, int relayBytes})
  get receivedRouteStats => (
    udpFrames: _udpFrames,
    udpBytes: _udpBytes,
    relayFrames: _relayFrames,
    relayBytes: _relayBytes,
  );
  late final StreamSubscription<NovoRudpFrame> _subscription;
  late final StreamSubscription<void> _session;
  late final Timer _timer;
  final Duration _idleTimeout;
  Timer? _idleTimer;
  int _progress = 0;
  Future<void>? _closing;
  bool _closed = false;
  bool _sendingAck = false;
  int _queued = 0;
  Future<void> Function(int, Uint8List)? _resumeWriter;
  bool Function()? _canPreserve;

  /// The owner supplies its message-scoped encrypted cache, never a public path.
  /// Cached blocks do not imply file verification or receiver completion.
  /// A separate preservation check can survive user cancellation; the writer
  /// must still validate account ownership and deletion before every write.
  void preserveBlocksOnClose(
    Future<void> Function(int, Uint8List) write, {
    bool Function()? canPreserve,
  }) {
    _check();
    _resumeWriter = write;
    _canPreserve = canPreserve;
  }

  Future<void> restoreBlocks(Future<Uint8List?> Function(int, int) read) async {
    _check();
    await _receiver.restoreBlocks(1024 * 1024, (index, length) async {
      _check();
      final bytes = await read(index, length);
      _check();
      return bytes;
    });
    _check();
    _progress = _receiver.receivedFragments;
    _armIdle();
  }

  Future<File> get completed => _done.future;
  int get receivedBytes => _receiver.receivedBytes;

  void _armIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(
      _idleTimeout,
      () => _fail(TimeoutException('File receive stalled')),
    );
  }

  void _check() {
    if (_closed || !_canReceive()) throw StateError('File access unavailable');
  }

  Future<void> _receive(NovoRudpFrame frame) async {
    try {
      _check();
      final ack = await _receiver.receiveAuthenticated(frame);
      _check();
      if (!_done.isCompleted && _receiver.receivedFragments > _progress) {
        _progress = _receiver.receivedFragments;
        _armIdle();
      }
      if (ack == null) return;
      // A verified file is useful only after the current permission recheck.
      File? file;
      try {
        file = await _receiver.verifiedFile();
      } on StateError {
        // Normal partial receipt: send missing ranges, not completion.
      }
      _check();
      // Local verified data must not wait for a blocked outgoing transport.
      // Keep just one ACK in flight on this shared lane.
      if (!_sendingAck) unawaited(_sendAck(ack));
      _check();
      if (file != null && !_done.isCompleted) {
        _timer.cancel();
        _idleTimer?.cancel();
        _done.complete(file);
      }
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _sendAck(NovoRudpFrame ack) async {
    _sendingAck = true;
    try {
      _check();
      await _link.send(ack);
    } on SocketException {
      // A dropped local ACK is retried by the sender's next DONE request.
    } catch (error) {
      if (!_closed) _fail(error);
    } finally {
      _sendingAck = false;
    }
  }

  void _fail(Object error) {
    if (!_done.isCompleted) _done.completeError(error);
    unawaited(close());
  }

  Future<void> close() {
    _closed = true;
    if (!_done.isCompleted) {
      _done.completeError(StateError('File receive closed'));
    }
    return _closing ??= _close();
  }

  Future<void> _close() async {
    _timer.cancel();
    _idleTimer?.cancel();
    // Enqueue the snapshot before the owner invalidates the peer attempt.
    // The writer independently checks session/deletion on each block.
    final writer = _resumeWriter;
    final checkpoint = writer != null && (_canPreserve ?? _canReceive)()
        ? _receiver
              .checkpointBlocks(1024 * 1024, writer)
              .catchError((Object _) {})
        : Future<void>.value();
    await _subscription.cancel();
    await _routeSubscription?.cancel();
    if (!kReleaseMode && _routeSubscription != null) {
      debugPrint(
        'PeerReceive routes udpFrames=$_udpFrames udpBytes=$_udpBytes relayFrames=$_relayFrames relayBytes=$_relayBytes',
      );
    }
    await _session.cancel();
    await checkpoint;
    await _receiver.close();
  }
}
