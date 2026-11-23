'use client';

import { createContext, createElement, useContext, type ReactNode } from 'react';
import Link from 'next/link';
import { resolveMedia } from '@/lib/catalog/media';
import { Carousel, CategoryCarousel, ScrollRail } from './SampleCarousels';
import { SampleHeader } from './SampleHeader';
import { referenceLink } from '@/lib/catalog/commerce-samples';

export interface MarkupNode { tag: string; attrs: Record<string, string>; children: Array<MarkupNode | string> }
export type Overrides = Map<MarkupNode, Record<string, unknown>>;
export interface SampleActions {
  count: number;
  add: (id: string) => void;
  openBag: () => void;
  openArticle: (index: number) => void;
  openPreview: (name: string) => void;
  added: string | null;
}
export const Actions = createContext<SampleActions | null>(null);
export function useActions() {
  const actions = useContext(Actions);
  if (!actions) throw new Error('Sample actions require the preview storefront');
  return actions;
}
export const hasClass = (node: MarkupNode, name: string) => (node.attrs.class || '').split(' ').includes(name);
export function nodes(node: MarkupNode, predicate: (node: MarkupNode) => boolean): MarkupNode[] {
  return [ ...(predicate(node) ? [node] : []), ...node.children.flatMap(child => typeof child === 'string' ? [] : nodes(child, predicate)) ];
}
export const byClass = (node: MarkupNode, name: string) => nodes(node, item => hasClass(item, name));
export const byId = (node: MarkupNode, id: string) => nodes(node, item => item.attrs.id === id)[0];
export function assign(map: Overrides, node: MarkupNode | undefined, props: Record<string, unknown>) {
  if (node) map.set(node, { ...map.get(node), ...props });
}
const names: Record<string, string> = { class: 'className', tabindex: 'tabIndex', for: 'htmlFor', autocomplete: 'autoComplete', 'stroke-width': 'strokeWidth', 'stroke-linecap': 'strokeLinecap', 'stroke-linejoin': 'strokeLinejoin', viewbox: 'viewBox', srcset: 'srcSet', fetchpriority: 'fetchPriority', 'fill-rule': 'fillRule', 'clip-rule': 'clipRule' };
function attributes(node: MarkupNode): Record<string, unknown> {
  const props: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(node.attrs)) {
    if (key.startsWith('on') || key === 'data-media') continue;
    if (key === 'style') {
      props.style = Object.fromEntries(value.split(';').filter(Boolean).map(pair => {
        const colon = pair.indexOf(':');
        return [pair.slice(0, colon).trim().replace(/-([a-z])/g, (_, c: string) => c.toUpperCase()), pair.slice(colon + 1).trim()];
      }));
    } else if (['hidden', 'inert', 'required', 'disabled', 'checked', 'multiple'].includes(key)) props[key] = true;
    else props[names[key] || key] = value;
  }
  if (node.tag === 'img') {
    Object.assign(props,resolveMedia(node.attrs['data-media']?JSON.parse(node.attrs['data-media']):{ source: { kind: 'local-preview', path: node.attrs.src as `/assets/${string}` }, alt: node.attrs.alt || '' }));
  }
  return props;
}

/** React elements from reviewed inert markup; no HTML/script injection or DOM event installation. */
export function Plain({ node, overrides = new Map() }: { node: MarkupNode; overrides?: Overrides }) {
  const actions = useActions();
  const props = attributes(node);
  if (node.tag === 'h3'&&node.attrs['data-product-href'])props.children=<a href={node.attrs['data-product-href']}>{node.children.filter(c=>typeof c==='string').join('')}</a>;
  if (node.tag === 'a') {
    const href = referenceLink(node.attrs);
    if (href) props.href = href;
    else if (node.attrs.href?.startsWith('#')) props.href = `/${node.attrs.href}`;
  }
  if (node.attrs['data-add'] !== undefined) {
    props.onClick = () => actions.add(node.attrs['data-add']);
    if (actions.added === node.attrs['data-add']) props.className += ' added';
  }
  if (node.attrs['data-blog'] !== undefined) props.onClick = () => actions.openArticle(Number(node.attrs['data-blog']));
  if (node.attrs['data-preview']) props.onClick = () => actions.openPreview(node.attrs['data-preview']);
  if (hasClass(node, 'bag-button')) { props.onClick = actions.openBag; props['aria-label'] = `Shopping bag, ${actions.count} items`; }
  if (hasClass(node, 'bag-count')) props.children = actions.count;
  Object.assign(props, overrides.get(node));
  if (!('children' in props) && node.children.length) props.children = node.children.map((child, index) => <Node key={index} node={child} overrides={overrides} />);
  if(node.tag==='a'&&typeof props.href==='string'&&props.href.startsWith('/')&&!props.href.startsWith('//'))return createElement(Link,{...props,href:props.href});
  return createElement(node.tag,props);
}
export function Node({ node, overrides }: { node: MarkupNode | string; overrides?: Overrides }): ReactNode {
  if (typeof node === 'string') return node;
  if (hasClass(node, 'ng-header')) return <SampleHeader node={node} />;
  if (hasClass(node, 'hero-carousel')) return <Carousel node={node} kind="hero" />;
  if (hasClass(node, 'edit-carousel')) return <Carousel node={node} kind="edit" />;
  if (hasClass(node, 'product-gallery')) return <Carousel node={node} kind="gallery" />;
  if (hasClass(node, 'corner-section')) return <CategoryCarousel node={node} />;
  if (hasClass(node, 'brands')) return <ScrollRail node={node} kind="brands" />;
  if (hasClass(node, 'needs')) return <ScrollRail node={node} kind="concerns" />;
  return <Plain node={node} overrides={overrides} />;
}
