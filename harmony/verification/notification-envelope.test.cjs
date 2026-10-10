// Executes the actual pure ArkTS envelope validator through TypeScript; not an OS integration test.
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.join(__dirname, '../plugins/kingclub_notification_ohos/ohos/src/main/ets/NotificationEnvelope.ets'), 'utf8');
const moduleExports = {};
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText,
  { exports: moduleExports, Date, JSON, Number, Array });
const normalize = moduleExports.normalizeEnvelope;
const valid = { version: 1, eventId: '12345678-1234-1234-1234-123456789012', recipient: 'KM123',
  target: 'KM456', scope: 'direct', kind: 'message', expiresAt: Date.now() + 60000 };
const check = value => normalize(JSON.stringify(value));
assert.deepEqual(JSON.parse(check(valid)), valid);
assert.deepEqual(JSON.parse(check({ ...valid, body: 'private', token: 'secret', url: 'https://private' })), valid);
for (const patch of [{version: 2}, {eventId: ''}, {recipient: '../bad'}, {target: ''}, {scope: 'unknown'},
  {kind: 'payment'}, {expiresAt: Date.now() - 1}, {expiresAt: Date.now() + 2 * 86400000},
  {expiresAt: '123'}, {scope: 'group', target: 'KM456'}]) assert.equal(check({...valid, ...patch}), null);
assert.ok(check({...valid, scope: 'group', target: valid.eventId}));
for (const raw of [undefined, null, '', 'null', '[]', '{', 'x'.repeat(2049)]) assert.equal(normalize(raw), null);
console.log('Envelope validation passed: whitelist, types, recipients, group targets, expiry, malformed input.');
