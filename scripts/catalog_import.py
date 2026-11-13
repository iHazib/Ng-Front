"""Offline, read-only XLSX -> lossless source capture and draft catalog plan.

Python 3.11+ standard library only. Never opens a network or database connection.
See docs/catalog-import-contract.md. The source XLSX is never saved or modified.
"""
import argparse
from collections import Counter, defaultdict
import csv
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path
import re
import unicodedata
import uuid
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
RID = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id'
ID_NAMESPACE = uuid.UUID('51299a68-a4ca-51ca-a072-bf0b47152287')
HEADINGS = {'HOME APPLIANCES'}
BASE_REQUIREMENTS = ['identity', 'taxonomy', 'content', 'condition', 'primary_media',
                     'publication_review', 'approved_variant_price_stock']
CATEGORY_REQUIREMENTS = {
    'skincare': 'cosmetic_label', 'makeup': 'makeup_identity', 'bath-body': 'body_scope',
    'hair-care': 'hair_scope', 'personal-fragrance': 'fragrance_identity',
    'home-fragrance': 'home_use', 'cutlery': 'cutlery_specification',
}


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def digest(value):
    return hashlib.sha256(value if isinstance(value, bytes) else canonical(value).encode()).hexdigest()


def sku_key(sku):
    """Collision detector only. Never the identity, replacement SKU, or lookup key."""
    return re.sub(r'\s*-\s*', '-', unicodedata.normalize('NFKC', sku).strip()).upper()


def identifier(kind, sku):
    return str(uuid.uuid5(ID_NAMESPACE, f'{kind}:{sku}'))


def read_workbook(path):
    binary = path.read_bytes()
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError('Workbook CRC failure')
        shared = []
        if 'xl/sharedStrings.xml' in archive.namelist():
            for si in ET.fromstring(archive.read('xl/sharedStrings.xml')).findall('m:si', NS):
                shared.append(''.join(si.itertext()))
        relationships = {r.attrib['Id']: r.attrib['Target'] for r in
                         ET.fromstring(archive.read('xl/_rels/workbook.xml.rels'))}
        sheets = []
        workbook = ET.fromstring(archive.read('xl/workbook.xml'))
        for sheet in workbook.findall('m:sheets/m:sheet', NS):
            target = relationships[sheet.attrib[RID]]
            target = target.lstrip('/') if target.startswith('/') else 'xl/' + target
            xml = ET.fromstring(archive.read(target))
            cells = []
            for cell in xml.findall('m:sheetData/m:row/m:c', NS):
                raw_value = cell.findtext('m:v', default=None, namespaces=NS)
                formula = cell.find('m:f', NS)
                kind = cell.get('t', 'n')
                inline = cell.find('m:is', NS)
                value = raw_value
                if kind == 's' and raw_value is not None:
                    value = shared[int(raw_value)]
                elif kind == 'inlineStr':
                    value = ''.join(inline.itertext()) if inline is not None else ''
                cells.append({'coordinate': cell.attrib['r'], 'type': kind,
                              'style': cell.get('s'), 'value': value,
                              'formula': formula.text if formula is not None else None,
                              'formula_attributes': dict(formula.attrib) if formula is not None else {},
                              'raw_xml': ET.tostring(cell, encoding='unicode')})
            sheets.append({'name': sheet.attrib['name'], 'state': sheet.get('state', 'visible'),
                           'dimension': xml.find('m:dimension', NS).get('ref'), 'cells': cells})
        return {'source_filename': path.name, 'sha256': digest(binary),
                'archive_members': {n: digest(archive.read(n)) for n in sorted(archive.namelist())},
                'sheets': sheets}


