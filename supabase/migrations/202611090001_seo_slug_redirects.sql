-- Stable legacy slugs for public product, article, deal and brand URLs.
-- Only explicit, owner-maintained mappings are returned. The resolver verifies
-- that the target is still publicly eligible, so a stale mapping cannot send a
-- crawler to a draft, deleted or otherwise private record.
create table public.slug_redirects (
  id uuid primary key default gen_random_uuid(),
  entity_kind text not null check (entity_kind in ('product','article','deal','brand')),
  old_slug text not null check (old_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(old_slug) between 1 and 180),
  new_slug text not null check (new_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(new_slug) between 1 and 180),
  created_at timestamptz not null default now(),
  unique (entity_kind, old_slug),
  check (old_slug <> new_slug)
);
alter table public.slug_redirects enable row level security;
revoke all on table public.slug_redirects from public, anon, authenticated;

create function public.storefront_slug_redirect(p_kind text, p_slug text)
returns text language sql stable security definer set search_path='' set statement_timeout='4s' as $redirect$
  select case p_kind
    when 'product' then (
      select '/products/' || p.slug
      from public.slug_redirects r
      join public.products p on p.slug = r.new_slug
      where r.entity_kind = 'product' and r.old_slug = left(p_slug, 180)
        and p.status = 'published' and public.product_is_public(p.id)
      limit 1
    )
    when 'article' then (
      select '/the-edit/' || a.slug
      from public.slug_redirects r
      join public.articles a on a.slug = r.new_slug
      where r.entity_kind = 'article' and r.old_slug = left(p_slug, 180)
        and a.status = 'published' and a.published_at <= now() and a.deleted_at is null
      limit 1
    )
    when 'deal' then (
      select '/deals/' || d.slug
      from public.slug_redirects r
      join public.deals d on d.slug = r.new_slug
      where r.entity_kind = 'deal' and r.old_slug = left(p_slug, 180)
        and public.deal_is_public(d.id)
      limit 1
    )
    when 'brand' then (
      select '/brands/' || b.id
      from public.slug_redirects r
      join public.brands b on b.id = r.new_slug
      where r.entity_kind = 'brand' and r.old_slug = left(p_slug, 180)
        and b.status = 'published'
      limit 1
    )
  end
$redirect$;
revoke all on function public.storefront_slug_redirect(text,text) from public, anon, authenticated;
grant execute on function public.storefront_slug_redirect(text,text) to anon, authenticated;
notify pgrst, 'reload schema';
