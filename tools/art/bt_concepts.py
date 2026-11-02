"""Beam Turismo, Runde 4: viele schlichte BT-Zeichen (flach, zwei Farben) als Auswahlblatt.
Einheiten: Höhe 200, Grundlinie y=200, Schräge wird beim Zeichnen eingerechnet."""
import math

SL = 14


def sk(pts, ox, oy, s, slant=SL):
    k = math.tan(math.radians(slant))
    return [(ox + (x + (200 - y) * k) * s, oy + y * s) for x, y in pts]


def d_of(pts):
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def arc(cx, cy, rxo, ryo, rxi, ryi, a0, a1, n=64, taper=0.0):
    """Ringstück zwischen zwei Ellipsen von Winkel a0 bis a1 (Grad, 0 = rechts, 90 = unten).
    taper: 0..1, das Ende bei a1 läuft spitz zu."""
    out, inn = [], []
    for i in range(n + 1):
        f = i / n
        a = math.radians(a0 + (a1 - a0) * f)
        tp = 1 - taper * max(0, (f - 0.6) / 0.4)
        ri_x = rxo - (rxo - rxi) * tp
        ri_y = ryo - (ryo - ryi) * tp
        out.append((cx + rxo * math.cos(a), cy + ryo * math.sin(a)))
        inn.append((cx + ri_x * math.cos(a), cy + ri_y * math.sin(a)))
    return out + inn[::-1]


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def T_plain(x=176):
    return [[(x, 0), (x + 200, 0), (x + 200, 54), (x + 128, 54), (x + 128, 200), (x + 72, 200), (x + 72, 54), (x, 54)]]


def lobes(x0=50, t=46, top_rx=92, bot_rx=110):
    return [arc(x0, 50, top_rx, 50, top_rx - t, 50 - t * 0.55, -90, 90, ),
            arc(x0, 150, bot_rx, 50, bot_rx - t, 50 - t * 0.55, -90, 90)]


def c1():   # kräftiges B aus Stamm + zwei Bögen, schlichtes T
    return [rect(0, 0, 50, 200)] + lobes(), T_plain(186)


def c2():   # B: ein großer Bogen + Mittelsteg (wie der Innenblock beim G)
    big = arc(50, 100, 118, 100, 70, 58, -90, 90)
    return [rect(0, 0, 50, 200), rect(50, 88, 120, 124)], T_plain(196)


def c3():   # unterer Bogen des B läuft weit unter das T und spitz aus
    top = arc(50, 50, 92, 50, 46, 26, -90, 90)
    bot = arc(50, 150, 110, 50, 64, 26, -90, 90)
    tail = arc(150, 70, 230, 130, 230 - 30, 130 - 34, 50, 125, taper=1.0)
    return [rect(0, 0, 50, 200), top, bot], T_plain(190)


def c4():   # Querbalken des T läuft nach links und bildet das Dach des B
    bar = [(0, 0), (380, 0), (380, 50), (0, 50)]
    stemT = rect(270, 50, 326, 200)
    B = [rect(0, 64, 46, 200), arc(46, 107, 84, 43, 44, 22, -90, 90), arc(46, 162, 102, 38, 60, 16, -90, 90)]
    return B, [bar, stemT]


def c5():   # ganz reduziert: zwei schräge Rundplatten = B, Block-T
    B = [[(0, 0), (60, 0)] + arc(60, 47, 70, 47, 0, 0, -90, 90, n=40)[:41] + [(0, 94)],
         [(0, 106), (70, 106)] + arc(70, 153, 74, 47, 0, 0, -90, 90, n=40)[:41] + [(0, 200)]]
    return B, T_plain(170)


def c6():   # B offen wie das G: zwei dicke Bögen ohne Stamm, Stamm nur als kurzer Block unten
    top = arc(40, 52, 110, 52, 62, 22, -150, 90)
    bot = arc(40, 150, 120, 50, 72, 22, -90, 120, taper=0.0)
    return [top, bot, rect(0, 108, 46, 168)], T_plain(196)


def c7():   # T als Stufen-Klinge (Balken links höher), B kräftig
    T = [[(178, 0), (376, 0), (376, 52), (310, 52), (296, 200), (240, 200), (252, 70), (178, 70)]]
    return [rect(0, 0, 50, 200)] + lobes(), T


def c8():   # Rahmen: T-Balken als Dach über beide Buchstaben, Bogen unten als Boden
    bar = [(0, 0), (380, 0), (380, 46), (0, 46)]
    stemT = rect(270, 46, 324, 160)
    floor = arc(150, 40, 230, 160, 230 - 0.01, 160 - 30, 40, 140, taper=0.0)
    B = [rect(0, 60, 44, 186), arc(44, 98, 80, 38, 42, 18, -90, 90), arc(44, 150, 96, 36, 56, 16, -90, 90)]
    return B, [bar, stemT]


CONCEPTS = {"1": c1, "2": c2, "3": c3, "4": c4, "5": c5, "6": c6, "7": c7, "8": c8}
