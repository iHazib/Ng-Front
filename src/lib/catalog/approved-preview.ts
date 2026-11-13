import 'server-only';
import fixture from './approved-homepage.json';
import type { MarkupNode } from '@/components/storefront/SampleMarkup';
import {sampleProducts} from './commerce-samples';

export interface ApprovedPreview {
  kind: 'approved-sample' | 'published-catalog';
  nodes: Array<MarkupNode | string>;
  catalog: Array<{ id: string; name: string; brand: string; price: number; image: string; available?: number; href?: string }>;
  articles: Array<{ title: string; category: string; time: string; image: string; summary: string; body: Array<MarkupNode | string> }>;
}

// Generated from reviewed markup, isolated from any production catalog. Prices,
// category choices and editorial copy are approved visual fixtures, not live data.
export function getApprovedPreview(): ApprovedPreview {
  const preview=structuredClone(fixture) as ApprovedPreview;
  let heroSeen=false;
  const visit=(nodes:ApprovedPreview['nodes'])=>nodes.forEach(node=>{if(typeof node!=='string'){
    if(node.tag==='h3'){const product=sampleProducts.find(p=>node.children.length===1&&node.children[0]===p.name);if(product)node.attrs['data-product-href']='/products/'+product.slug;}
    if(node.tag==='img'){
      const isHero=(node.attrs.class||'').split(' ').includes('hero-photo');
      const isHeaderLogo=(node.attrs.src||'').includes('/assets/brand/logo-header.png');
      node.attrs.decoding='async';
      if(isHero){node.attrs.loading=heroSeen?'lazy':'eager';node.attrs.fetchpriority=heroSeen?'low':'high';heroSeen=true;}
      else if(isHeaderLogo){node.attrs.loading='eager';node.attrs.fetchpriority='high';}
      else if(!node.attrs.loading)node.attrs.loading='lazy';
    }
    visit(node.children);
  }});
  visit(preview.nodes);
  return preview;
}
