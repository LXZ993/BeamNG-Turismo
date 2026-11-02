-- Turismo Karriere - core
-- Bootstrap (loads all turismo modules in order and keeps them alive across
-- level changes), per-frame updates, toasts and the UI bridge.
--
-- UI -> Lua:  bngApi.engineLua("extensions.turismo_core.uiCall('<action>', <args>, <reqId>)")
-- Lua -> UI:  guihooks 'TurismoResult' {reqId, action, ok, data, error}
--             guihooks 'TurismoState' (profile summary), 'TurismoToast', 'TurismoHubToggle',
--             race/test HUD events (see race.lua / tests.lua)

local M = {}

M.VERSION = '0.1.4' -- muss zu data/turismo/build.json "modVersion" und CHANGELOG.md passen

M.MODULES = {
  'turismo_logger', 'turismo_util', 'turismo_save', 'turismo_data', 'turismo_rating', 'turismo_vehicleDb',
  'turismo_profile', 'turismo_garage', 'turismo_condition', 'turismo_services', 'turismo_dealer',
  'turismo_licenses', 'turismo_tracks', 'turismo_courses', 'turismo_aiDirector', 'turismo_race', 'turismo_tests',
  'turismo_modes', 'turismo_drag', 'turismo_events', 'turismo_cafe', 'turismo_progression',
  'turismo_audio', 'turismo_session', 'turismo_imguiHub',
}

local hubVisible = false
local activeActivity -- forward declaration (defined with the UI handlers)
local stateDirty = true
local stateTimer = 0

local function U() return extensions.turismo_util end
local function S() return extensions.turismo_save end
local function X(name) return extensions['turismo_' .. name] end

local function levelLoaded()
  local lvl = getCurrentLevelIdentifier and getCurrentLevelIdentifier()
  return lvl ~= nil and lvl ~= ''
end
M.levelLoaded = levelLoaded

