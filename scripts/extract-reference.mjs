import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import postcss from 'postcss';
import selectorParser from 'postcss-selector-parser';

const html = readFileSync('design/reference/Nook_Glow_Homepage_Wireframe.html', 'utf8');
const blocks = [...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map((match) => match[1]);
if (blocks.length !== 14) throw new Error('Reference style block count changed; review before extracting.');
const root = postcss.parse(blocks.join('\n'), { from: 'approved-reference.html' });
let tokens = '';
root.walkRules((rule) => {
  if (rule.selector === ':root') {
    tokens += `.storefront{${rule.nodes.map((node) => node.toString()).join(';')}}\n`;
    rule.remove();
    return;
  }
  let parent = rule.parent;
  while (parent) {
    if (parent.type === 'atrule' && /keyframes$/i.test(parent.name)) return;
    parent = parent.parent;
  }
  rule.selector = selectorParser((selectors) => {
    selectors.each((selector) => {
      const first = selector.first;
      if (first.type === 'tag' && ['html', 'body'].includes(first.value)) {
        first.replaceWith(selectorParser.className({ value: 'storefront' }));
      } else {
        selector.prepend(selectorParser.combinator({ value: ' ' }));
        // :where adds no specificity; preserve the original cascade.
        selector.prepend(selectorParser.pseudo({ value: ':where', nodes: [
          selectorParser.selector({ nodes: [selectorParser.className({ value: 'storefront' })] }),
        ] }));
      }
    });
  }).processSync(rule.selector);
});
const comment = '/* Generated from all 14 final reference style blocks, in source order. Do not hand-edit. */\n';
tokens += '.storefront{--font-body:Arial,Helvetica,sans-serif;--font-display:Georgia,serif;--site-max-width:1800px;--edit-sage:#d7ded1;--edit-warm:#34291f;--edit-blush:#e5c9bf}\n';
const outputs = {
  'src/components/storefront/tokens.css': comment + tokens,
  'src/components/storefront/reference.css': comment + root.toString() + '\n',
};
mkdirSync('src/components/storefront', { recursive: true });
for (const [path, content] of Object.entries(outputs)) {
  if (process.argv.includes('--check')) {
    if (readFileSync(path, 'utf8') !== content) throw new Error(`Generated style drift: ${path}`);
  } else writeFileSync(path, content);
}
console.log('Reference CSS: 14 blocks, original cascade, scoped selectors and exact tokens verified.');
