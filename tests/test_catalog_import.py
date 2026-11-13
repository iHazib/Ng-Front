"""Contract tests use in-memory mutations, never edit the supplied workbook."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from catalog_import import digest, plan, read_workbook, run, source_rows


class CatalogContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = ROOT / 'data/imports/Nook_Glow_Product_Listing_Updated.xlsx'
        cls.contract_path = ROOT / 'data/catalog-contract/review.json'
        cls.contract = json.loads(cls.contract_path.read_text(encoding='utf-8'))
        cls.capture = read_workbook(cls.source)
        cls.rows, cls.skipped = source_rows(cls.capture)
        cls.baseline, _ = plan(cls.rows, cls.contract)

    def test_complete_source_and_private_drafts(self):
        self.assertEqual(len(self.rows), 121)
        self.assertEqual(len(self.skipped), 418)
        self.assertEqual([s['row'] for s in self.skipped if s['reason'] == 'heading'], [125])
        self.assertEqual(sum(r['source_stock_units'] for r in self.baseline), 270)
        self.assertEqual(len({r['product_id'] for r in self.baseline}), 121)
        self.assertTrue(all(r['approval_state'] == 'draft' and not r['active_filter_values'] and not r['approved_concerns'] for r in self.baseline))
        self.assertTrue(all(not r['blocking_import_errors'] for r in self.baseline))
        self.assertEqual(len(self.capture['sheets']), 5)
        cells = {c['coordinate']: c for c in self.capture['sheets'][0]['cells']}
        self.assertEqual(cells['Y2']['formula'], 'H2*J2')
        self.assertEqual(cells['A109']['value'], 'DANM - 001')
        self.assertIn('raw_xml', cells['M44'])

    def test_repeat_is_unchanged_and_reordering_preserves_ids(self):
        repeated, retained = plan(list(reversed(self.rows)), self.contract, self.baseline)
        self.assertFalse(retained)
        self.assertTrue(all(r['import_operation'] == 'unchanged' for r in repeated))
        self.assertEqual({r['original_sku']: r['variant_id'] for r in repeated}, {r['original_sku']: r['variant_id'] for r in self.baseline})

    def test_exact_duplicate_only_quarantines_affected_rows(self):
        duplicate = copy.deepcopy(self.rows[0]); duplicate['row'] = 700
        results, _ = plan(self.rows + [duplicate], self.contract)
        self.assertEqual(sum(r['import_operation'] == 'quarantine' for r in results), 2)
        self.assertEqual(sum(r['import_operation'] == 'stage_draft' for r in results), 120)

    def test_normalization_collision_never_merges_stock(self):
        duplicate = copy.deepcopy(next(r for r in self.rows if r['fields']['SKU'] == 'DANM - 001'))
        duplicate['row'] = 700; duplicate['fields']['SKU'] = 'DANM-001'; duplicate['fingerprint'] = digest(duplicate['fields'])
        results, _ = plan(self.rows + [duplicate], self.contract)
        blocked = [r for r in results if r['blocking_import_errors']]
        self.assertEqual({r['original_sku'] for r in blocked}, {'DANM - 001', 'DANM-001'})
        self.assertEqual([r['source_stock_units'] for r in blocked], [1, 1])
        self.assertNotEqual(blocked[0]['variant_id'], blocked[1]['variant_id'])

    def test_collision_with_prior_identity_is_detected(self):
        incoming = copy.deepcopy(self.rows)
        row = next(r for r in incoming if r['fields']['SKU'] == 'MAC - 001')
        row['fields']['SKU'] = 'MAC-001'; row['fingerprint'] = digest(row['fields'])
        results, retained = plan(incoming, self.contract, self.baseline)
        self.assertEqual([r['original_sku'] for r in results if r['blocking_import_errors']], ['MAC-001'])
        self.assertEqual(retained, [{'original_sku': 'MAC - 001', 'operation': 'retain_existing_source_absent'}])

    def test_changed_price_is_proposal_with_stable_identity(self):
        incoming = copy.deepcopy(self.rows)
        incoming[0]['fields']['Target Price (PKR)'] = '4200'
        incoming[0]['fingerprint'] = digest(incoming[0]['fields'])
        results, _ = plan(incoming, self.contract, self.baseline)
        self.assertEqual(results[0]['product_id'], self.baseline[0]['product_id'])
        self.assertEqual(results[0]['import_operation'], 'stage_update')
        self.assertEqual(results[0]['evidence_status'], 'stale_requires_recheck')
        self.assertIsNone(results[0]['published_price_pkr'])
        self.assertEqual(results[0]['proposed_source_changes']['Target Price (PKR)']['previous'], '3999')
        self.assertEqual(sum(r['import_operation'] == 'unchanged' for r in results), 120)

    def test_missing_price_zero_stock_and_absent_rows_are_distinct(self):
        sb = next(r for r in self.baseline if r['original_sku'] == 'SB-001')
        self.assertIsNone(sb['proposed_price_pkr'])
        self.assertEqual(sb['import_operation'], 'stage_draft')
        incoming = copy.deepcopy(self.rows[:-1]); incoming[0]['fields']['Quantity'] = '0'
        incoming[0]['fingerprint'] = digest(incoming[0]['fields'])
        results, retained = plan(incoming, self.contract, self.baseline)
        self.assertEqual(results[0]['source_stock_units'], 0)
        self.assertNotIn('missing_or_invalid_stock', results[0]['unresolved_flags'])
        self.assertEqual(retained[0]['original_sku'], 'AROM-001')

    def test_invalid_numeric_and_formula_stock_are_not_applied(self):
        incoming = copy.deepcopy(self.rows)
        incoming[0]['fields']['Quantity'] = '-2'
        incoming[1]['fields']['Target Price (PKR)'] = 'NaN'
        incoming[2]['cells']['H']['formula'] = '1+1'
        results, _ = plan(incoming, self.contract)
        self.assertIsNone(results[0]['source_stock_units'])
        self.assertIsNone(results[1]['proposed_price_pkr'])
        self.assertEqual(results[2]['import_operation'], 'quarantine')
        self.assertIn('formula_in_stock', results[2]['blocking_import_errors'])

    def test_new_or_missing_sku_is_accounted_for(self):
        new = copy.deepcopy(self.rows[0]); new['fields']['SKU'] = 'NEW-001'; new['row'] = 700
        missing = copy.deepcopy(new); missing['fields']['SKU'] = None; missing['row'] = 701
        results, _ = plan(self.rows + [new, missing], self.contract)
        self.assertEqual(results[-2]['import_operation'], 'stage_draft')
        self.assertIn('new_sku_requires_mapping', results[-2]['unresolved_flags'])
        self.assertIsNone(results[-2]['proposed_category'])
        self.assertEqual(results[-1]['import_operation'], 'quarantine')

    def test_typed_facets_and_concerns_reject_wrong_scope(self):
        contract = copy.deepcopy(self.contract)
        contract['sku_reviews']['CUT-001']['filter_values'].append({'facet':'concentration','value':'eau-de-parfum','evidence':['workbook:Product Listings!A126']})
        contract['sku_reviews']['CUT-002']['concern_proposals'].append({'concern_id':'dryness','evidence':['axis-darkspot']})
        results, _ = plan(self.rows, contract)
        self.assertEqual({r['original_sku'] for r in results if r['blocking_import_errors']}, {'CUT-001','CUT-002'})

    def test_no_automatic_family_merge_or_invented_scent(self):
        self.assertTrue(all(r['confirmed_family_id'] is None for r in self.baseline))
        self.assertEqual(len(self.contract['concerns']), 8)
        self.assertTrue(all(not c['production_active'] for c in self.contract['concerns']))
        for r in self.baseline:
            if r['original_sku'] in ['VS-002','TB-001','DKNY-001','AROM-001']:
                self.assertFalse(any(f['facet'] in ['fragrance-note','fragrance-family','concentration','marketed-audience'] for f in r['filter_values']))

    def test_byte_repeatability_and_source_immutability(self):
        before = self.source.read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            one, two = Path(directory)/'one', Path(directory)/'two'
            run(self.source, self.contract_path, one)
            run(self.source, self.contract_path, two)
            for file in one.iterdir():
                self.assertEqual(file.read_bytes(), (two/file.name).read_bytes())
        self.assertEqual(before, self.source.read_bytes())

    def test_public_output_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Private catalog'):
            run(self.source, self.contract_path, ROOT / 'public/catalog-private')


if __name__ == '__main__':
    unittest.main()
