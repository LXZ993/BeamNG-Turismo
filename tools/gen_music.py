#!/usr/bin/env python3
"""Turismo-Soundtrack: composes and renders original music procedurally.

Everything (melodies, chords, drums, sounds) is generated here, so the tracks
are our own work and free of third-party licences. Styles follow the classic
racing-game vibe: lounge/jazz-funk for menus, driving rock/electro for races.

    python3 tools/gen_music.py            # all tracks
    python3 tools/gen_music.py lounge     # one track
"""
import json, os, subprocess, sys, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'mod', 'ui', 'modules', 'apps', 'TurismoHub', 'audio', 'music')

NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}
QUAL = {'maj7': [0, 4, 7, 11], 'maj9': [0, 4, 7, 11, 14], 'm7': [0, 3, 7, 10], 'm9': [0, 3, 7, 10, 14], '7': [0, 4, 7, 10], '9': [0, 4, 7, 10, 14],
        '13': [0, 4, 10, 14, 21], 'm11': [0, 3, 10, 14, 17], '5': [0, 7, 12], 'maj': [0, 4, 7], 'm': [0, 3, 7], 'sus': [0, 5, 7, 10], '6': [0, 4, 7, 9], 'm6': [0, 3, 7, 9]}


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def parse_chord(s, octave=3):
    root = s[:2] if len(s) > 1 and s[1] in '#b' else s[:1]
    q = s[len(root):] or 'maj'
    base = 12 * (octave + 1) + NOTE[root]
    return base, [base + i for i in QUAL[q]]


# ------------------------------------------------------------------ instruments
def adsr(n, a, d, s, r):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    e = np.full(n, s, dtype=float)
    a = min(a, n); e[:a] = np.linspace(0, 1, a)
    d2 = min(d, max(0, n - a)); e[a:a + d2] = np.linspace(1, s, d2)
    r = min(r, n); e[n - r:] *= np.linspace(1, 0, r)
    return e


def epiano(f, dur, vel=0.8):
    n = int(dur * SR); t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * f * 1.0 * t) * (2.2 * vel) * np.exp(-t * 4)
    y = np.sin(2 * np.pi * f * t + mod) + 0.18 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 9)
    y *= np.exp(-t * (1.1 + f / 900)) * adsr(n, 0.003, 0.0, 1.0, min(0.08, dur * 0.4))
    return y * vel


def pad(f, dur, vel=0.5, bright=0.4):
    n = int(dur * SR); t = np.arange(n) / SR
    y = np.zeros(n)
    for det in (-0.12, 0.0, 0.11):
        ff = f * 2 ** (det / 12)
        for k in range(1, 7):
            y += np.sin(2 * np.pi * ff * k * t + k) * (bright ** (k - 1)) / k
    return y * adsr(n, min(0.6, dur / 3), 0.3, 0.8, min(0.8, dur / 3)) * vel / 3


def bass(f, dur, vel=0.9, kind='finger'):
    n = int(dur * SR); t = np.arange(n) / SR
    if kind == 'synth':  # saw-ish, few harmonics, filter env via harmonic decay
        y = sum(np.sin(2 * np.pi * f * k * t) / k * np.exp(-t * (2 + k * 1.5)) for k in range(1, 9))
        y += 0.6 * np.sin(2 * np.pi * f * t)
    else:  # finger bass
        y = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 6) + 0.12 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t * 10)
    return y * adsr(n, 0.004, 0.15, 0.7, min(0.05, dur * 0.3)) * vel


