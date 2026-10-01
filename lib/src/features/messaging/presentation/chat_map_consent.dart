import 'package:flutter/material.dart';

import '../data/chat_map_preview_cache.dart';

Future<bool> requestTencentChatMapConsent(BuildContext context) async {
  if (await ChatMapPreviewCache.restoreConsent()) return true;
  if (!context.mounted) return false;
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('使用地图选择位置'),
      content: const Text(
        '地图与附近地点由腾讯位置服务提供，将使用你选择的位置或搜索词加载地图和地点。仅在位置页面使用定位，不进行后台定位。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('同意并使用'),
        ),
      ],
    ),
  );
  if (agreed != true) return false;
  await ChatMapPreviewCache.acceptConsent();
  return true;
}
