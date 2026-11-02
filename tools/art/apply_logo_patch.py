#!/usr/bin/env python3
"""Baut Name+Logo "Beam Turismo" in einen Mod-Ordner ein (idempotent, Ordner im Mod-Layout wie auf dem PC). Aufruf: python3 tools/art/apply_logo_patch.py <mod-ordner>
Nötig, solange die Branches der anderen Threads nicht zusammengeführt sind."""
import re, sys, os
R = sys.argv[1]
def P(rel): return os.path.join(R, rel)
def patch(rel, pairs, must=True):
    p = P(rel)
    if not os.path.exists(p): print('fehlt', rel); return
    s = open(p, encoding='utf-8').read()
    for a, b in pairs:
        if b in s and a not in s: continue
        n = s.count(a)
        if n != 1:
            print('NICHT GEFUNDEN in', rel, ':', a[:70]); continue
        s = s.replace(a, b)
    open(p, 'w', encoding='utf-8').write(s)

patch('ui/ui-vue/mods/turismo_karriere/index.js', [(
'''  addButton({ title: "Turismo Karriere", iconId: "stopwatchArrows02", action: openCareer })''',
'''  // eigenes Bild-Icon: das Hauptmenü zeigt "icon" nur im Angular-Stil (translateid/icon/targetState),
  // targetState darf dabei eine Funktion sein (MainMenu.vue addButton + MoreView normalizedAddons, 0.40)
  addButton({ translateid: "Beam Turismo", icon: BASE + "art/menu_icon.png", targetState: openCareer })''')])

patch('ui/ui-vue/mods/turismo_karriere/PauseCard.vue', [
('''    <div class="logo"><span class="t">T</span>URISMO</div>''', '''    <img class="logo" src="/ui/modules/apps/TurismoHub/art/logo_auf_dunkel.png" alt="Beam Turismo" />'''),
('''Turismo-Menü öffnen ▸''', '''Beam Turismo öffnen ▸'''),
('''  .logo { font-size: 2rem; font-weight: 900; letter-spacing: 0.25em; .t { color: #36d1ff; } }''', '''  .logo { display: block; width: 22rem; max-width: 100%; height: auto; margin: -1rem 0 -0.5rem -1rem; }'''),
('''    padding: 0.75rem 1.5rem; border-radius: 2rem; border: 1px solid rgba(54, 209, 255, 0.6);
    background: rgba(20, 60, 110, 0.9); color: #fff; font-weight: 700; cursor: pointer;
    &:hover { background: rgba(54, 140, 220, 0.95); }''', '''    padding: 0.75rem 1.5rem; border-radius: 0.25rem; border: 0;
    background: #d0021b; color: #fff; font-weight: 700; cursor: pointer;
    &:hover { background: #ff1f35; }'''),
])

patch('ui/modules/apps/TurismoHub/turismo-ui.js', [
('''<div class="logo">TURISMO</div>''', '''<img class="logo" src="' + BASE + 'art/logo_auf_dunkel.png" alt="Beam Turismo">'''),
('''<div class="tz-logo" data-act="home"><b>T</b>URISMO<small>KARRIERE</small></div>''', '''<div class="tz-logo" data-act="home"><img src="' + BASE + 'art/logo_leiste.png" alt="Beam Turismo"></div>'''),
('''<div class="tz-logo" data-act="home"><img src="' + BASE + 'art/logo_auf_dunkel.png" alt="Beam Turismo"></div>''', '''<div class="tz-logo" data-act="home"><img src="' + BASE + 'art/logo_leiste.png" alt="Beam Turismo"></div>'''),
('''<div class="tz-bigLogo"><b>T</b>URISMO</div><div class="tz-sub">DIE KARRIERE · FÜR BEAMNG.DRIVE</div>''', '''<div class="tz-bigLogo"><img src="' + BASE + 'art/logo_auf_dunkel.png" alt="Beam Turismo"></div>'''),
("""'Turismo – Die Karriere · ein Fan-Mod für BeamNG.drive'""", """'Beam Turismo · eine Karriere für BeamNG.drive (Fan-Mod)'"""),
("""<h2 style="margin:0 0 6px">Turismo</h2>""", """<h2 style="margin:0 0 6px">Beam Turismo</h2>"""),
("""Alle Fahrer-, Serien- und Hallennamen sind frei erfunden.</div>'""", """Alle Fahrer-, Serien- und Hallennamen sind frei erfunden.</div>' +
      '<div style="margin-top:8px">Logo und Menü-Icon: eigene Gestaltung, erstellt mit VectorCraft. Die Buchstaben stammen aus der Schrift <b>Inter</b> von Rasmus Andersson (SIL Open Font License 1.1, rsms.me/inter), umgewandelt in Pfade.</div>'"""),
("'Was sich in Turismo Karriere geändert hat'", "'Was sich in Beam Turismo geändert hat'"),
("<h2>Willkommen bei Turismo</h2>", "<h2>Willkommen bei Beam Turismo</h2>"),
("<b>Esc → Mods → Turismo-Menü</b>", "<b>Esc → Mods → Beam Turismo</b>"),
])

