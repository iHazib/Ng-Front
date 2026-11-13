import { defineConfig, globalIgnores } from 'eslint/config';
import nextPlugin from '@next/eslint-plugin-next';
import typescript from 'typescript-eslint';

export default defineConfig([
  ...typescript.configs.recommended,
  { files: ['src/**/*.{ts,tsx}'], plugins: { '@next/next': nextPlugin }, rules: {
    ...nextPlugin.configs.recommended.rules, ...nextPlugin.configs['core-web-vitals'].rules,
  } },
  // Keep the wireframe's native image sizing/framing. Optimize at the media stage.
  { files: ['src/components/storefront/**/*.tsx'], rules: { '@next/next/no-img-element': 'off' } },
  globalIgnores(['.next/**', '.tools/**', '.local/**', '.npm-cache/**', 'local-sources/**',
    'design/**', 'data/**', 'public/**', 'product-images-import/**', 'next-env.d.ts',
    'playwright-report/**', 'test-results/**']),
]);
