-- Catalog structure only. No source catalog rows or credentials are seeded.
create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;
revoke create on schema public from public, anon, authenticated;

create table app_private.admin_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active boolean not null default true,
  granted_at timestamptz not null default now(),
  granted_by uuid references auth.users(id),
  reason text not null check (length(btrim(reason)) > 0)
);
alter table app_private.admin_members enable row level security;
create function public.is_admin() returns boolean language sql stable security definer
set search_path = '' as $$
  select exists(select 1 from app_private.admin_members where user_id = auth.uid() and active)
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;
create function app_private.require_admin() returns void language plpgsql security definer
set search_path = '' as $$ begin
  if not public.is_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
end $$;

create type public.publication_status as enum ('draft','published','archived');
create type public.review_status as enum ('pending','approved','rejected');
create type public.catalog_scope as enum ('skincare','makeup','bath-body','hair-care','personal-fragrance','home-fragrance','cutlery');
create type public.facet_kind as enum ('enum','reference','integer','decimal','boolean','quantity');

create table public.brands (
  id text primary key, name text not null, status public.publication_status not null default 'draft',
  created_at timestamptz not null default now()
);
create table public.brand_aliases (
  id uuid primary key default gen_random_uuid(), brand_id text not null references public.brands(id),
  alias text not null check (length(btrim(alias))>0),
  normalized text generated always as (lower(btrim(alias))) stored unique
);
create table public.categories (
  id text primary key, parent_id text references public.categories(id), name text not null,
  scope public.catalog_scope, status public.publication_status not null default 'draft',
  check (parent_id is distinct from id)
);
create function app_private.category_no_cycle() returns trigger language plpgsql set search_path='' as $$ begin
  -- Serialize hierarchy edits; concurrent reparenting must not create a cycle.
  perform pg_advisory_xact_lock(73521);
  if exists(with recursive ancestors as (
    select c.id,c.parent_id from public.categories c where c.id=new.parent_id
    union select c.id,c.parent_id from public.categories c join ancestors a on c.id=a.parent_id
  ) select 1 from ancestors where id=new.id) then raise exception 'Category cycle'; end if;
  return new;
end $$;
create trigger category_no_cycle before insert or update on public.categories for each row execute function app_private.category_no_cycle();
create table public.product_types (id text primary key, name text not null);
create table public.category_product_types (
  category_id text references public.categories(id), product_type_id text references public.product_types(id),
  primary key(category_id,product_type_id)
);
create table public.products (
  id uuid primary key default gen_random_uuid(), name text not null check(length(btrim(name))>0),
  slug text unique, brand_id text references public.brands(id),
  category_id text references public.categories(id), product_type_id text references public.product_types(id),
  status public.publication_status not null default 'draft', description text, usage text,
  identity_confirmed boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  revision integer not null default 1 check(revision>0),
  search_vector tsvector generated always as (to_tsvector('simple',coalesce(name,'') || ' ' || coalesce(description,''))) stored,
  foreign key(category_id,product_type_id) references public.category_product_types(category_id,product_type_id)
);
create table public.product_categories (
  product_id uuid references public.products(id), category_id text references public.categories(id), primary key(product_id,category_id)
);
create function public.sku_collision_key(value text) returns text language sql immutable strict set search_path='' as $$
  select upper(regexp_replace(btrim(normalize(value,NFKC)), '\s*-\s*','-','g'))
$$;
create table public.variants (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id),
  original_sku text not null unique check(length(btrim(original_sku))>0),
  sku_key text generated always as (public.sku_collision_key(original_sku)) stored unique,
  label text, status public.publication_status not null default 'draft',
  sellable_kind text not null default 'single' check(sellable_kind in ('single','factory_set','unconfirmed_set')),
  identity_confirmed boolean not null default false,
  created_at timestamptz not null default now(), unique(id,product_id)
);
create table public.sku_aliases (
  alias text primary key, variant_id uuid not null references public.variants(id),
  collision_key text generated always as (public.sku_collision_key(alias)) stored unique
);
create function app_private.guard_sku() returns trigger language plpgsql set search_path='' as $$ begin
  perform pg_advisory_xact_lock(73522);
  if tg_table_name='variants' then
    if tg_op='UPDATE' and new.original_sku is distinct from old.original_sku then raise exception 'Original SKU is immutable; add an audited alias'; end if;
    if exists(select 1 from public.sku_aliases where collision_key=public.sku_collision_key(new.original_sku) and variant_id<>new.id) then raise exception 'SKU alias collision'; end if;
  else
    if exists(select 1 from public.variants where sku_key=public.sku_collision_key(new.alias) and id<>new.variant_id) then raise exception 'SKU collision'; end if;
  end if;
  return new;
