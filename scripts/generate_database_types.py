"""TypeScript table types generated from applied PostgreSQL information_schema."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def generate(rows,enums):
    enum_map={e['typname']:e['labels'] for e in enums}
    def type_for(r):
        t=r['udt_name']
        base=('Database["public"]["Enums"]["'+t+'"]') if t in enum_map else {'uuid':'string','text':'string','timestamptz':'string','date':'string','tsvector':'string','int2':'number','int4':'number','int8':'number','numeric':'number','bool':'boolean','jsonb':'Json','_text':'string[]'}.get(t,'unknown')
        return base+(' | null' if r['is_nullable']=='YES' else '')
    tables={}
    for r in rows: tables.setdefault(r['table_name'],[]).append(r)
    out=['// Generated from the disposable migrated PostgreSQL database. Do not hand-edit.','export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];','export type Database = { public: { Tables: {']
    for table,columns in tables.items():
        out+=['  '+table+': {','    Row: {']
        for r in columns: out+=['      '+r['column_name']+': '+type_for(r)+';']
        out+=['    };','    Insert: {']
        for r in columns:
            if r['is_identity']=='YES' or r['column_name'] in ('sku_key','normalized','collision_key','search_vector'): continue
            optional=r['is_nullable']=='YES' or r['column_default'] is not None
            out+=['      '+r['column_name']+('?' if optional else '')+': '+type_for(r)+';']
        out+=['    };','    Update: Partial<Database["public"]["Tables"]["'+table+'"]["Insert"]>;','  };']
    out+=['}; Enums: {']
    for name,labels in enum_map.items(): out+=['  '+name+': '+' | '.join('"'+v+'"' for v in labels)+';']
    out+=['}; }; };','export type TableName = keyof Database["public"]["Tables"];','export type Row<T extends TableName> = Database["public"]["Tables"][T]["Row"];']
    dest=ROOT/'src/lib/server/database/database.types.ts';dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text('\n'.join(out)+'\n',encoding='utf-8')
