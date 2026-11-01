#!/usr/bin/env python3
"""Synthesises all Turismo UI/race sound effects from scratch (no samples, no
third-party audio -> no licence questions). Writes WAV, converts to OGG via ffmpeg.

    python3 tools/gen_sfx.py
"""
import os, subprocess, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'mod', 'ui', 'modules', 'apps', 'TurismoHub', 'audio', 'sfx')
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.1, curve=4.0):
    """attack/exponential release envelope of n samples"""
    x = np.ones(n)
    na = max(1, int(a * SR))
    x[:na] = np.linspace(0, 1, na)
    rel = np.exp(-curve * np.linspace(0, 1, n - na))
    x[na:] *= rel
    if r:
        nr = min(n, int(r * SR))
        x[-nr:] *= np.linspace(1, 0, nr) ** 1.5
    return x


def tone(f, d, kind='sine', a=0.004, curve=5.0, vib=0.0, harmonics=None):
    tt = t(d)
    ph = 2 * np.pi * f * tt + (vib * np.sin(2 * np.pi * 5.5 * tt) if vib else 0)
    if kind == 'sine':
        y = np.sin(ph)
    elif kind == 'tri':
        y = 2 / np.pi * np.arcsin(np.sin(ph))
    elif kind == 'square':
        y = np.tanh(4 * np.sin(ph)) * 0.6
    elif kind == 'bell':
        y = np.sin(ph) + 0.5 * np.sin(2.76 * ph) * np.exp(-6 * tt) + 0.25 * np.sin(5.4 * ph) * np.exp(-10 * tt)
    elif kind == 'epiano':  # FM-ish electric piano
        mod = np.sin(2 * np.pi * f * tt) * 1.6 * np.exp(-5 * tt)
        y = np.sin(ph + mod) + 0.25 * np.sin(2 * ph)
    else:
        y = np.sin(ph)
    if harmonics:
        for k, amp in harmonics:
            y = y + amp * np.sin(k * ph)
    return y * env(len(tt), a=a, r=min(0.05, d / 3), curve=curve)


def noise(d, lp=None, hp=None, curve=6.0, a=0.002):
    y = rng.standard_normal(int(SR * d))
    if lp:
        y = onepole(y, lp)
    if hp:
        y = y - onepole(y, hp)
    return y * env(len(y), a=a, r=0.02, curve=curve)


