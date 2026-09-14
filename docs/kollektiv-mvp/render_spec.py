"""Render this package's limited Markdown syntax into a standalone reading copy."""
from pathlib import Path
import base64
import html
import re

ROOT = Path(__file__).resolve().parent
source = (ROOT / 'SPEC.md').read_text()
headings = []


def inline(value):
    value = html.escape(value)
    value = re.sub(r'`([^`]+)`', r'<code>\1</code>', value)
    value = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', value)
    value = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', value)
    return value


lines = source.splitlines()
blocks = []
i = 0
while i < len(lines):
    line = lines[i]
    if not line.strip():
        i += 1
        continue
    if line.startswith('```'):
        code = []
        i += 1
        while i < len(lines) and not lines[i].startswith('```'):
            code.append(lines[i])
            i += 1
        blocks.append('<pre><code>' + html.escape('\n'.join(code)) + '</code></pre>')
        i += 1
        continue
    image = re.fullmatch(r'!\[([^\]]*)\]\(([^)]+)\)', line)
    if image:
        alt, filename = image.groups()
        data = base64.b64encode((ROOT / filename).read_bytes()).decode()
        blocks.append(f'<figure><img src="data:image/png;base64,{data}" alt="{html.escape(alt)}"><figcaption>{html.escape(alt)}</figcaption></figure>')
        i += 1
        continue
    heading = re.match(r'^(#{1,3}) (.+)$', line)
    if heading:
        level = len(heading[1])
        label = heading[2]
        anchor = 'section-' + str(len(headings))
        headings.append((level, label, anchor))
        blocks.append(f'<h{level} id="{anchor}">{inline(label)}</h{level}>')
        i += 1
        continue
    if line.startswith('|'):
        rows = []
        while i < len(lines) and lines[i].startswith('|'):
            rows.append([cell.strip() for cell in lines[i].strip('|').split('|')])
            i += 1
        assert all(re.fullmatch(r':?-+:?', c) for c in rows[1]), 'Unsupported table'
        blocks.append('<div class="table-scroll"><table><thead><tr>' + ''.join('<th>' + inline(c) + '</th>' for c in rows[0]) + '</tr></thead><tbody>' + ''.join('<tr>' + ''.join('<td>' + inline(c) + '</td>' for c in row) + '</tr>' for row in rows[2:]) + '</tbody></table></div>')
        continue
    if re.match(r'^(- |\d+\. )', line):
        ordered = bool(re.match(r'^\d+\.', line))
        tag = 'ol' if ordered else 'ul'
        pattern = r'^\d+\. (.*)' if ordered else r'^- (.*)'
        items = []
        while i < len(lines):
            match = re.match(pattern, lines[i])
            if not match:
                break
            items.append('<li>' + inline(match[1]) + '</li>')
            i += 1
        blocks.append(f'<{tag}>' + ''.join(items) + f'</{tag}>')
        continue
    paragraph = [line]
    i += 1
    while i < len(lines) and lines[i].strip() and not re.match(r'^(#|\||!\[|```|- |\d+\. )', lines[i]):
        paragraph.append(lines[i])
        i += 1
    blocks.append('<p>' + inline(' '.join(paragraph)) + '</p>')

nav = ''.join(f'<a href="#{anchor}">{html.escape(label)}</a>' for level, label, anchor in headings if level == 2)
css = '''
:root{color-scheme:light;--ink:#07112f;--blue:#0755f5;--cream:#fffcf2;--yellow:#fff08a}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:32px}
body{margin:0;background:var(--cream);color:var(--ink);font:17px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
aside{position:fixed;inset:0 auto 0 0;width:270px;overflow:auto;background:var(--yellow);padding:32px 24px;border-right:1px solid #07112f18}
.brand{font-size:32px;font-weight:900;letter-spacing:-1px}.edition{font-size:12px;text-transform:uppercase;letter-spacing:1.5px;margin:8px 0 24px}
nav a{display:block;color:var(--ink);text-decoration:none;font-size:13px;line-height:1.4;padding:9px 0}nav a:hover{text-decoration:underline}
main{max-width:1240px;margin-left:270px;padding:48px 64px 100px}h1{font-size:48px;line-height:1.1;letter-spacing:-2px;margin:0 0 24px}h2{font-size:30px;line-height:1.25;letter-spacing:-.6px;margin:64px 0 20px;border-top:3px solid var(--blue);padding-top:22px}h3{font-size:21px;line-height:1.4;margin:32px 0 12px}p{margin:14px 0}li{padding:4px 0}a{color:var(--blue)}strong{font-weight:750}
.table-scroll{overflow:auto;margin:24px 0}table{border-collapse:collapse;width:100%;font-size:14px;line-height:1.5}th{text-align:left;background:var(--ink);color:white;padding:13px}td{padding:13px;vertical-align:top;border-bottom:1px solid #07112f22}tbody tr:nth-child(even){background:#fff7cd}th:first-child,td:first-child{min-width:110px}
figure{margin:28px 0}img{display:block;width:100%;height:auto;border:1px solid #07112f14;border-radius:16px}figcaption{font-size:12px;color:#555d73;margin-top:9px}code{font-size:.86em;background:#07112f09;padding:2px 5px;border-radius:4px}pre{overflow:auto;padding:22px;border-radius:12px;background:var(--ink);color:white;font-size:13px;line-height:1.7}pre code{padding:0;background:none}
@media(max-width:1000px){aside{position:relative;width:auto;padding:22px}nav{display:flex;gap:16px;overflow:auto}nav a{white-space:nowrap}main{margin:0;padding:32px 22px}h1{font-size:38px}.edition{margin-bottom:10px}}
@media print{aside{display:none}main{margin:0;padding:0;max-width:none}body{font-size:11px}h1{font-size:28px}h2{font-size:20px;break-after:avoid}h3{break-after:avoid}table{font-size:9px}figure{break-inside:avoid}a{color:inherit}img{max-height:680px;object-fit:contain}}
'''
document = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Kollektiv — MVP specification</title><style>' + css + '</style></head><body><aside><div class="brand">Kollektiv.</div><div class="edition">MVP specification · v1.0</div><nav>' + nav + '</nav></aside><main>' + '\n'.join(blocks) + '</main></body></html>'
(ROOT / 'SPEC.html').write_text(document)
print(f'Rendered {len(blocks)} blocks and {sum(x[0] == 2 for x in headings)} sections, with 6 embedded mockup boards.')
