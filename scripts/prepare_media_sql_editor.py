"""Generate the incremental media installer; never alter the six applied migrations."""
from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'supabase/migrations/202610050007_media_service.sql'
digest=hashlib.sha256(source.read_bytes()).hexdigest()
sql="""-- Incremental media service only. Run the ENTIRE file once in the development SQL Editor.
-- Additive columns/table/functions/triggers; no product import or existing-row deletion.
begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
select pg_advisory_xact_lock(73523);
do $$ begin
 if to_regclass('app_private.sql_editor_receipts') is null then raise exception 'Six-migration SQL Editor installation receipt required'; end if;
 if (select count(*) from app_private.sql_editor_receipts where version between '202610050001' and '202610050006')<>6 then raise exception 'Prerequisite receipts missing'; end if;
 if to_regclass('public.media_workflows') is not null then raise exception 'Media migration already present; do not overwrite'; end if;
end $$;
"""+source.read_text(encoding='utf-8')+"\ninsert into app_private.sql_editor_receipts(version,filename,sha256) values('202610050007','202610050007_media_service.sql','"+digest+"');\nnotify pgrst, 'reload schema';\ncommit;\nselect 'MEDIA SERVICE MIGRATION COMMITTED' as result;\n"
(ROOT/'supabase/sql-editor/05_install_media_service.sql').write_text(sql,encoding='utf-8')
print('Prepared additive migration 007 SQL Editor file; no connection made.')
