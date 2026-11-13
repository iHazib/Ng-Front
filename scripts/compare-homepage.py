"""Compare paired Playwright PNGs at identical viewport, motion and UI states."""
from pathlib import Path
from PIL import Image, ImageChops, ImageStat
import json

root = Path(__file__).resolve().parents[1]
results = []
for actual in sorted((root / 'test-results').rglob('react-*.png')):
    reference = actual.with_name(actual.name.replace('react-', 'reference-'))
    if not reference.exists():
        raise SystemExit(f'Missing comparison: {reference.name}')
    with Image.open(actual).convert('RGB') as a, Image.open(reference).convert('RGB') as b:
        same_size = a.size == b.size
        difference = ImageChops.difference(a, b) if same_size else None
        box = difference.getbbox() if same_size else (0, 0, *a.size)
        mean_error = sum(ImageStat.Stat(difference).mean) / 3 if same_size else 255
        results.append({'viewport': actual.parent.name.split('-')[-1], 'state': actual.stem.removeprefix('react-'),
                        'size': a.size, 'referenceSize': b.size, 'identicalPixels': same_size and box is None,
                        'meanAbsoluteChannelDifference': mean_error, 'differenceBounds': box})
report = root / 'docs/homepage-visual-checks.json'
report.write_text(json.dumps({'browser': 'Installed Microsoft Edge / Chromium', 'motion': 'reduced for deterministic comparison', 'comparisons': results}, indent=2) + '\n')
print(f'{len(results)} paired screenshots; {sum(item["identicalPixels"] for item in results)} pixel-identical.')
for item in results:
    if not item['identicalPixels']:
        print(item)
# Mobile header/hero now intentionally differ; the desktop reference suite has
# 23 pairs. Mobile layout and navigation have separate responsive browser checks.
if len(results) < 23 or any(item['meanAbsoluteChannelDifference'] > .15 for item in results):
    raise SystemExit('Visual comparison requires investigation.')
