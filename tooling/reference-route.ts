import 'server-only';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

export const dynamic = 'force-dynamic';

export async function GET() {
  if (process.env.NODE_ENV !== 'development') return new Response(null, { status: 404 });
  const html = await readFile(resolve('design/reference/Nook_Glow_Homepage_Wireframe.html'), 'utf8');
  const manifest: { path: string; sha256: string }[] = JSON.parse(
    await readFile(resolve('design/reference/asset-manifest.json'), 'utf8'),
  );
  const paths = new Map(manifest.map((entry) => [entry.sha256, entry.path]));
  // These two embedded WebP logos decode to the exact RGBA pixels of the supplied
  // PNG assets. Keep source bytes untouched; resolve their encoding aliases here.
  const aliases: Record<string, string> = JSON.parse(
    await readFile(resolve('tooling/reference-image-aliases.json'), 'utf8'),
  );
  for (const [hash, path] of Object.entries(aliases)) {
    if (!manifest.some((entry) => entry.path === path)) throw new Error('Invalid reference alias path');
    paths.set(hash, path);
  }
  const localHtml = html.replace(/data:image\/[^;]+;base64,([A-Za-z0-9+/=]+)/g, (_, encoded: string) => {
    const hash = createHash('sha256').update(Buffer.from(encoded, 'base64')).digest('hex');
    const path = paths.get(hash);
    if (!path) throw new Error('Reference contains an image outside the verified asset contract.');
    return path;
  });
  return new Response(localHtml, { headers: {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'private, no-store',
    'X-Robots-Tag': 'noindex, nofollow, noarchive',
  } });
}