end $$;
create trigger guard_sku before insert or update on public.variants for each row execute function app_private.guard_sku();
create trigger guard_alias before insert or update on public.sku_aliases for each row execute function app_private.guard_sku();
create table public.variant_prices (
  variant_id uuid primary key references public.variants(id), currency text not null default 'PKR' check(currency='PKR'),
  amount_minor bigint not null check(amount_minor between 1 and 9007199254740991),
  approved boolean not null default false, updated_at timestamptz not null default now()
);
create table public.option_axes (id text primary key, name text not null);
create table public.option_values (
  id text primary key, axis_id text not null references public.option_axes(id), label text not null,
  unique(id,axis_id)
);
create table public.variant_options (
  variant_id uuid references public.variants(id), axis_id text references public.option_axes(id),
  value_id text not null, primary key(variant_id,axis_id),
  foreign key(value_id,axis_id) references public.option_values(id,axis_id)
);
create table public.facet_definitions (
  id text primary key, name text not null, kind public.facet_kind not null,
  active boolean not null default false, unique(id,kind)
);
create table public.facet_scopes (
  facet_id text references public.facet_definitions(id), scope public.catalog_scope, primary key(facet_id,scope)
);
create table public.facet_values (
  id text primary key, facet_id text not null references public.facet_definitions(id), label text not null,
  unique(id,facet_id)
);
create table public.evidence (
  id uuid primary key default gen_random_uuid(), source_key text unique,
  source_type text not null check(source_type in ('workbook','official_page','official_excerpt','package','retailer','unverified')),
  url text, finding text not null, region text, product_version text, accessed_on date,
  status public.review_status not null default 'pending', reviewed_by uuid references auth.users(id), reviewed_at timestamptz,
  check(status<>'approved' or (reviewed_by is not null and reviewed_at is not null))
);
create table public.product_facets (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id),
  variant_id uuid, facet_id text not null, kind public.facet_kind not null,
  option_id text, integer_value integer, decimal_value numeric(14,4), boolean_value boolean, unit text,
  evidence_id uuid references public.evidence(id), status public.review_status not null default 'pending',
  foreign key(variant_id,product_id) references public.variants(id,product_id),
  foreign key(facet_id,kind) references public.facet_definitions(id,kind),
  foreign key(option_id,facet_id) references public.facet_values(id,facet_id),
  check(num_nonnulls(option_id,integer_value,decimal_value,boolean_value)=1),
  check((kind in ('enum','reference') and option_id is not null and unit is null)
    or (kind='integer' and integer_value is not null and unit is null)
    or (kind='decimal' and decimal_value is not null and unit is null)
    or (kind='boolean' and boolean_value is not null and unit is null)
    or (kind='quantity' and decimal_value>0 and unit in ('ml','g','cm','mm'))),
  check(status<>'approved' or evidence_id is not null)
);
create table public.concerns (
  id text primary key, name text not null, claim_kind text not null check(claim_kind in ('cosmetic','suitability','hydration')),
  active boolean not null default false
);
create table public.product_concerns (
  product_id uuid references public.products(id), concern_id text references public.concerns(id),
  evidence_id uuid references public.evidence(id), status public.review_status not null default 'pending',
  qualification text not null, primary key(product_id,concern_id),
  check(status<>'approved' or evidence_id is not null)
);
create table public.collections (
  id uuid primary key default gen_random_uuid(), slug text not null unique, name text not null,
  status public.publication_status not null default 'draft'
);
create table public.collection_products (
  collection_id uuid references public.collections(id), product_id uuid references public.products(id),
  position integer not null check(position>=0), primary key(collection_id,product_id), unique(collection_id,position)
);
create table public.media_assets (
  id uuid primary key default gen_random_uuid(), provider text not null check(provider in ('cloudinary','supabase_private')),
  cloudinary_public_id text, cloudinary_version bigint, cloudinary_resource_type text,
  cloudinary_format text, private_bucket text, private_path text,
  width integer check(width>0), height integer check(height>0), alt text,
  status public.review_status not null default 'pending', created_at timestamptz not null default now(),
  check((provider='cloudinary' and cloudinary_public_id is not null and cloudinary_version is not null and private_path is null and private_bucket is null)
    or (provider='supabase_private' and private_bucket='catalog-private' and private_path is not null and cloudinary_public_id is null)),
  check(status<>'approved' or provider='cloudinary'), unique(cloudinary_public_id,cloudinary_version), unique(private_bucket,private_path)
);
create table public.product_media (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id), variant_id uuid,
  media_id uuid not null references public.media_assets(id), position integer not null check(position>=0), is_primary boolean not null default false,
  foreign key(variant_id,product_id) references public.variants(id,product_id),
  unique nulls not distinct(product_id,variant_id,position), unique nulls not distinct(product_id,variant_id,media_id)
);
create unique index product_media_primary on public.product_media(product_id,coalesce(variant_id,'00000000-0000-0000-0000-000000000000'::uuid)) where is_primary;
create table public.factory_set_contents (
  id uuid primary key default gen_random_uuid(), set_variant_id uuid not null references public.variants(id),
  position integer not null check(position>=0), name text not null, quantity integer not null check(quantity>0),
  size_value numeric(12,4) check(size_value>0), size_unit text check(size_unit in ('ml','g')), shade text,
  evidence_id uuid references public.evidence(id), unique(set_variant_id,position)
);

