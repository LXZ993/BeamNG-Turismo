# Installation

1. **Zip kopieren:** `turismo_karriere.zip` (nicht entpacken) nach
   `Dokumente\BeamNG.drive\0.40\mods\` – bzw. in deinen BeamNG-Userordner unter `current\mods\`
   (bei dir vermutlich `F:\BeamNG\current\mods\`).
2. **Spiel starten**, im Hauptmenü unter *Mods* prüfen, dass „turismo_karriere“ aktiv ist.
3. **Freie Fahrt** auf einer beliebigen Karte starten (z. B. West Coast USA).
4. **App ins Layout ziehen (einmalig):** `Strg+Leertaste` öffnet den UI-Editor (bzw. *Optionen → UI-Apps*).
   Die App **„Turismo Karriere“** suchen und irgendwo klein ablegen (z. B. unten rechts).
   Sie zeigt nur einen kleinen Knopf „TURISMO ▸ Menü“ – das eigentliche Menü legt sich über den ganzen Bildschirm.
5. **Tasten belegen:** *Optionen → Steuerung → Gameplay*:
   - `Turismo: Hauptmenü öffnen/schließen` (Vorschlag: **F6**)
   - `Turismo: Rennmenü (Neustart/Aufgeben)` (Vorschlag: **F7**)
   - `Turismo: Intro überspringen` (Vorschlag: **Leertaste** oder **F8**)
   - `Turismo: Notfall-Menü (IMGUI)` (Vorschlag: **F9**) – falls die Oberfläche einmal nicht erscheint
   - `Turismo: Streckenrekorder – Checkpoint setzen` (optional)
6. Menü öffnen → **Neue Karriere** → Café-Heft 1 führt dich zum ersten Gebrauchtwagen.

## Wenn etwas nicht erscheint
- Konsole öffnen (`~`) und eingeben: `extensions.turismo_core.toggleHub()` – öffnet das Menü direkt.
- Notfall-Menü: `extensions.turismo_imguiHub.toggle()`
- Log: `Dokumente\BeamNG.drive\0.40\beamng.log`, nach `turismo` suchen.
- Diagnose-Seite im Menü zeigt, wie viele Autos/Strecken gefunden wurden und welche Serien keine Strecke haben.

## Spielstände
`settings\turismo\profile_<1-3>.json` (plus `.bak` als Sicherung des vorherigen Stands). Eigene Strecken aus dem Rekorder: `settings\turismo\tracks\`.

## Eigene Inhalte
Zusätzliche JSON-Dateien `data/turismo/events_<name>.json`, `cafe_<name>.json`, `drivers_<name>.json` usw. werden automatisch mit den Grunddaten zusammengeführt (gleiche `id` = ersetzen). Eigene Musik: Datei nach `ui/modules/apps/TurismoHub/audio/music/` und in `playlist.json` eintragen.
