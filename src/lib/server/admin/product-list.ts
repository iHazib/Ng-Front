import 'server-only';
import {authorizeAdmin} from '../database/client';
import {AdminError} from './errors';
import {identifier} from './catalog';
import type {AdminFacet,AdminListFilters,AdminListResult} from '../../catalog/admin-list';
import {attentionOptions} from '../../catalog/admin-list';
function text(value:unknown,max=120){if(typeof value!=='string'||value.length>max)throw new AdminError('Search or filter is too long.');return value;}
export function listFilters(value:unknown):AdminListFilters{
 if(!value||typeof value!=='object'||Array.isArray(value))throw new AdminError('Invalid filters.');
 const f=value as Record<string,unknown>;
 if(Object.keys(f).some(k=>!['status','brand','category','type','facets','issues','mode','reminders'].includes(k)))throw new AdminError('Unknown filter.');
 const out:AdminListFilters={};
 for(const key of ['status','brand','category','type','mode','reminders'] as const)if(f[key]!==undefined)(out as Record<string,unknown>)[key]=text(f[key]);
 if(!['','draft','published','archived'].includes(out.status??'')||!['any','all'].includes(out.mode??'any')||!['','ignored'].includes(out.reminders??''))throw new AdminError('Invalid filter choice.');
 if(f.issues!==undefined){if(!Array.isArray(f.issues)||f.issues.length>attentionOptions.length||f.issues.some(x=>!attentionOptions.includes(x)))throw new AdminError('Invalid attention filter.');out.issues=[...new Set(f.issues)] as string[];}
 if(f.facets!==undefined){if(!f.facets||typeof f.facets!=='object'||Array.isArray(f.facets)||Object.keys(f.facets).length>30)throw new AdminError('Too many filters.');out.facets={};for(const [key,values] of Object.entries(f.facets)){text(key);if(!Array.isArray(values)||values.length>30)throw new AdminError('Too many filter values.');out.facets[key]=[...new Set(values.map(v=>text(v)))];}}
 return out;
}
async function installed<T>(work:()=>Promise<T>):Promise<T>{try{return await work();}catch(error){if(error instanceof Error&&error.message==='Database request failed (404).')throw new AdminError('The product list update is not installed. Apply and verify migration 013, then refresh. Do not rerun earlier installers.',503);throw error;}}
export async function adminCatalogList(token:string,params:URLSearchParams){
 const admin=await authorizeAdmin(token),q=text(params.get('q')??'',160),raw=params.get('filters')??'{}';
 if(raw.length>10000)throw new AdminError('Too many filters.');
 let parsed:unknown;try{parsed=JSON.parse(raw);}catch{throw new AdminError('Invalid filters.');}
 const offset=Number(params.get('offset')??0);if(!Number.isSafeInteger(offset)||offset<0||offset>100000)throw new AdminError('Invalid page.');
 return installed(()=>admin.rpc<AdminListResult>('admin_catalog_list',{p_query:q,p_filters:listFilters(parsed),p_offset:offset,p_limit:25}));
}
export async function adminCatalogOptions(token:string,category:string){const admin=await authorizeAdmin(token);return installed(()=>admin.rpc<AdminFacet[]>('admin_catalog_filter_options',{p_category:text(category)}));}
export async function setReminder(token:string,body:Record<string,unknown>){const admin=await authorizeAdmin(token);const key=text(body.key,255),episode=identifier(body.episode);if(typeof body.ignore!=='boolean')throw new AdminError('Choose Ignore or Restore.');try{return await installed(()=>admin.rpc('admin_catalog_reminder',{p_key:key,p_episode:episode,p_ignore:body.ignore}));}catch(error){if(error instanceof Error&&error.message==='Database request failed (400).')throw new AdminError('This reminder has changed. Refresh the list and try again.',409);throw error;}}
