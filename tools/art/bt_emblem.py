"""BT-Emblem für Beam Turismo: B und T als abstrakte, schräge Flächen mit waagerechten Schlitzen
(wie Fahrbahnmarkierungen). B dunkel/silbern, T rot. Alle Kurven als Bezier, Schräge eingerechnet."""
import math

K = 0.5523  # Bezier-Faktor für Viertelkreise


class Pen:
    def __init__(self, ox, oy, scale, slant):
        self.ox, self.oy, self.s, self.k = ox, oy, scale, math.tan(math.radians(slant))
        self.d = []

    def p(self, x, y):
        # Schräge um die Grundlinie y=200 (Emblem-Einheiten)
        X = self.ox + (x + (200 - y) * self.k) * self.s
        Y = self.oy + y * self.s
        return f"{X:.1f},{Y:.1f}"

    def M(self, x, y): self.d.append("M" + self.p(x, y))
    def L(self, x, y): self.d.append("L" + self.p(x, y))
    def C(self, x1, y1, x2, y2, x, y): self.d.append("C" + self.p(x1, y1) + " " + self.p(x2, y2) + " " + self.p(x, y))
    def Z(self): self.d.append("Z")

    def round_right(self, x0, y0, x1, y1, r):
        """Rechteck mit runder rechter Seite (Radius r) – Uhrzeigersinn."""
        self.M(x0, y0); self.L(x1 - r, y0)
        self.C(x1 - r + r * K, y0, x1, y1 - (y1 - y0) + r - r * K, x1, y0 + r)
        self.L(x1, y1 - r)
        self.C(x1, y1 - r + r * K, x1 - r + r * K, y1, x1 - r, y1)
        self.L(x0, y1); self.Z()

    def pill(self, x0, y0, x1, y1):
        r = (y1 - y0) / 2
        self.M(x0 + r, y0); self.L(x1 - r, y0)
        self.C(x1 - r + r * K, y0, x1, y0 + r - r * K, x1, y0 + r)
        self.C(x1, y0 + r + r * K, x1 - r + r * K, y1, x1 - r, y1)
        self.L(x0 + r, y1)
        self.C(x0 + r - r * K, y1, x0, y0 + r + r * K, x0, y0 + r)
        self.C(x0, y0 + r - r * K, x0 + r - r * K, y0, x0 + r, y0); self.Z()

    def poly(self, *pts):
        self.M(*pts[0])
        for q in pts[1:]: self.L(*q)
        self.Z()

    def get(self):
        d, self.d = " ".join(self.d), []
        return d


# Emblem-Einheiten: Höhe 200, Breite ~372 (ohne Schräge)
W_UNITS, H_UNITS = 372, 200


def emblem_paths(ox, oy, scale, slant=16, gap=14, form="schlitz"):
    """Gibt (b_pfad, t_pfad) zurück; Füllregel evenodd.
    form: 'schlitz' (B mit Langlöchern), 'platte' (B ohne Löcher, nur Schlitz), 'band' (Querbalken des T
    läuft als Dach über das B)."""
    g = gap / 2
    pn = Pen(ox, oy, scale, slant)
    if form == "band":
        # B unter dem Dach: obere Platte beginnt unter dem Balken
        pn.round_right(0, 54 + gap, 150, 120, 26)
        pn.round_right(0, 120 + gap, 172, 200, 40)
        pn.pill(42, 120 + gap + 26, 126, 200 - 26)
        b = pn.get()
        pn.poly((0, 0), (372, 0), (356, 54), (0, 54))
        pn.poly((246, 54 + gap), (318, 54 + gap), (302, 200), (240, 200))
        return b, pn.get()
    pn.round_right(0, 0, 150, 100 - g, 46)
    if form == "schlitz":
        pn.pill(42, 30, 104, 100 - g - 30)
    pn.round_right(0, 100 + g, 170, 200, 50)
    if form == "schlitz":
        pn.pill(42, 100 + g + 30, 122, 200 - 30)
    b = pn.get()
    # T: Querbalken (rechts schräg angeschnitten), Schlitz, keilförmiger Stamm
    pn.poly((186, 0), (372, 0), (356, 54), (186, 54))
    pn.poly((246, 54 + gap), (318, 54 + gap), (302, 200), (240, 200))
    t = pn.get()
    return b, t


def emblem_width(scale, slant=16):
    return (W_UNITS + H_UNITS * math.tan(math.radians(slant))) * scale
