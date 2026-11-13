"""Extract inert, approved sample markup; never execute handoff scripts.

Standard-library only. Original files remain immutable. Regenerate deliberately
when the approved reference changes, then review the fixture diff.
"""
from pathlib import Path
from html.parser import HTMLParser
import base64
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'design/reference/Nook_Glow_Homepage_Wireframe.html').read_text(encoding='utf-8')
manifest = json.loads((ROOT / 'design/reference/asset-manifest.json').read_text())
paths = {item['sha256']: item['path'] for item in manifest}
paths.update(json.loads((ROOT / 'tooling/reference-image-aliases.json').read_text()))
source = re.sub(r'data:image/[^;]+;base64,([A-Za-z0-9+/=]+)',
                lambda match: paths[hashlib.sha256(base64.b64decode(match[1])).hexdigest()], source)


class Markup(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = {'tag': 'root', 'attrs': {}, 'children': []}
        self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        node = {'tag': tag, 'attrs': {k: v if v is not None else '' for k, v in attrs}, 'children': []}
        self.stack[-1]['children'].append(node)
        if tag not in {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'}:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if self.stack[-1]['tag'] == tag:
            self.stack.pop()

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i]['tag'] == tag:
                del self.stack[i:]
                break

    def handle_data(self, text):
        self.stack[-1]['children'].append(text)


def find(node, tag):
    if isinstance(node, dict):
        if node['tag'] == tag:
            return node
        for child in node['children']:
            found = find(child, tag)
            if found:
                return found


parser = Markup()
parser.feed(source)
body = find(parser.root, 'body')
# Storefront and dialog shells only. User explicitly removed the handoff notes
# from the homepage; the immutable development reference retains them.
body['children'] = [n for n in body['children'] if not isinstance(n, dict) or
                    (n['tag'] not in {'script', 'style'} and
                     'notes' not in n['attrs'].get('class', '').split())]
catalog_text, rest = source.split('const catalog=', 1)[1].split(',blogs=', 1)
blog_text = rest.split(',drawer=document.', 1)[0]
catalog = json.loads(catalog_text)
blogs = json.loads(blog_text)
for blog in blogs:
    parser = Markup()
    parser.feed(blog.pop('body'))
    blog['body'] = parser.root['children']
result = {'kind': 'approved-sample', 'nodes': body['children'], 'catalog': catalog, 'articles': blogs}
target = ROOT / 'src/lib/catalog/approved-homepage.json'
target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Extracted approved sample DOM, four sample products and three sample articles.')
