#!/usr/bin/env python3
"""Handbook chapters 7/8/12 and changelog entries for the licence/driving-school
rework, as a patch (several threads edit these files in parallel).
  python3 tools/patches/docs_licenses.py <folder with CHANGELOG.md, CHANGELOG_EN.md, docs/handbuch.html>
Safe to run twice."""
import os
import re
import sys

LIC_ROWS = '''
<section id="lizenzen">
<h2><span class="n">7</span> Lizenzen und Prüfungen <span class="tag">data\\turismo\\licenses.json</span></h2>
<p>7 Lizenzen mit zusammen 61 Prüfungen: C, B, A, I, S mit je 10, Rallye 6, Drift 5. Aufbau wie in GT: erst Grundlagen, dann Abschnitte und Sektoren echter Strecken, am Ende eine Prüfungsrunde.
Lizenz C und B finden im <b>ETK-Fahrerzentrum</b> statt (Karte <code>driver_training</code>, die Übungsstrecken von BeamNG), A, I und S auf Hirochi Raceway, dem Automation Test Track und in Italien.</p>
<p>Die Tore einer Prüfung sind die <b>Checkpoints aus den race-Dateien des Spiels</b>, z. B. <code>/gameplay/missions/driver_training/campaigns/008-slalom/race.race.json</code>. Darum liegen sie immer auf der Straße. Welche Dateien es gibt, steht in <code>F:\\BeamNG\\current\\turismo_dump\\index.txt</code> (Abzug deiner 0.40.4-Installation).</p>
<table>
<tr><th>Feld (Lizenz)</th><th>Bedeutung</th></tr>
<tr><td><code>id</code></td><td>z. B. <code>L1</code>. Wird in <code>requires</code> von Serien benutzt. Nicht ändern.</td></tr>
<tr><td><code>name</code>, <code>short</code>, <code>color</code>, <code>desc</code></td><td>Anzeige. <code>short</code> ist der Buchstabe auf der Plakette und in der Prüfungsnummer (C-1, C-2 …).</td></tr>
<tr><td><code>requires</code></td><td>Lizenz, die vorher nötig ist</td></tr>
<tr><td><code>allGoldReward</code></td><td>Geschenkauto für alle Prüfungen in Gold (<a href="#kriterien">Kriterien</a>)</td></tr>
<tr><td><code>tests</code></td><td>Liste der Prüfungen</td></tr>
</table>
<table>
<tr><th>Feld (Prüfung)</th><th>Bedeutung</th></tr>
<tr><td><code>id</code></td><td>z. B. <code>L1-03</code>. Auch der Name des Vorschaubilds: <code>ui\\modules\\apps\\TurismoHub\\previews\\tests\\L1-03.jpg</code> (16:9). Fehlt das Bild, zeigt das Menü eine farbige Kachel mit der Nummer.</td></tr>
<tr><td><code>name</code></td><td>Titel</td></tr>
<tr><td><code>goal</code></td><td>Ziel, steht im Briefing und auf der Strecke (<code>desc</code> = gleicher Text für alte Stellen)</td></tr>
<tr><td><code>tip</code></td><td>Tipp im Briefing</td></tr>
<tr><td><code>place</code></td><td>Ortsname in der Anzeige, z. B. „ETK-Fahrerzentrum“</td></tr>
<tr><td><code>type</code></td><td><code>path</code> = Tore aus einer race-Datei (alle neuen Prüfungen). Alt: <code>gates</code> (Tore in Metern vom Startpunkt eines <a href="#orte">Orts</a>), <code>track</code> (Runden mit BeamNGs Rennlogik).</td></tr>
<tr><td><code>race</code></td><td>race-Datei. Auch eine Liste: die erste vorhandene wird genommen.</td></tr>
<tr><td><code>level</code></td><td>Karte, die geladen wird (sonst aus dem Pfad der race-Datei)</td></tr>
<tr><td><code>from</code>, <code>to</code></td><td>Abschnitt: von Checkpoint Nr. bis Nr. (in Fahrtrichtung gezählt, 1 = Start). Ohne Angabe die ganze Strecke.</td></tr>
<tr><td><code>sector</code>, <code>of</code></td><td>Statt from/to: Sektor x von y, die Checkpoints werden gleichmäßig aufgeteilt.</td></tr>
<tr><td><code>laps</code></td><td>Runden auf einem Rundkurs. Start auf dem Startplatz der Datei, Ziel = Checkpoint 1.</td></tr>
<tr><td><code>start</code></td><td><code>{"kind": "standing"}</code> = Auto steht am ersten Checkpoint, Zeit läuft ab „Los“. <code>{"kind": "rolling", "speed": 110, "back": 45}</code> = fliegender Start: Auto startet 45 m vor dem ersten Tor mit 110 km/h, die Zeit läuft ab dem ersten Tor.</td></tr>
<tr><td><code>finish</code></td><td><code>gate</code> = Ziel ist das letzte Tor. <code>stop</code> = danach in einer Haltezone anhalten (<code>stopAfter</code> m hinter dem Tor, Größe <code>stopLen</code> × <code>stopW</code>).</td></tr>
<tr><td><code>speed</code></td><td>Tempo an einem Tor, Nummer in der Liste der Tore: <code>{"2": {"min": 60}}</code> oder <code>{"3": {"max": 80}}</code></td></tr>
<tr><td><code>offTrack</code></td><td>Wie weit (m) du von der Linie zwischen zwei Checkpoints weg darfst. Ohne Angabe 10 m + Torbreite + 22 % des Abstands. Länger als 3 s draußen = nicht bestanden.</td></tr>
<tr><td><code>car</code></td><td>Leihwagen nach <code>criteria</code>, oder <code>"rental": false</code> = eigenes Auto (Schäden bleiben)</td></tr>
<tr><td><code>targets</code></td><td>Zielzeiten. <code>{"mode": "auto", "goldFactor": 1.04, "silverFactor": 1.12, "bronzeFactor": 1.25}</code>: Referenzzeit × Faktor. Referenz = Zeit der Vorführung, sonst beim ersten Start auf der echten Straße berechnet, sonst grob aus den Checkpoints geschätzt. Feste Zeiten: <code>gold</code>/<code>silver</code>/<code>bronze</code> in Sekunden.</td></tr>
<tr><td><code>timeLimit</code></td><td>Nicht bestanden nach x Sekunden</td></tr>
</table>
<p><b>Sicher ändern:</b> Einen Abschnitt verschieben = <code>from</code>/<code>to</code> ändern. Eine Prüfung leichter machen = <code>bronzeFactor</code> erhöhen. Neue Prüfung = Block kopieren, neue <code>id</code>. Die Checkpoint-Nummern einer Strecke siehst du im Spiel: Prüfung starten, die Tore sind der Reihe nach nummeriert (oben „Tor 3 / 8“).</p>
<pre><code>{ "id": "L1-02", "name": "Bremsen aus 60", "type": "path",
  "race": "/gameplay/missions/driver_training/campaigns/001-acceleationBraking/race.race.json",
  "start": {"kind": "standing"}, "finish": "stop", "speed": {"2": {"min": 60}},
  "car": {"criteria": {"categories": ["street"], "liMin": 230, "liMax": 340}},
  "targets": {"mode": "auto", "goldFactor": 1.04, "silverFactor": 1.12, "bronzeFactor": 1.25}, "timeLimit": 60 }</code></pre>
<p>Im Log (<a href="#log">turismo.log</a>) steht bei jedem Start <code>tests: start L1-02 (path)</code>, die berechnete Strecke (<code>route … m</code>) und die Referenzzeit.</p>
</section>

<section id="trainings">
<h2><span class="n">8</span> Fahrschule (Streckenkunde) <span class="tag">data\\turismo\\trainings.json</span></h2>
<p>Die Fahrschule bringt dir Strecken bei, Sektor für Sektor und dann die ganze Runde: ETK-Teststrecke (4 Sektoren), Hirochi Kurzkurs, Automation Kurzkurs, Stadtkurs Italien, Hirochi Langkurs (je 3). 22 Aufgaben.
Felder wie bei den <a href="#lizenzen">Prüfungen</a>, dazu <code>category</code> (Name der Strecke, Gruppe in der Anzeige), <code>school</code> (Kürzel, Teil der ID <code>TR-hrk-2</code>) und <code>dayCost</code> (Spieltage, 0 = keine). Jede Medaille wird einmal bezahlt (Beträge aus <code>economy.json</code> <code>testRewards</code>).</p>
<p>Neue Strecke: in <code>tools/gen_data.py</code> eine Zeile in <code>schools</code> ergänzen (Kürzel, Name, race-Datei, Anzahl Sektoren, Rundkurs ja/nein, Auto, Texte) und <code>python3 tools/gen_data.py</code> ausführen.</p>
</section>
'''

