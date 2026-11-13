/** Opt-in real development verification. No real SKU/catalog imports. */
import { readFile, writeFile } from 'node:fs/promises';
import { parseEnv } from 'node:util';
import { registerHooks } from 'node:module';
import { randomUUID } from 'node:crypto';
import { deflateSync } from 'node:zlib';
registerHooks({ resolve(specifier, context, next) {
  try { return next(specifier, context); }
  catch (error) { if (specifier.startsWith('.') && context.parentURL?.includes('/src/lib/server/')) return next(`${specifier}.ts`, context); throw error; }
} });
for (const path of ['.env','.env.local']) {
  try { Object.assign(process.env, parseEnv(await readFile(path,'utf8'))); }
  catch (error) { if (error.code !== 'ENOENT') throw new Error('Cannot load private configuration.'); }
}
const required = ['CLOUDINARY_CLOUD_NAME','CLOUDINARY_API_KEY','CLOUDINARY_API_SECRET','MEDIA_ENVIRONMENT','NEXT_PUBLIC_SUPABASE_URL','NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY','TEST_ADMIN_EMAIL','TEST_ADMIN_PASSWORD'];
const missing = required.filter(name => !process.env[name]);
const report = { kind: 'actual_provider', status: 'pending', checks: [], missing_configuration: missing,
  real_catalog_imported: false, retained_metadata: 'If executed: archived synthetic product, media workflow/tombstone and audit records retain retry/cleanup history.' };
