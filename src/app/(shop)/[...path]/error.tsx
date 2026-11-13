'use client';
import Link from 'next/link';
export default function Error({ retry }: { error: Error & { digest?: string }; retry: () => void }) { return <section className="commerce-empty" role="alert"><h1>This page could not be loaded.</h1><p>Please try again. Your bag remains on this device.</p><button className="commerce-button" onClick={retry}>Try again</button><Link className="text-link" href="/">Return home</Link></section>; }
