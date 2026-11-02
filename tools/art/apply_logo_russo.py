#!/usr/bin/env python3
"""Logo-Update auf die endgültige Fassung (Runde 8, Schrift Russo One) in einem Mod-Ordner,
auf dem apply_logo_patch.py schon gelaufen ist. Idempotent.
Aufruf: python3 tools/art/apply_logo_russo.py <mod-ordner>"""
import os, re, sys
R = sys.argv[1]


def P(rel):
    return os.path.join(R, rel)


def patch(rel, pairs):
    p = P(rel)
    if not os.path.exists(p):
        print('fehlt', rel); return
    s = open(p, encoding='utf-8').read()
    for a, b in pairs:
        if b in s and a not in s:
            continue
        if s.count(a) != 1:
            print('NICHT GEFUNDEN in', rel, ':', a[:80]); continue
        s = s.replace(a, b)
    open(p, 'w', encoding='utf-8').write(s)


ORANGE, ORANGE_HI = '#e35300', '#ff6600'

patch('ui/modules/apps/TurismoHub/turismo-ui.js', [
    ('''<div class="tz-logo" data-act="home"><img src="' + BASE + 'art/logo_auf_dunkel.png" alt="Beam Turismo"></div>''',
     '''<div class="tz-logo" data-act="home"><img src="' + BASE + 'art/logo_leiste.png" alt="Beam Turismo"></div>'''),
    ('''Die Buchstaben stammen aus der Schrift <b>Inter</b> von Rasmus Andersson (SIL Open Font License 1.1, rsms.me/inter), umgewandelt in Pfade.''',
     '''Schrift im Logo: <b>Russo One</b> von Jovanny Lemonad (SIL Open Font License 1.1), umgewandelt in Pfade.'''),
])

patch('ui/ui-vue/mods/turismo_karriere/PauseCard.vue', [
    ('background: #d0021b; color: #fff;', 'background: %s; color: #fff;' % ORANGE),
    ('&:hover { background: #ff1f35; }', '&:hover { background: %s; }' % ORANGE_HI),
])

patch('ui/modules/apps/TurismoHub/app.css', [
    ('.tz-loading .bar i { background: #d0021b; }', '.tz-loading .bar i { background: %s; }' % ORANGE_HI),
    ('.tz-logo img { display: block; height: 40px; width: auto; margin: -4px 0 -4px -10px; }',
     '.tz-logo img { display: block; height: 42px; width: auto; margin: -4px 0; }'),
])

patch('CREDITS.md', [(
    '''Die Buchstaben stammen aus der Schrift **Inter** von Rasmus Andersson ([rsms.me/inter](https://rsms.me/inter)), lizenziert unter der [SIL Open Font License 1.1](https://openfontlicense.org). Sie wurden in Pfade umgewandelt, breiter gezogen und schräg gestellt. Der Mod enthält keine Schriftdatei.''',
    '''Die Schrift im Logo ist **Russo One** von Jovanny Lemonad ([fonts.google.com/specimen/Russo+One](https://fonts.google.com/specimen/Russo+One)), lizenziert unter der [SIL Open Font License 1.1](https://openfontlicense.org). Sie wurde in Pfade umgewandelt und schräg gestellt. Der Mod enthält keine Schriftdatei.''')])

# alte Beschreibung im 0.1.5-Eintrag stimmt nicht mehr
patch('CHANGELOG.md', [
    ('und hat ein eigenes Logo: ein schräges „BT“-Schild mit rotem Streifen und dem Schriftzug daneben.',
     'und hat ein eigenes Logo: ein „BT“ in Silber und BeamNG-Orange, darunter der Schriftzug.'),
    ('mit dem BT-Schild als Symbol statt der Stoppuhr.', 'mit dem BT-Zeichen als Symbol statt der Stoppuhr.'),
    ('Der Ladebildschirm ist jetzt dunkelgrau mit rotem Balken statt blau.', 'Der Ladebildschirm ist jetzt dunkelgrau mit orangem Balken statt blau.'),
])
patch('CHANGELOG_EN.md', [
    ('and has its own logo: a slanted "BT" plate with a red stripe and the wordmark next to it.',
     'and has its own logo: a "BT" in silver and BeamNG orange with the wordmark below.'),
    ('shows the BT plate as its icon instead of the stopwatch.', 'shows the BT mark as its icon instead of the stopwatch.'),
    ('The loading screen is now dark grey with a red bar instead of blue.', 'The loading screen is now dark grey with an orange bar instead of blue.'),
])

