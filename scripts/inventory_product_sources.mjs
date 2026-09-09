// Structural source inventory only. Does not execute legacy code or contact services.
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, relative, dirname } from 'node:path';
const [miniRoot, dumpPath, outputPath] = process.argv.slice(2);
if (!miniRoot || !dumpPath || !outputPath) throw new Error('Expected MINI_ROOT DUMP_INVENTORY OUTPUT.json');
const read = path => readFileSync(path, 'utf8').replace(/^\uFEFF/, '');
const dump = JSON.parse(read(dumpPath));
const app = JSON.parse(read(join(miniRoot, 'app.json')));
const routes = [...app.pages, ...(app.subPackages ?? []).flatMap(pkg => pkg.pages.map(page => `${pkg.root}/${page}`))];
const excluded = new Set(['.git', 'node_modules', 'miniprogram_npm', 'docs', 'tests', 'scripts']);
function walk(path) {
  return readdirSync(path, { withFileTypes: true }).flatMap(entry => {
    if (excluded.has(entry.name)) return [];
    const full = join(path, entry.name);
    return entry.isDirectory() ? walk(full) : /\.(js|wxml|wxss)$/.test(entry.name) ? [full] : [];
  });
}
const files = walk(miniRoot).map(path => {
  const source = read(path);
  return { path: relative(miniRoot, path).replaceAll('\\', '/'), lines: source.split('\n').length,
    ids: [...new Set(source.match(/\bS[0-9]{10,}\b/g) ?? [])].sort(),
    nativeCalls: [...new Set([...source.matchAll(/\bwx\.([A-Za-z0-9_]+)\s*\(/g)].map(m => m[1]))].sort() };
});
const sourceIds = [...new Set(files.flatMap(file => file.ids))].sort();
const byRoutine = new Map(dump.routines.map(item => [item.name, item]));
const byId = new Map(dump.interfaces.map(item => [item.id, item]));
const categories = new Map((dump.interfaceCategories ?? []).map(item => [item.id, item]));
function dependencies(names, visited = new Set()) {
  const tables = [];
  for (const name of names) {
    if (visited.has(name)) continue;
    visited.add(name);
    const routine = byRoutine.get(name);
    tables.push(...(routine?.tableReferences ?? []), ...dependencies(routine?.routineCalls ?? [], visited));
  }
  return tables;
}
const interfaces = sourceIds.map(id => {
  const meta = byId.get(id);
  const tables = [...new Set([...(meta?.tables ?? []),
    ...dependencies(meta?.routines ?? [])])].sort();
  return { id, files: files.filter(file => file.ids.includes(id)).map(file => file.path),
    foundInDump: !!meta, deletedInDump: meta?.deleted ?? null, dumpLine: meta?.line ?? null,
    category: meta?.category ?? null, categoryName: categories.get(meta?.category)?.name ?? null,
    routines: meta?.routines ?? [], kingclubTables: tables.filter(name => /^k_/i.test(name)),
    externalDependencies: tables.filter(name => !/^k_/i.test(name)) };
});
const result = { limitations: ['Lexical inventory includes static IDs in comments',
  'Dynamic menu/URL/ID dispatch and transitive Routine calls require further contract validation',
  'Non-k_ references are dependencies, never an approved migration allowlist'],
  routeCount: routes.length, sourceFiles: files.length,
  routes: routes.map(route => ({ route, files: files.filter(file => file.path.startsWith(route + '.')) })),
  interfaces, files };
mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({ routes: routes.length, sourceFiles: files.length, staticIds: sourceIds.length,
  matchedDump: interfaces.filter(item => item.foundInDump).length,
  missingIds: interfaces.filter(item => !item.foundInDump).map(item => item.id),
  externalDependencies: [...new Set(interfaces.flatMap(item => item.externalDependencies))].sort() }));
