'use client';
import Link from 'next/link';
import {usePathname} from 'next/navigation';
import {AdminAccountMenu, AdminNavigation} from './AdminNavigation';

const sectionLabels:Record<string,string>={
  '/admin/products':'Catalog',
  '/admin/deals':'Catalog',
  '/admin/orders':'Commerce',
  '/admin/reports':'Commerce',
  '/admin/articles':'Content',
  '/admin/homepage':'Content',
  '/admin/reviews':'Content',
  '/admin/tools':'Utilities'
};

const pageLabels:Record<string,string>={
  '/admin/products':'Products',
  '/admin/deals':'Deals',
  '/admin/orders':'Orders',
  '/admin/reports':'Reports',
  '/admin/articles':'The Edit',
  '/admin/homepage':'Homepage',
  '/admin/reviews':'Reviews',
  '/admin/tools':'Import & technical tools'
};

export function AdminShell({children}:{children:React.ReactNode}){
  const path=usePathname();
  if(path==='/admin/login')return <div className="ng-admin ng-admin-auth"><main className="admin-auth-main">{children}</main></div>;
  const href=Object.keys(pageLabels).find(key=>path===key||path.startsWith(key+'/'))??'';
  const label=pageLabels[href]??'Administration';
  const group=sectionLabels[href]??'Admin';
  return <div className="ng-admin">
    <aside className="admin-rail">
      <Link className="admin-brand" href="/admin/products">
        <span className="admin-brand-mark" aria-hidden="true">N</span>
        <span className="admin-brand-text">Nook &amp; Glow<span>Store management</span></span>
      </Link>
      <AdminNavigation/>
      <AdminAccountMenu/>
    </aside>
    <div className="admin-main">
      <header className="admin-topbar">
        <div className="admin-topbar-title">
          <p className="admin-eyebrow">{group}</p>
          <span className="admin-crumb-sep" aria-hidden="true">/</span>
          <strong>{label}</strong>
        </div>
        <div className="admin-topbar-actions">
          <Link className="admin-chip" href="/" target="_blank" rel="noreferrer">View storefront&nbsp;↗</Link>
        </div>
      </header>
      <main className="admin-content">{children}</main>
    </div>
  </div>;
}
