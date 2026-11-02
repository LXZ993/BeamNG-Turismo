#!/usr/bin/env python3
"""Generates the content files in mod/data/turismo/*.json.

Content is written as Python data so it is easy to extend and keep consistent
(ids, unlock keys, track selectors). Run: python3 tools/gen_data.py
All names, texts and drivers are original (no real series, people or trademarks).
"""
import json
import math
import os
import random

OUT = os.path.join(os.path.dirname(__file__), '..', 'mod', 'data', 'turismo')
os.makedirs(OUT, exist_ok=True)


def write(name, data):
    with open(os.path.join(OUT, name + '.json'), 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print('wrote', name, len(data) if isinstance(data, list) else '')


# ---------------------------------------------------------------------------
# track selectors: always give fallbacks so every event resolves on any install
# ---------------------------------------------------------------------------
def circuit(*levels):
    return [f'@circuit:{l}' for l in levels] + ['@circuit:tarmac', '@circuit:']


def sprint(*levels):
    return [f'@sprint:{l}' for l in levels] + ['@sprint:tarmac', '@sprint:']


def dirt(*levels):
    return [f'@any:{l}' for l in levels] + ['@sprint:dirt', '@circuit:dirt', '@any:dirt', '@sprint:']


HR, WCU, ITA, ATT, ECU, JRI, UTAH, JV, IND = ('hirochi_raceway', 'west_coast_usa', 'italy', 'automation_test_track',
                                               'east_coast_usa', 'jungle_rock_island', 'utah', 'johnson_valley', 'industrial')

# ---------------------------------------------------------------------------
# economy
# ---------------------------------------------------------------------------
economy = {
    'startMoney': 15000,
    'homeLevel': WCU,
    'dailyGoalKm': 42,
    'currentYear': 2025,
    'usedRotationDays': 3,
    'usedOfferCount': 20,
    'legendRotationDays': 7,
    'legendOfferCount': 8,
    'legendYearMax': 1995,
    'legendCollectorLevel': 4,
    'testRewards': {'bronze': 1000, 'silver': 2500, 'gold': 5000},
    'collectorLevels': [0, 30000, 80000, 150000, 300000, 500000, 800000, 1200000, 2000000, 3500000, 5000000, 8000000],
    'baseUnlocks': ['dealer_used', 'services', 'freeDrive', 'recorder', 'hall_einsteiger', 'license_L1'],
    'purchaseLicenseByLI': [{'liMin': 800, 'license': 'L4'}, {'liMin': 650, 'license': 'L3'}],
}
write('economy', economy)

# ---------------------------------------------------------------------------
# venues
# ---------------------------------------------------------------------------
venues = [
    {'id': 'testgelaende', 'name': 'Testgelände', 'level': 'gridmap_v2',
     'fallbackLevels': [ATT, 'driver_training', 'smallgrid'], 'anchor': 'spawn', 'offset': [0, 25]},
    {'id': 'crawlpark', 'name': 'Felsenpark', 'level': JV, 'fallbackLevels': [UTAH, 'gridmap_v2'], 'anchor': 'spawn', 'offset': [0, 15]},
    {'id': 'derby_arena', 'name': 'Derby-Arena', 'level': 'derby', 'fallbackLevels': [IND, 'gridmap_v2'], 'anchor': 'spawn', 'radius': 24},
    {'id': 'derby_gross', 'name': 'Große Arena', 'level': 'derby', 'fallbackLevels': [IND, 'gridmap_v2'], 'anchor': 'spawn', 'radius': 34},
]
write('venues', venues)

# ---------------------------------------------------------------------------
# course building blocks (local metres: x right, y forward)
# ---------------------------------------------------------------------------
def startstop(dist, box_len=6, box_w=4):
    return [{'kind': 'stop', 'x': 0, 'y': dist, 'w': box_w, 'len': box_len, 'label': 'STOP'}]


def gate(x, y, w=6, **kw):
    g = {'kind': 'gate', 'x': round(x, 2), 'y': round(y, 2), 'w': w}
    g.update(kw)
    return g


def slalom(n, spacing, offset, start=30, w=4.5):
    return [gate(offset if i % 2 == 0 else -offset, start + i * spacing, w) for i in range(n)]


def arc(cx, cy, r, a0, a1, steps, w=7, direction=1):
    """gates on an arc around (cx, cy); angles in degrees, 0 = +x axis"""
    out = []
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        heading = -(a0 + (a1 - a0) * i / steps) + (90 if direction > 0 else -90)
        out.append(gate(x, y, w, heading=round(heading - 90, 1)))
    return out


def chicane(y0=40):
    return [gate(0, y0), gate(-5, y0 + 28, 5), gate(5, y0 + 52, 5), gate(0, y0 + 85)]


def lane_change(y0=60, entry_kmh=None):
    g0 = gate(0, y0, 3.2, label='Einfahrt')
    if entry_kmh:
        g0['minSpeed'] = entry_kmh
    return [g0, gate(0, y0 + 10, 3.2), gate(3.6, y0 + 23, 3.6), gate(3.6, y0 + 33, 3.6), gate(0, y0 + 48, 3.4), gate(0, y0 + 60, 3.4)]


def hairpin_right(y0=60, r=14):
    # straight, 180 deg right turn, come back
    pts = [gate(0, y0 - 30)]
    pts += arc(r, y0, r, 180, 0, 6, w=8, direction=-1)
    pts += [gate(2 * r, y0 - 40, 8)]
    return pts


def figure_eight(r=18):
    pts = arc(r, 30, r, 180, -180, 10, w=8, direction=-1)
    pts += arc(-r, 30 + 0.01, r, 0, 360, 10, w=8, direction=1)
    return pts


def braking_zone(speed_gate_y, stop_y, min_kmh):
    return [gate(0, speed_gate_y, 6, minSpeed=min_kmh, label=f'min {min_kmh}')] + startstop(stop_y)


STREET_RENTAL = {'criteria': {'categories': ['street'], 'liMin': 230, 'liMax': 340}}
SPORT_RENTAL = {'criteria': {'categories': ['sport', 'street'], 'liMin': 400, 'liMax': 520}}
FAST_RENTAL = {'criteria': {'categories': ['sport', 'touring'], 'liMin': 520, 'liMax': 650}}
RACE_RENTAL = {'criteria': {'categories': ['touring', 'gt'], 'liMin': 600, 'liMax': 760}}
TOP_RENTAL = {'criteria': {'categories': ['gt', 'proto'], 'liMin': 700}}
RALLY_RENTAL = {'criteria': {'categories': ['rally', 'offroad', 'street'], 'drivetrains': ['AWD', '4WD']}}
DRIFT_RENTAL = {'criteria': {'drivetrains': ['RWD'], 'liMin': 380, 'liMax': 620}}


def ctest(tid, name, desc, course, car, **kw):
    t = {'id': tid, 'name': name, 'desc': desc, 'type': 'gates', 'venue': 'testgelaende', 'course': course, 'car': car,
         'targets': {'mode': 'estimate'}, 'timeLimit': kw.pop('timeLimit', 120)}
    t.update(kw)
    return t


def ttest(tid, name, desc, track, car, laps=1, **kw):
    t = {'id': tid, 'name': name, 'desc': desc, 'type': 'track', 'track': track, 'laps': laps, 'car': car,
         'targets': {'mode': 'estimate'}, 'cleanLap': True}
    t.update(kw)
    return t


# ---------------------------------------------------------------------------
# licence tests and driving school on real BeamNG courses (0.40):
# checkpoints of the game's own race files. ETK-Fahrerzentrum = level
# driver_training with 13 training courses, then sections and laps of
# Hirochi Raceway, Automation Test Track and Italien.
# from/to = checkpoint numbers in driving order (see Handbuch, Lizenzen)
# ---------------------------------------------------------------------------
MIS = '/gameplay/missions/'
def etk(name): return MIS + 'driver_training/campaigns/' + name + '/race.race.json'
ETK_TRACK = MIS + 'driver_training/timeTrial/001-ardenteExperience/race.race.json'
HR_SHORT = MIS + 'hirochi_raceway/timeTrial/003-shortcourse/race.race.json'
HR_MED = MIS + 'hirochi_raceway/timeTrial/004-mediumcourse/race.race.json'
HR_LONG = MIS + 'hirochi_raceway/timeTrial/005-longcourse/race.race.json'
HR_FULL = MIS + 'hirochi_raceway/timeTrial/001-forgotten/race.race.json'
ATT_SHORT = MIS + 'automation_test_track/timeTrial/009-Short/race.race.json'
ATT_HANDLING = MIS + 'automation_test_track/timeTrial/003-Handling/race.race.json'
ATT_RACE = MIS + 'automation_test_track/timeTrial/008-Race/race.race.json'
ATT_OUTSIDE = MIS + 'automation_test_track/timeTrial/006-Outside/race.race.json'
ATT_MAIN = MIS + 'automation_test_track/aiRace/001-main1/race.race.json'
ATT_GRAVEL = MIS + 'automation_test_track/timeTrial/007-Gravel/race.race.json'
ATT_DIRT = MIS + 'automation_test_track/timeTrial/001-dirt1/race.race.json'
ATT_ALPINE = MIS + 'automation_test_track/rallyStage/001-alpineclimb/race.race.json'
ATT_DRIFT = MIS + 'automation_test_track/drift/001-handling/race.race.json'
ITA_STREET = MIS + 'italy/aiRace/001-street/race.race.json'
ITA_QUARRY = MIS + 'italy/aiRace/005-quarryRace/race.race.json'
JV_RALLY = MIS + 'johnson_valley/timeTrial/004-rally1/race.race.json'
HR_DRIFT = MIS + 'hirochi_raceway/drift/001-Pro/race.race.json'
DT_DRIFT = MIS + 'driver_training/drift/001-basics/race.race.json'

PLACE = {'driver_training': 'ETK-Fahrerzentrum', 'hirochi_raceway': 'Hirochi Raceway', 'automation_test_track': 'Automation Test Track',
         'italy': 'Italien', 'johnson_valley': 'Johnson Valley'}


def ptest(tid, name, goal, tip, race, car, start='standing', speed_kmh=None, finish='gate', **kw):
    level = race.split('/missions/')[1].split('/')[0]
    t = {'id': tid, 'name': name, 'desc': goal, 'goal': goal, 'tip': tip, 'type': 'path', 'race': race,
         'level': level, 'place': PLACE.get(level, level), 'car': car, 'targets': {'mode': 'auto', 'goldFactor': 1.04, 'silverFactor': 1.12, 'bronzeFactor': 1.25}, 'finish': finish,
         'start': {'kind': start}}
    if start == 'rolling':
        t['start']['speed'] = speed_kmh or 60
        t['start']['back'] = kw.pop('back', 45)
    t.update(kw)
    return t


def spd(**rules):
    """speed rules per gate number: spd(g2=dict(min=50))"""
    return {k[1:]: v for k, v in rules.items()}


ETK_RWD = {'criteria': {'drivetrains': ['RWD'], 'liMin': 300, 'liMax': 460}}

licenses = [
    {'id': 'L1', 'name': 'Lizenz C - Clubsport', 'short': 'C', 'color': '#4fa3e0',
     'desc': 'Die Grundlagen im ETK-Fahrerzentrum: anfahren, bremsen, lenken. Voraussetzung für die ersten Pokale.',
     'allGoldReward': {'categories': ['street', 'sport'], 'liMax': 420},
     'tests': [
         ptest('L1-01', 'Anfahren und Anhalten', 'Fahre los und halte in der Zone am Ende der Geraden an.',
               'Gleichmäßig Gas geben, früh und dosiert bremsen. Zu spät gebremst ist nicht bestanden.',
               etk('001-acceleationBraking'), STREET_RENTAL, finish='stop', timeLimit=60),
         ptest('L1-02', 'Bremsen aus 60', 'Mit mindestens 60 km/h durch das mittlere Tor, dann in der Zone anhalten.',
               'Voll beschleunigen, nach dem Tor sofort fest bremsen. Das ABS hilft, lenke dabei gerade.',
               etk('001-acceleationBraking'), STREET_RENTAL, finish='stop', speed=spd(g2=dict(min=60)), timeLimit=60),
         ptest('L1-03', 'Sauber anfahren', 'Fahre los und nimm die zwei Kurven bis ins Ziel.',
               'Nicht mit durchdrehenden Rädern starten. Vor der Kurve bremsen, nicht in der Kurve.',
               etk('013-starting'), STREET_RENTAL, timeLimit=60),
         ptest('L1-04', 'Kurvengrundlagen', 'Fahre durch alle Tore der Kurvenstrecke.',
               'Außen anfahren, innen den Scheitel treffen, außen hinaus. Erst bremsen, dann lenken.',
               etk('002-cornering'), STREET_RENTAL, timeLimit=80),
         ptest('L1-05', 'Spurwechsel', 'Mit mindestens 50 km/h in den Spurwechsel und durch alle Tore.',
               'Ruhig lenken, nicht ruckartig. Schau zum nächsten Tor, nicht auf das aktuelle.',
               etk('004-lanechange'), STREET_RENTAL, speed=spd(g2=dict(min=50)), timeLimit=60),
         ptest('L1-06', 'Enge Straße', 'Folge der engen Straße durch alle Tore.',
               'Auf engen Straßen zählt die Linie mehr als das Tempo. Kurven nicht abkürzen.',
               etk('003-tightroad'), STREET_RENTAL, timeLimit=90),
         ptest('L1-07', 'Haarnadel', 'Nimm die Haarnadelkurve und fahre ins Ziel.',
               'Weit außen anfahren, spät einlenken, langsam rein und schnell raus.',
               etk('007-hairpins'), STREET_RENTAL, timeLimit=60),
         ptest('L1-08', 'Slalom', 'Fahre den Slalom hin und zurück durch alle Tore.',
               'Rhythmus statt Gewalt: früh einlenken, damit das Auto nicht aufschaukelt.',
               etk('008-slalom'), STREET_RENTAL, timeLimit=120),
         ptest('L1-09', 'Kurvengeschwindigkeit', 'Eine Folge schneller Kurven: halte das Tempo, ohne die Strecke zu verlassen.',
               'Lieber etwas langsamer hinein und früh wieder Gas. Abflug heißt nicht bestanden.',
               etk('005-cornerspeed'), STREET_RENTAL, timeLimit=120),
         ptest('L1-10', 'Prüfung: Kleiner Rundkurs', 'Eine Runde auf dem kleinen Rundkurs des Fahrerzentrums.',
               'Alles zusammen: bremsen vor der Kurve, saubere Linie, kein Kontakt.',
               etk('006-easycircuit'), STREET_RENTAL, laps=1, timeLimit=150),
     ]},
    {'id': 'L2', 'name': 'Lizenz B - National', 'short': 'B', 'color': '#6fbf73', 'requires': 'L1',
     'desc': 'Fahrzeugkontrolle bei höherem Tempo, Heckantrieb, nasse Kurven und die erste Rennstrecke.',
     'allGoldReward': {'categories': ['sport'], 'liMin': 420, 'liMax': 540},
     'tests': [
         ptest('L2-01', 'Bremsen aus 80', 'Mit mindestens 80 km/h durch das mittlere Tor, dann in der Zone anhalten.',
               'Schnelle Autos brauchen mehr Weg. Bremse hart an, dann löse leicht, um genau zu treffen.',
               etk('001-acceleationBraking'), SPORT_RENTAL, finish='stop', speed=spd(g2=dict(min=80)), timeLimit=60),
         ptest('L2-02', 'Wechselnder Grip', 'Fahre geradeaus über die Teststrecke mit wechselndem Grip.',
               'Wenn ein Rad weniger Grip hat, zieht das Auto zur Seite. Ruhig gegenlenken.',
               etk('011-diffs'), SPORT_RENTAL, speed=spd(g3=dict(min=50)), timeLimit=60),
         ptest('L2-03', 'Heckantrieb', 'Eine Runde im Heckantriebler, ohne dreher.',
               'Am Kurvenausgang das Gas langsam aufmachen, sonst kommt das Heck.',
               etk('009-rwd'), ETK_RWD, laps=1, timeLimit=150),
         ptest('L2-04', 'Nasse Kurve', 'Nimm die Kurvenfolge mit wenig Grip.',
               'Auf nassem Belag weich bremsen und weich lenken. Alles langsamer als gewohnt.',
               etk('012-wetcorner'), SPORT_RENTAL, timeLimit=90),
         ptest('L2-05', 'Schneller Slalom', 'Den Slalom hin und zurück mit einem schnelleren Auto.',
               'Mit mehr Tempo musst du noch früher einlenken.',
               etk('008-slalom'), SPORT_RENTAL, timeLimit=110),
         ptest('L2-06', 'Kurvengeschwindigkeit Sport', 'Die schnelle Kurvenfolge mit einem Sportwagen.',
               'Nutze die ganze Breite der Strecke.',
               etk('005-cornerspeed'), SPORT_RENTAL, timeLimit=110),
         ptest('L2-07', 'Fortgeschrittener Kurs', 'Eine Runde auf dem großen Übungskurs.',
               'Plane jede Kurve vorher: wo bremsen, wo einlenken, wo Gas.',
               etk('010-advanced'), SPORT_RENTAL, laps=1, timeLimit=150),
         ptest('L2-08', 'Teststrecke Teil 1', 'Die erste Hälfte der ETK-Teststrecke.',
               'Die Kehren nach der ersten Geraden kommen schnell. Rechtzeitig bremsen.',
               ETK_TRACK, SPORT_RENTAL, to=14, timeLimit=150),
         ptest('L2-09', 'Teststrecke Teil 2', 'Die zweite Hälfte der ETK-Teststrecke mit fliegendem Start.',
               'Du kommst mit Tempo an. Die Zeit läuft ab dem ersten Tor.',
               ETK_TRACK, SPORT_RENTAL, start='rolling', speed_kmh=70, **{'from': 14}, timeLimit=150),
         ptest('L2-10', 'Prüfung: ETK-Teststrecke', 'Die ganze ETK-Teststrecke ohne Fehler.',
               'Ruhig fahren und keine Strafen sammeln. Das bringt mehr als Risiko.',
               ETK_TRACK, SPORT_RENTAL, timeLimit=240),
     ]},
    {'id': 'L3', 'name': 'Lizenz A - National Pro', 'short': 'A', 'color': '#b07de8', 'requires': 'L2',
     'desc': 'Rennstrecke: Bremspunkte, Kurvenkombinationen und Sektoren auf Hirochi Raceway und dem Automation Test Track.',
     'allGoldReward': {'categories': ['sport', 'touring'], 'liMin': 540, 'liMax': 650},
     'tests': [
         ptest('L3-01', 'Bremspunkt Hirochi', 'Fliegender Start auf der Geraden, dann die Rechtskurve sauber treffen.',
               'Bremspunkt suchen: lieber zu früh als zu spät, dann in der nächsten Runde später.',
               HR_SHORT, FAST_RENTAL, start='rolling', speed_kmh=110, **{'from': 2, 'to': 4}, timeLimit=60),
         ptest('L3-02', 'Linkskombination Hirochi', 'Zwei Linkskurven hintereinander, ohne die Strecke zu verlassen.',
               'Die erste Kurve opfern, damit du schnell aus der zweiten kommst.',
               HR_SHORT, FAST_RENTAL, start='rolling', speed_kmh=90, **{'from': 5, 'to': 8}, timeLimit=80),
         ptest('L3-03', 'Hirochi Sektor 1', 'Erster Sektor des Kurzkurses.', 'Die Zeit läuft ab dem Start.',
               HR_SHORT, FAST_RENTAL, sector=1, of=3, timeLimit=80),
         ptest('L3-04', 'Hirochi Sektor 2', 'Zweiter Sektor mit fliegendem Start.', 'Halte das Tempo aus dem Anlauf mit.',
               HR_SHORT, FAST_RENTAL, sector=2, of=3, start='rolling', speed_kmh=100, timeLimit=80),
         ptest('L3-05', 'Hirochi Sektor 3', 'Letzter Sektor bis zur Ziellinie.', 'Der Ausgang der letzten Kurve entscheidet über die Zeit auf der Geraden.',
               HR_SHORT, FAST_RENTAL, sector=3, of=3, start='rolling', speed_kmh=100, timeLimit=80),
         ptest('L3-06', 'Handling-Kurs Sektor', 'Die erste Hälfte des Handling-Kurses auf dem Automation Test Track.',
               'Viele Richtungswechsel: Auto nicht überfahren.',
               ATT_HANDLING, FAST_RENTAL, **{'from': 1, 'to': 6}, timeLimit=80),
         ptest('L3-07', 'Kurzkurs Automation', 'Eine Runde auf dem kurzen Rundkurs des Automation Test Track.',
               'Schnelle Kurven: gleichmäßig lenken, nicht nachkorrigieren.',
               ATT_SHORT, FAST_RENTAL, laps=1, timeLimit=120),
         ptest('L3-08', 'Eigenes Auto', 'Eine Runde Hirochi Kurzkurs mit deinem eigenen Auto. Schäden bleiben!',
               'Kenne dein Auto: Bremsweg und Grip sind anders als beim Testwagen.',
               HR_SHORT, {'rental': False}, laps=1, timeLimit=180),
         ptest('L3-09', 'Hirochi Mittelkurs Teil', 'Der lange Mittelteil des Mittelkurses mit fliegendem Start.',
               'Auf der langen Geraden zählt der Kurvenausgang davor.',
               HR_MED, FAST_RENTAL, start='rolling', speed_kmh=100, **{'from': 3, 'to': 6}, timeLimit=100),
         ptest('L3-10', 'Prüfung: Hirochi Kurzkurs', 'Eine fehlerfreie Runde auf dem Hirochi Kurzkurs.',
               'Alles, was du in den Sektoren gelernt hast, in einer Runde.',
               HR_SHORT, FAST_RENTAL, laps=1, timeLimit=150),
     ]},
    {'id': 'L4', 'name': 'Lizenz I - International', 'short': 'I', 'color': '#e8a33d', 'requires': 'L3',
     'desc': 'Rennwagen mit viel Grip: lange Bremszonen, schnelle Kombinationen und internationale Strecken.',
     'allGoldReward': {'categories': ['touring', 'gt'], 'liMin': 620, 'liMax': 760},
     'tests': [
         ptest('L4-01', 'Haarnadel nach Gerade', 'Mit hohem Tempo von der Geraden in die Haarnadel.',
               'Bei viel Abtrieb kannst du später bremsen, als du denkst. Aber nicht zu spät.',
               HR_FULL, RACE_RENTAL, start='rolling', speed_kmh=150, **{'from': 6, 'to': 8}, timeLimit=60),
         ptest('L4-02', 'Schnelle Kombination', 'Eine schnelle Links-Rechts-Folge auf dem Rennkurs.',
               'Die Linie für die zweite Kurve beginnt schon in der ersten.',
               ATT_RACE, RACE_RENTAL, start='rolling', speed_kmh=140, **{'from': 1, 'to': 4}, timeLimit=80),
         ptest('L4-03', 'Lange Gerade, enge Kurve', 'Nach der langen Geraden die Kehre treffen.',
               'Je schneller die Gerade, desto wichtiger der Bremspunkt.',
               ATT_OUTSIDE, RACE_RENTAL, start='rolling', speed_kmh=160, **{'from': 8, 'to': 10}, timeLimit=80),
         ptest('L4-04', 'Rennkurs Sektor 1', 'Erster Sektor des Rennkurses auf dem Automation Test Track.', 'Konstant bleiben.',
               ATT_RACE, RACE_RENTAL, sector=1, of=3, timeLimit=100),
         ptest('L4-05', 'Rennkurs Sektor 2', 'Zweiter Sektor mit fliegendem Start.', 'Nimm Schwung aus dem Anlauf mit.',
               ATT_RACE, RACE_RENTAL, sector=2, of=3, start='rolling', speed_kmh=130, timeLimit=100),
         ptest('L4-06', 'Rennkurs Sektor 3', 'Letzter Sektor bis ins Ziel.', 'Der letzte Kurvenausgang zählt doppelt.',
               ATT_RACE, RACE_RENTAL, sector=3, of=3, start='rolling', speed_kmh=130, timeLimit=100),
         ptest('L4-07', 'Stadtkurs Italien', 'Eine Runde auf dem engen Stadtkurs in Italien.',
               'Mauern verzeihen nichts. Lieber zehn Zentimeter Platz lassen.',
               ITA_STREET, RACE_RENTAL, laps=1, timeLimit=150),
         ptest('L4-08', 'Hirochi Langkurs', 'Eine Runde auf dem Hirochi Langkurs.', 'Teile dir die Reifen ein.',
               HR_LONG, RACE_RENTAL, laps=1, timeLimit=200),
         ptest('L4-09', 'Eigener Rennwagen', 'Eine Runde Rennkurs Automation mit deinem eigenen Auto.',
               'Dein Auto, deine Schäden.', ATT_RACE, {'rental': False}, laps=1, timeLimit=240),
         ptest('L4-10', 'Prüfung: Rennkurs Automation', 'Eine fehlerfreie Runde auf dem Rennkurs.',
               'Bleib sauber, die Zeit kommt von allein.', ATT_RACE, RACE_RENTAL, laps=1, timeLimit=200),
     ]},
    {'id': 'L5', 'name': 'Lizenz S - Super', 'short': 'S', 'color': '#e85d3d', 'requires': 'L4',
     'desc': 'Nur für die Besten: GT-Rennwagen und Prototypen am Limit, lange Runden ohne Fehler.',
     'allGoldReward': {'categories': ['gt', 'proto'], 'liMin': 720},
     'tests': [
         ptest('L5-01', 'Vollgas-Bremszone', 'Mit über 200 km/h von der Geraden in die Kehre.',
               'Bei diesem Tempo ist jeder Meter Bremsweg Zeit.',
               ATT_OUTSIDE, TOP_RENTAL, start='rolling', speed_kmh=200, **{'from': 8, 'to': 10}, timeLimit=60),
         ptest('L5-02', 'Hochgeschwindigkeits-Kurven', 'Die schnellen Kurven am Ende des Rennkurses.',
               'Gefühl für den Abtrieb: je schneller, desto mehr Grip.',
               ATT_RACE, TOP_RENTAL, start='rolling', speed_kmh=180, **{'from': 6, 'to': 9}, timeLimit=80),
         ptest('L5-03', 'Außenkurs Sektor 1', 'Erster Sektor des Außenkurses.', 'Lange Geraden, harte Bremszonen.',
               ATT_OUTSIDE, TOP_RENTAL, sector=1, of=3, timeLimit=100),
         ptest('L5-04', 'Außenkurs Sektor 2', 'Zweiter Sektor mit fliegendem Start.', 'Die Kehre nach der Geraden ist der Schlüssel.',
               ATT_OUTSIDE, TOP_RENTAL, sector=2, of=3, start='rolling', speed_kmh=160, timeLimit=100),
         ptest('L5-05', 'Außenkurs Sektor 3', 'Letzter Sektor bis ins Ziel.', 'Nicht übermütig werden.',
               ATT_OUTSIDE, TOP_RENTAL, sector=3, of=3, start='rolling', speed_kmh=160, timeLimit=100),
         ptest('L5-06', 'Hirochi Gesamtkurs', 'Eine Runde auf dem vollständigen Hirochi-Kurs.', 'Die längste Runde der Rennstrecke.',
               HR_FULL, TOP_RENTAL, laps=1, timeLimit=240),
         ptest('L5-07', 'Steinbruch Italien', 'Eine Runde auf dem Steinbruch-Kurs in Italien.', 'Wenig Auslauf, viel Staub.',
               ITA_QUARRY, TOP_RENTAL, laps=1, timeLimit=150),
         ptest('L5-08', 'Zwei Runden konstant', 'Zwei Runden Hirochi Kurzkurs ohne einen Fehler.', 'Konstanz schlägt die eine schnelle Runde.',
               HR_SHORT, TOP_RENTAL, laps=2, timeLimit=240),
         ptest('L5-09', 'Eigener Rennwagen', 'Eine Runde Außenkurs mit deinem eigenen Auto.', 'Schäden bleiben!',
               ATT_OUTSIDE, {'rental': False}, laps=1, timeLimit=300),
         ptest('L5-10', 'Meisterprüfung: Großer Kurs', 'Eine fehlerfreie Runde auf dem großen Kurs des Automation Test Track.',
               'Die letzte Prüfung. Ruhig atmen.', ATT_MAIN, TOP_RENTAL, laps=1, timeLimit=300),
     ]},
    {'id': 'R1', 'name': 'Rallye-Lizenz', 'short': 'R', 'color': '#a0703d', 'requires': 'L1',
     'desc': 'Lose Untergründe, Kehren und Sprünge. Öffnet Rallye & Gelände.',
     'allGoldReward': {'categories': ['rally', 'offroad']},
     'tests': [
         ptest('R1-01', 'Schotter-Runde klein', 'Eine Runde auf dem kleinen Schotterkurs.', 'Auf Schotter früher bremsen und das Auto rollen lassen.',
               ATT_DIRT, RALLY_RENTAL, laps=1, timeLimit=90),
         ptest('R1-02', 'Kehren auf Schotter', 'Die erste Hälfte des Schotterkurses mit den engen Kehren.', 'Mit dem Heck einlenken, früh Gas.',
               ATT_GRAVEL, RALLY_RENTAL, **{'from': 1, 'to': 5}, timeLimit=90),
         ptest('R1-03', 'Schotterkurs', 'Eine ganze Runde auf dem Schotterkurs.', 'Gleichmäßig bleiben.',
               ATT_GRAVEL, RALLY_RENTAL, laps=1, timeLimit=150),
         ptest('R1-04', 'Bergprüfung Teil 1', 'Der erste Teil der Alpen-Bergprüfung.', 'Bergauf trägt das Auto weniger Schwung in die Kurve.',
               ATT_ALPINE, RALLY_RENTAL, **{'from': 1, 'to': 6}, timeLimit=150),
         ptest('R1-05', 'Bergprüfung', 'Die ganze Alpen-Bergprüfung.', 'Kehren eng anfahren, sonst fehlt der Platz.',
               ATT_ALPINE, RALLY_RENTAL, timeLimit=240),
         ptest('R1-06', 'Wüstenprüfung', 'Eine Rallye-Prüfung in Johnson Valley mit deinem Auto.', 'Sand bremst. Nicht zu weit vom Weg.',
               JV_RALLY, {'rental': False}, timeLimit=360, offTrack=60),
     ]},
    {'id': 'D1', 'name': 'Drift-Lizenz', 'short': 'D', 'color': '#e05db0', 'requires': 'L1',
     'desc': 'Kontrolliert quer: Winkel, Tempo, Linie. Mit Heckantrieb.',
     'tests': [
         ptest('D1-01', 'Erster Drift', 'Fahre die kurze Driftstrecke im Fahrerzentrum.', 'Einlenken, kurz Gas, gegenlenken. Nicht drehen.',
               DT_DRIFT, DRIFT_RENTAL, timeLimit=60),
         ptest('D1-02', 'Kurvenfolge quer', 'Der erste Teil des Handling-Driftkurses.', 'Gewicht verlagern: kurz anbremsen, dann einlenken.',
               ATT_DRIFT, DRIFT_RENTAL, **{'from': 1, 'to': 14}, timeLimit=120),
         ptest('D1-03', 'Handling-Driftkurs', 'Der ganze Handling-Driftkurs.', 'Rhythmus finden.',
               ATT_DRIFT, DRIFT_RENTAL, timeLimit=240),
         ptest('D1-04', 'Hirochi Drift', 'Der Driftkurs auf Hirochi Raceway.', 'Schnelle Übergänge von links nach rechts.',
               HR_DRIFT, DRIFT_RENTAL, timeLimit=200),
         ptest('D1-05', 'Eigenes Driftauto', 'Der Handling-Driftkurs mit deinem eigenen Auto.', 'Dein Auto, deine Schäden.',
               ATT_DRIFT, {'rental': False}, timeLimit=300),
     ]},
]
for lic in licenses:
    for t in lic['tests']:
        t['licenseId'] = lic['id']
write('licenses', licenses)

# ---------------------------------------------------------------------------
# Fahrschule = Streckenkunde (like a circuit experience): every circuit sector
# by sector, then the whole lap. Medals are paid once; the car is chosen per
# school so everyone drives the same.
# ---------------------------------------------------------------------------
schools = [
    ('etk', 'ETK-Teststrecke', ETK_TRACK, 4, False, SPORT_RENTAL,
     ['Die Gerade und die ersten Kehren.', 'Die schnellen Wechselkurven.', 'Der kurvige Mittelteil.', 'Der Weg ins Ziel.']),
    ('hrk', 'Hirochi Kurzkurs', HR_SHORT, 3, True, FAST_RENTAL,
     ['Start-Ziel-Gerade und erste Kurve.', 'Die Linkskombination.', 'Die letzten Kurven vor der Geraden.']),
    ('att', 'Automation Kurzkurs', ATT_SHORT, 3, True, FAST_RENTAL,
     ['Die schnellen ersten Kurven.', 'Der Mittelteil.', 'Zurück zur Ziellinie.']),
    ('ita', 'Stadtkurs Italien', ITA_STREET, 3, True, SPORT_RENTAL,
     ['Durch die engen Gassen.', 'Die Kurven am Platz.', 'Die Gerade und die Schlusskurven.']),
    ('hrl', 'Hirochi Langkurs', HR_LONG, 3, True, RACE_RENTAL,
     ['Die ersten Kurven.', 'Die lange Gegengerade.', 'Die Schlussrunde.']),
]
trainings = []
for sid, sname, race, of, closed, car, texts in schools:
    for i in range(1, of + 1):
        t = ptest(f'TR-{sid}-{i}', f'Sektor {i}', texts[i - 1], 'Lerne den Abschnitt: Bremspunkte, Einlenkpunkte, Kurvenausgang.',
                  race, car, sector=i, of=of, start='rolling' if i > 1 else 'standing', speed_kmh=80, timeLimit=180)
        t.update(category=sname, school=sid, dayCost=0)
        trainings.append(t)
    t = ptest(f'TR-{sid}-lap', 'Ganze Runde' if closed else 'Ganze Strecke', 'Alle Sektoren zusammen.',
              'Jetzt zählt, was du in den Sektoren gelernt hast.', race, car, timeLimit=360, **({'laps': 1} if closed else {}))
    t.update(category=sname, school=sid, dayCost=0)
    trainings.append(t)
write('trainings', trainings)

# ---------------------------------------------------------------------------
# drivers (original fictional names)
# ---------------------------------------------------------------------------
first = {
    'de': ['Lukas', 'Jonas', 'Felix', 'Marie', 'Lena', 'Tobias', 'Sven', 'Katrin', 'Moritz', 'Jana', 'Henrik', 'Paula'],
    'jp': ['Haruto', 'Ren', 'Yui', 'Sora', 'Kaito', 'Mio', 'Takumi', 'Aoi', 'Daichi', 'Rin', 'Kenta', 'Hina'],
    'it': ['Matteo', 'Giulia', 'Lorenzo', 'Chiara', 'Davide', 'Sara', 'Paolo', 'Elena'],
    'fr': ['Hugo', 'Camille', 'Louis', 'Manon', 'Théo', 'Inès', 'Julien', 'Chloé'],
    'gb': ['Oliver', 'Amelia', 'Harry', 'Isla', 'George', 'Freya', 'Callum', 'Megan'],
    'us': ['Tyler', 'Madison', 'Cody', 'Brooke', 'Wyatt', 'Kayla', 'Dalton', 'Avery'],
    'es': ['Pablo', 'Lucía', 'Álvaro', 'Carmen', 'Diego', 'Nerea'],
    'se': ['Erik', 'Astrid', 'Nils', 'Saga', 'Oskar', 'Linnea'],
    'br': ['Rafael', 'Larissa', 'Thiago', 'Bianca'],
}
last = {
    'de': ['Brandt', 'Kessler', 'Vogt', 'Lindner', 'Hartmann', 'Seidel', 'Krämer', 'Ostermann', 'Falk', 'Reuter', 'Winter', 'Brenner'],
    'jp': ['Takeda', 'Morikawa', 'Shimizu', 'Arakawa', 'Kobayashi', 'Nakano', 'Fujiwara', 'Ishida', 'Hayashi', 'Ogawa', 'Matsuda', 'Kuroda'],
    'it': ['Ferraresi', 'Bellandi', 'Conti', 'Moretti', 'Galli', 'Rinaldi', 'Serra', 'Valli'],
    'fr': ['Lefèvre', 'Garnier', 'Rousseau', 'Morel', 'Chevalier', 'Perrin', 'Fournier', 'Leclair'],
    'gb': ['Ashford', 'Pemberton', 'Whitlock', 'Harrow', 'Coleby', 'Fairbairn', 'Marlow', 'Sutcliffe'],
    'us': ['Callahan', 'Beaumont', 'Rourke', 'Whitaker', 'Delaney', 'Hollister', 'Prescott', 'McAllister'],
    'es': ['Navarro', 'Ortega', 'Castillo', 'Romero', 'Vidal', 'Herrera'],
    'se': ['Lindqvist', 'Holmberg', 'Ekström', 'Sandberg', 'Nyström', 'Berglund'],
    'br': ['Duarte', 'Moraes', 'Teixeira', 'Campos'],
}
styles = ['smooth', 'aggressive', 'defensive', 'latebraker']
tier_plan = [('rookie', 22), ('amateur', 26), ('pro', 22), ('expert', 14), ('legend', 6)]
rng = random.Random(4242)
used = set()
drivers = []
nations = list(first.keys())
for tier, count in tier_plan:
    for i in range(count):
        for _ in range(50):
            nat = rng.choice(nations)
            name = f"{rng.choice(first[nat])} {rng.choice(last[nat])}"
            if name not in used:
                used.add(name)
                break
        base = {'rookie': 0.35, 'amateur': 0.55, 'pro': 0.75, 'expert': 0.88, 'legend': 0.96}[tier]
        d = {
            'id': f'drv_{len(drivers) + 1:03d}', 'name': name, 'nation': nat, 'tier': tier,
            'style': rng.choice(styles),
            'skill': round(min(1.0, max(0.1, base + rng.uniform(-0.06, 0.05))), 2),
            'consistency': round(min(1.0, max(0.2, base + rng.uniform(-0.12, 0.08))), 2),
            'racecraft': round(min(1.0, max(0.2, base + rng.uniform(-0.1, 0.08))), 2),
            'aggression': round(rng.uniform(0.3, 0.85), 2),
            'reaction': round(max(0.15, 0.6 - base * 0.4 + rng.uniform(-0.05, 0.08)), 2),
        }
        drivers.append(d)
write('drivers', drivers)

# ---------------------------------------------------------------------------
# events
# ---------------------------------------------------------------------------
def prizes(first_prize, n=8):
    ratios = [1, 0.62, 0.45, 0.32, 0.22, 0.15, 0.1, 0.07, 0.05, 0.04, 0.03, 0.02]
    return [int(round(first_prize * r / 50.0) * 50) for r in ratios[:n]]


events = []


def series(sid, name, hall, desc, races, eligibility=None, rec=None, tiers=None, size=7, first_prize=3000,
           championship=False, fmt='quick', start='standing', requires=None, car_reward=None, champ_money=None,
           difficulty=1, etype=None, ticket=None, **kw):
    s = {
        'id': sid, 'name': name, 'hall': hall, 'desc': desc, 'races': races,
        'eligibility': eligibility or {}, 'recommendedLI': rec, 'difficulty': difficulty,
        'field': {'size': size, 'tiers': tiers or ['rookie', 'amateur'], 'liSpread': kw.pop('spread', 35)},
        'rewards': {'positions': prizes(first_prize, size + 1)},
        'championship': championship, 'format': fmt, 'startType': start,
    }
    if etype:
        s['type'] = etype
    if requires:
        s['requires'] = requires
    if car_reward:
        if championship:
            s['rewards']['championship'] = {'money': champ_money or first_prize * 4, 'car': car_reward}
        else:
            s['rewards']['car'] = car_reward
    elif championship:
        s['rewards']['championship'] = {'money': champ_money or first_prize * 4}
    if ticket:
        s['rewards']['ticketTier'] = ticket
    if kw.get('oneMake'):
        s['field']['oneMake'] = True
        kw.pop('oneMake')
    if 'fieldCriteria' in kw:
        s['field']['criteria'] = kw.pop('fieldCriteria')
    s.update(kw)
    events.append(s)


def R(track, laps=3, name=None, **kw):
    r = {'track': track, 'laps': laps}
    if name:
        r['name'] = name
    r.update(kw)
    return r


L1, L2, L3, L4, L5 = ({'license': x} for x in ('L1', 'L2', 'L3', 'L4', 'L5'))

# --- Einsteiger
series('sonntagspokal', 'Sonntagspokal', 'einsteiger', 'Der klassische Einstieg: Alltagsautos, kurze Rennen.',
       [R(circuit(HR, WCU), 2, 'Lauf 1'), R(circuit(ITA, HR), 2, 'Lauf 2'), R(circuit(ATT, WCU), 2, 'Lauf 3')],
       {'liMax': 330, 'excludeCategories': ['gt', 'proto', 'touring']}, 300, requires=L1, first_prize=2000,
       car_reward={'categories': ['street'], 'liMax': 320})
series('clubsport_cup', 'Clubsport-Cup', 'einsteiger', 'Für Straßenwagen bis LI 400.',
       [R(circuit(HR), 3), R(circuit(WCU, ITA), 3), R(circuit(ITA), 3), R(circuit(ATT, HR), 3)],
       {'liMax': 400, 'excludeCategories': ['gt', 'proto']}, 380, requires=L1, first_prize=3500,
       car_reward={'categories': ['sport', 'street'], 'liMax': 420})
series('frontantrieb_trophy', 'Frontantriebs-Trophäe', 'einsteiger', 'Nur Fronttriebler: Untersteuern beherrschen.',
       [R(circuit(HR), 3), R(circuit(ITA), 3), R(circuit(WCU), 3)], {'drivetrains': ['FWD'], 'liMax': 450}, 380,
       requires=L1, first_prize=3000)
series('hecktriebler_pokal', 'Hecktriebler-Pokal', 'einsteiger', 'Hinterradantrieb und leichte Autos.',
       [R(circuit(HR), 3), R(circuit(WCU), 3), R(circuit(ITA), 3)], {'drivetrains': ['RWD'], 'liMax': 450}, 400,
       requires=L1, first_prize=3000)
series('leichtgewicht_cup', 'Leichtgewicht-Cup', 'einsteiger', 'Unter 1100 kg: Kurvenspeed statt PS.',
       [R(circuit(HR), 3), R(sprint(ITA), 1), R(circuit(ATT, WCU), 3)], {'weightMax': 1100, 'liMax': 460}, 380, requires=L1)
series('kompakt_sprint', 'Kompaktsprint', 'einsteiger', 'Kurze K.O.-Rennen: Wer am Rundenende Letzter ist, fliegt.',
       [R(circuit(HR), 5, 'K.O. 1'), R(circuit(WCU), 5, 'K.O. 2')], {'liMax': 380}, 340, requires=L1, etype='elimination', size=7)

# --- Amateur
series('tourenwagen_club', 'Tourenwagen-Club', 'amateur', 'Meisterschaft für getunte Straßenwagen.',
       [R(circuit(HR), 4), R(circuit(WCU), 4), R(circuit(ITA), 4), R(circuit(ATT), 4), R(circuit(ECU, HR), 4)],
       {'liMax': 520}, 500, tiers=['amateur', 'pro'], requires=L2, first_prize=6000, championship=True,
       car_reward={'categories': ['touring', 'sport'], 'liMin': 480, 'liMax': 600}, champ_money=30000, difficulty=2, fmt='choice')
series('sportwagen_festival', 'Sportwagen-Festival', 'amateur', 'Coupés und Roadster bis LI 560.',
       [R(circuit(HR), 4), R(sprint(ITA), 1), R(circuit(WCU), 4), R(circuit(ITA, HR), 4)],
       {'liMax': 560, 'categories': ['sport', 'street']}, 540, tiers=['amateur', 'pro'], requires=L2, first_prize=7000, difficulty=2)
series('allrad_challenge', 'Allrad-Challenge', 'amateur', 'Vier angetriebene Räder, jede Menge Traktion.',
       [R(circuit(HR), 4), R(circuit(WCU), 4), R(dirt(UTAH), 1)], {'drivetrains': ['AWD', '4WD'], 'liMax': 600}, 560,
       tiers=['amateur', 'pro'], requires=L2, first_prize=7000, difficulty=2)
series('saugmotor_meisterschaft', 'Saugmotor-Meisterschaft', 'amateur', 'Nur Saugmotoren - Drehzahl ist alles.',
       [R(circuit(HR), 4), R(circuit(ITA), 4), R(circuit(WCU), 4)], {'aspiration': 'NA', 'liMax': 560}, 520,
       tiers=['amateur', 'pro'], requires=L2, first_prize=6500, difficulty=2)
series('turbo_trophy', 'Turbo-Trophäe', 'amateur', 'Ladedruck erwünscht.', [R(circuit(WCU), 4), R(circuit(HR), 4), R(circuit(ITA), 4)],
       {'aspiration': 'Turbo', 'liMax': 580}, 540, tiers=['amateur', 'pro'], requires=L2, first_prize=6500, difficulty=2)
series('verfolgungsjagd', 'Verfolgungsjagd', 'amateur', 'Die Gegner starten mit Vorsprung. Hol sie alle ein!',
       [R(circuit(HR), 3, 'Jagd 1'), R(circuit(WCU), 3, 'Jagd 2'), R(circuit(ITA), 3, 'Jagd 3')], {'liMax': 520}, 500,
       tiers=['amateur', 'pro'], requires=L2, etype='pursuit', gap=3, first_prize=6000, difficulty=2)

# --- Profi
series('gt_nationals', 'GT-Nationals', 'profi', 'Nationale GT-Meisterschaft mit Rennwochenende.',
       [R(circuit(HR), 6), R(circuit(WCU), 6), R(circuit(ITA), 6), R(circuit(ATT), 6), R(circuit(ECU, HR), 6), R(circuit(JRI, WCU), 6)],
       {'liMax': 680}, 650, tiers=['pro', 'expert'], requires=L3, first_prize=15000, championship=True, fmt='weekend',
       start='rolling', car_reward={'categories': ['gt', 'touring'], 'liMin': 620, 'liMax': 720}, champ_money=120000, difficulty=3, ticket=3)
series('supersport_serie', 'Supersport-Serie', 'profi', 'Die schnellsten Straßenwagen der Welt.',
       [R(circuit(HR), 5), R(circuit(WCU), 5), R(sprint(ITA), 1), R(circuit(ITA), 5)], {'categories': ['sport'], 'liMin': 560, 'liMax': 760},
       700, tiers=['pro', 'expert'], requires=L3, first_prize=18000, difficulty=3, fmt='choice', ticket=3)
series('tourenwagen_international', 'Tourenwagen International', 'profi', 'Rennumbauten auf den großen Strecken.',
       [R(circuit(HR), 6), R(circuit(ITA), 6), R(circuit(WCU), 6), R(circuit(ATT), 6)], {'categories': ['touring'], 'liMax': 720}, 660,
       tiers=['pro', 'expert'], requires=L3, first_prize=16000, championship=True, fmt='weekend', start='rolling', difficulty=3)
series('profi_ko', 'Profi-K.O.', 'profi', 'Elimination mit Sportwagen.', [R(circuit(HR), 7), R(circuit(WCU), 7)], {'liMax': 700}, 650,
       tiers=['pro', 'expert'], requires=L3, etype='elimination', size=9, first_prize=15000, difficulty=3)

# --- Extrem
series('gt_weltmeisterschaft', 'GT-Weltmeisterschaft', 'extrem', 'Die große GT-Meisterschaft. Rennwochenende Pflicht.',
       [R(circuit(HR), 10), R(circuit(ITA), 10), R(circuit(WCU), 10), R(circuit(ATT), 10), R(circuit(ECU), 10), R(circuit(JRI), 10), R(circuit(HR, ITA), 12)],
       {'liMax': 800}, 760, tiers=['expert', 'legend'], requires=L4, first_prize=40000, championship=True, fmt='weekend',
       start='rolling', car_reward={'categories': ['gt', 'proto'], 'liMin': 740}, champ_money=500000, difficulty=4, ticket=4, size=11)
series('prototypen_masters', 'Prototypen-Masters', 'extrem', 'Prototypen und Formelautos: das schnellste Feld.',
       [R(circuit(HR), 10), R(circuit(ITA), 10), R(circuit(WCU), 10), R(circuit(ATT), 10)], {'categories': ['proto', 'gt'], 'liMin': 760}, 880,
       tiers=['expert', 'legend'], requires=L5, first_prize=60000, championship=True, fmt='weekend', start='rolling',
       car_reward={'categories': ['proto'], 'liMin': 800}, champ_money=1000000, difficulty=5, ticket=5, size=11)
series('unlimited', 'Ohne Limit', 'extrem', 'Keine Regeln, keine Grenzen.', [R(circuit(HR), 8), R(circuit(WCU), 8), R(circuit(ITA), 8)], {}, 900,
       tiers=['expert', 'legend'], requires=L5, first_prize=80000, difficulty=5, ticket=5)

# --- Langstrecke (weekend + damage matters)
series('ausdauer_100', '100-km-Ausdauer', 'langstrecke', 'Eine lange Distanz: Material schonen, Schäden bleiben.',
       [R(circuit(HR, WCU), 25, '100 km')], {'liMax': 620}, 580, tiers=['amateur', 'pro'], requires=L3, first_prize=40000,
       fmt='weekend', start='rolling', difficulty=3, ticket=3, size=9)
series('ausdauer_gt', 'GT-Langstrecke', 'langstrecke', 'Langstrecke für GT-Rennwagen.', [R(circuit(ITA, HR), 30, '2 Stunden')],
       {'liMax': 780}, 740, tiers=['pro', 'expert'], requires=L4, first_prize=120000, fmt='weekend', start='rolling', difficulty=4, ticket=4, size=11)
series('ausdauer_klassik', 'Klassiker-Langstrecke', 'langstrecke', 'Vor 1990 gebaute Autos auf langer Distanz.',
       [R(circuit(HR, WCU), 20)], {'yearMax': 1990}, 450, tiers=['amateur', 'pro'], requires=L2, first_prize=30000, fmt='weekend', start='rolling', difficulty=3)

# --- Marken-Cups (one-make)
for brand, li in [('Ibishu', 420), ('Hirochi', 520), ('Gavril', 480), ('Bruckell', 500), ('ETK', 600), ('Civetta', 720),
                  ('Cherrier', 450), ('Autobello', 300), ('Soliad', 450), ('Burnside', 350)]:
    sid = 'marke_' + brand.lower()
    series(sid, f'{brand}-Markenpokal', 'marken', f'Nur Fahrzeuge von {brand}.',
           [R(circuit(HR), 3), R(circuit(WCU), 3), R(circuit(ITA), 3)], {'brands': [brand]}, li, tiers=['amateur', 'pro'],
           requires=L1, first_prize=int(li * 12), car_reward={'brands': [brand]}, oneMake=True, spread=80)

# --- Regional
series('japan_cup', 'Japan-Cup', 'regional', 'Fahrzeuge aus Japan.', [R(circuit(HR), 3), R(circuit(ITA), 3), R(circuit(WCU), 3)],
       {'regions': ['japan'], 'liMax': 560}, 480, requires=L1, first_prize=5000, car_reward={'regions': ['japan'], 'liMax': 560})
series('europa_cup', 'Europa-Cup', 'regional', 'Fahrzeuge aus Europa.', [R(circuit(ITA), 3), R(circuit(HR), 3), R(circuit(WCU), 3)],
       {'regions': ['europe'], 'liMax': 600}, 520, requires=L1, first_prize=5500, car_reward={'regions': ['europe'], 'liMax': 600})
series('amerika_cup', 'Amerika-Cup', 'regional', 'Big-Block und Pick-ups: Amerika.', [R(circuit(WCU), 3), R(circuit(HR), 3), R(circuit(ECU, WCU), 3)],
       {'regions': ['america'], 'liMax': 600}, 520, requires=L1, first_prize=5500, car_reward={'regions': ['america'], 'liMax': 600})
series('achtziger', '80er-Jahre-Pokal', 'regional', 'Baujahr 1980 bis 1989.', [R(circuit(HR), 3), R(circuit(WCU), 3), R(sprint(ITA), 1)],
       {'yearMin': 1980, 'yearMax': 1989}, 380, requires=L1, first_prize=4000)
series('neunziger', '90er-Jahre-Pokal', 'regional', 'Baujahr 1990 bis 1999.', [R(circuit(HR), 3), R(circuit(ITA), 3), R(circuit(WCU), 3)],
       {'yearMin': 1990, 'yearMax': 1999}, 450, requires=L1, first_prize=4500)

# --- Rallye & Gelände
series('schotter_cup', 'Schotter-Cup', 'gelaende', 'Rallye-Prüfungen gegen die Uhr.', [R(dirt(UTAH), 1, 'WP 1'), R(dirt(JV), 1, 'WP 2'), R(dirt(UTAH, ITA), 1, 'WP 3')],
       {'excludeCategories': ['proto', 'gt', 'truck']}, 450, requires={'license': 'R1'}, etype='timeAttack', runs=2, first_prize=6000)
series('rallye_meisterschaft', 'Rallye-Meisterschaft', 'gelaende', 'Mehrere Prüfungen, Gesamtwertung.',
       [R(dirt(UTAH), 1), R(dirt(JV), 1), R(dirt(ITA), 1), R(dirt(UTAH, JV), 1)], {'categories': ['rally', 'offroad', 'street', 'sport']}, 560,
       tiers=['pro', 'expert'], requires={'license': 'R1'}, etype='timeAttack', runs=1, championship=True, first_prize=12000, difficulty=3,
       car_reward={'categories': ['rally']})
series('gelaende_trophy', 'Gelände-Trophäe', 'gelaende', 'Offroader auf Rundkursen im Dreck.', [R(dirt(JV, UTAH), 3), R(dirt(UTAH), 3)],
       {'categories': ['offroad', 'truck']}, 350, requires={'license': 'R1'}, first_prize=5000)
series('crawl_meister', 'Crawler-Meisterschaft', 'gelaende', 'Langsam, präzise, über Felsen. Strafsekunden für ausgelassene Tore.',
       [R(None, 1, 'Parcours 1', course=slalom(6, 14, 3.0, start=15, w=4) + [gate(0, 110, 5)], venue='crawlpark', parTime=150, timeLimit=600),
        R(None, 1, 'Parcours 2', course=hairpin_right(40, 10) + slalom(4, 12, 2.5, start=-80, w=4), venue='crawlpark', parTime=200, timeLimit=600)],
       {'categories': ['offroad', 'truck']}, 300, requires={'license': 'R1'}, etype='crawl', first_prize=5000, size=7)
series('truck_auftraege', 'Transport-Aufträge', 'gelaende', 'Liefere pünktlich und ohne Ladungsschaden.',
       [R(sprint(WCU, ECU), 1, 'Hafen-Lieferung', budget=3000), R(sprint(UTAH, ITA), 1, 'Bergstraße', budget=2500), R(sprint(JV, WCU), 1, 'Wüstenfahrt', budget=3500)],
       {'categories': ['truck']}, 250, requires=L1, etype='trucking', first_prize=6000, size=1)

# --- Spezial: drift, drag, derby, touge, time attack, hillclimb
series('drift_einsteiger', 'Drift-Einsteiger', 'spezial', 'Punkte für Winkel und Tempo.', [R(circuit(IND, HR), 2, timeLimit=180), R(circuit(WCU, HR), 2, timeLimit=180)],
       {'drivetrains': ['RWD']}, 450, requires={'license': 'D1'}, etype='drift', parScore=18000, first_prize=5000)
series('drift_masters', 'Drift-Masters', 'spezial', 'Die Drift-Elite.', [R(circuit(IND, HR), 3, timeLimit=240), R(circuit(ITA, WCU), 3, timeLimit=240), R(sprint(ITA), 1, timeLimit=240)],
       {'drivetrains': ['RWD'], 'liMin': 450}, 600, tiers=['pro', 'expert'], requires={'license': 'D1'}, etype='drift', parScore=40000, first_prize=15000, difficulty=3)
series('drag_strasse', 'Straßen-Drag', 'spezial', 'Viertelmeile mit Straßenautos: Qualifying, dann K.O.-Leiter.',
       [R(None, 1, 'Drag-Wochenende', level=WCU, distance=402.34)], {'excludeCategories': ['gt', 'proto', 'touring'], 'liMax': 520}, 450,
       requires=L1, etype='drag', tree='sportsman', qualifyingRuns=2, first_prize=6000)
series('drag_bracket', 'Bracket-Drag', 'spezial', 'Dial-in-Rennen: Konstanz schlägt Leistung. Zu schnell = verloren.',
       [R(None, 1, 'Bracket-Wochenende', level=WCU, distance=201.17)], {}, 500, requires=L1, etype='drag', tree='sportsman', bracket=True,
       qualifyingRuns=3, first_prize=8000)
series('drag_pro', 'Pro-Drag', 'spezial', 'Pro-Tree und volle Viertelmeile für Umbauten.', [R(None, 1, 'Pro-Wochenende', level=WCU, distance=402.34)],
       {'liMin': 550}, 700, tiers=['pro', 'expert'], requires=L3, etype='drag', tree='pro', qualifyingRuns=3, first_prize=25000, difficulty=3)
series('derby_einsteiger', 'Blechschaden-Derby', 'spezial', 'Destruction Derby: wer zuletzt noch fährt, gewinnt.', [R(None, 1, 'Arena', venue='derby_arena', timeLimit=300)],
       {'excludeCategories': ['proto', 'gt']}, 300, requires=L1, etype='derby', size=9, first_prize=4000)
series('derby_gross', 'Großes Derby', 'spezial', 'Mehr Autos, größere Arena, mehr Chaos.', [R(None, 1, 'Große Arena', venue='derby_gross', timeLimit=420)],
       {}, 400, requires=L2, etype='derby', size=13, first_prize=9000)
series('touge_battle', 'Touge-Duelle', 'spezial', 'Eins gegen eins am Berg: erst jagen, dann führen.',
       [R(sprint(ITA, UTAH), 1, 'Duell 1'), R(sprint(ITA, WCU), 1, 'Duell 2'), R(sprint(UTAH, ITA), 1, 'Duell 3')], {'liMax': 600}, 520,
       tiers=['pro', 'expert'], requires=L2, etype='touge', first_prize=8000, size=1, difficulty=3)
series('time_attack', 'Time Attack', 'spezial', 'Eine schnelle Runde zählt.', [R(circuit(HR), 3, 'Attacke 1'), R(circuit(WCU), 3, 'Attacke 2'), R(circuit(ITA), 3, 'Attacke 3')],
       {}, 600, tiers=['pro', 'expert'], requires=L2, etype='timeAttack', runs=1, first_prize=10000, difficulty=2, timeLimit=600)
series('hillclimb', 'Bergrennen', 'spezial', 'Zwei Läufe bergauf, der bessere zählt.', [R(sprint(ITA, UTAH), 1, 'Bergwertung 1'), R(sprint(UTAH, ITA), 1, 'Bergwertung 2')],
       {}, 550, tiers=['amateur', 'pro'], requires=L2, etype='timeAttack', runs=2, first_prize=9000, difficulty=2)
series('klassiker_parade', 'Klassiker-Rennen', 'spezial', 'Baujahr vor 1975.', [R(circuit(HR), 3), R(circuit(WCU), 3)], {'yearMax': 1975}, 330,
       requires=L1, first_prize=4000)

write('events', events)

# ---------------------------------------------------------------------------
# café booklets (guided progression)
# ---------------------------------------------------------------------------
def own(label, criteria, count=1, hint=None):
    s = {'type': 'own', 'label': label, 'criteria': criteria, 'count': count}
    if hint:
        s['hint'] = hint
    return s


def trophy(label, sid, pos=3, all_races=False):
    return {'type': 'trophy', 'label': label, 'series': sid, 'position': pos, 'allRaces': all_races}


def lic(label, lid):
    return {'type': 'license', 'label': label, 'license': lid}


cafe = []


def book(bid, name, chapter, intro, outro, steps, reward=None, unlocks=None, unlock_names=None, after=None):
    b = {'id': bid, 'name': name, 'chapter': chapter, 'intro': intro, 'outro': outro, 'steps': steps,
         'reward': reward or {}, 'unlocks': unlocks or [], 'unlockNames': unlock_names or []}
    if after:
        b['after'] = after
    cafe.append(b)


book('h01', 'Das erste eigene Auto', 1,
     'Willkommen im Boxenstopp-Café! Jeder Fahrer fängt klein an. Such dir beim Gebrauchtwagenhändler etwas Günstiges aus.',
     'Das ist der Anfang einer langen Freundschaft. Ein Auto, das man selbst gekauft hat, fährt man ganz anders.',
     [own('Kaufe ein Fahrzeug', {}, 1, 'Gebrauchtwagenmarkt im Hauptmenü')], {'money': 2000},
     ['license_L1'], ['Lizenzzentrum (Lizenz C)'])
book('h02', 'Die Lizenz C', 1, 'Ohne Lizenz kein Rennen. Zeig im Lizenzzentrum, dass du ein Auto beherrschst.',
     'Glückwunsch! Mit der C-Lizenz stehen dir die ersten Pokale offen.', [lic('Erwirb die Lizenz C', 'L1')],
     {'money': 3000}, ['hall_einsteiger', 'services'], ['Einsteiger-Liga', 'Werkstatt'])
book('h03', 'Sonntagsausflug', 1, 'Der Sonntagspokal ist das Rennen der Leute. Fahr mit und hol dir einen Podestplatz.',
     'Die ersten Pokale im Regal! Siehst du, wie viel Spaß Rennen machen können?',
     [trophy('Podium im Sonntagspokal (beliebiges Rennen)', 'sonntagspokal', 3)], {'car': {'categories': ['street'], 'liMax': 330}},
     ['dealer_new'], ['Neuwagen-Zentrum'])
book('h04', 'Japanische Kompakte', 1, 'Kleine, leichte Autos aus Japan haben die Clubsport-Szene geprägt. Sammle drei davon.',
     'Leicht, drehfreudig, zuverlässig: Kein Wunder, dass diese Autos auf jedem Clubsport-Parkplatz stehen.',
     [own('Besitze 3 Fahrzeuge aus Japan mit LI unter 420', {'regions': ['japan'], 'liMax': 420}, 3)],
     {'ticket': 2}, ['hall_regional'], ['Regional-Cups'])
book('h05', 'Front gegen Heck', 1, 'Frontantrieb zieht, Hinterradantrieb schiebt. Fahre beide Trophäen.',
     'Jetzt kennst du beide Welten. Welche magst du lieber?',
     [trophy('Podium in der Frontantriebs-Trophäe', 'frontantrieb_trophy'), trophy('Podium im Hecktriebler-Pokal', 'hecktriebler_pokal')],
     {'money': 8000}, ['tuning'], ['Tuning (Umbau-Stufen)'])
book('h06', 'Clubsport', 2, 'Der Clubsport-Cup ist die Schule der Rennfahrer.',
     'Du fährst jetzt wie ein echter Clubsportler. Zeit für die nächste Lizenz.',
     [trophy('Podium in allen Läufen des Clubsport-Cups', 'clubsport_cup', 3, True)], {'car': {'categories': ['sport'], 'liMax': 460}},
     ['license_L2', 'license_R1', 'license_D1'], ['Lizenz B', 'Rallye-Lizenz', 'Drift-Lizenz'])
book('h07', 'Die Lizenz B', 2, 'Höhere Geschwindigkeiten brauchen mehr Können.', 'Mit der B-Lizenz geht es in die Amateur-Liga.',
     [lic('Erwirb die Lizenz B', 'L2')], {'money': 10000}, ['hall_amateur', 'hall_marken'], ['Amateur-Liga', 'Marken-Cups'])
book('h08', 'Europäische Klassiker', 2, 'Europa hat einige der schönsten Autos hervorgebracht. Sammle drei.',
     'Design, Handwerk, Geschichte: Diese Autos erzählen etwas über ihre Herkunft.',
     [own('Besitze 3 Fahrzeuge aus Europa', {'regions': ['europe']}, 3)], {'ticket': 2})
book('h09', 'Amerikanische Muskeln', 2, 'Viel Hubraum, viel Drehmoment. Sammle drei amerikanische Autos.',
     'Ein V8 klingt nach Freiheit. Und auf der Geraden ist er kaum zu schlagen.',
     [own('Besitze 3 Fahrzeuge aus Amerika', {'regions': ['america']}, 3)], {'money': 15000})
book('h10', 'Schotter und Staub', 2, 'Rallye ist die härteste Schule. Hol dir die Rallye-Lizenz und einen Pokal.',
     'Wer auf Schotter schnell ist, ist überall schnell.',
     [lic('Erwirb die Rallye-Lizenz', 'R1'), trophy('Podium im Schotter-Cup', 'schotter_cup')],
     {'car': {'categories': ['rally', 'offroad']}}, ['hall_gelaende'], ['Rallye & Gelände'])
book('h11', 'Quer ist mehr', 2, 'Drift ist Kunst. Hol dir die Drift-Lizenz und zeig es den Punktrichtern.',
     'Rauch, Winkel, Gefühl. Die Zuschauer lieben dich.',
     [lic('Erwirb die Drift-Lizenz', 'D1'), trophy('Podium bei den Drift-Einsteigern', 'drift_einsteiger')],
     {'money': 15000}, ['hall_spezial'], ['Spezial-Events (Drag, Derby, Touge ...)'])
book('h12', 'Tourenwagen', 3, 'Die Tourenwagen-Club-Meisterschaft: fünf Rennen, ein Champion.',
     'Ein Meistertitel! Jetzt bist du bereit für die Profis.',
     [{'type': 'championship', 'label': 'Werde unter die ersten 3 im Tourenwagen-Club', 'series': 'tourenwagen_club'}],
     {'ticket': 3}, ['license_L3'], ['Lizenz A'])
book('h13', 'Die Lizenz A', 3, 'Die A-Lizenz trennt Amateure von Profis.', 'Willkommen in der Profi-Liga.',
     [lic('Erwirb die Lizenz A', 'L3')], {'money': 30000}, ['hall_profi', 'hall_langstrecke', 'dealer_legend'],
     ['Profi-Liga', 'Langstrecke', 'Klassiker-Galerie'])
book('h14', 'Sammlerleidenschaft', 3, 'Ein echter Sammler hat Autos aus allen Epochen.',
     'Deine Garage wird langsam zum Museum.',
     [own('Besitze ein Fahrzeug vor 1975', {'yearMax': 1975}), own('Besitze ein Fahrzeug der 80er', {'yearMin': 1980, 'yearMax': 1989}),
      own('Besitze ein Fahrzeug der 90er', {'yearMin': 1990, 'yearMax': 1999}), {'type': 'collector', 'label': 'Erreiche Sammlerstufe 5', 'level': 5}],
     {'car': {'yearMax': 1980, 'liMin': 350}})
book('h15', 'Ausdauer', 3, 'Langstrecke heißt: ankommen. Schone dein Auto und fahr die 100 km.',
     'Material schonen ist eine Kunst. Du beherrschst sie.',
     [trophy('Podium beim 100-km-Ausdauerrennen', 'ausdauer_100')], {'ticket': 3})
book('h16', 'GT-Nationals', 4, 'Die nationale GT-Meisterschaft: Rennwochenende mit Qualifying und fliegendem Start.',
     'Ein nationaler GT-Champion! Die Welt wartet.',
     [{'type': 'championship', 'label': 'Gewinne die GT-Nationals', 'series': 'gt_nationals', 'win': True}],
     {'money': 100000}, ['license_L4'], ['Lizenz I'])
book('h17', 'Die Lizenz I', 4, 'International fahren nur die Besten.', 'Die Extrem-Liga steht dir offen.',
     [lic('Erwirb die Lizenz I', 'L4')], {'ticket': 4}, ['hall_extrem'], ['Extrem-Liga'])
book('h18', 'Supersportler', 4, 'Drei Supersportwagen mit über 600 LI gehören in jede große Sammlung.',
     'Diese Autos sind Ingenieurskunst in Reinform.',
     [own('Besitze 3 Fahrzeuge mit LI über 600', {'liMin': 600}, 3)], {'money': 150000})
book('h19', 'Weltmeister', 5, 'Die GT-Weltmeisterschaft. Mehr gibt es nicht zu sagen.',
     'Du bist Weltmeister. Der Café-Besitzer stellt dein Foto an die Wand.',
     [{'type': 'championship', 'label': 'Gewinne die GT-Weltmeisterschaft', 'series': 'gt_weltmeisterschaft', 'win': True}],
     {'ticket': 5}, ['license_L5'], ['Lizenz S'])
book('h20', 'Die Lizenz S', 5, 'Die letzte Lizenz.', 'Es gibt nichts mehr, was du nicht fahren darfst.',
     [lic('Erwirb die Lizenz S', 'L5'), trophy('Podium bei den Prototypen-Masters', 'prototypen_masters')],
     {'car': {'categories': ['proto'], 'liMin': 800}, 'money': 500000})
write('cafe', cafe)

# ---------------------------------------------------------------------------
# curated track metadata (match = substring of the race file path)
# ---------------------------------------------------------------------------
tracks = [
    {'match': 'hirochi_raceway', 'tags': ['tarmac', 'circuit-main']},
    {'match': 'automation_test_track', 'tags': ['tarmac']},
    {'match': '/utah/', 'surface': 'dirt'},
    {'match': 'johnson_valley', 'surface': 'dirt'},
    {'match': 'jungle_rock_island', 'surface': 'tarmac'},
]
write('tracks', tracks)

# music playlists (files live in ui/modules/apps/TurismoHub/audio/music)
write('music', {'note': 'Playlists are defined in ui/modules/apps/TurismoHub/audio/music/playlist.json'})
print('done')
