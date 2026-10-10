"""Stage the pinned native candidate without downgrading Dart or primary platforms."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

repo = Path(__file__).resolve().parent.parent
root, upstream, dart_package = [Path(v).resolve() for v in sys.argv[1:4]]
if root == repo or repo in root.parents or not root.is_dir():
    raise SystemExit('Use an isolated Harmony application.')
pin = json.loads((repo / 'harmony/webrtc-source.json').read_text(encoding='utf-8'))
revision = subprocess.check_output(['git', '-C', str(upstream), 'rev-parse', 'HEAD'], text=True).strip()
if revision != pin['commit']:
    raise SystemExit('Unexpected upstream revision.')
if subprocess.check_output(['git', '-C', str(upstream), 'status', '--porcelain'], text=True).strip():
    raise SystemExit('Upstream audit checkout must be clean.')
for name, expected in pin['sha256'].items():
    if hashlib.sha256((upstream / name).read_bytes()).hexdigest() != expected:
        raise SystemExit('Native binary checksum mismatch: '+name)
dest = root / 'native_plugins/flutter_webrtc'
if dest.exists(): raise SystemExit('Already staged; do not overwrite.')
manifest = root / 'pubspec.yaml'
s = manifest.read_text(encoding='utf-8')
if 'dependency_overrides:' not in s or 'path: native_plugins/flutter_webrtc' in s:
    raise SystemExit('Review dependency overrides.')
package = (dart_package / 'pubspec.yaml').read_text(encoding='utf-8')
if 'version: 1.6.2+hotfix.1' not in package or '      ohos:' in package:
    raise SystemExit('Expected current standard WebRTC package.')
media = root / 'lib/src/features/messaging/data/native_call_media.dart'
m = media.read_text(encoding='utf-8')
anchor = '  Future<void> _open() async {\n    try {'
if anchor not in m: raise SystemExit('Review capture lifecycle.')
group = root / 'lib/src/features/messaging/data/native_group_call_media.dart'
g = group.read_text(encoding='utf-8')
if anchor not in g: raise SystemExit('Review group capture lifecycle.')
shutil.copytree(dart_package, dest, ignore=shutil.ignore_patterns('.dart_tool', 'build', '.git'))
shutil.copytree(upstream / 'ohos', dest / 'ohos')
shutil.copyfile(upstream / 'LICENSE', dest / 'LICENSE-OHOS-UPSTREAM')
package = package.replace('    platforms:', '    platforms:\n      ohos:\n        pluginClass: FlutterWebRTCPlugin', 1)
(dest / 'pubspec.yaml').write_text(package, encoding='utf-8')
native_manifest = dest / 'ohos/oh-package.json5'
n = native_manifest.read_text(encoding='utf-8').replace('file:../libs/flutter.har', 'file:libs/flutter.har')
native_manifest.write_text(n, encoding='utf-8')
# The new embedding owns a public viewId; keep the plugin's ID independent.
view = dest / 'ohos/src/main/ets/components/VideoRenderHandler.ets'
v = view.read_text(encoding='utf-8')
v = v.replace('private viewId: number;', 'private renderViewId: number;').replace('this.viewId', 'this.renderViewId')
view.write_text(v, encoding='utf-8')
manifest.write_text(s.replace('dependency_overrides:', 'dependency_overrides:\n  flutter_webrtc:\n    path: native_plugins/flutter_webrtc', 1), encoding='utf-8')
gate = '''
      if (defaultTargetPlatform == TargetPlatform.ohos &&
          !const bool.fromEnvironment('KINGCLUB_HARMONY_CALL_MEDIA')) {
        throw StateError('鸿蒙音视频通话尚在适配，暂未开放');
      }'''
media.write_text(m.replace(anchor, anchor + gate), encoding='utf-8')
group.write_text(g.replace(anchor, anchor + gate), encoding='utf-8')
print('Pinned native candidate staged. Camera/microphone capture remains disabled by default.')
