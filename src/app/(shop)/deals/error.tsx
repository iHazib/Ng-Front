'use client';
import Link from 'next/link';
export default function DealError({retry}:{retry:()=>void}){return <section role="alert"><h1>This deal could not be loaded.</h1><p>We could not check current contents, prices and availability. Please try again before adding it to your bag.</p><button className="commerce-button" onClick={retry}>Try again</button><Link className="text-link" href="/deals">View all deals</Link></section>;}
