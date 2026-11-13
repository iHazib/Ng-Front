'use client';

import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { CommerceContext } from './CommerceContext';
import {cartWireLine,type DealResult} from '@/lib/catalog/deals';
import type {CartQuote} from '@/lib/catalog/commerce';
import { articleSlugs } from '@/lib/catalog/commerce-samples';
import { Actions, assign, byId, Node, nodes, type MarkupNode, type Overrides } from './SampleMarkup';
import type { ApprovedPreview } from '@/lib/catalog/approved-preview';
import type { CatalogResult } from '@/lib/catalog/public-types';
import { resolveMedia } from '@/lib/catalog/media';
import './tokens.css';
import './reference.css';
import './mobile.css';

const money = (amount: number) => `Rs ${amount.toLocaleString('en-PK')}`;
const storageKey = 'ng-approved-sample-bag-v1';

export function ApprovedHomepage({ sample, children }: { sample: ApprovedPreview; children?: ReactNode }) {
  const live=sample.kind==='published-catalog';
  const bagStorageKey=live?'ng-public-bag-v1':storageKey;
  const [pool,setPool]=useState(sample.catalog);
  const register=useCallback((item:ApprovedPreview['catalog'][number])=>setPool(current=>{const old=current.find(p=>p.id===item.id);return JSON.stringify(old)===JSON.stringify(item)?current:[...current.filter(p=>p.id!==item.id),item];}),[]);
  const router = useRouter();
  const [bag, setBag] = useState<Record<string, number>>({});
  const [loaded, setLoaded] = useState(false);
  const [quote,setQuote]=useState<CartQuote|null>(null);
  const [quoteError,setQuoteError]=useState('');
  const [checking,setChecking]=useState(false);
  const [refresh,setRefresh]=useState(0);
  const requestSequence=useRef(0);
  const rememberedPrices=useRef<Record<string,number>>({});
  const rememberedDeals=useRef<Record<string,number>>({});
  const [checkout, setCheckout] = useState(false);
  const [confirmed, setConfirmed] = useState(false);
  const article = 0;
  const [preview, setPreview] = useState('');
  const [toast, setToast] = useState('');
  const [added, setAdded] = useState<string | null>(null);
  const cart = useRef<HTMLDialogElement>(null);
  const articleDialog = useRef<HTMLDialogElement>(null);
  const previewDialog = useRef<HTMLDialogElement>(null);
  const toastTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const addedTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const tree: MarkupNode = { tag: 'div', attrs: { class: 'storefront', 'data-preview-ready': String(loaded) }, children: sample.nodes };
  useEffect(() => {
    try {
      const saved: unknown = JSON.parse(localStorage.getItem(bagStorageKey) || '{}');
      const clean: Record<string, number> = {};
      if(live&&saved&&typeof saved==='object'){
        for(const id of Object.keys(saved).filter(id=>/^(deal:)?[0-9a-f-]{36}$/i.test(id)).slice(0,20)){
          const n=(saved as Record<string,unknown>)[id];if(typeof n==='number'&&Number.isInteger(n)&&n>0&&n<=99)clean[id]=n;
        }
        try{rememberedPrices.current=JSON.parse(localStorage.getItem('ng-public-prices-v1')||'{}');rememberedDeals.current=JSON.parse(localStorage.getItem('ng-public-deal-revisions-v1')||'{}');}catch{/* Optional remembered price notifications. */}
      }
      if (!live&&saved && typeof saved === 'object') for (const product of sample.catalog) {
        const quantity = (saved as Record<string, unknown>)[product.id];
        if (typeof quantity === 'number' && Number.isInteger(quantity) && quantity > 0 && quantity <= 99) clean[product.id] = quantity;
      }
      setBag(clean);
    } catch { /* Preview persistence is optional when storage is unavailable. */ }
    setLoaded(true);
    return () => { clearTimeout(toastTimer.current); clearTimeout(addedTimer.current); };
  }, [sample.catalog,live,bagStorageKey]);
  useEffect(() => { if (loaded) { try { localStorage.setItem(bagStorageKey, JSON.stringify(bag)); } catch { /* Optional local bag. */ } } }, [bag, loaded,bagStorageKey]);
  useEffect(()=>{
    if(!live||!loaded)return;
    const sequence=++requestSequence.current,ids=Object.keys(bag);
    if(!ids.length){setQuote(null);setChecking(false);setQuoteError('');return;}
    setChecking(true);setQuoteError('');
    const lines=ids.map(id=>cartWireLine(id,bag[id],rememberedPrices.current[id],rememberedDeals.current[id]));
    void Promise.all([
      fetch('/api/commerce',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'quote',lines}),cache:'no-store'}).then(async r=>{const data=await r.json();if(!r.ok)throw Error(data.error);return data as CartQuote;}),
      ids.some(id=>!id.startsWith('deal:'))?fetch('/api/catalog?'+new URLSearchParams(ids.filter(id=>!id.startsWith('deal:')).map(id=>['variant',id])),{cache:'no-store'}).then(async r=>{if(!r.ok)throw Error();return r.json() as Promise<CatalogResult>;}):Promise.resolve({products:[]} as Pick<CatalogResult,'products'>),
      ids.some(id=>id.startsWith('deal:'))?fetch('/api/deals?'+new URLSearchParams(ids.filter(id=>id.startsWith('deal:')).map(id=>['id',id.slice(5)])),{cache:'no-store'}).then(async r=>{if(!r.ok)throw Error();return r.json() as Promise<DealResult>;}):Promise.resolve({deals:[]} as Pick<DealResult,'deals'>)
    ]).then(([q,result,deals])=>{
      if(sequence!==requestSequence.current)return;setQuote(q);
      const items=result.products.flatMap(p=>p.variants.map(v=>({id:v.id,name:p.name+' · '+v.label,brand:p.brand,price:v.priceMinor/100,image:v.media[0]?resolveMedia(v.media[0]).src:'',available:v.available,href:'/products/'+p.slug})));
      const dealItems=deals.deals.map(d=>({id:'deal:'+d.id,name:d.title,brand:'Assembled deal',price:d.priceMinor/100,image:d.media[0]?resolveMedia(d.media[0]).src:'',available:d.available,href:'/deals/'+d.slug}));
      setPool(current=>[...current.filter(p=>!ids.includes(p.id)),...items,...dealItems]);
      for(const line of q.lines){if(line.price_minor!==null)rememberedPrices.current[line.id]=line.price_minor;if(line.dealRevision)rememberedDeals.current[line.id]=line.dealRevision;}
      try{localStorage.setItem('ng-public-prices-v1',JSON.stringify(rememberedPrices.current));localStorage.setItem('ng-public-deal-revisions-v1',JSON.stringify(rememberedDeals.current));}catch{/* Optional storage. */}
    }).catch(()=>{if(sequence===requestSequence.current){setQuote(null);setQuoteError('Current prices and availability could not be checked. Retry before checkout.');}}).finally(()=>{if(sequence===requestSequence.current)setChecking(false);});
    return()=>{requestSequence.current++;};
  },[bag,loaded,live,refresh]);
  useEffect(()=>{const reload=()=>setRefresh(n=>n+1);window.addEventListener('focus',reload);return()=>window.removeEventListener('focus',reload);},[]);
  useEffect(() => { if (checkout) cart.current?.querySelector<HTMLInputElement>('input')?.focus(); }, [checkout]);
  const count = Object.values(bag).reduce((sum, quantity) => sum + quantity, 0);
  const total = live?(quote?.subtotal_minor??0)/100:pool.reduce((sum, product) => sum + product.price * (bag[product.id] || 0), 0);
  const notify = (message: string) => {
    setToast(message); clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(''), 2500);
  };
  const refreshQuote=useCallback(()=>setRefresh(n=>n+1),[]);
  const quantity = (id: string, amount: number) => { if(live&&amount>0&&!bag[id]&&Object.keys(bag).length>=20){notify('Your bag supports up to 20 different options.');return;}if(live)setChecking(true);setBag(current => {
    const product=pool.find(product=>product.id===id);
    if ((!live&&!product) || !Number.isInteger(amount)) return current;
    const next = { ...current };
    if (amount <= 0) delete next[id]; else next[id] = Math.min(amount,99);
    return next;
  });};
  const cartView = () => { setCheckout(false); setConfirmed(false); };
  const map: Overrides = new Map();
  const id = (name: string, props: Record<string, unknown>) => assign(map, byId(tree, name), props);
  if (children !== undefined) id('top', { children });
  id('cart-drawer', { ref: cart, onClick: (event: React.MouseEvent<HTMLDialogElement>) => { if (event.target === event.currentTarget && event.clientX < event.currentTarget.getBoundingClientRect().left) cart.current?.close(); } });
  id('cart-close', { onClick: () => cart.current?.close() });
  id('cart-item-count', { children: count });
  id('cart-summary', { hidden: checkout || !count });
  id('cart-total', { children: live&&(checking||quoteError)?'Checking current total':money(total) });
  id('checkout-total', { children: money(total) });
  id('continue-shopping', { onClick: () => cart.current?.close() });
  id('checkout-open', { onClick: () => { cart.current?.close(); router.push('/checkout'); } });
  id('cart-title', { children: <Link href="/cart">Shopping bag <span id="cart-item-count">{count}</span></Link> });
  id('checkout-back', { onClick: cartView });
  id('checkout-preview', { hidden: true, children: null });
  id('checkout-form', { hidden: confirmed, onSubmit: (event: React.FormEvent) => { event.preventDefault(); setConfirmed(true); } });
  id('checkout-confirmation', { hidden: !confirmed });
  id('cart-items', { hidden: checkout, children: live&&count&&!quote?.valid ? <><p role="status">{quoteError||'Your bag needs an availability check. Review it before checkout.'}</p><Link href="/cart" onClick={()=>cart.current?.close()}>Review bag</Link></> : count ? pool.filter(product => bag[product.id]).map(product => <article className="cart-line" key={product.id}>
    {product.image&&<img src={product.image} alt={product.name} />}<div><small>{product.brand}</small><h3>{product.name}</h3><p>{money(product.price * bag[product.id])}</p>
      <div className="cart-line-controls"><div className="quantity"><button aria-label={`Decrease ${product.name} quantity`} onClick={() => quantity(product.id, bag[product.id] - 1)}>−</button><span>{bag[product.id]}</span><button aria-label={`Increase ${product.name} quantity`} disabled={bag[product.id] === 99} onClick={() => quantity(product.id, bag[product.id] + 1)}>+</button></div><button className="remove-item" aria-label={`Remove ${product.name}`} onClick={() => { quantity(product.id, 0); notify('Removed from your bag'); }}>Remove</button></div>
    </div>
  </article>) : <div className="empty-bag"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1"><path d="M5 7h14l1 14H4L5 7Z" /><path d="M8 8V6a4 4 0 0 1 8 0v2" /></svg><h3>Your next favourite awaits.</h3><p>Explore the edit and add something<br />you would love to make room for.</p><button className="button" onClick={() => { cart.current?.close(); document.getElementById('products')?.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth' }); }}>Discover the edit ↗</button></div> });
  const currentArticle = sample.articles[article];
  id('article-dialog', { ref: articleDialog });
  id('article-close', { onClick: () => articleDialog.current?.close() });
  id('article-shop', { onClick: () => articleDialog.current?.close() });
  id('article-image', { src: currentArticle.image, alt: currentArticle.title });
  id('article-category', { children: `${currentArticle.category} · ${currentArticle.time}` });
  id('article-title', { children: currentArticle.title });
  id('article-body', { children: currentArticle.body.map((node, index) => <Node key={index} node={node} />) });
  id('preview-dialog', { ref: previewDialog });
  const previewNode = byId(tree, 'preview-dialog');
  assign(map, nodes(previewNode, n => n.tag === 'h3')[0], { children: preview });
  assign(map, nodes(previewNode, n => n.tag === 'p')[0], { children: ['Instagram', 'Facebook'].includes(preview) ? `Your official ${preview} profile URL will be connected here in the finished website.` : `This wireframe reserves a place for your ${preview.toLowerCase()} page. Approved content will be connected during implementation.` });
  assign(map, nodes(previewNode, n => n.tag === 'button')[0], { onClick: () => previewDialog.current?.close() });
  id('bag-status', { children: toast, className: `bag-status${toast ? ' show' : ''}` });
  return <Actions.Provider value={{ count, added,
    add: productId => {
      const product = pool.find(item => item.id === productId);
      if (!product) return;
      if ((bag[productId] || 0) >= (live?product.available??0:99)) { notify(live?'Choose a quantity within current availability.':'Preview quantity limit reached'); return; }
      quantity(productId, (bag[productId] || 0) + 1);
      notify(`${product.brand} added to your bag`);
      setAdded(productId); clearTimeout(addedTimer.current); addedTimer.current = setTimeout(() => setAdded(null), 1200);
    },
    openBag: () => { cartView(); cart.current?.showModal(); },
    openArticle: index => { router.push(`/the-edit/${articleSlugs[index]}`); },
    openPreview: name => {
      const routes: Record<string, string> = { 'Shipping': '/shipping', 'Delivery': '/shipping', 'Delivery information': '/shipping', 'Shipping & delivery': '/shipping', 'Returns': '/returns', 'Returns & exchanges': '/returns', 'Privacy policy': '/privacy', 'Privacy Policy': '/privacy', 'Terms & conditions': '/terms', 'Terms & Conditions': '/terms', 'Contact': '/contact', 'Contact us': '/contact', 'Customer care': '/customer-care' };
      Object.assign(routes, { 'Delivery & tracking': '/shipping', 'FAQs': '/faqs', 'Returns & refunds': '/returns', 'Shipping policy': '/shipping' });
      if (routes[name]) { router.push(routes[name]); return; }
      setPreview(name); previewDialog.current?.showModal();
    },
  }}><CommerceContext.Provider value={{ quantities: bag, ready: loaded, setQuantity: quantity, notify,...(live?{items:pool,register,quote,quoteError,checking,refreshQuote,clear:()=>setBag({})}:{}) }}><Node node={tree} overrides={map} /></CommerceContext.Provider></Actions.Provider>;
}
