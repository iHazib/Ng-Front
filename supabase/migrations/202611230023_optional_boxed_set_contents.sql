-- 023: Owner-requested removal of boxed-set confirmation gates only.
-- Keep original set classification, contents, SKU identities, inventory and audit history.
-- Rewrite checked function definitions in place, preserving OIDs/ACLs/owners/settings.
do $boxed_gate$
declare definition text; signature text; needle text;
begin
 signature='app_private.publication_blockers(uuid)';
 definition=pg_get_functiondef(to_regprocedure(signature));
 if definition is null then raise exception 'Required function missing: %',signature;end if;
 needle=$fragment$ if exists(select 1 from public.variants where product_id=p_product and status<>'archived' and sellable_kind='unconfirmed_set') then missing=array_append(missing,'set_contents_missing'); end if;
$fragment$;
 if position(needle in definition)=0 then raise exception 'Unexpected function definition: %. Review before applying; no changes committed.',signature;end if;
 definition=replace(definition,needle,$fragment$$fragment$);
 needle=$fragment$ if exists(select 1 from public.variants v where v.product_id=p_product and v.status<>'archived' and v.sellable_kind='factory_set' and not exists(select 1 from public.factory_set_contents c where c.set_variant_id=v.id)) then missing=array_append(missing,'set_contents_missing'); end if;
$fragment$;
 if position(needle in definition)=0 then raise exception 'Unexpected function definition: %. Review before applying; no changes committed.',signature;end if;
 definition=replace(definition,needle,$fragment$$fragment$);
 execute definition;
 signature='public.variant_is_public(uuid)';
 definition=pg_get_functiondef(to_regprocedure(signature));
 if definition is null then raise exception 'Required function missing: %',signature;end if;
 needle=$fragment$and v.sellable_kind<>'unconfirmed_set' and p.approved$fragment$;
 if position(needle in definition)=0 then raise exception 'Unexpected function definition: %. Review before applying; no changes committed.',signature;end if;
 definition=replace(definition,needle,$fragment$and p.approved$fragment$);
 execute definition;
 signature='app_private.admin_current_issues(uuid)';
 definition=pg_get_functiondef(to_regprocedure(signature));
 if definition is null then raise exception 'Required function missing: %',signature;end if;
 needle=$fragment$,
 ('set_contents_missing',true,v.sellable_kind='unconfirmed_set' or (v.sellable_kind='factory_set' and not exists(select 1 from public.factory_set_contents s where s.set_variant_id=v.id)))$fragment$;
 if position(needle in definition)=0 then raise exception 'Unexpected function definition: %. Review before applying; no changes committed.',signature;end if;
 definition=replace(definition,needle,$fragment$$fragment$);
 execute definition;
 signature='app_private.daily_product_issues(uuid)';
 definition=pg_get_functiondef(to_regprocedure(signature));
 if definition is null then raise exception 'Required function missing: %',signature;end if;
 needle=$fragment$'factory_pack_and_contents_unconfirmed',$fragment$;
 if position(needle in definition)=0 then raise exception 'Unexpected function definition: %. Review before applying; no changes committed.',signature;end if;
 definition=replace(definition,needle,$fragment$$fragment$);
 execute definition;
end $boxed_gate$;
-- Retire only derived boxed-set reminders; retain dismissal/audit history.
update app_private.admin_reminder_issues set active=false where active and code in ('set_contents_missing','factory_pack_and_contents_unconfirmed');
