import 'server-only';
import { createHash, timingSafeEqual } from 'node:crypto';

function equal(left: string, right: string) {
  return timingSafeEqual(createHash('sha256').update(left).digest(), createHash('sha256').update(right).digest());
}

export function previewAccess(authorization: string | null): 'allowed' | 'unauthorized' | 'unconfigured' {
  // Only `next dev` in a development environment gets credential-free access.
  // The dev script binds to loopback. Setting APP_ENV=development cannot bypass a build.
  if (process.env.NODE_ENV === 'development' && (!process.env.APP_ENV || process.env.APP_ENV === 'development')) return 'allowed';
  const username = process.env.PREVIEW_USERNAME;
  const password = process.env.PREVIEW_PASSWORD;
  if (!username || username.includes(':') || !password || password.length < 32) return 'unconfigured';
  if (!authorization?.startsWith('Basic ')) return 'unauthorized';
  const supplied = Buffer.from(authorization.slice(6), 'base64').toString('utf8');
  return equal(supplied, `${username}:${password}`) ? 'allowed' : 'unauthorized';
}
