"""Add the surface lifecycle adapter to an already staged isolated RTC package."""
from pathlib import Path
import sys

repo = Path(__file__).resolve().parent.parent
root = Path(sys.argv[1]).resolve()
if root == repo or repo in root.parents:
    raise SystemExit('Use the isolated Harmony app.')
base = root / 'native_plugins/flutter_webrtc'
renderer = base / 'lib/src/native/rtc_video_renderer_impl.dart'
view = base / 'lib/src/native/rtc_video_view_impl.dart'
handler = base / 'ohos/src/main/ets/components/VideoRenderHandler.ets'
component = base / 'ohos/src/main/ets/components/VideoRender.ets'
r, v, h, c = [p.read_text(encoding='utf-8') for p in [renderer, view, handler, component]]
if 'bindOhosSurface' in r:
    raise SystemExit('Already staged; do not overwrite.')

def change(s, old, new, count=1):
    if s.count(old) != count:
        raise SystemExit('Source drift; review anchor: ' + old[:70])
    return s.replace(old, new)

members = (repo / 'harmony/verification/ohos_rtc_renderer_members.dart.template').read_text(encoding='utf-8')
r = change(r, '  Completer? _initializing;', members + '\n  Completer? _initializing;')
r = change(r, '    _initializing!.complete(null);', '    _initializing!.complete(null);\n    if (defaultTargetPlatform == TargetPlatform.ohos) await _syncOhosSurface();')
r = change(r, '    _srcObject = stream;', '''    _srcObject = stream;
    if (defaultTargetPlatform == TargetPlatform.ohos) {
      _ohosTrack = null;
      _syncOhosSurface().catchError((Object error) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: StateError('Harmony video stream binding failed'),
          library: 'KINGCLUB WebRTC'));
      });
      return;
    }''', 2)
# The async setter must propagate failure and retain the explicit track selector.
start = r.index('  Future<void> setSrcObject(')
tail = r[start:]
a = tail.index('    if (defaultTargetPlatform == TargetPlatform.ohos) {')
b = tail.index('    var oldTextureId', a)
tail = tail[:a] + '''    if (defaultTargetPlatform == TargetPlatform.ohos) {
      _ohosTrack = trackId;
      await _syncOhosSurface();
      return;
    }
''' + tail[b:]
r = r[:start] + tail
r = change(r, '    if (_disposed) return;\n    await _eventSubscription?.cancel();', '''    if (_disposed || _ohosClosing) return;
    if (defaultTargetPlatform == TargetPlatform.ohos) {
      _ohosClosing = true;
      await _ohosPending;
    }
    await _eventSubscription?.cancel();''')
r = change(r, 'bool get renderVideo => _textureId != null && _srcObject != null;', "bool get renderVideo => _textureId != null && _srcObject != null &&\n      (defaultTargetPlatform != TargetPlatform.ohos || _ohosSurface != null);")
v = change(v, "import 'rtc_video_renderer_impl.dart';", "import 'rtc_video_renderer_impl.dart';\nimport 'ohos_rtc_surface.dart';\nimport 'package:flutter/foundation.dart';")
v = change(v, 'child: videoRenderer.renderVideo', '''child: defaultTargetPlatform == TargetPlatform.ohos
                    ? OhosRtcSurface(renderer: videoRenderer)
                    : videoRenderer.renderVideo''')
h = change(h, '  private disposed: boolean = false;', "  private disposed: boolean = false;\n  private currentSurface: string = '';" )
h = change(h, '    switch (method) {', "    switch (method) {\n      case 'getSurfaceId':\n        result.success(this.currentSurface);\n        break;")
a = h.index('    Log.d(TAG, \'VideoRenderHandler sendMessage:')
b = h.index("    this.methodChannel?.invokeMethod('putSurfaceId'", a)
h = h[:a] + "    if (this.disposed) return;\n    this.currentSurface = surfaceId;\n" + h[b:]
a = h.index('  private sendMessageDirect(')
b = h.index('  /**', a)
h = h[:a] + h[b:]
h = change(h, '    this.disposed = true;', "    this.disposed = true;\n    this.currentSurface = '';" )
c = change(c, "      Log.d(TAG, 'onSurfaceDestroyed: SurfaceTexture destroyed (likely rotation), keeping methodChannel alive');", "      this.videoRenderHandler.sendMessage('');")
c = change(c, '    this.videoRenderHandler.dispose();', "    this.videoRenderHandler.sendMessage('');")
for p, s in [(renderer,r), (view,v), (handler,h), (component,c)]:
    p.write_text(s, encoding='utf-8')
(base / 'lib/src/native/ohos_rtc_surface.dart').write_text(
    (repo / 'harmony/verification/ohos_rtc_surface.dart.template').read_text(encoding='utf-8'), encoding='utf-8')
print('Surface adapter staged. Media gate remains disabled.')
