import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cryptography/dart.dart';

import '../../../core/session/member_qr_memory.dart';
import 'novorudp_file_receiver.dart';
import 'novorudp_frame.dart';
import 'novorudp_frame_link.dart';

/// One authenticated file transfer. Completion means the receiver verified its
/// temporary file, not that a chat message was durably accepted by the service.
class NovoRudpFileSender {
  NovoRudpFileSender({
    required this.link,
    required this.file,
    required this.streamId,
    required this.objectId,
    required this.size,
    required this.sha256,
    this.ackWait = const Duration(seconds: 1),
    this.maxStalls = 8,
    this.deadline = const Duration(minutes: 5),
  }) {
    if (size < 0 ||
        size > NovoRudpFileReceiver.maxBytes ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) ||
        ackWait <= Duration.zero ||
        deadline <= Duration.zero ||
        maxStalls < 1) {
      throw ArgumentError('Invalid file sender configuration');
    }
  }
  final NovoRudpFrameLink link;
  final File file;
  final BigInt streamId, objectId;
  final int size, maxStalls;
  final String sha256;
  final Duration ackWait, deadline;
  final _clock = Stopwatch();
  final int _generation = MemberQrMemory.generation;
  bool _started = false, _cancelled = false;
  Object? _failure;
  NovoRudpFrame? _latest;
  Completer<void>? _wake;

  void cancel() {
    _cancelled = true;
    _signal();
  }

  void _signal() {
    if (_wake?.isCompleted == false) _wake!.complete();
  }

  void _check() {
    if (_cancelled || _generation != MemberQrMemory.generation) {
      throw StateError('File transfer cancelled');
    }
    if (_failure != null) throw StateError('Secure lane ended: $_failure');
    if (_clock.elapsed >= deadline) {
      throw TimeoutException('File transfer deadline');
    }
  }

  NovoRudpFrame _frame(
    NovoRudpFrameKind kind,
    int sequence,
    List<int> payload,
  ) => NovoRudpFrame(
    kind: kind,
    sessionId: link.channel.sessionId,
    streamId: streamId,
    objectId: objectId,
    sequence: BigInt.from(sequence),
    ackEpoch: BigInt.zero,
    payload: payload,
  );

  Future<void> _send(NovoRudpFrame frame) async {
    // Retry only a locally unaccepted send. Each attempt is freshly sealed, so
    // retransmission never reuses an AEAD nonce or relies on replay acceptance.
    for (var attempt = 0; ; attempt++) {
      _check();
      try {
        await link.send(frame);
        return;
      } on SocketException {
        if (attempt >= maxStalls) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  Future<NovoRudpFrame?> _nextAck() async {
    _check();
    if (_latest == null) {
      _wake = Completer<void>();
      final remaining = deadline - _clock.elapsed;
      try {
        await _wake!.future.timeout(remaining < ackWait ? remaining : ackWait);
      } on TimeoutException {
        /* The bounded retry loop requests another ACK. */
      } finally {
        _wake = null;
      }
    }
    _check();
    final value = _latest;
    _latest = null;
    return value;
  }

  Future<void> run() async {
    if (_started) throw StateError('File sender is single-use');
    _started = true;
    _clock.start();
    _check();
    final fragments = math.max(
      1,
      (size + NovoRudpFileReceiver.chunkSize - 1) ~/
          NovoRudpFileReceiver.chunkSize,
    );
    final planner = link.channel.createRepairSender(
      streamId: streamId,
      objectId: objectId,
      fragments: fragments,
    );
    RandomAccessFile? source;
    final subscription = link.frames.listen(
      (frame) {
        if (frame.kind == NovoRudpFrameKind.ack &&
            frame.streamId == streamId &&
            frame.objectId == objectId &&
            (_latest == null || frame.ackEpoch > _latest!.ackEpoch)) {
          _latest = frame;
          _signal();
        }
      },
      onError: (Object error) {
        _failure = error;
        _signal();
      },
      onDone: () {
        _failure = StateError('Socket closed');
        _signal();
      },
    );
    try {
      source = await file.open();
      if (await source.length() != size) {
        throw const FormatException('Source size changed');
      }
      final sink = const DartSha256().newHashSink();
      try {
        while (true) {
          _check();
          final bytes = await source.read(65536);
          if (bytes.isEmpty) break;
          sink.add(bytes);
        }
      } finally {
        sink.close();
      }
      final digest = (await sink.hash()).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (digest != sha256) {
        throw const FormatException('Source digest changed');
      }
      NovoRudpFrame? resumeAck;
      dynamic resumeDecision;
      for (var attempt = 0; attempt < maxStalls; attempt++) {
        await _send(_frame(NovoRudpFrameKind.done, 0, const []));
        final ack = await _nextAck();
        if (ack == null) continue;
        final decision = await planner.acceptAuthenticatedAck(ack);
        _check();
        if (decision == 'ReceiverDone') return;
        if (decision is Map && decision.containsKey('Repair')) {
          resumeAck = ack;
          resumeDecision = decision;
          break;
        }
      }
      if (resumeAck == null) {
        throw TimeoutException('Receiver did not acknowledge');
      }
      final missingAtStart =
          (jsonDecode(utf8.decode(resumeAck.payload)) as Map)['missing_count'];
      if (missingAtStart == fragments) {
        // Send the initial data once. The ACK repair planner is for actual loss,
        // not for delivering every byte through small repeated repair windows.
        // Keep conservative pacing while transport congestion control is pending.
        await source.setPosition(0);
        for (var index = 0; index < fragments; index++) {
          _check();
          final length = math.min(
            NovoRudpFileReceiver.chunkSize,
            size - index * NovoRudpFileReceiver.chunkSize,
          );
          final bytes = await source.read(length);
          if (bytes.length != length) {
            throw const FormatException('Source truncated');
          }
          await _send(_frame(NovoRudpFrameKind.data, index, bytes));
          if ((index + 1) % 16 == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        }
        resumeAck = null;
        resumeDecision = null;
      }
      var stalls = 0, previousMissing = fragments + 1;
      while (true) {
        _check();
        NovoRudpFrame? ack;
        dynamic decision;
        if (resumeAck != null) {
          ack = resumeAck;
          decision = resumeDecision;
          resumeAck = null;
          resumeDecision = null;
        } else {
          await _send(_frame(NovoRudpFrameKind.done, 0, const []));
          ack = await _nextAck();
          if (ack == null) {
            if (++stalls >= maxStalls) {
              throw TimeoutException('Receiver did not acknowledge');
            }
            continue;
          }
          try {
            decision = await planner.acceptAuthenticatedAck(ack);
            _check();
          } on StateError {
            _check();
            if (++stalls >= maxStalls) {
              throw const FormatException('Invalid transfer acknowledgements');
            }
            continue;
          }
        }
        if (decision == 'ReceiverDone') return;
        if (decision is! Map || !decision.containsKey('Repair')) {
          if (++stalls >= maxStalls) {
            throw TimeoutException('Receiver made no progress');
          }
          continue;
        }
        final missing =
            (jsonDecode(utf8.decode(ack.payload)) as Map)['missing_count']
                as int;
        stalls = missing < previousMissing ? 0 : stalls + 1;
        previousMissing = missing;
        if (stalls >= maxStalls) {
          throw TimeoutException('Receiver made no progress');
        }
        final plan = decision['Repair'] as Map;
        final pause = Duration(
          milliseconds:
              (plan['batch_pause_ms'] as int) * (1 << math.min(stalls, 5)),
        );
        final batch = math.max(
          1,
          (plan['batch_size'] as int) >> math.min(stalls, 4),
        );
        var sent = 0;
        for (final range in plan['window']['missing_ranges'] as List) {
          for (
            var index = range['start'] as int;
            index <= range['end_inclusive'];
            index++
          ) {
            _check();
            await source.setPosition(index * NovoRudpFileReceiver.chunkSize);
            final length = math.min(
              NovoRudpFileReceiver.chunkSize,
              size - index * NovoRudpFileReceiver.chunkSize,
            );
            final bytes = await source.read(length);
            if (bytes.length != length) {
              throw const FormatException('Source truncated');
            }
            for (var copy = 0; copy < plan['packet_copies']; copy++) {
              await _send(_frame(NovoRudpFrameKind.repair, index, bytes));
              if (++sent % batch == 0) await Future<void>.delayed(pause);
            }
          }
        }
      }
    } finally {
      await subscription.cancel();
      planner.close();
      await source?.close();
      _clock.stop();
    }
  }
}
