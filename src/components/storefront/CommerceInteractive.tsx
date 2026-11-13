'use client';
import Link from 'next/link';
import { useEffect, useRef, useState, type FormEvent } from 'react';
import { usePreviewBag } from './CommerceContext';
import { formatPkr, sampleProducts, type CatalogSample, type CheckoutSlots } from '@/lib/catalog/commerce-samples';
import { resolveMedia } from '@/lib/catalog/media';

export function Filters({ path, brand, sort, q, brands }: { path: string; brand: string; sort: string; q: string; brands: { slug: string; name: string }[] }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const fields = (prefix: string) => <>
    {q && <input type="hidden" name="q" value={q} />}
    <label htmlFor={`${prefix}-brand`}>Brand</label><select id={`${prefix}-brand`} name="brand" defaultValue={brand}><option value="">All sample brands</option>{brands.map(item => <option key={item.slug} value={item.slug}>{item.name}</option>)}</select>
    <label htmlFor={`${prefix}-sort`}>Sort by</label><select id={`${prefix}-sort`} name="sort" defaultValue={sort}><option value="featured">Featured order</option><option value="price-asc">Price: low to high</option><option value="price-desc">Price: high to low</option><option value="name">Name: A–Z</option></select>
    <button className="commerce-button" type="submit">Apply filters</button>
  </>;
  return <>
    <form className="desktop-filters" action={path} method="get"><h2>Refine the edit</h2>{fields('desktop')}</form>
    <button ref={trigger} className="commerce-button mobile-filter-trigger" onClick={() => dialog.current?.showModal()}>Filter & sort</button>
    <dialog ref={dialog} className="filter-dialog" aria-labelledby="filter-title" onClose={() => trigger.current?.focus()}><div className="dialog-heading"><h2 id="filter-title">Refine the edit</h2><button className="plain-control" aria-label="Close filters" onClick={() => dialog.current?.close()}>×</button></div><form action={path} method="get">{fields('mobile')}</form></dialog>
  </>;
}

export function ProductPurchase({ product }: { product: CatalogSample }) {
  const bag = usePreviewBag();
  const [quantity, setQuantity] = useState(1);
  const [variant, setVariant] = useState(product.variants[0].id);
  const [image, setImage] = useState(0);
  const media = product.media[image];
  return <div className="product-detail-grid">
    <div><div className="detail-image">{media ? <img {...resolveMedia(media)} /> : <span>Photo awaiting approval</span>}</div>
      {product.media.length > 1 && <div className="image-thumbnails" aria-label="Product images">{product.media.map((item, i) => <button key={i} aria-label={`Show photo ${i + 1}`} aria-pressed={i === image} onClick={() => setImage(i)}><img {...resolveMedia(item)} /></button>)}</div>}
      <p className="muted">Supplied sample photograph. No additional product angles are available.</p>
    </div>
    <div className="product-information"><p className="eyebrow">{product.brandSlug ? <Link href={`/brands/${product.brandSlug}`}>{product.brand}</Link> : product.brand}</p><h1>{product.name}</h1><p className="detail-price">{formatPkr(product.pricePkr)} <span>PKR · sample price</span></p><p>Preview only · live availability is not connected.</p>
      <fieldset><legend>{product.variants[0].shade ? 'Shade' : 'Product option'}</legend>{product.variants.map(option => <label className="variant-option" key={option.id}><input type="radio" name="variant" value={option.id} checked={variant === option.id} onChange={() => setVariant(option.id)} />{option.label}</label>)}</fieldset>
      <p className="muted">Only the supplied option is available in this sample. Additional shade and size choices need validated records.</p>
      <label htmlFor="product-quantity">Quantity</label><input id="product-quantity" type="number" min="1" max="99" value={quantity} onChange={event => setQuantity(Number(event.target.value))} />
      <button className="commerce-button" disabled={!bag.ready || !Number.isInteger(quantity) || quantity < 1 || quantity > 99} onClick={() => { const next = (bag.quantities[product.id] || 0) + quantity; if (next > 99) { bag.notify('Preview quantity limit is 99'); return; } bag.setQuantity(product.id, next); bag.notify(`${product.brand} added to your bag`); }}>Add to sample bag</button>
      <Link className="text-link" href="/cart">View your bag →</Link>
    </div>
  </div>;
}

export function CartContents() {
  const bag = usePreviewBag();
  if (!bag.ready) return <p role="status">Loading your sample bag…</p>;
  const items = sampleProducts.filter(product => bag.quantities[product.id]);
  if (!items.length) return <div className="commerce-empty"><h2>Your next favourite awaits.</h2><p>Your sample bag is empty.</p><Link className="commerce-button" href="/search">Explore the edit</Link></div>;
  const subtotal = items.reduce((sum, item) => sum + item.pricePkr * bag.quantities[item.id], 0);
  return <div className="cart-layout"><div>{items.map(product => <article className="page-cart-line" key={product.id}><Link href={`/products/${product.slug}`}><img {...resolveMedia(product.media[0])} /></Link><div><p className="eyebrow">{product.brand}</p><h2><Link href={`/products/${product.slug}`}>{product.name}</Link></h2><p>{product.variants[0].label} · {formatPkr(product.pricePkr)}</p><label htmlFor={`quantity-${product.id}`}>Quantity</label><input id={`quantity-${product.id}`} type="number" min="1" max="99" value={bag.quantities[product.id]} onChange={event => { const number = Number(event.target.value); if (number >= 1 && number <= 99) bag.setQuantity(product.id, number); }} /><button className="text-control" onClick={() => { bag.setQuantity(product.id, 0); bag.notify('Removed from your bag'); }}>Remove <span className="sr-only">{product.name}</span></button></div><strong>{formatPkr(product.pricePkr * bag.quantities[product.id])}</strong></article>)}</div><aside className="order-summary"><h2>Your summary</h2><p className="summary-row"><span>Items subtotal</span><strong>{formatPkr(subtotal)}</strong></p><p>Delivery and payment options await configuration. This is not a payable total.</p><Link className="commerce-button" href="/checkout">Continue to checkout</Link><Link className="text-link" href="/search">Continue exploring</Link></aside></div>;
}

