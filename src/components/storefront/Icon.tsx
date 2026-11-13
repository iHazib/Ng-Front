// Paths and stroke widths copied from the approved wireframe, no icon library.
export function Icon({ name }: { name: 'search' | 'bag' | 'chevron' | 'instagram' | 'facebook' }) {
  if (name === 'chevron') return <svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" aria-hidden="true"><path d="m4 6 4 4 4-4" /></svg>;
  if (name === 'facebook') return <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M14 22v-9h3l.5-4H14V7c0-1.2.4-2 2-2h2V1.5c-.6-.1-1.8-.3-3-.3-3 0-5 1.8-5 5V9H7v4h3v9z" /></svg>;
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={name === 'bag' ? 1.4 : 1.5} aria-hidden="true">
    {name === 'search' && <><circle cx="10.5" cy="10.5" r="6.5" /><path d="m16 16 5 5" /></>}
    {name === 'bag' && <><path d="M5 7h14l1 14H4L5 7Z" /><path d="M8 8V6a4 4 0 0 1 8 0v2" /></>}
    {name === 'instagram' && <><rect x="3" y="3" width="18" height="18" rx="5" /><circle cx="12" cy="12" r="4" /><circle cx="17.5" cy="6.5" r=".9" fill="currentColor" stroke="none" /></>}
  </svg>;
}
