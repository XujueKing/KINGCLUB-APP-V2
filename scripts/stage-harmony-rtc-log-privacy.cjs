// Replace upstream payload logging with static event identifiers, only in OHOS.
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.argv[2]);
const root = path.resolve(process.argv[3]);
const repo = path.resolve(__dirname, '..');
if (root === repo || root.startsWith(repo + path.sep)) throw Error('Use an isolated Harmony application.');
const base = path.join(root, 'native_plugins/flutter_webrtc/ohos/src/main/ets');
const changes = [];
function visitDir(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) { visitDir(file); continue; }
    if (!entry.name.endsWith('.ets')) continue;
    const source = fs.readFileSync(file, 'utf8');
    const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
    const edits = [];
    function walk(node) {
      if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression)) {
        const owner = node.expression.expression.getText(tree);
        const method = node.expression.name.text;
        if (owner === 'console' || owner === 'hilog') throw Error('Unreviewed direct logger: ' + file);
        if (owner === 'Log') {
          if (!['d','i','w','e'].includes(method)) throw Error('Unreviewed logger method: ' + method);
          if (node.arguments.length === 2 && node.arguments.every(ts.isStringLiteral)
              && node.arguments[0].text === 'KINGCLUB_RTC'
              && /^rtc:[A-Za-z0-9_.-]+:\d+$/.test(node.arguments[1].text)) return;
          const line = tree.getLineAndCharacterOfPosition(node.getStart(tree)).line + 1;
          edits.push({start:node.getStart(tree), end:node.end,
            text:`Log.${method}('KINGCLUB_RTC', 'rtc:${entry.name}:${line}')`});
          return;
        }
      }
      ts.forEachChild(node, walk);
    }
    walk(tree);
    let result = source;
    for (const edit of edits.reverse()) result = result.slice(0,edit.start) + edit.text + result.slice(edit.end);
    if (edits.length) changes.push({file, result, count:edits.length});
  }
}
visitDir(base);
for (const change of changes) fs.writeFileSync(change.file, change.result);
console.log(JSON.stringify({files:changes.length, staticEvents:changes.reduce((n,c)=>n+c.count,0)}));
