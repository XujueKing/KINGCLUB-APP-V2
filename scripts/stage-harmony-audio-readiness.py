"""Reject incomplete audio initialization in the isolated Harmony RTC adapter."""
from pathlib import Path
import sys

repo = Path(__file__).resolve().parent.parent
root = Path(sys.argv[1]).resolve()
if root == repo or repo in root.parents:
    raise SystemExit('Use an isolated Harmony application.')
p = root / 'native_plugins/flutter_webrtc/ohos/src/main/ets/audio/AudioSwitchManager.ets'
s = p.read_text(encoding='utf-8')
if 'AUDIO_RESOURCES_NOT_READY' in s:
    raise SystemExit('Already staged.')
start = s.index('  whenReady(): Promise<void> {')
end = s.index('\n  /**', start)
s = s[:start] + '''  async whenReady(): Promise<void> {
    await this.readyPromise;
    if (this.destroyed) throw new Error('AUDIO_SESSION_ENDED');
    if (this.initError) throw new Error('AUDIO_INITIALIZATION_FAILED');
    if (!this.audioRenderer || !this.audioCapturer) throw new Error('AUDIO_RESOURCES_NOT_READY');
  }
''' + s[end:]
anchor = '      if (active !== enable) throw new Error(\'AUDIO_ROUTE_NOT_APPLIED\');'
if s.count(anchor) != 1:
    raise SystemExit('Stage RTC controls first; unexpected route source.')
s = s.replace(anchor, '''      if (this.destroyed || AudioSwitchManager.instance !== this || this.activeCount <= 0) {
        throw new Error('AUDIO_SESSION_ENDED');
      }
''' + anchor)
p.write_text(s, encoding='utf-8')
print('Harmony audio readiness and late route acknowledgement checks staged.')