css = open(P('ui/modules/apps/TurismoHub/app.css'), encoding='utf-8').read()
if 'Beam Turismo: Logo als Bild' not in css:
    css += '''
/* Beam Turismo: Logo als Bild (tools/art/make_logo.py, VectorCraft) */
.tz-logo img { display: block; height: 40px; width: auto; margin: -4px 0 -4px -10px; }
.tz-title .tz-bigLogo { text-shadow: none; }
.tz-title .tz-bigLogo img { display: block; width: min(820px, 80vw); height: auto; }
.tz-loading .logo { display: block; width: min(640px, 70vw); height: auto; text-indent: 0; }
.tz-loading { background: radial-gradient(ellipse at 50% 45%, #1a1c21, #0b0c0e 70%); }
.tz-loading .bar i { background: #d0021b; }
'''
    open(P('ui/modules/apps/TurismoHub/app.css'), 'w', encoding='utf-8').write(css)

patch('lua/ge/extensions/turismo/core.lua', [
("""label = 'Turismo-Menü', icon = 'wrench',""", """label = 'Beam Turismo', icon = 'wrench',"""),
("""U().log('I', 'Turismo Karriere %s geladen', M.VERSION)""", """U().log('I', 'Beam Turismo %s geladen', M.VERSION)"""),
('-- pause menu (Esc) -> tab "Mods" -> "Turismo-Menü"', '-- pause menu (Esc) -> tab "Mods" -> "Beam Turismo"'),
('-- main menu button "Turismo Karriere"', '-- main menu button "Beam Turismo"'),
])

cr = open(P('CREDITS.md'), encoding='utf-8').read()
if '## Logo und Schrift' not in cr:
    cr = cr.replace('# Credits\n', '# Credits – Beam Turismo\n', 1) + '''
## Logo und Schrift

Logo und Hauptmenü-Icon sind eigene Gestaltung, gerendert mit **VectorCraft** ([github.com/storytold/vectorcraft](https://github.com/storytold/vectorcraft), MIT/Apache-2.0), Generator `tools/art/make_logo.py`.
Die Buchstaben stammen aus der Schrift **Inter** von Rasmus Andersson ([rsms.me/inter](https://rsms.me/inter)), lizenziert unter der [SIL Open Font License 1.1](https://openfontlicense.org). Sie wurden in Pfade umgewandelt, breiter gezogen und schräg gestellt. Der Mod enthält keine Schriftdatei.
'''
    open(P('CREDITS.md'), 'w', encoding='utf-8').write(cr)

DE = '''
### Neu: Name und Logo „Beam Turismo“
- Die Mod heißt jetzt **Beam Turismo** und hat ein eigenes Logo: ein schräges „BT“-Schild mit rotem Streifen und dem Schriftzug daneben.
- Im Hauptmenü unter **Mehr** steht „Beam Turismo“ mit dem BT-Schild als Symbol statt der Stoppuhr.
- Das Logo erscheint auf dem Startbildschirm mit den Spielständen, oben links in der Menüleiste, im Ladebildschirm und im Pausenmenü (Esc → Mods → Beam Turismo). Auch der Willkommens-Hinweis und der Changelog-Bildschirm sagen jetzt „Beam Turismo“.
- Der Ladebildschirm ist jetzt dunkelgrau mit rotem Balken statt blau.
- In den Credits steht, woher die Schrift im Logo kommt.
'''
EN = '''
### New: name and logo "Beam Turismo"
- The mod is now called **Beam Turismo** and has its own logo: a slanted "BT" plate with a red stripe and the wordmark next to it.
- In the main menu under **More**, "Beam Turismo" shows the BT plate as its icon instead of the stopwatch.
- The logo appears on the start screen with the save slots, top left in the menu bar, on the loading screen and in the pause menu (Esc → Mods → Beam Turismo). The welcome guide and the changelog screen now say "Beam Turismo" too.
- The loading screen is now dark grey with a red bar instead of blue.
- The credits say where the logo's typeface comes from.
'''
for fn, txt in (('CHANGELOG.md', DE), ('CHANGELOG_EN.md', EN)):
    s = open(P(fn), encoding='utf-8').read()
    if txt.strip().splitlines()[0] in s: continue
    m = re.search(r'(?m)^## [^\n]*\n', s)
    s = s[:m.end()] + txt + s[m.end():]
    open(P(fn), 'w', encoding='utf-8').write(s)
print('ok')