ORTE_NOTE = '<p>Lizenzprüfungen und Fahrschule brauchen keine Orte mehr, sie nutzen die race-Dateien der Strecken. Orte gelten noch für Crawling und Derby.</p>\n'

CL_DE = '''### Neu: Lizenzprüfungen auf echten Strecken
- Die Prüfungen finden jetzt auf echten BeamNG-Strecken statt, nicht mehr auf der leeren Gridmap. Lizenz C und B im ETK-Fahrerzentrum (Bremsen, Kurven, Spurwechsel, Slalom, Haarnadel, Rundkurs, Teststrecke), Lizenz A, I und S auf Hirochi Raceway, dem Automation Test Track und in Italien.
- Jede Lizenz hat 10 Prüfungen, aufgebaut wie in GT: erst Grundlagen, dann Abschnitte und Sektoren, am Ende eine Prüfungsrunde. Rallye-Lizenz 6, Drift-Lizenz 5.
- Das Lizenzzentrum zeigt oben alle Lizenzen, darunter die gewählte Lizenz mit Fortschritt und ihre Prüfungen als Kacheln (C-1, C-2 …) mit Medaille.
- Ein Klick auf eine Prüfung öffnet das Briefing: Ziel, Tipp, Ort, Auto, stehender oder fliegender Start, Medaillenzeiten mit Belohnung und dein Bestwert. Dort startest du die Prüfung oder die Vorführung.
- Fliegender Start: Du kommst mit Tempo an, die Zeit läuft ab dem ersten Tor.
- Auf der Strecke zeigen orange Tore, wo du durch musst. Orange Pfeile auf der Straße zeigen den Weg zum nächsten Tor, oben stehen ein Richtungspfeil und die Entfernung.
- Fährst du zu weit von der Strecke weg, erscheint „Zurück auf die Strecke!“. Nach 3 Sekunden ist die Prüfung nicht bestanden.
- Die Zielzeiten werden beim ersten Start auf der echten Straße berechnet, nach einer Vorführung aus der Zeit des KI-Fahrers.
- Jede Prüfung hat Platz für ein eigenes Vorschaubild.

### Neu: Fahrschule als Streckenkunde
- Die Fahrschule bringt dir fünf Strecken bei: ETK-Teststrecke, Hirochi Kurzkurs, Automation Kurzkurs, Stadtkurs Italien und Hirochi Langkurs. Jede Sektor für Sektor, dann die ganze Runde. Jede Medaille wird einmal bezahlt.

### Fehler behoben
- Lizenztest: Das Auto stand verkehrt herum, deshalb zeigte die Linie vom Auto weg. Autos stehen jetzt richtig herum, auch beim Neusetzen nach einer Reparatur und die Gegner im Derby.
- Die Vorführung im Lizenztest fuhr nicht los. Der KI-Fahrer folgt jetzt der Straße durch alle Tore.

'''

