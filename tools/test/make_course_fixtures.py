#!/usr/bin/env python3
"""Writes synthetic race files for every course used by licences/trainings into
tools/test/fixture_root (unit tests only, the real files come with BeamNG).
Closed courses are circles, open ones a wavy line. Node counts as on 0.40."""
import json, math, os
ROOT = os.path.join(os.path.dirname(__file__), 'fixture_root')
DATA = os.path.join(os.path.dirname(__file__), '..', '..', 'mod', 'data', 'turismo')
COUNTS = {'001-ardenteExperience': 28, 'drift/001-handling': 39, '001-forgotten': 16, '006-Outside': 13, '001-main1': 18,
          '008-Race': 11, '003-Handling': 10, '001-street': 13, '004-rally1': 19, 'hirochi_raceway/drift/001-Pro': 19,
          '005-quarryRace': 11, '001-alpineclimb': 11, '005-longcourse': 9, '003-shortcourse': 8, '004-mediumcourse': 8, '008-slalom': 16, '005-cornerspeed': 8,
          '003-tightroad': 7, '009-rwd': 9, '006-easycircuit': 6, '010-advanced': 5, '009-Short': 6, '007-Gravel': 8, '001-dirt1': 8}
CLOSED = ['006-easycircuit', '009-rwd', '010-advanced', 'timeTrial/00', 'aiRace/001-main1', 'italy/aiRace']
files = {}
for kind in ('licenses', 'trainings'):
    data = json.load(open(os.path.join(DATA, kind + '.json'), encoding='utf-8'))
    tests = [t for l in data for t in l['tests']] if kind == 'licenses' else data
    for t in tests:
        if t.get('type') == 'path':
            files[t['race']] = True
for f in files:
    n = 4
    for k, c in COUNTS.items():
        if k in f: n = c
    closed = any(k in f for k in CLOSED) and 'ardente' not in f and 'alpine' not in f
    nodes = []
    for i in range(n):
        if closed:
            a = 2 * math.pi * i / n
            pos = [300 * math.cos(a), 300 * math.sin(a), 10]
        else:
            pos = [i * 60.0, 15 * math.sin(i), 10]
        nodes.append({'oldId': i + 1, 'name': f'cp{i + 1}', 'pos': pos, 'radius': 6})
    segs = [{'from': i + 1, 'to': i + 2} for i in range(n - 1)]
    if closed: segs.append({'from': n, 'to': 1})
    starts = [{'oldId': 100, 'name': 'Start', 'pos': [300, -20, 10], 'rot': [0, 0, 0, 1]}] if closed else []
    out = {'name': 'Fixture', 'pathnodes': nodes, 'segments': segs, 'startNode': 1, 'startPositions': starts,
           'classification': {'closed': closed}, 'defaultStartPosition': 100 if closed else -1}
    p = os.path.join(ROOT, f.lstrip('/'))
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump(out, open(p, 'w'))
print(len(files), 'fixtures')
