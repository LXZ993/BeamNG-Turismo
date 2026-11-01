-- Turismo Karriere - modes
-- Special event types beyond circuit racing:
--   timeAttack : Time Attack / Hillclimb / Rallye-Prüfung. Solo runs on a race
--                file; best lap (circuit) or run time (sprint) is ranked against
--                simulated rival times (same lap-time model as qualifying).
--   touge      : 1-gegen-1 on a mountain sprint. Run 1 the rival leads, run 2 you
--                lead. Score = your lead gap in run 2 minus your deficit in run 1.
--   drift      : drift scoring (angle x speed x combo) over laps / time limit,
--                ranked against rival scores.
--   derby      : Destruction Derby in an arena: AI cars hunt each other and you,
--                cars that stop moving are out, last car running wins.
--   trucking   : timed haul over a point-to-point route with a damage budget
--                ("Ladungsschaden"); payout drops with damage and lateness.
--   crawl      : handled by tests.lua (gate course with penalty seconds), ranked here.
-- All modes report back through cfg.onFinish(results) like race.lua.

local M = {}

local function U() return extensions.turismo_util end
local function AI() return extensions.turismo_aiDirector end
local function SES() return extensions.turismo_session end
local function P() return extensions.turismo_profile end

local X = nil -- running mode context

local function hud(name, data) if guihooks then guihooks.trigger(name, data) end end
local function toast(msg, kind) if extensions.hook then extensions.hook('onTurismoToast', msg, kind or 'info') end end
local function veh(id) return id and getObjectByID and getObjectByID(id) or nil end
local function damageOf(id)
  local m = map and map.objects and map.objects[id]
  return m and (m.damage or 0) or 0
end

function M.isActive() return X ~= nil end
function M.context() return X end

---------------------------------------------------------------------------
-- shared helpers
---------------------------------------------------------------------------
local function loadPath(track)
  local path = require('/lua/ge/extensions/gameplay/race/path')('Turismo')
  path:onDeserialized(jsonReadFile(track.file))
  path:autoConfig()
  return path
end

local function soloRace(path, ids, laps)
  local race = require('/lua/ge/extensions/gameplay/race/race')()
  race:setPath(path)
  race.lapCount = laps
  race.useHotlappingApp = false
  race.useWaypointAudio = false
  race:setVehicleIds(ids)
  return race
end

local function trackLength(path)
  local len, prev = 0, nil
  for _, pn in ipairs(path.pathnodes.sorted) do
    if prev then len = len + prev:distance(pn.pos) end
    prev = vec3(pn.pos)
  end
  return len
end

local function freeze(id, on) local v = veh(id) if v then v:queueLuaCommand('controller.setFreeze(' .. (on and 1 or 0) .. ')') end end

-- simulated rivals (pure-ish)
function M.rivalTimes(field, lengthM, trackFactor, seed, difficulty)
  local rng = U().rng(seed)
  local res = {}
  for _, f in ipairs(field or {}) do
    local info = extensions.turismo_vehicleDb.get(f.carKey)
    local li = info and info.rating.li or f.li or 400
    res[#res + 1] = {
      name = f.driver.name, car = info and info.name or f.carKey, driverId = f.driver.id,
      time = AI().simulatedLapTime(f.driver, lengthM, li, trackFactor, rng, difficulty),
    }
  end
  return res
end

local function rankByTime(entries)
  table.sort(entries, function(a, b) return (a.time or math.huge) < (b.time or math.huge) end)
  for i, e in ipairs(entries) do e.pos = i end
  return entries
end

local function finish(results)
  local cfg = X.cfg
  X.phase = 'results'
  SES().capturePlayerCar(function()
    local out = cfg.onFinish and cfg.onFinish(results) or {}
    results.rewards = out
    hud('TurismoRaceResults', results)
    if extensions.turismo_audio then extensions.turismo_audio.play('race_finish') end
  end)
end

local function countdownThen(seconds, fn)
  X.countdown = seconds
  X.afterCountdown = fn
  X.lastCount = nil
end

