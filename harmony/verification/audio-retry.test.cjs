const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]);
const source=fs.readFileSync(process.argv[3]+'/MethodCallHandlerImpl.ets','utf8');
const start=source.indexOf('  async initialize(call:');
const code=source.slice(start,source.indexOf('\n  /**',start));
assert.ok(code.includes('initializeAudioOnce'));
let instance=null,created=0,destroyed=0,allocations=0,fail=false,block=null;
const AudioSwitchManager={
 getInstance(){return instance??=(created++,{async createAudioDeviceModule(){allocations++;if(block)await block;if(fail)throw Error('private SDK error');}});},
 getExistingInstance(){return instance;},
 destroy(){destroyed++;instance=null;}
};
const exportsObject={};
vm.runInNewContext(ts.transpileModule(`export class Handler {
 disposed=false;getUserMediaImpl=null;stateProvider={};context={};
 resultError(method,message,result){result.error(message);}
 ${code}
}`,{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{
 exports:exportsObject,AudioSwitchManager,GetUserMediaImpl:class {},Log:{i(){}},
 getOptionsMap:call=>call.options,getOptionsNetworkIgnoreMask:()=>0,
 getOptionsForceSWCodec:()=>false,getOptionsForceSWCodecList:()=>[],getOptionsAudioConfiguration:()=>({})
});
const invoke=async(handler,options={})=>{
 let replies=0,ok,message;
 await handler.initialize({method:'initialize',options},{success(){replies++;ok=true;},error(m){replies++;ok=false;message=m;}});
 assert.equal(replies,1);if(message)assert.ok(!message.includes('private SDK'));
 return ok;
};
const tick=()=>new Promise(r=>setTimeout(r,0));
(async()=>{
 const h=new exportsObject.Handler();let release;
 assert.equal(await invoke(h,null),false);assert.equal(created,0);
 fail=true;block=new Promise(r=>release=r);
 const first=invoke(h),second=invoke(h);await tick();assert.equal(allocations,1);
 release();assert.deepEqual(await Promise.all([first,second]),[false,false]);
 assert.equal(destroyed,1);assert.equal(h.getUserMediaImpl,null);
 fail=false;block=null;assert.equal(await invoke(h),true);assert.equal(created,2);
 assert.equal(await invoke(h),true);assert.equal(allocations,2);
 instance=null;const disposedHandler=new exportsObject.Handler();block=new Promise(r=>release=r);
 const late=invoke(disposedHandler);await tick();disposedHandler.disposed=true;release();
 assert.equal(await late,false);assert.equal(disposedHandler.getUserMediaImpl,null);assert.equal(instance,null);
 const replacing=new exportsObject.Handler();block=new Promise(r=>release=r);
 const old=invoke(replacing);await tick();const replacement={marker:'new owner'};instance=replacement;
 release();assert.equal(await old,false);assert.equal(instance,replacement);assert.equal(replacing.getUserMediaImpl,null);
 console.log('Audio retry passed: invalid request, concurrent failure, clean retry, idempotency, dispose, newer owner preserved.');
})().catch(e=>{console.error(e);process.exitCode=1;});
