import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';

enum NovoRudpFrameKind { data, repair, ack, endpoint, done }

/// Wire compatibility only. Checksum is not authentication or encryption.
/// No production chat transport is enabled by this codec.
class NovoRudpFrame {
  NovoRudpFrame({
    required this.kind,
    required List<int> sessionId,
    required this.streamId,
    required this.objectId,
    required this.sequence,
    required this.ackEpoch,
    required List<int> payload,
  }) : sessionId = Uint8List.fromList(sessionId).asUnmodifiableView(),
       payload = Uint8List.fromList(payload).asUnmodifiableView() {
    if (sessionId.length != 16 ||
        payload.length > maxPayload ||
        [...sessionId, ...payload].any((b) => b < 0 || b > 255)) {
      throw const FormatException('Invalid NovoRUDP payload or session');
    }
    for (final value in [streamId, objectId, sequence, ackEpoch]) {
      if (value < BigInt.zero || value > _maxU64) {
        throw const FormatException('NovoRUDP unsigned integer out of range');
      }
    }
  }
  static const headerSize = 96;
  static const maxPayload = 65507 - headerSize;
  static final _magic = ascii.encode('NOVRUDP0');
  static final _domain = ascii.encode('novorudp-transport-frame-v0');
  static final _maxU64 = (BigInt.one << 64) - BigInt.one;
  final NovoRudpFrameKind kind;
  final Uint8List sessionId, payload;
  final BigInt streamId, objectId, sequence, ackEpoch;

  static Uint8List _u64(BigInt value) => Uint8List.fromList([
    for (var i = 0; i < 8; i++) ((value >> (i * 8)) & BigInt.from(255)).toInt(),
  ]);
  static BigInt _readU64(Uint8List bytes, int offset) {
    var value = BigInt.zero;
    for (var i = 7; i >= 0; i--) {
      value = (value << 8) | BigInt.from(bytes[offset + i]);
    }
    return value;
  }

  Future<List<int>> _checksum() async => (await const DartSha256().hash([
    ..._domain,
    ..._magic,
    1,
    0,
    kind.index + 1,
    ...sessionId,
    ..._u64(streamId),
    ..._u64(objectId),
    ..._u64(sequence),
    ..._u64(ackEpoch),
    ..._u64(BigInt.from(payload.length)),
    ...payload,
  ])).bytes;

  Future<Uint8List> encode() async {
    final out = Uint8List(headerSize + payload.length);
    out.setRange(0, 8, _magic);
    final data = ByteData.sublistView(out);
    data.setUint16(8, 1, Endian.little);
    out[10] = kind.index + 1;
    out.setRange(12, 28, sessionId);
    var offset = 28;
    for (final value in [streamId, objectId, sequence, ackEpoch]) {
      out.setRange(offset, offset + 8, _u64(value));
      offset += 8;
    }
    data.setUint32(60, payload.length, Endian.little);
    out.setRange(64, 96, await _checksum());
    out.setRange(96, out.length, payload);
    return out;
  }

  static Future<NovoRudpFrame> decode(Uint8List input) async {
    if (input.length < headerSize || input.length > headerSize + maxPayload) {
      throw const FormatException('Invalid NovoRUDP datagram length');
    }
    // Own bytes across the asynchronous checksum calculation.
    final bytes = Uint8List.fromList(input);
    final data = ByteData.sublistView(bytes);
    if (!List.generate(8, (i) => bytes[i] == _magic[i]).every((v) => v) ||
        data.getUint16(8, Endian.little) != 1 ||
        bytes[10] < 1 ||
        bytes[10] > 5 ||
        data.getUint32(60, Endian.little) != bytes.length - headerSize) {
      throw const FormatException('Invalid NovoRUDP frame header');
    }
    // Upstream v0 does not interpret the reserved byte at offset 11.
    final frame = NovoRudpFrame(
      kind: NovoRudpFrameKind.values[bytes[10] - 1],
      sessionId: bytes.sublist(12, 28),
      streamId: _readU64(bytes, 28),
      objectId: _readU64(bytes, 36),
      sequence: _readU64(bytes, 44),
      ackEpoch: _readU64(bytes, 52),
      payload: bytes.sublist(headerSize),
    );
    final checksum = await frame._checksum();
    var mismatch = 0;
    for (var i = 0; i < 32; i++) {
      mismatch |= bytes[64 + i] ^ checksum[i];
    }
    if (mismatch != 0) {
      throw const FormatException('NovoRUDP checksum mismatch');
    }
    return frame;
  }
}
