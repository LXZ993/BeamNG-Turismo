"""Beam Turismo, Runde 3: BT aus geschwungenen Flächen.
B = zwei sichelförmige Bögen (wie zwei Kurven einer Schikane) an einem schrägen, spitz zulaufenden Stamm,
T = roter Pfeil-Balken mit schrägem Stamm. Punkte werden berechnet und als Polygon geschrieben
(fein genug für 2x-Export), Schräge eingerechnet."""
import math


def _sk(pts, ox, oy, s, slant, base=200):
    k = math.tan(math.radians(slant))
    return [(ox + (x + (base - y) * k) * s, oy + y * s) for x, y in pts]


def _d(pts):
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def crescent(x0, cy, ry, rx, t, tail=0.0, n=48):
    """Sichel nach rechts offen-links: äußere Halbellipse (rx, ry) minus innere (rx - t, ry),
    Spitzen oben/unten bei x0. tail zieht die obere Spitze nach links (Schwung)."""
    out, inn = [], []
    for i in range(n + 1):
        a = -math.pi / 2 + math.pi * i / n
        out.append((x0 + rx * math.cos(a), cy + ry * math.sin(a)))
    for i in range(n, -1, -1):
        a = -math.pi / 2 + math.pi * i / n
        inn.append((x0 + (rx - t) * math.cos(a), cy + (ry - t * 0.35) * math.sin(a)))
    pts = out + inn
    if tail:
        pts = [(x - tail * max(0.0, (cy - y) / ry) ** 3, y) for x, y in pts]
    return pts


def bt(ox, oy, s, slant=14, style="schwung"):
    """Gibt (b_pfade[], t_pfad) als SVG-d zurück. Einheiten: Höhe 200."""
    B = []
    # Stamm: schmaler, nach unten breiter werdender Keil
    stem = [(0, 0), (30, 0), (38, 200), (0, 200)]
    B.append(stem)
    # obere Sichel (kleiner), untere Sichel (größer, weiter nach rechts)
    B.append(crescent(30, 50, 50, 92, 40, tail=0))
    B.append(crescent(30, 148, 52, 116, 44, tail=0))
    if style == "schwung":
        # langer Unterstrich: Ideallinie läuft aus der unteren Sichel nach links hinaus
        B.append([(-60, 194), (60, 186), (60, 200), (-70, 200)])
    T = [(170, 0), (380, 0), (366, 46), (290, 46), (262, 200), (214, 200), (236, 46), (156, 46)]
    bd = [_d(_sk(p, ox, oy, s, slant)) for p in B]
    td = _d(_sk(T, ox, oy, s, slant))
    return bd, td


def _bez(p0, p1, p2, p3, n=24):
    out = []
    for i in range(1, n + 1):
        t = i / n; u = 1 - t
        out.append((u**3*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t**3*p3[0],
                    u**3*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t**3*p3[1]))
    return out


def track_b_centerline():
    """Mittellinie eines Rundkurses in B-Form: Start-Ziel-Gerade = Stamm, zwei Kurvenbögen, Schikane in der Mitte."""
    pts = [(14, 186), (14, 14)]
    pts += _bez((14, 14), (70, 14), (128, 18), (128, 56))
    pts += _bez((128, 56), (128, 88), (96, 98), (70, 100))
    pts += _bez((70, 100), (60, 101), (60, 106), (72, 107))      # Schikane
    pts += _bez((72, 107), (130, 110), (150, 128), (150, 150))
    pts += _bez((150, 150), (150, 178), (110, 186), (60, 186))
    return pts


def sickle_bt():
    """B nur aus zwei kräftigen Sicheln (kein Stamm, offen wie ein Zeichen), T als Klinge."""
    B = [crescent(18, 50, 50, 100, 52), crescent(4, 150, 50, 124, 56)]
    T = [(176, 0), (392, 0), (376, 50), (300, 50), (270, 200), (212, 200), (240, 50), (162, 50)]
    return B, T