export function GuestCheckout({ slots }: { slots: CheckoutSlots }) {
  const bag = usePreviewBag();
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [review, setReview] = useState(false);
  const form = useRef<HTMLFormElement>(null);
  const confirmation = useRef<HTMLHeadingElement>(null);
  useEffect(() => { if (review) confirmation.current?.focus(); }, [review]);
  const items = sampleProducts.filter(product => bag.quantities[product.id]);
  const total = items.reduce((sum, product) => sum + product.pricePkr * bag.quantities[product.id], 0);
  if (!bag.ready) return <p role="status">Loading your sample bag…</p>;
  if (!items.length) return <div className="commerce-empty"><h2>Your bag is empty.</h2><Link className="commerce-button" href="/search">Explore the edit</Link></div>;
  const fields = [ ['name', 'Full name', 'name'], ['email', 'Email', 'email'], ['phone', 'Phone', 'tel'], ['address', 'Delivery address', 'street-address'], ['city', 'City', 'address-level2'], ['postal', 'Postal code (optional)', 'postal-code'] ];
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault(); const data = new FormData(event.currentTarget); const next: Record<string, string> = {};
    for (const [name, label] of fields) if (name !== 'postal' && !String(data.get(name) || '').trim()) next[name] = `Enter ${label.toLowerCase()}.`;
    if (data.get('email') && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(data.get('email')))) next.email = 'Enter a valid email address.';
    if (data.get('phone') && !/^\+?[\d ()-]{7,20}$/.test(String(data.get('phone')))) next.phone = 'Enter a valid phone number.';
    if (slots.shipping.length && !data.get('shipping')) next.shipping = 'Choose a delivery option.';
    if (slots.payment.length && !data.get('payment')) next.payment = 'Choose a payment option.';
    setErrors(next);
    if (Object.keys(next).length) requestAnimationFrame(() => form.current?.querySelector<HTMLInputElement>(`[name="${Object.keys(next)[0]}"]`)?.focus());
    else setReview(true);
  };
  return <div className="cart-layout"><div><p className="preview-notice">Guest checkout preview. No order, payment or delivery request will be created. Details are not saved.</p>
    {review && <section className="commerce-empty" role="status"><h2 ref={confirmation} tabIndex={-1}>Your checkout preview is ready.</h2><p>No order has been placed. Shipping, payment and final totals need approved configuration.</p><button className="commerce-button" onClick={() => { setReview(false); requestAnimationFrame(() => form.current?.querySelector('input')?.focus()); }}>Edit details</button></section>}
    <form ref={form} noValidate onSubmit={submit} hidden={review} className="checkout-form"><h2>Delivery details</h2><div className="checkout-grid">{fields.map(([name, label, autoComplete]) => <div key={name} className={name === 'address' ? 'full-field' : undefined}><label htmlFor={`delivery-${name}`}>{label}</label><input id={`delivery-${name}`} name={name} type={name === 'email' ? 'email' : name === 'phone' ? 'tel' : 'text'} autoComplete={autoComplete} maxLength={name === 'address' ? 300 : 120} required={name !== 'postal'} aria-invalid={Boolean(errors[name])} aria-describedby={errors[name] ? `${name}-error` : undefined} />{errors[name] && <p className="field-error" id={`${name}-error`}>{errors[name]}</p>}</div>)}</div>
      <fieldset><legend>Delivery option</legend>{slots.shipping.length ? slots.shipping.map(option => <label key={option.id}><input type="radio" name="shipping" value={option.id} />{option.label} · {option.pricePkr === null ? 'Price pending' : formatPkr(option.pricePkr)}</label>) : <p>Shipping rules and charges are awaiting approval.</p>}{errors.shipping && <p className="field-error" role="alert">{errors.shipping}</p>}</fieldset>
      <fieldset><legend>Payment option</legend>{slots.payment.length ? slots.payment.map(option => <label key={option.id}><input type="radio" name="payment" value={option.id} />{option.label}</label>) : <p>Payment methods are not configured.</p>}{errors.payment && <p className="field-error" role="alert">{errors.payment}</p>}</fieldset>
      <button className="commerce-button" type="submit">Review sample checkout</button>
    </form></div><aside className="order-summary"><h2>Your order summary</h2>{items.map(item => <p className="summary-row" key={item.id}><span>{item.name} × {bag.quantities[item.id]}</span><strong>{formatPkr(item.pricePkr * bag.quantities[item.id])}</strong></p>)}<p className="summary-row"><span>Items subtotal</span><strong>{formatPkr(total)}</strong></p><p>Shipping: not configured<br />Payable total: not available</p><Link className="text-link" href="/cart">Edit bag</Link></aside></div>;
}
