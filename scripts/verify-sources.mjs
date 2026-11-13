import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const contract = JSON.parse(readFileSync('docs/source-contract.json', 'utf8'));
for (const [path, hash] of Object.entries(contract)) {
  if (createHash('sha256').update(readFileSync(path)).digest('hex') !== hash) throw new Error(`Source changed: ${path}`);
}
execFileSync(process.execPath, ['scripts/extract-reference.mjs', '--check'], { stdio: 'inherit' });
console.log(`All ${Object.keys(contract).length} original handoff/import files remain byte-identical.`);
