"""Prepare and audit the supplied package. No application or database operations.

Run with bundled Python (Pillow and openpyxl), passing the original Web-Assets.zip.
Existing files are only accepted when byte-identical; conflicting files are never replaced.
"""
import argparse
import base64
import collections
import csv
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import zipfile

from PIL import Image
import openpyxl

ROOT = Path(__file__).resolve().parents[1]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def destination(relative):
    path = PurePosixPath(relative)
    assert not path.is_absolute() and '..' not in path.parts and '\\' not in relative
    result = (ROOT / relative).resolve()
    assert result.is_relative_to(ROOT)
    return result


def preserve(relative, data):
    target = destination(relative)
    if target.exists():
        assert target.read_bytes() == data, f'Existing file conflict: {relative}'
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)


def decode(data):
    with Image.open(io.BytesIO(data)) as image:
        image.verify()
    with Image.open(io.BytesIO(data)) as image:
        image.load()
        return {'width': image.width, 'height': image.height, 'format': image.format}


def csv_write(name, records, fields):
    with (ROOT / 'docs' / name).open('w', encoding='utf-8', newline='') as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        writer.writerows(records)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    original = args.archive.read_bytes()
    outer = zipfile.ZipFile(io.BytesIO(original))
    assert outer.testzip() is None, 'Outer ZIP CRC failure'
    nested_bytes = outer.read('Web-Assets/Nook_Glow_Approved_Homepage_Handoff.zip')
    inner = zipfile.ZipFile(io.BytesIO(nested_bytes))
    assert inner.testzip() is None, 'Nested ZIP CRC failure'
    pairs = [
        ('Web-Assets/Nook_Glow_Homepage_Wireframe (12).html', 'design/reference/Nook_Glow_Homepage_Wireframe.html'),
        ('Web-Assets/Nook_Glow_Product_Listing_Updated.xlsx', 'data/imports/Nook_Glow_Product_Listing_Updated.xlsx'),
    ]
    comparisons = [{'top_level': a, 'nested': b, 'top_sha256': digest(outer.read(a)),
                    'nested_sha256': digest(inner.read(b)), 'identical': outer.read(a) == inner.read(b)}
                   for a, b in pairs]
    assert all(p['identical'] for p in comparisons), f'Source conflict; no extraction: {comparisons}'
    # Validate all archive paths and image bytes before writing any supplied content.
    image_records = []
    for archive, prefix in [(outer, 'outer'), (inner, 'handoff')]:
        for entry in archive.infolist():
            destination(entry.filename)
            if not entry.is_dir() and Path(entry.filename).suffix.lower() in {'.png', '.webp', '.jpg', '.jpeg', '.gif'}:
                data = archive.read(entry)
                local = entry.filename.removeprefix('Web-Assets/') if prefix == 'outer' else entry.filename
                image_records.append({'path': local, 'source': prefix, 'bytes': len(data),
                                      'sha256': digest(data), **decode(data)})
    html = outer.read(pairs[0][0]).decode('utf-8')
    embedded = re.findall(r'data:image/[^;\s]+;base64,([A-Za-z0-9+/=\r\n]+)', html)
    embedded_images = [decode(base64.b64decode(value, validate=False)) for value in embedded]
    manifest = json.loads(inner.read('design/reference/asset-manifest.json'))
    contract = inner.read('src/config/assets.ts').decode('utf-8')
    paths = re.findall(r'"(/assets/[^"\s]+)"', contract)
    assert len(paths) == len(set(paths)), 'Duplicate contract paths'
    assert set(paths) == {entry['path'] for entry in manifest}, 'Contract/manifest path mismatch'
    for entry in manifest:
        raw = inner.read('public' + entry['path'])
        dimensions = decode(raw)
        assert digest(raw) == entry['sha256'], f'Manifest hash mismatch: {entry["path"]}'
        assert (dimensions['width'], dimensions['height']) == (entry['width'], entry['height'])
    assert {'/' + p.removeprefix('public/') for p in inner.namelist() if p.startswith('public/') and not p.endswith('/')} == set(paths)

    workbook_bytes = outer.read(pairs[1][0])
    with zipfile.ZipFile(io.BytesIO(workbook_bytes)) as book_zip:
        assert book_zip.testzip() is None, 'Workbook ZIP CRC failure'
    workbook = openpyxl.load_workbook(io.BytesIO(workbook_bytes), read_only=True, data_only=False)
    sheet = workbook['Product Listings']
    catalog, excluded = [], []
    for number, row in enumerate(sheet.values, 1):
        if number == 1:
            assert row[0] == 'SKU' and row[1] == 'Product Name'
            continue
        sku = row[0]
        if isinstance(sku, str) and re.fullmatch(r'[A-Z0-9]+\s*-\s*\d+', sku):
            assert row[1], f'Missing product name at row {number}'
            catalog.append({'sheet': sheet.title, 'row': number, 'sku': sku, 'product_name': row[1],
                            'category': row[4] or '', 'sku_format_review': 'spaces around hyphen' if ' ' in sku else ''})
        elif any(value is not None for value in row[:7]):
            excluded.append({'row': number, 'values': list(row[:7])})
    skus = [p['sku'] for p in catalog]
    assert len(skus) == len(set(skus)), 'Duplicate source SKUs'
    imports = [p for p in image_records if p['source'] == 'outer']
    matched, unmatched = [], []
    for item in imports:
        stem = Path(item['path']).stem
        item['exact_sku'] = stem if stem in skus else ''
        (matched if item['exact_sku'] else unmatched).append(item['path'])
    missing = [sku for sku in skus if sku not in {p['exact_sku'] for p in imports}]
    for item in image_records:
        item.setdefault('exact_sku', '')
    sheets = [{'name': s.title, 'rows': s.max_row, 'columns': s.max_column} for s in workbook]
    workbook.close()

    preserve('local-sources/Web-Assets.zip', original)
    preserve('local-sources/Nook_Glow_Approved_Homepage_Handoff.zip', nested_bytes)
    for top, target in pairs:
        preserve('local-sources/' + PurePosixPath(top).name, outer.read(top))
    for entry in inner.infolist():
        if not entry.is_dir():
            preserve(entry.filename, inner.read(entry))
    for top, target in pairs:
        preserve(target, outer.read(top))
    for entry in outer.infolist():
        if entry.filename.startswith('Web-Assets/product-images-import/'):
            local = entry.filename.removeprefix('Web-Assets/')
            if entry.is_dir():
                destination(local).mkdir(parents=True, exist_ok=True)
            else:
                preserve(local, outer.read(entry))
    for item in image_records:
        assert digest(destination(item['path']).read_bytes()) == item['sha256']
        decode(destination(item['path']).read_bytes())
    assert args.archive.read_bytes() == original, 'Original archive changed'
    report = {
        'source_archive': str(args.archive.resolve()), 'source_sha256': digest(original),
        'source_bytes': len(original), 'nested_sha256': digest(nested_bytes),
        'outer_crc_pass': True, 'nested_crc_pass': True, 'workbook_crc_pass': True,
        'source_comparisons': comparisons, 'source_preserved': True,
        'catalog_sheets': sheets, 'product_count': len(catalog), 'unique_sku_count': len(set(skus)),
        'excluded_non_product_rows': excluded, 'sku_format_reviews': [p for p in catalog if p['sku_format_review']],
        'import_image_count': len(imports), 'import_image_bytes': sum(p['bytes'] for p in imports),
        'exact_sku_image_count': len(matched), 'unmatched_files': unmatched,
        'skus_without_exact_import_image': missing,
        'contract_path_count': len(paths), 'manifest_entry_count': len(manifest),
        'handoff_image_count': len(image_records) - len(imports),
        'embedded_html_image_occurrences_decoded': len(embedded_images),
        'contract_paths_resolve': True, 'manifest_hashes_and_dimensions_match': True,
        'all_images_decode': True, 'source_conflicts': [],
    }
    (ROOT / 'docs').mkdir(exist_ok=True)
    (ROOT / 'docs/source-audit.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    csv_write('asset-inventory.csv', image_records, ['path', 'source', 'bytes', 'sha256', 'width', 'height', 'format', 'exact_sku'])
    csv_write('catalog-inventory.csv', catalog, ['sheet', 'row', 'sku', 'product_name', 'category', 'sku_format_review'])
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