def source_rows(capture):
    sheet = next(s for s in capture['sheets'] if s['name'] == 'Product Listings')
    rows = defaultdict(dict)
    for cell in sheet['cells']:
        col, number = re.fullmatch(r'([A-Z]+)(\d+)', cell['coordinate']).groups()
        rows[int(number)][col] = cell
    headers = {col: c['value'] for col, c in rows[1].items() if c['value'] is not None}
    if headers.get('A') != 'SKU' or headers.get('B') != 'Product Name':
        raise ValueError('Unrecognized Product Listings header; review source before import')
    if len(headers.values()) != len(set(headers.values())):
        raise ValueError('Duplicate column headers; preserve source and repair contract')
    records, skipped = [], []
    last_row = int(re.search(r'\d+$', sheet['dimension']).group())
    for number in range(2, last_row + 1):
        cells = rows[number]
        fields = {label: cells.get(col, {}).get('value') for col, label in headers.items()}
        # Formula-only template rows are not products. Preserve their XML in the capture.
        substantive = [c['value'] for col, c in cells.items() if col != 'Y' and c['value'] not in (None, '')]
        if not substantive:
            skipped.append({'row': number, 'reason': 'empty_or_formula_template'})
            continue
        if len(substantive) == 1 and str(substantive[0]).strip().upper() in HEADINGS:
            skipped.append({'row': number, 'reason': 'heading', 'value': substantive[0]})
            continue
        records.append({'row': number, 'fields': fields, 'cells': cells,
                        'fingerprint': digest(fields)})
    return records, skipped


def number(value, integer=False):
    if value in (None, ''):
        return None
    try:
        result = Decimal(str(value))
        if not result.is_finite() or result < 0 or (integer and result != result.to_integral_value()):
            return None
        return int(result) if integer else format(result, 'f')
    except InvalidOperation:
        return None


