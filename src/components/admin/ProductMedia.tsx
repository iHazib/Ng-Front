'use client';
/* eslint-disable @next/next/no-img-element -- Private images use an authorized, uncached route. */
import { useState } from 'react';
import type { Detail } from './types';
import { adminRequest } from './ProductAdmin';
type Props={detail:Detail;refresh:()=>Promise<void>;owner:string;onOwnerChange:(owner:string)=>void};
export function ProductMedia({detail,refresh,owner,onOwnerChange}:Props){
 const [replace,setReplace]=useState(''),[progress,setProgress]=useState<number|null>(null);
 // Image feedback belongs beside the images; the page-level status line sits above the editor.
 const [state,setState]=useState<{busy:boolean;message:string;error:boolean}|null>(null);
 const active=detail.variants.filter(v=>v.status!=='archived');
 const perform=async(work:()=>Promise<unknown>,success:string)=>{
  setState({busy:true,message:'Working…',error:false});
  try{await work();setState({busy:false,message:success,error:false});}
  catch(error){setState({busy:false,message:error instanceof Error?error.message:'Image operation failed. Refresh and retry.',error:true});}
 };
 const busy=state?.busy===true;
 const associations=detail.associations;const visible=detail.workflows.filter(w=>(w.variant_id===owner||w.variant_id===null)&&!['deleted','retired','deleting'].includes(w.media_assets.lifecycle)).sort((a,b)=>(associations.find(x=>x.media_id===a.media_id)?.position??10000)-(associations.find(x=>x.media_id===b.media_id)?.position??10000));
 const act=async(action:string,id:string,extra:Record<string,unknown>={})=>{await adminRequest('/admin/api/media',{action,id,...extra});await refresh();};
 return <div className="admin-media-block">
 {active.length>1&&<label>Images for<select aria-label="Images for" value={owner} onChange={e=>{onOwnerChange(e.target.value);setReplace('');}}><option value="">All options</option>{active.map(v=><option key={v.id} value={v.id}>{v.label||v.original_sku}</option>)}</select></label>}
 <form onSubmit={e=>{e.preventDefault();const f=new FormData(e.currentTarget);const files=f.getAll('photos').filter((file):file is File=>file instanceof File&&file.size>0);void perform(async()=>{
  if(replace&&files.length!==1)throw new Error('Choose one replacement image.');
  const selected=associations.find(a=>a.id===replace);const variant=selected?selected.variant_id??'':owner;
  for(const file of files){setProgress(0);if(file.size>10*1024*1024)throw new Error('Each image must be smaller than 10 MB.');const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',await file.arrayBuffer()))).map(b=>b.toString(16).padStart(2,'0')).join('');const alt=String(f.get('alt')||detail.product.name);const key=['ng-media',detail.product.id,variant,replace,digest,alt].join(':');let id=sessionStorage.getItem(key);if(!id){id=crypto.randomUUID();sessionStorage.setItem(key,id);}try{await adminRequest('/admin/api/media?'+new URLSearchParams({action:'upload',id,productId:detail.product.id,variantId:variant,replace,alt}),undefined,file,setProgress);}finally{setProgress(null);}}
  setReplace('');await refresh();
 },'Images uploaded.');}}>
 <>{progress!==null&&<div role="status"><progress max={100} value={progress}/><small>{progress<100?`Uploading ${progress}%`:'Upload sent. Processing private image…'}</small></div>}</><label>{replace?'Replacement image':'Choose images'}<input name="photos" type="file" accept="image/png,image/jpeg,image/webp" multiple={!replace} required/></label><label>Image description <small>Optional</small><input name="alt" maxLength={500}/></label><div className="actions"><button disabled={busy}>Upload</button>{replace&&<button type="button" className="btn-ghost" disabled={busy} onClick={()=>setReplace('')}>Cancel replacement</button>}</div></form>
 {state&&<p className={'admin-media-status'+(state.error?' is-error':'')} role="status" aria-live="polite">{state.message}</p>}
 {!visible.length&&<p className="admin-media-empty">No images yet. Upload one above; it stays private until you approve it.</p>}<div className="media-grid">{visible.map(w=>{const asset=w.media_assets;const association=associations.find(a=>a.media_id===w.media_id);const group=associations.filter(a=>a.variant_id===w.variant_id).sort((a,b)=>a.position-b.position);const index=group.findIndex(a=>a.media_id===w.media_id);
 const move=async(delta:number)=>{const ids=group.map(a=>a.id);[ids[index],ids[index+delta]]=[ids[index+delta],ids[index]];await act('reorder','',{productId:detail.product.id,variantId:w.variant_id,ids});};
 return <article key={w.media_id}><img src={`/admin/api/media?id=${w.media_id}`} alt={asset.alt??detail.product.name}/><p className="admin-media-label" data-kind={association?.is_primary?'primary':association?'approved':'private'}>{association?.is_primary?'Main image':association?'Approved':'Not published yet'}</p><div className="actions">
 {!association&&<button type="button" className="btn-publish btn-sm" disabled={busy} onClick={()=>perform(()=>act('approve-publish',w.media_id),'Image approved.')}>Approve image</button>}
 {association&&<><button type="button" className="btn-secondary btn-sm" disabled={busy||association.is_primary} onClick={()=>perform(()=>act('primary',w.media_id,{productId:detail.product.id,variantId:w.variant_id}),'Saved.')}>Set primary</button><button type="button" className="btn-ghost btn-sm" disabled={busy||index<=0} aria-label="Move image earlier" onClick={()=>perform(()=>move(-1),'Image order saved.')}>←</button><button type="button" className="btn-ghost btn-sm" disabled={busy||index===group.length-1} aria-label="Move image later" onClick={()=>perform(()=>move(1),'Image order saved.')}>→</button><button type="button" className="btn-secondary btn-sm" disabled={busy} onClick={()=>{setReplace(association.id);document.querySelector('#product-images input[type=file]')?.scrollIntoView({behavior:'smooth'});}}>Replace</button></>}
 <button type="button" className="btn-danger btn-sm" aria-label="Remove image" disabled={busy} onClick={()=>perform(async()=>{if(association)await adminRequest('/admin/api/media',{action:'detach',id:w.media_id});try{await adminRequest('/admin/api/media',{action:'cleanup',id:w.media_id});}finally{await refresh();}},'Image removed.')}>Remove</button>
 </div></article>;})}</div></div>;
}

