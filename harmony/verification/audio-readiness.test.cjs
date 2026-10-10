// Execute staged ArkTS methods with SDK promises controlled by the test.
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const source = fs.readFileSync(process.argv[3]+'/audio/AudioSwitchManager.ets','utf8');
const start = source.indexOf('  async whenReady():');
assert.ok(start >= 0);
const method = source.slice(start,source.indexOf('\n  /**',start));
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(`export class Manager {
  readyPromise=Promise.resolve(); destroyed=false; initError=null;
  audioRenderer={}; audioCapturer={}; ${method}
}`,{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{exports:exportsObject});
(async()=>{
  const m = new exportsObject.Manager();
  await m.whenReady();
  for (const key of ['audioRenderer','audioCapturer']) {
    m[key]=null; await assert.rejects(m.whenReady(),/AUDIO_RESOURCES_NOT_READY/);m[key]={};
  }
  let release;
  m.readyPromise=new Promise(r=>release=r);
  const pending=m.whenReady();m.initError=Error('private SDK detail');release();
  await assert.rejects(pending,/^Error: AUDIO_INITIALIZATION_FAILED$/);
  m.initError=null;
  m.readyPromise=new Promise(r=>release=r);
  const disposed=m.whenReady();m.destroyed=true;release();
  await assert.rejects(disposed,/AUDIO_SESSION_ENDED/);
  const fresh=new exportsObject.Manager();await fresh.whenReady();
  console.log('Audio readiness passed: resources absent, async failure, disposal during init, new instance.');
})().catch(e=>{console.error(e);process.exitCode=1;});
