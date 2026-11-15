'use client';
import type {ReactNode} from 'react';
import {publicationMessage} from '@/lib/catalog/publication-messages';

const readinessText:Record<string,string>={
  slug_missing:'Add a product link.',
  description_missing:'Add a product description.',
  usage_missing:'Add how to use.',
  benefits_missing:'Add key benefits.',
  price_missing:'Enter a price for every option.',
  price_approval:'Approve the price.',
  image_missing:'Add a main image.',
  image_approval:'Approve the main image.',
  stock_count_missing:'Enter the stock count, including zero if sold out.',
  out_of_stock:'This option is out of stock.',
  brand_missing:'Choose the brand.',
  category_type_missing:'Choose a category and product type.',
  option_missing:'Add a shade or size for this option.',
  publication_blockers:'Publication blockers are still open.'
};

export function readinessMessage(code:string){return readinessText[code]??publicationMessage(code);}

const stroke={fill:'none',stroke:'currentColor',strokeWidth:1.6,strokeLinecap:'round',strokeLinejoin:'round'} as const;

export const icon={
  search:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 4.5 4.5"/></svg>,
  filter:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M4 6h16"/><path d="M7 12h10"/><path d="M10 18h4"/></svg>,
  plus:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M12 5v14M5 12h14"/></svg>,
  check:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M4.5 12.5 9 17l10.5-10.5"/></svg>,
  alert:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M12 4.5 21 19.5H3z"/><path d="M12 10v4.5"/><path d="M12 17.2v.1"/></svg>,
  image:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><circle cx="9" cy="9.5" r="1.6"/><path d="m4.5 17 4.5-4.5 3.5 3.5 3-3L20 17"/></svg>,
  tag:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M4 10.5V4h6.5L20 13.5 13.5 20z"/><path d="M8 8h.01"/></svg>,
  layers:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M12 3.5 20 8l-8 4.5L4 8z"/><path d="M4 12.5 12 17l8-4.5"/></svg>,
  box:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M4 8.5 12 4l8 4.5v7L12 20l-8-4.5z"/><path d="M4 8.5 12 13l8-4.5M12 13v7"/></svg>,
  eye:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/></svg>,
  grid:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/></svg>,
  list:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M4 6h16M4 12h16M4 18h16"/></svg>,
  clock:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><circle cx="12" cy="12" r="8"/><path d="M12 7.5V12l3 2"/></svg>,
  sparkle:<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M12 3.5 13.6 9 19 10.5 13.6 12 12 17.5 10.4 12 5 10.5 10.4 9z"/></svg>
};

export function PageHeader({eyebrow,title,description,actions}:{eyebrow?:string;title:string;description?:string;actions?:ReactNode}){
  return <div className="admin-page-head">
    <div className="admin-page-head-text">
      {eyebrow&&<p className="admin-eyebrow">{eyebrow}</p>}
      <h1>{title}</h1>
      {description&&<p className="admin-page-lead">{description}</p>}
    </div>
    {actions&&<div className="admin-page-head-actions">{actions}</div>}
  </div>;
}

export function SectionCard({id,icon:glyph,title,description,aside,children,tone}:{id?:string;icon?:ReactNode;title:string;description?:string;aside?:ReactNode;children:ReactNode;tone?:'plain'|'accent'}){
  return <section id={id} className={'admin-section'+(tone==='accent'?' admin-section-accent':'')}>
    <header className="admin-section-head">
      {glyph&&<span className="admin-section-icon" aria-hidden="true">{glyph}</span>}
      <div className="admin-section-text"><h3>{title}</h3>{description&&<p>{description}</p>}</div>
      {aside&&<div className="admin-section-aside">{aside}</div>}
    </header>
    <div className="admin-section-body">{children}</div>
  </section>;
}

export function EmptyState({title,hint}:{title:string;hint?:string}){
  return <div className="admin-empty">
    <span className="admin-empty-mark" aria-hidden="true" />
    <p className="admin-empty-title">{title}</p>
    {hint&&<p className="admin-empty-hint">{hint}</p>}
  </div>;
}

export function KpiTile({label,value,caption,tone}:{label:string;value:string|number;caption?:string;tone?:'plain'|'warn'|'good'}){
  return <div className={'admin-kpi'+(tone&&tone!=='plain'?' admin-kpi-'+tone:'')}>
    <p className="admin-kpi-label">{label}</p>
    <p className="admin-kpi-value">{value}</p>
    {caption&&<p className="admin-kpi-caption">{caption}</p>}
  </div>;
}
