import { readFileSync, writeFileSync, mkdirSync, existsSync, unlinkSync } from 'node:fs';
import { resolve } from 'node:path';

const marker = '// Generated development-only reference route.';

export function prepareDevelopmentReference(development) {
  const target = resolve('src/app/reference/route.ts');
  if (existsSync(target) && !readFileSync(target, 'utf8').startsWith(marker)) {
    throw new Error('Refusing to replace an unrecognized reference route.');
  }
  if (!development) {
    if (existsSync(target)) unlinkSync(target);
    return;
  }
  mkdirSync(resolve('src/app/reference'), { recursive: true });
  const code = readFileSync(resolve('tooling/reference-route.ts'), 'utf8');
  writeFileSync(target, `${marker}\n${code}`);
}
