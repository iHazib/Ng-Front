# Catalog review findings — 2026-10-05

Concern research is **partially complete**. Existing evidence-backed proposals are not a complete assignment across all SKUs. Optional concern assignments never block publication. Contract v1.1.0 separates category-specific essential publication requirements from optional enrichment and package review notes; the original SKU mapping remains the database import contract.

All 121 source SKU rows are represented in [the complete mapping](../data/catalog-dry-run/sku-mapping.json) and its [CSV review view](../data/catalog-dry-run/sku-mapping.csv). Original values are unchanged. No duplicate exact SKUs or normalization collisions were found in this source. All proposals remain drafts; no family is merged and no production filter value is active. Source quantities total 270 units, including factory-pack candidates counted as packs.

## Rechecked prior flags

| SKU / row | Verified workbook finding | Proposal and exact remaining evidence |
| --- | --- | --- |
| SB-001 / 59 | Unit cost, target, minimum and market prices are all blank; quantity 1 | Retain draft with no selling price. Owner must approve a PKR price; do not borrow another price. |
| DANM - 001 / 109; MAC - 001 / 122 | Both contain spaces around the hyphen; no current collision | Preserve exact identity. Offer DANM-001 / MAC-001 only as collision-checked aliases. Danessa shade is absent; confirm its label. MAC needs exact edition/palette contents. |
| DIOR-001…005 / 79…83 | All five say Cherry, but codes are 004, 020, 012, 030, 007; each says 6ml and stock 1 | Propose 004 Coral, 020 Mahogany, 012 Rosewood, 007 Raspberry as candidates. 030 remains unresolved. Obtain front/box/bottom shade label, barcode, batch, market/generation and Oil versus Balm/Maximizer identity for each SKU before correcting or grouping. |
| AROM-001 / 130 | Already Main Category Home / Subcategory Home Fragrance, not Perfume; brand absent | Retain Home Fragrance under the Fragrances menu. Obtain brand, outer barcode and each component's format, quantity, size and labels. No peony scent-note or diffuser/candle assumption. |
| VAS-001 / 116 | Skincare classification conflicts with Body Serum product type/title; size 360ml | Propose Bath & Body / body serum. Official regional products are body-directed, but retrieved Cranberry pack is 320ml. Confirm fruit variant, market, barcode, volume and directions before applying any claims. |
| SNG-002 / 5 | The RUSHOWER Dry Shampoo 200ml is under Skincare | Propose Beauty / Hair Care / Dry Shampoo. Exact 200ml Boots brand-range listing supports hair use. Confirm can/barcode/version and aerosol directions. No exact manufacturer-domain page was located. |
| CTP-001 / 40 | Rough & Bumpy Daily Smoothing Moisturizer 296ml, currently Skincare | Propose body moisturizer for review; do not approve face use. Official legacy urea, current 8 fl oz cream, and regional 296ml products must not be conflated with UK SA lotion. Need GTIN, country, ingredients/formula and body/face directions. |
| VS-001 / 53 | Victoria Secret Cloud Wash Foaming Gel Cleanser 130ml; no scent/variant | No exact official manufacturer match established. Bath & Body is tentative only. Need full title/scent, brand/barcode, directions and net quantity including ml versus g. Marketplace claims are not adopted. |
| OPI-001 / 47 | The Survival Kit, Skincare Set, no size/contents | No exact official manufacturer contents established. Hand & Nail Care is a pending review destination, not a confirmed reclassification. Need outer travel/edition code, all component labels, counts, sizes and use areas. |

