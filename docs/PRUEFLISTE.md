# Prüfliste für BeamNG 0.40 (morgen am PC)

Offline ist alles getestet, was ohne Spiel testbar ist (46 automatische Prüfungen, UI im Browser gerendert). Ungeprüft ist, ob die Engine-Schnittstellen in 0.40 noch genauso heißen wie in den Spielquellen, gegen die ich entwickelt habe. Diese Punkte gehe ich mit Zugriff auf `F:\BeamNG\current` der Reihe nach durch – zuerst am Spielordner (Lua-Quellen vergleichen), dann im Spiel.

## A. Vorab im Spielordner (ohne Spielstart)
- [ ] `lua/ge/extensions/gameplay/race/path.lua` und `race.lua`: Konstruktor, `onDeserialized`, `autoConfig`, `getAiPath`, `startPositions`, `moveResetVehicleTo(id, lowPrecision, repair)`
- [ ] `core_vehicleBridge.requestValue/executeAction` mit `getPartConditions` / `initPartConditions(conds, odometer, integrity, visual)`
- [ ] `core_vehicles.getConfigList()` – Feldnamen (`Power`, `Weight`, `0-100 km/h`, `Drivetrain`, `Value`, `Years` …)
- [ ] `freeroam_freeroam.startFreeroam`, `core_levels.getLevelByName`, Hook `onWorldReadyState`
- [ ] `core_paths.playPath` (Kamerafahrt), `commands.setGameCamera`, `simTimeAuthority.pause`
- [ ] KI: `ai.driveUsingPath{wpTargetList, noOfLaps, aggression …}`, `ai.setParameters`, `ai.setRacing`
- [ ] Dragstrip-Dateien `levels/*/dragstrips/*.dragData.json` (Lane-Struktur)
- [ ] Welche `*.race.json` gibt es in 0.40 (Hirochi Raceway, Automation Test Track, West Coast …)?
- [ ] UI: werden Angular-Apps (`ui/modules/apps/*/app.json`) in 0.40 noch geladen? Name des Stream-Dienstes (`StreamsManager`) und `bngApi.engineLua`
- [ ] Teilenamen für eigene **Drag-Konfigurationen** (Amateur bis Pro) aus den Jbeams auslesen

## B. Im Spiel
1. [ ] Mod aktiv, Log zeigt `Turismo Karriere 0.1.0 geladen`, keine Fehler mit `turismo`
2. [ ] App ins Layout, Taste belegt, Menü öffnet sich, Spiel pausiert
3. [ ] Neue Karriere → Café-Heft 1 → Gebrauchtwagen kaufen → Garage
4. [ ] Diagnose: Anzahl Autos/Marken plausibel, Liste „nicht gefundene Strecken“ prüfen
5. [ ] **Lizenztest L1-01**: Karte lädt, Leihwagen spawnt, Tore sichtbar, Countdown, Zeit, Medaille, Ergebnis-Screen
6. [ ] Vorführung eines Tests (KI fährt den Kurs)
7. [ ] **Schnelles Rennen** (Sonntagspokal): Kamerafahrt, Ampel, KI fährt, HUD-Werte, Ziel, Ergebnis, Preisgeld
8. [ ] **Schaden bleibt:** Auto im Rennen beschädigen → Menü → nächstes Rennen → Schaden noch da; Werkstatt repariert
9. [ ] Reset-Taste während des Rennens repariert nicht
10. [ ] **Rennwochenende** (GT-Nationals, ggf. per „Klassisch“-Spielstand): Training, Qualifying, Startaufstellung, Einführungsrunde, fliegender Start
11. [ ] K.O.-Rennen und Verfolgung
12. [ ] Zeitfahren, Bergrennen, Touge, Drift (Punkte steigen), Derby (KI rammt), Transport, Crawling
13. [ ] **Drag-Wochenende:** Staging, Baum, Reaktionszeit, Zwischenzeiten, Gegner-KI startet, Leiter
14. [ ] Musik/Sounds laufen über die CEF-Oberfläche (Lautstärke im Spiel prüfen)
15. [ ] Speichern/Laden, Spiel neu starten, Spielstand weiter da
16. [ ] Notfall-Menü (IMGUI) öffnet sich
17. [ ] Streckenrekorder: Rundkurs aufnehmen, speichern, taucht unter „Bekannte Strecken“ auf

## C. Feintuning nach dem Test
- KI-Stärke pro Stufe, Patzer-Häufigkeit
- Zielzeiten der Lizenztests (Vorführung kalibriert automatisch)
- Preise, Preisgelder, Werkstattkosten
- LI-Formel an echten 0.40-Daten gegenprüfen (alle Autos als Tabelle ausgeben)