# ---- Handbuch (Kapitel 17) ----
LOGO_SEC = '''<h3 id="logo">Name, Logo und Icon</h3>
<p>Der Name im Spiel ist <b>Beam Turismo</b>. Intern heißen Ordner, Lua-Module und Spielstände weiter <code>turismo_…</code> bzw. <span class="path">turismo_karriere</span>, damit alte Spielstände und Tastenbelegungen bleiben. „BeamNG“ steht absichtlich nicht im Namen: Die Markenrichtlinien von BeamNG verbieten, ihre Marke mit eigenen Namen zu verbinden. „für BeamNG.drive“ als Hinweis ist erlaubt.</p>
<table>
<tr><th>Datei (in <span class="path">ui\\modules\\apps\\TurismoHub\\art\\</span>)</th><th>Wo im Spiel</th></tr>
<tr><td><code>logo_auf_dunkel.png</code> (weiße Schrift, transparent)</td><td>Startbildschirm, Menüleiste oben links, Ladebildschirm, Pausenmenü</td></tr>
<tr><td><code>logo_auf_hell.png</code> (schwarze Schrift, transparent)</td><td>für helle Flächen (Reserve)</td></tr>
<tr><td><code>menu_icon.png</code> (weiß, transparent)</td><td>Symbol der Kachel im BeamNG-Hauptmenü unter „Mehr“</td></tr>
</table>
<p>So kommt das Icon ins Hauptmenü: BeamNG 0.40 zeigt ein eigenes Bild nur bei Knöpfen im „Angular-Stil“. Darum ruft <span class="path">index.js</span> <code>addButton({ translateid: "Beam Turismo", icon: ".../art/menu_icon.png", targetState: openCareer })</code> auf. <code>translateid</code> ist der angezeigte Text (ohne Übersetzung bleibt er so stehen), <code>targetState</code> darf eine Funktion sein. Mit <code>iconId</code> statt <code>icon</code> ginge nur ein Symbol aus BeamNGs eigener Icon-Schrift.</p>
<p><b>Logo ändern oder Variante tauschen:</b> Die Logos entstehen in <span class="path">tools\\art\\make_logo.py</span> (drei Varianten: <code>a</code> Plakette, <code>b</code> Ideallinie, <code>c</code> Rondell, je hell/dunkel, dazu je ein Icon). Farben stehen oben in der Datei (<code>RED</code>, <code>INK</code>, <code>SILVER</code>). Neu bauen:</p>
<pre><code>VC=/pfad/zu/vectorcraft-cli LOGO=a sh tools/art/build_logo.sh   # rendert alles, schneidet zu, kopiert Variante a in den Mod</code></pre>
<p>Unter Windows liegt eine fertige <span class="path">render.cmd</span> in <span class="path">F:\\BeamNG\\current\\turismo_logo\\</span>, die alle SVGs dort mit VectorCraft rendert. Danach mit <code>python3 tools/art/crop_png.py IN OUT 16</code> zuschneiden. Die Schrift im Logo ist <b>Inter</b> (SIL Open Font License, steht in den Credits), in Pfade umgewandelt; der Mod enthält keine Schriftdatei.</p>

'''
hb_p = P('docs/handbuch.html')
s = open(hb_p, encoding='utf-8').read()
if 'id="logo"' not in s:
    for a, b in [
        ('''<li><b>Hauptmenü:</b> „Turismo Karriere“ unter <b>Mehr</b> (Vue-UI-Mod in <span class="path">ui\\ui-vue\\mods\\turismo_karriere\\index.js</span>).</li>''',
         '''<li><b>Hauptmenü:</b> „Beam Turismo“ unter <b>Mehr</b> mit eigenem Bild-Icon (Vue-UI-Mod in <span class="path">ui\\ui-vue\\mods\\turismo_karriere\\index.js</span>, siehe <a href="#logo">Name, Logo und Icon</a>).</li>'''),
        ('''<li><b>Pausenmenü:</b> Esc → Mods → Turismo-Menü (<span class="path">PauseCard.vue</span>).</li>''',
         '''<li><b>Pausenmenü:</b> Esc → Mods → Beam Turismo (<span class="path">PauseCard.vue</span>).</li>'''),
        ('''<h3 id="grafik">Grafiken (VectorCraft)</h3>''', LOGO_SEC + '''<h3 id="grafik">Grafiken (VectorCraft)</h3>'''),
        ('''    <a class="l2" href="#grafik">Grafiken (VectorCraft)</a>''', '''    <a class="l2" href="#logo">Name, Logo und Icon</a>
    <a class="l2" href="#grafik">Grafiken (VectorCraft)</a>'''),
    ]:
        if s.count(a) != 1: print('HANDBUCH NICHT GEFUNDEN:', a[:70]); continue
        s = s.replace(a, b)
    open(hb_p, 'w', encoding='utf-8').write(s)
print('handbuch ok')
