"""Beam Turismo: das Zeichen. Gebaut wie klassische Spiele-Zeichen aus wenigen flachen Teilen:
B = geschwungener Doppelbogen (rechte Seite des B, oben und unten gerade abgeschnitten)
    + kurzer Stamm-Block links, mit Abstand (wie ein eingesetztes Teil),
T = ein rotes Teil aus Querbalken und Stamm.
Einheiten: Höhe 200; Schräge wird beim Ausgeben eingerechnet."""
import math

SL = 15


def bez(p0, p1, p2, p3, n=28):
    out = []
    for i in range(1, n + 1):
        t = i / n; u = 1 - t
        out.append((u**3*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t**3*p3[0],
                    u**3*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t**3*p3[1]))
    return out


def path(start, segs):
    pts = [start]; cur = start
    for s in segs:
        if len(s) == 1:
            pts.append(s[0]); cur = s[0]
        else:
            pts += bez(cur, *s); cur = s[2]
    return pts


def sk(pts, ox, oy, s, slant=SL):
    k = math.tan(math.radians(slant))
    return [(ox + (x + (200 - y) * k) * s, oy + y * s) for x, y in pts]


def d_of(pts):
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def mark(t_mode="normal"):
    # Doppelbogen: außen
    outer = path((56, 0), [
        [(108, 0)],
        [(150, 0), (176, 20), (176, 50)],
        [(176, 74), (160, 90), (138, 99)],
        [(166, 108), (188, 128), (188, 154)],
        [(188, 184), (158, 200), (112, 200)],
        [(56, 200)],
    ])
    # innen (zurück nach oben)
    inner = path((56, 200), [
        [(56, 154)],
        [(108, 154)],
        [(126, 154), (136, 150), (136, 140)],
        [(136, 130), (124, 122), (106, 122)],
        [(78, 122)],
        [(78, 78)],
        [(100, 78)],
        [(116, 78), (126, 70), (126, 60)],
        [(126, 50), (116, 44), (100, 44)],
        [(56, 44)],
    ])
    # Doppelbogen: außen + innen als eine Fläche (der Stamm fehlt absichtlich in der Mitte)
    bow = outer + inner[1:]
    stem = [(0, 0), (42, 0), (42, 200), (0, 200)]
    if t_mode == "normal":
        T = [(206, 0), (400, 0), (400, 50), (326, 50), (326, 200), (276, 200), (276, 50), (206, 50)]
    else:  # Balken läuft nach links über den Doppelbogen
        T = [(0, -62), (400, -62), (400, -12), (326, -12), (326, 200), (276, 200), (276, -12), (0, -12)]
    return [stem, bow], [T]


def mark_solid(t_mode="normal"):
    """Runde 6: B als ein geschlossenes Stück (Stamm + Bögen, zwei Innenräume), gleiche Strichstärke wie das T."""
    outer = path((0, 0), [
        [(108, 0)],
        [(152, 0), (178, 20), (178, 50)],
        [(178, 74), (162, 90), (140, 99)],
        [(168, 108), (190, 128), (190, 154)],
        [(190, 184), (160, 200), (112, 200)],
        [(0, 200)],
    ])
    # Innenräume gegen den Uhrzeigersinn (Gegenrichtung zur Außenkontur), damit sie als Löcher gelten
    up = path((50, 44), [
        [(50, 80)],
        [(100, 80)],
        [(118, 80), (128, 72), (128, 62)],
        [(128, 52), (118, 44), (100, 44)],
    ])
    low = path((50, 122), [
        [(50, 156)],
        [(108, 156)],
        [(128, 156), (138, 150), (138, 139)],
        [(138, 128), (126, 122), (106, 122)],
    ])
    _, T = mark(t_mode)
    return [[outer, up, low]], T


def d_multi(parts):
    return " ".join(d_of(p) for p in parts)


def _round(pts, r_conv=10, r_conc=16, min_turn=25, n=8):
    """Ecken eines geschlossenen Polygons abrunden (nur echte Knicke; Bezier-Stützpunkte bleiben)."""
    out = []
    m = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % m][1] - pts[(i + 1) % m][0] * pts[i][1] for i in range(m))
    for i in range(m):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % m]
        a = (p0[0] - p1[0], p0[1] - p1[1]); b = (p2[0] - p1[0], p2[1] - p1[1])
        la = math.hypot(*a); lb = math.hypot(*b)
        if la < 1e-6 or lb < 1e-6:
            continue
        cosang = max(-1, min(1, (a[0] * b[0] + a[1] * b[1]) / (la * lb)))
        turn = 180 - math.degrees(math.acos(cosang))
        if turn < min_turn:
            out.append(p1); continue
        cross = a[0] * b[1] - a[1] * b[0]
        convex = (cross < 0) == (area > 0)
        r = min(r_conv if convex else r_conc, la * 0.45, lb * 0.45)
        q0 = (p1[0] + a[0] / la * r, p1[1] + a[1] / la * r)
        q2 = (p1[0] + b[0] / lb * r, p1[1] + b[1] / lb * r)
        for k in range(n + 1):
            t = k / n; u = 1 - t
            out.append((u * u * q0[0] + 2 * u * t * p1[0] + t * t * q2[0], u * u * q0[1] + 2 * u * t * p1[1] + t * t * q2[1]))
    return out


def mark_soft(t_mode="normal"):
    """Runde 7: geschlossenes B, T in gleicher Breite/Stärke wie das B, alle Ecken gerundet."""
    (B,), _ = mark_solid(t_mode)
    outer, up, low = B
    outer = _round(outer, 12, 12)
    up = _round(up, 7, 7); low = _round(low, 7, 7)
    if t_mode == "normal":   # Balken so breit wie das B, Stamm mittig, Stärken wie beim B
        T = [(214, 0), (404, 0), (404, 46), (334, 46), (334, 200), (284, 200), (284, 46), (214, 46)]
    else:
        T = [(0, -60), (404, -60), (404, -14), (334, -14), (334, 200), (284, 200), (284, -14), (0, -14)]
    T = _round(T, 12, 18)
    return [[outer, up, low]], [T]
