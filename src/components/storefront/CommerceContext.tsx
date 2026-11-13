'use client';
import { createContext, useContext } from 'react';
import type {CartQuote} from '@/lib/catalog/commerce';
export interface PreviewBag {
  quantities: Readonly<Record<string, number>>;
  ready: boolean;
  quote?:CartQuote|null;
  quoteError?:string;
  checking?:boolean;
  refreshQuote?:()=>void;
  clear?:()=>void;
  setQuantity: (id: string, amount: number) => void;
  notify: (message: string) => void;
  items?: {id:string;name:string;brand:string;price:number;image:string;available?:number;href?:string}[];
  register?: (item:{id:string;name:string;brand:string;price:number;image:string;available:number;href:string})=>void;
}
export const CommerceContext = createContext<PreviewBag | null>(null);
export function usePreviewBag() {
  const bag = useContext(CommerceContext);
  if (!bag) throw new Error('Preview commerce requires its storefront provider');
  return bag;
}
