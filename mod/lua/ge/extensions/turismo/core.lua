-- Turismo Karriere - core
-- Bootstrap (loads all turismo modules in order and keeps them alive across
-- level changes), per-frame updates, toasts and the UI bridge.
--
-- UI -> Lua:  bngApi.engineLua("extensions.turismo_core.uiCall('<action>', <args>, <reqId>)")
-- Lua -> UI:  guihooks 'TurismoResult' {reqId, action, ok, data, error}
--             guihooks 'TurismoState' (profile summary), 'TurismoToast', 'TurismoHubToggle',
--             race/test HUD events (see race.lua / tests.lua)

local M = {}

M.VERSION = '0.1.0'

M.MODULES = {
  'turismo_util', 'turismo_save', 'turismo_data', 'turismo_rating', 'turismo_vehicleDb',
  'turismo_profile', 'turismo_garage', 'turismo_condition', 'turismo_services', 'turismo_dealer',
  'turismo_licenses', 'turismo_tracks', 'turismo_aiDirector', 'turismo_race', 'turismo_tests',
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
  -- data must be available before anything reads it
  X('data').reload()
end

function M.onExtensionLoaded()
  if setExtensionUnloadMode then setExtensionUnloadMode(M, 'manual') end
  loadModules()
  log('I', 'turismo', 'Turismo Karriere ' .. M.VERSION .. ' geladen')
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
    log('E', 'turismo', 'update error: ' .. tostring(err))
  end
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
    difficulty = a.difficulty, progressionMode = a.progressionMode, damageMode = a.damageMode,
  })
  st.meta.hardcore = a.hardcore and true or false
  st.economy.money = eco.startMoney or st.economy.money
  st.settings = st.settings or { pauseInHub = true, homeLevel = eco.homeLevel or 'west_coast_usa', raceLength = 'normal' }
  S().save()
  return M.snapshotState()
end

handlers.loadProfile = function(a)
  if not S().load(a.slot) then error('Spielstand konnte nicht geladen werden', 0) end
  local st = S().get()
  st.settings = st.settings or { pauseInHub = true, homeLevel = 'west_coast_usa', raceLength = 'normal' }
  return M.snapshotState()
end

handlers.deleteProfile = function(a) S().deleteSlot(a.slot) return S().listSlots() end
handlers.save = function() requireProfile() S().save() return true end

handlers.setting = function(a)
  requireProfile()
  local st = S().get()
  local metaKeys = { difficulty = true, hardcore = true, damageMode = true, progressionMode = true, raceLength = true, skipIntro = true, catchUp = true }
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
  local results = S().get().licenses.results
  for _, t in ipairs(X('data').get('trainings') or {}) do
    local r = results[t.id] or {}
    res[#res + 1] = { id = t.id, name = t.name, desc = t.desc, category = t.category, medal = r.medal or 'none',
      best = r.best, targets = X('licenses').targetsFor(t), scoring = t.scoring or 'time' }
  end
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

handlers.hub = function(a) M.setHubVisible(a.visible) return true end
handlers.sound = function(a) X('audio').play(a.cue) return true end

function M.uiCall(action, args, reqId)
  local h = handlers[action]
  local res = { reqId = reqId, action = action }
  if not h then
    res.ok, res.error = false, 'Unbekannte Aktion: ' .. tostring(action)
  else
    local ok, data = pcall(h, args or {})
    res.ok = ok
    if ok then res.data = data else
      res.error = tostring(data)
      log('W', 'turismo', 'uiCall ' .. tostring(action) .. ' failed: ' .. tostring(data))
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
