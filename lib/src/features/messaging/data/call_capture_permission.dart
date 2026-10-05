import 'dart:io';

import 'package:flutter/services.dart';

class CallCapturePermissionDenied implements Exception {}

Future<void> requireCallCapturePermission({required bool video}) async {
  if (!Platform.isIOS && !Platform.isAndroid) return;
  final granted = await const MethodChannel('kingclub/call-permission')
      .invokeMethod<bool>('request', {'video': video});
  if (granted != true) throw CallCapturePermissionDenied();
}