DE = '''
### Neu: endgültiges Logo
- Das Logo ist neu gestaltet: ein „BT“ in glänzendem Silber und BeamNG-Orange in der Schrift Russo One, darunter „BEAM TURISMO“.
- Das Symbol im Hauptmenü unter **Mehr** zeigt jetzt das BT-Zeichen auf dunkler Kachel mit orangem Rand.
- Oben links in der Menüleiste steht das Zeichen mit dem Schriftzug daneben.
- Ladebalken und der Knopf im Pausenmenü sind jetzt orange.
'''
EN = '''
### New: final logo
- The logo has been redesigned: a "BT" in glossy silver and BeamNG orange in the Russo One typeface, with "BEAM TURISMO" below.
- The icon in the main menu under **More** now shows the BT mark on a dark tile with an orange rim.
- The menu bar shows the mark with the wordmark next to it in the top left.
- The loading bar and the button in the pause menu are orange now.
'''
for fn, txt in (('CHANGELOG.md', DE), ('CHANGELOG_EN.md', EN)):
    s = open(P(fn), encoding='utf-8').read()
    if txt.strip().splitlines()[0] in s:
        continue
    m = re.search(r'(?m)^## [^\n]*\n', s)
    s = s[:m.end()] + txt + s[m.end():]
    open(P(fn), 'w', encoding='utf-8').write(s)

# Handbuch: Abschnitt "Name, Logo und Icon"
patch('docs/handbuch.html', [
    ('''<tr><td><code>logo_auf_dunkel.png</code> (weiße Schrift, transparent)</td><td>Startbildschirm, Menüleiste oben links, Ladebildschirm, Pausenmenü</td></tr>
<tr><td><code>logo_auf_hell.png</code> (schwarze Schrift, transparent)</td><td>für helle Flächen (Reserve)</td></tr>
<tr><td><code>menu_icon.png</code> (weiß, transparent)</td><td>Symbol der Kachel im BeamNG-Hauptmenü unter „Mehr“</td></tr>''',
     '''<tr><td><code>logo_auf_dunkel.png</code> (Zeichen + Schriftzug, helle Schrift, transparent)</td><td>Startbildschirm, Ladebildschirm, Pausenmenü</td></tr>
<tr><td><code>logo_leiste.png</code> (Zeichen links, Schriftzug rechts, transparent)</td><td>Menüleiste oben links</td></tr>
<tr><td><code>logo_auf_hell.png</code> (dunkelblaues B, dunkle Schrift, transparent)</td><td>für helle Flächen (Reserve)</td></tr>
<tr><td><code>menu_icon.png</code> (dunkle Kachel mit orangem Rand)</td><td>Symbol der Kachel im BeamNG-Hauptmenü unter „Mehr“</td></tr>'''),
    ('''(drei Varianten: <code>a</code> Plakette, <code>b</code> Ideallinie, <code>c</code> Rondell, je hell/dunkel, dazu je ein Icon). Farben stehen oben in der Datei (<code>RED</code>, <code>INK</code>, <code>SILVER</code>). Neu bauen:''',
     '''(endgültige Fassung: Aufruf mit <code>runde8</code>, Funktion <code>main8</code>; ältere Entwürfe stehen als <code>runde1</code> bis <code>runde7</code> daneben). Farben: <code>SILVER_B</code> (B auf dunkel), <code>STEEL</code> (B auf hell), <code>ORANGE</code> (T). Neu bauen:'''),
    ('''<pre><code>VC=/pfad/zu/vectorcraft-cli LOGO=a sh tools/art/build_logo.sh   # rendert alles, schneidet zu, kopiert Variante a in den Mod</code></pre>''',
     '''<pre><code>VC=/pfad/zu/vectorcraft-cli sh tools/art/build_logo.sh   # rendert alles, schneidet zu, kopiert die vier Bilder in den Mod</code></pre>'''),
    ('''Die Schrift im Logo ist <b>Inter</b> (SIL Open Font License, steht in den Credits), in Pfade umgewandelt; der Mod enthält keine Schriftdatei.''',
     '''Die Schrift im Logo ist <b>Russo One</b> (SIL Open Font License, liegt mit Lizenz in <span class="path">tools\\art\\fonts\\</span>, steht in den Credits), in Pfade umgewandelt; der Mod enthält keine Schriftdatei.'''),
])
print('ok')
