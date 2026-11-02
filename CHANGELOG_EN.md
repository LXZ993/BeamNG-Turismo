# Turismo Career Changelog

## 0.1.4 (as of 2026-11-02)

### New: GT-style driving HUD
- Bottom right: a rev bar with a red zone. In the red, the bar and the gear flash: shift now.
- Big gear and speed right above the rev bar.
- Minimap bottom left: the track with all cars, you are the blue dot, the finish line is the white square.
- Top centre: live gap to your best lap, green = faster, red = slower. Shows from the second lap.
- The standings top right now show only the 5 drivers around you.

### New: pictures in the menu
- Every tile in the world menu has its own picture.
- For places 1 to 3 the podium screen shows a gold, silver or bronze trophy.

### New: changelog and bug report in the menu
- **Settings** now has **Changelog**: it lists what changed in each version.
- **Create bug report** is now in Settings and on the title screen. You can add a short note about what happened. Afterwards it shows where the file is.

## 0.1.3 (as of 2026-11-02)

### New: bug report and own log
- The mod now writes its own log: `settings\turismo\logs\turismo.log` in the BeamNG user folder. It only contains Turismo messages, with timestamps, easy to read.
- Every start begins with the mod version, BeamNG version and all other active mods. The mod then checks its data and reports broken files right away.
- Every click in the Turismo menu and every error is recorded, errors with the exact location and the game state at that moment. The game keeps running.
- The log never grows huge: at most 4 files of 512 KB each.
- New: **Create bug report**. Use the key "Turismo: Fehlerbericht erstellen" (bind it under Options > Controls) or the emergency menu. This writes `bugreport.txt` with the log and your save. That one file is what you send when something goes wrong.
- New: handbook `docs/handbuch.html` (German). It explains where everything is and how to change series, licences, café books, drivers and prices yourself.

### First test on PC
- The name field for a new save now accepts keyboard input.
- Opponent strength now adjusts automatically to your results. There is no setting for it anymore. Beginners get a light catch-up help at first that fades over time.
- The world menu explains every area. On your first visit there is a short introduction, later you find it under "So funktioniert's".
- Licence tests: the BeamNG menu closes on start, the posts are bigger and labelled, a yellow line shows the way and the next target with distance is shown at the top. There is a short briefing before the start.
- The main menu banner is gone, it covered the "Back" button in the pause menu.

## 0.1.2 (as of 2026-11-02)

### New: own game mode in the main menu
- Turismo Career is now in the BeamNG main menu under **More**. You start the career like its own game mode, no longer from free roam.
- Loading or creating a save loads the home map and opens the world menu.
- While driving: Esc, then **Mods**, then **Turismo menu**.
- The interface loads by itself. You no longer need to drag an app into the UI layout.

## 0.1.1 (as of 2026-11-02)

### Bug fixes
- Adapted to BeamNG.drive 0.40.4.
- Recovery points of a track no longer end up in the starting grid.
- Opponents no longer jump to the first waypoint at the start.
- Drag strips in the new 0.40 format are recognised, the old format still works.
- The BeamNG lap time app is hidden during Turismo races so it does not cover the own HUD.

## 0.1.0 (as of 2026-11-01)

### First version
- Career with 3 save slots, progress through 20 café books or "Classic" with everything open, damage mode and hardcore mode.
- Licences C, B, A, I, S, Rally and Drift with 50 tests, gold, silver and bronze. 10 optional trainings at the driving school.
- 53 race series in 9 halls: circuit, elimination, pursuit, time attack, hill climb, touge, drift, destruction derby, trucking, crawling and drag weekends.
- Quick race or race weekend with practice, qualifying, camera flyover, formation lap and rolling start.
- Performance index (LI) and classes E to X for every car on your install, mod cars included.
- Dealers for new cars, used cars and classics. Workshop with wash, oil change, repair, engine overhaul and conversions.
- Damage stays: part condition is saved and nothing repairs itself.
- 90 AI drivers with their own level and driving style.
- World menu, own race HUD, start lights, drag tree, result screens and an emergency menu.
