"""Acknowledge track toggles only after native state readback."""
from pathlib import Path
import sys

repo = Path(__file__).resolve().parent.parent
root = Path(sys.argv[1]).resolve()
if root == repo or repo in root.parents:
    raise SystemExit('Use an isolated Harmony application.')
p = root/'native_plugins/flutter_webrtc/ohos/src/main/ets/TrackControlHandlers.ets'
s = p.read_text(encoding='utf-8')
if 'Track state change was not applied' in s:
    raise SystemExit('Already staged.')
start = s.index('  mediaStreamTrackSetEnable(call:')
end = s.index('\n  /**', start)
s = s[:start] + '''  mediaStreamTrackSetEnable(call: MethodCall, result: MethodResult): void {
    try {
      const trackId = getTrackId(call);
      const enabled: boolean = call.argument('enabled');
      if (typeof enabled !== 'boolean') {
        this.resultError(call.method, 'enabled must be a boolean', result);
        return;
      }
      const peerConnectionId = getPeerConnectionId(call);
      const track = this.getTrackForId(trackId, peerConnectionId);
      if (!track || track.readyState !== 'live') {
        this.resultError(call.method, 'Live track is unavailable', result);
        return;
      }
      if (track.enabled !== enabled) track.enabled = enabled;
      if (track.readyState !== 'live' || track.enabled !== enabled) {
        this.resultError(call.method, 'Track state change was not applied', result);
        return;
      }
      result.success(null);
    } catch (_) {
      this.resultError(call.method, 'Track state change failed', result);
    }
  }
''' + s[end:]
p.write_text(s,encoding='utf-8')
print('Harmony track toggle acknowledgement checks staged.')
