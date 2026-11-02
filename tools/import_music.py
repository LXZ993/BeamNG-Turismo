#!/usr/bin/env python3
"""Turismo soundtrack: converts the licensed MP3s to OGG and writes playlist.json.

All tracks are by Kevin MacLeod (incompetech.com), licensed CC BY 4.0. The MP3s
come from https://incompetech.com/music/royalty-free/mp3-royaltyfree/<Title>.mp3
and are not stored in the repo; the converted OGGs are.

    python3 tools/import_music.py <folder with the MP3s>
    python3 tools/import_music.py --playlist-only   # rewrite playlist.json only

Each track is loudness-normalised (EBU R128) so menu and race music sit at a
similar level, then encoded as Ogg Vorbis (BeamNG's CEF plays OGG reliably).
"""
import json, os, re, subprocess, sys

OUT = os.path.join(os.path.dirname(__file__), '..', 'mod', 'ui', 'modules', 'apps', 'TurismoHub', 'audio', 'music')
ARTIST = 'Kevin MacLeod (incompetech.com)'
LICENSE = 'CC BY 4.0'
LICENSE_URL = 'http://creativecommons.org/licenses/by/4.0/'

# key: (title, context list, target loudness LUFS)
TRACKS = {
    'exhilarate':        ('Exhilarate',                ['title'],             -15),
    'airport_lounge':    ('Airport Lounge',            ['menu'],              -18),
    'bossa_antigua':     ('Bossa Antigua',             ['menu', 'dealer'],    -18),
    'cool_vibes':        ('Cool Vibes',                ['menu'],              -18),
    'lobby_time':        ('Lobby Time',                ['menu'],              -18),
    'local_forecast':    ('Local Forecast - Elevator', ['menu'],              -18),
    'funkorama':         ('Funkorama',                 ['dealer', 'menu'],    -17),
    'funky_chunk':       ('Funky Chunk',               ['dealer'],            -17),
    'groove_grove':      ('Groove Grove',              ['dealer'],            -17),
    'easy_lemon':        ('Easy Lemon',                ['license'],           -17),
    'cut_and_run':       ('Cut and Run',               ['race'],              -15),
    'exit_the_premises': ('Exit the Premises',         ['race'],              -15),
    'movement_prop':     ('Movement Proposition',      ['race'],              -15),
    'ouroboros':         ('Ouroboros',                 ['race'],              -15),
    'raving_energy':     ('Raving Energy',             ['race'],              -15),
    'rhinoceros':        ('Rhinoceros',                ['race'],              -15),
    'volatile_reaction': ('Volatile Reaction',         ['race'],              -15),
    'hep_cats':          ('Hep Cats',                  ['results'],           -17),
}
CONTEXT_ORDER = ['title', 'menu', 'dealer', 'license', 'race', 'results']


LICENSE_TEXT = 'Licensed under Creative Commons: By Attribution 4.0 License, ' + LICENSE_URL


def main(src, encode=True):
    os.makedirs(OUT, exist_ok=True)
    tracks, contexts = {}, {c: [] for c in CONTEXT_ORDER}
    for key, (title, ctxs, lufs) in TRACKS.items():
        mp3 = os.path.join(src, title + '.mp3')
        ogg = 'km_' + key + '.ogg'
        if encode and not os.path.exists(mp3):
            sys.exit('missing: ' + mp3)
        if encode: subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', mp3, '-map', '0:a', '-map_metadata', '-1',
                        '-af', 'loudnorm=I=%d:TP=-1.5:LRA=11' % lufs, '-ar', '44100', '-ac', '2',
                        '-c:a', 'libvorbis', '-q:a', '3',
                        '-metadata', 'title=' + title, '-metadata', 'artist=Kevin MacLeod',
                        '-metadata', 'copyright=' + LICENSE + ' ' + LICENSE_URL,
                        os.path.join(OUT, ogg)], check=True)
        tracks[key] = {'file': ogg, 'title': title, 'artist': ARTIST, 'license': LICENSE, 'licenseText': LICENSE_TEXT,
                       'source': 'https://incompetech.com/music/royalty-free/mp3-royaltyfree/' + title.replace(' ', '%20') + '.mp3'}
        for c in ctxs:
            contexts[c].append(key)
        print('ok', ogg)
    pl = {
        'info': 'Musik: Kevin MacLeod (incompetech.com), Lizenz Creative Commons BY 4.0 (' + LICENSE_URL + '). '
                'Namensnennung wird beim Abspielen eingeblendet und steht in CREDITS.md. Eigene Musik: OGG hier ablegen und unten eintragen.',
        'credit': 'Alle Musikstücke von Kevin MacLeod (incompetech.com), lizenziert unter Creative Commons BY 4.0. '
                  'Für Turismo nur ins OGG-Format umgewandelt und in der Lautstärke angeglichen.',
        'tracks': tracks,
        'contexts': contexts,
    }
    with open(os.path.join(OUT, 'playlist.json'), 'w', encoding='utf-8') as f:
        json.dump(pl, f, ensure_ascii=False, indent=1)
    if not encode:
        return
    keep = {t['file'] for t in tracks.values()} | {'playlist.json'}
    for f in os.listdir(OUT):
        if f not in keep and re.search(r'\.(ogg|mp3|wav)$', f):
            os.remove(os.path.join(OUT, f)); print('removed old', f)


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--playlist-only':
        main('.', encode=False)
    else:
        main(sys.argv[1] if len(sys.argv) > 1 else '.')
