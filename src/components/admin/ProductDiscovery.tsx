'use client';
import {useState} from 'react';
import type {Detail,References} from './types';
import {categoryScope,discoveryLabel,type DiscoveryDraft} from '@/lib/catalog/discovery';
import {SectionCard,icon} from './ui';
type Selection=DiscoveryDraft['facets'][number];
const meaningful=(f:Selection)=>Boolean(f.value.trim()||f.newValue.trim());
const fieldOrder:Record<string,string[]>={
 'personal-fragrance':['concentration','fragrance-family','fragrance-note','marketed-audience','size','occasion','season','piece-count'],
 'home-fragrance':['home-format','fragrance-family','fragrance-note','size','occasion','season','piece-count'],
 'bath-body':['body-format','body-concern','application-area','ingredient','size','spf','occasion'],
 'skincare':['skin-type','application-area','ingredient','size','spf','piece-count'],
 'makeup':['makeup-format','shade','makeup-finish','coverage','skin-type','application-area','size','material','piece-count','occasion'],
 'hair-care':['hair-format','hair-type','hair-concern','application-area','ingredient','size'],
 'cutlery':['material','finish-colour','piece-count','care-feature','care','occasion'],
};
const blank=(facetId:string):Selection=>({facetId,variantId:'',value:'',newValue:'',unit:'ml'});
export function ProductDiscovery({detail,refs,category,onValue}:{detail:Detail;refs:References;category:string;onValue:(value:DiscoveryDraft)=>void}){
 const [draft,setDraft]=useState<DiscoveryDraft>({facets:[],concerns:[],removeFacets:[],removeConcerns:[],confirmed:false,sourceType:'package',sourceUrl:''});
 const installed=detail.report.discovery_editor_version===1,scope=categoryScope(category,refs.categories);
 const priorities=fieldOrder[scope??'']??[];
 const definitions=refs.facet_definitions.filter(f=>refs.facet_scopes.some(s=>s.scope===scope&&s.facet_id===f.id)&&!/^synthetic/i.test(f.name)).toSorted((a,b)=>(priorities.indexOf(a.id)<0?999:priorities.indexOf(a.id))-(priorities.indexOf(b.id)<0?999:priorities.indexOf(b.id))||a.name.localeCompare(b.name));
 const update=(next:DiscoveryDraft)=>{setDraft(next);onValue({...next,facets:next.facets.filter(meaningful)});};
 const edit=(index:number,current:Selection,patch:Partial<Selection>)=>update({...draft,confirmed:false,facets:index<0?[...draft.facets,{...current,...patch}]:draft.facets.map((f,i)=>i===index?{...f,...patch}:f)});
 const existing=detail.facets.filter(f=>!draft.removeFacets.includes(f.id));
 const concernChecked=(id:string)=>draft.concerns.includes(id)||detail.concerns.some(c=>c.concern_id===id&&!draft.removeConcerns.includes(id));
 const hasAdds=draft.facets.some(meaningful)||draft.concerns.length>0;
 const saved=(f:Detail['facets'][number])=>{const def=refs.facet_definitions.find(d=>d.id===f.facet_id),value=f.facet_values?.label??refs.facet_values.find(v=>v.id===f.option_id)?.label??String(f.integer_value??f.decimal_value??f.boolean_value??'');return <div className="discovery-assignment" key={f.id}><span>{value}{f.unit?' '+f.unit:''}<small>{f.variant_id?detail.variants.find(v=>v.id===f.variant_id)?.label||detail.variants.find(v=>v.id===f.variant_id)?.original_sku:'All shades / sizes'}</small>{!definitions.some(d=>d.id===f.facet_id)&&<small>{discoveryLabel(f.facet_id,def?.name)} · Not used in this category</small>}</span><button type="button" className="btn-ghost btn-sm" onClick={()=>update({...draft,removeFacets:[...draft.removeFacets,f.id]})}>Remove</button></div>;};
 return <SectionCard id="product-discovery" icon={icon.tag} title="Discovery filters" description="Optional · help customers find this product by its actual features.">
 {!installed?<p>The discovery filter update needs to be installed (024) before saving these selections.</p>:!scope?<p>Choose a specific category to see its filters. For fragrance, choose Personal Fragrance or Home Fragrance.</p>:<>
 <p>Leave anything that does not apply blank. Only select details checked against the product label or official information.</p>
 {scope==='skincare'&&<fieldset className="discovery-concerns"><legend>Shop by concern</legend><p>Choose explicit suitability only. Ingredients alone do not establish acne treatment or sensitive-skin suitability.</p><div className="discovery-checks">{refs.concerns.map(c=><label className="check" key={c.id}><input type="checkbox" checked={concernChecked(c.id)} onChange={e=>{const original=detail.concerns.some(x=>x.concern_id===c.id);update({...draft,confirmed:false,concerns:e.target.checked&&!original?[...draft.concerns,c.id]:draft.concerns.filter(id=>id!==c.id),removeConcerns:e.target.checked?draft.removeConcerns.filter(id=>id!==c.id):original?[...draft.removeConcerns,c.id]:draft.removeConcerns});}}/>{c.name}</label>)}</div></fieldset>}
 {scope!=='skincare'&&detail.concerns.filter(c=>!draft.removeConcerns.includes(c.concern_id)).map(c=><p key={c.concern_id}>{refs.concerns.find(x=>x.id===c.concern_id)?.name??c.concern_id} · Not used in this category <button type="button" className="btn-ghost btn-sm" onClick={()=>update({...draft,removeConcerns:[...draft.removeConcerns,c.concern_id]})}>Remove</button></p>)}
 <div className="discovery-fields">{definitions.map(def=>{
 const name=discoveryLabel(def.id,def.name),values=refs.facet_values.filter(v=>v.facet_id===def.id),entries=draft.facets.map((item,index)=>({item,index})).filter(row=>row.item.facetId===def.id),rows=entries.length?entries:[{item:blank(def.id),index:-1}];
 return <section className="discovery-field" data-field={def.id} key={def.id}><h3>{name} <small>Optional</small></h3>{existing.filter(f=>f.facet_id===def.id).map(saved)}{rows.map(({item,index},n)=>{
 const label=name+(n?' '+(n+1):'');
 return <div className="discovery-field-row" key={index}><label><span className="filter-sr-only">{label}</span>{def.kind==='enum'||def.kind==='reference'?<select aria-label={label} value={item.newValue?'__new':item.value} onChange={e=>edit(index,item,{value:e.target.value==='__new'?'':e.target.value,newValue:e.target.value==='__new'?' ':''})}><option value="">Choose / leave blank</option>{values.map(v=><option key={v.id} value={v.id}>{v.label.replaceAll('-',' ')}</option>)}{def.kind==='reference'&&<option value="__new">Add a specific value…</option>}</select>:def.kind==='boolean'?<select aria-label={label} value={item.value} onChange={e=>edit(index,item,{value:e.target.value})}><option value="">Choose / leave blank</option><option value="true">Yes</option><option value="false">No</option></select>:<input aria-label={label} placeholder="Leave blank if not applicable" type="number" min={def.kind==='integer'?1:0.0001} step={def.kind==='integer'?1:0.0001} value={item.value} onChange={e=>edit(index,item,{value:e.target.value})}/>}</label>
 {def.kind==='reference'&&Boolean(item.newValue)&&<label>Specific {name.toLowerCase()}<input aria-label={'Specific '+label.toLowerCase()} maxLength={80} value={item.newValue.trimStart()} onChange={e=>edit(index,item,{newValue:e.target.value||' '})}/><small>One named value per selection.</small></label>}
 {def.kind==='quantity'&&<label>Unit<select aria-label={label+' unit'} value={item.unit} onChange={e=>edit(index,item,{unit:e.target.value})}>{['ml','g','cm','mm'].map(u=><option key={u}>{u}</option>)}</select></label>}
 {detail.variants.filter(v=>v.status!=='archived').length>1&&<label>Applies to<select aria-label={label+' applies to'} value={item.variantId} onChange={e=>edit(index,item,{variantId:e.target.value})}><option value="">All shades / sizes</option>{detail.variants.filter(v=>v.status!=='archived').map(v=><option key={v.id} value={v.id}>{v.label||v.original_sku}</option>)}</select></label>}
 {index>=0&&<button type="button" className="btn-ghost btn-sm" onClick={()=>update({...draft,facets:draft.facets.filter((_,i)=>i!==index)})}>Clear selection</button>}
 </div>;})}{entries.some(row=>meaningful(row.item))&&<button type="button" className="btn-ghost btn-sm" onClick={()=>update({...draft,confirmed:false,facets:[...draft.facets,blank(def.id)]})}>Add another {name.toLowerCase()}</button>}
 </section>;
 })}</div>
 {existing.filter(f=>!definitions.some(d=>d.id===f.facet_id)).map(saved)}
 {scope.includes('fragrance')&&detail.variants.some(v=>v.status!=='archived'&&v.sellable_kind!=='single')&&<label className="check"><input type="checkbox" checked={draft.setSingleProfileConfirmed??false} onChange={e=>update({...draft,setSingleProfileConfirmed:e.target.checked,confirmed:false})}/>All included items share one fragrance profile, confirmed from the label or official information. Leave unchecked for multi-fragrance sets.</label>}
 {scope.includes('fragrance')&&<p className="admin-helper">Concentration does not establish longevity. Occasion and season reflect your store’s curation.</p>}
 {hasAdds&&<div className="discovery-confirmation"><label>Checked against<select value={draft.sourceType} onChange={e=>update({...draft,sourceType:e.target.value,confirmed:false})}><option value="package">Product label / packaging</option><option value="official_page">Official product page</option></select></label>{draft.sourceType==='official_page'&&<label>Official product link<input type="url" value={draft.sourceUrl} maxLength={2000} onChange={e=>update({...draft,sourceUrl:e.target.value})}/></label>}<label className="check"><input type="checkbox" checked={draft.confirmed} onChange={e=>update({...draft,confirmed:e.target.checked})}/>I checked these selections against the label or official product information. Occasion/season selections reflect my store’s curation.</label></div>}
 {(draft.removeFacets.length>0||draft.removeConcerns.length>0)&&<button type="button" className="btn-ghost" onClick={()=>update({...draft,removeFacets:[],removeConcerns:[]})}>Undo removals</button>}
 <small>Save below to keep these selections. Blank optional fields do not block saving or publishing.</small>
 </>}
 </SectionCard>;
}