-- BeamNG draws the minimap (Navigation app, or another mod's minimap) with imgui on top of every HTML
-- layer, so it would show through the world menu. While the menu is open: hide it and hold back new
-- transforms; when the menu closes, put the last known transform back and ask the apps to resend theirs.
local mmTimer = 0
local mmGuard = { wrapped = nil, orig = nil, last = nil, blocked = false }
local function minimapGuard(block)
  local mm = rawget(_G, 'ui_apps_minimap_minimap')
  if not mm or type(mm.setDrawTransform) ~= 'function' then return end
  if mmGuard.wrapped ~= mm then
    local orig = mm.setDrawTransform
    mmGuard.wrapped, mmGuard.orig, mmGuard.last, mmGuard.blocked = mm, orig, nil, false
    mm.setDrawTransform = function(...)
      mmGuard.last = { ... }
      if not mmGuard.blocked then return orig(...) end
    end
  end
  if block == mmGuard.blocked then return end
  mmGuard.blocked = block
  if block then
    pcall(mm.hide)
  else
    if mmGuard.last then pcall(mmGuard.orig, unpack(mmGuard.last)) end
    if guihooks then guihooks.trigger('onMinimapSettingsChanged') end
  end
  U().log('D', 'Minikarte %s', block and 'ausgeblendet (Menü offen)' or 'wieder an')
end

-- own loading cover: keeps the world menu from flashing up before the map loads
local function loadingCover(on, text)
  if guihooks then guihooks.trigger('TurismoLoading', { visible = on and true or false, text = text }) end
end
M.loadingCover = loadingCover

---------------------------------------------------------------------------
-- bootstrap
---------------------------------------------------------------------------
local function loadModules()
  for _, name in ipairs(M.MODULES) do
    if not extensions[name] then
      extensions.load(name)
    end
    if setExtensionUnloadMode then setExtensionUnloadMode(name, 'manual') end
  end
  X('logger').start()
  -- data must be available before anything reads it
  X('data').reload()
  X('logger').checkData()
  for _, name in ipairs(M.MODULES) do
    if name ~= 'turismo_logger' then X('logger').protect(name) end
  end
end

function M.onExtensionLoaded()
  if setExtensionUnloadMode then setExtensionUnloadMode(M, 'manual') end
  loadModules()
  M.registerPauseButton()
  U().log('I', 'Turismo Karriere %s geladen', M.VERSION)
end

function M.onUpdate(dtReal, dtSim, dtRaw)
  local ok, err = pcall(function()
    X('session').update(dtReal, dtSim)
    X('race').update(dtReal, dtSim)
    X('tests').update(dtReal, dtSim)
    X('modes').update(dtReal, dtSim)
    X('drag').update(dtReal, dtSim)
    S().update(dtReal)
    if X('imguiHub') then X('imguiHub').draw(dtReal) end
  end)
  if not ok then
    U().log('E', 'FEHLER in onUpdate: %s | Zustand: %s', tostring(err), X('logger').context())
  end
  X('logger').onUpdate(dtReal)
  -- a minimap app may load while the menu is already open
  mmTimer = (mmTimer or 0) + dtReal
  if hubVisible and mmTimer > 1 then mmTimer = 0 pcall(minimapGuard, true) end
  stateTimer = stateTimer + dtReal
  if stateDirty and stateTimer > 0.5 then
    stateTimer = 0
    stateDirty = false
    M.pushState()
  end
end

---------------------------------------------------------------------------
-- hub visibility
---------------------------------------------------------------------------

function M.setHubVisible(v)
  hubVisible = v and true or false
  pcall(minimapGuard, hubVisible)
  if hubVisible then loadingCover(false) end
  -- leaving the Turismo menu to drive: make sure BeamNG's own menu is closed too
  if not hubVisible and levelLoaded() and ui_menuManager and ui_menuManager.closeMenu then
    pcall(ui_menuManager.closeMenu)
  end
  if guihooks then guihooks.trigger('TurismoHubToggle', { visible = hubVisible }) end
  local st = S().get()
  local pause = not st or not st.settings or st.settings.pauseInHub ~= false
  if pause and simTimeAuthority and simTimeAuthority.pause and not activeActivity() then
    pcall(simTimeAuthority.pause, hubVisible)
  end
  X('audio').music(hubVisible and (S().isLoaded() and 'menu' or 'title') or 'off')
  stateDirty = true
end

function M.toggleHub() M.setHubVisible(not hubVisible) end

---------------------------------------------------------------------------
-- career as its own game mode (main menu entry, see ui/ui-vue/mods/turismo_karriere)
---------------------------------------------------------------------------

-- main menu button "Turismo Karriere": title screen with the save slots
function M.startCareer()
  U().log('I', 'Karriere aus dem Hauptmenü gestartet')
  M.registerPauseButton()
  -- started from the in-game menu: close it, the Turismo menu takes over
  if levelLoaded() and ui_menuManager and ui_menuManager.closeMenu then pcall(ui_menuManager.closeMenu) end
  M.setHubVisible(true)
end

-- pause menu (Esc) -> tab "Mods" -> "Turismo-Menü": no key binding needed
function M.registerPauseButton()
  local pa = extensions.ui_pause_actions
  if not pa or not pa.registerModButton then return end
  pcall(pa.registerModButton, {
    id = 'turismo-open', tabId = 'mods', label = 'Turismo-Menü', icon = 'wrench',
    componentName = '/ui/ui-vue/mods/turismo_karriere/PauseCard.vue',
  })
end

function M.openFromPause()
  if ui_menuManager and ui_menuManager.closeMenu then pcall(ui_menuManager.closeMenu) end
  M.setHubVisible(true)
end

function M.onWorldReadyState(state)
  if state == 2 then M.registerPauseButton() end
end

-- after a save slot was loaded/created in the main menu: load the home map,
-- put the active garage car there and open the world menu
function M.enterCareerWorld()
  if levelLoaded() or not S().isLoaded() then return end
  local st = S().get()
  local home = (st.settings and st.settings.homeLevel) or 'west_coast_usa'
  M.setHubVisible(false) -- keep the loading screen visible
  X('session').loadLevel(home, function()
    local function show() M.setHubVisible(true) end
    if X('garage').active() then
      X('session').spawnPlayerCar(nil, nil, show)
    else
      show()
    end
  end)
end

-- keybinding: pause menu while driving an event (UI shows restart/abort)
function M.raceMenu()
  local a, n = activeActivity()
  if guihooks then guihooks.trigger('TurismoRaceMenu', { active = a ~= nil, kind = n }) end
  if not a then M.toggleHub() end
end

-- keybinding: skip intro camera / close result screens
function M.skip()
  local a, n = activeActivity()
  if n == 'race' and a.skipIntro then a.skipIntro() end
  if guihooks then guihooks.trigger('TurismoSkip', { kind = n }) end
end
function M.isHubVisible() return hubVisible end

---------------------------------------------------------------------------
-- toasts & state
---------------------------------------------------------------------------
function M.onTurismoToast(msg, kind)
  if guihooks then
    guihooks.trigger('TurismoToast', { msg = msg, kind = kind or 'info' })
    -- also show in BeamNG's own message app as a fallback
    guihooks.trigger('Message', { ttl = 6, msg = msg, category = 'turismo', icon = 'flag' })
  end
  stateDirty = true
end

function M.onTurismoMoneyChanged() stateDirty = true end
function M.onTurismoDayAdvanced() stateDirty = true end
function M.onTurismoCarAdded() stateDirty = true end

function M.snapshotState()
  local st = S().get()
  if not st then return { loaded = false, version = M.VERSION } end
  local P, G = X('profile'), X('garage')
  local th = P.collectorThresholds()
  local lvl = P.collectorLevel()
  local cafe = X('cafe')
  local cur = st.cafe.current and X('data').cafeBook(st.cafe.current)
  local curDone, curTotal = 0, 0
  if cur then curDone, curTotal = cafe.bookProgress(cur) end
  local owned = {}
  for id in pairs(st.licenses.owned) do owned[#owned + 1] = id end
  table.sort(owned)
  return {
    loaded = true, version = M.VERSION, slot = S().slot(),
    meta = st.meta, settings = st.settings or {},
    money = st.economy.money, day = st.calendar.day,
    dailyKm = st.calendar.dailyKm, dailyGoal = X('data').economy().dailyGoalKm or 42,
    dailyGoalDone = st.calendar.dailyGoalDone,
    collector = { level = lvl, points = st.collector.points, next = th[lvl + 1], current = th[lvl] },
    activeCar = G.snapshot(G.active()), carCount = G.count(),
    tickets = #st.rewards.tickets, licenses = owned,
    cafe = cur and { id = cur.id, name = cur.name, done = curDone, total = curTotal } or nil,
    cafeCompleted = st.cafe.completedCount or 0,
    unlocks = X('progression').snapshot(),
    stats = st.stats,
    raceActive = X('race').isActive() or X('modes').isActive() or X('drag').isActive(), testActive = X('tests').isActive(),
    level = X('session').currentLevel(),
    hubVisible = hubVisible,
    aiLevel = X('aiDirector').ratingLabel(st.meta.aiRating),
    firstVisit = not (st.meta.introSeen),
  }
end

function M.pushState()
  if guihooks then guihooks.trigger('TurismoState', M.snapshotState()) end
end

function M.markStateDirty() stateDirty = true end

---------------------------------------------------------------------------
-- UI actions
---------------------------------------------------------------------------
local handlers = {}

local function requireProfile()
  if not S().isLoaded() then error('Kein Spielstand geladen', 0) end
end

handlers.ping = function() X('audio').setUiAlive(true) return { version = M.VERSION } end
handlers.state = function() return M.snapshotState() end
handlers.getSlots = function() return S().listSlots() end

handlers.newProfile = function(a)
  local eco = X('data').economy()
  local st = S().newProfile(a.slot or 1, a.name, {
    progressionMode = a.progressionMode, damageMode = a.damageMode,
  })
  st.meta.hardcore = a.hardcore and true or false
  st.economy.money = eco.startMoney or st.economy.money
  st.settings = st.settings or { pauseInHub = true, homeLevel = eco.homeLevel or 'west_coast_usa', raceLength = 'normal' }
  S().save()
  if not levelLoaded() then
    -- hide the menu right away: otherwise the world menu shows for a moment before BeamNG's loading screen
    M.setHubVisible(false)
    loadingCover(true, 'Karriere wird geladen …')
    X('session').defer(0.3, M.enterCareerWorld)
  end
  return M.snapshotState()
end

handlers.loadProfile = function(a)
  if not S().load(a.slot) then error('Spielstand konnte nicht geladen werden', 0) end
  local st = S().get()
  st.settings = st.settings or { pauseInHub = true, homeLevel = 'west_coast_usa', raceLength = 'normal' }
  if not levelLoaded() then
    -- hide the menu right away: otherwise the world menu shows for a moment before BeamNG's loading screen
    M.setHubVisible(false)
    loadingCover(true, 'Karriere wird geladen …')
    X('session').defer(0.3, M.enterCareerWorld)
  end
  return M.snapshotState()
end

handlers.deleteProfile = function(a) S().deleteSlot(a.slot) return S().listSlots() end
handlers.save = function() requireProfile() S().save() return true end

handlers.setting = function(a)
  requireProfile()
  local st = S().get()
  local metaKeys = { introSeen = true, hardcore = true, damageMode = true, progressionMode = true, raceLength = true, skipIntro = true }
  if metaKeys[a.key] then st.meta[a.key] = a.value else
    st.settings = st.settings or {}
    st.settings[a.key] = a.value
  end
  S().markDirty()
  return M.snapshotState()
end

-- garage
handlers.garage = function() requireProfile() return X('garage').list() end
handlers.setActiveCar = function(a) requireProfile() return X('garage').setActive(a.carId) end
handlers.sellCar = function(a)
  requireProfile()
  local v, err = X('garage').sellCar(a.carId)
  if not v then error(err, 0) end
  X('audio').play('money')
  return { value = v }
end
handlers.renameCar = function(a)
  requireProfile()
  local car = X('garage').get(a.carId)
  if car then car.nickname = (a.name ~= '' and a.name) or nil S().markDirty() end
  return true
end
handlers.favoriteCar = function(a)
  requireProfile()
  local car = X('garage').get(a.carId)
  if car then car.favorite = not car.favorite S().markDirty() end
  return true
end
handlers.carDetails = function(a)
  requireProfile()
  local car = X('garage').get(a.carId)
  if not car then error('Fahrzeug nicht gefunden', 0) end
  local snap = X('garage').snapshot(car)
  snap.history = car.history
  snap.info = X('vehicleDb').get(car.key)
  snap.summary = car.summary
  return snap
end

-- dealers
handlers.dealerRegions = function() requireProfile() return X('dealer').regions() end
handlers.showroom = function(a) requireProfile() return X('dealer').showroom(a.brand) end
handlers.usedOffers = function() requireProfile() return X('dealer').usedOffers() end
handlers.legendOffers = function() requireProfile() return X('dealer').legendOffers() end
handlers.buy = function(a)
  requireProfile()
  local car, err = X('dealer').buy(a.kind, a.id)
  if not car then error(err, 0) end
  X('audio').play('purchase')
  return X('garage').snapshot(car)
end

-- services
handlers.services = function(a)
  requireProfile()
  local car = X('garage').get(a.carId or (X('garage').active() and X('garage').active().id))
  if not car then error('Kein Fahrzeug', 0) end
  local q, sum = X('services').quotes(car)
  local list = {}
  for _, id in ipairs({ 'wash', 'oil', 'quickRepair', 'fullRepair', 'engine', 'paint' }) do
    local item = q[id]
    if item then
      list[#list + 1] = { id = id, name = item.label, desc = item.desc, price = item.price, available = item.available }
    end
  end
  return { car = X('garage').snapshot(car), quotes = list, summary = sum }
end
handlers.service = function(a)
  requireProfile()
  local ok, res = X('services').perform(a.carId, a.service)
  if not ok then error(res, 0) end
  X('audio').play(a.service == 'wash' and 'wash' or 'repair')
  return handlers.services(a)
end
handlers.conversions = function(a) requireProfile() return X('services').conversions(X('garage').get(a.carId)) end
handlers.convert = function(a)
  requireProfile()
  local ok, res = X('services').convert(a.carId, a.key)
  if not ok then error(res, 0) end
  return true
end

-- licences, tests, trainings
handlers.licenses = function() requireProfile() return X('licenses').snapshot() end
handlers.trainings = function()
  requireProfile()
  local res = {}
  for _, t in ipairs(X('data').get('trainings') or {}) do res[#res + 1] = X('licenses').testInfo(t) end
  return res
end
handlers.startTest = function(a)
  requireProfile()
  local ok, err = X('tests').start(a.testId, { demo = a.demo })
  if ok == false then error(err or 'Test konnte nicht gestartet werden', 0) end
  M.setHubVisible(false)
  return true
end
handlers.retryTest = function() X('tests').retry() return true end
handlers.closeTest = function() X('tests').close() return true end
handlers.calibrateVenue = function(a) requireProfile() return X('session').setVenueAnchorHere(a.venueId or 'testgelaende') end

-- events & races
handlers.events = function() requireProfile() return X('events').snapshot() end
handlers.startRace = function(a)
  requireProfile()
  local ok, err = X('events').startRace(a.seriesId, a)
  if not ok then error(err or 'Rennen konnte nicht gestartet werden', 0) end
  M.setHubVisible(false)
  return true
end
activeActivity = function()
  for _, n in ipairs({ 'race', 'modes', 'drag', 'tests' }) do
    if X(n).isActive() then return X(n), n end
  end
  return nil
end
M.activeActivity = activeActivity

handlers.raceRestart = function()
  local a, n = activeActivity()
  local st = S().get()
  if st and st.meta.hardcore and n ~= 'tests' then error('Im Hardcore-Modus gibt es keinen Neustart.', 0) end
  if a and a.restart then a.restart() elseif a and a.retry then a.retry() end
  return n
end
handlers.raceClose = function()
  local a = activeActivity()
  if a then a.close() else X('session').returnToHub() end
  return true
end
handlers.raceAbort = function()
  local a, n = activeActivity()
  if n == 'race' then a.abort('user') elseif a then a.abort() end
  X('session').returnToHub()
  return true
end
handlers.dragDial = function(a) X('drag').setDial(a.value) return true end
handlers.raceEndSession = function() X('race').endSession() return true end
handlers.raceSkipIntro = function() X('race').skipIntro() return true end

-- café
handlers.cafe = function() requireProfile() return X('cafe').snapshot() end
handlers.cafeAccept = function(a) requireProfile() return X('cafe').accept(a.bookId) end
handlers.cafeComplete = function(a)
  requireProfile()
  local r, err = X('cafe').tryComplete(a.bookId)
  if not r then error(err or 'Noch nicht erfüllt', 0) end
  X('audio').play('levelup')
  return r
end

-- rewards
handlers.tickets = function() requireProfile() return S().get().rewards.tickets end
handlers.openTicket = function(a)
  requireProfile()
  local r, err = X('profile').openTicket(a.id)
  if not r then error(err, 0) end
  X('audio').play('ticket')
  return r
end

-- world
handlers.freeDrive = function(a)
  requireProfile()
  X('session').freeDrive(a.level, a.carId)
  return true
end
handlers.levels = function()
  local res = {}
  for _, l in ipairs(X('tracks').byLevel()) do res[#res + 1] = { level = l.level, tracks = #l.tracks } end
  return res
end
handlers.tracks = function()
  local res = {}
  for _, t in ipairs(X('tracks').all()) do
    res[#res + 1] = { id = t.id, name = t.name, level = t.level, closed = t.closed, lengthM = t.lengthM,
      grid = t.grid, surface = t.surface, source = t.source, best = S().isLoaded() and S().get().stats.bestLaps[t.id] or nil }
  end
  return res
end
handlers.rescan = function()
  X('vehicleDb').rebuild()
  X('tracks').rebuild()
  X('data').reload()
  return { cars = #X('vehicleDb').all(), tracks = #X('tracks').all() }
end
-- Changelog für den Bildschirm "Neuigkeiten". Eigener Mod-Ordner zuerst: /CHANGELOG.md teilen sich alle Mods
-- (z. B. Hashiriya Battle hat auch eine), deshalb wird die Überschrift geprüft.
handlers.changelog = function()
  local candidates = { '/mods/unpacked/turismo_karriere/CHANGELOG.md', '/CHANGELOG.md' }
  for _, path in ipairs(candidates) do
    local txt = readFile and readFile(path)
    if txt and txt:find('^# Changelog Turismo') then return { text = txt, path = path } end
  end
  U().log('W', 'Changelog nicht gefunden (%s)', table.concat(candidates, ', '))
  error('Changelog nicht gefunden', 0)
end

handlers.diagnostics = function()
  local problems = X('data').validate()
  local missingTracks = {}
  for _, s in ipairs(X('data').get('events') or {}) do
    for i, r in ipairs(s.races or {}) do
      if r.track and not X('tracks').resolve(r.track, U().hashString(s.id .. i)) then
        missingTracks[#missingTracks + 1] = s.id .. ' #' .. i .. ': ' .. tostring(r.track)
      end
    end
  end
  return {
    version = M.VERSION, cars = #X('vehicleDb').all(), tracks = #X('tracks').all(),
    brands = #X('vehicleDb').brands(), problems = problems, missingTracks = missingTracks,
    level = X('session').currentLevel(),
  }
end

-- track recorder
handlers.recorderStart = function(a) return X('tracks').recorderStart(a.name, a.closed) end
handlers.recorderCheckpoint = function(a) return X('tracks').recorderAddCheckpoint(a.radius) end
handlers.recorderGrid = function() return X('tracks').recorderAddGridSlot() end
handlers.recorderState = function() return X('tracks').recorderState() end
handlers.recorderCancel = function() X('tracks').recorderCancel() return true end
handlers.recorderSave = function()
  local ok, file = X('tracks').recorderSave()
  if not ok then error(file or 'Speichern fehlgeschlagen', 0) end
  return file
end

-- Fehlerbericht: schreibt settings/turismo/logs/bugreport.txt (die eine Datei, die Tester schicken)
handlers.bugReport = function(a)
  local path = X('logger').writeReport(a and a.note)
  if not path then error('Fehlerbericht konnte nicht geschrieben werden', 0) end
  return { path = path }
end
function M.bugReport(note)
  local path = X('logger').writeReport(note)
  if path then M.onTurismoToast('Fehlerbericht gespeichert: ' .. path, 'info') end
  return path
end

handlers.hub = function(a) M.setHubVisible(a.visible) return true end
handlers.sound = function(a) X('audio').play(a.cue) return true end

-- Aktionen, die die UI ständig abfragt: nicht ins Log (sonst wird es unlesbar)
local QUIET_ACTIONS = { ping = true, state = true, recorderState = true, sound = true, getSlots = true }

-- kurze Zusammenfassung der Argumente für das Log (keine langen Texte)
local function argSummary(args)
  if type(args) ~= 'table' then return '' end
  local parts = {}
  for k, v in pairs(args) do
    if type(v) ~= 'table' then
      local t = tostring(v)
      if #t > 40 then t = t:sub(1, 40) .. '...' end
      parts[#parts + 1] = tostring(k) .. '=' .. t
    end
  end
  table.sort(parts)
  return table.concat(parts, ' ')
end

function M.uiCall(action, args, reqId)
  local h = handlers[action]
  local res = { reqId = reqId, action = action }
  if not QUIET_ACTIONS[action] then U().log('I', 'Aktion: %s %s', tostring(action), argSummary(args)) end
  if not h then
    res.ok, res.error = false, 'Unbekannte Aktion: ' .. tostring(action)
    U().log('W', 'uiCall: unbekannte Aktion %s', tostring(action))
  else
    local ok, data = xpcall(h, debug.traceback, args or {})
    res.ok = ok
    if ok then res.data = data else
      local msg = tostring(data)
      res.error = msg:match('^[^\n]*') or msg
      -- error('Text', 0) sind erwartete Meldungen an den Spieler (z. B. "Kein Spielstand geladen"), kein Code-Fehler
      local expected = not msg:find('%.lua:%d+:')
      if expected then
        U().log('W', 'uiCall %s abgelehnt: %s', tostring(action), res.error)
      else
        U().log('E', 'FEHLER in uiCall %s: %s | Zustand: %s', tostring(action), msg, X('logger').context())
      end
    end
  end
  if guihooks then guihooks.trigger('TurismoResult', res) end
  stateDirty = true
  return res
end

-- for the IMGUI fallback and console use: returns ok, dataOrError (no UI event)
M.handlers = handlers
function M.call(action, args)
  local h = handlers[action]
  if not h then return false, 'Unbekannte Aktion: ' .. tostring(action) end
  local ok, data = pcall(h, args or {})
  stateDirty = true
  return ok, data
end

return M