---------------------------------------------------------------------------
-- start (dispatch)
---------------------------------------------------------------------------
-- cfg: { type, title, track, laps, runs, field, playerCarId, timeLimit, parScore,
--        difficulty, trackFactor, onFinish, arena (venue), budget (trucking) }
function M.start(cfg)
  if X then M.abort() end
  X = { cfg = cfg, phase = 'loading', time = 0, hudTimer = 0 }
  local level = cfg.track and cfg.track.level or (cfg.arena and cfg.arena.level)
  SES().loadLevel(level, function()
    local fn = M['_setup_' .. cfg.type]
    if not fn then
      toast('Unbekannter Event-Typ: ' .. tostring(cfg.type), 'error')
      X = nil
      return
    end
    local ok, err = pcall(fn)
    if not ok then
      U().log('E', 'modes: setup failed: %s', tostring(err))
      toast('Event konnte nicht gestartet werden.', 'error')
      X = nil
    end
  end)
  return true
end

local function spawnPlayerAtSlot(slot, cb)
  SES().spawnPlayerCar(X.cfg.playerCarId, { startPosition = slot }, function(id)
    X.playerId = id
    X.damage0 = damageOf(id)
    freeze(id, true)
    cb(id)
  end)
end

---------------------------------------------------------------------------
-- time attack / hillclimb / rally stage
---------------------------------------------------------------------------
function M._setup_timeAttack()
  local cfg = X.cfg
  X.path = loadPath(cfg.track)
  X.closed = X.path.config.closed
  X.len = trackLength(X.path)
  X.runsLeft = cfg.runs or (X.closed and 1 or 2)
  X.best = nil
  X.runTimes = {}
  local slot = X.path.startPositions.sorted[1]
  spawnPlayerAtSlot(slot, function(id)
    X.slot = slot
    M._timeAttackRun()
  end)
end

