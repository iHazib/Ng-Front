import 'server-only';
import { assets } from '@/config/assets';
import type { Media, SampleHomepage } from './types';

const preview = (path: `/assets/${string}`, alt: string): Media => ({ source: { kind: 'local-preview', path }, alt });

// Approved visual fixtures only. These IDs are deliberately not production UUIDs or SKUs.
const homepage: SampleHomepage = {
  kind: 'sample',
  heroes: [
    { id: 'brand-introduction', className: 'selected-brand', media: preview(assets.hero['brand-introduction'], 'Nook & Glow introduction featuring skincare, makeup, fragrances, bath and body, and cutlery'), title: 'Nook & Glow — beauty, home, and the everyday', cta: 'Explore our categories →' },
    { id: 'makeup', className: 'selected-makeup dark', media: preview(assets.hero.makeup, 'Charlotte Tilbury, NYX, Huda Beauty and MAC makeup on warm stone plinths'), title: 'Make room\nfor colour.', eyebrow: 'The makeup edit', summary: 'Discover Charlotte Tilbury, NYX, Huda Beauty and MAC.', cta: 'Explore makeup →' },
    { id: 'skincare', className: 'selected-skincare', media: preview(assets.hero.skincare, 'Clarins Cleansing Milk, Anua PDRN Hyaluron and Medicube Pink Collagen Capsule Cream'), title: 'Your daily\ncare ritual.', eyebrow: 'The skincare edit', summary: 'Discover Clarins, Anua and Medicube.', cta: 'Explore skincare →' },
    { id: 'fragrances', className: 'selected-fragrance dark', media: preview(assets.hero.fragrances, 'Elizabeth Arden Green Tea, Red Door and White Tea with DKNY Be Delicious'), title: 'A lasting\nimpression.', eyebrow: 'The fragrance edit', summary: 'Explore Elizabeth Arden and DKNY fragrance favourites.', cta: 'Explore fragrances →' },
  ],
  articles: [
    { id: 'sample:skincare', theme: 'sage', title: 'A cleanser that fits your routine.', summary: 'From foaming textures to creamier cleansers, start with the product type that fits your everyday routine. A closer look at the details that help you choose.', media: preview(assets.editorial.skincare, 'CeraVe cleanser editorial') },
    { id: 'sample:table', theme: 'warm', title: 'The art of an everyday table.', summary: 'Warm metals, soft linen and a few considered pieces can make even a quiet meal feel special.', media: preview(assets.editorial['table-styling'], 'Gold cutlery and linen, table styling editorial') },
    { id: 'sample:makeup', theme: 'blush', title: 'A little colour, your way.', summary: 'Cream, liquid or powder: explore blush textures and soft finishing touches that bring your everyday makeup together.', media: preview(assets.editorial.makeup, 'Soft rose makeup, blush editorial') },
  ],
  products: Object.entries(assets.products).map(([id, product]) => ({ id: `sample:${id}`, name: product.name, media: preview(product.primary, product.name) })),
};

export function getSampleHomepage(): SampleHomepage {
  return structuredClone(homepage);
}
