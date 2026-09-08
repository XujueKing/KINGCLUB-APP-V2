import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export function checkRepositoryContent(
  repositoryRoot,
  { maxFileBytes = 10 * 1024 * 1024, maxSnapshotBytes = 100 * 1024 * 1024 } = {},
) {
  for (const budget of [maxFileBytes, maxSnapshotBytes]) {
    if (!Number.isSafeInteger(budget) || budget <= 0) {
      throw new Error('Repository size budgets must be positive safe integers.');
    }
  }

  const git = (args) => execFileSync('git', ['-C', repositoryRoot, ...args], {
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
  const ignoredTracked = git([
    'ls-files', '--cached', '--ignored', '--exclude-standard', '-z',
  ]).split('\0').filter(Boolean);
  if (ignoredTracked.length > 0) {
    throw new Error(`Ignored files are staged or tracked. Remove them from the index, not the working directory:\n${ignoredTracked.join('\n')}`);
  }

  const treeId = git(['write-tree']).trim();
  const entries = git(['ls-tree', '-r', '-l', '-z', treeId])
    .split('\0')
    .filter(Boolean)
    .map((line) => line.match(/^\d+\s+blob\s+\w+\s+(\d+)\t([\s\S]+)$/))
    .filter(Boolean)
    .map((match) => ({ path: match[2], bytes: Number(match[1]) }));
  const oversized = entries.filter((entry) => entry.bytes > maxFileBytes);
  if (oversized.length > 0) {
    throw new Error(`Files exceed the ${maxFileBytes} byte budget:\n${oversized.map((entry) => entry.path).join('\n')}`);
  }

  const totalBytes = entries.reduce((total, entry) => total + entry.bytes, 0);
  if (totalBytes > maxSnapshotBytes) {
    throw new Error(`Snapshot size ${totalBytes} bytes exceeds the ${maxSnapshotBytes} byte budget.`);
  }
  return { fileCount: entries.length, totalBytes };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const repositoryRoot = process.argv[2] ?? fileURLToPath(new URL('..', import.meta.url));
    const result = checkRepositoryContent(repositoryRoot);
    console.log(`PASS: ${result.fileCount} files, ${(result.totalBytes / 1024 / 1024).toFixed(2)} MiB in the staged snapshot; no ignored files tracked.`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