async function save() { await writeFile('docs/cloudinary-provider-verification.json',JSON.stringify(report,null,2)+'\n'); }
if (missing.length || !process.argv.includes('--run-development')) {
  await save(); console.log('PENDING: configure listed environment names and explicitly run with --run-development. No provider operation made.');
} else {
  if (process.env.MEDIA_ENVIRONMENT !== 'development') throw new Error('Verification requires MEDIA_ENVIRONMENT=development.');
  const url = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL);
  if (url.protocol !== 'https:' || url.username || url.password) throw new Error('Invalid test project URL.');
  let token; const productId=randomUUID(), mediaId=randomUUID(); let productCreated=false, intentCreated=false;
  report.fixture_media_id=mediaId; report.fixture_product_id=productId;
  async function http(path, method='GET', body) {
    const r = await fetch(url.origin+path,{method,headers:{ apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
      ...(token ? {Authorization:`Bearer ${token}`} : {}),'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000),redirect:'error'});
    if (!r.ok) throw new Error(`Development request failed (${r.status}).`);
    const text=await r.text();
    return text ? JSON.parse(text) : null;
  }
  function check(label,ok) { report.checks.push({check:label,result:ok?'passed':'failed'}); console.log(`${ok?'PASS':'FAIL'}: ${label}`); if(!ok) throw new Error('Verification assertion failed.'); }
  const service = await import('../src/lib/server/media/service.ts');
  const provider = await import('../src/lib/server/media/cloudinary.ts');
  try {
    const login = await http('/auth/v1/token?grant_type=password','POST',{email:process.env.TEST_ADMIN_EMAIL,password:process.env.TEST_ADMIN_PASSWORD}); token=login.access_token;
    const { authorizeAdmin }=await import('../src/lib/server/database/client.ts'); await authorizeAdmin(token); check('verified admin session',true);
    await http('/rest/v1/media_workflows?select=media_id&limit=1'); check('incremental media migration available',true);
    // Generate a genuine neutral 1px PNG, never a product photograph.
    function chunk(name,data) { const t=Buffer.concat([Buffer.from(name),data]); let crc=0xffffffff;
      for(const b of t){crc^=b;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}
      const length=Buffer.alloc(4),checksum=Buffer.alloc(4);length.writeUInt32BE(data.length);checksum.writeUInt32BE((crc^0xffffffff)>>>0);return Buffer.concat([length,t,checksum]); }
    const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(1,0);ihdr.writeUInt32BE(1,4);ihdr[8]=8;ihdr[9]=6;
    const bytes=Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr),chunk('IDAT',deflateSync(Buffer.from([0,220,220,220,255]))),chunk('IEND',Buffer.alloc(0))]);
    await http('/rest/v1/products','POST',{id:productId,name:`Synthetic media verification ${mediaId}`});productCreated=true;
    intentCreated=true;
    await service.uploadPendingMedia(token,{mediaId,productId,alt:'Synthetic neutral verification pixel'},bytes); check('private pending upload',true);
    const privateImage=await service.getPrivateReviewImage(token,mediaId);
    check('private source bytes match generated fixture',provider.sha256(privateImage.bytes)===provider.sha256(bytes));
    check('pending review has no public Cloudinary asset',await provider.lookupCloudImage(`nook-glow/development/${mediaId}`)===null);
    await service.approveMediaForPublication(token,mediaId); check('explicit private review approval',true);
    const linked=await service.publishApprovedMedia(token,mediaId); check('verified Cloudinary metadata and association',!!linked.associationId);
    const repeated=await service.publishApprovedMedia(token,mediaId);check('duplicate completion is idempotent',repeated.associationId===linked.associationId);
    const [asset]=await http(`/rest/v1/media_assets?id=eq.${mediaId}&select=*`);
    check('stored provider identity version dimensions format and lifecycle',!!asset.cloudinary_asset_id && asset.cloudinary_version>0 && asset.width===1 && asset.height===1 && asset.cloudinary_format==='png' && asset.byte_size===bytes.length && asset.content_sha256===provider.sha256(bytes) && asset.lifecycle==='linked' && asset.status==='approved');
    const associations=await http(`/rest/v1/product_media?media_id=eq.${mediaId}&select=id,is_primary,position`);
    check('one primary ordered database association after duplicate completion',associations.length===1 && associations[0].id===linked.associationId && associations[0].is_primary && associations[0].position===0);
    const {resolveMedia}=await import('../src/lib/catalog/media.ts');
    const delivery=resolveMedia({alt:asset.alt,source:{kind:'cloudinary',publication:'published',cloudName:asset.cloudinary_cloud_name,publicId:asset.cloudinary_public_id,version:asset.cloudinary_version,format:asset.cloudinary_format,width:asset.width,height:asset.height}});
    const response=await fetch(delivery.src,{signal:AbortSignal.timeout(30000),redirect:'error'});
    check('responsive image delivery',response.ok && (response.headers.get('content-type')??'').startsWith('image/'));
    let protectedAsset=false;
    try { await service.cleanupOrphanMedia(token,mediaId); } catch { protectedAsset=true; }
    check('cleanup refuses referenced asset without deleting provider image',protectedAsset && await provider.lookupCloudImage(asset.cloudinary_public_id)!==null);
    await service.detachMedia(token,mediaId);await service.cleanupOrphanMedia(token,mediaId);
    check('Cloudinary deletion confirmed',await provider.lookupCloudImage(asset.cloudinary_public_id)===null);
    const [removed]=await http(`/rest/v1/media_assets?id=eq.${mediaId}&select=lifecycle`);check('private cleanup and deletion tombstone',removed.lifecycle==='deleted');
    report.status='passed';
  } catch (error) {
    report.status='failed';
    const known=['Provider cleanup failed.','Provider cleanup not confirmed.','Provider deletion still pending; retry cleanup.','Provider identity changed; deletion blocked.','Private cleanup incomplete; retry same media UUID.','Private deletion not confirmed; retry same media UUID.','Publication incomplete; retry reconciliation with the same media UUID.'];
    report.failure_category=known.includes(error.message)?error.message:/^(Development|Database) request failed \(\d+\)\.$/.test(error.message)?error.message:'Internal verification failure; provider payload suppressed.';
    console.log('FAILED: '+report.failure_category);
  }
  finally {
    if(token && intentCreated && report.status!=='passed') {
      try { await service.detachMedia(token,mediaId); } catch { /* may not have linked */ }
      try { await service.cleanupOrphanMedia(token,mediaId);report.checks.push({check:'failure cleanup',result:'passed'}); }
      catch { report.checks.push({check:'failure cleanup',result:'pending',reason:'Cleanup needs reconciliation by fixture UUID; do not infer a settling-period cause without diagnostics.'}); }
    }
    if(token && productCreated) {
      try { await http(`/rest/v1/products?id=eq.${productId}`,'PATCH',{status:'archived'}); }
      catch { report.checks.push({check:'archive synthetic parent',result:'pending'}); }
    }
    await save();
  }
  if(report.status==='failed')process.exitCode=1;
}
