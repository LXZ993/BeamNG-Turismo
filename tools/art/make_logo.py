#!/usr/bin/env python3
"""Beam Turismo: Logo-Varianten und Hauptmenü-Icon.

Aufruf: python3 tools/art/make_logo.py OUTDIR
  OUTDIR/<name>.svg + <name>_steps.json  (für VectorCraft, siehe build.sh)
Schrift: Inter Display (SIL Open Font License 1.1, rsms.me/inter), als Pfade umgewandelt,
breiter gezogen und schräg gestellt. Im Mod steckt keine Schriftdatei, nur die Pfade.
Benötigt: pip install fonttools; Inter liegt unter /usr/share/fonts/opentype/inter/
(oder FONT_DIR=... setzen).
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bt_emblem import emblem_paths, emblem_width
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

FONT_DIR = os.environ.get("FONT_DIR", "/usr/share/fonts/opentype/inter")
RED, RED_D = "#D0021B", "#8E0012"
INK, SILVER = "#121417", "#C9CDD2"
_fonts = {}


def font(weight):
    if weight not in _fonts:
        _fonts[weight] = TTFont(os.path.join(FONT_DIR, f"InterDisplay-{weight}.otf"))
    return _fonts[weight]


def text_path(s, size, weight="ExtraBold", wide=1.22, slant=12, track=0.0, ox=0.0, oy=0.0):
    """Text als SVG-Pfad (Grundlinie y=0, links x=0). Gibt (d, breite) zurück."""
    f = font(weight)
    gs, cmap, upm = f.getGlyphSet(), f.getBestCmap(), f["head"].unitsPerEm
    k = size / upm
    sk = math.tan(math.radians(slant))
    pen = SVGPathPen(gs)
    x = 0.0
    for i, ch in enumerate(s):
        if ch == " ":
            x += gs[cmap[32]].width * k * wide * 0.8
            continue
        g = gs[cmap[ord(ch)]]
        # x' = wide*k*x + sk*k*y + x0 ; y' = -k*y  (Font-y zeigt nach oben)
        g.draw(TransformPen(pen, (wide * k, 0, sk * k, -k, ox + x, oy)))
        x += g.width * k * wide + track * size
    return pen.getCommands(), x - track * size


class Doc:
    def __init__(self, w, h, bg=None):
        self.w, self.h, self.bg = w, h, bg
        self.defs, self.body, self.fx, self.n = [], [], [], 0

    def uid(self, p):
        self.n += 1
        return f"{p}{self.n:03d}"

    def lin(self, stops, x1=0, y1=0, x2=0, y2=1):
        i = self.uid("lg")
        st = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
        self.defs.append(f'<linearGradient id="{i}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
        return f"url(#{i})"

    def path(self, d, fill, extra="", name=None):
        name = name or self.uid("p")
        self.body.append(f'<path id="{name}" d="{d}" fill="{fill}" {extra}/>')
        return name

    def text(self, s, x, y, size, fill, **kw):
        d, w = text_path(s, size, **kw)
        self.body.append(f'<g transform="translate({x:.1f} {y:.1f})"><path id="{self.uid("t")}" d="{d}" fill="{fill}"/></g>')
        return w

    def shadow(self, name, blur=6, dy=3, opacity=0.35):
        self.fx.append((name, "stylize.dropShadow", {"opacity": round(opacity * 100), "x": 0, "y": dy, "blur": blur}))

    def svg(self):
        bg = f'<rect width="{self.w}" height="{self.h}" fill="{self.bg}"/>' if self.bg else ""
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}">'
                f'<defs>{"".join(self.defs)}</defs>{bg}{"".join(self.body)}</svg>')

    def steps(self):
        out = []
        for name, eff, params in self.fx:
            out.append({"command": "document.find", "params": {"name": name, "select": True}})
            out.append({"command": "effect.apply", "params": {"effect": eff, "params": params}})
        return out


def para(x, y, w, h, sl, r=0):
    """Schräges Rechteck (Parallelogramm), Neigung sl Pixel über die Höhe."""
    return f"M{x+sl:.1f},{y:.1f}H{x+w+sl:.1f}L{x+w:.1f},{y+h:.1f}H{x:.1f}Z"


def swoosh(x0, x1, y, rise, thick):
    """Ideallinie: Kurve, die vorne dünn beginnt und hinten kräftig endet."""
    xm = (x0 + x1) / 2
    top = f"M{x0:.1f},{y:.1f} C{xm:.1f},{y+rise*0.15:.1f} {xm+ (x1-xm)*0.4:.1f},{y-rise:.1f} {x1:.1f},{y-rise*1.1:.1f}"
    bot = f"L{x1-thick*0.6:.1f},{y-rise*1.1+thick:.1f} C{xm+(x1-xm)*0.35:.1f},{y-rise+thick*1.1:.1f} {xm:.1f},{y+rise*0.15+thick*0.7:.1f} {x0+8:.1f},{y+1.2:.1f}Z"
    return top + bot


# ---------- Bausteine ----------

def monogram(d, x, y, s, fg="#fff", bar=RED):
    """BT-Plakette: schräge Plakette, darin 'BT', unten roter Streifen."""
    sl = s * 0.22
    d.path(para(x, y, s * 1.25, s, sl), d.lin([(0, "#2A2E34"), (1, INK)]), name=d.uid("badge"))
    d.shadow(d.body[-1].split('id="')[1].split('"')[0], blur=8, dy=4, opacity=0.4)
    d.path(para(x + s * .05, y + s * .05, s * 1.15, s * .9, sl * .9), "none", f'stroke="{SILVER}" stroke-width="{s*0.018:.2f}" opacity="0.55"')
    d.path(para(x + s * .02, y + s * .74, s * 1.21, s * .1, sl * .1), bar)
    d.text("BT", x + s * .2, y + s * .64, s * .55, fg, weight="Black", wide=1.15, slant=12, track=-0.02)


def wordmark_line(d, x, y, size, beam=RED, tur=INK):
    w1 = d.text("BEAM", x, y, size, beam, weight="Black", wide=1.25, slant=12, track=0.02)
    gap = size * 0.28
    w2 = d.text("TURISMO", x + w1 + gap, y, size, tur, weight="ExtraBold", wide=1.25, slant=12, track=0.02)
    return w1 + gap + w2


def variant_a(dark, bg=True):
    """A 'Plakette': BT-Plakette + Schriftzug in einer Zeile."""
    d = Doc(1200, 360, ("#0E0F12" if dark else "#F2F3F5") if bg else None)
    monogram(d, 60, 90, 180)
    fg = "#FFFFFF" if dark else INK
    w = wordmark_line(d, 365, 210, 80, RED, fg)
    d.text("KARRIERE FÜR BEAMNG.DRIVE", 369, 262, 22, SILVER if dark else "#6B7078", weight="SemiBold", wide=1.1, slant=12, track=0.28)
    return d


def variant_b(dark, bg=True):
    """B 'Ideallinie': gestapelter Schriftzug, rote Linie wie eine Kurve durch den Scheitelpunkt."""
    d = Doc(1200, 420, ("#0E0F12" if dark else "#F2F3F5") if bg else None)
    fg = "#FFFFFF" if dark else INK
    d.text("BEAM", 168, 150, 54, SILVER if dark else "#5A5F67", weight="Bold", wide=1.35, slant=12, track=0.55)
    d.text("TURISMO", 150, 290, 150, fg, weight="Black", wide=1.22, slant=12, track=0.01)
    n = d.path(swoosh(140, 1080, 335, 36, 13), d.lin([(0, RED_D), (0.6, RED), (1, "#FF2A3C")], 0, 0, 1, 0))
    d.shadow(n, blur=4, dy=2, opacity=0.3)
    return d


def roundel(d, cx, cy, r, mono=None):
    """C 'Rondell': Kreis mit drei schrägen Streifen (Flagge + Fahrbahn)."""
    i = d.uid("cp")
    d.defs.append(f'<clipPath id="{i}"><circle cx="{cx}" cy="{cy}" r="{r*0.86:.1f}"/></clipPath>')
    ring = mono or SILVER
    d.body.append(f'<circle id="{d.uid("ring")}" cx="{cx}" cy="{cy}" r="{r:.1f}" fill="{mono or INK}"/>')
    d.shadow(d.body[-1].split('id="')[1].split('"')[0], blur=8, dy=4, opacity=0.35)
    d.body.append(f'<circle cx="{cx}" cy="{cy}" r="{r*0.93:.1f}" fill="none" stroke="{ring if not mono else "#000"}" stroke-width="{r*0.025:.2f}" opacity="{0.6 if not mono else 0}"/>')
    g = []
    cols = (["#000", "#000", "#000"] if mono else [RED, "#FFFFFF", RED])
    for k, c in enumerate(cols):
        off = (k - 1) * r * 0.42
        x0, y0 = cx + off - r * 0.3, cy + r
        g.append(f'<path d="M{x0-r*0.25:.1f},{y0:.1f} L{x0+r*0.85:.1f},{cy-r:.1f} L{x0+r*1.13:.1f},{cy-r:.1f} L{x0+r*0.05:.1f},{y0:.1f}Z" fill="{c}"/>')
    d.body.append(f'<g clip-path="url(#{i})" {"opacity=\"0\"" if False else ""}>{"".join(g)}</g>')


def variant_c(dark, bg=True):
    d = Doc(1200, 420, ("#0E0F12" if dark else "#F2F3F5") if bg else None)
    roundel(d, 210, 210, 140)
    fg = "#FFFFFF" if dark else INK
    d.text("BEAM", 420, 175, 64, RED, weight="Black", wide=1.3, slant=12, track=0.3)
    d.text("TURISMO", 412, 290, 120, fg, weight="Black", wide=1.2, slant=12, track=0.01)
    return d


def icon(kind):
    """Hauptmenü-Icon: weiß auf transparent, quadratisch. Ohne Masken (Löcher per evenodd),
    damit VectorCraft und der Spiel-Browser es gleich darstellen."""
    d = Doc(256, 256)
    if kind == "a":
        sl = 34
        bt, w = text_path("BT", 100, weight="Black", wide=1.15, slant=12, track=-0.02, ox=46, oy=156)
        d.body.append(f'<path id="icon" fill="#FFFFFF" fill-rule="evenodd" d="{para(10, 52, 206, 150, sl)} '
                      f'{para(16, 170, 196, 13, 3)} {bt}"/>')
    elif kind == "b":
        dpath, w = text_path("T", 190, weight="Black", wide=1.2, slant=12)
        d.body.append(f'<g transform="translate({(256-w)/2-14:.0f} 170)"><path id="icon" d="{dpath}" fill="#FFFFFF"/></g>')
        d.path(swoosh(8, 250, 236, 26, 22), "#FFFFFF")
    else:
        d.defs.append('<clipPath id="ci"><circle cx="128" cy="128" r="96"/></clipPath>')
        d.body.append('<circle id="icon" cx="128" cy="128" r="112" fill="none" stroke="#FFFFFF" stroke-width="16"/>')
        st = "".join(f'<path d="M{x-40:.0f},256 L{x+70:.0f},0 L{x+104:.0f},0 L{x-6:.0f},256Z" fill="#FFFFFF"/>' for x in (48, 112, 176))
        d.body.append(f'<g clip-path="url(#ci)">{st}</g>')
    return d


def main(out):
    os.makedirs(out, exist_ok=True)
    items = {}
    for v, fn in (("a", variant_a), ("b", variant_b), ("c", variant_c)):
        for dark in (False, True):
            items[f"logo_{v}_{'dunkel' if dark else 'hell'}"] = fn(dark)          # Vorschau mit Hintergrund
            items[f"logo_{v}_auf_{'dunkel' if dark else 'hell'}"] = fn(dark, False)  # transparent, fürs Spiel
        items[f"icon_{v}"] = icon(v)
    for name, d in items.items():
        open(os.path.join(out, name + ".svg"), "w").write(d.svg())
        json.dump(d.steps(), open(os.path.join(out, name + "_steps.json"), "w"), indent=1)
    print(len(items), "Grafiken nach", out)


# ---------- Runde 2: BT-Emblem im Stil eines großen Spiele-Logos (Alex: "mehr wie GT, aber eigenständig") ----------
FORMS = {"d": "schlitz", "e": "platte", "f": "band"}


def emblem(d, cx, top, scale, form, dark, mono=None):
    w = emblem_width(scale)
    b, t = emblem_paths(cx - w / 2, top, scale, form=form)
    bfill = mono or (d.lin([(0, "#FFFFFF"), (1, "#AEB4BC")]) if dark else d.lin([(0, "#3A3F47"), (1, "#121417")]))
    nb = d.path(b, bfill, 'fill-rule="evenodd"')
    nt = d.path(t, mono or d.lin([(0, "#FF2338"), (1, "#B80018")]), 'fill-rule="evenodd"')
    if not mono:
        d.shadow(nb, blur=6, dy=4, opacity=0.25)
        d.shadow(nt, blur=6, dy=4, opacity=0.25)
    return w


def centered_text(d, s, cy, size, fill, **kw):
    dp, w = text_path(s, size, **kw)
    d.body.append(f'<g transform="translate({(d.w - w) / 2:.1f} {cy:.1f})"><path id="{d.uid("t")}" d="{dp}" fill="{fill}"/></g>')
    return w


def stacked(v, dark, bg=True):
    """Emblem oben, Schriftzug darunter, rote Ideallinie, Untertitel (Aufbau wie ein Spieltitel)."""
    d = Doc(1200, 760, ("#0E0F12" if dark else "#F2F3F5") if bg else None)
    emblem(d, 600, 70, 1.45, FORMS[v], dark)
    fg = "#FFFFFF" if dark else "#2A2E35"
    w = centered_text(d, "BEAM TURISMO", 520, 104, fg, weight="Black", wide=1.18, slant=14, track=0.0)
    x0 = (d.w - w) / 2
    n = d.path(swoosh(x0 - 10, x0 + w + 30, 572, 22, 11), d.lin([(0, RED_D), (0.6, RED), (1, "#FF2A3C")], 0, 0, 1, 0))
    centered_text(d, "KARRIERE FÜR BEAMNG.DRIVE", 640, 26, SILVER if dark else "#5A5F67", weight="Bold", wide=1.15, slant=14, track=0.32)
    return d


def wide(v, dark, bg=True):
    """Querformat für Menüleiste: Emblem links, Schriftzug rechts."""
    d = Doc(1400, 300, ("#0E0F12" if dark else "#F2F3F5") if bg else None)
    ew = emblem(d, 60 + emblem_width(0.95) / 2, 55, 0.95, FORMS[v], dark)
    fg = "#FFFFFF" if dark else "#2A2E35"
    x = 60 + ew + 40
    w = d.text("BEAM TURISMO", x, 190, 104, fg, weight="Black", wide=1.18, slant=14)
    d.path(swoosh(x - 6, x + w + 20, 236, 14, 9), d.lin([(0, RED_D), (0.6, RED), (1, "#FF2A3C")], 0, 0, 1, 0))
    d.w = int(x + w + 60)
    return d


def icon2(v):
    d = Doc(256, 256)
    s = 230 / emblem_width(1)
    b, t = emblem_paths((256 - emblem_width(s)) / 2, 128 - 100 * s, s, form=FORMS[v])
    d.path(b, "#FFFFFF", 'fill-rule="evenodd"', name="icon")
    d.path(t, RED, 'fill-rule="evenodd"')
    return d


def main2(out):
    os.makedirs(out, exist_ok=True)
    items = {}
    for v in FORMS:
        for dark in (False, True):
            t = "dunkel" if dark else "hell"
            items[f"logo_{v}_{t}"] = stacked(v, dark)
            items[f"logo_{v}_auf_{t}"] = stacked(v, dark, False)
            items[f"leiste_{v}_auf_{t}"] = wide(v, dark, False)
        items[f"icon_{v}"] = icon2(v)
    for name, d in items.items():
        open(os.path.join(out, name + ".svg"), "w").write(d.svg())
        json.dump(d.steps(), open(os.path.join(out, name + "_steps.json"), "w"), indent=1)
    print(len(items), "Grafiken nach", out)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "tools/art/out/logo"
    if len(sys.argv) > 2 and sys.argv[2] == "runde1":
        main(out)
    else:
        main2(out)
