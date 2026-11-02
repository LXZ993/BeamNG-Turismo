#!/usr/bin/env python3
"""Turismo Karriere: Stadtkarte für das World-Menü (Tag und Nacht), im Stil einer Weltkarte von schräg oben.

Aufruf: python3 tools/art/make_map.py OUTDIR
  OUTDIR/map_day.svg, map_night.svg (+ _steps.json für VectorCraft, + _preview.svg für den Browser)
tools/art/build.sh rendert sie mit VectorCraft nach mod/ui/modules/apps/TurismoHub/art/.

Die Orte (Marker) setzt die Oberfläche als HTML darüber. Ihre Plätze stehen in PLACES unten und müssen zu
MAP_PLACES in turismo-ui.js passen (Angaben in Prozent der Bildbreite/-höhe).
"""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(__file__))
from make_art import Doc, vc_steps, f, ell

W, H = 1920, 1080

# Plätze der Orte in Prozent (x, y) – gleich wie MAP_PLACES in turismo-ui.js
PLACES = {
    "cafe": (50, 50), "events": (70, 34), "licenses": (31, 30), "trainings": (19, 46),
    "dealers": (60, 72), "used": (78, 62), "legends": (88, 40), "garage": (38, 68),
    "workshop": (24, 76), "world2": (12, 24),
}

THEMES = {
    "day": dict(ground="#c9ced6", ground2="#bfc5cf", block="#dfe3e9", top="#f4f6f9", side="#a9b1bf", road="#ffffff", road_edge="#aab3c2",
                main="#ffffff", main_edge="#8f9bb0", water="#7fa7d6", water2="#9dbde2", park="#a9c79a", plaza="#ffffff", glow=None),
    "night": dict(ground="#05070c", ground2="#080b12", block="#0c1018", top="#141a26", side="#080b11", road="#141b28", road_edge="#0b0f18",
                  main="#1e2738", main_edge="#0a0e16", water="#050b16", water2="#0a1528", park="#0c1a14", plaza="#1b2a40", glow=("#ff9a3c", "#4fc3ff")),
}


def river_pts():
    # a lazy river from the left edge to the bottom right
    pts = []
    for i in range(0, 41):
        t = i / 40
        x = -60 + t * (W + 120)
        y = 1000 + math.sin(t * 3.1 + .6) * 50 - t * 30
        pts.append((x, y))
    return pts


def dist_to_poly(p, pts):
    best = 1e9
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy
        t = max(0, min(1, ((p[0] - ax) * dx + (p[1] - ay) * dy) / L)) if L else 0
        cx, cy = ax + t * dx, ay + t * dy
        best = min(best, math.hypot(p[0] - cx, p[1] - cy))
    return best


def path_of(pts):
    return "M" + " L".join(f"{f(x)} {f(y)}" for x, y in pts)


