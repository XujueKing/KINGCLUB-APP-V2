"""Correct native async acknowledgements only in the isolated Harmony package."""
from pathlib import Path
import sys
repo = Path(__file__).resolve().parent.parent
root = Path(sys.argv[1]).resolve()
if root == repo or repo in root.parents:
    raise SystemExit('Use an isolated Harmony application.')
base = root / 'native_plugins/flutter_webrtc/ohos/src/main/ets'
paths = [base/'audio/AudioSwitchManager.ets', base/'AudioMethodHandlers.ets',
         base/'GetUserMediaImpl.ets', base/'utils/CameraStateManager.ets']
a,h,g,c = [p.read_text(encoding='utf-8') for p in paths]
if 'setSpeakerChecked' in a: raise SystemExit('Already staged.')
def swap(s, old, new):
    if s.count(old) != 1: raise SystemExit('Source drift: '+old[:80])
    return s.replace(old,new)
a = swap(a, '  selectAudioOutput(deviceId: number): void {', '''  private routeBusy: boolean = false;
  async setSpeakerChecked(enable: boolean): Promise<void> {
    if (this.routeBusy) throw new Error('AUDIO_ROUTE_BUSY');
    if (!this.audioRoutingManager || this.activeCount <= 0 || AudioSwitchManager.instance !== this) {
      throw new Error('AUDIO_SESSION_INACTIVE');
    }
    this.routeBusy = true;
    try {
      await this.audioRoutingManager.setCommunicationDevice(audio.CommunicationDeviceType.SPEAKER, enable);
      if (AudioSwitchManager.instance !== this || this.activeCount <= 0) throw new Error('AUDIO_SESSION_ENDED');
      const active = await this.audioRoutingManager.isCommunicationDeviceActive(audio.CommunicationDeviceType.SPEAKER);
      if (active !== enable) throw new Error('AUDIO_ROUTE_NOT_APPLIED');
    } finally { this.routeBusy = false; }
  }

  async selectOutputChecked(deviceId: number): Promise<void> {
    const device = this.getAudioOutputDevices()?.find((d: audio.AudioDeviceDescriptor) => d.id === deviceId);
    if (!device) throw new Error('AUDIO_DEVICE_UNAVAILABLE');
    if (device.deviceType === audio.DeviceType.SPEAKER) {
      await this.setSpeakerChecked(true);
    } else if (device.deviceType === audio.DeviceType.EARPIECE) {
      const external = this.getAudioOutputDevices()?.some((d: audio.AudioDeviceDescriptor) =>
        d.deviceType !== audio.DeviceType.SPEAKER && d.deviceType !== audio.DeviceType.EARPIECE);
      if (external) throw new Error('USE_SYSTEM_AUDIO_PICKER');
      await this.setSpeakerChecked(false);
    } else {
      throw new Error('USE_SYSTEM_AUDIO_PICKER');
    }
  }

  selectAudioOutput(deviceId: number): void {''')
for expr, checked in [
 ('AudioSwitchManager.getExistingInstance()?.enableSpeakerphone(enable);','manager.setSpeakerChecked(enable)'),
 ('AudioSwitchManager.getExistingInstance()?.selectAudioOutput(parsedId);','manager.selectOutputChecked(parsedId)'),
 ('AudioSwitchManager.getExistingInstance()?.enableSpeakerButPreferBluetooth();','manager.setSpeakerChecked(!manager.getAudioOutputDevices()?.some((d: audio.AudioDeviceDescriptor) => d.deviceType === audio.DeviceType.BLUETOOTH_SCO || d.deviceType === audio.DeviceType.WIRED_HEADSET))')]:
    h=swap(h,expr+'\n      result.success(null);', '''const manager = AudioSwitchManager.getExistingInstance();
      if (!manager) {
        this.resultError(call.method, 'Audio session is unavailable', result);
        return;
      }
      '''+checked+'''.then(() => result.success(null)).catch(() => {
        this.resultError(call.method, 'Audio route switch failed', result);
      });''')
h = "import audio from '@ohos.multimedia.audio';\n" + h
# Do not accept a partially numeric device id (e.g. "2abc").
h=h.replace('let parsedId: number = parseInt(deviceId, 10);','let parsedId: number = /^\\d+$/.test(deviceId) ? Number(deviceId) : NaN;', 1)
g=swap(g,'  switchCamera(trackId: string, result: MethodResult): void {','  async switchCamera(trackId: string, result: MethodResult): Promise<void> {')
g=swap(g,'''      this.cameraPosition = !this.cameraPosition;
      switchCamera(Number(this.cameraPosition), surfaceId, 0);
      result.success(true);''','''      const switched = await switchCamera(-1, surfaceId, 0);
      if (!switched || !this.stateProvider?.getLocalTrack(trackId) || !this.surfaceTextureEntry) {
        this.resultError('switchCamera', 'Camera switch did not complete', result);
        return;
      }
      result.success(isCameraFrontFacing());''')
g=swap(g,'  switchCamera\n', '  switchCamera,\n  isCameraFrontFacing\n')
start=c.index('export async function switchCamera(')
end=c.index('\n/**',start)
c=c[:start]+'''export function isCameraFrontFacing(): boolean {
  return getState().lastCameraDevice?.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT;
}
let switchInProgress: boolean = false;
export async function switchCamera(cameraPosition: number, surfaceId: string, foldAbleStatus: number): Promise<boolean> {
  if (switchInProgress || !surfaceId) return false;
  const state = getState();
  const devices = state.cameraManager?.getSupportedCameras();
  const previous = state.lastCameraDevice;
  if (!devices || !previous) return false;
  const oldIndex = devices.findIndex((d: camera.CameraDevice) => d.cameraId === previous.cameraId);
  const facing = previous.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT
    ? camera.CameraPosition.CAMERA_POSITION_BACK : camera.CameraPosition.CAMERA_POSITION_FRONT;
  const target = cameraPosition < 0
    ? devices.findIndex((d: camera.CameraDevice) => d.cameraPosition === facing) : cameraPosition;
  if (oldIndex < 0 || target < 0 || target >= devices.length || target === oldIndex) return false;
  switchInProgress = true;
  const context = state.currentContext;
  try {
    await releaseCamera();
    if (restoreCameraManager(context) && await configureSwitchedCamera(target, surfaceId, foldAbleStatus)) return true;
    // A failed replacement must not silently discard the previous camera.
    await releaseCamera();
    if (restoreCameraManager(context)) await configureSwitchedCamera(oldIndex, surfaceId, foldAbleStatus);
    return false;
  } catch (_) {
    return false;
  } finally { switchInProgress = false; }
}
''' + c[end:]
for p,s in zip(paths,[a,h,g,c]):p.write_text(s,encoding='utf-8')
print('Native camera/audio controls staged; media remains disabled.')
