import {ProductDisclosure} from './ProductDisclosure';
import {ProductMarkdown} from './ProductMarkdown';
import Link from 'next/link';
import { assets } from '@/config/assets';
import { site } from '@/config/site';
import { getApprovedPreview } from '@/lib/catalog/approved-preview';
import { categories, sampleProducts, sampleBrands, articleSlugs, carePages, formatPkr, previewCheckoutSlots, type CatalogSample } from '@/lib/catalog/commerce-samples';
import { resolveMedia } from '@/lib/catalog/media';
import { CartContents, Filters, GuestCheckout, ProductPurchase } from './CommerceInteractive';
import { Node } from './SampleMarkup';

export type Query = Record<string, string | string[] | undefined>;
const first = (value: string | string[] | undefined) => (Array.isArray(value) ? value[0] : value) || '';
export function routeTitle(path: string): string | undefined {
  const category = categories.find(item => item.slug === path);
  if (category) return category.name;
  if (path === 'fragrances/home-fragrance') return 'Home Fragrance';
  if (path === 'fragrances/personal-fragrance') return 'Personal Fragrance';
  if (path === 'brands') return 'Brands to know';
  if (path.startsWith('brands/')) return sampleBrands.find(item => `brands/${item.slug}` === path)?.name;
  if (path.startsWith('products/')) return sampleProducts.find(item => `products/${item.slug}` === path)?.name;
  if (path === 'search') return 'Search the edit';
  if (path === 'cart') return 'Your shopping bag';
  if (path === 'checkout') return 'Guest checkout';
  if (path === 'the-edit') return 'The Edit';
  const article = articleSlugs.findIndex(slug => `the-edit/${slug}` === path);
  if (article >= 0) return getApprovedPreview().articles[article].title;
  return Object.hasOwn(carePages, path) ? carePages[path] : undefined;
}
export function Breadcrumbs({ items }: { items: { label: string; href?: string }[] }) {
  return <nav className="breadcrumbs" aria-label="Breadcrumb"><ol><li><Link href="/">Home</Link></li>{items.map((item, index) => <li key={index}>{item.href ? <Link href={item.href}>{item.label}</Link> : <span aria-current="page">{item.label}</span>}</li>)}</ol></nav>;
}
export function ProductCard({ product }: { product: CatalogSample }) {
  return <article className="catalog-card"><Link href={`/products/${product.slug}`} className="catalog-image">{product.media[0] ? <img {...resolveMedia(product.media[0])} /> : <span>Photo awaiting approval</span>}</Link><p className="eyebrow">{product.brand}</p><h2><Link href={`/products/${product.slug}`}>{product.name}</Link></h2><p>{formatPkr(product.pricePkr)} <small>PKR · sample</small></p><Link className="text-link" href={`/products/${product.slug}`}>View product ↗</Link></article>;
}
function Listing({ path, query, title, products }: { path: string; query: Query; title: string; products: CatalogSample[] }) {
  const q = first(query.q).trim().slice(0, 160), brand = first(query.brand);
  const sort = ['price-asc', 'price-desc', 'name'].includes(first(query.sort)) ? first(query.sort) : 'featured';
  const page = Math.max(1, Math.min(10000, Number.parseInt(first(query.page), 10) || 1));
  const options = sampleBrands.filter(item => products.some(product => product.brandSlug === item.slug));
  let matches = products.filter(product => (!brand || product.brandSlug === brand) && (!q || `${product.name} ${product.brand} ${product.category}`.toLowerCase().includes(q.toLowerCase())));
  if (sort === 'price-asc') matches = matches.toSorted((a, b) => a.pricePkr - b.pricePkr);
  if (sort === 'price-desc') matches = matches.toSorted((a, b) => b.pricePkr - a.pricePkr);
  if (sort === 'name') matches = matches.toSorted((a, b) => a.name.localeCompare(b.name));
  const pages = Math.ceil(matches.length / 2), visible = matches.slice((page - 1) * 2, page * 2);
  const href = (changes: Record<string, string>) => {
    const params = new URLSearchParams({ ...(q ? { q } : {}), ...(brand ? { brand } : {}), sort, ...changes });
    for (const [key, value] of [...params]) if (!value || (key === 'sort' && value === 'featured')) params.delete(key);
    return `/${path}${params.size ? `?${params}` : ''}`;
  };
  return <>
    <Breadcrumbs items={path.startsWith('brands/') ? [{ label: 'Brands', href: '/brands' }, { label: title }] : path.startsWith('fragrances/') ? [{ label: 'Fragrances', href: '/fragrances' }, { label: title }] : [{ label: title }]} />
    <header className="commerce-heading"><p className="eyebrow">The considered collection</p><h1>{title}</h1><p>{matches.length} sample {matches.length === 1 ? 'product' : 'products'} · prices and availability are preview data.</p></header>
    {query.concern && <p className="preview-notice">Concern assignments await approved catalog information. Showing the sample category without applying a suitability filter.</p>}
    {path === 'fragrances' && <nav className="branch-links" aria-label="Fragrance collections"><Link href="/fragrances/personal-fragrance">Personal Fragrance ↗</Link><Link href="/fragrances/home-fragrance">Home Fragrance ↗</Link></nav>}
    {path === 'fragrances/home-fragrance' && <p>Home scent has its own collection, separate from perfume. No approved product samples have been assigned yet.</p>}
    {path === 'search' && <form action="/search" method="get" className="catalog-search"><label htmlFor="catalog-query">Search sample products</label><div><input id="catalog-query" name="q" type="search" maxLength={160} defaultValue={q} placeholder="Product or brand name" /><button className="commerce-button">Search</button></div></form>}
    <div className="catalog-layout"><aside><Filters path={`/${path}`} q={q} brand={brand} sort={sort} brands={options} key={`${q}-${brand}-${sort}`} /></aside><section aria-label="Product results">
      <div className="applied-filters" aria-label="Applied filters">{brand && <Link href={href({ brand: '', page: '' })}>Brand: {options.find(item => item.slug === brand)?.name || brand} <span aria-label="Remove brand filter">×</span></Link>}{q && <Link href={href({ q: '', page: '' })}>Search: {q} <span aria-label="Remove search filter">×</span></Link>}{(brand || q || sort !== 'featured') && <Link href={`/${path}`}>Clear all</Link>}</div>
      {visible.length ? <div className="catalog-grid">{visible.map(product => <ProductCard key={product.id} product={product} />)}</div> : <div className="commerce-empty"><h2>{matches.length ? 'No products on this page.' : 'Nothing in this edit yet.'}</h2><p>{products.length ? 'Try clearing your filters or another search.' : 'Approved samples will appear here when available.'}</p><Link className="text-link" href={matches.length ? href({ page: '1' }) : '/search'}>{matches.length ? 'Return to page 1' : 'Explore all sample products'} →</Link></div>}
      {pages > 1 && <nav className="pagination" aria-label="Product pages">{page > 1 && <Link rel="prev" href={href({ page: String(page - 1) })}>← Previous</Link>}{Array.from({ length: pages }, (_, i) => <Link key={i} href={href({ page: String(i + 1) })} aria-current={page === i + 1 ? 'page' : undefined}>{i + 1}</Link>)}{page < pages && <Link rel="next" href={href({ page: String(page + 1) })}>Next →</Link>}</nav>}
    </section></div>
  </>;
}