-- Source data never shares a row with public catalog content.
create table public.import_batches (
  id uuid primary key default gen_random_uuid(), source_sha256 text not null check(source_sha256 ~ '^[0-9a-f]{64}$'),
  contract_version text not null, contract_sha256 text not null, created_at timestamptz not null default now(),
  created_by uuid references auth.users(id), unique(source_sha256,contract_sha256)
);
create table public.import_records (
  id uuid primary key default gen_random_uuid(), batch_id uuid not null references public.import_batches(id),
  source_row integer not null, original_sku text, variant_id uuid references public.variants(id),
  raw_fields jsonb not null, mapping jsonb not null, source_quantity integer check(source_quantity>=0),
  source_cost_minor bigint check(source_cost_minor>=0), source_target_minor bigint check(source_target_minor>=0),
  source_minimum_minor bigint check(source_minimum_minor>=0), source_market_minor bigint check(source_market_minor>=0),
  state text not null check(state in ('staged','unchanged','needs_review','quarantined')),
  flags jsonb not null default '[]', unique(batch_id,source_row)
);
create table public.product_checks (
  product_id uuid references public.products(id), code text not null, approved boolean not null default false,
  evidence_id uuid references public.evidence(id), approved_by uuid references auth.users(id), approved_at timestamptz,
  primary key(product_id,code), check(not approved or (approved_by is not null and approved_at is not null))
);
create table public.publication_requirements (
  scope public.catalog_scope, code text, kind text not null check(kind in ('essential','optional','review_note')),
  description text not null, primary key(scope,code)
);
create table public.audit_logs (
  id bigint generated always as identity primary key, actor_id uuid, occurred_at timestamptz not null default now(),
  table_name text not null, record_key text, operation text not null,
  -- No customer payload, credentials, row copies or order addresses in audit logs.
  changed_columns text[] not null default '{}'
);

create index products_search on public.products using gin(search_vector);
create index products_name_trgm on public.products using gin(name extensions.gin_trgm_ops);
create index variants_sku_trgm on public.variants using gin(original_sku extensions.gin_trgm_ops);
create index products_category_status on public.products(category_id,status);
create index variants_product_status on public.variants(product_id,status);
create index import_records_sku on public.import_records(original_sku);
create index product_media_owner on public.product_media(product_id,variant_id);
