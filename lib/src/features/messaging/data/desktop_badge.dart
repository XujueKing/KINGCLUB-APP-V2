import 'package:flutter/services.dart';

/// ColorOS 16's documented API. False means unsupported/disabled, not success.
/// The user retains control over the system's numeric-badge permission.
class DesktopBadge {
  static const _channel = MethodChannel('kingclub/local-notifications');
  static Future<bool> update(int unread) async {
    try {
      return await _channel.invokeMethod<bool>('badge', {
            'count': unread.clamp(0, 9999),
          }) ==
          true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
