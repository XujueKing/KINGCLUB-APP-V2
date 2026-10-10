const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]);
const source=fs.readFileSync(require('node:path').join(__dirname,'CallBackgroundLease.ets.template'),'utf8').replace(/^import .*;\r?\n/gm,'');
let starts=0,stops=0,blocked,fail=false,listener=null,taskId=0;
const backgroundTaskManager={
 on(event,cb){assert.equal(event,'continuousTaskCancel');assert.equal(listener,null);listener=cb;},
 off(event,cb){if(listener===cb)listener=null;},
 async startBackgroundRunning(context,modes){
  assert.equal(modes.join(','),'voip');starts++;const current=++taskId;
  if(blocked)await blocked;if(fail)throw Error('denied');
  return {continuousTaskId:current};
 },
 async stopBackgroundRunning(){stops++;}
};
const tick=()=>new Promise(r=>setTimeout(r,0));
const exportsObject={};
vm.runInNewContext(ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{exports:exportsObject,backgroundTaskManager,wantAgent:{async getWantAgent(){return {};},OperationType:{START_ABILITY:1},WantAgentFlags:{UPDATE_PRESENT_FLAG:1}}});
const id='11111111-1111-4111-8111-111111111111';
const call=(lease,method)=>new Promise(resolve=>lease.onMethodCall({method,argument:()=>id},{success:()=>resolve(true),error:()=>resolve(false),notImplemented:()=>resolve(false)}));
const context={abilityInfo:{bundleName:'test',name:'EntryAbility'}};
(async()=>{
 const lease=new exportsObject.CallBackgroundLease();lease.context=context;
 assert.equal(await call(lease,'start'),true);assert.equal(await call(lease,'start'),true);assert.equal(starts,1);
 assert.equal(await call(lease,'stop'),true);assert.equal(await call(lease,'stop'),true);assert.equal(stops,1);
 fail=true;assert.equal(await call(lease,'start'),false);fail=false;
 let release;blocked=new Promise(r=>release=r);
 const pending=call(lease,'start');await new Promise(r=>setTimeout(r,0));
 const closing=call(lease,'stop');release();assert.equal(await pending,false);assert.equal(await closing,true);blocked=null;
 assert.equal(stops,2);
 blocked=new Promise(r=>release=r);const detached=call(lease,'start');await new Promise(r=>setTimeout(r,0));lease.detach();release();assert.equal(await detached,false);blocked=null;
 assert.equal(await call(lease,'start'),false);assert.equal(stops,3);
 assert.equal(listener,null);
 const active=new exportsObject.CallBackgroundLease();active.context=context;
 const lost=[];active.lost=value=>lost.push(value);
 assert.equal(await call(active,'start'),true);
 listener({id:taskId+99});assert.equal(lost.length,0);
 const old=listener;old({id:taskId});assert.deepEqual(lost,[id]);assert.equal(listener,null);
 old({id:taskId});assert.equal(lost.length,1);
 assert.equal(await call(active,'stop'),true);
 assert.equal(await call(active,'start'),true);
 old({id:taskId-1});old({id:taskId});assert.equal(lost.length,1);
 await call(active,'stop');assert.equal(listener,null);assert.equal(lost.length,1);
 blocked=new Promise(r=>release=r);const early=call(active,'start');await tick();
 listener({id:taskId});release();assert.equal(await early,false);blocked=null;
 assert.equal(lost.length,2);assert.equal(listener,null);
 assert.equal(await call(active,'start'),true);await call(active,'stop');
 console.log('Call lease tests passed: lifecycle, unrelated/stale/duplicate cancellation, active cancellation, cancellation during start, restart.');
})().catch(e=>{console.error(e);process.exitCode=1;});
