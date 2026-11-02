# Turismo Career Changelog

## 0.1.4 (as of 2026-11-02)

### New: licence tests on real tracks
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

### New: GT-style driving HUD
- Bottom right: a rev bar with a red zone. In the red, the bar and the gear flash: shift now.
- Big gear and speed right above the rev bar.
- Minimap bottom left: the track with all cars, you are the blue dot, the finish line is the white square.
- Top centre: live gap to your best lap, green = faster, red = slower. Shows from the second lap.
- The standings top right now show only the 5 drivers around you.

### New: world menu as a city map
- Instead of the colourful tiles the world menu now shows a city map from above at an angle. Bright during the day, dark with glowing roads from 7 pm and at night (based on your PC's clock).
- The places are dots with names on the map: Café, Races, License Centre, Driving School, New Cars, Used Cars, Classic Gallery, Garage, Workshop and Free Drive. Click to open a place.
- Hovering a place shows a short line about it at the bottom. The arrow keys jump from place to place, Enter opens it.
- Locked places are grey with a lock. The bottom line says how to unlock them.
- Help, bonus tickets, settings, changelog and diagnostics are small buttons on the right edge.
- The bar at the top is slimmer and darker.
- For places 1 to 3 the podium screen shows a gold, silver or bronze trophy.

### New: dealers, races, garage and café in GT style
- Used cars, new cars and the classic gallery show cars as bright cards with picture, brand, name, mileage and price. A click opens a window with all data and the buy button. It also says why you can't buy a car right now (licence or money missing).
- The new-car brands are bright cards instead of tiles.
- Races: the race classes are tall cards side by side with series, open and won series. Inside a class every race is its own card with track, laps, best result (trophy) and start button.
- Garage: the selected car large on the left with condition, engine, mileage and value, the list of all cars on the right. Clicking a column header sorts the list.
- Café: the current booklet lies open on a bright board, next to it all booklets as small covers. Finished ones carry a stamp.

### Bug fixes
- Loading a save briefly flashed the world menu, then the loading screen, then the menu again. Now a Turismo loading screen shows and the menu appears only once the map is loaded.
- The minimap (from BeamNG or another mod) was drawn over the Turismo menu. It is now hidden while the menu is open and comes back when you drive.

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
