'use client';
import Link from 'next/link';
import {usePathname} from 'next/navigation';
import {useState} from 'react';
import {adminRequest} from './ProductAdmin';
export function AdminNavigation(){
 const path=usePathname(),[error,setError]=useState('');
 if(path==='/admin/login')return null;
 return <><nav aria-label="Administration">{[['/admin/products','Products'],['/admin/deals','Deals'],['/admin/orders','Orders'],['/admin/reports','Reports'],['/admin/articles','The Edit'],['/admin/homepage','Homepage'],['/admin/reviews','Reviews']].map(([href,label])=><Link key={href} href={href} aria-current={path===href?'page':undefined}>{label}</Link>)}</nav><details className="admin-tools"><summary>More</summary><Link href="/admin/tools">Import & technical tools</Link><button onClick={async()=>{try{if(document.querySelector('[data-unsaved=true]')&&!window.confirm('Sign out without saving your changes?'))return;await adminRequest('/admin/api/session',{action:'logout'});window.location.assign('/admin/login');}catch{setError('Could not sign out. Please retry.');}}}>Sign out</button>{error&&<p role="alert">{error}</p>}</details></>;
}
