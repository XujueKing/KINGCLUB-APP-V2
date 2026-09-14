import 'dart:convert';
import 'dart:typed_data';

/// KINGCLUB's versioned UDP carrier for the upstream secure envelope.
/// This is not the unencrypted NOVRUDP0 frame format. Authentication remains
/// entirely in the upstream channel; decoding alone does not establish trust.
class NovoRudpSecurePacket {
  static const headerSize = 112;
  static const maxDatagramBytes = 1200;
  static const maxFramePayload = maxDatagramBytes - headerSize - 16 - 96;
  static final _magic = ascii.encode('KCNSEC01');
  static const _peerPrefix = 'novovm-ed25519:';

  static Uint8List encode(Map<String, dynamic> envelope) {
    if (envelope['version'] != 1) {
      throw const FormatException('Unsupported secure envelope');
    }
    final cipher = _bytes(envelope['ciphertext']);
    if (cipher.length < 16 || cipher.length > maxDatagramBytes - headerSize) {
      throw const FormatException('Secure datagram exceeds lane budget');
    }
    final sequence = envelope['sequence'];
    // Dart's JSON bridge currently supports signed 64-bit integers. Rotate the
    // channel before exhaustion; never truncate an upstream unsigned sequence.
    if (sequence is! int || sequence < 0) {
      throw const FormatException('Unsupported secure sequence');
    }
    final wire = Uint8List(headerSize + cipher.length);
    final view = ByteData.sublistView(wire);
    wire.setAll(0, _magic);
    view.setUint16(8, 1, Endian.little);
    wire.setAll(10, _bytes(envelope['session_id'], 16));
    wire.setAll(26, _peer(envelope['sender_peer_id']));
    wire.setAll(58, _peer(envelope['recipient_peer_id']));
    view.setUint64(90, sequence, Endian.little);
    wire.setAll(98, _bytes(envelope['nonce'], 12));
    view.setUint16(110, cipher.length, Endian.little);
    wire.setAll(headerSize, cipher);
    return wire;
  }

  static Map<String, dynamic> decode(Uint8List wire) {
    if (wire.length < headerSize + 16 || wire.length > maxDatagramBytes) {
      throw const FormatException('Invalid secure datagram length');
    }
    final view = ByteData.sublistView(wire);
    for (var i = 0; i < _magic.length; i++) {
      if (wire[i] != _magic[i]) {
        throw const FormatException('Invalid secure datagram magic');
      }
    }
    if (view.getUint16(8, Endian.little) != 1 ||
        wire[97] >= 128 ||
        view.getUint16(110, Endian.little) != wire.length - headerSize) {
      throw const FormatException('Invalid secure datagram header');
    }
    String peer(int offset) =>
        '$_peerPrefix${wire.sublist(offset, offset + 32).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    return {
      'version': 1,
      'session_id': wire.sublist(10, 26),
      'sender_peer_id': peer(26),
      'recipient_peer_id': peer(58),
      'sequence': view.getUint64(90, Endian.little),
      'nonce': wire.sublist(98, 110),
      'ciphertext': wire.sublist(headerSize),
    };
  }

  static Uint8List _bytes(dynamic value, [int? length]) {
    if (value is! List ||
        (length != null && value.length != length) ||
        value.any((b) => b is! int || b < 0 || b > 255)) {
      throw const FormatException('Invalid secure envelope bytes');
    }
    return Uint8List.fromList(value.cast<int>());
  }

  static Uint8List _peer(dynamic value) {
    if (value is! String ||
        !RegExp(r'^novovm-ed25519:[0-9a-f]{64}$').hasMatch(value)) {
      throw const FormatException('Invalid network peer');
    }
    final hex = value.substring(_peerPrefix.length);
    return Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
  }
}
