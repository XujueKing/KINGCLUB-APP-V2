const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]);
const source=fs.readFileSync(process.argv[3]+'/TrackControlHandlers.ets','utf8');
const start=source.indexOf('  mediaStreamTrackSetEnable(call:');
const code=source.slice(start,source.indexOf('\n  /**',start));
const exportsObject={};
vm.runInNewContext(ts.transpileModule(`export class Handler {
 track=null; getTrackForId(){return this.track;}
 resultError(method,message,result){result.error(message);}
 ${code}
}`,{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{
 exports:exportsObject,getTrackId:()=> 'test-track',getPeerConnectionId:()=>''
});
const h=new exportsObject.Handler();
function invoke(enabled){
 let replies=0,ok,message;
 h.mediaStreamTrackSetEnable({method:'mediaStreamTrackSetEnable',argument:()=>enabled},
 {success(){replies++;ok=true;},error(m){replies++;ok=false;message=m;}});
 assert.equal(replies,1);assert.ok(!message?.includes('private'));
 return ok;
}
assert.equal(invoke(false),false);
for(const kind of ['audio','video']){
 let state=true,writes=0,mode='ok';
 h.track={kind,readyState:'live',get enabled(){return state;},set enabled(v){
   writes++;if(mode==='throw')throw Error('private SDK detail');
   if(mode==='ignore')return;state=v;if(mode==='end')this.readyState='ended';
 }};
 assert.equal(invoke('false'),false);assert.equal(writes,0);
 assert.equal(invoke(false),true);assert.equal(state,false);
 assert.equal(invoke(false),true);assert.equal(writes,1);
 assert.equal(invoke(true),true);assert.equal(state,true);
 mode='ignore';assert.equal(invoke(false),false);
 mode='throw';assert.equal(invoke(false),false);
 mode='end';assert.equal(invoke(false),false);
 const count=writes;assert.equal(invoke(false),false);assert.equal(writes,count);
}
console.log('Track state passed for audio/video: missing, invalid, mute/unmute, idempotent, ignored write, SDK failure, ended.');
