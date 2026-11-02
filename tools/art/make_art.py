#!/usr/bin/env python3
"""Turismo Karriere: Grafiken für das Hub (Kachelbilder) und die Siegerehrung (Pokale).

Aufruf: python3 tools/art/make_art.py OUTDIR
  OUTDIR/<name>.svg + <name>_steps.json  (für VectorCraft)
  OUTDIR/<name>_preview.svg              (Browser-Vorschau, Effekte als SVG-Filter)
Rendern (VectorCraft, github.com/storytold/vectorcraft):
  vectorcraft-cli run --in X.svg --commands X_steps.json --export X.png --scale 2
tools/art/build.sh erledigt beides und kopiert die PNGs nach mod/ui/modules/apps/TurismoHub/art/.

Muster wie in Hashiriya Battle (tools/silhouette/vc): weiche Lichter/Schatten sind eigene, benannte
Pfade; vc_steps() macht daraus VectorCraft-Effekte (blur.gaussian, stylize.dropShadow).
"""
import json, math, os, sys

W, H = 320, 200


def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


class Doc:
    def __init__(self, preview, w=W, h=H):
        self.preview, self.w, self.h = preview, w, h
        self.defs, self.body, self.fx, self.n = [], [], [], 0

    def uid(self, p):
        self.n += 1
        return f"{p}{self.n:04d}"

    def lin(self, stops, x1=0, y1=0, x2=0, y2=1):
        i = self.uid("lg")
        st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.defs.append(f'<linearGradient id="{i}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
        return f"url(#{i})"

    def rad(self, stops, cx=.5, cy=.5, r=.5):
        i = self.uid("rg")
        st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.defs.append(f'<radialGradient id="{i}" cx="{cx}" cy="{cy}" r="{r}">{st}</radialGradient>')
        return f"url(#{i})"

    def clip(self, d):
        i = self.uid("cp")
        self.defs.append(f'<clipPath id="{i}"><path d="{d}"/></clipPath>')
        return f'clip-path="url(#{i})"'

    def soft(self, d, fill, blur, opacity=1.0):
        """Weicher Pfad (Glühen, Schatten): VectorCraft blur.gaussian."""
        name = self.uid("fxblur")
        self.fx.append((name, "blur.gaussian", {"radius": blur}))
        flt = ""
        if self.preview:
            fid = f"b{blur}"
            if f'id="{fid}"' not in "".join(self.defs):
                self.defs.append(f'<filter id="{fid}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{blur * .6}"/></filter>')
            flt = f' filter="url(#{fid})"'
        self.body.append(f'<path id="{name}" d="{d}" fill="{fill}" opacity="{opacity}"{flt}/>')

    def group(self, inner, shadow=None):
        """Gruppe, optional mit Schlagschatten (VectorCraft stylize.dropShadow)."""
        if not shadow:
            self.body.append(f"<g>{inner}</g>")
            return
        dx, dy, blur, op = shadow
        name = self.uid("fxds")
        self.fx.append((name, "stylize.dropShadow", {"opacity": op, "x": dx, "y": dy, "blur": blur}))
        flt = ""
        if self.preview:
            fid = self.uid("ds")
            self.defs.append(f'<filter id="{fid}" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="{dx}" dy="{dy}" stdDeviation="{blur * .5}" flood-opacity="{op / 100}"/></filter>')
            flt = f' filter="url(#{fid})"'
        self.body.append(f'<g id="{name}"{flt}>{inner}</g>')

    def svg(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" width="{self.w}" height="{self.h}">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.body)}</svg>')


def vc_steps(doc):
    steps = []
    for name, eff, params in doc.fx:
        steps.append({"command": "document.find", "params": {"name": name, "select": True}})
        steps.append({"command": "effect.apply", "params": {"effect": eff, "params": params}})
    return steps


# ---------------------------------------------------------------- shared materials
def metal(doc, top="#ffffff", mid="#c9d6ee", low="#6f7f9e"):
    return doc.lin([(0, top, 1), (.45, mid, 1), (1, low, 1)])


def glow(doc, cx, cy, rx, ry, col, op=.55, blur=18):
    doc.soft(ell(cx, cy, rx, ry), col, blur, op)


def ell(cx, cy, rx, ry):
    return f"M{f(cx - rx)} {f(cy)}A{f(rx)} {f(ry)} 0 1 0 {f(cx + rx)} {f(cy)}A{f(rx)} {f(ry)} 0 1 0 {f(cx - rx)} {f(cy)}Z"


def rrect(x, y, w, h, r):
    return (f"M{f(x + r)} {f(y)}H{f(x + w - r)}Q{f(x + w)} {f(y)} {f(x + w)} {f(y + r)}V{f(y + h - r)}Q{f(x + w)} {f(y + h)} {f(x + w - r)} {f(y + h)}"
            f"H{f(x + r)}Q{f(x)} {f(y + h)} {f(x)} {f(y + h - r)}V{f(y + r)}Q{f(x)} {f(y)} {f(x + r)} {f(y)}Z")


def star(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append(f"{f(cx + r * math.cos(a))} {f(cy + r * math.sin(a))}")
    return "M" + "L".join(pts) + "Z"


def floor_shadow(doc, cx, cy, rx, ry=7):
    doc.soft(ell(cx, cy, rx, ry), "#000", 6, .55)


# ---------------------------------------------------------------- car (side view coupe)
def car_paths(x=0, y=0, k=1.0, classic=False):
    def T(d):
        # simple affine on the absolute path coords we use below
        out, num, buf, isx = [], "", [], True
        import re
        toks = re.findall(r"[A-Za-z]|-?\d+(?:\.\d+)?", d)
        res, cmd, idx = [], None, 0
        for t in toks:
            if t.isalpha():
                cmd, idx = t, 0
                res.append(t)
                continue
            v = float(t)
            if cmd == "A":
                pos = idx % 7
                if pos in (0, 1):
                    v *= k
                elif pos == 5:
                    v = x + v * k
                elif pos == 6:
                    v = y + v * k
            else:
                v = x + v * k if idx % 2 == 0 else y + v * k
            res.append(f(v))
            idx += 1
        return " ".join(res)
    if classic:
        body = ("M30 142 C30 128 40 122 62 119 L104 114 C120 92 146 82 178 82 C206 82 224 94 238 112 L276 116 C292 118 298 128 298 142 "
                "L298 150 L262 150 A26 26 0 0 0 210 150 L118 150 A26 26 0 0 0 66 150 L30 150 Z")
        win = "M114 113 C128 96 148 89 176 89 C198 89 214 98 226 113 Z"
    else:
        body = ("M34 140 C34 126 44 119 66 116 L118 108 C140 90 166 80 202 80 C232 80 250 92 266 108 L286 112 C298 115 302 126 302 140 "
                "L302 150 L264 150 A27 27 0 0 0 210 150 L122 150 A27 27 0 0 0 68 150 L34 150 Z")
        win = "M128 108 C146 93 166 87 198 87 C218 87 234 95 248 108 Z"
    return T(body), T(win), (x + 95 * k, y + 150 * k), (x + 237 * k, y + 150 * k), 22 * k, T


def draw_car(doc, x=0, y=0, k=1.0, paint=("#7fe3ff", "#1f8fd6", "#0b3a66"), classic=False):
    body, win, w1, w2, r, T = car_paths(x, y, k, classic)
    floor_shadow(doc, x + 166 * k, y + 172 * k, 140 * k, 8 * k)
    paint_g = doc.lin([(0, paint[0], 1), (.5, paint[1], 1), (1, paint[2], 1)])
    glass = doc.lin([(0, "#e8f6ff", .95), (1, "#3c5a80", .95)])
    hi = T("M70 120 C120 112 200 104 290 118 L290 124 C200 112 120 118 70 128 Z")
    wheels = ""
    for (cx, cy) in (w1, w2):
        wheels += f'<path d="{ell(cx, cy, r, r)}" fill="#0c0f16"/><path d="{ell(cx, cy, r * .62, r * .62)}" fill="{metal(doc)}"/>'
        for a in range(0, 360, 72):
            ra = math.radians(a)
            wheels += f'<path d="M{f(cx)} {f(cy)}L{f(cx + r * .55 * math.cos(ra))} {f(cy + r * .55 * math.sin(ra))}" stroke="#56627a" stroke-width="{f(3 * k)}"/>'
        wheels += f'<path d="{ell(cx, cy, r * .14, r * .14)}" fill="#20283a"/>'
    lamp = T("M290 124 L300 126 L300 132 L289 131 Z")
    tail = T("M36 126 L46 124 L46 131 L36 133 Z")
    inner = (f'<path d="{body}" fill="{paint_g}"/><path d="{win}" fill="{glass}"/><path d="{hi}" fill="#ffffff" opacity=".35"/>'
             f'<path d="{lamp}" fill="#fff7c2"/><path d="{tail}" fill="#ff4a5a"/>' + wheels)
    doc.group(inner, shadow=(0, 4, 6, 45))


# ---------------------------------------------------------------- subjects
def art_cafe(doc):
    glow(doc, 210, 110, 90, 60, "#ffb066", .45, 22)
    floor_shadow(doc, 205, 168, 95)
    saucer = ell(205, 160, 92, 14)
    cup = "M140 86 L270 86 C268 130 248 158 205 158 C162 158 142 130 140 86 Z"
    handle = "M266 98 C300 96 302 136 258 138 L260 128 C288 126 286 106 264 108 Z"
    coffee = ell(205, 88, 65, 10)
    inner = (f'<path d="{saucer}" fill="{metal(doc, "#ffffff", "#e9dccb", "#a48b70")}"/>'
             f'<path d="{handle}" fill="{metal(doc, "#ffffff", "#efe3d3", "#b09676")}"/>'
             f'<path d="{cup}" fill="{doc.lin([(0, "#ffffff", 1), (.6, "#f1e6d8", 1), (1, "#b89c7c", 1)], 0, 0, 1, 0)}"/>'
             f'<path d="{coffee}" fill="#4a2a14"/><path d="{ell(195, 86, 30, 4)}" fill="#8a5a33" opacity=".7"/>'
             f'<path d="M150 104 C160 136 180 150 200 152" stroke="#fff" stroke-width="5" fill="none" opacity=".5"/>')
    doc.group(inner, shadow=(0, 5, 8, 40))
    for i, x in enumerate((180, 206, 232)):
        d = f"M{x} 74 C{x - 14} 58 {x + 14} 46 {x} 30 C{x - 10} 18 {x + 6} 10 {x + 2} 2"
        doc.body.append(f'<path d="{d}" stroke="#ffffff" stroke-width="7" fill="none" stroke-linecap="round" opacity=".18"/>')
        doc.body.append(f'<path d="{d}" stroke="#fff3e0" stroke-width="3" fill="none" stroke-linecap="round" opacity=".55"/>')


def art_race(doc):
    glow(doc, 200, 90, 110, 70, "#5aa8ff", .45, 22)
    # curving track ribbon
    doc.body.append('<path d="M20 200 C80 150 150 170 220 140 C270 118 300 120 320 110 L320 140 C300 148 280 146 236 166 C170 196 110 186 70 200 Z" fill="#0d1630" opacity=".9"/>')
    doc.body.append('<path d="M45 200 C100 162 160 180 228 152 C274 132 300 130 320 125" stroke="#ffffff" stroke-width="3" stroke-dasharray="14 12" fill="none" opacity=".7"/>')
    # flag on pole
    wave = "M150 30 C180 18 210 42 240 30 C262 22 280 26 292 34 L292 104 C280 96 262 92 240 100 C210 112 180 88 150 100 Z"
    cp = doc.clip(wave)
    sq = ""
    for r in range(8):
        for c in range(9):
            if (r + c) % 2 == 0:
                sq += f'<rect x="{150 + c * 16}" y="{14 + r * 14}" width="16" height="14" fill="#0b0f18"/>'
    shade = doc.lin([(0, "#000", .0), (.5, "#000", .25), (1, "#000", 0)], 0, 0, 1, 0)
    inner = (f'<path d="M144 24 L150 24 L150 176 L144 176 Z" fill="{metal(doc)}"/><path d="{ell(147, 22, 6, 6)}" fill="#ffd34d"/>'
             f'<g {cp}><path d="{wave}" fill="#f4f7ff"/>{sq}<path d="{wave}" fill="{shade}"/></g>')
    doc.group(inner, shadow=(0, 6, 8, 45))


def art_license(doc):
    glow(doc, 200, 100, 100, 60, "#4fe3c8", .4, 22)
    card = rrect(110, 40, 180, 116, 12)
    inner = (f'<path d="{card}" fill="{doc.lin([(0, "#f7fbff", 1), (1, "#bcd3e6", 1)], 0, 0, 1, 1)}"/>'
             f'<path d="{rrect(110, 40, 180, 26, 12)}" fill="#1a8f86"/><path d="M110 56 H290 V66 H110 Z" fill="#1a8f86"/>'
             f'<path d="{rrect(124, 78, 48, 58, 6)}" fill="#86a3bf"/><path d="{ell(148, 98, 12, 13)}" fill="#e8f0f8"/>'
             f'<path d="M128 136 C130 118 166 118 168 136 Z" fill="#e8f0f8"/>'
             + "".join(f'<path d="{rrect(184, y, w, 7, 3)}" fill="#5f7a94" opacity=".8"/>' for y, w in ((82, 90), (98, 70), (114, 84), (130, 54)))
             + f'<path d="{rrect(250, 116, 28, 24, 4)}" fill="{metal(doc, "#fff6c8", "#ffd34d", "#a07800")}"/>'
             f'<path d="M124 48 H200" stroke="#fff" stroke-width="5" opacity=".8"/>')
    doc.group(f'<g transform="rotate(-8 200 98)">{inner}</g>', shadow=(0, 8, 10, 45))


def cone(doc, x, y, s):
    body = f"M{f(x - 22 * s)} {f(y)} L{f(x - 5 * s)} {f(y - 78 * s)} L{f(x + 5 * s)} {f(y - 78 * s)} L{f(x + 22 * s)} {f(y)} Z"
    base = rrect(x - 32 * s, y - 2 * s, 64 * s, 10 * s, 3 * s)
    st1 = f"M{f(x - 15 * s)} {f(y - 26 * s)} L{f(x - 11 * s)} {f(y - 40 * s)} L{f(x + 11 * s)} {f(y - 40 * s)} L{f(x + 15 * s)} {f(y - 26 * s)} Z"
    st2 = f"M{f(x - 9 * s)} {f(y - 50 * s)} L{f(x - 7 * s)} {f(y - 60 * s)} L{f(x + 7 * s)} {f(y - 60 * s)} L{f(x + 9 * s)} {f(y - 50 * s)} Z"
    g = doc.lin([(0, "#ffb070", 1), (.5, "#ff6a1a", 1), (1, "#a83500", 1)], 0, 0, 1, 0)
    return f'<path d="{base}" fill="#2a2a30"/><path d="{body}" fill="{g}"/><path d="{st1}" fill="#f4f4f4"/><path d="{st2}" fill="#f4f4f4"/>'


def art_cones(doc):
    glow(doc, 200, 110, 100, 60, "#ffa040", .35, 22)
    doc.body.append('<path d="M60 200 L170 120 L176 120 L90 200 Z" fill="#ffffff" opacity=".18"/><path d="M230 200 L190 120 L196 120 L262 200 Z" fill="#ffffff" opacity=".18"/>')
    floor_shadow(doc, 200, 168, 110)
    doc.group(cone(doc, 140, 166, .9) + cone(doc, 262, 166, .9) + cone(doc, 200, 172, 1.15), shadow=(0, 4, 6, 45))


def art_car(doc):
    glow(doc, 180, 110, 130, 50, "#7b6cff", .45, 22)
    draw_car(doc, 0, 4, 1.0, ("#e9e6ff", "#7b6cff", "#2a1f6e"))


def art_used(doc):
    glow(doc, 180, 110, 130, 50, "#b56cff", .35, 22)
    draw_car(doc, 0, 10, .95, ("#ffe0b8", "#c98a45", "#5a3410"))
    tag = "M232 26 L292 26 L302 46 L292 66 L232 66 Z"
    inner = (f'<path d="M200 96 C214 70 226 52 236 46" stroke="#e8eefc" stroke-width="2" fill="none"/>'
             f'<path d="{tag}" fill="{doc.lin([(0, "#fff8d6", 1), (1, "#ffc35a", 1)])}"/><path d="{ell(240, 46, 4, 4)}" fill="#3a2a10"/>'
             f'<path d="M252 38 H286 M252 46 H280 M252 54 H284" stroke="#6a4a10" stroke-width="3" stroke-linecap="round"/>')
    doc.group(f'<g transform="rotate(10 266 46)">{inner}</g>', shadow=(0, 4, 5, 40))


def art_legend(doc):
    doc.soft(star(250, 60, 70, 30), "#ffd34d", 20, .45)
    doc.group(f'<path d="{star(250, 58, 36, 15)}" fill="{metal(doc, "#fff8d0", "#ffd34d", "#9a6a00")}"/>', shadow=(0, 3, 6, 40))
    glow(doc, 170, 130, 130, 40, "#ffd34d", .25, 20)
    draw_car(doc, 0, 18, .9, ("#ff9a9a", "#c4142c", "#4a0610"), classic=True)


def art_garage(doc):
    glow(doc, 200, 110, 100, 70, "#8aa4d6", .35, 22)
    floor_shadow(doc, 200, 176, 120)
    roof = "M90 70 L200 22 L310 70 L310 80 L200 34 L90 80 Z"
    wall = "M104 74 L200 32 L296 74 L296 176 L104 176 Z"
    door = rrect(130, 96, 140, 80, 4)
    slats = "".join(f'<path d="M130 {y} H270" stroke="#2c3850" stroke-width="2"/>' for y in range(108, 176, 12))
    light = "M150 96 L250 96 L290 176 L110 176 Z"
    inner = (f'<path d="{wall}" fill="{doc.lin([(0, "#cdd8ea", 1), (1, "#7d8aa3", 1)])}"/><path d="{roof}" fill="#e8eefc"/>'
             f'<path d="{door}" fill="{doc.lin([(0, "#9fb0cc", 1), (1, "#5d6c88", 1)])}"/>{slats}'
             f'<path d="{ell(200, 62, 10, 10)}" fill="#ffd34d"/>')
    doc.group(inner, shadow=(0, 6, 8, 45))
    doc.soft(light, "#fff3c0", 8, .12)


def art_wrench(doc):
    glow(doc, 200, 100, 100, 60, "#36d1ff", .35, 22)
    wrench = ("M0 -12 L120 -12 C126 -24 140 -32 156 -30 L142 -16 L146 -2 L160 2 L174 -12 C178 6 168 22 150 26 "
              "C140 28 130 24 124 18 L0 18 C-10 18 -16 10 -16 3 C-16 -4 -10 -12 0 -12 Z")
    inner = f'<g transform="translate(118 132) rotate(-30)"><path d="{wrench}" fill="{metal(doc)}"/><path d="M0 -6 H118" stroke="#fff" stroke-width="4" opacity=".7"/></g>'
    doc.group(inner, shadow=(0, 6, 8, 45))
    for (x, y, s) in ((268, 60, 1), (290, 96, .7), (252, 108, .55)):
        d = f"M{x} {y - 18 * s} C{x + 12 * s} {y - 2 * s} {x + 12 * s} {y + 10 * s} {x} {y + 10 * s} C{x - 12 * s} {y + 10 * s} {x - 12 * s} {y - 2 * s} {x} {y - 18 * s} Z"
        doc.group(f'<path d="{d}" fill="{doc.lin([(0, "#e8fbff", 1), (1, "#36a8ff", 1)])}"/>', shadow=(0, 2, 3, 30))


def art_ticket(doc):
    glow(doc, 200, 100, 100, 60, "#ff6ab0", .4, 22)
    t = ("M100 50 H300 V82 C288 82 288 104 300 104 V136 H100 V104 C112 104 112 82 100 82 Z")
    inner = (f'<path d="{t}" fill="{doc.lin([(0, "#fff0f6", 1), (1, "#ff8fc0", 1)], 0, 0, 1, 1)}"/>'
             f'<path d="M244 54 V132" stroke="#b03070" stroke-width="2" stroke-dasharray="5 5"/>'
             f'<path d="{star(172, 93, 28, 12)}" fill="{metal(doc, "#fff8d0", "#ffd34d", "#9a6a00")}"/>'
             f'<path d="M258 80 H286 M258 92 H280 M258 104 H286" stroke="#b03070" stroke-width="4" stroke-linecap="round"/>')
    doc.group(f'<g transform="rotate(-10 200 93)">{inner}</g>', shadow=(0, 6, 8, 45))


def art_map(doc):
    glow(doc, 200, 110, 100, 60, "#ff6a8a", .35, 22)
    panels = [("M100 60 L160 44 L160 160 L100 176 Z", "#e7f0e0"), ("M160 44 L230 62 L230 178 L160 160 Z", "#cfdcc6"), ("M230 62 L292 46 L292 162 L230 178 Z", "#e7f0e0")]
    inner = "".join(f'<path d="{d}" fill="{c}"/>' for d, c in panels)
    inner += '<path d="M118 150 C140 120 170 140 190 110 C210 82 250 120 270 80" stroke="#d6304a" stroke-width="4" stroke-dasharray="8 6" fill="none" stroke-linecap="round"/>'
    inner += '<path d="M106 96 C130 90 150 104 170 96 S220 84 250 100 S280 96 292 92" stroke="#7fb2e6" stroke-width="6" fill="none" opacity=".8"/>'
    doc.group(inner, shadow=(0, 6, 8, 40))
    pin = "M270 80 C252 80 246 60 246 54 C246 40 256 30 270 30 C284 30 294 40 294 54 C294 60 288 80 270 80 Z"
    doc.group(f'<path d="{pin}" fill="{doc.lin([(0, "#ff8a9a", 1), (1, "#b0102a", 1)])}"/><path d="{ell(270, 52, 8, 8)}" fill="#fff"/>', shadow=(0, 4, 4, 45))


def art_book(doc):
    glow(doc, 200, 110, 100, 60, "#8aa4d6", .35, 22)
    floor_shadow(doc, 200, 166, 100)
    left = "M200 64 C170 50 130 50 104 60 L104 158 C130 148 170 148 200 162 Z"
    right = "M200 64 C230 50 270 50 296 60 L296 158 C270 148 230 148 200 162 Z"
    lines = "".join(f'<path d="M{x0} {y} C{x0 + 20} {y - 6} {x0 + 50} {y - 6} {x0 + 70} {y}" stroke="#8090aa" stroke-width="3" fill="none" opacity=".7"/>'
                    for x0 in (118, 212) for y in (84, 100, 116, 132))
    inner = (f'<path d="M96 66 L200 170 L304 66 L304 166 L200 176 L96 166 Z" fill="#2a4a8a"/>'
             f'<path d="{left}" fill="{doc.lin([(0, "#ffffff", 1), (1, "#d7deea", 1)], 0, 0, 1, 0)}"/>'
             f'<path d="{right}" fill="{doc.lin([(0, "#d7deea", 1), (1, "#ffffff", 1)], 0, 0, 1, 0)}"/>{lines}')
    doc.group(inner, shadow=(0, 6, 8, 40))


def gear_path(cx, cy, r1, r2, teeth):
    pts = []
    for i in range(teeth * 4):
        a = math.radians(i * 360 / (teeth * 4))
        r = r1 if (i % 4) in (1, 2) else r2
        pts.append(f"{f(cx + r * math.cos(a))} {f(cy + r * math.sin(a))}")
    return "M" + "L".join(pts) + "Z"


def art_gear(doc):
    glow(doc, 210, 100, 100, 60, "#93a3c7", .35, 22)
    g1 = gear_path(200, 100, 62, 50, 12) + ell(200, 100, 20, 20)
    g2 = gear_path(282, 52, 36, 28, 9) + ell(282, 52, 11, 11)
    doc.group(f'<path d="{g2}" fill="{metal(doc, "#ffffff", "#9fb0cc", "#4d5c78")}" fill-rule="evenodd"/>'
              f'<path d="{g1}" fill="{metal(doc)}" fill-rule="evenodd"/>', shadow=(0, 6, 8, 45))


def art_diag(doc):
    glow(doc, 200, 100, 100, 60, "#4fe39a", .35, 22)
    floor_shadow(doc, 200, 172, 90)
    inner = (f'<path d="{rrect(104, 36, 192, 120, 10)}" fill="#2a3446"/><path d="{rrect(114, 46, 172, 100, 6)}" fill="#07140f"/>'
             + "".join(f'<path d="M114 {y} H286" stroke="#1d3a2c" stroke-width="1"/>' for y in range(56, 146, 12))
             + '<path d="M180 156 L220 156 L230 172 L170 172 Z" fill="#3a465c"/>')
    doc.group(inner, shadow=(0, 6, 8, 45))
    wave = "M118 110 L150 110 L160 76 L172 132 L184 96 L196 110 L230 110 L240 86 L250 122 L260 110 L284 110"
    doc.soft(wave + " L284 112 L118 112 Z", "#4fe39a", 6, .5)
    doc.body.append(f'<path d="{wave}" stroke="#7dffb8" stroke-width="3" fill="none" stroke-linejoin="round"/>')


def art_trophy(doc, tone):
    cols = {"gold": ("#fff6c2", "#ffd34d", "#8a6200"), "silver": ("#ffffff", "#cfd8e6", "#5d6878"), "bronze": ("#ffe0c2", "#d58a4a", "#5a2f0c")}[tone]
    glow(doc, 100, 92, 54, 62, cols[1], .4, 14)
    floor_shadow(doc, 100, 188, 60)
    g = doc.lin([(0, cols[0], 1), (.45, cols[1], 1), (1, cols[2], 1)], 0, 0, 1, 0)
    cup = "M52 28 L148 28 C148 86 128 112 100 116 C72 112 52 86 52 28 Z"
    handles = "M54 40 C22 40 22 86 66 92 L64 84 C36 78 36 50 56 50 Z M146 40 C178 40 178 86 134 92 L136 84 C164 78 164 50 144 50 Z"
    inner = (f'<path d="{handles}" fill="{g}"/><path d="{cup}" fill="{g}"/><path d="{ell(100, 28, 48, 7)}" fill="{cols[2]}"/>'
             f'<path d="M92 114 L108 114 L112 146 L88 146 Z" fill="{g}"/><path d="{rrect(70, 144, 60, 12, 3)}" fill="{g}"/>'
             f'<path d="{rrect(60, 156, 80, 28, 4)}" fill="#1a2238"/><path d="{rrect(78, 164, 44, 12, 2)}" fill="{g}"/>'
             f'<path d="M66 40 C68 70 78 92 92 104" stroke="#fff" stroke-width="6" fill="none" opacity=".45" stroke-linecap="round"/>'
             f'<path d="{star(100, 62, 18, 8)}" fill="#ffffff" opacity=".55"/>')
    doc.group(inner, shadow=(0, 6, 8, 45))


TILES = {
    "tile_cafe": art_cafe, "tile_race": art_race, "tile_lic": art_license, "tile_cone": art_cones,
    "tile_car": art_car, "tile_used": art_used, "tile_star": art_legend, "tile_garage": art_garage,
    "tile_wrench": art_wrench, "tile_ticket": art_ticket, "tile_map": art_map, "tile_guide": art_book,
    "tile_gear": art_gear, "tile_rec": art_diag,
}


def write(out, name, mk, w=W, h=H):
    for prev in (False, True):
        d = Doc(prev, w, h)
        mk(d)
        open(os.path.join(out, f"{name}{'_preview' if prev else ''}.svg"), "w", encoding="utf-8").write(d.svg())
        if not prev:
            json.dump(vc_steps(d), open(os.path.join(out, f"{name}_steps.json"), "w"), indent=0)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "out"
    os.makedirs(out, exist_ok=True)
    for name, fn in TILES.items():
        write(out, name, fn)
    for tone in ("gold", "silver", "bronze"):
        write(out, f"trophy_{tone}", lambda d, t=tone: art_trophy(d, t), 200, 200)
    print("ok", len(TILES) + 3)
