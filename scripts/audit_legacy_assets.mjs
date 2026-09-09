// Read-only, bounded-memory inventory. Never executes SQL or exports row values.
// Usage: node scripts/audit_legacy_assets.mjs sql INPUT OUTPUT.json
import { createReadStream, writeFileSync, mkdirSync, statSync } from 'node:fs';
import { dirname, basename, resolve } from 'node:path';
import { createHash } from 'node:crypto';

const [mode, inputArg, outputArg] = process.argv.slice(2);
if (mode !== 'sql' || !inputArg || !outputArg) throw new Error('Expected sql INPUT OUTPUT.json');
const input = resolve(inputArg);
const output = resolve(outputArg);
if (input === output || !output.endsWith('.json')) throw new Error('Output must be a separate JSON file');
const maxLine = 1024 * 1024;
const hash = createHash('sha256');
const result = { source: basename(input), bytes: statSync(input).size, sha256: '',
  limitations: ['INSERT statements are not row counts', 'Only structural identifiers are exported',
    'Routine dependencies are lexical candidates, not a complete SQL dependency graph'],
  lines: 0, cappedLines: 0, tables: [], routines: [], views: [], triggers: [], events: [],
  insertStatements: {}, interfaces: [], interfaceCategories: [], skippedInterfaceLines: 0, header: {} };
