"""Stage permission support into an isolated Harmony application only."""
from pathlib import Path
import shutil
import sys

repo = Path(__file__).resolve().parent.parent
root = Path(sys.argv[1]).resolve()
if root == repo or repo in root.parents or not root.is_dir():
    raise SystemExit('Use an existing isolated Harmony application.')
destination = root / 'native_plugins/kingclub_notification_ohos'
if destination.exists():
    raise SystemExit('Already staged; review instead of overwriting.')
manifest_path = root / 'pubspec.yaml'
manifest = manifest_path.read_text(encoding='utf-8')
page_path = root / 'lib/src/features/profile_settings/presentation/settings_page.dart'
page = page_path.read_text(encoding='utf-8')
start = page.index('                KingSwitchListTile(', page.index('Future<void> _showNotificationStatus()'))
end = page.index('\n              ],', start)
background = page[start:end]
if "title: const Text('后台接收消息和来电')" not in background or 'dependencies:' not in manifest:
    raise SystemExit('Settings contract changed; review before staging.')
permission_ui = '''                if (defaultTargetPlatform == TargetPlatform.ohos) ...[
                  TextButton(
                    onPressed: () async {
                      try {
                        await NativePushRegistration().requestNotificationPermission();
                      } catch (_) {
                        if (settingsContext.mounted) {
                          KingNotice.of(context).showSnackBar(
                            const SnackBar(content: Text('未能开启通知，可通过系统设置调整')),
                          );
                        }
                      }
                      final enabled = await NativePushRegistration().notificationStatus();
                      if (mounted) setState(() => _notificationsEnabled = enabled);
                      if (settingsContext.mounted) update(() {});
                    },
                    child: const Text('允许通知'),
                  ),
                ] else ...[
'''
page = page[:start] + permission_ui + background + '\n                ],' + page[end:]
page = page.replace("var receiverEnabled = await BackgroundConnection.invoke('enabled');", "var receiverEnabled = defaultTargetPlatform == TargetPlatform.ohos ? false : await BackgroundConnection.invoke('enabled');")
page = "import 'package:flutter/foundation.dart';\n" + page
shutil.copytree(repo / 'harmony/plugins/kingclub_notification_ohos', destination)
manifest_path.write_text(manifest.replace('dependencies:', 'dependencies:\n  kingclub_notification_ohos:\n    path: native_plugins/kingclub_notification_ohos', 1), encoding='utf-8')
page_path.write_text(page, encoding='utf-8')
print('Harmony notification permissions staged; no vendor registration enabled.')
