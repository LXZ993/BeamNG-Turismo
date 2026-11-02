# Changelog Turismo Karriere

## 0.1.4 (Stand 02.11.2026)

### Neu: Fahr-HUD im GT-Stil
- Unten rechts ein Drehzahlband mit roter Zone. Im roten Bereich blinken Band und Gang: jetzt schalten.
- Großer Gang und Geschwindigkeit direkt über dem Drehzahlband.
- Minikarte unten links: die Strecke mit allen Autos, du bist der blaue Punkt, die Ziellinie das weiße Quadrat.
- Oben in der Mitte der Abstand zu deiner besten Runde, live: grün = schneller, rot = langsamer. Erscheint ab der zweiten Runde.
- Die Rangliste oben rechts zeigt nur noch 5 Fahrer um dich herum.

### Neu: World-Menü als Stadtkarte
- Statt der bunten Kacheln zeigt das World-Menü jetzt eine Stadtkarte von schräg oben. Tagsüber hell, abends ab 19 Uhr und nachts dunkel mit leuchtenden Straßen (nach der Uhrzeit deines PCs).
- Die Orte stehen als Punkte mit Namen auf der Karte: Café, Rennen, Lizenzzentrum, Fahrschule, Neuwagen, Gebrauchtwagen, Klassiker-Galerie, Garage, Werkstatt und Freie Fahrt. Anklicken öffnet den Ort.
- Fährst du mit der Maus über einen Ort, steht unten kurz, was es dort gibt. Mit den Pfeiltasten springst du von Ort zu Ort, Enter öffnet ihn.
- Gesperrte Orte sind grau mit Schloss. Unten steht, wie du sie freischaltest.
- Hilfe, Bonuslose, Einstellungen, Changelog und Diagnose liegen als kleine Knöpfe am rechten Rand.
- Die Leiste oben ist schmaler und dunkler.
- Bei Platz 1 bis 3 steht in der Siegerehrung ein Pokal in Gold, Silber oder Bronze.

### Neu: Händler, Rennen, Garage und Café im GT-Stil
- Gebrauchtwagen, Neuwagen und Klassiker-Galerie zeigen die Autos als helle Karten mit Bild, Marke, Name, Kilometern und Preis. Ein Klick öffnet ein Fenster mit allen Daten und dem Kaufen-Knopf. Dort steht auch, warum du ein Auto gerade nicht kaufen kannst (Lizenz fehlt, Geld fehlt).
- Bei den Neuwagen sind die Marken helle Karten statt Kacheln.
- Rennen: Die Rennklassen stehen als hohe Karten nebeneinander, mit Serien, offenen und gewonnenen Serien. In einer Klasse ist jeder Lauf eine eigene Karte mit Strecke, Runden, bestem Ergebnis (Pokal) und Start-Knopf.
- Garage: links groß das gewählte Auto mit Zustand, Motor, Kilometern und Wert, rechts die Liste aller Autos. Ein Klick auf eine Spaltenüberschrift sortiert die Liste.
- Café: Das aktuelle Heft liegt aufgeschlagen auf einer hellen Tafel, daneben alle Hefte als kleine Hefte. Erledigte tragen einen Stempel.

### Fehler behoben
- Beim Laden eines Spielstands blitzte das World-Menü kurz auf, dann kam der Ladebildschirm, dann wieder das Menü. Jetzt erscheint ein eigener Turismo-Ladebildschirm und das Menü erst, wenn die Karte geladen ist.
- Die Minikarte (von BeamNG oder einer anderen Mod) lag über dem Turismo-Menü. Sie ist jetzt ausgeblendet, solange das Menü offen ist, und kommt beim Fahren zurück.

### Neu: Changelog und Fehlerbericht im Menü
- In den **Einstellungen** gibt es jetzt **Changelog**: Dort steht, was sich in jeder Version geändert hat.
- **Fehlerbericht erstellen** gibt es jetzt in den Einstellungen und auf dem Startbildschirm. Du kannst kurz dazuschreiben, was passiert ist. Danach steht dort, wo die Datei liegt.

## 0.1.3 (Stand 02.11.2026)

