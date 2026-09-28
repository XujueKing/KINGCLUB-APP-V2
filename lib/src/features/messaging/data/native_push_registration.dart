import 'package:flutter/services.dart';

/// Device registration only. The authenticated server must bind this token to
/// the current session before it becomes a notification destination.
class NativePushRegistration {
  static const _channel = MethodChannel('kingclub/push-registration');

  /// Null means the platform could not report its application-level setting.
  Future<bool?> notificationStatus() async {
    try {
      return await _channel.invokeMethod<bool>('notificationStatus');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> openNotificationSettings() =>
      _channel.invokeMethod<void>('openNotificationSettings');

  Future<void> requestNotificationPermission() =>
      _channel.invokeMethod<void>('requestNotificationPermission');

  Future<({String provider, String token})> registerApple() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'registerApple',
    );
    final provider = result?['provider'];
    final token = result?['token'];
    if (!const ['apns', 'apns_sandbox'].contains(provider) ||
        token is! String ||
        token.length > 512 ||
        !RegExp(r'^(?:[0-9a-f]{2}){16,256}$').hasMatch(token)) {
      throw const FormatException('Invalid APNs registration');
    }
    return (provider: provider as String, token: token);
  }

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
