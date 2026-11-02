#!/usr/bin/env python3
"""Turismo Karriere: hält im Handbuch die Abschnitte Changelog und Roadmap aktuell.

Aufruf (im Repo-Ordner):  python3 tools/handbuch_sync.py
- CHANGELOG.md -> zwischen <!-- CHANGELOG-START --> und <!-- CHANGELOG-ENDE -->:
  jede "## <Version>"-Überschrift wird ein eigener Spoiler (<details>), neueste oben.
- tools/roadmap.json -> zwischen <!-- ROADMAP-START --> und <!-- ROADMAP-ENDE -->: Meilenstein-Tabelle.
Die Ideen-Liste im Handbuch ist Handarbeit (steht direkt in docs/handbuch.html).
"""
import html
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def inline(text):
    t = html.escape(text, quote=False)
    t = re.sub(r'`([^`]+)`', r'<code>\1</code>', t)
    t = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', t)
    return t


def section_html(body):
    out, in_list = [], False
    for raw in body.splitlines():
        line = raw.strip()
        if line.startswith('- '):
            if not in_list:
                out.append('<ul>')
                in_list = True
            out.append('<li>' + inline(line[2:]) + '</li>')
            continue
        if in_list:
            out.append('</ul>')
            in_list = False
        if line.startswith('### '):
            out.append('<h4>' + inline(line[4:]) + '</h4>')
        elif line:
            out.append('<p>' + inline(line) + '</p>')
    if in_list:
        out.append('</ul>')
    return '\n'.join(out)


def changelog_html():
    md = (ROOT / 'CHANGELOG.md').read_text(encoding='utf-8')
    parts = re.split(r'(?m)^## ', md)[1:]
    blocks = []
    for part in parts:
        head, _, body = part.partition('\n')
        m = re.match(r'(.*?)\s*\((.*)\)\s*$', head.strip())
        ver, info = (m.group(1), m.group(2)) if m else (head.strip(), '')
        summary = '<b>' + inline(ver) + '</b>' + (' <small>' + inline(info) + '</small>' if info else '')
        blocks.append('<details class="cl">\n<summary>' + summary + '</summary>\n<div>\n' + section_html(body) + '\n</div>\n</details>')
    return blocks


def roadmap_html():
    data = json.loads((ROOT / 'tools' / 'roadmap.json').read_text(encoding='utf-8'))
    rows = ['<table>', '<tr><th>Version</th><th>Meilenstein</th><th>Stand</th></tr>']
    first_open = True
    for ms in data.get('meilensteine', []):
        if ms.get('fertig'):
            state = '<span style="color:var(--ok)">✓ fertig</span>'
        elif first_open:
            state = '<span style="color:var(--accent)">▶ als Nächstes</span>'
            first_open = False
        else:
            state = '<span style="color:var(--muted)">geplant</span>'
        rows.append('<tr><td><b>' + inline(ms.get('version', '')) + '</b></td><td>' + inline(ms.get('titel', '')) + '</td><td>' + state + '</td></tr>')
    rows.append('</table>')
    return rows


def replace_block(hb, name, lines):
    start, ende = '<!-- ' + name + '-START -->', '<!-- ' + name + '-ENDE -->'
    if start not in hb or ende not in hb:
        sys.exit(name + '-Marker fehlen in docs/handbuch.html')
    a, b = hb.index(start) + len(start), hb.index(ende)
    return hb[:a] + '\n' + '\n'.join(lines) + '\n' + hb[b:]


def version_check(cl_blocks):
    """Warnt, wenn Changelog, build.json und turismo_core.VERSION nicht dieselbe Version haben."""
    top = lambda name: (re.search(r'(?m)^## ([^ (]+)', (ROOT / name).read_text(encoding='utf-8')) or [None, None])[1]
    de, en = top('CHANGELOG.md'), top('CHANGELOG_EN.md')
    build = json.loads((ROOT / 'mod' / 'data' / 'turismo' / 'build.json').read_text(encoding='utf-8')).get('modVersion')
    core = re.search(r"M\.VERSION = '([^']+)'", (ROOT / 'mod' / 'lua' / 'ge' / 'extensions' / 'turismo' / 'core.lua').read_text(encoding='utf-8'))
    core = core and core.group(1)
    if len({de, en, build, core}) != 1:
        print(f'WARNUNG: Versionen passen nicht zusammen: CHANGELOG.md={de}, CHANGELOG_EN.md={en}, build.json={build}, core.lua={core}')
        return False
    return True


def main():
    hb_path = ROOT / 'docs' / 'handbuch.html'
    hb = hb_path.read_text(encoding='utf-8')
    cl = changelog_html()
    hb = replace_block(hb, 'CHANGELOG', cl)
    hb = replace_block(hb, 'ROADMAP', roadmap_html())
    hb_path.write_text(hb, encoding='utf-8')
    print(f'Handbuch aktualisiert: {len(cl)} Changelog-Versionen, Roadmap')
    if not version_check(cl):
        sys.exit(1)


if __name__ == '__main__':
    main()
