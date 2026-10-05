import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/call_capture_permission.dart';

Future<bool> checkCallPermission(
  BuildContext context, {
  required bool video,
  Future<void> Function({required bool video})? request,
}) async {
  try {
    await (request ?? requireCallCapturePermission)(video: video);
    return context.mounted;
  } on CallCapturePermissionDenied {
    if (!context.mounted) return false;
    final locale = Localizations.localeOf(context);
    final index = locale.languageCode == 'en'
        ? 1
        : locale.languageCode == 'th'
        ? 3
        : (locale.countryCode == 'TW' || locale.scriptCode == 'Hant')
        ? 2
        : 0;
    final text = video
        ? [
            '视频通话需要麦克风和相机权限，请在系统设置中开启。',
            'Enable microphone and camera access in Settings to make video calls.',
            '視訊通話需要麥克風和相機權限，請在系統設定中開啟。',
            'โปรดอนุญาตไมโครโฟนและกล้องในการตั้งค่าเพื่อโทรวิดีโอ',
          ]
        : [
            '语音通话需要麦克风权限，请在系统设置中开启。',
            'Enable microphone access in Settings to make voice calls.',
            '語音通話需要麥克風權限，請在系統設定中開啟。',
            'โปรดอนุญาตไมโครโฟนในการตั้งค่าเพื่อโทรด้วยเสียง',
          ];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(text[index]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(['取消', 'Cancel', '取消', 'ยกเลิก'][index]),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Geolocator.openAppSettings();
            },
            child: Text(
              ['去设置', 'Open Settings', '前往設定', 'เปิดการตั้งค่า'][index],
            ),
          ),
        ],
      ),
    );
    return false;
  }
}
