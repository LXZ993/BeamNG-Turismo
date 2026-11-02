# Prüfliste für BeamNG 0.40 (morgen am PC)

Offline ist alles getestet, was ohne Spiel testbar ist (49 automatische Prüfungen, UI im Browser gerendert). Teil A (Schnittstellen gegen die Lua-Quellen von 0.40.4 abgleichen) ist erledigt, offen ist Teil B im Spiel.

## A. Vorab im Spielordner (ohne Spielstart) – erledigt am 02.11. gegen 0.40.4
- [x] `gameplay/race/path.lua`, `race.lua`, `startPosition.lua`: Konstruktor, `onDeserialized`, `autoConfig`, `getAiPath`, `moveResetVehicleTo(id, lowPrecision, repair)` passen. **Korrigiert:** Race-Dateien führen Bergungspunkte (`group = 'recovery'`) in `startPositions` – die standen bisher mit in der Startaufstellung. Jetzt gefiltert, Standard-Startplatz zuerst; Ersatz-Startplatz auch für Zeitfahren/Touge, wenn eine Datei keinen hat. Die Vanilla-Rundenzeiten-App wird bei Turismo-Rennen nicht mehr mitgestartet.
- [x] `core_vehicleBridge` + `interactPartCondition`: `getPartConditions` / `initPartConditions(conds, odometer, integrity, visual)` passen. **Korrigiert:** statt `nil` wird bei neuen Autos `{}` übergeben (Typprüfung der Fahrzeugseite).
- [x] `core_vehicles.getConfigList()` – gleiche Felder wie bisher (`configs`, `model_key`, `key`, `Name`, `aggregates`, `Value`, `Years` …)
- [x] `freeroam_freeroam.startFreeroam(level, …)`, `core_levels.getLevelByName`, `simTimeAuthority.pause` – passen
- [x] Kamerafahrt: `core_paths.playPath(path, offset, initData)` mit absoluten Marker-Zeiten und `finishedPath` – passt
- [x] KI: `driveUsingPath`, `setParameters`, `setRacing`, `setSpeedMode` passen. **Korrigiert:** im Skript-Modus (Strecken ohne Straßennetz, Lizenz-Vorführung) setzt 0.40 das Auto auf den ersten Skriptpunkt und ignoriert Aggression/avoidCars/Tempolimit. Erster Punkt ist jetzt die eigene Position, die Werte werden separat gesetzt.
- [x] Dragstrips: 0.40 nutzt ein neues Format (`*.dragData.json` → `stripId` → `*.strip.json`, Wegpunkte als Liste mit `type`). **Korrigiert:** beide Formate werden gelesen.
- [ ] Welche `*.race.json` es in 0.40 gibt, zeigt der Diagnose-Bildschirm im Spiel (die Level liegen gezippt in `content/levels`, 0,8–3 GB je Karte)
- [x] UI: Angular-Apps werden in 0.40 weiter geladen. **Korrigiert:** `StreamsManager` ist in 0.40 eine globale Variable und kein Angular-Dienst mehr – die App holt ihn jetzt so wie die Vanilla-Apps (sonst wäre die App beim Laden ausgestiegen).
- [x] Eingabe-Aktionen (`core/input/actions/*.json`): Format passt
- [ ] Teilenamen für eigene **Drag-Konfigurationen** (Fahrzeuge liegen gezippt in `content/vehicles`)

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
