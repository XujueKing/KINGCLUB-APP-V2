import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// RFC 8489 IPv4 binding discovery, not peer authentication. The caller must
/// match the server source address/port and reuse the data socket. A mapped
/// endpoint only becomes usable after an authenticated peer connectivity check.
class NovoRudpStunBinding {
  NovoRudpStunBinding() {
    final random = Random.secure();
    _transaction = Uint8List.fromList(
      List.generate(12, (_) => random.nextInt(256)),
    );
  }
  static const cookie = 0x2112a442;
  late final Uint8List _transaction;

  Uint8List get request {
    final bytes = Uint8List(20);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, 0x0001);
    data.setUint32(4, cookie);
    bytes.setRange(8, 20, _transaction);
    return bytes;
  }

  ({InternetAddress address, int port})? parseResponse(Uint8List bytes) {
    if (bytes.length < 20 || bytes.length > 1024) return null;
    final data = ByteData.sublistView(bytes);
    final length = data.getUint16(2);
    if (data.getUint16(0) != 0x0101 ||
        data.getUint32(4) != cookie ||
        length % 4 != 0 ||
        length + 20 != bytes.length) {
      return null;
    }
    for (var i = 0; i < 12; i++) {
      if (bytes[i + 8] != _transaction[i]) return null;
    }
    ({InternetAddress address, int port})? result;
    for (var offset = 20; offset < bytes.length;) {
      if (offset + 4 > bytes.length) return null;
      final type = data.getUint16(offset);
      final size = data.getUint16(offset + 2);
      final start = offset + 4;
      final end = start + ((size + 3) & ~3);
      if (end > bytes.length) return null;
      if (type == 0x0020) {
        if (size != 8 || bytes[start + 1] != 1 || result != null) return null;
        final port = data.getUint16(start + 2) ^ (cookie >> 16);
        final address = data.getUint32(start + 4) ^ cookie;
        if (port == 0) return null;
        result = (
          address: InternetAddress.fromRawAddress(
            Uint8List.fromList([
              address >> 24,
              (address >> 16) & 255,
              (address >> 8) & 255,
              address & 255,
            ]),
          ),
          port: port,
        );
      } else if (type < 0x8000 && type != 0x0001) {
        // Unknown comprehension-required attributes are not silently accepted.
        return null;
      }
      offset = end;
    }
    return result;
  }
}
