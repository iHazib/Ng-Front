-- 019: rebind existing policy OIDs after 017 renamed the legacy helper.
-- No rows, grants, RLS settings, roles or visibility predicates are changed.
do $rebind$
declare p record; expression text; changed integer=0;
begin
 for p in select pol.oid,pol.polname,pol.polrelid,pg_get_expr(pol.polqual,pol.polrelid) predicate
 from pg_policy pol join pg_depend d on d.classid='pg_policy'::regclass and d.objid=pol.oid
 where d.refclassid='pg_proc'::regclass and d.refobjid='app_private.media_is_public_016(uuid)'::regprocedure
 loop
  if p.polname<>'public_read' or p.polrelid not in('public.product_media'::regclass,'public.article_media'::regclass,'public.homepage_selections'::regclass,'public.homepage_media'::regclass,'public.review_media'::regclass) then
   raise exception 'Unexpected legacy media policy dependency; inspect before proceeding';
  end if;
  expression=replace(p.predicate,'app_private.media_is_public_016(', 'public.media_is_public(');
  if expression=p.predicate then raise exception 'Unrecognized legacy policy expression';end if;
  execute format('alter policy %I on %s using (%s)',p.polname,p.polrelid::regclass,expression);
  changed=changed+1;
 end loop;
 if changed<>5 then raise exception 'Expected exactly five legacy media policies, found %',changed;end if;
end $rebind$;
