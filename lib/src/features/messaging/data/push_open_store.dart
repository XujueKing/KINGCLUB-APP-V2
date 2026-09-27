import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One short-lived notification destination, never message text or credentials.
class PushOpenStore {
  PushOpenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'kingclub.chat.pending-notification.v1';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: key);
  Future<void> save(String value) => _storage.write(key: key, value: value);
  Future<void> clear() => _storage.delete(key: key);
}
