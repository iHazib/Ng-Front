import {discoveryLabel,type DiscoveryDraft} from './discovery';
export interface SavedDiscovery {
 facets:{id:string;facet_id:string;variant_id:string|null;option_id:string|null;integer_value:number|null;decimal_value:number|null;boolean_value:boolean|null;unit:string|null;status:string;facet_values?:{label:string}|null}[];
 concerns:{concern_id:string;status:string}[];
}
/** Check the existing post-save read rather than trusting an HTTP success alone. */
export function missingSavedDiscovery(draft:DiscoveryDraft,saved:SavedDiscovery):string[]{
 const missing:string[]=[];
 for(const input of draft.facets){
  const found=saved.facets.some(f=>{
   if(f.facet_id!==input.facetId||(f.variant_id??'')!==input.variantId||f.status!=='approved')return false;
   if(input.newValue.trim())return f.facet_values?.label?.trim().toLowerCase()===input.newValue.trim().toLowerCase();
   if(f.option_id!==null)return f.option_id===input.value;
   if(f.boolean_value!==null)return String(f.boolean_value)===input.value;
   const value=f.integer_value??f.decimal_value;
   return value!==null&&Number(input.value)===Number(value)&&(!f.unit||f.unit===input.unit);
  });
  if(!found)missing.push(discoveryLabel(input.facetId));
 }
 for(const id of draft.concerns)if(!saved.concerns.some(c=>c.concern_id===id&&c.status==='approved'))missing.push('Shop by concern');
 if(draft.removeFacets.some(id=>saved.facets.some(f=>f.id===id)))missing.push('Removed filter');
 if(draft.removeConcerns.some(id=>saved.concerns.some(c=>c.concern_id===id)))missing.push('Removed concern');
 return [...new Set(missing)];
}
