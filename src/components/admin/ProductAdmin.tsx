'use client';
/* eslint-disable @next/next/no-img-element -- Private thumbnails require authorized uncached delivery. */
import { useEffect, useState } from 'react';
import type { Detail, InitialImage, References, SearchRow } from './types';
import { ProductEditor } from './ProductEditor';
import { ProductList } from './ProductList';
import { PageHeader } from './ui';

export async function adminRequest<T>(path:string, body?:unknown, bytes?:File,onProgress?:(percent:number)=>void):Promise<T> {
  const headers:Record<string,string>={};
  if(body!==undefined || bytes){
    const result=await fetch('/admin/api/session',{cache:'no-store'});const {csrf}=await result.json();headers['x-admin-csrf']=csrf;
    headers['Content-Type']=bytes?'application/octet-stream':'application/json';
  }
  if(bytes&&onProgress){return new Promise<T>((resolve,reject)=>{const xhr=new XMLHttpRequest();xhr.open('POST',path);Object.entries(headers).forEach(([name,value])=>xhr.setRequestHeader(name,value));xhr.upload.onprogress=e=>{if(e.lengthComputable)onProgress(Math.round(e.loaded/e.total*100));};xhr.onerror=()=>reject(new Error('Upload interrupted. Retry the same image.'));xhr.onload=()=>{try{const result=JSON.parse(xhr.responseText);if(xhr.status===401)window.location.assign('/admin/login');if(xhr.status<200||xhr.status>=300)reject(new Error(result.error??'Upload failed.'));else resolve(result as T);}catch{reject(new Error('Upload response could not be read. Refresh before retrying.'));}};xhr.send(bytes);});}
  const response=await fetch(path,{method:body!==undefined||bytes?'POST':'GET',headers,body:bytes??(body===undefined?undefined:JSON.stringify(body)),cache:'no-store'});
  const result=await response.json();
  if(!response.ok){if(response.status===401)window.location.assign('/admin/login');throw new Error(result.error??'Request failed.');}
  return result as T;
}
export function ProductAdmin({toolsOnly=false}:{toolsOnly?:boolean}){
  const [rows,setRows]=useState<SearchRow[]>([]),[refs,setRefs]=useState<References|null>(null),[detail,setDetail]=useState<Detail|null>(null);
  const [dirty,setDirty]=useState(false),[visibility,setVisibility]=useState('');
  const [q,setQ]=useState(''),[offset,setOffset]=useState(0),[message,setMessage]=useState(''),[busy,setBusy]=useState(false),[images,setImages]=useState<InitialImage[]|null>(null);
  const [createIds,setCreateIds]=useState<{productId:string;variantId:string}|null>(null);
  const [history,setHistory]=useState<{created_at:string;contract_version:string}[]|null>(null);
  async function assignImage(image:InitialImage){
    const sku=window.prompt(`Enter the exact SKU for ${image.filename}. Only assign after checking the product.`);
    if(!sku)return;
    const rows=await adminRequest<SearchRow[]>(`/admin/api/catalog?q=${encodeURIComponent(sku)}`);
    const row=rows.find(r=>r.original_sku===sku);
    if(!row)throw new Error('No exact SKU found. Check the SKU and try again.');
    if(window.confirm(`Assign ${image.filename} to ${row.name} (${row.original_sku})?`))await adminRequest('/admin/api/catalog',{action:'initial-image',key:image.key,variantId:row.variant_id});
  }
  const load=async(query=q,start=offset)=>{if(!toolsOnly)return;const list=await adminRequest<SearchRow[]>(`/admin/api/catalog?q=${encodeURIComponent(query)}&offset=${start}&status=${visibility}`);setRows(list);};
  useEffect(()=>{Promise.all([adminRequest<References>('/admin/api/catalog?view=references'),toolsOnly?adminRequest<SearchRow[]>('/admin/api/catalog'):Promise.resolve([] as SearchRow[])]).then(([references,list])=>{setRefs(references);setRows(list);}).catch(error=>setMessage(error.message));},[toolsOnly]);
  async function run(work:()=>Promise<unknown>,success='Saved.'){setBusy(true);setMessage('');try{await work();setMessage(success);}catch(error){setMessage(error instanceof Error?error.message:'Operation failed.');}finally{setBusy(false);}}
  const open=async(id:string)=>{setDetail(await adminRequest<Detail>(`/admin/api/catalog?view=product&id=${id}`));};
  const mutate=async(body:Record<string,unknown>)=>{
    await adminRequest('/admin/api/catalog',body);if(detail)await open(detail.product.id);setDirty(false);await load();
  };
  return <>{toolsOnly&&<PageHeader eyebrow="Utilities" title="Import & technical tools" description="Bring the reviewed workbook into the catalog and stage the original product images."/>}
    <p role="status" aria-live="polite">{busy?'Working…':message}</p>
    <fieldset disabled={busy||!refs} style={{border:0,padding:0,background:'transparent'}}>
    {detail&&refs?<><ProductEditor key={detail.product.id+':'+detail.product.revision} detail={detail} onDirty={setDirty} refs={refs} run={run} mutate={mutate} refresh={()=>open(detail.product.id)} onBack={()=>{if(!dirty||window.confirm('Leave without saving your changes?')){setDirty(false);setDetail(null);}}} /></>:<>
    {toolsOnly&&<form className="actions" onSubmit={event=>{event.preventDefault();setOffset(0);void run(()=>load(q,0),'Search updated.');}}><label>Search by SKU or product name<input value={q} onChange={e=>setQ(e.target.value)} name="search" type="search" /></label><label>Visibility<select aria-label="Visibility" value={visibility} onChange={e=>setVisibility(e.target.value)}><option value="">All products</option><option value="draft">Draft</option><option value="published">Published</option><option value="archived">Hidden</option></select></label><button>Search</button><button type="button" onClick={()=>setCreateIds({productId:crypto.randomUUID(),variantId:crypto.randomUUID()})}>New product</button></form>}
    {createIds&&<section><h2>Create draft product</h2><form onSubmit={e=>{e.preventDefault();const f=new FormData(e.currentTarget);void run(async()=>{const result=await adminRequest<{productId:string}>('/admin/api/catalog',{action:'create',...createIds,name:f.get('name'),sku:f.get('sku')});setCreateIds(null);await load();await open(result.productId);},'Draft created.');}}><label>Product name<input name="name" required maxLength={300}/></label><label>SKU<input name="sku" required maxLength={120}/></label><button>Create draft</button> <button type="button" onClick={()=>setCreateIds(null)}>Cancel</button></form></section>}
    {!toolsOnly&&refs&&<ProductList refs={refs} onEdit={id=>void run(()=>open(id),'Product loaded.')} onCreate={()=>setCreateIds({productId:crypto.randomUUID(),variantId:crypto.randomUUID()})}/>}
    {toolsOnly&&<><div className="table-scroll"><table className="product-table"><thead><tr><th>Product</th><th>Price</th><th>Stock</th><th>Visibility</th><th>Action</th></tr></thead><tbody>{rows.map(row=><tr key={row.variant_id}><td><div className="product-list-name">{row.media_id?<img src={'/admin/api/media?id='+row.media_id} alt=""/>:<span className="thumbnail-empty" aria-label="No photo">—</span>}<div><strong>{row.name}</strong><small>{row.original_sku}</small></div></div></td><td data-label="Price">{row.price_minor!=null?new Intl.NumberFormat('en-PK',{style:'currency',currency:'PKR',minimumFractionDigits:2,maximumFractionDigits:2}).format(row.price_minor/100):'Not set'}</td><td data-label="Stock">{row.stock??'Not counted'}</td><td data-label="Visibility"><span className="status-pill" data-status={row.status}>{row.status==='archived'?'Hidden':row.status}</span></td><td><button onClick={()=>run(()=>open(row.product_id),'Product loaded.')}>Edit {row.original_sku}</button></td></tr>)}</tbody></table></div>{!rows.length&&<p className="admin-empty">No matching SKUs.</p>}
    <nav className="actions" aria-label="Catalog pages"><button disabled={offset===0} onClick={()=>{const n=Math.max(0,offset-50);setOffset(n);void run(()=>load(q,n),'Page loaded.');}}>Previous</button><span>Page {offset/50+1} · {rows.length} records</span><button disabled={rows.length<50} onClick={()=>{const n=offset+50;setOffset(n);void run(()=>load(q,n),'Page loaded.');}}>Next</button></nav></>}
    {toolsOnly&&<section><h2>Import tools</h2><p>The reviewed workbook contains 121 SKUs. Repeating its import preserves edits, prices and live stock. Missing images and optional concerns do not block draft creation.</p><button onClick={()=>run(async()=>{const result=await adminRequest('/admin/api/catalog',{action:'catalog-import'});await load();setImages(null);return result;},'Catalog import completed. Existing records preserved.')}>Import / repeat 121 draft SKUs</button> <button className="btn-secondary" onClick={()=>run(async()=>setImages(await adminRequest<InitialImage[]>('/admin/api/catalog?view=images')),'Image preview ready.')}>Preview initial image matches</button>
    {images&&<><p>{images.filter(i=>i.exactSku).length} exact filenames · {images.filter(i=>!i.exactSku).length} unmatched. Uploads remain private until explicit review and approval.</p><div className="table-scroll"><table><thead><tr><th>Source filename</th><th>SKU match</th><th>Private upload</th></tr></thead><tbody>{images.map(image=><tr key={image.key}><td>{image.filename}</td><td>{image.exactSku??'Unmatched — do not guess'}</td><td>{image.exactSku?<button onClick={()=>run(()=>adminRequest('/admin/api/catalog',{action:'initial-image',key:image.key}),'Image staged privately. Review it in the SKU editor.')}>Stage / retry</button>:<button onClick={()=>run(()=>assignImage(image),'Manual assignment finished. Review the private image in the product editor.')}>Assign to SKU</button>}</td></tr>)}</tbody></table></div></>}
    <button className="btn-secondary" onClick={()=>run(async()=>setHistory(await adminRequest<{created_at:string;contract_version:string}[]>('/admin/api/catalog?view=history')),'Import history loaded.')}>View import history</button>
    {history&&<ul>{history.map((batch,i)=><li key={i}>{new Date(batch.created_at).toLocaleString('en-PK',{timeZone:'Asia/Karachi'})} (Karachi) · {batch.contract_version}</li>)}</ul>}
    </section>}</>}
    </fieldset></>;
}
