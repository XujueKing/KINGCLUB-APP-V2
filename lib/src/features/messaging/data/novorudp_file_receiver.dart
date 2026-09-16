import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/dart.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_frame.dart';
import 'novorudp_secure_packet.dart';

/// Temporary, disk-backed receiver for an authenticated transfer manifest.
/// Caller supplies its private directory and a trusted size/digest. Feed only
/// authenticated frames. Copy the verified file into the media store before
/// close: all temporary files remain owned here and are deleted on close/logout.
class NovoRudpFileReceiver {
  static const chunkSize = NovoRudpSecurePacket.maxFramePayload;
  static const maxQueuedFragments = 256;
  static const maxBytes = chunkSize * 1000000;
  static Future<NovoRudpFileReceiver> create({
    required Directory privateDirectory,
    required List<int> sessionId,
    required BigInt streamId,
    required BigInt objectId,
    required int size,
    required String sha256,
  }) async {
    if (size < 0 ||
        size > maxBytes ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw ArgumentError('Invalid transfer manifest');
    }
    // Reuse the frame's unsigned ID/session validation before creating files.
    final scope = NovoRudpFrame(
      kind: NovoRudpFrameKind.data,
      sessionId: sessionId,
      streamId: streamId,
      objectId: objectId,
      sequence: BigInt.zero,
      ackEpoch: BigInt.zero,
      payload: const [],
    );
    final generation = MemberQrMemory.generation;
    final directory = await privateDirectory.createTemp('novorudp-');
    RandomAccessFile? output;
    try {
      final file = File(
        '${directory.path}${Platform.pathSeparator}receiving.part',
      );
      output = await file.open(mode: FileMode.write);
      if (generation != MemberQrMemory.generation) {
        throw StateError('Transfer session ended');
      }
      return NovoRudpFileReceiver._(
        directory,
        file,
        output,
        scope,
        size,
        sha256,
        generation,
      );
    } catch (_) {
      await output?.close();
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  NovoRudpFileReceiver._(
    this._directory,
    this._file,
    this._output,
    this._scope,
    this.size,
    this.sha256,
    this._generation,
  ) : fragments = math.max(1, (size + chunkSize - 1) ~/ chunkSize),
      _received = Uint8List(math.max(1, (size + chunkSize - 1) ~/ chunkSize)) {
    _session = SecureSessionStore.changes.stream.listen(
      (_) => unawaited(close()),
    );
  }
  final Directory _directory;
  final File _file;
  final RandomAccessFile _output;
  final NovoRudpFrame _scope;
  final int size, fragments, _generation;
  final String sha256;
  final Uint8List _received;
  late final StreamSubscription<void> _session;
  Future<void> _tail = Future<void>.value();
  Future<void>? _closing;
  bool _closed = false, _verified = false, _failed = false;
  int _count = 0, _epoch = 0, _queuedFragments = 0;

  /// Unique fragments written to disk; duplicates and ACK polls are not progress.
  int get receivedFragments => _count;

  void _check() {
    if (_closed || _failed || _generation != MemberQrMemory.generation) {
      throw StateError('Transfer unavailable');
    }
  }

  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Overload is packet loss, not receipt: dropped fragments remain missing in
  /// authenticated ACKs and are repaired by the sender. Bound queued payloads
  /// before retaining them in the serialized disk-write closure.
  Future<void> acceptAuthenticated(NovoRudpFrame frame) async {
    _check();
    if (frame.payload.length > chunkSize) {
      throw const FormatException('Fragment exceeds receiver budget');
    }
    if (_queuedFragments >= maxQueuedFragments) return;
    _queuedFragments++;
    try {
      await _accept(frame);
    } finally {
      _queuedFragments--;
    }
  }

  Future<void> _accept(NovoRudpFrame frame) => _serial(() async {
    _check();
    if ((frame.kind != NovoRudpFrameKind.data &&
            frame.kind != NovoRudpFrameKind.repair) ||
        frame.streamId != _scope.streamId ||
        frame.objectId != _scope.objectId ||
        !List.generate(
          16,
          (i) => frame.sessionId[i] == _scope.sessionId[i],
        ).every((v) => v) ||
        frame.sequence >= BigInt.from(fragments)) {
      throw const FormatException('Different file transfer');
    }
    final index = frame.sequence.toInt();
    final expected = math.min(chunkSize, size - index * chunkSize);
    if (frame.payload.length != expected) {
      throw const FormatException('Wrong fragment length');
    }
    if (_received[index] != 0) return;
    await _output.setPosition(index * chunkSize);
    _check();
    await _output.writeFrom(frame.payload);
    _check();
    _received[index] = 1;
    _count++;
    if (_count == fragments) {
      await _output.flush();
      _check();
      final sink = const DartSha256().newHashSink();
      try {
        await for (final bytes in _file.openRead()) {
          _check();
          sink.add(bytes);
        }
      } finally {
        sink.close();
      }
      final actual = (await sink.hash()).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      _check();
      if (actual != sha256 || await _file.length() != size) {
        _failed = true;
        throw const FormatException('Received file digest mismatch');
      }
      _check();
      _verified = true;
    }
  });

  Future<File> verifiedFile() => _serial(() async {
    _check();
    if (!_verified) throw StateError('File is incomplete');
    return _file;
  });

  /// The sender uses an empty DONE frame as a request for current ACK state,
  /// including after a lost final ACK. It is not permission to finalize a file.
  Future<NovoRudpFrame?> receiveAuthenticated(NovoRudpFrame frame) async {
    if (frame.kind != NovoRudpFrameKind.done) {
      await acceptAuthenticated(frame);
      return null;
    }
    _check();
    if (frame.streamId != _scope.streamId ||
        frame.objectId != _scope.objectId ||
        frame.payload.isNotEmpty ||
        frame.sequence != BigInt.zero ||
        !List.generate(
          16,
          (i) => frame.sessionId[i] == _scope.sessionId[i],
        ).every((v) => v)) {
      throw const FormatException('Invalid transfer ACK request');
    }
    return acknowledgement();
  }

  Future<NovoRudpFrame> acknowledgement() => _serial(() async {
    _check();
    final first = _received.indexOf(0);
    var end = first < 0 ? -1 : math.min(fragments - 1, first + 63);
    final epoch = ++_epoch;
    List<int> payload;
    do {
      final ranges = <Map<String, int>>[];
      for (var i = first; i >= 0 && i <= end; i++) {
        if (_received[i] != 0) continue;
        final start = i;
        while (i < end && _received[i + 1] == 0) {
          i++;
        }
        ranges.add({'start': start, 'end_inclusive': i});
      }
      payload = utf8.encode(
        jsonEncode({
          'header': {
            'version': 1,
            'kind': 'Ack',
            'session_id': _scope.sessionId,
            'epoch': epoch,
            'sequence': null,
            'window_id': first < 0 ? null : first ~/ 64,
          },
          'expected_total': fragments,
          'receiver_done': _verified,
          'missing_count': fragments - _count,
          'current_window': first < 0
              ? null
              : {'start': first, 'end_inclusive': end},
          'current_window_missing_ranges': ranges,
        }),
      );
      if (payload.length <= chunkSize) break;
      end--;
      if (end < first) throw StateError('ACK exceeds datagram budget');
    } while (true);
    return NovoRudpFrame(
      kind: NovoRudpFrameKind.ack,
      sessionId: _scope.sessionId,
      streamId: _scope.streamId,
      objectId: _scope.objectId,
      sequence: BigInt.zero,
      ackEpoch: BigInt.from(epoch),
      payload: payload,
    );
  });

  Future<void> close() {
    _closed = true;
    return _closing ??= _serial(() async {
      await _session.cancel();
      try {
        await _output.close();
      } finally {
        await _directory.delete(recursive: true);
      }
    });
  }
}
