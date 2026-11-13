"""Prepare deterministic SQL taxonomy seed and private RPC fixture, never connect."""
import json
from decimal import Decimal
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def quote(value):
    if value is None: return 'null'
    if isinstance(value,bool): return str(value).lower()
    return "'"+str(value).replace("'","''")+"'"

def prepare():
    c=json.loads((ROOT/'data/catalog-contract/review.json').read_text(encoding='utf-8'))
    sql=['-- Controlled taxonomy from reviewed contract. No source inventory or approvals.']
    def insert(table,cols,values):
        sql.append('insert into public.'+table+'('+','.join(cols)+') values('+','.join(quote(v) for v in values)+') on conflict do nothing;')
    for b in c['brands']:
        insert('brands',['id','name'],[b['id'],b['name']])
        for a in b['aliases']: insert('brand_aliases',['brand_id','alias'],[b['id'],a])
    scopes={'skincare','makeup','bath-body','hair-care','personal-fragrance','home-fragrance','cutlery'}
    for cat in c['categories']:
        root=cat['id'].split('/')[0]
        insert('categories',['id','parent_id','name','scope'],[cat['id'],cat['parent_id'],cat['label'],root if root in scopes else None])
    for t in c['product_types']: insert('product_types',['id','name'],[t['id'],t['label']])
    for r in c['sku_reviews'].values(): insert('category_product_types',['category_id','product_type_id'],[r['proposed_category'],r['product_type']])
    insert('option_axes',['id','name'],['shade','Shade'])
    for v in c['value_registries']['variant_option_values']: insert('option_values',['id','axis_id','label'],[v['id'],'shade',v['label']])
    for f in c['facets']:
        insert('facet_definitions',['id','name','kind'],[f['id'],f['id'],f['type']])
        for scope in f['scopes']: insert('facet_scopes',['facet_id','scope'],[f['id'],scope])
        for value in f.get('values',[]): insert('facet_values',['id','facet_id','label'],[f['id']+':'+value,f['id'],value])
    for v in c['value_registries']['variant_option_values']: insert('facet_values',['id','facet_id','label'],[v['id'],'shade',v['label']])
    for concern in c['concerns']:
        kind='suitability' if concern['id'] in ('acne-and-blemishes','sensitive-skin') else 'hydration' if concern['id']=='dryness' else 'cosmetic'
        insert('concerns',['id','name','claim_kind'],[concern['id'],concern['label'],kind])
    (ROOT/'supabase/migrations/202610050005_taxonomy.sql').write_text('\n'.join(sql)+'\n',encoding='utf-8')
    records=json.loads((ROOT/'data/catalog-dry-run/sku-mapping.json').read_text(encoding='utf-8'))
    for r in records:
        for short,field in [('cost','Unit Cost (PKR)'),('target','Target Price (PKR)'),('minimum','Minimum Price (PKR)'),('market','Market Price (PKR)')]:
            raw=r['raw_source_fields'][field]
            amount=Decimal(raw)*100 if raw is not None else None
            if amount is not None and (amount!=amount.to_integral_value() or abs(amount)>9007199254740991): raise ValueError('Invalid minor unit conversion')
            r['source_'+short+'_minor']=int(amount) if amount is not None else None
    summary=json.loads((ROOT/'data/catalog-dry-run/summary.json').read_text(encoding='utf-8'))
    payload={'p_source_hash':summary['source_sha256'],'p_contract_hash':summary['contract_sha256'],'p_version':c['version'],'p_records':records}
    (ROOT/'data/catalog-dry-run/database-payload.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Prepared taxonomy migration and private 121-row fixture; no connection made.')

if __name__=='__main__': prepare()
