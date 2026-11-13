import type { NextConfig } from 'next';
import { PHASE_DEVELOPMENT_SERVER } from 'next/constants';
import { prepareDevelopmentReference } from './tooling/development-reference.mjs';

export default function config(phase: string): NextConfig {
  prepareDevelopmentReference(phase === PHASE_DEVELOPMENT_SERVER);
  return {
    ...(phase===PHASE_DEVELOPMENT_SERVER&&['sample','public','deals'].includes(process.env.NG_VERIFICATION_BUILD??'')?{distDir:process.env.NG_VERIFICATION_BUILD==='sample'?'.next-sample-verification':process.env.NG_VERIFICATION_BUILD==='deals'?'.next-deals-verification':'.next-public-verification'}:{}),
    // Production/typegen validate only the freshly generated production routes.
    // Development includes the temporary /reference route in its own type output.
    typescript: { tsconfigPath: phase === PHASE_DEVELOPMENT_SERVER ? 'tsconfig.json' : 'tsconfig.build.json' },
    poweredByHeader: false,
    devIndicators: false,
    async headers() {
      return [
        { source: '/:path*', headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'no-referrer' },
        ] },
        { source: '/admin/:path*', headers: [
          { key: 'X-Robots-Tag', value: 'noindex, nofollow, noarchive' },
        ] },
        { source: '/api/:path*', headers: [
          { key: 'X-Robots-Tag', value: 'noindex, nofollow, noarchive' },
        ] },
      ];
    },
  };
}