def lead(f, dur, vel=0.6, kind='soft'):
    n = int(dur * SR); t = np.arange(n) / SR
    vib = 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t * 3 - 0.3, 0, 1)
    ph = 2 * np.pi * f * (t + np.cumsum(vib) / SR * 0)  # simple
    ph = 2 * np.pi * f * t + 2 * np.pi * f * np.cumsum(vib) / SR * 40
    if kind == 'saw':
        y = sum(np.sin(k * ph) / k for k in range(1, 12)) * 0.6
    elif kind == 'square':
        y = sum(np.sin(k * ph) / k for k in range(1, 14, 2)) * 0.8
    elif kind == 'bell':
        y = np.sin(ph + 1.5 * np.sin(3.5 * ph) * np.exp(-t * 3)) * np.exp(-t * 2.5)
    else:  # soft flute-ish
        y = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    return y * adsr(n, 0.02, 0.1, 0.8, min(0.12, dur * 0.4)) * vel


def guitar(freqs, dur, vel=0.7):
    """distorted power chord"""
    n = int(dur * SR); t = np.arange(n) / SR
    y = np.zeros(n)
    for f in freqs:
        y += sum(np.sin(2 * np.pi * f * k * t + k * 0.7) / k for k in range(1, 7))
    y = np.tanh(y * 2.5) * adsr(n, 0.005, 0.1, 0.75, min(0.04, dur * 0.3))
    return y * vel


rng_noise = np.random.default_rng(1)


def hp(x):
    return np.diff(x, prepend=0)


def kick(vel=1.0, punch=1.0):
    n = int(0.35 * SR); t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t * 28) * punch
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    y += rng_noise.standard_normal(n) * np.exp(-t * 200) * 0.15
    return y * vel


def snare(vel=0.8, brush=False):
    n = int((0.25 if not brush else 0.18) * SR); t = np.arange(n) / SR
    nz = rng_noise.standard_normal(n)
    if brush:
        return hp(nz) * np.exp(-t * 22) * vel * 0.22
    y = hp(nz) * np.exp(-t * 16) * 0.45 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.7
    return y * vel


def hat(vel=0.4, open_=False):
    n = int((0.25 if open_ else 0.05) * SR); t = np.arange(n) / SR
    y = hp(hp(rng_noise.standard_normal(n))) * np.exp(-t * (10 if open_ else 70))
    return y * vel * 0.12


def clap(vel=0.7):
    n = int(0.2 * SR); t = np.arange(n) / SR
    env = np.exp(-t * 30) + 0.6 * np.exp(-np.maximum(0, t - 0.012) * 40) * (t > 0.012) + 0.4 * np.exp(-np.maximum(0, t - 0.024) * 30) * (t > 0.024)
    return hp(rng_noise.standard_normal(n)) * env * vel * 0.35


def crash(vel=0.5):
    n = int(1.8 * SR); t = np.arange(n) / SR
    return hp(hp(rng_noise.standard_normal(n))) * np.exp(-t * 2.2) * vel * 0.1


# ------------------------------------------------------------------ arranging
class Track:
    def __init__(self, bpm, bars, beats=4):
        self.bpm, self.beat = bpm, 60.0 / bpm
        self.len = int((bars * beats * self.beat + 3) * SR)
        self.bus = {k: np.zeros(self.len) for k in ('drums', 'bass', 'keys', 'pad', 'lead', 'gtr')}
        self.pan = {'drums': 0.0, 'bass': 0.0, 'keys': -0.25, 'pad': 0.2, 'lead': 0.15, 'gtr': -0.3}

    def add(self, bus, beat_pos, sig, gain=1.0, swing=0.0):
        # swing: delay off-beat 8ths
        frac = beat_pos % 1.0
        if swing and abs(frac - 0.5) < 1e-6:
            beat_pos += swing
        i = int(beat_pos * self.beat * SR)
        if i >= self.len: return
        sig = sig[:self.len - i]
        self.bus[bus][i:i + len(sig)] += sig * gain

    def render(self, rev=0.25, master=0.8):
        out = np.zeros((self.len, 2))
        ir = make_ir(1.8)
        for k, x in self.bus.items():
            if not np.any(x): continue
            wet = conv(x, ir) * (rev if k not in ('bass', 'drums') else rev * 0.35)
            y = x + wet[:len(x)]
            p = self.pan[k]
            out[:, 0] += y * (1 - max(0, p)); out[:, 1] += y * (1 + min(0, p))
        out = out / (np.percentile(np.abs(out), 99.9) + 1e-9) * 0.85
        out = np.tanh(out * 1.2) / np.tanh(1.2) * master
        # fade out tail
        f = int(2.5 * SR)
        out[-f:] *= np.linspace(1, 0, f)[:, None]
        return out


