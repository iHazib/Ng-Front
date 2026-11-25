import type {Media} from './types';
export interface PublicAttribute {key:string;label:string;value:string;valueLabel:string}
export interface PublicImage extends Media {id:string;variantId:string|null;primary:boolean;position:number}
export interface PublicVariant {id:string;sku:string;label:string;priceMinor:number;available:number;media:PublicImage[];attributes:PublicAttribute[]}
export interface PublicProduct {id:string;slug:string;name:string;brandId:string;brand:string;categoryId:string;category:string;scope:string;type:string;description:string|null;usage:string|null;keyBenefits?:string|null;priceMinor:number;variants:PublicVariant[]}
export interface FilterGroup {key:string;label:string;options:{value:string;label:string;count:number}[]}
export interface CatalogResult {version:1;total:number;page:number;size:number;products:PublicProduct[];filters:FilterGroup[]}
export interface PublicNavigation {version:1;facets?:{scope:string;key:string;label:string;value:string;value_label:string;count:number}[];brands:{id:string;name:string;count:number;scopes?:string[]}[];categories:{id:string;parent_id:string|null;name:string;scope:string|null}[];types:{id:string;name:string;scope:string;count:number}[];concerns:{id:string;name:string;count:number}[]}
export type CatalogQuery=Record<string,string|string[]|undefined>;
export const scopeRoutes:Record<string,string>={'skincare':'skincare','makeup':'makeup','bath-body':'bath-body','hair-care':'hair-care','cutlery':'cutlery','personal-fragrance':'fragrances/personal-fragrance','home-fragrance':'fragrances/home-fragrance'};
export const rootRoutes:Record<string,string[]>={skincare:['skincare'],makeup:['makeup'],'bath-body':['bath-body'],'hair-care':['hair-care'],cutlery:['cutlery'],fragrances:['personal-fragrance','home-fragrance'],'fragrances/home-fragrance':['home-fragrance'],'fragrances/personal-fragrance':['personal-fragrance']};
export const rootLabels:Record<string,string>={skincare:'Skincare',makeup:'Makeup','bath-body':'Bath & Body','hair-care':'Hair Care',cutlery:'Cutlery',fragrances:'Fragrances','fragrances/home-fragrance':'Home Fragrance','fragrances/personal-fragrance':'Personal Fragrance'};
export const pkrMinor=(amount:number)=>`Rs ${(amount/100).toLocaleString('en-PK',{maximumFractionDigits:2})}`;
export function queryValues(value:string|string[]|undefined){return [...new Set((Array.isArray(value)?value:[value]).filter((v):v is string=>Boolean(v)).map(v=>v.slice(0,160)))].slice(0,20);}
export function catalogParams(query:CatalogQuery){
 const filters:Record<string,string[]>={};
 for(const [key,value] of Object.entries(query))if(!['q','sort','page'].includes(key)&&/^[a-z][a-z0-9_-]{0,63}$/.test(key)){filters[key]=queryValues(value);if(Object.keys(filters).length>=16)break;}
 const sort=queryValues(query.sort)[0]??'relevance';
 return {q:queryValues(query.q)[0]??'',sort:['relevance','price-asc','price-desc','name'].includes(sort)?sort:'relevance',page:Math.max(1,Math.min(10000,Number.parseInt(queryValues(query.page)[0]??'1',10)||1)),filters};
}
