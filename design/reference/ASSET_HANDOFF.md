# Nook & Glow approved homepage handoff — v14

Extract this ZIP into the repository ROOT (the folder containing package.json). It contains design/, data/, public/assets/, and src/config/assets.ts without an enclosing directory.

The embedded imagery is extracted from the final approved wireframe, not an older Downloads copy. This package is authorized for faithful frontend implementation. Four hero slides are approved. Preserve their order and artwork. Keep the final header, brand-values strip, category coverflow, three-theme The Edit carousel, product galleries, concern carousel, brand carousel, story and premium footer. Contact email: nooktheglow@gmail.com.

assets.ts is a starting asset contract, not an existing app integration. Adapt imports and component types without redesigning the page. Browser image URLs start /assets/; filesystem paths start public/assets/. The manifest records dimensions, checksums and status. Generated editorials are sample content. Do not embed base64 in the production React components.

## What remains provisional
- Bath & Body category uses a reused skincare image in the approved wireframe. Preserve as explicitly labelled preview artwork for now; it does not represent a Bath & Body SKU. Do not invent a replacement or stop the entire frontend over this one asset.
- The four product-card samples are layout examples. Match their exact brand/name/variant to the supplied catalog before mapping to real SKUs, prices or stock. Only four product packshots are extracted here; other product images remain in the repo's existing public/products tree. Audit and map those by exact SKU; do not delete or blindly relabel them. Missing images get an explicit neutral placeholder, not unrelated photography.
- Product gallery alternate slides use the same packshot with different framing. There are no genuine secondary/detail product photos in this handoff.
- Brand images are the 12 logos actually embedded in the approved carousel. Additional catalog brands may need assets; publish links only for supported inventory.
- All eight concern images are present. Enable concern filters only for verified published product assignments; imagery alone is not evidence.
- Three editorial images are supplied: CeraVe cleanser, table setting and makeup model. Copy in the reference is sample content, not researched published advice or an endorsement.
- Instagram/Facebook URLs and approved policy text remain unset. Keep honest preview behaviour; do not invent handles or policy promises.
- Cart/checkout interactions are frontend previews. No backend orders, payment, stock reservation or courier calls are implemented here.

## Implementation sequence
1. Validate these paths and image bytes, compare the approved HTML, and wire src/config/assets.ts into the existing project.
2. Implement only the authorized frontend stage of Prompt 2. Preserve existing routes, working code and the agreed architecture. No wholesale repository replacement.
3. Use real catalog records where validated; keep pending mappings visible in the developer handoff, not in customer copy. Build responsive components with keyboard controls and reduced-motion support.
4. Run appropriate project checks and inspect desktop/mobile. Report completed work and genuinely missing SKU assets separately. Continue later prompts in order; do not implement Supabase/Cloudinary/admin/payment stages prematurely.
