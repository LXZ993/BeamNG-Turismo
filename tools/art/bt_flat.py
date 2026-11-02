"""Beam Turismo, Runde 4: schlichtes Zeichen aus wenigen flachen Formen.
B = schräger Stamm-Block + ein geschwungener Doppelbogen (wie eine "3"), der spitz ausläuft.
T = roter Block aus Querbalken und Stamm. Keine Verläufe, keine Effekte."""
import math


def sk(pts, ox, oy, s, slant=16, base=200):
    k = math.tan(math.radians(slant))
    return [(ox + (x + (base - y) * k) * s, oy + y * s) for x, y in pts]


def d_of(pts):
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def lobe(x0, cy, ry, rx, t, n=60, reach=0.0):
    """Sichel: außen Halbellipse (rx, ry), innen (rx-t, ry-0.3t); Spitzen bei x0.
    reach > 0 zieht die äußere Spitze oben bzw. unten weiter nach links (Schwung über den Stamm)."""
    out, inn = [], []
    for i in range(n + 1):
        a = -math.pi / 2 + math.pi * i / n
        out.append((x0 + rx * math.cos(a), cy + ry * math.sin(a)))
    for i in range(n, -1, -1):
        a = -math.pi / 2 + math.pi * i / n
        inn.append((x0 + (rx - t) * math.cos(a), cy + (ry - t * 0.3) * math.sin(a)))
    return out + inn


def shapes(kind="a"):
    """Gibt (B-Polygone, T-Polygone) in Einheiten (Höhe 200) zurück."""
    stem = [(0, 0), (34, 0), (34, 200), (0, 200)]
    if kind == "a":      # Doppelbogen, Stamm voll
        B = [stem, lobe(46, 50, 50, 96, 46), lobe(46, 150, 50, 116, 50)]
    elif kind == "b":    # oberer Bogen greift über den Stamm (Schwung wie ein Dach)
        top = lobe(46, 50, 50, 96, 46)
        cap = [(-6, 0), (60, 0), (60, 22), (-12, 22)]
        B = [[(0, 30), (34, 30), (34, 200), (0, 200)], cap, top, lobe(46, 150, 50, 116, 50)]
    else:                # Stamm nur unten (wie der Innenblock beim G), Bögen tragen die Form
        B = [[(0, 104), (34, 104), (34, 200), (0, 200)], lobe(0, 50, 50, 142, 48), lobe(46, 150, 50, 116, 50)]
    T = [(176, 0), (380, 0), (366, 52), (300, 52), (300, 200), (246, 200), (246, 52), (162, 52)]
    return B, [T]
