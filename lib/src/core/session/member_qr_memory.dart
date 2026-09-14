import 'dart:io';

/// Session-local presentation cache. Never persisted or shared across logins.
abstract final class MemberQrMemory {
  static int generation = 0;
  static int presentationGeneration = 0;
  static Map<String, dynamic>? profile;
  static File? avatar;
  static Map<String, dynamic>? _qr;
  static Stopwatch? _age;
  static Future<Map<String, dynamic>>? pending;
  static Map<String, dynamic>? get valid {
    if (_qr == null) return null;
    final remaining =
        (_qr!['ttlSeconds'] as num).toInt() -
        (_age?.elapsed.inSeconds ?? 0) -
        2;
    return remaining > 0 ? {..._qr!, 'ttlSeconds': remaining} : null;
  }

  static void put(Map<String, dynamic> value) {
    _qr = value;
    _age = Stopwatch()..start();
  }

  static void clear() {
    generation++;
    clearPresentation();
  }

  static void clearPresentation() {
    presentationGeneration++;
    profile = null;
    avatar = null;
    _qr = null;
    _age = null;
    pending = null;
  }
}
