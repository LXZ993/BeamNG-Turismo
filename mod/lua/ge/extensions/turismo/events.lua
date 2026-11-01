-- Turismo Karriere - events
-- Race series ("Rennserien") grouped in halls: Einsteiger, Amateur, Profi,
-- Extrem, Langstrecke, Marken-Cups, Regional-Cups, Rallye/Gelände, Spezial.
-- A series is either a championship (points over all races, one season
-- field) or a set of single races (each with its own trophy).

local M = {}

local function U() return extensions.turismo_util end
local function S() return extensions.turismo_save end
local function D() return extensions.turismo_data end
local function VDB() return extensions.turismo_vehicleDb end
local function G() return extensions.turismo_garage end
local function P() return extensions.turismo_profile end
local function LIC() return extensions.turismo_licenses end
local function AI() return extensions.turismo_aiDirector end

M.POINTS = { 10, 8, 6, 5, 4, 3, 2, 1 }

M.halls = {
  { id = 'einsteiger', name = 'Einsteiger-Liga', desc = 'Die ersten Pokale mit Alltagsautos.' },
  { id = 'amateur', name = 'Amateur-Liga', desc = 'Clubsport-Serien für getunte Straßenwagen.' },
  { id = 'profi', name = 'Profi-Liga', desc = 'Internationale Meisterschaften für Sport- und Rennwagen.' },
  { id = 'extrem', name = 'Extrem-Liga', desc = 'Die Königsklasse: GT- und Prototypen-Meisterschaften.' },
  { id = 'langstrecke', name = 'Langstrecke', desc = 'Ausdauer für Fahrer und Material. Schäden bleiben!' },
  { id = 'marken', name = 'Marken-Cups', desc = 'Markenpokale: nur Fahrzeuge eines Herstellers.' },
  { id = 'regional', name = 'Regional-Cups', desc = 'Japan, Europa, Amerika: Herkunft zählt.' },
  { id = 'gelaende', name = 'Rallye & Gelände', desc = 'Schotter, Matsch und Sprünge.' },
  { id = 'spezial', name = 'Spezial-Events', desc = 'Drift, Klassiker und besondere Herausforderungen.' },
}

M.defaults = {
  series = {},   -- seriesId -> {season, raceIndex, points={entryId=pts}, field={...}, done, results={}, trophies={raceIdx=pos}}
}

local function es() return S().get().events end

-- trophies are stored with string keys so sparse tables survive JSON round trips
local function trophy(st, i)
  if not st.trophies then return nil end
  return st.trophies[tostring(i)] or st.trophies[i]
end

local function seriesState(id)
  local st = es().series[id]
  if not st then
    st = { season = 1, raceIndex = 1, points = {}, results = {}, trophies = {}, done = false, won = false }
    es().series[id] = st
  end
  return st
end
M.seriesState = seriesState

---------------------------------------------------------------------------
-- availability & eligibility
---------------------------------------------------------------------------
function M.isAvailable(series)
  local req = series.requires or {}
  if req.license and not LIC().has(req.license) then
    return false, 'Benötigt ' .. (D().license(req.license) and D().license(req.license).name or ('Lizenz ' .. req.license))
  end
  if req.collectorLevel and P().collectorLevel() < req.collectorLevel then
    return false, 'Benötigt Sammlerstufe ' .. req.collectorLevel
  end
  for _, sid in ipairs(req.series or {}) do
    local st = es().series[sid]
    if not (st and st.done) then
      local s = D().series(sid)
      return false, 'Erst "' .. (s and s.name or sid) .. '" abschließen'
    end
  end
  if extensions.turismo_progression and not extensions.turismo_progression.isUnlocked('series_' .. series.id, series) then
    return false, 'Im Café freischalten'
  end
  return true
end

function M.isEligible(series, car)
  if not car then return false, 'Kein Fahrzeug gewählt' end
  local info = VDB().get(car.key)
  if not info then return false, 'Fahrzeug nicht installiert' end
  local li = G().effectiveLI(car)
  if not VDB().matches(info, series.eligibility, li) then
    return false, 'Erfüllt die Teilnahmebedingungen nicht: ' .. VDB().describeCriteria(series.eligibility)
  end
  return true
