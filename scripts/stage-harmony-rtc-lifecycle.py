"""Serialize camera teardown against switching in the isolated OHOS plugin."""
from pathlib import Path
import sys

repo = Path(__file__).resolve().parent.parent
root = Path(sys.argv[1]).resolve()
if root == repo or repo in root.parents:
    raise SystemExit('Use an isolated Harmony application.')
p = root / 'native_plugins/flutter_webrtc/ohos/src/main/ets/utils/CameraStateManager.ets'
s = p.read_text(encoding='utf-8')
if 'cameraEpoch' in s or 'let switchInProgress' not in s:
    raise SystemExit('Source drift or already staged.')
s = s.replace('export async function releaseCamera(): Promise<void> {', '''export async function releaseCamera(): Promise<void> {
  if (pendingRelease) { await pendingRelease; return; }
  cameraEpoch++;
  const task = (async (): Promise<void> => {
    if (pendingSwitch) await pendingSwitch;
    await releaseCameraInternal();
  })();
  pendingRelease = task;
  try { await task; } finally { pendingRelease = undefined; }
}

async function releaseCameraInternal(): Promise<void> {''', 1)
s = s.replace('let switchInProgress: boolean = false;', '''let cameraEpoch: number = 0;
let pendingSwitch: Promise<boolean> | undefined;
let pendingRelease: Promise<void> | undefined;
let switchInProgress: boolean = false;''', 1)
signature = 'export async function switchCamera(cameraPosition: number, surfaceId: string, foldAbleStatus: number): Promise<boolean> {'
s = s.replace(signature, signature + '''
  if (pendingSwitch || pendingRelease) return false;
  const task = performCameraSwitch(cameraPosition, surfaceId, foldAbleStatus, cameraEpoch);
  pendingSwitch = task;
  try { return await task; } finally { pendingSwitch = undefined; }
}

async function performCameraSwitch(cameraPosition: number, surfaceId: string, foldAbleStatus: number,
  epoch: number): Promise<boolean> {''', 1)
start = s.index('async function performCameraSwitch(')
end = s.index('\n/**', start)
part = s[start:end].replace('await releaseCamera();', 'await releaseCameraInternal();')
part = part.replace('if (restoreCameraManager(context) && await configureSwitchedCamera(target, surfaceId, foldAbleStatus)) return true;', '''if (epoch !== cameraEpoch) return false;
    const switched = restoreCameraManager(context) && await configureSwitchedCamera(target, surfaceId, foldAbleStatus);
    if (epoch !== cameraEpoch) return false;
    if (switched) return true;''')
part = part.replace('if (restoreCameraManager(context)) await configureSwitchedCamera(oldIndex, surfaceId, foldAbleStatus);', 'if (epoch === cameraEpoch && restoreCameraManager(context)) await configureSwitchedCamera(oldIndex, surfaceId, foldAbleStatus);')
s = s[:start] + part + s[end:]
p.write_text(s, encoding='utf-8')
print('Camera switch/teardown serialization staged.')
