import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../../../core/session/member_qr_memory.dart';
import 'chat_history_store.dart';
import 'novorudp_frame.dart';
import 'novorudp_frame_link.dart';

class _TextSend {
  _TextSend(this.hash, this.packets);
  final String hash;
  final List<Map<String, dynamic>> packets;
  final done = Completer<void>();
  Timer? retry, deadline;
  bool sending = false;
}

class _TextParts {
  _TextParts(this.hash, this.count);
  final String hash;
  final int count;
  final parts = <int, List<int>>{};
  final age = Stopwatch()..start();
}

/// One already-authorized device lane. The caller supplies the live local grant.
/// Receiver receipts follow durable storage; loss retries use fresh AEAD sequences.
class NearbyTextChannel {
  NearbyTextChannel({
    required this.link,
    required this.history,
    required this.peerId,
    required this.canExchange,
    this.peerAccount,
  }) {
    _subscription = link.frames.listen(
      (frame) {
        if (_closed || _queued >= 32 || frame.streamId != _stream) return;
        _queued++;
        _tail = _tail
            .then((_) => _receive(frame))
            .catchError((Object _) {
              unawaited(close());
            })
            .whenComplete(() {
              _queued--;
            });
      },
      onError: (Object _) => unawaited(close()),
      onDone: () => unawaited(close()),
    );
    if (peerAccount != null) {
      _readRetry = Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(flushReadReceipts()),
      );
      unawaited(flushReadReceipts());
    }
  }
  final NovoRudpFrameLink link;
  final ChatHistoryStore history;
  final String peerId;
  final String? peerAccount;
  final bool Function() canExchange;
  static final _stream = BigInt.from(0x4b43544d);
  static final _uuid = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
  );
  final int _generation = MemberQrMemory.generation;
  final _pending = <String, _TextSend>{};
  final _assembling = <String, _TextParts>{};
  final _changes = StreamController<String>.broadcast();
  late final StreamSubscription<NovoRudpFrame> _subscription;
  Future<void> _tail = Future.value();
  Future<void>? _closing;
  BigInt _sequence = BigInt.zero;
  int _queued = 0;
  bool _closed = false;
  Timer? _readRetry;
  bool _sendingRead = false;
  Future<void> flushReadReceipts() async {
    if (_closed || _sendingRead || peerAccount == null) return;
    _sendingRead = true;
    try {
      _check();
      final ids = await history.pendingNearbyReadReceipts(peerId);
      _check();
      if (ids.isNotEmpty) {
        await _send({'v': 1, 'op': 'read', 'ids': ids}, NovoRudpFrameKind.data);
      }
    } catch (_) {
      // Durable pending IDs remain available for the next live channel.
    } finally {
      _sendingRead = false;
    }
  }

  Stream<String> get changes => _changes.stream;
  void _check() {
    if (_closed || _generation != MemberQrMemory.generation || !canExchange()) {
      unawaited(close());
      throw StateError('Nearby chat unavailable');
    }
  }

  Future<String> _hash(List<int> bytes) async =>
      base64UrlEncode((await Sha256().hash(bytes)).bytes);
  Future<void> _send(
    Map<String, dynamic> packet,
    NovoRudpFrameKind kind,
  ) async {
    _check();
    _sequence += BigInt.one;
    await link.send(
      NovoRudpFrame(
        kind: kind,
        sessionId: link.channel.sessionId,
        streamId: _stream,
        objectId: BigInt.zero,
        sequence: _sequence,
        ackEpoch: BigInt.zero,
        payload: utf8.encode(jsonEncode(packet)),
      ),
    );
    _check();
  }

  Future<void> sendText(String text, {String? messageId}) async {
    _check();
    if (_pending.length >= 8) throw StateError('Nearby send queue full');
    final id = messageId ?? const Uuid().v4();
    await history.persistNearbyText(
      peerAccount: peerAccount,
      peerId: peerId,
      id: id,
      text: text,
      outgoing: true,
    );
    _check();
    final existing = _pending[id];
    if (existing != null) return existing.done.future;
    if (_pending.length >= 8) throw StateError('Nearby send queue full');
    final bytes = utf8.encode(text);
    final hash = await _hash(bytes);
    _check();
    if (_pending[id] != null) return _pending[id]!.done.future;
    if (_pending.length >= 8) throw StateError('Nearby send queue full');
    final count = (bytes.length + 511) ~/ 512;
    final state = _TextSend(
      hash,
      List.generate(
        count,
        (i) => {
          'v': 1,
          'id': id,
          'hash': hash,
          'i': i,
          'n': count,
          'data': base64Encode(
            bytes.sublist(
              i * 512,
              (i + 1) * 512 > bytes.length ? bytes.length : (i + 1) * 512,
            ),
          ),
        },
      ),
    );
    _pending[id] = state;
    Future<void> transmit() async {
      if (state.sending || state.done.isCompleted) return;
      state.sending = true;
      try {
        for (final packet in state.packets) {
          if (state.done.isCompleted) break;
          await _send(packet, NovoRudpFrameKind.data);
        }
      } catch (error) {
        _finish(id, error);
      } finally {
        state.sending = false;
      }
    }

    state.retry = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => unawaited(transmit()),
    );
    state.deadline = Timer(
      const Duration(seconds: 15),
      () => _finish(id, TimeoutException('Nearby receipt timed out')),
    );
    unawaited(transmit());
    await state.done.future;
  }

  Future<void> resumePending() async {
    while (true) {
      _check();
      final rows = await history.nearbyMessages(
        peerId,
        pendingOnly: true,
        limit: 200,
      );
      if (rows.isEmpty) return;
      for (final row in rows) {
        await sendText(row['text'] as String, messageId: row['id'] as String);
      }
    }
  }

  Future<void> _receive(NovoRudpFrame frame) async {
    _check();
    Map<String, dynamic> value;
    try {
      final decoded = jsonDecode(utf8.decode(frame.payload));
      if (decoded is! Map<String, dynamic>) return;
      value = decoded;
    } on FormatException {
      return;
    }
    if (value['v'] == 1 &&
        (value['op'] == 'read' || value['op'] == 'read_ack')) {
      if (frame.kind != NovoRudpFrameKind.data || peerAccount == null) return;
      final ids = value['ids'];
      if (ids is! List ||
          ids.isEmpty ||
          ids.length > 16 ||
          ids.any((id) => id is! String || !_uuid.hasMatch(id))) {
        return;
      }
      final ack = value['op'] == 'read_ack';
      final matched = await history.applyNearbyReadReceipt(
        peerId: peerId,
        peerAccount: peerAccount!,
        ids: ids.cast<String>(),
        acknowledgement: ack,
      );
      _check();
      if (!ack) {
        // Acknowledge processing even if local cleanup removed the message.
        // Unknown IDs never create messages or acquire a read state, and cannot
        // pin the other device's durable receipt queue ahead of newer receipts.
        await _send({
          'v': 1,
          'op': 'read_ack',
          'ids': ids.toSet().toList(),
        }, NovoRudpFrameKind.data);
        for (final id in matched) {
          _changes.add(id);
        }
      }
      return;
    }
    final id = value['id'], hash = value['hash'];
    if (value['v'] != 1 ||
        id is! String ||
        !_uuid.hasMatch(id) ||
        hash is! String ||
        hash.length != 44) {
      return;
    }
    if (frame.kind == NovoRudpFrameKind.ack) {
      final state = _pending[id];
      if (state == null || state.hash != hash) return;
      if (await history.confirmNearbyReceipt(peerId: peerId, id: id)) {
        _check();
        _finish(id);
        _changes.add(id);
      }
      return;
    }
    if (frame.kind != NovoRudpFrameKind.data) return;
    final index = value['i'], count = value['n'], encoded = value['data'];
    if (index is! int ||
        count is! int ||
        count < 1 ||
        count > 24 ||
        index < 0 ||
        index >= count ||
        encoded is! String ||
        encoded.length > 684) {
      return;
    }
    List<int> bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException {
      return;
    }
    if (bytes.isEmpty || bytes.length > 512) return;
    _assembling.removeWhere(
      (_, parts) => parts.age.elapsed > const Duration(seconds: 15),
    );
    if (!_assembling.containsKey(id) && _assembling.length >= 32) return;
    final parts = _assembling.putIfAbsent(id, () => _TextParts(hash, count));
    if (parts.hash != hash || parts.count != count) return;
    parts.parts[index] = bytes;
    if (parts.parts.length != count) return;
    final all = [for (var i = 0; i < count; i++) ...parts.parts[i]!];
    _assembling.remove(id);
    // Match the UI/server's 4000 UTF-16 units: up to 12000 UTF-8 bytes.
    if (all.length > 12000 || await _hash(all) != hash) return;
    String text;
    try {
      text = utf8.decode(all);
    } on FormatException {
      return;
    }
    if (text.isEmpty || text.length > 4000) return;
    _check();
    await history.persistNearbyText(
      peerAccount: peerAccount,
      peerId: peerId,
      id: id,
      text: text,
      outgoing: false,
    );
    _check();
    await _send({'v': 1, 'id': id, 'hash': hash}, NovoRudpFrameKind.ack);
    _changes.add(id);
  }

  void _finish(String id, [Object? error]) {
    final state = _pending.remove(id);
    if (state == null) return;
    state.retry?.cancel();
    state.deadline?.cancel();
    if (error == null) {
      state.done.complete();
    } else {
      state.done.completeError(error);
    }
  }

  Future<void> close() {
    _closed = true;
    _readRetry?.cancel();
    return _closing ??= _close();
  }

  Future<void> _close() async {
    for (final id in _pending.keys.toList()) {
      _finish(id, StateError('Nearby chat closed'));
    }
    _assembling.clear();
    await _subscription.cancel();
    await link.close();
    await _changes.close();
  }
}