CL_EN = '''### New: licence tests on real tracks
- Tests now take place on real BeamNG tracks instead of the empty grid map. Licences C and B at the ETK Driver Experience Center (braking, corners, lane change, slalom, hairpin, small circuit, test track), licences A, I and S on Hirochi Raceway, the Automation Test Track and Italy.
- Every licence has 10 tests, built like in GT: basics first, then sections and sectors, a final exam lap at the end. Rally licence 6, drift licence 5.
- The licence centre shows all licences at the top, below the selected licence with its progress and its tests as tiles (C-1, C-2 …) with medal.
- Clicking a test opens the briefing: goal, tip, place, car, standing or rolling start, medal times with reward and your best. Start the test or the demo from there.
- Rolling start: you arrive at speed, the clock starts at the first gate.
- On track, orange gates show where to go. Orange arrows on the road lead to the next gate, a direction arrow and the distance are shown at the top.
- Drive too far off the track and "Back on track!" appears. After 3 seconds the test is failed.
- Target times are calculated on the real road at the first start, after a demo from the AI driver's time.
- Every test has room for its own preview image.

### New: driving school as track school
- The driving school teaches five tracks: ETK test track, Hirochi short course, Automation short course, Italy street circuit and Hirochi long course. Each sector by sector, then the full lap. Every medal pays once.

### Fixed
- Licence test: the car stood the wrong way round, so the guide line pointed away from it. Cars now face the right way, also when respawned after a repair and the opponents in the derby.
- The demo in licence tests did not drive off. The AI driver now follows the road through all gates.

'''

MARK_DE = '### Neu: Lizenzprüfungen auf echten Strecken'
MARK_EN = '### New: licence tests on real tracks'


def insert_changelog(path, block, mark):
    s = open(path, encoding='utf-8').read()
    if mark in s:
        a = s.index(mark)
        # replace our block (up to the next '### ' that is not ours or '## ')
        end = s.find('\n## ', a)
        return  # already there; keep it simple and idempotent
    m = re.search(r'^## .*\n\n', s, flags=re.M)
    s = s[:m.end()] + block + s[m.end():]
    open(path, 'w', encoding='utf-8', newline='\n').write(s)


def patch_handbook(path):
    s = open(path, encoding='utf-8').read()
    a = s.index('<section id="lizenzen">')
    b = s.index('<section id="cafe">')
    s = s[:a] + LIC_ROWS.lstrip('\n') + '\n' + s[b:]
    if ORTE_NOTE not in s:
        a = s.index('<section id="orte">')
        e = s.index('</section>', a)
        s = s[:e] + ORTE_NOTE + s[e:]
    open(path, 'w', encoding='utf-8', newline='\n').write(s)


def main():
    d = sys.argv[1]
    insert_changelog(os.path.join(d, 'CHANGELOG.md'), CL_DE, MARK_DE)
    insert_changelog(os.path.join(d, 'CHANGELOG_EN.md'), CL_EN, MARK_EN)
    patch_handbook(os.path.join(d, 'docs', 'handbuch.html'))
    print('docs patched', d)


if __name__ == '__main__':
    main()
