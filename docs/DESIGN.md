# Design – wie Turismo funktioniert

## Grundsätze
- **Original statt Kopie:** eigene Namen (Turismo, Boxenstopp-Café, Leistungsindex), eigene Texte, Grafiken und Sounds; Musik von Kevin MacLeod (CC BY 4.0, Namensnennung im Spiel). Die Struktur folgt bewährten Genre-Mustern (Lizenzen, Hallen, Menühefte), nicht einem bestimmten Spiel.
- **Funktioniert mit jeder Installation:** Autos werden über Kriterien gewählt (Kategorie, LI, Antrieb, Region, Baujahr …), Strecken über Selektoren mit Ausweichlisten (`@circuit:hirochi_raceway` → `@circuit:tarmac` → beliebiger Rundkurs). Mod-Autos und -Karten werden automatisch eingebunden.
- **Robust gegen Versionsunterschiede:** jeder Aufruf in die Spiel-Engine ist abgesichert; fällt etwas aus, gibt es eine Meldung statt eines Absturzes.

## Leistungsindex (LI)
`LI = 100 + 235 · ln(1 + PS/t ÷ 60)`, zu 70/30 gemischt mit einem Beschleunigungswert (0–100), plus Zu-/Abschläge für Antrieb, Reifen-/Kategorie (GT +35, Prototyp +70, Lkw −40) und Höchstgeschwindigkeit.

| Klasse | E | D | C | B | A | S | X |
|---|---|---|---|---|---|---|---|
| LI | <300 | 300–399 | 400–499 | 500–599 | 600–699 | 700–799 | 800+ |

Beispiele (Testdaten): Autobello Piccolina 207 · Covet 1.5 320 · Sunburst 1.8 398 · SBR4 557 · ETK KC8 624 · Scintilla 755 · Bolide Race 841.
**Effektiver LI:** Motorverschleiß (bis −25), Schaden und altes Öl senken den Wert – ein heruntergerittenes Auto darf in niedrigeren Serien starten, ist aber auch langsamer.

## Karriere-Ablauf
1. Café-Heft 1: erstes Auto kaufen (Startgeld 15.000 Cr.) → Heft 2: Lizenz C → Einsteiger-Liga …
2. 20 Hefte in 4 Kapiteln schalten Hallen, Händler und Lizenzen frei und belohnen mit Geld, Losen und Autos.
3. Modus „Klassisch“: alles offen, nur Lizenzen begrenzen.
4. **Kalender:** jedes Rennen kostet einen Tag; Gebrauchtwagen wechseln alle 3 Tage, die Klassiker-Galerie alle 7.
5. **Tagesziel:** 42 km am Tag (Freie Fahrt zählt) → Bonuslos.
6. **Sammlerstufe** wächst mit dem Garagenwert und schaltet die Klassiker-Galerie frei.

## Schäden & Werkstatt
- Nach jedem Rennen/Test wird der Teilezustand des Autos ausgelesen (`getPartConditions`) und gespeichert, beim nächsten Spawn wieder eingespielt (`initPartConditions`) – das ist dasselbe Verfahren wie die offizielle Karriere. Der Reset-Knopf repariert damit nicht mehr gratis.
- Gebrauchtwagen bekommen beim ersten Einsatz einen Grundverschleiß passend zur Laufleistung.
- Werkstatt-Preise skalieren mit dem Neupreis des Autos. Motorüberholung setzt den Motor-Kilometerstand zurück (beeinflusst das Verschleißmodell des Spiels).
- Modi: *realistisch* (alles bleibt), *nur Mechanik* (Blech wird gerichtet), *aus*.

## Rennformate – wann gibt es Einführungsrunden?
| Format | Ablauf | Einsatz |
|---|---|---|
| Schnell | Kamerafahrt → stehender Start mit Ampel | Einsteiger, Amateur, Marken, Regional – kurze Spaßrennen |
| Wahl | Spieler wählt „Schnelles Rennen“ oder „Rennwochenende“ | Tourenwagen-Club, Supersport |
| Rennwochenende | Training → Qualifying (Bestzeit zählt, KI-Zeiten simuliert) → Startaufstellung → Kamerafahrt → **Einführungsrunde** → fliegender Start | GT-Nationals, Tourenwagen International, GT-Weltmeisterschaft, Prototypen, Langstrecke („authentisch“) |
| Hardcore (Einstellung) | **jedes** Rundstreckenrennen als Wochenende mit Einführungsrunde, kein Neustart, keine Aufholhilfe | für Simulations-Fans |

Einführungsrunde: Tempolimit ~80 km/h, Überholen verboten, Grün wenn der Führende 150 m vor der Linie ist. Sprints/Bergrennen haben keine Einführungsrunde.

## KI
Jeder Fahrer hat eine **Stufe** (Rookie, Amateur, Profi, Experte, Legende → Können, Konstanz, Zweikampf, Reaktion) und einen **Stil** (sauber, aggressiv, defensiv, Spätbremser). Daraus entstehen die Parameter für BeamNGs Renn-KI (Aggression, Kurvenradius-Nutzung, Abstand zum Rand, Vorausschau). Ein Direktor passt 4× pro Sekunde an:
- **Konstanz:** leichte Tempo-Schwankung je nach Fahrer
- **Patzer:** zu spät gebremst, kurz gelupft – häufiger bei Rookies und aggressiven Fahrern, seltener auf „Profi“
- **Angriff/Verteidigung:** mehr Aggression knapp hinter/vor einem Gegner
- **Blaue Flagge:** Überrundete machen Platz
- **Schaden:** beschädigte Autos fahren vorsichtiger; **Ermüdung** in langen Rennen
- **Bergung:** festgefahrene Autos werden zurückgesetzt
- **Aufholhilfe** (optional, nie im Wochenende/Hardcore)

Die Rundenzeit-Erwartung pro Strecke lernt sich selbst: nach jedem Rennen wird der Streckenfaktor aus echten Zeiten nachjustiert.

## Lizenztests
Kurse werden relativ zu einem Anker auf der Testkarte erzeugt (Tore, Stoppzonen, Mindesttempo). Zielzeiten werden aus einer Fahrphysik-Schätzung (Leistung, Gewicht, Haftung, Kurvenradien) berechnet; eine **Vorführung** durch die KI kalibriert sie auf die echte Strecke. Rundentests nutzen echte Rennstrecken.

## Drag
Viertelmeile (oder Achtel) auf den Dragstrips der Karten bzw. einer erzeugten Bahn. Wochenende: 2 Qualifying-Läufe → 8er-Leiter (1 gegen 8) → Viertelfinale bis Finale. Sportsman-Baum (Ampeln nacheinander) oder Pro-Baum (alle gleichzeitig), Bracket-Rennen mit Dial-In und Breakout-Regel. Zwischenzeiten 60 ft / 330 ft / 1/8 / 1000 ft / 1/4, Endgeschwindigkeit, Rotlicht. Die Gegner-KI im Fahrzeug startet mit Traktionskontrolle und eigener Reaktionszeit.

## Daten
Alle Inhalte liegen als JSON in `data/turismo/` und werden von `tools/gen_data.py` erzeugt – Änderungen am besten dort vornehmen.
