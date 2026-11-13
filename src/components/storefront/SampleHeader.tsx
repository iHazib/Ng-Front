'use client';

import { useEffect, useRef, useState, type KeyboardEvent, type PointerEvent, type FocusEvent } from 'react';
import { assign, byClass, byId, Plain, type MarkupNode, type Overrides } from './SampleMarkup';
import { useRouter } from 'next/navigation';
import { categories } from '@/lib/catalog/commerce-samples';

export function SampleHeader({ node }: { node: MarkupNode }) {
  const router = useRouter();
  const [menu, setMenu] = useState<string | null>(null);
  const [search, setSearch] = useState(false);
  const [mobileMenu, setMobileMenu] = useState(false);
  const [query, setQuery] = useState<string | null>(null);
  const header = useRef<HTMLElement>(null);
  const input = useRef<HTMLInputElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const mobileTrigger = useRef<HTMLButtonElement>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const pointerActivation = useRef<{ id: string; wasOpen: boolean } | null>(null);
  useEffect(() => {
    const outside = (event: globalThis.PointerEvent) => { if (!header.current?.contains(event.target as globalThis.Node)) { setMenu(null); setMobileMenu(false); } };
    document.addEventListener('pointerdown', outside);
    return () => { document.removeEventListener('pointerdown', outside); clearTimeout(timer.current); };
  }, []);
  useEffect(() => { if (search) input.current?.focus(); }, [search]);
  const close = () => { setMenu(null); setSearch(false); setMobileMenu(false); };
  const restoreMenuFocus = () => header.current?.querySelector<HTMLButtonElement>(`[aria-controls="${menu}"]`)?.focus();
  const map: Overrides = new Map();
  assign(map, node, {
    ref: header,
    className: `${node.attrs.class}${mobileMenu ? ' mobile-menu-open' : ''}`,
    onPointerEnter: () => clearTimeout(timer.current),
    onPointerLeave: (event: PointerEvent) => { if (event.pointerType === 'mouse') timer.current = setTimeout(() => setMenu(null), 180); },
    onBlur: (event: FocusEvent) => { if (!event.currentTarget.contains(event.relatedTarget)) setMenu(null); },
    onKeyDown: (event: KeyboardEvent) => { if (event.key === 'Escape') { if (search) trigger.current?.focus(); else if (mobileMenu) mobileTrigger.current?.focus(); else restoreMenuFocus(); close(); } },
  });
  const intro = byClass(node, 'nav-intro')[0];
  assign(map, intro, { children: <><span className="desktop-nav-intro">{intro.children.filter(child => typeof child === 'string').join('')}</span><button ref={mobileTrigger} type="button" className="mobile-menu-toggle" aria-label={mobileMenu ? 'Close menu' : 'Open menu'} aria-expanded={mobileMenu} aria-controls="storefront-navigation" onClick={() => { setMobileMenu(!mobileMenu); setMenu(null); setSearch(false); }}><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" aria-hidden="true">{mobileMenu ? <path d="m6 6 12 12M6 18 18 6" /> : <path d="M4 6h16M4 12h16M4 18h16" />}</svg></button></> });
  assign(map, byClass(node, 'ng-links')[0], { id: 'storefront-navigation', onClick: (event: React.MouseEvent) => { if ((event.target as HTMLElement).closest('a')) close(); } });
  for (const button of byClass(node, 'category-toggle')) {
    const id = button.attrs['aria-controls'];
    const open = () => { clearTimeout(timer.current); setMenu(id); setSearch(false); };
    assign(map, button, {
      'aria-expanded': menu === id,
      onPointerEnter: (event: PointerEvent) => { if (event.pointerType === 'mouse' && matchMedia('(min-width: 1051px)').matches) open(); },
      onFocus: () => { if (matchMedia('(min-width: 1051px)').matches) open(); },
      onPointerDown: () => { pointerActivation.current = { id, wasOpen: menu === id }; },
      onClick: () => {
        const pointer = pointerActivation.current;
        setMenu(current => (pointer?.id === id ? pointer.wasOpen : current === id) ? null : id);
        pointerActivation.current = null; setSearch(false);
      },
    });
  }
  for (const panel of byClass(node, 'category-menu')) assign(map, panel, {
    hidden: menu !== panel.attrs.id,
    onClick: (event: React.MouseEvent) => { if ((event.target as HTMLElement).closest('a')) close(); },
  });
  for (const button of byClass(node, 'menu-close')) assign(map, button, { onClick: () => { restoreMenuFocus(); setMenu(null); } });
  assign(map, byClass(node, 'search-trigger')[0], { ref: trigger, 'aria-label': 'Search products', 'aria-expanded': search, onClick: () => { setSearch(!search); setMenu(null); setMobileMenu(false); }, onPointerEnter: () => setMenu(null) });
  assign(map, byId(node, 'nav-search'), { hidden: !search });
  const searchInput = byClass(node, 'search-field')[0].children.find(child => typeof child !== 'string' && child.tag === 'input') as MarkupNode;
  assign(map, searchInput, { ref: input, value: query ?? '', onChange: (event: React.ChangeEvent<HTMLInputElement>) => setQuery(event.target.value), onKeyDown: (event: KeyboardEvent) => { if (event.key === 'Enter') { event.preventDefault(); close(); router.push(`/search?q=${encodeURIComponent(query || '')}`); } } });
  const closeSearch = byClass(node, 'search-field')[0].children.find(child => typeof child !== 'string' && child.tag === 'button') as MarkupNode;
  assign(map, closeSearch, { onClick: () => { setSearch(false); trigger.current?.focus(); } });
  if (query !== null) {
    const matches = ['Skincare', 'Makeup', 'Fragrances', 'Bath & Body', 'Cutlery', 'Brands'].filter(name => name.toLowerCase().includes(query.trim().toLowerCase()));
    assign(map, byId(node, 'search-results'), { children: node.attrs['data-catalog-mode']==='published'?<a href={`/search?q=${encodeURIComponent(query)}`}>Search products, brands and verified concerns →</a>:<>{matches.length ? matches.map(name => <a key={name} href={name === 'Brands' ? '/brands' : `/${categories.find(category => category.name === name)?.slug}`}>{name}</a>) : 'No category match. Browse the product edit below.'}<a href={`/search?q=${encodeURIComponent(query)}`}>Search sample products →</a></> });
  }
  for (const name of ['ng-logo', 'bag-button']) assign(map, byClass(node, name)[0], { onPointerEnter: () => setMenu(null) });
  return <Plain node={node} overrides={map} />;
}
