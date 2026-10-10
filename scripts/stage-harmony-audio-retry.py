"""Allow another native initialization attempt after Harmony audio failure."""
from pathlib import Path
import sys

repo = Path(__file__).resolve().parent.parent
root = Path(sys.argv[1]).resolve()
if root == repo or repo in root.parents:
    raise SystemExit('Use an isolated Harmony application.')
p = root/'native_plugins/flutter_webrtc/ohos/src/main/ets/MethodCallHandlerImpl.ets'
s = p.read_text(encoding='utf-8')
if 'initializeAudioOnce' in s:
    raise SystemExit('Already staged.')
start = s.index('  async initialize(call:')
end = s.index('\n  /**',start)
original = s[start:end]
prefix = original[:original.index('      if (this.peerConnectionFactory)')]
replacement = prefix + '''      if (this.disposed) throw new Error('disposed');
      if (!this.getUserMediaImpl) {
        if (!this.initializingAudio) this.initializingAudio = this.initializeAudioOnce();
        const pending = this.initializingAudio;
        try { await pending; }
        finally { if (this.initializingAudio === pending) this.initializingAudio = null; }
      }
      if (this.disposed) throw new Error('disposed');
      result.success(null);
    } catch (_) {
      this.resultError(call.method, 'Audio initialization unavailable; please retry', result);
    }
  }

  private initializingAudio: Promise<void> | null = null;
  private async initializeAudioOnce(): Promise<void> {
    const manager = AudioSwitchManager.getInstance();
    try {
      await manager.createAudioDeviceModule();
      if (this.disposed || AudioSwitchManager.getExistingInstance() !== manager) {
        throw new Error('Audio initialization cancelled');
      }
      this.getUserMediaImpl = new GetUserMediaImpl(this.stateProvider, this.context);
    } catch (_) {
      if (AudioSwitchManager.getExistingInstance() === manager) AudioSwitchManager.destroy();
      throw new Error('Audio initialization failed');
    }
  }
'''
p.write_text(s[:start]+replacement+s[end:],encoding='utf-8')
(root/'test').mkdir(exist_ok=True)
(root/'test/harmony_audio_retry_test.dart').write_text(
    (repo/'harmony/verification/harmony_audio_retry_test.dart.template').read_text(encoding='utf-8'),
    encoding='utf-8')
print('Harmony initialization retry, concurrency and disposal guards staged.')
