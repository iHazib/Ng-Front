'use client';
import {useState} from 'react';
import {ProductMarkdown} from '@/components/storefront/ProductMarkdown';
export function MarkdownEditor({name,label,initial='',optional=false,form,onValueChange}:{name:string;label:string;initial?:string;optional?:boolean;form?:string;onValueChange?:(value:string)=>void}){
 const [value,setValue]=useState(initial),[preview,setPreview]=useState(false);
 return <div className="markdown-editor"><div className="toolbar"><label htmlFor={'content-'+name}>{label}{optional&&<small>Optional</small>}</label><div className="actions" role="group" aria-label={label+' editor mode'}><button type="button" aria-pressed={!preview} onClick={()=>setPreview(false)}>Write</button><button type="button" aria-pressed={preview} onClick={()=>setPreview(true)}>Preview</button></div></div><textarea form={form} hidden={preview} id={'content-'+name} aria-label={label} name={name} value={value} onChange={e=>{setValue(e.target.value);onValueChange?.(e.target.value);}} rows={7} maxLength={30000}/>{preview&&<div className="markdown-preview" aria-label={label+' preview'}>{value?<ProductMarkdown source={value}/>:<p>Nothing to preview yet.</p>}</div>}<small>Use ## for headings, **bold**, - for bullets and 1. for steps. Add images through Images above.</small></div>;
}
