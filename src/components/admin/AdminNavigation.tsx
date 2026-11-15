'use client';
import Link from 'next/link';
import {usePathname} from 'next/navigation';
import {useState} from 'react';
import {adminRequest} from './ProductAdmin';

const stroke = {fill:'none',stroke:'currentColor',strokeWidth:1.6,strokeLinecap:'round',strokeLinejoin:'round'} as const;

const icons = {
  products:<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M4.5 7.5h15l-1.2 12H5.7z"/><path d="M9 7.5V6a3 3 0 0 1 6 0v1.5"/></svg>,
  deals:<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M12 3.5 20 8l-8 4.5L4 8z"/><path d="M4 12.5 12 17l8-4.5"/><path d="M4 16.5 12 21l8-4.5"/></svg>,
  orders:<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M6 3.5h12v17l-2.2-1.6-2.2 1.6-2.2-1.6L9.2 20.5 7 19z"/><path d="M9.5 8h5M9.5 12h5"/></svg>,
  reports:<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M4 20h16"/><path d="M7 20v-6"/><path d="M12 20V8"/><path d="M17 20v-9"/></svg>,
  articles:<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M5 4.5h9.5L19 9v10.5H5z"/><path d="M14 4.5V9h5"/><path d="M8.5 13h7M8.5 16h4.5"/></svg>,
  homepage:<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><path d="M3.5 9.5h17"/><path d="M9 9.5v10"/></svg>,
  reviews:<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><path d="M12 3.8l2.5 5.2 5.7.8-4.1 4 1 5.7-5.1-2.7-5.1 2.7 1-5.7-4.1-4 5.7-.8z"/></svg>,
  more:<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" {...stroke}><circle cx="5.5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="18.5" cy="12" r="1.4"/></svg>
};

export const adminSections = [
  {href:'/admin/products',label:'Products',icon:icons.products,group:'Catalog'},
  {href:'/admin/deals',label:'Deals',icon:icons.deals,group:'Catalog'},
  {href:'/admin/orders',label:'Orders',icon:icons.orders,group:'Commerce'},
  {href:'/admin/reports',label:'Reports',icon:icons.reports,group:'Commerce'},
  {href:'/admin/articles',label:'The Edit',icon:icons.articles,group:'Content'},
  {href:'/admin/homepage',label:'Homepage',icon:icons.homepage,group:'Content'},
  {href:'/admin/reviews',label:'Reviews',icon:icons.reviews,group:'Content'}
];

export function AdminNavigation(){
  const path=usePathname();
  if(path==='/admin/login')return null;
  const groups=[...new Set(adminSections.map(s=>s.group))];
  return <nav aria-label="Administration">{groups.map(group=>
    <div className="admin-nav-group" key={group}>
      <p className="admin-nav-group-label">{group}</p>
      {adminSections.filter(section=>section.group===group).map(section=>
        <Link key={section.href} href={section.href} aria-current={path===section.href?'page':undefined}>{section.icon}{section.label}</Link>)}
    </div>)}</nav>;
}

export function AdminAccountMenu(){
  const path=usePathname(),[error,setError]=useState('');
  if(path==='/admin/login')return null;
  return <details className="admin-tools"><summary>{icons.more}<span>More</span></summary>
    <Link href="/admin/tools">Import &amp; technical tools</Link>
    <button onClick={async()=>{try{if(document.querySelector('[data-unsaved=true]')&&!window.confirm('Sign out without saving your changes?'))return;await adminRequest('/admin/api/session',{action:'logout'});window.location.assign('/admin/login');}catch{setError('Could not sign out. Please retry.');}}}>Sign out</button>
    {error&&<p role="alert">{error}</p>}
  </details>;
}