def onepole(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def mix(*parts):
    """parts: (offset_seconds, signal, gain)"""
    n = max(int(o * SR) + len(s) for o, s, g in parts)
    out = np.zeros(n)
    for o, s, g in parts:
        i = int(o * SR)
        out[i:i + len(s)] += s * g
    return out


def chord(freqs, d, kind='epiano', spread=0.0, gain=1.0, curve=3.0):
    return mix(*[(i * spread, tone(f, d, kind, curve=curve), gain / len(freqs)) for i, f in enumerate(freqs)])


def reverb(x, wet=0.25, room=0.06):
    """cheap feedback-delay reverb"""
    out = np.concatenate([x, np.zeros(int(SR * 0.6))])
    for dl, g in ((room, 0.5), (room * 1.37, 0.4), (room * 1.83, 0.33), (room * 2.41, 0.25)):
        d = int(dl * SR)
        buf = np.zeros_like(out)
        for k in range(1, 6):
            if d * k < len(out):
                buf[d * k:] += out[:len(out) - d * k] * (g ** k)
        out = out + buf * wet / 2
    return out


def stereoize(x, width=0.0012):
    d = int(width * SR)
    l = x
    r = np.concatenate([np.zeros(d), x[:-d]]) if d else x
    return np.stack([l, r], axis=1)


def write(name, x, gain=0.8, stereo=True):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    # fade the tail to silence
    n = min(len(x), int(0.01 * SR))
    x[-n:] *= np.linspace(1, 0, n)
    data = stereoize(x) if stereo else x[:, None]
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + '.wav')
    with wave.open(wav, 'wb') as w:
        w.setnchannels(data.shape[1]); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(data, -1, 1) * 32767).astype('<i2').tobytes())
    ogg = os.path.join(OUT, name + '.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '5', ogg], check=True)
    os.remove(wav)
    print('  ', name)


def N(note):
    """note name like 'A4', 'C#5' -> Hz"""
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    base = names[note[0]]
    rest = note[1:]
    if rest.startswith('#'): base += 1; rest = rest[1:]
    elif rest.startswith('b'): base -= 1; rest = rest[1:]
    return 440.0 * 2 ** ((base + 12 * (int(rest) - 4)) / 12)


def main():
    print('Turismo SFX ->', os.path.abspath(OUT))
    # UI
    write('ui_hover', mix((0, tone(N('E6'), 0.05, 'sine', curve=9), 0.5), (0, noise(0.02, hp=4000), 0.05)), gain=0.35)
    write('ui_click', mix((0, tone(N('A5'), 0.07, 'tri', curve=8), 1), (0, noise(0.012, hp=3000), 0.3)), gain=0.6)
    write('ui_back', mix((0, tone(N('E5'), 0.06, 'tri', curve=8), 1), (0.045, tone(N('B4'), 0.09, 'tri', curve=7), 0.9)), gain=0.55)
    write('ui_open', reverb(mix((0, tone(N('C5'), 0.08, 'epiano'), 1), (0.05, tone(N('G5'), 0.12, 'epiano'), 0.8)), 0.2), gain=0.6)
    write('ui_confirm', reverb(mix((0, tone(N('D5'), 0.1, 'epiano'), 1), (0.07, tone(N('A5'), 0.1, 'epiano'), 1), (0.14, tone(N('D6'), 0.25, 'epiano', curve=3), 0.9)), 0.25), gain=0.65)
    write('ui_error', mix((0, tone(N('D3'), 0.14, 'square', curve=4), 1), (0.12, tone(N('C#3'), 0.2, 'square', curve=4), 1)), gain=0.5)
    # money / purchase: register-like bells + coin shimmer
    coins = mix(*[(0.03 * i, tone(f, 0.18, 'bell', curve=6), 0.6) for i, f in enumerate([N('E6'), N('G#6'), N('B6'), N('E7')])])
    write('ui_money', reverb(coins, 0.3), gain=0.6)
    write('ui_purchase', reverb(mix((0, chord([N('C4'), N('E4'), N('G4'), N('B4')], 0.9, 'epiano', spread=0.025, curve=2.2), 1), (0.12, coins, 0.6)), 0.35), gain=0.75)
    write('ui_levelup', reverb(mix(*[(0.09 * i, tone(N(n), 0.5, 'epiano', curve=3), 0.8) for i, n in enumerate(['C5', 'E5', 'G5', 'C6', 'E6'])],
                                   (0.45, chord([N('C4'), N('G4'), N('E5')], 1.2, 'epiano', curve=1.8), 0.9)), 0.4), gain=0.8)
    write('ui_ticket', reverb(mix(*[(0.05 * i, tone(N('C6') * 2 ** (i / 12), 0.08, 'bell', curve=7), 0.5) for i in range(0, 13, 2)],
                                  (0.4, chord([N('F5'), N('A5'), N('C6')], 0.8, 'bell', curve=2.5), 1)), 0.35), gain=0.7)
    # race
    write('race_count', tone(N('A4'), 0.35, 'sine', a=0.002, curve=2.5, harmonics=[(2, 0.3), (3, 0.12)]), gain=0.7)
    write('race_go', tone(N('A5'), 0.9, 'sine', a=0.002, curve=1.4, harmonics=[(2, 0.3), (3, 0.12)]), gain=0.8)
    sting = mix((0, chord([N('D3'), N('A3'), N('D4'), N('F#4')], 1.6, 'epiano', curve=1.6), 1),
                (0, noise(1.2, lp=900, curve=2.0), 0.25),
                (0.35, chord([N('E3'), N('B3'), N('E4'), N('G#4')], 1.8, 'epiano', curve=1.4), 1.0))
    write('race_intro_sting', reverb(sting, 0.35, 0.08), gain=0.8)
    write('race_finish', reverb(mix(*[(0.12 * i, chord([N(a), N(b)], 0.5, 'epiano', curve=2.5), 0.9) for i, (a, b) in enumerate([('G4', 'D5'), ('A4', 'E5'), ('B4', 'F#5')])],
                                    (0.42, chord([N('G3'), N('D4'), N('G4'), N('B4'), N('D5')], 2.0, 'epiano', curve=1.3), 1.1)), 0.4), gain=0.85)
    # tests
    write('test_gate', mix((0, tone(N('B5'), 0.09, 'sine', curve=7), 1), (0.03, tone(N('E6'), 0.12, 'sine', curve=6), 0.7)), gain=0.5)
    write('test_fail', reverb(mix((0, tone(N('E4'), 0.3, 'tri', curve=2), 1), (0.22, tone(N('C4'), 0.3, 'tri', curve=2), 1), (0.44, tone(N('A3'), 0.7, 'tri', curve=1.5), 1)), 0.25), gain=0.65)
    write('test_medal', reverb(mix((0, tone(N('C5'), 0.3, 'bell', curve=3), 1), (0.12, tone(N('G5'), 0.5, 'bell', curve=2.5), 1)), 0.35), gain=0.7)
    write('test_medal_gold', reverb(mix(*[(0.08 * i, tone(N(n), 0.7, 'bell', curve=2.2), 0.8) for i, n in enumerate(['C5', 'E5', 'G5', 'C6'])],
                                         (0.35, chord([N('C4'), N('G4'), N('C5'), N('E5')], 2.2, 'epiano', curve=1.2), 1.0),
                                         (0.35, noise(1.4, hp=6000, curve=3), 0.05)), 0.45), gain=0.85)
    # services
    wash = noise(1.6, lp=2500, hp=300, curve=0.8, a=0.15) * (0.6 + 0.4 * np.sin(2 * np.pi * 3 * t(1.6)))
    write('svc_wash', mix((0, wash, 1), (1.3, tone(N('E6'), 0.25, 'bell', curve=4), 0.4)), gain=0.55)
    clank = lambda f: mix((0, tone(f, 0.12, 'bell', curve=9), 1), (0, noise(0.03, hp=2000, curve=12), 0.5))
    write('svc_repair', reverb(mix((0, clank(1240), 1), (0.16, clank(1480), 0.9), (0.3, clank(1180), 0.9),
                                   (0.5, noise(0.35, lp=3000, hp=800, curve=1.5), 0.3), (0.95, tone(N('G5'), 0.3, 'epiano', curve=3), 0.6)), 0.25), gain=0.6)


if __name__ == '__main__':
    main()
