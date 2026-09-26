import 'package:flutter/services.dart';

/// Device registration only. The authenticated server must bind this token to
/// the current session before it becomes a notification destination.
class NativePushRegistration {
  static const _channel = MethodChannel('kingclub/push-registration');

  Future<String> register({
    required String appKey,
    required String appSecret,
  }) async {
    if (appKey.trim().isEmpty || appSecret.trim().isEmpty) {
      throw ArgumentError('Missing client push configuration');
    }
    final result = await _channel.invokeMapMethod<String, dynamic>('register', {
      'appKey': appKey,
      'appSecret': appSecret,
    });
    final token = result?['token'];
    if (result?['provider'] != 'oppo' ||
        token is! String ||
        token.trim().isEmpty ||
        token.length > 4096) {
      throw const FormatException('Invalid push registration');
    }
    return token;
  }
}