def make_ir(sec):
    n = int(sec * SR); t = np.arange(n) / SR
    r = np.random.default_rng(3).standard_normal(n) * np.exp(-t * 3.2)
    r[:int(0.012 * SR)] = 0
    return r / np.sqrt(np.sum(r ** 2)) * 0.6


def conv(x, ir):
    n = len(x) + len(ir)
    N = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[:len(x)]


def melody(rng, chords, scale_root, scale, bars, density=0.6, octave=5, motif_len=2, rhythm_set=None):
    """Motif-based melody: a 2-bar motif is varied over the chord progression (A A' B A'')."""
    rhythm_set = rhythm_set or [[1, 1, 1, 1], [1.5, 0.5, 1, 1], [0.5, 0.5, 1, 2], [1, 0.5, 0.5, 2], [2, 1, 1], [0.75, 0.75, 0.5, 2]]
    pitches = [12 * (octave + 1) + scale_root + s for s in scale] + [12 * (octave + 2) + scale_root + s for s in scale[:3]]

    def make_motif():
        notes = []
        for b in range(motif_len):
            rh = rhythm_set[rng.integers(len(rhythm_set))]
            for d in rh:
                notes.append([d, int(rng.integers(len(pitches) - 3))])
        return notes

    A = make_motif(); B = make_motif()
    form = []
    for i in range(0, bars, motif_len):
        sec = (i // motif_len) % 4
        form.append(B if sec == 2 else A)
    events, pos = [], 0.0
    for mi, mot in enumerate(form):
        shift = [0, 1, 0, -1][mi % 4]
        for d, idx in mot:
            bar = int(pos // 4)
            ch = chords[bar % len(chords)]
            _, tones = parse_chord(ch, octave)
            p = pitches[max(0, min(len(pitches) - 1, idx + shift))]
            # snap long notes to chord tones for consonance
            if d >= 1:
                cands = [tn + 12 * k for tn in tones for k in range(-1, 3)]
                p = min(cands, key=lambda c: abs(c - p))
            if rng.random() < density:
                events.append((pos, d, p))
            pos += d
    return events


SCALES = {'major': [0, 2, 4, 5, 7, 9, 11], 'dorian': [0, 2, 3, 5, 7, 9, 10], 'minor': [0, 2, 3, 5, 7, 8, 10], 'mixo': [0, 2, 4, 5, 7, 9, 10],
          'penta': [0, 2, 4, 7, 9], 'mpenta': [0, 3, 5, 7, 10]}


# ------------------------------------------------------------------ songs
def song_lounge(seed=11, name='Boulevard Lounge'):
    rng = np.random.default_rng(seed)
    T = Track(92, 48)
    prog = ['Dmaj9', 'Bm9', 'Em9', 'A13', 'Gmaj9', 'F#m7', 'Em9', 'A13']
    for bar in range(48):
        ch = prog[bar % len(prog)]
        root, tones = parse_chord(ch, 3)
        b0 = bar * 4
        # e-piano comping: syncopated
        for off, d in ((0, 1.5), (1.5, 1.0), (3.0 if bar % 2 else 2.5, 1.0)):
            for k, m in enumerate(tones[1:]):
                T.add('keys', b0 + off + k * 0.012, epiano(hz(m + 12), d * T.beat, 0.35), 0.5, swing=0.08)
        # walking-ish bass
        walk = [root - 12, root - 12 + 7, root - 12 + (10 if 'm' in ch or '7' in ch or '13' in ch else 11), root - 12 + 5]
        if bar % 2: walk[3] = root - 12 + 2
        for i, m in enumerate(walk):
            T.add('bass', b0 + i, bass(hz(m), T.beat * 0.9, 0.8), 0.9)
        # brushes & ride
        if bar >= 4:
            for i in range(4):
                T.add('drums', b0 + i, hat(0.35), 0.6)
                T.add('drums', b0 + i + 0.5, hat(0.22), 0.6, swing=0.12)
            T.add('drums', b0 + 1, snare(0.5, brush=True), 0.8)
            T.add('drums', b0 + 3, snare(0.55, brush=True), 0.8)
            T.add('drums', b0, kick(0.55, 0.6), 0.8)
            T.add('drums', b0 + 2.5, kick(0.4, 0.6), 0.7, swing=0.1)
        if bar % 8 == 0:
            T.add('pad', b0, pad(hz(tones[0] + 12), 16 * T.beat, 0.3, 0.3), 0.5)
    for (pos, d, p) in melody(rng, prog, NOTE['D'], SCALES['major'], 48, density=0.75):
        if 8 * 4 <= pos < 40 * 4:
            T.add('lead', pos, lead(hz(p), d * T.beat * 0.95, 0.45, 'soft'), 0.55, swing=0.08)
    return T.render(rev=0.32)


def song_funk(seed=21):
    rng = np.random.default_rng(seed)
    T = Track(104, 48)
    prog = ['Em9', 'Em9', 'A13', 'A13', 'Cmaj9', 'Bm7', 'Am9', 'B7']
    for bar in range(48):
        ch = prog[bar % len(prog)]
        root, tones = parse_chord(ch, 3)
        b0 = bar * 4
        # slap-ish bass 16ths pattern
        pat = [(0, 0), (0.75, 12), (1.5, 0), (2, 7), (2.5, 10), (3, 0), (3.5, 12)]
        for o, iv in pat:
            T.add('bass', b0 + o, bass(hz(root - 12 + iv), T.beat * 0.4, 0.9, 'finger'), 0.9)
        # clav-like stabs
        for o in (0.5, 1.75, 2.5, 3.75):
            for k, m in enumerate(tones[1:4]):
                T.add('keys', b0 + o, epiano(hz(m + 12), T.beat * 0.3, 0.5), 0.45)
        if bar >= 2:
            for i in range(8):
                T.add('drums', b0 + i * 0.5, hat(0.4 if i % 2 == 0 else 0.25, open_=(i == 7)), 0.7)
            T.add('drums', b0, kick(0.9), 0.9); T.add('drums', b0 + 1.75, kick(0.6), 0.8); T.add('drums', b0 + 2.5, kick(0.75), 0.8)
            T.add('drums', b0 + 1, snare(0.75), 0.75); T.add('drums', b0 + 3, snare(0.8), 0.75)
        if bar % 8 == 0 and bar >= 8:
            T.add('drums', b0, crash(0.4), 0.5)
            T.add('pad', b0, pad(hz(tones[0] + 12), 16 * T.beat, 0.25, 0.35), 0.4)
    for (pos, d, p) in melody(rng, prog, NOTE['E'], SCALES['dorian'], 48, density=0.7):
        if 8 * 4 <= pos < 44 * 4:
            T.add('lead', pos, lead(hz(p), d * T.beat * 0.9, 0.45, 'bell'), 0.5)
    return T.render(rev=0.22)


def song_race_rock(seed=31, key='E', bpm=148):
    rng = np.random.default_rng(seed)
    T = Track(bpm, 64)
    r = NOTE[key]
    prog = [r, r, r + 8 - 12 + 12, r + 10 - 12 + 12, r + 5, r + 5, r + 3, r + 10 - 12]
    prog = [x % 12 for x in [r, r, (r + 8) % 12, (r + 10) % 12, (r + 5) % 12, (r + 5) % 12, (r + 3) % 12, (r + 10) % 12]]
    for bar in range(64):
        rt = 40 + prog[bar % 8]
        b0 = bar * 4
        section = (bar // 16)
        # driving 8th bass
        for i in range(8):
            T.add('bass', b0 + i * 0.5, bass(hz(rt - 12), T.beat * 0.45, 0.9, 'synth'), 0.8)
        # power chords
        if section >= 1:
            for o, d in ((0, 1.5), (1.5, 0.5), (2, 1.5), (3.5, 0.5)):
                T.add('gtr', b0 + o, guitar([hz(rt), hz(rt + 7), hz(rt + 12)], d * T.beat * 0.95, 0.5), 0.45)
        # drums
        for i in range(8):
            T.add('drums', b0 + i * 0.5, hat(0.35), 0.6)
        T.add('drums', b0, kick(1.0), 1.0); T.add('drums', b0 + 2, kick(0.9), 1.0); T.add('drums', b0 + 2.5, kick(0.7), 0.9)
        T.add('drums', b0 + 1, snare(0.9), 0.85); T.add('drums', b0 + 3, snare(0.95), 0.85)
        if bar % 16 == 15:
            for k in range(8): T.add('drums', b0 + 2 + k * 0.25, snare(0.5 + k * 0.06), 0.7)
        if bar % 8 == 0:
            T.add('drums', b0, crash(0.6), 0.6)
        if bar % 4 == 0:
            T.add('pad', b0, pad(hz(rt + 12), 16 * T.beat, 0.25, 0.5), 0.3)
    for (pos, d, p) in melody(rng, [k + 'm' for k in ['E']] * 8, r, SCALES['mpenta'], 64, density=0.85, octave=5,
                              rhythm_set=[[0.5, 0.5, 1, 2], [1, 1, 0.5, 0.5, 1], [1.5, 0.5, 2], [0.5, 0.5, 0.5, 0.5, 2]]):
        if 16 * 4 <= pos < 32 * 4 or 40 * 4 <= pos < 60 * 4:
            T.add('lead', pos, lead(hz(p), d * T.beat * 0.9, 0.5, 'saw'), 0.42)
    return T.render(rev=0.18)


def song_electro(seed=41, key='A', bpm=128):
    rng = np.random.default_rng(seed)
    T = Track(bpm, 64)
    r = NOTE[key]
    prog = ['Am', 'F', 'C', 'G']
    prog = [p.replace('A', key) if p == 'Am' else p for p in prog]
    for bar in range(64):
        ch = prog[(bar // 2) % 4]
        root, tones = parse_chord(ch, 3)
        b0 = bar * 4
        build = bar % 16 >= 12
        # offbeat bass
        for i in range(4):
            T.add('bass', b0 + i + 0.5, bass(hz(root - 12), T.beat * 0.45, 0.9, 'synth'), 0.85)
        # arp
        if bar >= 8:
            arp = tones + [tones[1] + 12]
            for i in range(16):
                m = arp[i % len(arp)] + 12
                T.add('keys', b0 + i * 0.25, lead(hz(m), T.beat * 0.22, 0.35, 'square'), 0.3)
        # four on the floor
        if not (bar % 16 in (14, 15) and bar < 60):
            for i in range(4): T.add('drums', b0 + i, kick(1.0), 1.0)
        for i in range(4): T.add('drums', b0 + i + 0.5, hat(0.45, open_=True), 0.4)
        T.add('drums', b0 + 1, clap(0.8), 0.8); T.add('drums', b0 + 3, clap(0.8), 0.8)
        if build:
            for k in range(4): T.add('drums', b0 + k, snare(0.3 + 0.1 * (bar % 4)), 0.6)
        if bar % 16 == 0: T.add('drums', b0, crash(0.6), 0.6)
        if bar % 2 == 0:
            for m in tones: T.add('pad', b0, pad(hz(m + 12), 8 * T.beat, 0.2, 0.55), 0.35)
    for (pos, d, p) in melody(rng, prog * 2, r, SCALES['minor'], 64, density=0.8, octave=5):
        if 24 * 4 <= pos < 40 * 4 or 48 * 4 <= pos < 62 * 4:
            T.add('lead', pos, lead(hz(p), d * T.beat * 0.9, 0.5, 'saw'), 0.4)
    return T.render(rev=0.25)


def song_license(seed=51):
    rng = np.random.default_rng(seed)
    T = Track(108, 40)
    prog = ['Fmaj7', 'G6', 'Em7', 'Am7', 'Dm9', 'G9', 'Cmaj9', 'Cmaj9']
    for bar in range(40):
        ch = prog[bar % 8]
        root, tones = parse_chord(ch, 3)
        b0 = bar * 4
        for i in range(8):
            m = tones[(i * 2) % len(tones)] + 12
            T.add('keys', b0 + i * 0.5, epiano(hz(m), T.beat * 0.6, 0.35), 0.45)
        T.add('bass', b0, bass(hz(root - 12), T.beat * 1.4, 0.8), 0.85)
        T.add('bass', b0 + 2.5, bass(hz(root - 5), T.beat * 1.2, 0.7), 0.8)
        if bar >= 4:
            for i in range(8): T.add('drums', b0 + i * 0.5, hat(0.3), 0.55)
            T.add('drums', b0, kick(0.8), 0.85); T.add('drums', b0 + 2, kick(0.7), 0.8)
            T.add('drums', b0 + 1, snare(0.55), 0.6); T.add('drums', b0 + 3, snare(0.6), 0.6)
    for (pos, d, p) in melody(rng, prog, NOTE['C'], SCALES['major'], 40, density=0.7):
        if 8 * 4 <= pos < 36 * 4:
            T.add('lead', pos, lead(hz(p), d * T.beat * 0.9, 0.4, 'bell'), 0.5)
    return T.render(rev=0.3)


def song_title(seed=61):
    """Atmospheric intro theme with a slow build."""
    rng = np.random.default_rng(seed)
    T = Track(84, 32)
    prog = ['Dmaj9', 'Dmaj9', 'Bm11', 'Bm11', 'Gmaj9', 'Gmaj9', 'A13', 'A13']
    prog = ['Dmaj9', 'Dmaj9', 'Bm9', 'Bm9', 'Gmaj9', 'Gmaj9', 'A13', 'A13']
    for bar in range(32):
        ch = prog[bar % 8]
        root, tones = parse_chord(ch, 3)
        b0 = bar * 4
        if bar % 2 == 0:
            for m in tones[:4]: T.add('pad', b0, pad(hz(m + 12), 8.5 * T.beat, 0.3, 0.35), 0.5)
        if bar >= 8:
            T.add('bass', b0, bass(hz(root - 12), T.beat * 3.5, 0.7), 0.8)
            for i in range(4):
                T.add('keys', b0 + i, epiano(hz(tones[(i + 1) % len(tones)] + 24), T.beat * 1.2, 0.3), 0.4)
        if bar >= 16:
            T.add('drums', b0, kick(0.7, 0.7), 0.8); T.add('drums', b0 + 2.5, kick(0.5, 0.7), 0.7)
            T.add('drums', b0 + 2, snare(0.5, brush=True), 0.7)
            for i in range(8): T.add('drums', b0 + i * 0.5, hat(0.25), 0.5)
    for (pos, d, p) in melody(rng, prog, NOTE['D'], SCALES['major'], 32, density=0.6, motif_len=4,
                              rhythm_set=[[2, 2], [3, 1], [1, 1, 2], [4]]):
        if 16 * 4 <= pos < 31 * 4:
            T.add('lead', pos, lead(hz(p), d * T.beat * 0.95, 0.45, 'soft'), 0.5)
    return T.render(rev=0.45)


def song_results(seed=71):
    T = Track(100, 16)
    prog = ['Cmaj9', 'Am9', 'Fmaj9', 'G13']
    rng = np.random.default_rng(seed)
    for bar in range(16):
        ch = prog[bar % 4]
        root, tones = parse_chord(ch, 3)
        b0 = bar * 4
        for off in (0, 1.5, 3):
            for m in tones[1:]: T.add('keys', b0 + off, epiano(hz(m + 12), T.beat * 1.2, 0.35), 0.5)
        T.add('bass', b0, bass(hz(root - 12), T.beat * 1.5, 0.8), 0.85); T.add('bass', b0 + 2, bass(hz(root - 5), T.beat * 1.5, 0.7), 0.8)
        for i in range(8): T.add('drums', b0 + i * 0.5, hat(0.3), 0.55, swing=0.1 if i % 2 else 0)
        T.add('drums', b0, kick(0.8), 0.85); T.add('drums', b0 + 1, snare(0.6), 0.6); T.add('drums', b0 + 3, snare(0.6), 0.6)
    for (pos, d, p) in melody(rng, prog, NOTE['C'], SCALES['major'], 16, density=0.8):
        if 4 * 4 <= pos < 15 * 4:
            T.add('lead', pos, lead(hz(p), d * T.beat * 0.9, 0.4, 'soft'), 0.5)
    return T.render(rev=0.3)


SONGS = {
    'title': ('turismo_titel.ogg', 'Lichter der Stadt', song_title),
    'lounge': ('turismo_lounge.ogg', 'Boulevard Lounge', song_lounge),
    'lounge2': ('turismo_lounge2.ogg', 'Espresso am Ring', lambda: song_lounge(seed=13)),
    'funk': ('turismo_funk.ogg', 'Showroom Funk', song_funk),
    'license': ('turismo_fahrschule.ogg', 'Fahrschule', song_license),
    'race1': ('turismo_rennen1.ogg', 'Vollgas', song_race_rock),
    'race2': ('turismo_rennen2.ogg', 'Kurvenjagd', lambda: song_race_rock(seed=33, key='A', bpm=156)),
    'race3': ('turismo_rennen3.ogg', 'Neon-Apex', song_electro),
    'race4': ('turismo_rennen4.ogg', 'Nachtfahrt', lambda: song_electro(seed=44, key='D', bpm=124)),
    'results': ('turismo_siegerehrung.ogg', 'Siegerehrung', song_results),
}

PLAYLIST_CONTEXTS = {
    'title': ['title'], 'menu': ['lounge', 'lounge2', 'funk'], 'dealer': ['funk', 'lounge'], 'license': ['license'],
    'race': ['race1', 'race2', 'race3', 'race4'], 'results': ['results'],
}


def write_ogg(path, data):
    wav = path[:-4] + '.wav'
    with wave.open(wav, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(data, -1, 1) * 32767).astype('<i2').tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '4', path], check=True)
    os.remove(wav)


def main():
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:]
    for key, (file, title, fn) in SONGS.items():
        if only and key not in only: continue
        data = fn()
        write_ogg(os.path.join(OUT, file), data)
        print('  %-10s %-22s %5.1f s' % (key, title, len(data) / SR))
    playlist = {
        'info': 'Alle Stücke wurden für Turismo prozedural komponiert und synthetisiert (tools/gen_music.py). Eigene Musik: Dateien hier ablegen und unten eintragen.',
        'tracks': {k: {'file': v[0], 'title': v[1], 'artist': 'Turismo (generiert)', 'license': 'eigenes Werk, frei verwendbar'} for k, v in SONGS.items()},
        'contexts': PLAYLIST_CONTEXTS,
    }
    with open(os.path.join(OUT, 'playlist.json'), 'w', encoding='utf-8') as f:
        json.dump(playlist, f, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