### Neu: Fehlerbericht und eigenes Log
- Die Mod schreibt jetzt ein eigenes Log: `settings\turismo\logs\turismo.log` im BeamNG-Userordner. Darin stehen nur die Meldungen von Turismo, mit Uhrzeit, gut lesbar.
- Bei jedem Start steht oben, welche Mod-Version, welche BeamNG-Version und welche anderen Mods aktiv sind. Danach prüft die Mod ihre Daten und meldet kaputte Dateien sofort.
- Jeder Klick im Turismo-Menü und jeder Fehler wird festgehalten, Fehler mit genauer Stelle und dem Spielzustand in diesem Moment. Das Spiel läuft danach weiter.
- Das Log wird nie riesig: höchstens 4 Dateien zu je 512 KB.
- Neu: **Fehlerbericht erstellen**. Das geht über die Taste „Turismo: Fehlerbericht erstellen“ (in den Optionen unter Steuerung belegen) oder im Notfall-Menü. Es entsteht `bugreport.txt` mit Log und Spielstand. Diese eine Datei schickst du, wenn etwas schiefgeht.
- Neu: Handbuch `docs/handbuch.html`. Dort steht, wo du was findest und wie du Serien, Lizenzen, Café-Hefte, Fahrer und Preise selbst änderst.

### Erster Test am PC
- Das Namensfeld beim neuen Spielstand nimmt jetzt Tastatureingaben an.
- Die Gegnerstärke stellt sich automatisch nach deinen Ergebnissen ein. Es gibt dafür keine Einstellung mehr. Anfänger bekommen am Anfang eine leichte Aufholhilfe, die mit der Zeit verschwindet.
- Das World-Menü erklärt jeden Bereich. Beim ersten Besuch gibt es eine kurze Einführung, später findest du sie unter „So funktioniert's“.
- Lizenztests: Das BeamNG-Menü schließt sich beim Start, die Pfosten sind größer und beschriftet, eine gelbe Linie zeigt den Weg und oben steht das nächste Ziel mit Entfernung. Vor dem Start gibt es eine kurze Einweisung.
- Das Banner im Hauptmenü ist weg, es hat im Pausenmenü den Knopf „Back“ verdeckt.

## 0.1.2 (Stand 02.11.2026)

### Neu: Eigener Spielmodus im Hauptmenü
- Turismo Karriere steht jetzt im BeamNG-Hauptmenü unter **Mehr**. Du startest die Karriere wie einen eigenen Spielmodus, nicht mehr aus dem Freeroam.
- Spielstand laden oder neu anlegen lädt die Heimatkarte und öffnet das World-Menü.
- Während der Fahrt: Esc, dann **Mods**, dann **Turismo-Menü**.
- Die Oberfläche lädt von selbst. Du musst keine App mehr ins UI-Layout ziehen.

## 0.1.1 (Stand 02.11.2026)

### Fehler behoben
- Angepasst an BeamNG.drive 0.40.4.
- Bergungspunkte einer Strecke landen nicht mehr in der Startaufstellung.
- Gegner springen beim Start nicht mehr zum ersten Wegpunkt.
- Dragstrips im neuen Format von 0.40 werden erkannt, das alte Format geht weiter.
- Die BeamNG-Rundenzeiten-App wird während Turismo-Rennen ausgeblendet, damit sie das eigene HUD nicht überdeckt.

## 0.1.0 (Stand 01.11.2026)

### Erste Version
- Karriere mit 3 Spielständen, Fortschritt über 20 Café-Hefte oder „Klassisch“ mit allem offen, Schadensmodus und Hardcore-Modus.
- Lizenzen C, B, A, I, S, Rallye und Drift mit 50 Tests, Gold, Silber und Bronze. 10 freiwillige Trainings in der Fahrschule.
- 53 Rennserien in 9 Hallen: Rundstrecke, K.O.-Rennen, Verfolgung, Zeitfahren, Bergrennen, Touge, Drift, Destruction Derby, Transport, Crawling und Drag-Wochenenden.
- Schnelles Rennen oder Rennwochenende mit Training, Qualifying, Kamerafahrt, Einführungsrunde und fliegendem Start.
- Leistungsindex (LI) und Klassen E bis X für alle Autos deiner Installation, auch Mod-Autos.
- Händler für Neuwagen, Gebrauchtwagen und Klassiker. Werkstatt mit Wäsche, Ölwechsel, Reparatur, Motorüberholung und Umbau.
- Schäden bleiben: Der Zustand der Teile wird gespeichert und nichts repariert sich von selbst.
- 90 KI-Fahrer mit eigener Stufe und eigenem Fahrstil.
- World-Menü, eigenes Renn-HUD, Startampel, Drag-Baum, Ergebnis-Screens und ein Notfall-Menü.
