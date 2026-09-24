import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'novorudp_secure_packet.dart';

/// Reassembly only; callers must authenticate every fragment before admission.
class NovoRudpIceSignaling {
  NovoRudpIceSignaling({Duration Function()? clock})
    : _clock = clock ?? ((Stopwatch()..start()).elapsedDuration);

  final Duration Function() _clock;
  static const maxBytes = 32768, chunkBytes = 512;
  final _pending = <String, _Assembly>{};
  final _recent = <String, Duration>{};

  static List<List<int>> encode(Map<String, dynamic> message) {
    final bytes = utf8.encode(jsonEncode(message));
    if (bytes.length > maxBytes) {
      throw const FormatException('ICE signal exceeds budget');
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final count = (bytes.length + chunkBytes - 1) ~/ chunkBytes;
    return [
      for (var index = 0; index < count; index++)
        utf8.encode(
          jsonEncode({
            'v': 1,
            'id': id,
            'i': index,
            'n': count,
            'b': base64Encode(
              bytes.sublist(
                index * chunkBytes,
                min(bytes.length, (index + 1) * chunkBytes),
              ),
            ),
          }),
        ),
    ];
  }

  Map<String, dynamic>? accept(List<int> payload) {
    if (payload.length > NovoRudpSecurePacket.maxFramePayload ||
        payload.any((b) => b < 0 || b > 255)) {
      throw const FormatException('Invalid ICE fragment size');
    }
    final value = jsonDecode(utf8.decode(payload));
    if (value is! Map ||
        value['v'] != 1 ||
        value['id'] is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(value['id']) ||
        value['i'] is! int ||
        value['n'] is! int ||
        value['n'] < 1 ||
        value['n'] > maxBytes ~/ chunkBytes ||
        value['i'] < 0 ||
        value['i'] >= value['n'] ||
        value['b'] is! String) {
      throw const FormatException('Invalid ICE fragment');
    }
    final bytes = base64Decode(value['b'] as String);
    final index = value['i'] as int, count = value['n'] as int;
    if (bytes.isEmpty ||
        bytes.length > chunkBytes ||
        (index < count - 1 && bytes.length != chunkBytes)) {
      throw const FormatException('Invalid ICE chunk length');
    }
    final now = _clock();
    _pending.removeWhere(
      (_, a) => now - a.started >= const Duration(seconds: 10),
    );
    _recent.removeWhere((_, at) => now - at >= const Duration(seconds: 30));
    final id = value['id'] as String;
    if (_recent.containsKey(id)) return null;
    var assembly = _pending[id];
    if (assembly != null &&
        (assembly.count != count ||
            (assembly.parts[index] != null &&
                !listEquals(assembly.parts[index], bytes)))) {
      throw const FormatException('Conflicting ICE fragment');
    }
    if (assembly == null) {
      if (_pending.length >= 4) {
        throw const FormatException('ICE reassembly full');
      }
      assembly = _Assembly(count, now);
      _pending[id] = assembly;
    }
    assembly.parts[index] = bytes;
    if (assembly.parts.length != count) return null;
    _pending.remove(id);
    if (_recent.length >= 64) _recent.remove(_recent.keys.first);
    _recent[id] = now;
    final decoded = jsonDecode(
      utf8.decode([for (var i = 0; i < count; i++) ...assembly.parts[i]!]),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid ICE message');
    }
    return decoded;
  }

  void clear() {
    _pending.clear();
    _recent.clear();
  }
}

class _Assembly {
  _Assembly(this.count, this.started);
  final int count;
  final Duration started;
  final parts = <int, List<int>>{};
}

extension on Stopwatch {
  Duration elapsedDuration() => elapsed;
}
