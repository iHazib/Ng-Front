import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { registerHooks } from 'node:module';
import { resolveMedia } from '../src/lib/catalog/media.ts';
import { boundedImageBody, signParameters, validateCloudMetadata, validateImageBytes, verifyCloudImage, sha256 } from '../src/lib/server/media/cloudinary.ts';

const publicId = 'nook-glow/development/12345678-1234-1234-1234-123456789012';
const bytes = Buffer.from('89504e470d0a1a0a', 'hex');
const metadata = { asset_id: 'synthetic-id', public_id: publicId, resource_type: 'image', type: 'upload', version: 1, width: 1, height: 1, format: 'png', bytes: bytes.length };
registerHooks({ resolve(specifier, context, next) {
  try { return next(specifier, context); }
  catch (error) { if (specifier.startsWith('.') && context.parentURL?.includes('/src/lib/server/')) return next(`${specifier}.ts`, context); throw error; }
} });
test('signature covers sorted parameters and prevents parameter substitution', () => {
  const signed = signParameters({ timestamp: '123', overwrite: 'false', public_id: 'fixture' }, 'synthetic-secret');
  assert.equal(signed, createHash('sha256').update('overwrite=false&public_id=fixture&timestamp=123synthetic-secret').digest('hex'));
  assert.notEqual(signed, signParameters({ timestamp: '123', overwrite: 'true', public_id: 'fixture' }, 'synthetic-secret'));
});
test('rejects SVG/non-image and oversized input', () => {
  assert.equal(validateImageBytes(bytes), 'png');
  assert.throws(() => validateImageBytes(Buffer.from('<svg/>')));
  assert.throws(() => validateImageBytes(new Uint8Array(10485761)));
});
test('metadata rejects mismatched identity, content type, excessive pixels and animation', () => {
  assert.equal(validateCloudMetadata(metadata, publicId, bytes.length).asset_id, 'synthetic-id');
  for (const patch of [{ public_id: 'other' }, { resource_type: 'raw' }, { type: 'authenticated' }, { format: 'svg' }, { width: 12001 }, { width: 10000, height: 10000 }, { pages: 2 }, { bytes: 100 }]) {
    assert.throws(() => validateCloudMetadata({ ...metadata, ...patch }, publicId, bytes.length));
  }
});
test('provider verification requires Admin API metadata plus exact original bytes (mock transport)', async () => {
  const originalFetch = globalThis.fetch;
  const names = ['CLOUDINARY_CLOUD_NAME','CLOUDINARY_API_KEY','CLOUDINARY_API_SECRET','MEDIA_ENVIRONMENT'];
  const previous = names.map(name => process.env[name]);
  Object.assign(process.env, { CLOUDINARY_CLOUD_NAME: 'synthetic-cloud', CLOUDINARY_API_KEY: 'fake', CLOUDINARY_API_SECRET: 'fake', MEDIA_ENVIRONMENT: 'development' });
  try {
    globalThis.fetch = async url => String(url).includes('api.cloudinary.com') ? Response.json(metadata) : new Response(bytes);
    assert.equal((await verifyCloudImage(publicId, sha256(bytes), bytes.length)).sha256, sha256(bytes));
    globalThis.fetch = async url => String(url).includes('api.cloudinary.com') ? Response.json(metadata) : new Response(Buffer.from('tampered'));
    await assert.rejects(verifyCloudImage(publicId, sha256(bytes), bytes.length));
    await assert.rejects(verifyCloudImage(publicId.replace('development','production'), sha256(bytes), bytes.length));
  } finally {
    globalThis.fetch = originalFetch;
    names.forEach((name,i) => { if (previous[i] === undefined) delete process.env[name]; else process.env[name] = previous[i]; });
  }
});
test('response body limit enforced', async () => {
  await assert.rejects(boundedImageBody(new Response(new Uint8Array(10485761))));
});
test('resolver preserves preview URL and generates versioned responsive delivery with explicit crops', () => {
  assert.deepEqual(resolveMedia({ source: { kind: 'local-preview', path: '/assets/test.png' }, alt: 'preview' }), { src: '/assets/test.png', alt: 'preview' });
  const media = { source: { kind: 'cloudinary', cloudName: 'test-cloud', publicId, version: 1, format: 'png', publication: 'published', width: 800, height: 600 }, alt: 'fixture' };
  assert.match(resolveMedia(media).srcSet, /c_limit,w_320,f_auto,q_auto/);
  assert.match(resolveMedia(media).srcSet, /w_800,f_auto,q_auto\/.* 800w$/);
  assert.doesNotMatch(resolveMedia(media).srcSet, /1600w/);
  const tiny = { ...media, source: { ...media.source, width: 1, height: 1 } };
  assert.match(resolveMedia(tiny, { widths: [160, 320, 640], sizes: '120px' }).srcSet, /w_1,f_auto,q_auto\/.* 1w$/);
  assert.match(resolveMedia(media, { crop: 'fill', aspectRatio: 1, widths: [400] }).src, /c_fill,g_center,w_400,h_400/);
  assert.throws(() => resolveMedia(media, { crop: 'fill' }));
  assert.throws(() => resolveMedia({ ...media, source: { ...media.source, publication: 'draft' } }));
});

