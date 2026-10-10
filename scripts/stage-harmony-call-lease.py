from pathlib import Path
import sys
repo = Path(__file__).resolve().parent.parent
root = Path(sys.argv[1]).resolve()
if root == repo or repo in root.parents:
    raise SystemExit('Use an isolated Harmony application.')
base = root / 'native_plugins/kingclub_notification_ohos/ohos/src/main/ets'
p = base / 'KingclubNotificationPlugin.ets'
s = p.read_text(encoding='utf-8')
if 'CallBackgroundLease' in s:
    raise SystemExit('Already staged')
s = "import { CallBackgroundLease } from './CallBackgroundLease';\n" + s
s = s.replace('  private local:', '  private callLease: CallBackgroundLease = new CallBackgroundLease();\n  private callChannel: MethodChannel | null = null;\n  private local:', 1)
s = s.replace("    this.channel = new MethodChannel", "    this.callChannel = new MethodChannel(binding.getBinaryMessenger(), 'kingclub/call-foreground');\n    this.callChannel.setMethodCallHandler(this.callLease);\n    this.channel = new MethodChannel", 1)
s = s.replace('this.local.context = this.context;', 'this.local.context = this.context; this.callLease.context = this.context;')
s = s.replace('this.local.detach();', 'this.local.detach(); this.callLease.detach();')
s = s.replace('    NotificationLifecycle.changed = null;', '    this.callChannel?.setMethodCallHandler(null); this.callChannel = null;\n    NotificationLifecycle.changed = null;')
p.write_text(s, encoding='utf-8')
(base/'CallBackgroundLease.ets').write_text((repo/'harmony/verification/CallBackgroundLease.ets.template').read_text(encoding='utf-8'),encoding='utf-8')
p = root/'lib/src/features/messaging/data/call_foreground_lease.dart'
s = p.read_text(encoding='utf-8').replace('Platform.isAndroid || Platform.isIOS', "Platform.isAndroid || Platform.isIOS || Platform.operatingSystem == 'ohos'")
p.write_text(s,encoding='utf-8')
p = root/'ohos/entry/src/main/module.json5'
s = p.read_text(encoding='utf-8')
if '"backgroundModes"' in s: raise SystemExit('Review existing background modes')
s = s.replace('"exported": true,', '"backgroundModes": ["voip"],\n        "exported": true,',1)
if 'ohos.permission.KEEP_BACKGROUND_RUNNING' not in s:
    s = s.replace('"requestPermissions": [', '"requestPermissions": [\n      {"name":"ohos.permission.KEEP_BACKGROUND_RUNNING"},',1)
p.write_text(s,encoding='utf-8')
print('Harmony call lease staged; media gate remains disabled.')
