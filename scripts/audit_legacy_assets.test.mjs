import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

// Synthetic fixtures only, kept in ignored local cache. No database connection.
const cache = resolve('.dart_tool');
mkdirSync(cache, { recursive: true });
const directory = mkdtempSync(join(cache, 'product-inventory-test-'));
function audit(source, name) {
  const input = join(directory, name + '.sql');
  const output = join(directory, name + '.json');
  writeFileSync(input, source);
  execFileSync(process.execPath, ['scripts/audit_legacy_assets.mjs', 'sql', input, output]);
  return { data: JSON.parse(readFileSync(output, 'utf8')), raw: readFileSync(output, 'utf8') };
}
const fixture = `/*
 Source Server Version : 50727 (synthetic)
 Date: synthetic-date
*/
CREATE TABLE \`k_user\` (
  \`rowId\` int(11) NOT NULL,
  \`privateField\` varchar(255) DEFAULT NULL,
  PRIMARY KEY (\`rowId\`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
INSERT INTO \`k_user\` VALUES (1, 'SENSITIVE-ROW-MARKER');
CREATE TABLE \`s_interface\` (
  \`interfaceId\` varchar(255) NOT NULL,
  \`interfaceType\` varchar(255) NOT NULL,
  \`interfaceSql\` longtext NOT NULL,
  \`deleted\` tinyint(1) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
INSERT INTO \`s_interface\` VALUES ('S100000000001', 'S200000000001', 'CALL K_Read(); SELECT \\'SENSITIVE-SQL-MARKER\\';', 0), ('S100000000002','S200000000001','SELECT * FROM k_user',0);
CREATE TABLE \`s_interface_type\` (
  \`typeId\` varchar(255) NOT NULL,
  \`typename\` varchar(255) NOT NULL,
  \`parentId\` varchar(255),
  \`deleted\` tinyint(1) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
INSERT INTO \`s_interface_type\` VALUES ('S200000000001','App','0',0);
delimiter ;;
CREATE PROCEDURE \`K_Read\`()
BEGIN
INSERT INTO \`k_user\` VALUES (2, 'SENSITIVE-ROUTINE-MARKER');
SELECT K_Helper() FROM k_user;
END;;
delimiter ;
delimiter ;;
CREATE FUNCTION \`K_Helper\`() RETURNS INT
BEGIN
RETURN 1;
END;;
delimiter ;
`;

test('extracts only structural metadata, categories and dependencies; hashes the whole input', () => {
  const { data, raw } = audit(fixture, 'metadata');
  assert.equal(data.sha256, createHash('sha256').update(fixture).digest('hex'));
  assert.equal(data.header['Source Server Version'], '50727 (synthetic)');
  assert.equal(data.insertStatements.k_user, 1); // Excludes INSERT inside a Routine.
  assert.equal(data.interfaces.length, 2);
  assert.deepEqual(data.interfaces[0].routines, ['K_Read']);
  assert.deepEqual(data.interfaces[1].tables, ['k_user']);
  assert.equal(data.interfaces[0].category, 'S200000000001');
  assert.equal(data.interfaceCategories[0].name, 'App');
  assert.deepEqual(data.routines[0].routineCalls, ['K_Helper']);
  assert.deepEqual(data.routines[0].tableReferences, ['k_user']);
  assert.equal(data.tables[0].columns[1].nullable, true);
  assert.ok(!raw.includes('SENSITIVE-'));
  assert.ok(!raw.includes('interfaceSql":'));
});

test('caps a huge data line without exporting values or losing following structure', () => {
  const source = fixture + "INSERT INTO `k_user` VALUES (3, '" + 'x'.repeat(1024 * 1024 + 100) + "');\n";
  const { data, raw } = audit(source, 'bounded');
  assert.equal(data.cappedLines, 1);
  assert.equal(data.insertStatements.k_user, 2);
  assert.equal(data.tables.length, 3);
  assert.ok(raw.length < 15000);
  assert.equal(data.sha256, createHash('sha256').update(source).digest('hex'));
});

test('rejects incomplete interface metadata without exporting partial SQL', () => {
  const { data, raw } = audit(fixture + "INSERT INTO `s_interface` VALUES ('S100000000003', 'S200000000001', 'unterminated\n", 'incomplete');
  assert.equal(data.skippedInterfaceLines, 1);
  assert.equal(data.interfaces.length, 2);
  assert.ok(!raw.includes('unterminated'));
});