function M._timeAttackRun()
  local cfg = X.cfg
  X.phase = 'countdown'
  if X.runTimes[1] then X.slot:moveResetVehicleTo(X.playerId, false, false) freeze(X.playerId, true) end
  local laps = X.closed and (cfg.laps or 3) or 1
  X.race = soloRace(X.path, { X.playerId }, laps)
  hud('TurismoRacePhase', { phase = 'timeAttack', title = cfg.title, run = #X.runTimes + 1, runs = cfg.runs or (X.closed and 1 or 2) })
  countdownThen(3.5, function()
    X.phase = 'running'
    X.runStart = X.time
    X.race:startRace()
    freeze(X.playerId, false)
  end)
end

function M._update_timeAttack(dt, dtReal)
  if X.phase ~= 'running' then return end
  X.race:onUpdate(dt)
  local st = X.race.states[X.playerId]
  if X.cfg.timeLimit and X.time - X.runStart > X.cfg.timeLimit then st.complete = true st.dnf = true end
  if st and st.complete then
    local best
    for _, l in ipairs(st.historicTimes or {}) do
      local v = X.closed and l.duration or nil
      if v and (not best or v < best) then best = v end
    end
    if not X.closed then best = st.endTime end
    if st.dnf then best = nil end
    X.runTimes[#X.runTimes + 1] = best or false
    if best and (not X.best or best < X.best) then X.best = best end
    X.runsLeft = X.runsLeft - 1
    if X.runsLeft > 0 then
      toast(string.format('Lauf beendet: %s. Nächster Lauf startet gleich.', best and U().formatTime(best) or 'ungültig'), 'info')
      X.phase = 'between'
      X.betweenEnd = X.time + 4
    else
      local entries = M.rivalTimes(X.cfg.field, X.len, X.cfg.trackFactor, U().hashString(X.cfg.eventRef or 'ta') + P().day(), X.cfg.difficulty)
      local car = extensions.turismo_garage.get(X.cfg.playerCarId)
      entries[#entries + 1] = { name = extensions.turismo_save.get().meta.playerName or 'Du', car = car and car.name, isPlayer = true, time = X.best, bestLap = X.best }
      rankByTime(entries)
      if X.best then P().recordBestLap(X.cfg.track.id, X.best, car and car.name) end
      finish({ list = entries, mode = 'timeAttack', runs = X.runTimes, cleanRace = damageOf(X.playerId) - X.damage0 < 500 })
    end
  end
  X.hudTimer = X.hudTimer + dtReal
  if X.hudTimer > 0.1 and st then
    X.hudTimer = 0
    local lapTime = 0
    if st.currentTimes and st.currentTimes[1] then lapTime = X.race.time - st.currentTimes[1].beginTime end
    hud('TurismoHud', { phase = 'timeAttack', lap = (st.currentLap or 0) + 1, laps = X.race.lapCount,
      lapTime = X.closed and lapTime or X.race.time, bestLap = X.best, pos = nil, total = nil })
  end
end

---------------------------------------------------------------------------
-- touge (cat & mouse, 2 runs)
---------------------------------------------------------------------------
function M._setup_touge()
  local cfg = X.cfg
  X.path = loadPath(cfg.track)
  local slots = X.path.startPositions.sorted
  if #slots < 2 then
    local base = slots[1]
    local fwd = base.rot * vec3(0, 1, 0)
    local sp = X.path.startPositions:create('Touge 2')
    sp:set(base.pos - fwd * 12, base.rot)
    slots = X.path.startPositions.sorted
  end
  X.slots = { slots[1], slots[2] }
  X.rival = cfg.field[1]
  X.run = 0
  X.score = {}
  spawnPlayerAtSlot(X.slots[2], function()
    local model, config = U().splitCarKey(X.rival.carKey)
    local v = core_vehicles.spawnNewVehicle(model, { config = 'vehicles/' .. model .. '/' .. (config or 'base') .. '.pc',
      pos = X.slots[1].pos + vec3(0, 0, 0.5), rot = quatFromEuler(0, 0, math.pi) * X.slots[1].rot, autoEnterVehicle = false })
    X.rivalId = v:getID()
    SES().defer(1.5, function() M._tougeRun() end)
  end)
end

function M._tougeRun()
  X.run = X.run + 1
  local playerLeads = (X.run == 2)
  local leadSlot, chaseSlot = X.slots[1], X.slots[2]
  X.slots[1]:moveResetVehicleTo(playerLeads and X.playerId or X.rivalId, false, not playerLeads)
  X.slots[2]:moveResetVehicleTo(playerLeads and X.rivalId or X.playerId, false, playerLeads)
  freeze(X.playerId, true)
  freeze(X.rivalId, true)
  AI().begin({ difficulty = X.cfg.difficulty, surface = X.cfg.track.surface, seed = U().hashString('touge') + X.run })
  local race = soloRace(X.path, { X.playerId, X.rivalId }, 1)
  local aiPath = race.aiPath
  local drive
  if aiPath and #aiPath > 1 then drive = { wpTargetList = aiPath } else
    local script = {}
    for _, pn in ipairs(X.path.pathnodes.sorted) do script[#script + 1] = { x = pn.pos.x, y = pn.pos.y, z = pn.pos.z } end
    drive = { script = script }
  end
  AI().addRacer(X.rivalId, X.rival.driver, drive)
  AI().prepare(X.rivalId)
  X.race = race
  X.phase = 'countdown'
  hud('TurismoRacePhase', { phase = 'touge', run = X.run, playerLeads = playerLeads, title = X.cfg.title })
  toast(playerLeads and 'Lauf 2: Du führst. Fahr ihm davon!' or 'Lauf 1: Bleib dran! Jeder Meter Rückstand zählt.', 'info')
  countdownThen(3.5, function()
    X.phase = 'running'
    race:startRace()
    freeze(X.playerId, false)
    AI().release()
  end)
end

function M._update_touge(dt, dtReal)
  if X.phase ~= 'running' then return end
  X.race:onUpdate(dt)
  local ctx = {}
  for _, id in ipairs({ X.playerId, X.rivalId }) do
    local v = veh(id)
    if v then ctx[id] = { speed = v:getVelocity():length(), finished = X.race.states[id] and X.race.states[id].complete } end
  end
  AI().update(dtReal, ctx)
  local ps, rs = X.race.states[X.playerId], X.race.states[X.rivalId]
  -- crash rule: big damage ends the run as a loss for that driver
  local crashed = damageOf(X.playerId) - X.damage0 > 3000
  if (ps and ps.complete and rs and rs.complete) or crashed or X.race.time > (X.cfg.timeLimit or 600) then
    local pt = ps and ps.complete and ps.endTime or math.huge
    local rt = rs and rs.complete and rs.endTime or math.huge
    if crashed then pt = math.huge end
    local playerLeads = X.run == 2
    -- positive = good for player
    local margin = playerLeads and (rt - pt) or (rt - pt) -- run1: deficit is negative margin
    if margin == math.huge then margin = 5 elseif margin == -math.huge then margin = -5 end
    X.score[X.run] = U().clamp(margin, -5, 5)
    AI().stop()
    if X.run < 2 then
      X.phase = 'between'
      X.betweenEnd = X.time + 4
      toast(string.format('Lauf 1: %+.2f s', X.score[1]), 'info')
    else
      local total = X.score[1] + X.score[2]
      local win = total > 0
      local car = extensions.turismo_garage.get(X.cfg.playerCarId)
      local info = extensions.turismo_vehicleDb.get(X.rival.carKey)
      local list = {
        { name = extensions.turismo_save.get().meta.playerName or 'Du', car = car and car.name, isPlayer = true, score = total },
        { name = X.rival.driver.name, car = info and info.name, driverId = X.rival.driver.id, score = -total },
      }
      table.sort(list, function(a, b) return a.score > b.score end)
      for i, e in ipairs(list) do e.pos = i end
      local v = veh(X.rivalId) if v then v:delete() end
      finish({ list = list, mode = 'touge', runs = X.score, total = total, win = win, cleanRace = not crashed })
    end
  end
  X.hudTimer = X.hudTimer + dtReal
  if X.hudTimer > 0.1 then
    X.hudTimer = 0
    local pv, rv = veh(X.playerId), veh(X.rivalId)
    local gap = (pv and rv) and pv:getPosition():distance(rv:getPosition()) or nil
    hud('TurismoModeHud', { mode = 'touge', run = X.run, gapM = gap, playerLeads = X.run == 2, score = X.score })
  end
end

---------------------------------------------------------------------------
-- drift
---------------------------------------------------------------------------
-- pure: score increment for one frame
function M.driftStep(angleDeg, speedMs, dt, combo)
  if speedMs < 8 or angleDeg < 12 or angleDeg > 100 then return 0 end
  return (angleDeg - 10) * speedMs * dt * 0.5 * combo
end

function M._setup_drift()
  local cfg = X.cfg
  X.path = loadPath(cfg.track)
  X.len = trackLength(X.path)
  X.score, X.pending, X.combo, X.calmTime = 0, 0, 1, 0
  X.best = 0
  local slot = X.path.startPositions.sorted[1]
  spawnPlayerAtSlot(slot, function()
    X.race = soloRace(X.path, { X.playerId }, X.path.config.closed and (cfg.laps or 2) or 1)
    X.phase = 'countdown'
    hud('TurismoRacePhase', { phase = 'drift', title = cfg.title })
    countdownThen(3.5, function()
      X.phase = 'running'
      X.race:startRace()
      freeze(X.playerId, false)
      X.runStart = X.time
      X.dmgDrift = damageOf(X.playerId)
    end)
  end)
end

function M._update_drift(dt, dtReal)
  if X.phase ~= 'running' then return end
  X.race:onUpdate(dt)
  local v = veh(X.playerId)
  if not v then return end
  local vel, dir = v:getVelocity(), v:getDirectionVector()
  local speed = vel:length()
  local angle = 0
  if speed > 3 then
    local a = vec3(vel.x, vel.y, 0):normalized()
    local b = vec3(dir.x, dir.y, 0):normalized()
    angle = math.deg(math.acos(U().clamp(a:dot(b), -1, 1)))
  end
  local add = M.driftStep(angle, speed, dt, X.combo)
  if add > 0 then
    X.pending = X.pending + add
    X.combo = math.min(5, X.combo + dt * 0.12)
    X.calmTime = 0
  else
    X.calmTime = X.calmTime + dt
    if X.calmTime > 0.8 and X.pending > 0 then
      X.score = X.score + X.pending   -- bank the drift chain
      X.pending, X.combo = 0, 1
    end
  end
  if angle > 110 and speed > 5 then X.pending, X.combo = 0, 1 end -- spin
  if damageOf(X.playerId) - X.dmgDrift > 250 then X.pending, X.combo = 0, 1 X.dmgDrift = damageOf(X.playerId) end -- crash
  local st = X.race.states[X.playerId]
  local timeUp = X.cfg.timeLimit and (X.time - X.runStart) > X.cfg.timeLimit
  if (st and st.complete) or timeUp then
    X.score = math.floor(X.score + X.pending)
    local par = X.cfg.parScore or 20000
    local rng = U().rng(U().hashString(X.cfg.eventRef or 'drift') + P().day())
    local list = {}
    for _, f in ipairs(X.cfg.field or {}) do
      local p = AI().resolveProfile(f.driver, X.cfg.difficulty)
      list[#list + 1] = { name = f.driver.name, driverId = f.driver.id, score = math.floor(par * (0.55 + 0.55 * p.skill) * (0.92 + rng:next() * 0.16)) }
    end
    local car = extensions.turismo_garage.get(X.cfg.playerCarId)
    list[#list + 1] = { name = extensions.turismo_save.get().meta.playerName or 'Du', car = car and car.name, isPlayer = true, score = X.score }
    table.sort(list, function(a, b) return a.score > b.score end)
    for i, e in ipairs(list) do e.pos = i end
    finish({ list = list, mode = 'drift', score = X.score, cleanRace = true })
    return
  end
  X.hudTimer = X.hudTimer + dtReal
  if X.hudTimer > 0.1 then
    X.hudTimer = 0
    hud('TurismoModeHud', { mode = 'drift', score = math.floor(X.score), pending = math.floor(X.pending), combo = X.combo,
      angle = angle, remaining = X.cfg.timeLimit and math.max(0, X.cfg.timeLimit - (X.time - X.runStart)) or nil })
  end
end

---------------------------------------------------------------------------
-- destruction derby
---------------------------------------------------------------------------
function M._setup_derby()
  local cfg = X.cfg
  local anchor = SES().venueAnchor(cfg.arena)
  if not anchor then error('no arena anchor') end
  local center = vec3(anchor.pos.x, anchor.pos.y, anchor.pos.z)
  local n = #cfg.field + 1
  local radius = cfg.arena.radius or 28
  X.cars = {}
  X.alive = {}
  local function slotTransform(i)
    local a = (i - 1) / n * math.pi * 2
    local pos = center + vec3(math.cos(a), math.sin(a), 0) * radius
    local dirIn = (center - pos):normalized()
    return pos, dirIn
  end
  local pos, dir = slotTransform(1)
  SES().spawnPlayerCar(cfg.playerCarId, { pos = pos + dir * 2.4, rot = quatFromDir(dir, vec3(0, 0, 1)) }, function(id)
    X.playerId = id
    freeze(id, true)
    X.alive[id] = { last = veh(id):getPosition(), still = 0, name = extensions.turismo_save.get().meta.playerName or 'Du', isPlayer = true }
    for i, f in ipairs(cfg.field) do
      local p, d = slotTransform(i + 1)
      local model, config = U().splitCarKey(f.carKey)
      local ok, v = pcall(core_vehicles.spawnNewVehicle, model, { config = 'vehicles/' .. model .. '/' .. (config or 'base') .. '.pc',
        pos = p + vec3(0, 0, 0.5), rot = quatFromEuler(0, 0, math.pi) * quatFromDir(d, vec3(0, 0, 1)), autoEnterVehicle = false })
      if ok and v then
        local vid = v:getID()
        X.cars[#X.cars + 1] = vid
        X.alive[vid] = { last = p, still = 0, name = f.driver.name, driver = f.driver }
      end
    end
    X.order = {}
    X.phase = 'countdown'
    hud('TurismoRacePhase', { phase = 'derby', title = cfg.title, cars = n })
    countdownThen(4.5, function()
      X.phase = 'running'
      X.runStart = X.time
      freeze(X.playerId, false)
      for _, vid in ipairs(X.cars) do
        local d = X.alive[vid].driver
        local p = AI().resolveProfile(d, cfg.difficulty)
        local v = veh(vid)
        if v then
          v:queueLuaCommand('controller.setFreeze(0)')
          v:queueLuaCommand('ai.setMode("chase")')
          v:queueLuaCommand(string.format('ai.setAggression(%.2f)', 0.7 + 0.3 * p.aggression))
          v:queueLuaCommand('ai.setAvoidCars("off")')
        end
        X.alive[vid].retarget = 0
      end
    end)
  end)
end

local function pickTarget(vid, rng)
  local candidates = {}
  for id in pairs(X.alive) do if id ~= vid then candidates[#candidates + 1] = id end end
  if #candidates == 0 then return nil end
  -- the player is a popular target
  if X.alive[X.playerId] and rng:next() < 0.4 then return X.playerId end
  return rng:pick(candidates)
end

function M._update_derby(dt, dtReal)
  if X.phase ~= 'running' then return end
  X.rng = X.rng or U().rng(os.time())
  local elapsed = X.time - X.runStart
  for id, a in pairs(X.alive) do
    local v = veh(id)
    if not v then
      X.alive[id] = nil
      table.insert(X.order, 1, { id = id, name = a.name, isPlayer = a.isPlayer })
    else
      local pos = v:getPosition()
      local moved = pos:distance(a.last)
      a.last = pos
      if moved < 0.03 then a.still = a.still + dt else a.still = math.max(0, a.still - dt * 2) end
      if a.retarget then
        a.retarget = a.retarget - dtReal
        if a.retarget <= 0 then
          a.retarget = 6 + X.rng:next() * 6
          local t = pickTarget(id, X.rng)
          if t then v:queueLuaCommand('ai.setTargetObjectID(' .. t .. ') ai.setMode("chase")') end
        end
      end
      if elapsed > 10 and a.still > (X.cfg.outTime or 15) then
        X.alive[id] = nil
        table.insert(X.order, 1, { id = id, name = a.name, isPlayer = a.isPlayer, driverId = a.driver and a.driver.id })
        if not a.isPlayer then v:queueLuaCommand('ai.setMode("disabled")') end
        toast(a.isPlayer and 'Du bist raus!' or (a.name .. ' ist raus!'), a.isPlayer and 'error' or 'info')
      end
    end
  end
  local aliveCount = U().count(X.alive)
  local playerOut = not X.alive[X.playerId]
  local timeUp = elapsed > (X.cfg.timeLimit or 300)
  if aliveCount <= 1 or playerOut or timeUp then
    -- remaining cars ranked by least damage
    local rest = {}
    for id, a in pairs(X.alive) do rest[#rest + 1] = { id = id, name = a.name, isPlayer = a.isPlayer, dmg = damageOf(id), driverId = a.driver and a.driver.id } end
    table.sort(rest, function(a, b) return a.dmg < b.dmg end)
    local list = {}
    for _, e in ipairs(rest) do list[#list + 1] = e end
    for _, e in ipairs(X.order) do list[#list + 1] = e end
    for i, e in ipairs(list) do e.pos = i end
    for _, vid in ipairs(X.cars) do local v = veh(vid) if v then v:delete() end end
    finish({ list = list, mode = 'derby', cleanRace = false })
    return
  end
  X.hudTimer = X.hudTimer + dtReal
  if X.hudTimer > 0.25 then
    X.hudTimer = 0
    hud('TurismoModeHud', { mode = 'derby', alive = aliveCount, total = #X.cars + 1, remaining = math.max(0, (X.cfg.timeLimit or 300) - elapsed),
      stillWarning = X.alive[X.playerId] and X.alive[X.playerId].still > 5 })
  end
end

---------------------------------------------------------------------------
-- trucking (haul on a sprint route)
---------------------------------------------------------------------------
function M._setup_trucking()
  local cfg = X.cfg
  X.path = loadPath(cfg.track)
  X.len = trackLength(X.path)
  local slot = X.path.startPositions.sorted[1]
  spawnPlayerAtSlot(slot, function()
    X.race = soloRace(X.path, { X.playerId }, 1)
    X.phase = 'countdown'
    X.targetTime = cfg.targetTime or (X.len / 16) -- ~58 km/h average
    hud('TurismoRacePhase', { phase = 'trucking', title = cfg.title, targetTime = X.targetTime, budget = cfg.budget })
    countdownThen(3.5, function()
      X.phase = 'running'
      X.race:startRace()
      freeze(X.playerId, false)
    end)
  end)
end

function M._update_trucking(dt, dtReal)
  if X.phase ~= 'running' then return end
  X.race:onUpdate(dt)
  local st = X.race.states[X.playerId]
  local cargoDamage = damageOf(X.playerId) - X.damage0
  local budget = X.cfg.budget or 4000
  if cargoDamage > budget then
    toast('Ladung zerstört! Auftrag gescheitert.', 'error')
    finish({ list = { { pos = 2, name = 'Du', isPlayer = true, dnf = true } }, mode = 'trucking', failed = true })
    return
  end
  if st and st.complete then
    local t = st.endTime
    local timeFactor = U().remap(t, X.targetTime, X.targetTime * 1.5, 1, 0.3)
    local damageFactor = 1 - cargoDamage / budget
    local grade = timeFactor * 0.6 + damageFactor * 0.4
    local pos = grade > 0.85 and 1 or (grade > 0.65 and 2 or (grade > 0.45 and 3 or 4))
    finish({ list = { { pos = pos, name = 'Du', isPlayer = true, time = t } }, mode = 'trucking', grade = grade,
      timeFactor = timeFactor, damageFactor = damageFactor, cleanRace = cargoDamage < budget * 0.1 })
    return
  end
  X.hudTimer = X.hudTimer + dtReal
  if X.hudTimer > 0.2 then
    X.hudTimer = 0
    hud('TurismoModeHud', { mode = 'trucking', time = X.race.time, target = X.targetTime, cargo = 1 - cargoDamage / budget })
  end
end

---------------------------------------------------------------------------
-- update / leave
---------------------------------------------------------------------------
function M.update(dtReal, dtSim)
  if not X or X.phase == 'loading' or X.phase == 'results' then return end
  local dt = dtSim or dtReal
  X.time = X.time + dt
  if X.countdown then
    X.countdown = X.countdown - dtReal
    local c = math.ceil(X.countdown)
    if c ~= X.lastCount then
      X.lastCount = c
      if c <= 3 and c >= 1 then
        hud('TurismoCountdown', { value = c })
        if extensions.turismo_audio then extensions.turismo_audio.play('count') end
      end
    end
    if X.countdown <= 0 then
      X.countdown = nil
      hud('TurismoCountdown', { value = 0, green = true })
      if extensions.turismo_audio then extensions.turismo_audio.play('race_go') end
      local fn = X.afterCountdown
      X.afterCountdown = nil
      if fn then fn() end
    end
    return
  end
  if X.phase == 'between' then
    if X.time >= X.betweenEnd then
      if X.cfg.type == 'touge' then M._tougeRun() else M._timeAttackRun() end
    end
    return
  end
  local fn = M['_update_' .. X.cfg.type]
  if fn then
    local ok, err = pcall(fn, dt, dtReal)
    if not ok then U().log('E', 'modes: update failed: %s', tostring(err)) end
  end
end

function M.abort()
  if not X then return end
  AI().stop()
  for _, vid in ipairs(X.cars or {}) do local v = veh(vid) if v then v:delete() end end
  if X.rivalId then local v = veh(X.rivalId) if v then v:delete() end end
  X = nil
  hud('TurismoRacePhase', { phase = 'idle' })
end

function M.close()
  M.abort()
  SES().returnToHub()
end

function M.restart()
  if not X then return end
  local cfg = X.cfg
  M.abort()
  SES().reloadPlayerCar(function() M.start(cfg) end)
end

return M