def plan(rows, contract, previous=None):
    exact, normalized = defaultdict(list), defaultdict(set)
    for row in rows:
        sku = row['fields'].get('SKU')
        if sku:
            exact[sku].append(row['row'])
            normalized[sku_key(sku)].add(sku)
    previous = previous or []
    previous_by_sku = {r['original_sku']: r for r in previous if r['original_sku']}
    previous_keys = defaultdict(set)
    for sku in previous_by_sku:
        previous_keys[sku_key(sku)].add(sku)
    mappings = []
    definitions = {f['id']: f for f in contract['facets']}
    category_ids = {c['id'] for c in contract['categories']}
    evidence_ids = {e['id'] for e in contract['evidence']}
    brand_ids = {b['id'] for b in contract['brands']}
    type_definitions = {t['id']: t for t in contract['product_types']}
    concern_ids = {c['id'] for c in contract['concerns']}
    for row in rows:
        raw = row['fields']
        sku = raw.get('SKU')
        errors, flags = [], []
        if not sku:
            errors.append('missing_sku')
        elif len(exact[sku]) > 1:
            errors.append('duplicate_exact_sku')
        if sku and len(normalized[sku_key(sku)] | previous_keys[sku_key(sku)]) > 1:
            errors.append('normalization_collision')
        review = contract['sku_reviews'].get(sku, {})
        if not review:
            flags.append('new_sku_requires_mapping')
        if review and review['source_fingerprint'] != row['fingerprint']:
            flags.append('source_changed_review_stale')
        category = review.get('proposed_category')
        if category and category not in category_ids:
            errors.append('unknown_category')
        if review.get('brand_id') and review['brand_id'] not in brand_ids:
            errors.append('unknown_brand')
        product_type = type_definitions.get(review.get('product_type'))
        if review and (not product_type or review.get('facet_scope') not in product_type['scopes']):
            errors.append('invalid_product_type')
        for concern in review.get('concern_proposals', []):
            if concern['concern_id'] not in concern_ids or review.get('facet_scope') != 'skincare':
                errors.append('invalid_concern_scope')
            if not concern.get('evidence') or any(e not in evidence_ids for e in concern['evidence']):
                errors.append('missing_concern_evidence')
        for field in ('Target Price (PKR)', 'Quantity'):
            col = next((c for c, v in row['cells'].items() if v['coordinate'].rstrip('0123456789') == ('J' if field.startswith('Target') else 'H')), None)
            if col and row['cells'][col]['formula']:
                errors.append('formula_in_' + ('price' if field.startswith('Target') else 'stock'))
        price = number(raw.get('Target Price (PKR)'))
        stock = number(raw.get('Quantity'), integer=True)
        if price is None or Decimal(price) <= 0:
            flags.append('missing_or_invalid_selling_price')
        if stock is None:
            flags.append('missing_or_invalid_stock')
        if sku and sku != sku_key(sku):
            flags.append('sku_format_review_do_not_rename')
        proposals = review.get('filter_values', [])
        for prop in proposals:
            definition = definitions.get(prop['facet'])
            if not definition or review.get('facet_scope') not in definition['scopes']:
                errors.append('invalid_facet_scope')
                continue
            if not prop.get('evidence') or any(e not in evidence_ids and not e.startswith('workbook:') for e in prop['evidence']):
                errors.append('missing_facet_evidence')
            if definition['type'] == 'enum' and prop['value'] not in definition['values']:
                errors.append('unknown_facet_value')
            if definition['type'] == 'quantity':
                v = prop['value']
                if not isinstance(v, dict) or v.get('unit') not in definition['units'] or number(v.get('amount')) is None:
                    errors.append('invalid_quantity_facet')
            if definition['type'] == 'integer' and (number(prop['value'], integer=True) is None or int(prop['value']) < definition.get('minimum', 0)):
                errors.append('invalid_integer_facet')
            if definition['type'] == 'reference' and prop['value'] not in {v['id'] for v in contract.get('value_registries', {}).get(definition['target'], [])}:
                errors.append('unknown_facet_reference')
        original = previous_by_sku.get(sku)
        operation = 'quarantine' if errors else ('unchanged' if original and original['source_fingerprint'] == row['fingerprint'] and original.get('review_fingerprint') == digest(review) else 'stage_update' if original else 'stage_draft')
        requirements = BASE_REQUIREMENTS.copy()
        if review.get('facet_scope') in CATEGORY_REQUIREMENTS:
            requirements.append(CATEGORY_REQUIREMENTS[review['facet_scope']])
        if review.get('sellable_kind') == 'factory_set_candidate':
            requirements.append('factory_pack_and_contents_confirmed')
        if review.get('product_type') == 'sunscreen':
            requirements.append('spf_label')
        mappings.append({
            'original_sku': sku, 'sku_normalization_proposal': sku_key(sku) if sku else None,
            'product_id': original['product_id'] if original else identifier('product', sku) if sku else None,
            'variant_id': original['variant_id'] if original else identifier('variant', sku) if sku else None,
            'source': {'sheet': 'Product Listings', 'row': row['row']},
            'source_fingerprint': row['fingerprint'], 'review_fingerprint': digest(review),
            'raw_source_fields': raw,
            'original_category': {'main': raw.get('Main Category'), 'category': raw.get('Subcategory'), 'type': raw.get('Product Type / Sub-Subcategory')},
            'proposed_category': category, 'menu_family': review.get('menu_family'),
            'product_type': review.get('product_type'), 'normalized_brand_id': review.get('brand_id'),
            'family_candidate': review.get('family_candidate'), 'confirmed_family_id': None,
            'family_state': 'unconfirmed_separate_product',
            'variant_attributes': review.get('variant_attributes', []),
            'sellable_kind': review.get('sellable_kind', 'unresolved'),
            'source_stock_units': stock, 'stock_application': 'pending_snapshot_reconciliation',
            'proposed_price_pkr': price, 'published_price_pkr': None,
            'filter_values': proposals, 'active_filter_values': [],
            'core_filter_proposals': {'brand': review.get('brand_id'), 'category': category, 'product_type': review.get('product_type'), 'state': 'inactive_pending_publication'},
            'source_concern_candidates': raw.get('Search Concern(s)'),
            'concern_proposals': review.get('concern_proposals', []), 'approved_concerns': [],
            'curated_collections': [], 'evidence': review.get('evidence', []),
            'evidence_status': 'stale_requires_recheck' if 'source_changed_review_stale' in flags else review.get('evidence_status', 'unreviewed'),
            'proposed_corrections': review.get('proposed_corrections', []),
            'approval_state': 'draft', 'import_operation': operation,
            'blocking_import_errors': sorted(set(errors)),
            'unresolved_flags': sorted(set(flags + review.get('unresolved_flags', []))),
            'publication_requirements': requirements,
            'publication_profile': {
                'scope': review.get('facet_scope'), 'essential_blockers': requirements,
                'optional_enrichment': ['concerns', 'secondary_media', 'reviews', 'verified_extra_facets', 'curated_collections'],
                'review_notes': review.get('required_package_details', []),
                'concern_research_status': 'partially_complete',
                'draft_import_requires_photos': False,
            },
            'proposed_source_changes': {key: {'previous': original['raw_source_fields'].get(key), 'incoming': value}
                                        for key, value in raw.items() if original and original['raw_source_fields'].get(key) != value},
            'admin_values_action': 'preserve; present source changes for field-level review',
        })
    present = {r['original_sku'] for r in mappings}
    retained = [{'original_sku': sku, 'operation': 'retain_existing_source_absent'} for sku in sorted(set(previous_by_sku) - present)]
    return mappings, retained


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def run(source, contract_path, output, previous_path=None):
    if output.resolve().is_relative_to((ROOT / 'public').resolve()):
        raise ValueError('Private catalog output must not be written under public/')
    contract = json.loads(contract_path.read_text(encoding='utf-8'))
    capture = read_workbook(source)
    rows, skipped = source_rows(capture)
    previous = json.loads(previous_path.read_text(encoding='utf-8')) if previous_path else None
    mappings, retained = plan(rows, contract, previous)
    summary = {'contract_version': contract['version'], 'source_sha256': capture['sha256'],
               'contract_sha256': digest(contract_path.read_bytes()), 'source_product_rows': len(rows),
               'unique_exact_skus': len({r['original_sku'] for r in mappings if r['original_sku']}),
               'draft_records': len(mappings), 'publishable_records': 0,
               'quarantined_records': sum(bool(r['blocking_import_errors']) for r in mappings),
               'exact_duplicate_rows': sum('duplicate_exact_sku' in r['blocking_import_errors'] for r in mappings),
               'normalization_collision_rows': sum('normalization_collision' in r['blocking_import_errors'] for r in mappings),
               'operations': dict(sorted(Counter(r['import_operation'] for r in mappings).items())),
               'category_counts': dict(sorted(Counter(r['proposed_category'] or 'unmapped' for r in mappings).items())),
               'source_stock_units_total': sum(r['source_stock_units'] or 0 for r in mappings),
               'skipped_rows': skipped, 'retained_absent_records': retained,
               'network_operations': 0, 'database_operations': 0,
               'notes': ['Stock totals are source snapshots, not available-to-sell stock.',
                         'All values are private draft proposals; no publication or automatic grouping.',
                         'Historical workbook instructions and review sheets are source data, not executable rules.']}
    output.mkdir(parents=True, exist_ok=True)
    write_json(output / 'raw-workbook.json', capture)
    write_json(output / 'sku-mapping.json', mappings)
    write_json(output / 'summary.json', summary)
    write_json(output / 'import-plan.json', {'records': [{k: r[k] for k in ['original_sku', 'product_id', 'variant_id', 'import_operation', 'blocking_import_errors', 'proposed_source_changes', 'admin_values_action']} for r in mappings], 'retained_absent_records': retained})
    fields = ['original_sku', 'source', 'raw_source_fields', 'original_category', 'proposed_category', 'menu_family', 'product_type', 'normalized_brand_id', 'variant_attributes', 'core_filter_proposals', 'filter_values', 'concern_proposals', 'family_candidate', 'sellable_kind', 'source_stock_units', 'proposed_price_pkr', 'evidence', 'evidence_status', 'approval_state', 'blocking_import_errors', 'unresolved_flags', 'proposed_corrections', 'publication_requirements']
    with (output / 'sku-mapping.csv').open('w', encoding='utf-8-sig', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=fields)
        writer.writeheader()
        for record in mappings:
            # JSON is authoritative. Excel-friendly view escapes formula-like text.
            display = {k: canonical(record[k]) if isinstance(record[k], (dict, list)) else record[k] for k in fields}
            writer.writerow({k: "'" + v if isinstance(v, str) and v.startswith(('=', '+', '-', '@')) else v for k, v in display.items()})
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'data/imports/Nook_Glow_Product_Listing_Updated.xlsx')
    parser.add_argument('--contract', type=Path, default=ROOT / 'data/catalog-contract/review.json')
    parser.add_argument('--output', type=Path, default=ROOT / 'data/catalog-dry-run')
    parser.add_argument('--previous', type=Path, help='Prior sku-mapping.json for a repeat/update dry run')
    args = parser.parse_args()
    if args.output.resolve().is_relative_to((ROOT / 'public').resolve()):
        parser.error('Private catalog output must not be written under public/')
    result = run(args.source, args.contract, args.output, args.previous)
    print(json.dumps({k: v for k, v in result.items() if k not in ('skipped_rows', 'category_counts', 'notes')}, indent=2))