def build(doc, theme):
    T = THEMES[theme]
    rnd = random.Random(7)
    d = doc
    d.body.append(f'<rect width="{W}" height="{H}" fill="{d.lin([(0, T["ground2"], 1), (1, T["ground"], 1)])}"/>')
    river = river_pts()
    places = [(x * W / 100, y * H / 100) for x, y in PLACES.values()]

    # street grid (slightly rotated), blocks between streets
    ang = math.radians(-14)
    ca, sa = math.cos(ang), math.sin(ang)
    def rot(x, y):
        x, y = x - W / 2, y - H / 2
        return (W / 2 + x * ca - y * sa, H / 2 + x * sa + y * ca)
    bw, bh, gap = 132, 96, 14
    roads, buildings, parks = [], [], []
    for gx in range(-12, 13):
        for gy in range(-9, 10):
            x0, y0 = W / 2 + gx * bw, H / 2 + gy * bh
            corners = [rot(x0, y0), rot(x0 + bw - gap, y0), rot(x0 + bw - gap, y0 + bh - gap), rot(x0, y0 + bh - gap)]
            cx = sum(c[0] for c in corners) / 4
            cy = sum(c[1] for c in corners) / 4
            if cx < -200 or cx > W + 200 or cy < -200 or cy > H + 200:
                continue
            if dist_to_poly((cx, cy), river) < 95:
                continue
            if any(math.hypot(cx - px, cy - py) < 70 for px, py in places):
                continue  # keep the places free (plazas)
            if rnd.random() < .08:
                parks.append(corners)
                continue
            # 2-6 buildings per block
            n = rnd.choice((2, 3, 3, 4, 4, 6))
            cols = 2 if n in (2, 4, 6) else 3
            rows = max(1, n // cols)
            cw, ch = (bw - gap) / cols, (bh - gap) / rows
            for i in range(cols):
                for j in range(rows):
                    pad = 3
                    bx, by = x0 + i * cw + pad, y0 + j * ch + pad
                    h = rnd.choice((4, 6, 8, 10, 14, 18, 26)) * (1.6 if math.hypot(cx - W / 2, cy - H / 2) < 380 else 1)
                    quad = [rot(bx, by), rot(bx + cw - 2 * pad, by), rot(bx + cw - 2 * pad, by + ch - 2 * pad), rot(bx, by + ch - 2 * pad)]
                    buildings.append((quad, h))
    # streets: lines along the grid
    for gx in range(-12, 14):
        x = W / 2 + gx * bw - gap / 2
        roads.append((rot(x, -400), rot(x, H + 400)))
    for gy in range(-9, 11):
        y = H / 2 + gy * bh - gap / 2
        roads.append((rot(-600, y), rot(W + 600, y)))
    rd = "".join(f"M{f(a[0])} {f(a[1])}L{f(b[0])} {f(b[1])}" for a, b in roads)
    d.body.append(f'<path d="{rd}" stroke="{T["road"]}" stroke-width="{gap - 4}" fill="none" opacity=".9"/>')

    # parks
    for q in parks:
        d.body.append(f'<path d="M{" L".join(f"{f(x)} {f(y)}" for x, y in q)}Z" fill="{T["park"]}"/>')
        if theme == "day":
            for _ in range(6):
                tx = sum(p[0] for p in q) / 4 + rnd.uniform(-35, 35)
                ty = sum(p[1] for p in q) / 4 + rnd.uniform(-25, 25)
                d.body.append(f'<path d="{ell(tx, ty, 7, 7)}" fill="#86ad78"/>')

    # river
    rp = path_of(river)
    d.body.append(f'<path d="{rp}" stroke="{T["water2"]}" stroke-width="150" fill="none" stroke-linecap="round"/>')
    d.body.append(f'<path d="{rp}" stroke="{T["water"]}" stroke-width="120" fill="none" stroke-linecap="round"/>')
    # bridges over the river (two main roads)
    # buildings: extruded towards the viewer (south), drawn back to front
    buildings.sort(key=lambda b: sum(p[1] for p in b[0]))
    shade_parts, win = [], []
    for quad, h in buildings:
        (x1, y1), (x2, y2), (x3, y3), (x4, y4) = quad
        # south face: bottom edge (x4,y4)-(x3,y3) extruded down by h
        side = f"M{f(x4)} {f(y4 - h)}L{f(x3)} {f(y3 - h)}L{f(x3)} {f(y3)}L{f(x4)} {f(y4)}Z"
        top = f"M{f(x1)} {f(y1 - h)}L{f(x2)} {f(y2 - h)}L{f(x3)} {f(y3 - h)}L{f(x4)} {f(y4 - h)}Z"
        shade_parts.append((side, top, h))
    for side, top, h in shade_parts:
        d.body.append(f'<path d="{side}" fill="{T["side"]}"/><path d="{top}" fill="{T["top"]}"/>')
        if theme == "night":
            if h > 12 and rnd.random() < .5:
                d.body.append(f'<path d="{side}" fill="#ffcf7a" opacity="{rnd.choice((.06, .1, .16))}"/>')
            # lit windows as tiny dots on the roof edge
            (x1, y1), (x2, y2), (x3, y3), (x4, y4) = quad
            for _ in range(rnd.choice((0, 0, 1, 2, 3))):
                t = rnd.uniform(.15, .85)
                wx, wy = x4 + (x3 - x4) * t, y4 + (y3 - y4) * t - rnd.uniform(1, max(2, h - 2))
                win.append(f"M{f(wx)} {f(wy)}h2.4v2.4h-2.4Z")

    if win:
        d.body.append(f'<path d="{"".join(win)}" fill="#ffd690" opacity=".75"/>')

    # main roads (expressway ring + avenue), with light trails at night
    ring = "M-80 300 C400 180 760 120 1100 170 C1500 230 1780 380 2000 360"
    ave = "M300 1160 C520 860 760 700 980 560 C1200 420 1450 300 1700 -60"
    low = "M-80 900 C300 860 700 900 1000 840 C1350 770 1650 860 2000 820"
    for p in (ring, ave, low):
        d.body.append(f'<path d="{p}" stroke="{T["main_edge"]}" stroke-width="34" fill="none"/>')
        d.body.append(f'<path d="{p}" stroke="{T["main"]}" stroke-width="26" fill="none"/>')
        if T["glow"]:
            gid = d.uid("fxblur")
            d.fx.append((gid, "blur.gaussian", {"radius": 10}))
            flt = ' filter="url(#b10)"' if d.preview else ""
            if d.preview and 'id="b10"' not in "".join(d.defs):
                d.defs.append('<filter id="b10" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="6"/></filter>')
            d.body.append(f'<path id="{gid}" d="{p}" stroke="{T["glow"][0]}" stroke-width="18" fill="none" opacity=".35"{flt}/>')
            d.body.append(f'<path d="{p}" stroke="{T["glow"][0]}" stroke-width="2.5" fill="none" stroke-dasharray="3 9" opacity=".95"/>')
            d.body.append(f'<path d="{p}" stroke="#ffffff" stroke-width="2" fill="none" stroke-dasharray="2 14" stroke-dashoffset="6" opacity=".8"/>')
        else:
            d.body.append(f'<path d="{p}" stroke="#ffd34d" stroke-width="2" fill="none" stroke-dasharray="18 14" opacity=".8"/>')

    # plazas for the places
    for px, py in places:
        # the marker itself is HTML; the map only shows a soft light pool under it
        if T["glow"]:
            d.soft(ell(px, py + 4, 70, 40), T["glow"][1], 22, .28)
        else:
            d.soft(ell(px, py + 4, 64, 34), "#ffffff", 16, .55)

    # vignette
    d.body.append(f'<rect width="{W}" height="{H}" fill="{d.rad([(0, "#000", 0), (.7, "#000", 0), (1, "#000", .45 if theme == "night" else .18)], .5, .5, .75)}"/>')


def write(out, name, theme):
    for prev in (False, True):
        d = Doc(prev, W, H)
        build(d, theme)
        open(os.path.join(out, f"{name}{'_preview' if prev else ''}.svg"), "w", encoding="utf-8").write(d.svg())
        if not prev:
            import json
            json.dump(vc_steps(d), open(os.path.join(out, f"{name}_steps.json"), "w"), indent=0)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "out"
    os.makedirs(out, exist_ok=True)
    write(out, "map_day", "day")
    write(out, "map_night", "night")
    print("ok 2")