let table;
let routine;
const tableMap = new Map();
// Only s_interface metadata is inspected. No arbitrary business rows are parsed.
function metadataRows(line) {
  const values = line.slice(line.indexOf('VALUES') + 6);
  const rows = [];
  let row; let value = ''; let quoted = false;
  for (let i = 0; i < values.length; i++) {
    const ch = values[i];
    if (quoted) {
      if (ch === '\\') { value += values[++i] ?? ''; }
      else if (ch === "'" && values[i + 1] === "'") { value += "'"; i++; }
      else if (ch === "'") quoted = false;
      else value += ch;
    } else if (ch === "'") quoted = true;
    else if (ch === '(' && !row) { row = []; value = ''; }
    else if (ch === ',' && row) { row.push(value.trim()); value = ''; }
    else if (ch === ')' && row) { row.push(value.trim()); rows.push(row); row = undefined; value = ''; }
    else if (row) value += ch;
  }
  if (quoted || row) throw new Error('Incomplete metadata row');
  return rows;
}
function consume(bytes, capped) {
  result.lines++;
  if (capped) result.cappedLines++;
  const line = bytes.toString('utf8').replace(/\r$/, '');
  if (/^delimiter\s+;\s*$/i.test(line)) routine = undefined;
  if (result.lines < 25) {
    const header = line.match(/^\s*(Source Server Version|Target Server Version|File Encoding|Date)\s*:\s*(.*)$/);
    if (header) result.header[header[1]] = header[2];
  }
  const insertion = line.match(/^INSERT\s+(?:IGNORE\s+)?INTO\s+`([A-Za-z0-9_]+)`/i);
  if (insertion && !routine && !table) {
    result.insertStatements[insertion[1]] = (result.insertStatements[insertion[1]] ?? 0) + 1;
    if (insertion[1] === 's_interface' || insertion[1] === 's_interface_type') {
      if (capped || !/\bVALUES\b/.test(line)) { result.skippedInterfaceLines++; return; }
      try {
        const columns = tableMap.get(insertion[1]).columns.map(c => c.name);
        for (const row of metadataRows(line)) {
          if (insertion[1] === 's_interface_type') {
            const id = row[columns.indexOf('typeId')];
            const parentId = row[columns.indexOf('parentId')];
            if (!/^S[0-9]+$/.test(id)) continue;
            result.interfaceCategories.push({ id, parentId: /^S[0-9]+$/.test(parentId) ? parentId : null,
              name: row[columns.indexOf('typename')].slice(0, 100),
              deleted: row[columns.indexOf('deleted')] === '1' });
            continue;
          }
          const id = row[columns.indexOf('interfaceId')];
          if (!/^S[0-9]+$/.test(id)) continue;
          const sql = row[columns.indexOf('interfaceSql')] ?? '';
          const category = row[columns.indexOf('interfaceType')];
          result.interfaces.push({ id, line: result.lines,
            category: /^S[0-9]+$/.test(category) ? category : null,
            identifiers: [...new Set(sql.match(/[A-Za-z_][A-Za-z0-9_]*/g) ?? [])],
            deleted: row[columns.indexOf('deleted')] === '1' });
        }
      } catch { result.skippedInterfaceLines++; }
    }
    return; // Do not inspect, retain, log, or export business row values.
  }
  const createTable = line.match(/^CREATE TABLE(?: IF NOT EXISTS)?\s+`([A-Za-z0-9_]+)`/i);
  if (createTable) {
    table = { name: createTable[1], line: result.lines, columns: [], indexes: [], foreignKeys: 0 };
    result.tables.push(table); tableMap.set(table.name, table); routine = undefined;
    return;
  }
  if (table) {
    const column = line.match(/^\s+`([A-Za-z0-9_]+)`\s+([A-Za-z]+)(\([\d, ]+\))?/);
    if (column) table.columns.push({ name: column[1], type: column[2] + (column[3] ?? ''),
      nullable: !/\bNOT NULL\b/i.test(line), unsigned: /\bunsigned\b/i.test(line) });
    if (/^\s*(PRIMARY|UNIQUE|KEY|INDEX|FULLTEXT|CONSTRAINT|FOREIGN)/i.test(line)) {
      if (/FOREIGN KEY/i.test(line)) table.foreignKeys++;
      table.indexes.push({ kind: line.trim().split(/\s/)[0],
        identifiers: [...line.matchAll(/`([A-Za-z0-9_]+)`/g)].map(m => m[1]) });
    }
    if (/^\)/.test(line)) {
      for (const [key, regex] of Object.entries({ engine: /ENGINE\s*=\s*(\w+)/i,
        charset: /(?:CHARSET|CHARACTER SET)\s*=\s*(\w+)/i, collation: /COLLATE\s*=\s*(\w+)/i })) {
        table[key] = line.match(regex)?.[1] ?? null;
      }
      table = undefined;
    }
    return;
  }
  const object = line.match(/^CREATE\b.*?\b(PROCEDURE|FUNCTION|VIEW|TRIGGER|EVENT)\s+`([A-Za-z0-9_]+)`/i);
  if (object) {
    const kind = object[1].toLowerCase();
    const item = { name: object[2], line: result.lines, kind, references: [], symbols: [] };
    if (kind === 'trigger') item.target = line.match(/\bON\s+`([A-Za-z0-9_]+)`/i)?.[1] ?? null;
    const list = kind === 'procedure' || kind === 'function' ? result.routines : result[kind + 's'];
    list.push(item); routine = item;
  }
  if (routine) {
    for (const match of line.matchAll(/\b([A-Za-z_][A-Za-z0-9_]*)\s*\(/g)) {
      if (!routine.symbols.includes(match[1])) routine.symbols.push(match[1]);
    }
    for (const match of line.matchAll(/\b(?:FROM|JOIN|UPDATE|INTO|CALL)\s+`?([A-Za-z_][A-Za-z0-9_]*)`?/gi)) {
      if (!routine.references.includes(match[1])) routine.references.push(match[1]);
    }
  }
}
let pending = [];
let pendingBytes = 0;
let capped = false;
for await (const chunk of createReadStream(input, { highWaterMark: 4 * 1024 * 1024 })) {
  hash.update(chunk);
  let start = 0;
  while (start < chunk.length) {
    const newline = chunk.indexOf(10, start);
    const end = newline < 0 ? chunk.length : newline;
    const remaining = maxLine - pendingBytes;
    if (end - start > remaining) capped = true;
    if (remaining > 0) {
      const piece = chunk.subarray(start, Math.min(end, start + remaining));
      pending.push(piece); pendingBytes += piece.length;
    }
    if (newline < 0) break;
    consume(pending.length === 1 ? pending[0] : Buffer.concat(pending, pendingBytes), capped);
    pending = []; pendingBytes = 0; capped = false; start = newline + 1;
  }
}
if (pendingBytes || capped) consume(Buffer.concat(pending, pendingBytes), capped);
result.sha256 = hash.digest('hex');
const routineNames = new Set(result.routines.map(item => item.name));
for (const item of [...result.routines, ...result.triggers, ...result.views, ...result.events]) {
  item.tableReferences = item.references.filter(name => tableMap.has(name));
  item.routineCalls = item.symbols.filter(name => name !== item.name && routineNames.has(name));
  delete item.references;
  delete item.symbols;
}
for (const item of result.interfaces) {
  item.tables = item.identifiers.filter(name => tableMap.has(name));
  item.routines = item.identifiers.filter(name => routineNames.has(name));
  delete item.identifiers;
}
mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, JSON.stringify(result, null, 2) + '\n');
// Output a compact structural summary only.
console.log(JSON.stringify({ source: result.source, bytes: result.bytes, sha256: result.sha256,
  header: result.header, lines: result.lines, cappedLines: result.cappedLines,
  tables: result.tables.length, kingclubTables: result.tables.filter(t => t.name.startsWith('k_')).length,
  routines: result.routines.length, views: result.views.length, triggers: result.triggers.length,
  events: result.events.length, tablesWithInserts: Object.keys(result.insertStatements).length,
  interfaces: result.interfaces.length, skippedInterfaceLines: result.skippedInterfaceLines }));
