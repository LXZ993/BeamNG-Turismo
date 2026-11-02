# Changelog Turismo Karriere

## 0.1.4 (Stand 02.11.2026)

### Neu: Echte Musik und Credits-Menü
- Die selbst erzeugte Musik ist raus. Jetzt laufen 18 echte Stücke von Kevin MacLeod (incompetech.com): Lounge und Bossa im Menü und Café, Funk beim Händler, Rock und Electro im Rennen, Jazz bei der Siegerehrung.
- Die Lautstärke der Stücke ist angeglichen, Rennmusik ist etwas kräftiger als Menümusik. Die Lautstärke stellst du wie bisher in den Einstellungen ein.
- Beim Start jedes Stücks erscheint oben kurz Titel und Künstler.
- Neu: **Credits** im Titelbildschirm und in den Einstellungen. Dort stehen alle Songs mit Künstler, Lizenz und Lizenzhinweis. Mit ▶ hörst du ein Stück an, ■ stoppt es wieder.
- Die Musik liegt als eigener Ordner `mods\unpacked\turismo_musik`. Die Mod selbst liegt entpackt in `mods\unpacked\turismo_karriere`.

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
