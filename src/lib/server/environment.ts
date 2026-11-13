import 'server-only';
import { siteUrl } from '@/lib/seo/site';

export function getEnvironment() {
  const environment = process.env.APP_ENV || (process.env.NODE_ENV === 'development' ? 'development' : 'staging');
  if (!['development', 'staging', 'production'].includes(environment)) throw new Error('Invalid APP_ENV');
  const domain = siteUrl();
  return { environment, domain };
}
