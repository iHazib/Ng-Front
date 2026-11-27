'use client';
/* eslint-disable @next/next/no-img-element -- Authenticated, uncached private previews. */
import {useEffect,useState} from 'react';
import type {References} from './types';
import {adminRequest} from './ProductAdmin';
import {EmptyState,KpiTile,PageHeader,icon} from './ui';
import type {AdminFacet,AdminListFilters,AdminListResult,Reminder} from '@/lib/catalog/admin-list';
import {attentionOptions,reminderLabels} from '@/lib/catalog/admin-list';
import {filterLabel} from '@/lib/catalog/discovery';
import {publicationMessage} from '@/lib/catalog/publication-messages';
const label=(issue:Reminder)=>reminderLabels[issue.code]??publicationMessage(issue.code);
const money=(minor:number)=>new Intl.NumberFormat('en-PK',{style:'currency',currency:'PKR',minimumFractionDigits:2,maximumFractionDigits:2}).format(minor/100);
export function ProductList({refs,onEdit,onCreate}:{refs:References;onEdit:(id:string)=>void;onCreate:()=>void}){
  const [query,setQuery]=useState(''),[filters,setFilters]=useState<AdminListFilters>({}),[applied,setApplied]=useState({query:'',filters:{} as AdminListFilters}),[offset,setOffset]=useState(0);
  const [result,setResult]=useState<AdminListResult|null>(null),[facets,setFacets]=useState<AdminFacet[]>([]),[busy,setBusy]=useState(false),[error,setError]=useState(''),[notice,setNotice]=useState(''),[reload,setReload]=useState(0),[undo,setUndo]=useState<Reminder|null>(null),[view,setView]=useState<'table'|'grid'>('table');
  useEffect(()=>{let current=true;setBusy(true);setError('');const params=new URLSearchParams({view:'list',q:applied.query,filters:JSON.stringify(applied.filters),offset:String(offset)});adminRequest<AdminListResult>('/admin/api/catalog?'+params).then(data=>{if(current){setResult(data);if(offset>0&&offset>=data.total)setOffset(Math.max(0,Math.floor((data.total-1)/25)*25));}}).catch(e=>{if(current){setError(e.message);setResult(null);}}).finally(()=>{if(current)setBusy(false);});return()=>{current=false;};},[applied,offset,reload]);
  useEffect(()=>{let current=true;adminRequest<AdminFacet[]>('/admin/api/catalog?view=filter-options&category='+encodeURIComponent(filters.category??'')).then(data=>{if(current)setFacets(data);}).catch(e=>{if(current){setFacets([]);setError(e.message);}});return()=>{current=false;};},[filters.category]);
  const change=(key:keyof AdminListFilters,value:string)=>setFilters(old=>({...old,[key]:value,...(key==='category'?{facets:{},type:''}:{})}));
  const toggleIssue=(code:string)=>setFilters(old=>({...old,issues:old.issues?.includes(code)?old.issues.filter(x=>x!==code):[...(old.issues??[]),code]}));
  const toggleFacet=(key:string,value:string)=>setFilters(old=>{const values=old.facets?.[key]??[];return{...old,facets:{...old.facets,[key]:values.includes(value)?values.filter(x=>x!==value):[...values,value]}};});
  async function reminder(issue:Reminder,ignore:boolean){setBusy(true);setError('');try{await adminRequest('/admin/api/catalog',{action:'reminder',key:issue.key,episode:issue.episode,ignore});setUndo(ignore?issue:null);setNotice(ignore?'Reminder ignored. Publication rules still apply.':'Reminder restored.');setReload(n=>n+1);}catch(e){setError(e instanceof Error?e.message:'Reminder could not be changed.');}finally{setBusy(false);}}
  function isDescendant(id:string,parent:string){let next:string|null=id;for(let n=0;next&&n<20;n++){if(next===parent)return true;next=refs.categories.find(c=>c.id===next)?.parent_id??null;}return false;}
  function categoryName(id:string){const names:string[]=[];let next:string|null=id;for(let n=0;next&&n<20;n++){const c=refs.categories.find(x=>x.id===next);if(!c)break;names.unshift(c.name);next=c.parent_id;}return names.join(' / ');}
  function badges(issues:Reminder[],sku:string){return issues.map(issue=><span className={'reminder-badge '+(issue.required?'required':'optional')} key={issue.key}><span><span>{label(issue)}</span>{issue.variantId&&<small>For {sku}</small>}</span><button type="button" disabled={busy} aria-label={'Ignore '+label(issue)+' for '+sku} onClick={()=>void reminder(issue,true)}>Ignore</button></span>);}
  const rows=result?.rows??[];
  const attention=rows.filter(row=>row.issues.some(i=>!i.ignored&&i.required)).length;
  const outOfStock=rows.filter(row=>row.stock===0).length;
  const published=rows.filter(row=>row.status==='published').length;
  const chips:{key:string;label:string;value:string}[]=[];
  if(applied.query)chips.push({key:'query',label:'Search',value:applied.query});
  if(applied.filters.status)chips.push({key:'status',label:'Visibility',value:applied.filters.status});
  if(applied.filters.brand)chips.push({key:'brand',label:'Brand',value:refs.brands.find(b=>b.id===applied.filters.brand)?.name??applied.filters.brand});
  if(applied.filters.category)chips.push({key:'category',label:'Category',value:categoryName(applied.filters.category)});
  if(applied.filters.type)chips.push({key:'type',label:'Type',value:refs.product_types.find(t=>t.id===applied.filters.type)?.name??applied.filters.type});
  if(applied.filters.issues?.length)chips.push({key:'issues',label:'Needs',value:applied.filters.issues.map(code=>reminderLabels[code]??code).join(', ')});
  const dropChip=(key:string)=>{const next={...applied.filters};delete next[key as keyof AdminListFilters];const draft={...filters};delete draft[key as keyof AdminListFilters];setFilters(draft);setApplied({query:applied.query,filters:next});setOffset(0);setUndo(null);};
  const cell=(row:AdminListResult['rows'][number])=>{
   const required=row.issues.filter(i=>!i.ignored&&i.required),optional=row.issues.filter(i=>!i.ignored&&!i.required),ignored=row.issues.filter(i=>i.ignored);
   const sku=row.variant_label??row.original_sku??row.name;
   return <>
    <div className="product-list-name">{row.media_id?<img src={'/admin/api/media?id='+row.media_id} alt=""/>:<span className="thumbnail-empty" aria-label="No photo">—</span>}<div className="product-list-copy"><strong>{row.name}</strong><small>{row.original_sku??'No SKU yet'}{row.variant_label&&' · '+row.variant_label}</small>{row.variant_status==='archived'&&<small className="product-list-note">Removed option · retained history</small>}</div></div>
    {required.length>0&&<div className="list-reminders"><small>Before publishing</small>{badges(required,sku)}</div>}
    {optional.length>0&&<div className="list-reminders"><small>Optional content / availability</small>{badges(optional,sku)}</div>}
    {ignored.length>0&&<details className="ignored-reminders"><summary>Ignored reminders ({ignored.length})</summary>{ignored.map(i=><div className="actions" key={i.key}><span>{label(i)}{i.variantId&&' · '+sku}</span><button disabled={busy} onClick={()=>void reminder(i,false)} aria-label={'Restore '+label(i)+' for '+(row.original_sku??row.name)}>Restore</button></div>)}</details>}
   </>;
  };
  return <div className="admin-product-list">
  <PageHeader eyebrow="Catalog" title="Products" description="Everything you sell, with the information each listing still needs." actions={<>
    <div className="admin-view-toggle" role="group" aria-label="Result layout">
      <button type="button" aria-pressed={view==='table'} onClick={()=>setView('table')}>{icon.list}Table</button>
      <button type="button" aria-pressed={view==='grid'} onClick={()=>setView('grid')}>{icon.grid}Cards</button>
    </div>
    <button type="button" onClick={onCreate}>{icon.plus}New product</button>
  </>}/>
  {result&&<div className="admin-kpis">
    <KpiTile label="Products" value={result.products} caption="in this result"/>
    <KpiTile label="SKUs" value={result.skus??result.total} caption={result.limit?`${result.limit} shown per page`:undefined}/>
    <KpiTile label="Live now" value={published} caption="published on this page" tone={published?'good':undefined}/>
    <KpiTile label="Needs attention" value={attention} caption="on this page" tone={attention?'warn':undefined}/>
    <KpiTile label="Out of stock" value={outOfStock} caption="counted at zero" tone={outOfStock?'warn':undefined}/>
  </div>}
  <form className="admin-searchbar list-search" onSubmit={e=>{e.preventDefault();setOffset(0);setApplied({query,filters});setUndo(null);}}>
  <label className="search-grow">Search products<input aria-label="Search products" aria-describedby="admin-search-help" type="search" value={query} maxLength={160} onChange={e=>setQuery(e.target.value)} placeholder="Name, SKU, brand or assigned attributes"/><small id="admin-search-help">Try “CeraVe cleanser dry skin”. All visibility states are included.</small></label>
  <label className="admin-field">Visibility<select aria-label="Visibility" value={filters.status??''} onChange={e=>change('status',e.target.value)}><option value="">All products</option><option value="draft">Draft</option><option value="published">Published</option><option value="archived">Hidden</option></select></label>
  <button className="btn-secondary" disabled={busy}>{icon.search}Search</button>
  {chips.length>0&&<div className="admin-chips">{chips.map(chip=><span className="admin-chip-filter" key={chip.key}><b>{chip.label}</b> {chip.value}<button type="button" aria-label={'Remove filter '+chip.label} onClick={()=>dropChip(chip.key)}>×</button></span>)}<button type="button" className="btn-ghost btn-sm" onClick={()=>{setQuery('');setFilters({});setApplied({query:'',filters:{}});setOffset(0);setUndo(null);}}>Clear all</button></div>}
  <details className="list-filters"><summary>{icon.filter}<span>Filters &amp; needs attention</span>{chips.length>0&&<em>{chips.length} active</em>}</summary><div className="list-filter-grid">
  <label>Brand<select aria-label="Brand" value={filters.brand??''} onChange={e=>change('brand',e.target.value)}><option value="">All brands</option>{refs.brands.map(b=><option key={b.id} value={b.id}>{b.name}</option>)}</select></label>
  <label>Category / subcategory<select aria-label="Category / subcategory" value={filters.category??''} onChange={e=>change('category',e.target.value)}><option value="">All categories</option>{refs.categories.map(c=><option key={c.id} value={c.id}>{categoryName(c.id)}</option>)}</select></label>
  <label>Product type<select aria-label="Product type" value={filters.type??''} onChange={e=>change('type',e.target.value)}><option value="">All product types</option>{refs.product_types.filter(t=>!filters.category||refs.category_product_types.some(x=>x.product_type_id===t.id&&(isDescendant(x.category_id,filters.category??'')))).map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select></label>
  <label>Reminders<select aria-label="Reminders" value={filters.reminders??''} onChange={e=>change('reminders',e.target.value)}><option value="">All products</option><option value="ignored">Ignored reminders</option></select></label>
  </div>
  <fieldset className="attention-options"><legend>Needs attention</legend><div className="list-checks">{attentionOptions.map(code=><label className="check" key={code}><input type="checkbox" checked={filters.issues?.includes(code)??false} onChange={()=>toggleIssue(code)}/>{reminderLabels[code]}</label>)}</div><label>Match issues<select aria-label="Match issues" value={filters.mode??'any'} onChange={e=>change('mode',e.target.value)}><option value="any">Any selected issue</option><option value="all">All selected issues</option></select></label><small>These filters check missing information even when a reminder is ignored. Optional content never blocks publication.</small></fieldset>
  {facets.length>0&&<details><summary>Assigned filters &amp; concerns</summary><p>Matches existing assignments only; it does not infer suitability.</p><div className="list-filter-grid">{facets.map(f=><fieldset key={f.key}><legend>{filterLabel(f.label)}</legend>{f.values.map(v=><label className="check" key={v.value}><input type="checkbox" checked={filters.facets?.[f.key]?.includes(v.value)??false} onChange={()=>toggleFacet(f.key,v.value)}/>{filterLabel(v.label)}</label>)}</fieldset>)}</div></details>}
  <div className="actions"><button disabled={busy}>Apply filters</button><button type="button" className="btn-ghost" disabled={busy} onClick={()=>{setQuery('');setFilters({});setApplied({query:'',filters:{}});setOffset(0);setUndo(null);}}>Clear all</button></div></details>
  </form>
  {error&&<p role="alert">{error} <button onClick={()=>setReload(n=>n+1)}>Retry</button></p>}
  <p role="status" aria-live="polite">{busy?'Loading…':notice}{!busy&&undo&&<button onClick={()=>void reminder(undo,false)}>Undo</button>}</p>
  {result&&<><p className="list-count">{result.products} matching products · {result.skus??result.total} matching SKUs{applied.query&&<> for “{applied.query}”</>}</p>
  {view==='table'&&<div className="table-scroll" aria-busy={busy}><table className="product-table"><thead><tr><th>Product</th><th>Price</th><th>Stock</th><th>Visibility</th><th>Action</th></tr></thead><tbody>{rows.map(row=><tr key={row.variant_id??row.product_id}>
  <td>{cell(row)}
  </td><td data-label="Price" className="cell-price">{row.price_minor!==null?money(row.price_minor):<span className="cell-empty">Not set</span>}</td><td data-label="Stock" className="cell-stock">{row.stock===null?<span className="cell-empty">Not counted</span>:<span className="cell-number">{row.stock}</span>}{row.reserved? <small>{row.reserved} reserved</small>:null}</td><td data-label="Visibility"><span className="status-pill" data-status={row.status}>{row.status==='archived'?'Hidden':row.status}</span>{row.status==='published'&&row.variant_status==='draft'&&<small>Draft option</small>}</td><td><button className="btn-secondary btn-sm" disabled={busy} onClick={()=>onEdit(row.product_id)}>Edit {row.original_sku??row.name}</button></td></tr>)}</tbody></table></div>}
  {view==='grid'&&<div className="catalog-grid" aria-busy={busy}>{rows.map(row=><article className="catalog-card" key={row.variant_id??row.product_id}>
   <div className="catalog-card-media">{row.media_id?<img src={'/admin/api/media?id='+row.media_id} alt=""/>:<span className="thumbnail-empty" aria-label="No photo">—</span>}</div>
   <div className="catalog-card-body"><p className="catalog-card-title">{row.name}</p><p className="catalog-card-sku">{row.original_sku??'No SKU yet'}{row.variant_label&&' · '+row.variant_label}</p>
   <dl className="catalog-card-meta"><div><dt>Price</dt><dd>{row.price_minor!==null?money(row.price_minor):'Not set'}</dd></div><div><dt>Stock</dt><dd>{row.stock===null?'Not counted':row.stock}</dd></div></dl>
   <div className="catalog-card-foot"><span className="status-pill" data-status={row.status}>{row.status==='archived'?'Hidden':row.status}</span><button className="btn-secondary btn-sm" disabled={busy} onClick={()=>onEdit(row.product_id)}>Edit {row.original_sku??row.name}</button></div>
   {row.issues.some(i=>!i.ignored&&i.required)&&<div className="list-reminders"><small>Before publishing</small>{badges(row.issues.filter(i=>!i.ignored&&i.required),row.variant_label??row.original_sku??row.name)}</div>}
   </div></article>)}</div>}
  {!rows.length&&<EmptyState title="No products match. Try fewer filters or clear your search." hint="Adjust the search, widen the filters, or clear everything to see the full catalog."/>}
  <nav className="actions admin-pagination" aria-label="Catalog pages"><button className="btn-secondary btn-sm" disabled={busy||offset===0} onClick={()=>setOffset(n=>Math.max(0,n-25))}>Previous</button><span>Page {Math.floor(offset/25)+1} of {Math.max(1,Math.ceil(result.total/25))} · {rows.length} {rows.some(row=>!row.variant_id)?'entries':'SKUs'} shown</span><button className="btn-secondary btn-sm" disabled={busy||offset+25>=result.total} onClick={()=>setOffset(n=>n+25)}>Next</button></nav></>}
  </div>;
}
