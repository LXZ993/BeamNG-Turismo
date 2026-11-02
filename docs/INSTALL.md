# Installation

1. **Zip kopieren:** `turismo_karriere.zip` (nicht entpacken) nach
   `Dokumente\BeamNG.drive\0.40\mods\` – bzw. in deinen BeamNG-Userordner unter `current\mods\`
   (bei dir vermutlich `F:\BeamNG\current\mods\`).
2. **Spiel starten**, im Hauptmenü unter *Mods* prüfen, dass „turismo_karriere“ aktiv ist.
3. **Karriere starten:** im Hauptmenü oben auf das Banner **„TURISMO KARRIERE ▸“** klicken
   oder unter **Mehr** den Eintrag **„Turismo Karriere“** wählen.
4. Spielstand wählen oder **Neue Karriere** anlegen – die Heimatkarte (West Coast USA) lädt,
   danach öffnet sich das World-Menü. Café-Heft 1 führt dich zum ersten Gebrauchtwagen.
5. **Zurück ins Menü während der Fahrt:** `Esc` → Reiter **Mods** → **Turismo-Menü**.
   Optional eine eigene Taste unter *Optionen → Steuerung → Gameplay*:
   - `Turismo: Hauptmenü öffnen/schließen` (Vorschlag: **F6**)
   - `Turismo: Rennmenü (Neustart/Aufgeben)` (Vorschlag: **F7**)
   - `Turismo: Intro überspringen` (Vorschlag: **Leertaste** oder **F8**)
   - `Turismo: Notfall-Menü (IMGUI)` (Vorschlag: **F9**)

Die UI-App „Turismo Karriere“ muss in 0.40 nicht mehr ins Layout gezogen werden.

## Wenn etwas nicht erscheint
- Konsole öffnen (`~`) und eingeben: `extensions.turismo_core.toggleHub()` – öffnet das Menü direkt.
- Notfall-Menü: `extensions.turismo_imguiHub.toggle()`
- Log: `Dokumente\BeamNG.drive\0.40\beamng.log`, nach `turismo` suchen.
- Diagnose-Seite im Menü zeigt, wie viele Autos/Strecken gefunden wurden und welche Serien keine Strecke haben.

## Spielstände
`settings\turismo\profile_<1-3>.json` (plus `.bak` als Sicherung des vorherigen Stands). Eigene Strecken aus dem Rekorder: `settings\turismo\tracks\`.

## Eigene Inhalte
Zusätzliche JSON-Dateien `data/turismo/events_<name>.json`, `cafe_<name>.json`, `drivers_<name>.json` usw. werden automatisch mit den Grunddaten zusammengeführt (gleiche `id` = ersetzen). Eigene Musik: Datei nach `ui/modules/apps/TurismoHub/audio/music/` und in `playlist.json` eintragen.