export function CommercePage({ path, query }: { path: string; query: Query }) {
  const title = routeTitle(path)!;
  const product = sampleProducts.find(item => `products/${item.slug}` === path);
  if (product) return <><Breadcrumbs items={[{ label: categories.find(item => item.slug === product.category)!.name, href: `/${product.category}` }, { label: product.name }]} /><ProductPurchase product={product} /><section className="product-detail-sections" aria-label="Product information"><div className="product-disclosures">{product.details?.trim()&&<ProductDisclosure title="Product description" initiallyOpen><ProductMarkdown source={product.details}/></ProductDisclosure>}{product.usage?.trim()&&<ProductDisclosure title="How to use"><ProductMarkdown source={product.usage}/></ProductDisclosure>}<ProductDisclosure title="Delivery information"><p>Delivery regions, charges and timelines are awaiting business approval.</p><Link className="text-link" href="/shipping">Delivery information →</Link></ProductDisclosure></div><div><h2>Approved reviews</h2><p>No approved reviews are available. No ratings or testimonials are shown.</p></div></section></>;
  if (categories.some(item => item.slug === path) || path.startsWith('fragrances/')) return <Listing path={path} query={query} title={title} products={sampleProducts.filter(item => path.includes('/') ? item.category === 'fragrances' && item.branch === path.split('/')[1] : item.category === path)} />;
  if (path === 'search' || path.startsWith('brands/')) return <Listing path={path} query={query} title={title} products={sampleProducts.filter(item => path === 'search' || item.brandSlug === path.split('/')[1])} />;
  if (path === 'brands') return <><Breadcrumbs items={[{ label: 'Brands' }]} /><header className="commerce-heading"><p className="eyebrow">The names in our edit</p><h1>{title}</h1><p>Approved homepage brand artwork. Product collections contain sample records only.</p></header><div className="brand-directory">{sampleBrands.map(brand => <Link key={brand.slug} href={`/brands/${brand.slug}`}><img src={assets.brands[brand.slug]} alt={`${brand.name} logo`} /><span>{brand.name} ↗</span><small>{sampleProducts.filter(item => item.brandSlug === brand.slug).length} sample products</small></Link>)}</div></>;
  if (path === 'the-edit') return <><Breadcrumbs items={[{ label: 'The Edit' }]} /><header className="commerce-heading"><p className="eyebrow">Beauty, home, everyday</p><h1>The Edit</h1><p>Sample articles from the approved homepage, awaiting publication review.</p></header><div className="edit-index">{getApprovedPreview().articles.map((article, index) => <article className={`editorial-entry theme-${index}`} key={articleSlugs[index]}><Link href={`/the-edit/${articleSlugs[index]}`}><img src={article.image} alt={article.title} /></Link><div><p className="eyebrow">{article.category} · {article.time}</p><h2><Link href={`/the-edit/${articleSlugs[index]}`}>{article.title}</Link></h2><p>{article.summary}</p><Link className="text-link" href={`/the-edit/${articleSlugs[index]}`}>Read the article ↗</Link></div></article>)}</div></>;
  if (path.startsWith('the-edit/')) {
    const index = articleSlugs.findIndex(slug => path.endsWith(`/${slug}`)); const article = getApprovedPreview().articles[index];
    return <><Breadcrumbs items={[{ label: 'The Edit', href: '/the-edit' }, { label: article.title }]} /><article className={`article-page theme-${index}`}><header><p className="eyebrow">{article.category} · {article.time}</p><h1>{article.title}</h1><p>{article.summary}</p><small>Sample editorial · awaiting publication approval</small></header><img className="article-cover" src={article.image} alt={article.title} /><div className="article-prose">{article.body.map((node, i) => <Node key={i} node={typeof node !== 'string' && node.tag === 'h4' ? { ...node, tag: 'h2' } : node} />)}<Link className="text-link" href="/search">Explore the collection →</Link></div></article></>;
  }
  if (path === 'cart' || path === 'checkout') return <><Breadcrumbs items={path === 'checkout' ? [{ label: 'Bag', href: '/cart' }, { label: 'Checkout' }] : [{ label: 'Bag' }]} /><header className="commerce-heading"><p className="eyebrow">Your considered edit</p><h1>{title}</h1></header>{path === 'cart' ? <CartContents /> : <GuestCheckout slots={previewCheckoutSlots} />}</>;
  return <><Breadcrumbs items={path === 'customer-care' ? [{ label: title }] : [{ label: 'Customer care', href: '/customer-care' }, { label: title }]} /><div className="care-layout"><nav aria-label="Customer care">{Object.entries(carePages).map(([slug, name]) => <Link key={slug} aria-current={path === slug ? 'page' : undefined} href={`/${slug}`}>{name}</Link>)}</nav><article><p className="eyebrow">Here to help</p><h1>{title}</h1>{path === 'contact' ? <><p>For enquiries, contact Nook & Glow.</p><a className="contact-link" href={`mailto:${site.contactEmail}`}>{site.contactEmail}</a></> : <><p className="preview-notice">Preview placeholder · approved content pending</p><p>This layout reserves space for approved {title.toLowerCase()} content. No policy, service commitment or legal terms are published here.</p><Link className="text-link" href="/contact">Contact us →</Link></>}</article></div></>;
}
