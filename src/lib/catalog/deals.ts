import type {Media} from './types';
export interface DealComponent {id:string;sku:string;name:string;label:string;slug?:string;quantity:number;eligible?:boolean}
export interface PublicDeal {id:string;slug:string;title:string;description:string|null;priceMinor:number;revision:number;available:number;standaloneMinor:number;components:DealComponent[];media:Media[];homePosition:number|null}
export interface DealResult {total:number;page:number;deals:PublicDeal[];homeOrder?:{id:string;kind:'product'|'deal';position:number}[]}
export const cartWireLine=(key:string,quantity:number,expectedPriceMinor?:number,expectedDealRevision?:number)=>({id:key.startsWith('deal:')?key.slice(5):key,...(key.startsWith('deal:')?{kind:'deal' as const}:{}),quantity,...(expectedPriceMinor===undefined?{}:{expectedPriceMinor}),...(expectedDealRevision===undefined?{}:{expectedDealRevision})});