test('cleanup confirms Storage metadata instead of cached downloads and refuses surviving objects (mock transport)', async () => {
  const { cleanupOrphanMedia } = await import('../src/lib/server/media/service.ts');
  const originalFetch = globalThis.fetch;
  const config = { CLOUDINARY_CLOUD_NAME: 'synthetic-cloud', CLOUDINARY_API_KEY: 'fake', CLOUDINARY_API_SECRET: 'fake', MEDIA_ENVIRONMENT: 'development', NEXT_PUBLIC_SUPABASE_URL: 'https://synthetic.invalid', NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: 'fake' };
  const previous = Object.fromEntries(Object.keys(config).map(name => [name,process.env[name]]));
  Object.assign(process.env,config);
  const id='12345678-1234-1234-1234-123456789012';
  const workflow={private_path:`media/development/${id}/original`,expected_public_id:publicId};
  const asset={id,lifecycle:'deleting',cloudinary_asset_id:'synthetic-id',cloudinary_cloud_name:'synthetic-cloud',media_environment:'development',workflow};
  let survives=false, tombstones=0;
  try {
    globalThis.fetch=async (input,init={}) => {
      const u=new URL(String(input));
      if(u.hostname==='api.cloudinary.com')return new Response('',{status:404});
      if(u.pathname==='/auth/v1/user')return Response.json({id:'synthetic-admin'});
      if(u.pathname.endsWith('/rpc/is_admin'))return Response.json(true);
      if(u.pathname.endsWith('/media_assets'))return Response.json([asset]);
      if(u.pathname.endsWith('/media_workflows'))return Response.json([workflow]);
      if(u.pathname.endsWith('/rpc/media_workflow_action')){
        if(JSON.parse(init.body).p_action==='deleted')tombstones++;
        return Response.json(asset);
      }
      if(u.pathname==='/storage/v1/object/catalog-private' && init.method==='DELETE')return Response.json([]);
      if(u.pathname==='/storage/v1/object/list/catalog-private'){
        assert.equal(JSON.parse(init.body).search,'original');
        return Response.json(survives?[{name:'original'}]:[]);
      }
      throw new Error('Unexpected request: cached download must not be used for cleanup confirmation');
    };
    await cleanupOrphanMedia('synthetic-token',id); assert.equal(tombstones,1);
    survives=true;
    await assert.rejects(cleanupOrphanMedia('synthetic-token',id),/Private deletion not confirmed/);
    assert.equal(tombstones,1);
  } finally {
    globalThis.fetch=originalFetch;
    Object.entries(previous).forEach(([name,value])=>{if(value===undefined)delete process.env[name];else process.env[name]=value;});
  }
});
