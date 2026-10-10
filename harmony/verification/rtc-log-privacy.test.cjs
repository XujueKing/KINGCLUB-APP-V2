const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const {execFileSync} = require('node:child_process');
const assert = require('node:assert/strict');
const temp = fs.mkdtempSync(path.join(os.tmpdir(),'kingclub-rtc-privacy-'));
const base = path.join(temp,'native_plugins/flutter_webrtc/ohos/src/main/ets');
fs.mkdirSync(base,{recursive:true});
const stage = path.resolve(__dirname,'../../scripts/stage-harmony-rtc-log-privacy.cjs');
const file = path.join(base,'Fixture.ets');
fs.writeFileSync(file, 'const payload = "synthetic-sdp";\nLog.d("tag", `offer ${payload}`);\nif (true) Log.e("tag", JSON.stringify({credential:"fake"}));\nconst keep = payload;');
const run = () => execFileSync(process.execPath,[stage,process.argv[2],temp],{encoding:'utf8',stdio:['ignore','pipe','pipe']});
try {
  assert.equal(JSON.parse(run()).staticEvents,2);
  const result=fs.readFileSync(file,'utf8');
  assert.ok(result.includes('const keep = payload;'));
  assert.ok(!result.includes('JSON.stringify'));
  assert.ok(!result.includes('offer ${payload}'));
  assert.equal(JSON.parse(run()).staticEvents,0);
  fs.appendFileSync(file,'\nconsole.log(payload);');
  assert.throws(run);
  console.log('RTC privacy tests passed: dynamic payloads removed, non-log code preserved, idempotent, direct logging rejected.');
} finally { fs.rmSync(temp,{recursive:true,force:true}); }
