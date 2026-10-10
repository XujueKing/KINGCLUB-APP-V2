// Runs the staged native control algorithms with mocked SDKs, not device validation.
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const base = process.argv[3];
function run(source, context) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(source, {compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,
    {...context, exports});
  return exports;
}
(async () => {
  const src = fs.readFileSync(base+'/audio/AudioSwitchManager.ets','utf8');
  const methods = src.slice(src.indexOf('  private routeBusy:'),src.indexOf('  selectAudioOutput(deviceId:'));
  const audio = {CommunicationDeviceType:{SPEAKER:2}, DeviceType:{SPEAKER:2,EARPIECE:1}};
  const {AudioSwitchManager:M} = run(`export class AudioSwitchManager {
    static instance; activeCount=1; audioRoutingManager; devices=[{id:1,deviceType:1},{id:2,deviceType:2}];
    getAudioOutputDevices(){return this.devices;} ${methods}}`,{audio});
  const m = new M(); M.instance = m;
  let active=false, fail=false, pending, readPending, calls=[];
  m.audioRoutingManager = {
    async setCommunicationDevice(type,value){calls.push([type,value]); if(fail)throw Error('denied'); if(pending)await pending; active=value;},
    async isCommunicationDeviceActive(){if(readPending)await readPending;return active;}
  };
  await m.setSpeakerChecked(true); assert.equal(active,true);
  await m.selectOutputChecked(1); assert.deepEqual(calls.at(-1),[2,false]);
  await assert.rejects(m.selectOutputChecked(999));
  m.devices.push({id:3,deviceType:7}); await assert.rejects(m.selectOutputChecked(1));
  fail=true; await assert.rejects(m.setSpeakerChecked(true)); fail=false;
  await m.setSpeakerChecked(true);
  let release; pending=new Promise(r=>release=r);
  const first=m.setSpeakerChecked(false); await assert.rejects(m.setSpeakerChecked(true));
  release(); await first; pending=null;
  m.activeCount=0; await assert.rejects(m.setSpeakerChecked(true));
  m.activeCount=1;readPending=new Promise(r=>release=r);
  const late=m.setSpeakerChecked(true);
  await new Promise(r=>setTimeout(r,0));m.activeCount=0;release();
  await assert.rejects(late,/AUDIO_SESSION_ENDED/);readPending=null;
  m.activeCount=1;readPending=new Promise(r=>release=r);
  const replaced=m.setSpeakerChecked(false);
  await new Promise(r=>setTimeout(r,0));M.instance=new M();release();
  await assert.rejects(replaced,/AUDIO_SESSION_ENDED/);readPending=null;M.instance=m;
  await m.setSpeakerChecked(true);
  const cameraSource=fs.readFileSync(base+'/utils/CameraStateManager.ets','utf8');
  const start=cameraSource.indexOf('let cameraEpoch:');
  const releaseStart=cameraSource.indexOf('export async function releaseCamera()');
  const code=cameraSource.slice(releaseStart,cameraSource.indexOf('async function releaseCameraInternal()',releaseStart))+cameraSource.slice(start,cameraSource.indexOf('\n/**',start));
  const devices=[{cameraId:'back',cameraPosition:0},{cameraId:'front',cameraPosition:1}];
  let targets=[], success=true, wait, releases=0;
  const state={cameraManager:{getSupportedCameras:()=>devices},lastCameraDevice:devices[0],currentContext:{}};
  const facingStart=cameraSource.indexOf('export function isCameraFrontFacing()');
  const facingCode=cameraSource.slice(facingStart,start);
  const c=run(facingCode+code,{getState:()=>state,camera:{CameraPosition:{CAMERA_POSITION_FRONT:1,CAMERA_POSITION_BACK:0}},
    releaseCameraInternal:async()=>{releases++;},restoreCameraManager:()=>true,
    configureSwitchedCamera:async(index)=>{targets.push(index);if(wait)await wait;return success;}});
  assert.equal(c.isCameraFrontFacing(),false);
  state.lastCameraDevice=devices[1];assert.equal(c.isCameraFrontFacing(),true);state.lastCameraDevice=devices[0];
  assert.equal(await c.switchCamera(-1,'surface',0),true); assert.equal(targets[0],1);
  targets=[];success=false; assert.equal(await c.switchCamera(-1,'surface',0),false);assert.deepEqual(targets,[1,0]);
  const before=releases; assert.equal(await c.switchCamera(99,'surface',0),false); assert.equal(releases,before);
  success=true;wait=new Promise(r=>release=r);const switching=c.switchCamera(-1,'surface',0);
  assert.equal(await c.switchCamera(-1,'surface',0),false);release();await switching;
  wait=new Promise(r=>release=r);
  const inFlight=c.switchCamera(-1,'surface',0);
  await new Promise(r=>setTimeout(r,0));
  const stop=c.releaseCamera();
  assert.equal(await c.switchCamera(-1,'surface',0),false);
  release(); assert.equal(await inFlight,false); await stop; wait=null;
  assert.equal(await c.switchCamera(-1,'surface',0),true);
  console.log('Native controls passed: speaker on/off, errors, unavailable routes, busy protection, camera facing, rollback, invalid target.');
})().catch(e=>{console.error(e);process.exitCode=1;});