end

function M.eligibleCars(series)
  local res = {}
  for _, car in pairs(G().cars()) do
    if M.isEligible(series, car) then res[#res + 1] = car.id end
  end
  return res
end

---------------------------------------------------------------------------
-- field generation
---------------------------------------------------------------------------
local function driverPool(tiers)
  local res = {}
  for _, d in ipairs(D().get('drivers') or {}) do
    if not tiers or U().contains(tiers, d.tier) then res[#res + 1] = d end
  end
  return res
end

-- pure-ish: builds an AI field for a series (deterministic per seed)
function M.generateField(series, seed, playerLI)
  local f = series.field or {}
  local size = f.size or 7
  local rng = U().rng(seed)
  local drivers = driverPool(f.tiers)
  rng:shuffle(drivers)
  local target = f.liTarget or series.recommendedLI or playerLI or 400
  local spread = f.liSpread or 35
  local criteria = U().deepcopy(f.criteria or series.eligibility or {})
  criteria.liMin = math.max(criteria.liMin or 0, target - spread)
  criteria.liMax = math.min(criteria.liMax or 1000, target + math.floor(spread * 0.6))
  local pool = VDB().find(criteria)
  if #pool < 3 then
    -- widen the window when few cars match on this install
    criteria.liMin, criteria.liMax = target - spread * 3, target + spread * 2
    pool = VDB().find(criteria)
  end
  if #pool == 0 then pool = VDB().find(series.eligibility) end
  local field = {}
  local usedCars = {}
  for i = 1, size do
    local driver = drivers[((i - 1) % math.max(1, #drivers)) + 1] or { id = 'ai' .. i, name = 'Fahrer ' .. i, tier = 'amateur' }
    -- prefer unique cars, but allow duplicates in one-make cups
    local car
    for _ = 1, 6 do
      car = rng:pick(pool)
      if car and (not usedCars[car.key] or f.oneMake) then break end
    end
    if car then
      usedCars[car.key] = true
      local p = AI().resolveProfile(driver)
      field[#field + 1] = {
        entryId = driver.id, driver = driver, carKey = car.key,
        li = car.rating.li,
        paceScore = car.rating.li * (0.85 + 0.3 * p.skill),
      }
    end
  end
  return field
end

local function seasonField(series)
  local st = seriesState(series.id)
  if series.championship and st.field and #st.field > 0 then return st.field end
  local seed = U().hashString(series.id) + st.season * 977 + (series.championship and 0 or P().day() * 31)
  local field = M.generateField(series, seed)
  if series.championship then st.field = field S().markDirty() end
  return field
end

---------------------------------------------------------------------------
-- starting a race
---------------------------------------------------------------------------
-- opts: { carId, raceIndex (single-race series), format ('quick'|'weekend') }
function M.startRace(seriesId, opts)
  opts = opts or {}
  local series = D().series(seriesId)
  if not series then return false, 'Unbekannte Serie' end
  local ok, why = M.isAvailable(series)
  if not ok then return false, why end
  local car = G().get(opts.carId) or G().active()
  ok, why = M.isEligible(series, car)
  if not ok then return false, why end
  G().setActive(car.id)

  local st = seriesState(series.id)
  local idx = series.championship and st.raceIndex or (opts.raceIndex or 1)
  local raceDef = series.races[idx]
  if not raceDef then return false, 'Rennen nicht gefunden' end
  local etype = raceDef.type or series.type or 'circuit'
  local meta = S().get().meta
  local function finisher(results) return M.onRaceFinished(series, idx, results, car.id) end
  local title = series.name .. (raceDef.name and (' - ' .. raceDef.name) or (' - Lauf ' .. idx))
  local eventRef = series.id .. '#' .. idx .. '#' .. st.season

  -- event types that do not need a race file
  if etype == 'drag' then
    return extensions.turismo_drag.start({
      title = title, eventRef = eventRef, level = raceDef.level or series.level or 'west_coast_usa',
      stripFile = raceDef.stripFile, distance = raceDef.distance or series.distance or 402.34,
      tree = series.tree or 'sportsman', bracket = series.bracket, qualifyingRuns = series.qualifyingRuns or 2,
      field = U().deepcopy(seasonField(series)), playerCarId = car.id, difficulty = meta.difficulty, onFinish = finisher,
    })
  elseif etype == 'derby' then
    local venues = U().indexBy(D().get('venues') or {}, 'id')
    return extensions.turismo_modes.start({
      type = 'derby', title = title, eventRef = eventRef, arena = venues[raceDef.venue or series.venue or 'derby_arena'],
      field = U().deepcopy(seasonField(series)), playerCarId = car.id, difficulty = meta.difficulty,
      timeLimit = raceDef.timeLimit or series.timeLimit, onFinish = finisher,
    })
  elseif etype == 'crawl' then
    local def = U().deepcopy(raceDef.course and raceDef or series.course)
    def.id = series.id .. '_' .. idx
    def.name = title
    def.penaltyPerGate = def.penaltyPerGate or 30
    def.penaltyPerReset = def.penaltyPerReset or 60
    def.ignoreDamage = true
    def.car = { rental = false }
    local field = seasonField(series)
    return extensions.turismo_tests.start(def.id, { def = def, onResult = function(r)
      local par = raceDef.parTime or 180
      local rng = U().rng(U().hashString(eventRef) + P().day())
      local list = {}
      for _, f in ipairs(field) do
        local pr = AI().resolveProfile(f.driver, meta.difficulty)
        list[#list + 1] = { name = f.driver.name, driverId = f.driver.id, time = par * (1.25 - 0.35 * pr.skill) * (0.95 + rng:next() * 0.1) }
      end
      list[#list + 1] = { name = meta.playerName or 'Du', isPlayer = true, time = (not r.failed) and r.value or nil, dnf = r.failed }
      table.sort(list, function(a, b) return (a.time or math.huge) < (b.time or math.huge) end)
      for i, e in ipairs(list) do e.pos = i end
      return finisher({ list = list, mode = 'crawl', cleanRace = (r.penalty or 0) == 0 })
    end })
  end

  local track = extensions.turismo_tracks.resolve(raceDef.track, U().hashString(series.id .. idx))
  if not track then
    return false, 'Strecke "' .. tostring(raceDef.track) .. '" ist auf dieser Installation nicht vorhanden.'
  end
  if etype == 'timeAttack' or etype == 'touge' or etype == 'drift' or etype == 'trucking' then
    local field = U().deepcopy(seasonField(series))
    if etype == 'touge' then field = { field[1] } end
    return extensions.turismo_modes.start({
      type = etype, title = title, eventRef = eventRef, track = track,
      laps = raceDef.laps or series.laps, runs = raceDef.runs or series.runs,
      field = field, playerCarId = car.id, difficulty = meta.difficulty,
      trackFactor = (S().get().trackFactors or {})[track.id], timeLimit = raceDef.timeLimit or series.timeLimit,
      parScore = raceDef.parScore or series.parScore, budget = raceDef.budget or series.budget,
      targetTime = raceDef.targetTime, onFinish = finisher,
    })
  end

  local format = opts.format or series.format or 'quick'
  if format == 'choice' then format = 'quick' end
  if meta.hardcore then format = 'weekend' end
  local field = U().deepcopy(seasonField(series))
  local laps = raceDef.laps or series.laps or 3
  if meta.raceLength == 'short' then laps = math.max(1, math.floor(laps * 0.6 + 0.5)) end
  if meta.raceLength == 'long' then laps = math.floor(laps * 1.6 + 0.5) end

  local cfg = {
    title = title, eventRef = eventRef,
    elimination = etype == 'elimination', pursuitGap = etype == 'pursuit' and (raceDef.gap or series.gap or 3) or nil,
    track = track, laps = laps,
    format = format,
    -- hardcore: every circuit race gets the full ritual (formation lap + rolling start)
    startType = meta.hardcore and 'rolling' or raceDef.startType or series.startType or 'standing',
    practice = format == 'weekend' and (series.practice ~= false),
    qualifying = format == 'weekend',
    field = field, playerCarId = car.id,
    playerGrid = series.playerGrid or 'back',
    difficulty = meta.difficulty or 'normal',
    catchUp = (format == 'weekend' or meta.hardcore) and 'off' or (meta.catchUp or 'off'),
    skipIntro = meta.skipIntro,
    trackFactor = (S().get().trackFactors or {})[track.id],
    onFinish = finisher,
  }
  return extensions.turismo_race.start(cfg)
end

---------------------------------------------------------------------------
-- results
---------------------------------------------------------------------------
function M.prizeFor(series, pos)
  local list = (series.rewards and series.rewards.positions) or { 3000, 2000, 1500, 1000, 700, 500, 300, 200 }
  return list[pos] or 0
end

function M.onRaceFinished(series, idx, results, carId)
  local st = seriesState(series.id)
  local player
  for _, r in ipairs(results.list) do if r.isPlayer then player = r end end
  local pos = player and player.pos or #results.list
  local out = { position = pos, money = 0, bonus = {} }

  -- prize money (GT style: full prize first time a race is won, 1/3 afterwards
  -- for single races; championships always pay full)
  local prize = M.prizeFor(series, pos)
  if not series.championship and trophy(st, idx) == 1 then prize = math.floor(prize / 3) end
  if prize > 0 then P().earn(prize, series.name .. ': Platz ' .. pos, 'race') out.money = prize end
  if results.cleanRace and pos <= 3 then
    local bonus = math.floor(prize * 0.1)
    if bonus > 0 then P().earn(bonus, 'Saubere-Fahrt-Bonus', 'race') out.bonus[#out.bonus + 1] = { name = 'Saubere Fahrt', money = bonus } end
  end

  local stats = S().get().stats
  if pos == 1 then stats.racesWon = (stats.racesWon or 0) + 1 end
  if pos <= 3 then stats.podiums = (stats.podiums or 0) + 1 end

  local car = G().get(carId)
  if car then G().recordRace(car, { day = P().day(), series = series.id, race = idx, position = pos }) end

  -- trophies for single races
  if not trophy(st, idx) or pos < trophy(st, idx) then st.trophies[tostring(idx)] = pos end

  if series.championship then
    for _, r in ipairs(results.list) do
      local key = r.isPlayer and 'player' or (r.driverId or r.name)
      st.points[key] = (st.points[key] or 0) + (M.POINTS[r.pos] or 0)
    end
    table.insert(st.results, { race = idx, position = pos })
    st.raceIndex = st.raceIndex + 1
    if st.raceIndex > #series.races then
      out.championship = M.finishChampionship(series, st)
    end
  else
    local allWon = true
    for i = 1, #series.races do if trophy(st, i) ~= 1 then allWon = false end end
    local allPodium = true
    for i = 1, #series.races do if not trophy(st, i) or trophy(st, i) > 3 then allPodium = false end end
    if allPodium and not st.done then
      st.done = true
      out.seriesComplete = true
    end
    if allWon and not st.won then
      st.won = true
      out.seriesWon = true
      out.prizeCar = M.grantPrizeCar(series)
    end
  end

  -- "Bonuslos" for wins in higher halls
  if pos == 1 and series.rewards and series.rewards.ticketTier then
    P().grantTicket(series.rewards.ticketTier, series.name)
    out.ticket = series.rewards.ticketTier
  end

  -- self-calibrating lap time model: remember how fast this track really is
  M.learnTrackFactor(results, series)

  P().advanceDay(series.dayCost or 1)
  S().markDirty()
  if extensions.hook then extensions.hook('onTurismoRaceResult', series.id, idx, pos, results) end
  return out
end

function M.finishChampionship(series, st)
  local standings = {}
  for key, pts in pairs(st.points) do standings[#standings + 1] = { key = key, points = pts } end
  table.sort(standings, function(a, b) return a.points > b.points end)
  local playerPos = #standings
  for i, s in ipairs(standings) do if s.key == 'player' then playerPos = i end end
  local res = { position = playerPos, standings = standings }
  if playerPos <= 3 then st.done = true end
  if playerPos == 1 then
    st.won = true
    local money = series.rewards and series.rewards.championship and series.rewards.championship.money or 0
    if money > 0 then P().earn(money, series.name .. ': Meisterschaft', 'race') res.money = money end
    res.prizeCar = M.grantPrizeCar(series)
  end
  -- new season
  st.season = st.season + 1
  st.raceIndex = 1
  st.points = {}
  st.field = nil
  st.results = {}
  return res
end

function M.grantPrizeCar(series)
  local pc = series.rewards and (series.rewards.car or (series.rewards.championship and series.rewards.championship.car))
  if not pc then return nil end
  local info
  if type(pc) == 'string' then info = VDB().get(pc) end
  if not info then
    info = VDB().pick(type(pc) == 'table' and pc or series.eligibility, U().hashString(series.id .. 'prize'))
  end
  if not info then return nil end
  local car = G().addCar(info.key, { source = 'Preis: ' .. series.name })
  return car and info.name
end

function M.learnTrackFactor(results, series)
  local race = extensions.turismo_race.context()
  if not race or not race.poly then return end
  local trackId = race.cfg.track.id
  local factors = S().get().trackFactors or {}
  S().get().trackFactors = factors
  local samples = {}
  for _, r in ipairs(results.list) do
    if r.bestLap and r.bestLap > 10 then
      local entry
      for _, f in ipairs(race.cfg.field) do if f.driver.id == r.driverId then entry = f end end
      local li = entry and entry.li
      if r.isPlayer then
        local car = G().get(race.cfg.playerCarId)
        li = car and G().effectiveLI(car)
      end
      if li then
        local ref = AI().referenceLapTime(race.poly.len, li, 1)
        samples[#samples + 1] = r.bestLap / ref
      end
    end
  end
  if #samples == 0 then return end
  table.sort(samples)
  local median = samples[math.ceil(#samples / 2)]
  local old = factors[trackId]
  factors[trackId] = old and (old * 0.6 + median * 0.4) or median
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
function M.snapshot()
  local halls = {}
  local byHall = {}
  for _, h in ipairs(M.halls) do
    local entry = { id = h.id, name = h.name, desc = h.desc, series = {} }
    halls[#halls + 1] = entry
    byHall[h.id] = entry
  end
  for _, s in ipairs(D().get('events') or {}) do
    local avail, why = M.isAvailable(s)
    local st = es().series[s.id] or {}
    local races = {}
    for i, r in ipairs(s.races or {}) do
      local t, label, ok, level
      if r.track then
        t = extensions.turismo_tracks.resolve(r.track, U().hashString(s.id .. i))
        label, ok, level = t and t.name or 'Strecke fehlt (Diagnose prüfen)', t ~= nil, t and t.level
      else
        -- venue based event (drag strip, derby arena, crawl park)
        local venue = r.venue and U().indexBy(D().get('venues') or {}, 'id')[r.venue]
        label = (venue and venue.name) or r.level or 'Veranstaltungsort'
        ok, level = true, (venue and venue.level) or r.level
      end
      races[#races + 1] = {
        idx = i, name = r.name, laps = r.laps or s.laps or 3,
        track = label, trackOk = ok,
        level = level, trophy = st.trophies and trophy(st, i),
      }
    end
    local hall = byHall[s.hall] or byHall.spezial
    table.insert(hall.series, {
      id = s.id, name = s.name, desc = s.desc, championship = s.championship, type = s.type or 'circuit',
      requirement = VDB().describeCriteria(s.eligibility), eligibility = s.eligibility,
      recommendedLI = s.recommendedLI, difficulty = s.difficulty or 1,
      format = s.format or 'quick', startType = s.startType or 'standing',
      available = avail, reason = why, done = st.done, won = st.won,
      raceIndex = st.raceIndex or 1, season = st.season or 1, points = st.points,
      races = races, rewards = s.rewards, eligibleCars = avail and M.eligibleCars(s) or {},
    })
  end
  return halls
end

function M.onExtensionLoaded()
  S().registerDefaults('events', M.defaults)
end

return M
