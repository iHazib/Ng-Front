'use client';
import { useState } from 'react';
export function AdminLogin() {
  const [message, setMessage] = useState(''); const [busy, setBusy] = useState(false);
  return <section className="admin-login">
    <div className="admin-login-brand">
      <span className="admin-brand-mark" aria-hidden="true">N</span>
      <span className="admin-brand-text">Nook &amp; Glow<span>Store management</span></span>
    </div>
    <h1>Administrator sign in</h1><p>Use your confirmed Supabase account with approved admin membership.</p><form onSubmit={async event => {
    event.preventDefault(); setBusy(true); setMessage(''); const data = new FormData(event.currentTarget);
    try {
      const { csrf } = await (await fetch('/admin/api/session', { cache: 'no-store' })).json();
      const response = await fetch('/admin/api/session', { method: 'POST', headers: { 'Content-Type': 'application/json', 'x-admin-csrf': csrf }, body: JSON.stringify({ email: data.get('email'), password: data.get('password') }) });
      const result = await response.json(); if (!response.ok) throw new Error(result.error);
      window.location.assign('/admin/products');
    } catch (error) { setMessage(error instanceof Error ? error.message : 'Login unavailable.'); } finally { setBusy(false); }
  }}><label>Email<input name="email" type="email" autoComplete="username" required /></label><label>Password<input name="password" type="password" autoComplete="current-password" required /></label><button disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</button><p role="alert">{message}</p></form></section>;
}
