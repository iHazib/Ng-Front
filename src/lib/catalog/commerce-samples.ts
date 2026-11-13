import { assets } from '@/config/assets';
import type { Media } from './types';

export const categories = [
  { slug: 'skincare', name: 'Skincare' }, { slug: 'makeup', name: 'Makeup' },
  { slug: 'fragrances', name: 'Fragrances' }, { slug: 'bath-body', name: 'Bath & Body' },
  { slug: 'cutlery', name: 'Cutlery' },
] as const;
export type Category = typeof categories[number]['slug'];
export interface SampleVariant { id: string; label: string; shade?: string; size?: string }
export interface CatalogSample {
  kind: 'sample'; id: string; slug: string; name: string; brand: string; brandSlug: string | null;
  category: Category; branch?: 'home-fragrance' | 'personal-fragrance'; pricePkr: number;
  media: Media[]; variants: SampleVariant[]; availability: 'preview-only';
  details: string | null; usage: string | null; approvedReviews: readonly never[];
}
const definitions = [
  { id: '0', slug: 'dark-spot-correcting-glow-serum', brand: 'AXIS-Y', brandSlug: 'axis-y', category: 'skincare', pricePkr: 3799 },
  { id: '1', slug: 'foaming-cleanser', brand: 'CeraVe', brandSlug: 'cera-ve', category: 'skincare', pricePkr: 5499 },
  { id: '2', slug: 'on-the-glow-blush-ruby', brand: 'Pixi', brandSlug: 'pixi', category: 'makeup', pricePkr: 3499 },
  { id: '3', slug: 'gold-stainless-cutlery-set', brand: 'Cutlery', brandSlug: null, category: 'cutlery', pricePkr: 2899 },
] as const;
// Retain the original bag identifiers 0–3. They are isolated sample keys, not SKUs
// or production UUIDs. No alternate shades, sizes, stock or claims are inferred.
export const sampleProducts: CatalogSample[] = definitions.map(item => ({
  ...item, kind: 'sample', name: assets.products[item.slug].name,
  media: [{ source: { kind: 'local-preview', path: assets.products[item.slug].primary }, alt: assets.products[item.slug].name }],
  variants: [{ id: `sample:${item.id}:default`, label: item.id === '2' ? 'Ruby' : 'Supplied sample', ...(item.id === '2' ? { shade: 'Ruby' } : {}) }],
  availability: 'preview-only', details: null, usage: null, approvedReviews: [],
}));
export const sampleBrands = [
  { slug: 'axis-y', name: 'AXIS-Y' }, { slug: 'pixi', name: 'Pixi' }, { slug: 'cera-ve', name: 'CeraVe' },
  { slug: 'soap-and-glory', name: 'Soap & Glory' }, { slug: 'the-ordinary', name: 'The Ordinary' },
  { slug: 'sk-ii', name: 'SK-II' }, { slug: 'cetaphil', name: 'Cetaphil' }, { slug: 'origins', name: 'Origins' },
  { slug: 'neutrogena', name: 'Neutrogena' }, { slug: 'boots', name: 'Boots' },
  { slug: 'la-roche-posay', name: 'La Roche-Posay' }, { slug: 'bath-and-body-works', name: 'Bath & Body Works' },
] as const;
export const articleSlugs = ['a-cleanser-that-fits-your-routine', 'the-art-of-an-everyday-table', 'a-little-colour-your-way'] as const;
export const carePages: Record<string, string> = {
  'customer-care': 'Customer care', 'contact': 'Contact us', 'about': 'About Nook & Glow',
  'shipping': 'Delivery information', 'returns': 'Returns & exchanges', 'privacy': 'Privacy policy', 'terms': 'Terms & conditions',
  'faqs': 'Frequently asked questions',
};
export const formatPkr = (amount: number) => `Rs ${amount.toLocaleString('en-PK')}`;
export interface CheckoutSlots { shipping: readonly { id: string; label: string; pricePkr: number | null }[]; payment: readonly { id: string; label: string }[] }
export const previewCheckoutSlots: CheckoutSlots = { shipping: [], payment: [] };

export function referenceLink(attrs: Record<string, string>): string | undefined {
  if (attrs['data-route']) return attrs['data-route'];
  if (attrs.href === '#brands') return '/brands';
  if (attrs.href === '#journal') return '/the-edit';
  if (attrs.href === '#story') return '/about';
  return undefined;
}
