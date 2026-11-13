# Homepage browser verification



## Full approved homepage — 2026-10-04



Compared the complete React page against the unchanged development reference at 1440 × 1000 desktop and 390 × 844 iPhone 13 emulation in installed Edge/Chromium on Windows. All measured section/header/footer geometry, font and background records match exactly. All rendered images decode. No hydration warnings or page/console errors occurred in the final comparison.



47 paired captures cover full pages, all four heroes, all five category states, all three Edit themes, all three article dialogs, all three first-product gallery crops, search reveal, sample bag and the five visible desktop menus. 44 pairs are pixel-identical after PNG decoding. The other three have tiny image-region pixel variations: desktop category 0 mean channel difference 0.004142/255, desktop full page 0.008097/255, and one mobile full-page pixel. These are recorded without claiming universal pixel perfection in `homepage-visual-checks.json`. Side-by-side visual inspection found no visible layout, text, colour or crop differences.



Deterministic captures use reduced motion and disable document smooth travel on both pages while moving between selected states. Mobile full-page captures use CSS-pixel resolution to avoid Edge’s large-raster capture limit; individual carousel captures retain device scale 3. Separate browser checks enable motion and exercise autoplay, pause, swipe and brand scrolling. Interaction checks cover menus, search matching/empty state, keyboard controls, article dialogs, bag add/quantity/remove/persistence, empty state, social preview and checkout with zero POST submissions. The mobile motion test was rerun successfully after explicitly resetting its category starting state following autoplay.



The original mobile layout—including its large cream hero area and hidden category navigation at <=1050px—is preserved. The visible handoff notes remain below the footer as part of this exact preview. These are reference behaviors, not new design decisions. Supplied galleries use alternate framing of the same photo; no genuine secondary angles are implied.



Limits: Chromium/Edge desktop and mobile emulation only; no physical iPhone, Safari/WebKit or Firefox verification. Not every intermediate breakpoint or every continuous-animation frame is exhaustively compared. No hosted/production deployment was performed.



Screenshots are in ignored `test-results/`; `scripts/compare-homepage.py` regenerates the tracked numeric evidence.



## Historical foundation verification



Checked on 2026-10-04 with Playwright 1.63.0 and installed Microsoft Edge 154.0.4258.53 (Chromium) on Windows.



Viewports: desktop 1440 × 1000 CSS pixels and iPhone 13 emulation at 390 × 844 CSS pixels, device scale 3, reduced motion enabled. These are browser emulations, not physical-device or Safari results.



The React foundation (`/`) and immutable approved HTML (`/reference`) run on the same development server. The browser suite checks:



- Rendered heading, noindex metadata/header and the development reference link.

- First hero successfully decoded at its expected intrinsic width.

- All reference image elements decode and use local `/assets/` URLs.

- Four hero slides and three editorial slides remain in the reference.

- Header, hero container and footer widths/heights, font families and background colours match between the two pages.

- No page JavaScript errors.

- The pure media resolver accepts local/public metadata and rejects traversal paths.



Screenshots are retained in ignored `test-results/` for both viewport projects. Visual inspection of the React foundation and reference confirms the original desktop image framing, header typography/logo, footer composition and mobile stacking. The reference has a large cream area below the mobile hero image; the scaffold retains that source behaviour.



This stage renders only the shared header/footer and first hero frame. Hero controls/autoplay, category navigation, search, shopping, other homepage sections and article interactions are intentionally deferred. The screenshot comparison is not a full-homepage fidelity claim. The browser suite does not assert a pixel-perfect image diff or cover every responsive breakpoint. Firefox, WebKit/Safari, physical devices and hosted environments have not been tested.



The browser test initially identified two alternate WebP logo encodings in the HTML. Pillow comparison confirmed exact dimensions and decoded RGBA pixel equality with the supplied PNGs; separate development-only aliases resolve all 55 image occurrences without altering any supplied source.

