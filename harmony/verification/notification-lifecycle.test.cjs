// Native queue logic with a private-storage double; does not simulate OS delivery.
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const base = path.join(__dirname, '../plugins/kingclub_notification_ohos/ohos/src/main/ets');
let saved = '[]';
let fail = false;
const preferences = { getPreferences: async () => ({
  get: async () => saved,
  put: async (_, value) => { if (fail) throw Error('storage unavailable'); saved = value; },
  flush: async () => {},
}) };
function load(name) {
  const exports = {};
  const code = ts.transpileModule(fs.readFileSync(path.join(base, name + '.ets'), 'utf8'),
    { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
  vm.runInNewContext(code, { exports, Date, JSON, Number, Array, Promise,
    require: id => id === '@ohos.data.preferences' ? { default: preferences } : load('NotificationEnvelope') });
  return exports;
}
const raw = n => JSON.stringify({version: 1, eventId: `12345678-1234-1234-1234-${String(n).padStart(12,'0')}`,
  recipient: 'KM123', target: 'KM456', scope: 'direct', kind: 'message', expiresAt: Date.now()+60000});
(async () => {
  let lifecycle = load('NotificationLifecycle').NotificationLifecycle;
  const first = raw(1);
  lifecycle.accept({}, {parameters: {kingclub_push: first}});
  lifecycle.accept({}, {parameters: {kingclub_push: first}});
  assert.equal(await lifecycle.pending({}), first);
  assert.equal(JSON.parse(saved).length, 1);
  assert.equal(await lifecycle.pending({}, raw(2)), first); // wrong ack cannot drop the head
  lifecycle = load('NotificationLifecycle').NotificationLifecycle; // process/engine recreation
  assert.equal(await lifecycle.pending({}), first);
  assert.equal(await lifecycle.pending({}, first), null);
  for (let n=1;n<=10;n++) lifecycle.accept({}, {parameters: {kingclub_push: raw(n)}});
  await lifecycle.pending({});
  assert.equal(JSON.parse(saved).length, 8);
  const before = saved;
  fail = true;
  await assert.rejects(() => lifecycle.pending({}));
  assert.equal(saved, before);
  fail = false;
  assert.ok(await lifecycle.pending({}));
  saved = '["bad"]';
  assert.equal(await lifecycle.pending({}), null);
  console.log('Lifecycle queue passed: deduplication, exact ack, recreation, capacity, failed storage, corruption.');
})().catch(error => { console.error(error); process.exitCode = 1; });