Dior candidate spelling is supported by [the current official Oil page](https://www.dior.com/en_us/beauty/products/dior-addict-lip-glow-oil-E000001057.html) for Rosewood/Raspberry and [the regional official Oil search result](https://www.dior.com/pt_br/beauty/products/dior-addict-lip-glow-oil-C012400031.html) for Coral/Mahogany. The regional page could not be fetched in full; that limitation is recorded. The current shade range does not establish 030 or the generation of stock on hand. Lip Glow Balm shade lists are not used as Oil identity proof.

Body-scope evidence: [Vaseline body serums](https://www.vaseline.com/my/en/products/body-serum.html), [regional Cranberry pack](https://www.vaseline.com/my/en/p/vaseline-super-vitamin-serum-cranberry.html/08851932443210), [Cetaphil legacy product](https://www.cetaphil.com/us/roughandbumpy.html), [current Rough & Bumpy cream](https://www.cetaphil.com/us/moisturizers/exfoliating-rough-and-bumpy-cream/302990410341.html). Hair classification is supported by [the exact RUSHOWER 200ml brand-range listing](https://www.boots.com/soap-and-glory-the-rushower-dry-shampoo-200ml-10367172). These sources do not approve local stock, price or authenticity.

## Additional review flags

- PIX-004 `fluer` → proposed Fleur, supported by [Pixi's official blush listing](https://www.pixibeauty.com/collections/whats-new/products/on-the-glow-blush). Pixi/Ciaté/Tarte shade and Estée serum-size grouping remains a candidate until exact packs/formulas match. Same-name EST-004 and EST-005 pouches are kept separate; compare dimensions/material/model, not price or name alone.
- COTY-001 literally says 0.35g; CERA-008/009 say 14.2ml. Preserve them and verify package units. Do not convert an assumed ounce value or density. CERA-002 lacks SPF and exact tinted/untinted/face/body identity.
- MER-001, LOR-001, ELF-006, NYX-001, COTY-001, OFR-001 and DANM - 001 need shade/colour or translucent identity. SKII-001, PIX-003 and SNG-001 need full printed product-line names. Per-SKU package requirements also cover other missing sizes, kit contents, condition and expiry/PAO.
- ELF-002 is proposed as a lip oil **stick**, with Vine & Shine as a candidate shade, based on [e.l.f.'s official product](https://www.elfcosmetics.co.uk/glow-reviver-slipstick/83357.html) and official listing. Preserve source Lip Oil and 3.4g until package confirmation.
- UD-001's trio and DKNY-001's edition with bag are factory-pack candidates, not automatic assembled deals. VS-002/TB-001 list 7.5ml without confirmed component details; no multiplication into a total size, concentration, audience, note list or longevity is performed.
- CUT-001…004 and AROM-001 lack brands. Cutlery colours are finish proposals; manufacturer, material grade/coating, piece counts and care remain unknown. No automatic store branding.

## Concern evidence

All eight visual groups are defined, including Uneven Texture; none is active in production. Evidence-supported candidates are separated from approved membership:

| SKU | Candidate groups | Evidence boundary |
| --- | --- | --- |
| CERA-010 | Uneven Texture | [Exact CeraVe serum page](https://www.cerave.com/skincare/facial-serums/resurfacing-retinol-serum); post-acne marks remain separate from active acne |
| ORD-004 | Oiliness, Dullness, Uneven Texture, Dryness, Acne and Blemishes, Fine lines | [Exact Ordinary product and FAQ](https://theordinary.com/en-us/niacinamide-10-zinc-1-serum-100436.html); blemish-prone suitability only, no treatment claim or sensitive-skin inference |
| ORD-005 | Dark Spots | [Exact Alpha Arbutin product](https://theordinary.com/en-us/alpha-arbutin-2-ha-serum-100401.html); formula/package confirmation still needed |
| AXI-002 | Sensitive Skin | [Exact ampoule page](https://www.axis-y.com/collections/ampoule-serum/products/artichoke-intensive-skin-barrier-ampoule) separately positions sensitive skin; this is not inferred from barrier support |
| AXI-003 | Dark Spots, Dryness | [Exact serum's product benefits](https://www.axis-y.com/products/dark-spot-correcting-glow-serum); no active-acne claim |

Other source concern matches remain unapproved; ingredient presence and name matching are not evidence of suitability. Blank concern lists are valid. The complete evidence registry records retrieval status and scope, including official search excerpts and unsuccessful identity research, in `data/catalog-contract/review.json`. A product can later publish without optional concern assignments once its required fields are approved.
