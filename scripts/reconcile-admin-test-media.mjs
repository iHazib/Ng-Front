/** Reconcile only the recorded synthetic failed-upload fixture, never catalog images. */
import{readFile,writeFile}from'node:fs/promises';import{parseEnv}from'node:util';import{registerHooks}from'node:module';
registerHooks({resolve(s,c,n){try{return n(s,c);}catch(e){if(s.startsWith('.')&&c.parentURL?.includes('/src/lib/server/'))return n(s+'.ts',c);throw e;}}});
for(const f of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(f,'utf8')));}catch{}
if(process.env.MEDIA_ENVIRONMENT!=='development')throw new Error('Development only.');
const report={kind:'actual_provider_cleanup',status:'pending'};
try{
 const prior=JSON.parse(await readFile('docs/admin-live-verification.json','utf8'));const fixture=prior.fixtures[0];const id=fixture.failedMediaId;
 if(!id)throw new Error('Recorded failed fixture required.');
 const root=process.env.NEXT_PUBLIC_SUPABASE_URL,headers={apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json'};
 const r=await fetch(root+'/auth/v1/token?grant_type=password',{method:'POST',headers,body:JSON.stringify({email:process.env.TEST_ADMIN_EMAIL,password:process.env.TEST_ADMIN_PASSWORD})});if(!r.ok)throw new Error('Login failed.');const token=(await r.json()).access_token;
 const {authorizeAdmin}=await import('../src/lib/server/database/client.ts');const admin=await authorizeAdmin(token);
 const [parent]=await admin.read('products',new URLSearchParams({id:`eq.${fixture.productId}`,select:'id,name,status'}));
 if(!parent?.name.startsWith('Synthetic admin verification '))throw new Error('Fixture identity mismatch.');
 const [workflow]=await admin.read('media_workflows',new URLSearchParams({media_id:`eq.${id}`,product_id:`eq.${fixture.productId}`,select:'updated_at,expected_public_id,media_assets(lifecycle)'}));
 if(!workflow)throw new Error('Workflow mismatch.');
 const associations=await admin.read('product_media',new URLSearchParams({media_id:`eq.${id}`,select:'id'}));
 const {lookupCloudImage}=await import('../src/lib/server/media/cloudinary.ts');const cloud=await lookupCloudImage(workflow.expected_public_id);
 report.mediaId=id;report.parent_archived=parent.status==='archived';report.associations=associations.length;report.cloudinary_asset_present=!!cloud;
 report.cleanup_eligible_at_utc=new Date(Date.parse(workflow.updated_at)+24*60*60*1000).toISOString();
 if(workflow.media_assets.lifecycle==='deleted'){report.status='passed';report.result='Already safely cleaned up.';}
 else if(Date.now()>=Date.parse(report.cleanup_eligible_at_utc)){
  const {cleanupOrphanMedia}=await import('../src/lib/server/media/service.ts');await cleanupOrphanMedia(token,id);report.status='passed';report.result='Failed synthetic image safely cleaned up through the existing service.';
  prior.pending=[];await writeFile('docs/admin-live-verification.json',JSON.stringify(prior,null,2)+'\n');
 }else{report.result='Existing 24-hour uncertainty guard is still active. Do not bypass it; rerun this script after eligibility.';}
 await fetch(root+'/auth/v1/logout?scope=local',{method:'POST',headers:{...headers,Authorization:`Bearer ${token}`}});
 console.log(JSON.stringify(report,null,2));
}catch{report.status='failed';report.result='Reconciliation could not be verified; sensitive details suppressed.';console.log(report.result);process.exitCode=1;}
await writeFile('docs/admin-cleanup-verification.json',JSON.stringify(report,null,2)+'\n');
