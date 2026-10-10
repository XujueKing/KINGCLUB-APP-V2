from pathlib import Path
import shutil
import sys

repo = Path(__file__).resolve().parent.parent
root = Path(sys.argv[1]).resolve()
if root == repo or repo in root.parents or not root.is_dir():
    raise SystemExit('Use an isolated Harmony application.')
plugin = root / 'native_plugins/kingclub_notification_ohos'
host = root / 'ohos/entry/src/main/ets/entryability/EntryAbility.ets'
app = root / 'lib/src/app.dart'
host_text = host.read_text(encoding='utf-8')
app_text = app.read_text(encoding='utf-8')
anchor = 'export default class EntryAbility extends FlutterAbility {'
gate = '(defaultTargetPlatform == TargetPlatform.android ||'
if not plugin.is_dir() or 'NotificationLifecycle' in host_text or anchor not in host_text or app_text.count(gate) != 1:
    raise SystemExit('Review host/plugin/platform gate before staging.')
hooks = '''
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    NotificationLifecycle.accept(this.context, want);
    super.onCreate(want, launchParam);
  }
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    NotificationLifecycle.accept(this.context, want);
    super.onNewWant(want, launchParam);
  }
  onForeground(): void {
    NotificationLifecycle.setForeground(true);
    super.onForeground();
  }
  onBackground(): void {
    NotificationLifecycle.setForeground(false);
    super.onBackground();
  }
'''
host_text = "import { NotificationLifecycle } from 'kingclub_notification_ohos';\nimport { Want, AbilityConstant } from '@kit.AbilityKit';\n" + host_text.replace(anchor, anchor + hooks)
app_text = app_text.replace(gate, '(defaultTargetPlatform == TargetPlatform.ohos ||\n         defaultTargetPlatform == TargetPlatform.android ||')
for source in (repo / 'harmony/plugins/kingclub_notification_ohos/ohos').rglob('*'):
    if source.is_file():
        target = plugin / 'ohos' / source.relative_to(repo / 'harmony/plugins/kingclub_notification_ohos/ohos')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
host.write_text(host_text, encoding='utf-8')
app.write_text(app_text, encoding='utf-8')
print('Staged native local notification and existing authenticated open flow.')
