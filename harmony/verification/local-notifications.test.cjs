const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const base = path.join(__dirname, '../plugins/kingclub_notification_ohos/ohos/src/main/ets');
const lifecycle = {foreground: false, epoch: 0};
let enabled = true, published = 0, cancelled = 0, badge = -1, duringPublish = () => {};
const manager = { SlotType: {SOCIAL_COMMUNICATION: 1}, ContentType: {NOTIFICATION_CONTENT_BASIC_TEXT: 0},
  getActiveNotifications: async () => [], cancel: async () => {cancelled++;},
  setBadgeNumber: async n => {badge=n;}, isNotificationEnabled: async () => enabled,
  addSlot: async () => {}, getSlot: async () => ({enabled: true}),
  publish: async value => { published++; assert.equal(value.content.normal.text,'你收到了一条新消息'); duringPublish(); },
};
function load(name) {
  const exports = {};
  const code = ts.transpileModule(fs.readFileSync(path.join(base,name+'.ets'),'utf8'),
    {compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText;
  vm.runInNewContext(code, {exports, Date, JSON, Number, Array, Promise,
    require: id => id === './NotificationLifecycle' ? {NotificationLifecycle: lifecycle} :
      id === './NotificationEnvelope' ? load('NotificationEnvelope') :
      id === '@ohos.app.ability.wantAgent' ? {default:{getWantAgent: async () => ({}), OperationType:{START_ABILITY:0},WantAgentFlags:{UPDATE_PRESENT_FLAG:0}}} :
      {default:manager}});
  return exports;
}
const plugin = new (load('LocalNotifications').LocalNotifications)();
plugin.context = {abilityInfo:{bundleName:'com.lingmei.kingclub',name:'EntryAbility'}};
const call = (method,args={}) => new Promise((resolve,reject) => plugin.onMethodCall({method,argument:key=>args[key]},
  {success:resolve,error:code=>reject(Error(code)),notImplemented:()=>reject(Error('not implemented'))}));
const envelope = kind => JSON.stringify({version:1,eventId:'12345678-1234-1234-1234-123456789012',recipient:'KM1',target:'KM2',scope:'direct',kind,expiresAt:Date.now()+60000});
(async () => {
  await call('badge',{count:12});
  await call('bind',{session:'a'});
  assert.equal(badge,12); // initial message binding must not erase aggregate badge
  assert.equal(await call('show',{session:'wrong',destination:envelope('message')}),false);
  lifecycle.foreground=true;
  assert.equal(await call('show',{session:'a',destination:envelope('message')}),false);
  lifecycle.foreground=false; enabled=false;
  assert.equal(await call('show',{session:'a',destination:envelope('message')}),false);
  enabled=true;
  assert.equal(await call('show',{session:'a',destination:envelope('call')}),false);
  assert.equal(published,0);
  assert.equal(await call('show',{session:'a',destination:envelope('message')}),true);
  duringPublish=()=>{lifecycle.epoch++;};
  assert.equal(await call('show',{session:'a',destination:envelope('message')}),false);
  assert.equal(cancelled,1);
  await call('bind',{session:null});
  assert.equal(badge,0);
  assert.equal(await call('show',{session:'a',destination:envelope('message')}),false);
  console.log('Local delivery passed: session, foreground, denied permission, unsupported calls, lifecycle race, badge reset.');
})().catch(error=>{console.error(error);process.exitCode=1;});
