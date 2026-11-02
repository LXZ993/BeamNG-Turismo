-- Turismo Karriere - race
-- Race weekend runtime on top of BeamNG's own race classes
-- (/lua/ge/extensions/gameplay/race/race + path).
--
-- Formats:
--   quick   : intro camera -> grid -> countdown -> race -> results
--   weekend : [practice] -> qualifying (player hot laps, AI simulated) ->
--             intro camera -> formation lap behind pace car -> rolling start
--             (or standing start) -> race -> results
-- Phases: idle, loading, spawning, practice, qualifying, intro, grid, countdown,
--         formation, racing, cooldown, results

local M = {}

local function U() return extensions.turismo_util end
local function AI() return extensions.turismo_aiDirector end
local function SES() return extensions.turismo_session end
local function G() return extensions.turismo_garage end
local function P() return extensions.turismo_profile end

local R = nil -- current race context

M.HUD_RATE = 0.1
M.COOLDOWN_TIME = 25
M.PACE_SPEED = 22 -- m/s during formation lap (~80 km/h)

local function hud(name, data) if guihooks then guihooks.trigger(name, data) end end
local function toast(msg, kind) if extensions.hook then extensions.hook('onTurismoToast', msg, kind or 'info') end end
local function veh(id) return id and getObjectByID and getObjectByID(id) or nil end

function M.isActive() return R ~= nil end
function M.context() return R end

---------------------------------------------------------------------------
-- track geometry helpers (own progress measure, independent of navgraph)
---------------------------------------------------------------------------
local function buildPolyline(path)
  local pts = {}
  local cfg = path.config
  -- follow the linear chain of segments from the start node
  local seg = cfg.graph and cfg.startSegments and cfg.graph[cfg.startSegments[1]]
  if seg then
    pts[#pts + 1] = vec3(path.pathnodes.objects[path.startNode].pos)
    local guard = 0
    while seg and guard < 2000 do
      guard = guard + 1
      pts[#pts + 1] = vec3(path.pathnodes.objects[seg.targetNode].pos)
      if seg.lastInLap then break end
      seg = cfg.graph[seg.successors[1]]
    end
  else
    for _, pn in ipairs(path.pathnodes.sorted) do pts[#pts + 1] = vec3(pn.pos) end
  end
  local cum = { 0 }
  for i = 2, #pts do cum[i] = cum[i - 1] + pts[i]:distance(pts[i - 1]) end
  return pts, cum, cum[#cum] or 0
end

-- distance along polyline of the closest point to pos; uses a search window around hint
local function projectProgress(poly, pos, hint)
  local pts, cum = poly.pts, poly.cum
  local n = #pts
  if n < 2 then return 0, 1 end
  local best, bestIdx, bestX = math.huge, hint or 1, 0
  local from, to = 1, n - 1
  if hint then from, to = math.max(1, hint - 3), math.min(n - 1, hint + 4) end
  for i = from, to do
    local a, b = pts[i], pts[i + 1]
    local ab = b - a
    local len2 = ab:squaredLength()
    local x = len2 > 0 and U().clamp((pos - a):dot(ab) / len2, 0, 1) or 0
    local d = (a + ab * x):squaredDistance(pos)
    if d < best then best, bestIdx, bestX = d, i, x end
  end
  if hint and best > 60 * 60 then return projectProgress(poly, pos, nil) end
  return cum[bestIdx] + (cum[bestIdx + 1] - cum[bestIdx]) * bestX, bestIdx
end

---------------------------------------------------------------------------
-- grid
---------------------------------------------------------------------------
local function gridSlots(path, count)
  local slots = {}
  for _, sp in ipairs(U().startSlots(path)) do slots[#slots + 1] = sp end
  if #slots >= count or #slots == 0 then return slots end
  -- generate missing slots behind the last known slot (2-wide, staggered rows)
  local base = slots[1]
  local fwd = base.rot * vec3(0, 1, 0)
  local right = base.rot * vec3(1, 0, 0)
  for i = #slots + 1, count do
    local row = math.floor((i - 1) / 2)
    local side = ((i - 1) % 2 == 0) and -1 or 1
    local sp = path.startPositions:create('Gen ' .. i)
    sp:set(base.pos - fwd * (row * 8 + (side > 0 and 4 or 0)) + right * side * 2.6, base.rot)
    slots[#slots + 1] = sp
  end
  return slots
end

-- fallback slot when the race file has no start positions: 30 m before first node
local function syntheticSlot(path, poly)
  local a, b = poly.pts[1], poly.pts[2]
  local dir = (b - a):normalized()
  local sp = path.startPositions:create('Synthetic')
  sp:set(a - dir * 30, quatFromDir(dir, vec3(0, 0, 1)))
  return sp
end

---------------------------------------------------------------------------
-- setup
---------------------------------------------------------------------------
-- cfg: { title, eventRef, track (registry entry), laps, format, startType,
--        practice, qualifying, field = { {driver, carKey}... }, playerCarId,
--        playerGrid ('back'|'front'|number), difficulty, catchUp, damage,
--        timeOfDay, rewards = {positions = {...}}, onFinish = function(results) }
function M.start(cfg)
  if R then M.abort('restart') end
  local track = cfg.track
  if not track or not track.file then
    toast('Strecke nicht gefunden. Bitte Streckenliste aktualisieren.', 'error')
    return false
  end
  R = {
    cfg = cfg, phase = 'loading', time = 0, hudTimer = 0,
    vehIds = {}, ai = {}, names = {}, cars = {},
    playerId = nil, results = nil, standings = {},
    qualifying = { best = nil, laps = {} },
    progressHint = {}, lastLapTimes = {}, bestLapTimes = {},
    damageStart = 0,
  }
  hud('TurismoRacePhase', { phase = 'loading', title = cfg.title })
  SES().loadLevel(track.level, function() M._onLevelReady() end)
  return true
end

function M._onLevelReady()
  if not R then return end
  local cfg = R.cfg
  local path = require('/lua/ge/extensions/gameplay/race/path')('Turismo')
  local okRead, json = pcall(jsonReadFile, cfg.track.file)
  if not okRead or not json then
    toast('Rennstrecke konnte nicht geladen werden: ' .. tostring(cfg.track.file), 'error')
    M.abort('track')
    return
  end
  path:onDeserialized(json)
  path:autoConfig()
  R.path = path
  local pts, cum, len = buildPolyline(path)
  R.poly = { pts = pts, cum = cum, len = len }
  R.closed = path.config.closed
  R.laps = R.closed and (cfg.laps or path.defaultLaps or 3) or 1

  if #U().startSlots(path) == 0 then syntheticSlot(path, R.poly) end
  local total = 1 + #(cfg.field or {})
  R.slots = gridSlots(path, total)
  if #R.slots < total then
    -- not enough room: shrink the field
    local keep = math.max(0, #R.slots - 1)
    while #cfg.field > keep do table.remove(cfg.field) end
    total = 1 + #cfg.field
  end

  R.phase = 'spawning'
  local first = R.slots[1]
  SES().spawnPlayerCar(cfg.playerCarId, { pos = first.pos, rot = first.rot }, function(vehId)
    R.playerId = vehId
    R.names[vehId] = extensions.turismo_save.get().meta.playerName or 'Du'
    local car = G().get(cfg.playerCarId)
    R.cars[vehId] = car and car.name or '?'
    local m = map and map.objects and map.objects[vehId]
    R.damageStart = m and m.damage or 0
    if cfg.format == 'weekend' and cfg.practice then
      M._startPractice()
    elseif cfg.format == 'weekend' and cfg.qualifying ~= false then
      M._startQualifying()
    else
      M._spawnField()
    end
  end)
end

---------------------------------------------------------------------------
-- practice & qualifying (player alone on track)
---------------------------------------------------------------------------
local function newRaceObject(ids, laps, rolling)
  local race = require('/lua/ge/extensions/gameplay/race/race')()
  race:setPath(R.path)
  race.lapCount = laps
  race.useHotlappingApp = false
  race.useLapTimesApp = false
  race.useWaypointAudio = false
  if rolling then race.path.config.rollingStart = true end
  race:setVehicleIds(ids)
  return race
end

function M._startSoloSession(kind, minutes)
  R.phase = kind
  R.sessionEnd = R.time + minutes * 60
  R.path.config.rollingStart = true -- flying laps
  R.soloRace = newRaceObject({ R.playerId }, 99, true)
  R.soloRace:startRace()
  local v = veh(R.playerId)
  if v then v:queueLuaCommand('controller.setFreeze(0)') end
  hud('TurismoRacePhase', { phase = kind, minutes = minutes, title = R.cfg.title })
  toast(kind == 'practice' and 'Freies Training: fahre dich ein. Beenden über das Rennmenü.' or
    'Qualifying: Deine schnellste Runde bestimmt den Startplatz.', 'info')
end

function M._startPractice() M._startSoloSession('practice', R.cfg.practiceMinutes or 10) end

function M._startQualifying() M._startSoloSession('qualifying', R.cfg.qualifyingMinutes or 8) end

-- UI: "Session beenden"
function M.endSession()
  if not R then return end
  if R.phase == 'practice' then
    R.soloRace = nil
    if R.cfg.qualifying ~= false then M._startQualifying() else M._spawnField() end
  elseif R.phase == 'qualifying' then
    R.soloRace = nil
    M._computeGrid()
    M._spawnField()
  end
end

-- AI qualifying times from the lap time model, player from real laps
function M._computeGrid()
  local cfg = R.cfg
  local rng = U().rng(U().hashString(cfg.eventRef or 'q') + P().day())
  local entries = {}
  local tf = cfg.trackFactor or 1
  for i, f in ipairs(cfg.field) do
    local info = extensions.turismo_vehicleDb.get(f.carKey)
    local li = info and info.rating.li or 400
    f.qualiTime = AI().simulatedLapTime(f.driver, R.poly.len, li, tf, rng, cfg.difficulty)
    entries[#entries + 1] = { idx = i, time = f.qualiTime }
  end
  local playerTime = R.qualifying.best or math.huge
  entries[#entries + 1] = { idx = 0, time = playerTime }
  table.sort(entries, function(a, b) return a.time < b.time end)
  R.gridOrder = entries
  R.qualiResults = {}
  for pos, e in ipairs(entries) do
    local name = e.idx == 0 and 'Du' or cfg.field[e.idx].driver.name
    R.qualiResults[#R.qualiResults + 1] = { pos = pos, name = name, time = e.time, isPlayer = e.idx == 0 }
  end
  hud('TurismoQualiResults', R.qualiResults)
end

---------------------------------------------------------------------------
-- field spawning
---------------------------------------------------------------------------
-- slot index for player and each AI
local function assignSlots()
  local cfg = R.cfg
  local n = #cfg.field + 1
  local order = {}
  if R.gridOrder then
    for _, e in ipairs(R.gridOrder) do order[#order + 1] = e.idx end
  else
    -- quick race: AI ordered by expected pace (fastest at front), player per setting
    local idx = {}
    for i = 1, #cfg.field do idx[#idx + 1] = i end
    table.sort(idx, function(a, b)
      local fa, fb = cfg.field[a], cfg.field[b]
      return (fa.paceScore or 0) > (fb.paceScore or 0)
    end)
    local playerPos = cfg.playerGrid == 'front' and 1 or (type(cfg.playerGrid) == 'number' and cfg.playerGrid or n)
    playerPos = U().clamp(playerPos, 1, n)
    for i = 1, n do
      if i == playerPos then order[#order + 1] = 0 else order[#order + 1] = table.remove(idx, 1) end
    end
  end
  return order
end

function M._spawnField()
  local cfg = R.cfg
  R.phase = 'spawning'
  local order = assignSlots()
  R.gridAssignment = order
  local pending = 0
  for slotIdx, fieldIdx in ipairs(order) do
    local slot = R.slots[slotIdx]
    if fieldIdx == 0 then
      local v = veh(R.playerId)
      if v and slot then
        slot:moveResetVehicleTo(R.playerId, false, false) -- false = keep damage
        v:queueLuaCommand('controller.setFreeze(1)')
      end
    else
      local f = cfg.field[fieldIdx]
      local model, config = U().splitCarKey(f.carKey)
      local spawnPos = slot.pos + (slot.rot * vec3(0, 1, 0)) * -2.5 + vec3(0, 0, 0.5)
      local rot = quatFromEuler(0, 0, math.pi) * slot.rot
      local ok, v = pcall(core_vehicles.spawnNewVehicle, model, {
        config = 'vehicles/' .. model .. '/' .. (config or 'base') .. '.pc',
        pos = spawnPos, rot = rot, autoEnterVehicle = false,
        paint = f.paint, licenseText = f.plate,
      })
      if ok and v then
        local id = v:getID()
        R.vehIds[#R.vehIds + 1] = id
        R.ai[id] = { field = f, slot = slot }
        R.names[id] = f.driver.name
        local info = extensions.turismo_vehicleDb.get(f.carKey)
        R.cars[id] = info and info.name or f.carKey
        pending = pending + 1
      else
        U().log('E', 'race: could not spawn %s: %s', tostring(f.carKey), tostring(v))
      end
    end
  end
  table.insert(R.vehIds, 1, R.playerId)
  R.spawnWait = 2.0 -- seconds to let vehicles load before placing them precisely
  R.phase = 'placing'
end

local function placeAiAndPrepare()
  local cfg = R.cfg
  AI().begin({
    difficulty = cfg.difficulty, surface = cfg.track.surface, wet = cfg.wet,
    catchUp = cfg.catchUp or 'off', seed = U().hashString(cfg.eventRef or 'r') + P().day(),
  })
  local drive = M._aiDriveTable()
  for id, a in pairs(R.ai) do
    a.slot:moveResetVehicleTo(id, false, true)
    local v = veh(id)
    if v then v:queueLuaCommand('controller.setFreeze(1)') end
    AI().addRacer(id, a.field.driver, drive)
    AI().prepare(id)
  end
end

-- AI driving instructions: navgraph route if the track has one, else a script line
function M._aiDriveTable()
  local race = newRaceObject({}, R.laps, false)
  local aiPath = race.aiPath
  if aiPath and #aiPath >= 2 then
    local p = U().deepcopy(aiPath)
    local laps = R.laps
    if R.closed then
      table.insert(p, p[1])
      laps = laps + 1 -- extra lap so AI keep driving across the line
    end
    return { wpTargetList = p, noOfLaps = laps }
  end
  -- fallback: follow the checkpoint polyline (repeated for every lap)
  local script = {}
  local reps = R.closed and (R.laps + 1) or 1
  for _ = 1, reps do
    for _, pt in ipairs(R.poly.pts) do script[#script + 1] = { x = pt.x, y = pt.y, z = pt.z } end
  end
  return { script = script }
end

---------------------------------------------------------------------------
-- intro camera ("Startaufstellung"-Kamerafahrt)
---------------------------------------------------------------------------
local function marker(pos, target, t, fov)
  return {
    fov = fov or 55, movingEnd = false, movingStart = false, positionSmooth = 0.5,
    pos = pos, rot = quatFromDir((target - pos):normalized(), vec3(0, 0, 1)), time = t, trackPosition = false,
  }
end

function M._playIntro()
  R.phase = 'intro'
  local pv = veh(R.playerId)
  if not pv or not core_paths then return M._toGrid() end
  local pts = R.poly.pts
  local center = vec3(0, 0, 0)
  for _, p in ipairs(pts) do center = center + p end
  center = center / math.max(1, #pts)
  local carPos = pv:getPosition()
  local fwd = pv:getDirectionVector()
  local right = fwd:cross(vec3(0, 0, 1)):normalized()
  local slot1 = R.slots[1].pos
  local lastSlot = R.slots[math.min(#R.slots, #R.vehIds)].pos
  local m = {
    marker(center + vec3(0, 0, 320) - fwd * 150, center, 0, 60),
    marker(slot1 + vec3(0, 0, 90) + fwd * 60, slot1, 3.5, 55),
    marker(lastSlot + vec3(0, 0, 6) - fwd * 25 + right * 6, slot1, 7.0, 50),
    marker(carPos + fwd * 7 + vec3(0, 0, 1.2), carPos, 9.5, 45),
    marker(carPos + right * 7 + vec3(0, 0, 1.4), carPos, 11.0, 45),
    marker(carPos - fwd * 7 + vec3(0, 0, 1.6), carPos, 12.5, 45),
    marker(carPos - right * 7 + vec3(0, 0, 1.4), carPos, 14.0, 45),
    marker(carPos - fwd * 6 + vec3(0, 0, 2.2), carPos + fwd * 10, 15.5, 60),
  }
  local camPath = { looped = false, manualFov = false, markers = m }
  local ok = pcall(core_paths.playPath, camPath, 0, {
    useDtReal = true,
    finishedPath = function() if R and R.phase == 'intro' then M._toGrid() end end,
  })
  hud('TurismoRacePhase', { phase = 'intro', title = R.cfg.title, track = R.cfg.track.name, laps = R.laps })
  if extensions.turismo_audio then extensions.turismo_audio.play('race_intro') end
  if not ok then M._toGrid() end
end

function M.skipIntro()
  if R and R.phase == 'intro' then M._toGrid() end
end

function M._toGrid()
  pcall(function() commands.setGameCamera() end)
  if R.cfg.startType == 'rolling' and R.closed then
    M._startFormation()
  else
    R.phase = 'countdown'
    R.countdown = 5.0
    R.lastCount = nil
  end
end

---------------------------------------------------------------------------
-- formation lap & rolling start
---------------------------------------------------------------------------
function M._startFormation()
  R.phase = 'formation'
  local v = veh(R.playerId)
  if v then v:queueLuaCommand('controller.setFreeze(0)') end
  AI().startFormation(M.PACE_SPEED)
  hud('TurismoRacePhase', { phase = 'formation' })
  toast('Einführungsrunde: Position halten, nicht überholen. Grün kommt vor der Ziellinie.', 'info')
end

---------------------------------------------------------------------------
-- race start & tracking
---------------------------------------------------------------------------
function M._go()
  R.phase = 'racing'
  R.raceStartTime = R.time
  R.race = newRaceObject(R.vehIds, R.laps, R.cfg.startType == 'rolling')
  R.race:startRace()
  local v = veh(R.playerId)
  if R.cfg.pursuitGap then
    -- Verfolgungsjagd: cars leave in grid order with a fixed gap; the player starts last
    local slotOf = {}
    for slotIdx, fieldIdx in ipairs(R.gridAssignment or {}) do slotOf[fieldIdx] = slotIdx end
    local fieldIdxOfVeh = {}
    for id, a in pairs(R.ai) do
      for i, f in ipairs(R.cfg.field) do if f == a.field then fieldIdxOfVeh[id] = i end end
    end
    for id, r in pairs(AI().racers()) do
      r.mode = 'launch'
      r.releaseAt = AI().now() + ((slotOf[fieldIdxOfVeh[id]] or 1) - 1) * R.cfg.pursuitGap
    end
    R.playerReleaseAt = R.time + ((slotOf[0] or #R.vehIds) - 1) * R.cfg.pursuitGap
  else
    if v then v:queueLuaCommand('controller.setFreeze(0)') end
    if R.cfg.startType == 'rolling' then
      for id in pairs(R.ai) do AI().setSpeedLimit(id, nil) end
      for _, r in pairs(AI().racers()) do r.mode = 'launch' r.releaseAt = 0 end
    else
      AI().release()
    end
  end
  R.eliminated = {}
  R.elimLap = 0
  hud('TurismoRacePhase', { phase = 'racing' })
  if extensions.turismo_audio then extensions.turismo_audio.play('race_go') end
  local st = extensions.turismo_save.get().stats
  st.racesStarted = (st.racesStarted or 0) + 1
end

local function updateProgress()
  local ctx = {}
  local entries = {}
  for _, id in ipairs(R.vehIds) do
    local v = veh(id)
    if v then
      local pos = v:getPosition()
      local prog, hint = projectProgress(R.poly, pos, R.progressHint[id])
      R.progressHint[id] = hint
      local st = R.race and R.race.states[id] or {}
      local lap = st.currentLap or 0
      local total = lap * R.poly.len + prog
      local vel = v:getVelocity()
      local m = map and map.objects and map.objects[id]
      ctx[id] = {
        pos = pos, speed = vel:length(), progress = total, lap = lap,
        finished = st.complete, isPlayer = (id == R.playerId),
        damage = m and U().clamp((m.damage or 0) / 30000, 0, 1) or 0,
      }
      entries[#entries + 1] = { id = id, progress = total, finished = st.complete, place = st.placement, endTime = st.endTime }
    end
  end
  -- standings: finished cars by placement, then by progress
  table.sort(entries, function(a, b)
    if a.finished and b.finished then return (a.place or 99) < (b.place or 99) end
    if a.finished ~= b.finished then return a.finished == true end
    return a.progress > b.progress
  end)
  for i, e in ipairs(entries) do
    local c = ctx[e.id]
    c.place = i
    local ahead, behind = entries[i - 1], entries[i + 1]
    if ahead then c.ahead = { id = ahead.id, gap = ahead.progress - e.progress, speed = ctx[ahead.id].speed } end
    if behind then c.behind = { id = behind.id, gap = e.progress - behind.progress, speed = ctx[behind.id].speed } end
  end
  local player = ctx[R.playerId]
  if player then
    for id, c in pairs(ctx) do
      if id ~= R.playerId then
        c.playerLapsAhead = math.floor((player.progress - c.progress) / math.max(1, R.poly.len))
        c.isPlayerBehind = player.progress < c.progress + R.poly.len * c.playerLapsAhead + 1 and
          (c.progress + R.poly.len * c.playerLapsAhead - player.progress) < 60
      end
    end
  end
  R.ctx, R.standings = ctx, entries
  return ctx, entries
end

local function pushHud()
  local p = R.ctx and R.ctx[R.playerId]
  if not p then return end
  local st = R.race and R.race.states[R.playerId] or {}
  local lapTime = 0
  if st.currentTimes and st.currentTimes[1] and st.currentTimes[1].beginTime then
    lapTime = R.race.time - st.currentTimes[1].beginTime
  end
  local last, best
  for _, l in ipairs(st.historicTimes or {}) do
    last = l.duration
    if not best or l.duration < best then best = l.duration end
  end
  local list = {}
  for i, e in ipairs(R.standings or {}) do
    if i > 16 then break end
    local c = R.ctx[e.id]
    local gapS = nil
    if i > 1 and R.ctx[R.standings[1].id] then
      local d = R.ctx[R.standings[1].id].progress - c.progress
      gapS = d / math.max(10, c.speed or 10)
    end
    list[#list + 1] = { pos = i, name = R.names[e.id], car = R.cars[e.id], gap = gapS, isPlayer = (e.id == R.playerId), finished = e.finished }
  end
  -- minimap: outline once per race (max ~160 points), car dots every update
  if not R.mapSent and R.poly and #R.poly.pts > 1 then
    R.mapSent = true
    local step = math.max(1, math.floor(#R.poly.pts / 160))
    local outline = {}
    for i = 1, #R.poly.pts, step do
      local pt = R.poly.pts[i]
      outline[#outline + 1] = { math.floor(pt.x * 10 + 0.5) / 10, math.floor(pt.y * 10 + 0.5) / 10 }
    end
    hud('TurismoTrackMap', { pts = outline, closed = R.closed and true or false })
  end
  local dots = {}
  for i, e in ipairs(R.standings or {}) do
    local c = R.ctx[e.id]
    if c and c.pos and not (R.eliminated and R.eliminated[e.id]) then
      dots[#dots + 1] = { math.floor(c.pos.x * 10 + 0.5) / 10, math.floor(c.pos.y * 10 + 0.5) / 10, e.id == R.playerId and 1 or 0, i }
    end
  end
  local gapAhead = p.ahead and p.ahead.gap / math.max(8, p.speed) or nil
  local gapBehind = p.behind and p.behind.gap / math.max(8, R.ctx[p.behind.id].speed) or nil
  hud('TurismoHud', {
    phase = R.phase, pos = p.place, total = #R.vehIds,
    lap = math.min((st.currentLap or 0) + 1, R.laps), laps = R.laps,
    lapTime = lapTime, lastLap = last, bestLap = best,
    gapAhead = gapAhead, gapBehind = gapBehind,
    nameAhead = p.ahead and R.names[p.ahead.id], nameBehind = p.behind and R.names[p.behind.id],
    standings = list, raceTime = R.race and R.race.time or 0,
    progress = R.poly.len > 0 and (p.progress % R.poly.len) / R.poly.len or 0,
    trackLen = R.poly.len, damage = p.damage, cars = dots,
  })
end

-- K.O.-Rennen: whenever the leader completes a lap, the last running car is out
function M._checkElimination()
  local leader = R.standings[1]
  if not leader then return false end
  local lst = R.race.states[leader.id]
  local lap = lst and lst.currentLap or 0
  if lap <= R.elimLap or lap >= R.laps then return false end
  R.elimLap = lap
  for i = #R.standings, 1, -1 do
    local e = R.standings[i]
    if not R.eliminated[e.id] and not e.finished then
      R.elimCount = (R.elimCount or 0) + 1
      R.eliminated[e.id] = R.elimCount
      if e.id == R.playerId then
        toast('Ausgeschieden! Du warst am Ende von Runde ' .. lap .. ' Letzter.', 'error')
        R.playerEliminated = true
        M._finishRace()
        return true
      end
      local st = R.race.states[e.id]
      if st then st.active = false end
      local v = veh(e.id)
      if v then v:queueLuaCommand('ai.setMode("stop")') end
      AI().removeRacer(e.id)
      toast(tostring(R.names[e.id]) .. ' ist ausgeschieden.', 'info')
      return false
    end
  end
  return false
end

local function finishRace()
  R.phase = 'results'
  if R.eliminated and next(R.eliminated) then
    -- eliminated cars rank behind everyone still running, earliest elimination last
    table.sort(R.standings, function(a, b)
      local ea, eb = R.eliminated[a.id], R.eliminated[b.id]
      if ea and eb then return ea > eb end
      if ea or eb then return eb ~= nil end
      if a.finished and b.finished then return (a.place or 99) < (b.place or 99) end
      if a.finished ~= b.finished then return a.finished == true end
      return a.progress > b.progress
    end)
  end
  local results = {}
  for i, e in ipairs(R.standings) do
    local st = R.race.states[e.id] or {}
    local best
    for _, l in ipairs(st.historicTimes or {}) do
      if not best or l.duration < best then best = l.duration end
    end
    results[#results + 1] = {
      pos = i, id = e.id, name = R.names[e.id], car = R.cars[e.id], isPlayer = (e.id == R.playerId),
      time = st.complete and st.endTime or nil, bestLap = best, dnf = not st.complete,
      driverId = R.ai[e.id] and R.ai[e.id].field.driver.id or nil,
    }
    if e.id == R.playerId and best then
      P().recordBestLap(R.cfg.track.id, best, R.cars[e.id])
    end
  end
  local m = map and map.objects and map.objects[R.playerId]
  local damageDelta = m and ((m.damage or 0) - R.damageStart) or 0
  R.results = { list = results, damageDelta = damageDelta, cleanRace = damageDelta < 500 }
  AI().stop()
  -- capture car condition (damage persists into the garage)
  SES().capturePlayerCar(function()
    local onFinish = R.cfg.onFinish
    local out = onFinish and onFinish(R.results) or {}
    R.results.rewards = out
    hud('TurismoRaceResults', R.results)
    if extensions.turismo_audio then extensions.turismo_audio.play('race_finish') end
  end)
end

M._finishRace = function() finishRace() end

function M.update(dtReal, dtSim)
  if not R then return end
  local dt = dtSim or dtReal
  R.time = R.time + dt

  if R.phase == 'placing' then
    R.spawnWait = R.spawnWait - dtReal
    if R.spawnWait <= 0 then
      placeAiAndPrepare()
      R.phase = 'preIntro'
      R.preIntroWait = 1.0
    end
  elseif R.phase == 'preIntro' then
    R.preIntroWait = R.preIntroWait - dtReal
    if R.preIntroWait <= 0 then
      if R.cfg.skipIntro then M._toGrid() else M._playIntro() end
    end
  elseif R.phase == 'practice' or R.phase == 'qualifying' then
    R.soloRace:onUpdate(dt)
    local st = R.soloRace.states[R.playerId]
    if st and st.historicTimes then
      for _, l in ipairs(st.historicTimes) do
        if not R.qualifying.best or l.duration < R.qualifying.best then R.qualifying.best = l.duration end
      end
    end
    R.hudTimer = R.hudTimer + dtReal
    if R.hudTimer > 0.25 then
      R.hudTimer = 0
      hud('TurismoSessionHud', { phase = R.phase, remaining = math.max(0, R.sessionEnd - R.time), best = R.qualifying.best })
    end
    if R.time >= R.sessionEnd then M.endSession() end
  elseif R.phase == 'countdown' then
    R.countdown = R.countdown - dtReal
    local c = math.ceil(R.countdown)
    if c ~= R.lastCount then
      R.lastCount = c
      hud('TurismoCountdown', { value = c })
      if extensions.turismo_audio and c <= 3 and c >= 1 then extensions.turismo_audio.play('count') end
    end
    if R.countdown <= 0 then M._go() end
  elseif R.phase == 'formation' then
    local ctx = updateProgress()
    AI().update(dtReal, ctx)
    -- green flag when the leader is 150 m from the line on its (only) formation lap
    local leader = R.standings[1] and R.ctx[R.standings[1].id]
    if leader and leader.progress > R.poly.len - 150 then
      hud('TurismoCountdown', { value = 0, green = true })
      M._go()
    end
    R.hudTimer = R.hudTimer + dtReal
    if R.hudTimer > M.HUD_RATE then R.hudTimer = 0 pushHud() end
  elseif R.phase == 'racing' or R.phase == 'cooldown' then
    R.race:onUpdate(dt)
    local ctx = updateProgress()
    AI().update(dtReal, ctx)
    if R.playerReleaseAt and R.time >= R.playerReleaseAt then
      R.playerReleaseAt = nil
      local pv = veh(R.playerId)
      if pv then pv:queueLuaCommand('controller.setFreeze(0)') end
      hud('TurismoCountdown', { value = 0, green = true })
    end
    if R.cfg.elimination and R.phase == 'racing' and M._checkElimination() then return end
    local pst = R.race.states[R.playerId]
    if R.phase == 'racing' and pst and pst.complete then
      R.phase = 'cooldown'
      R.cooldownEnd = R.time + M.COOLDOWN_TIME
      hud('TurismoRacePhase', { phase = 'finished', pos = ctx[R.playerId] and ctx[R.playerId].place })
      -- the player car is handed to the AI for a cool-down lap feel
    end
    if R.phase == 'cooldown' then
      local allDone = true
      for _, id in ipairs(R.vehIds) do
        local s = R.race.states[id]
        if s and not s.complete then allDone = false break end
      end
      if allDone or R.time >= R.cooldownEnd then finishRace() end
      if R.cfg.elimination and not allDone then
        -- in K.O. races only non-eliminated cars count
        local remaining = 0
        for _, id in ipairs(R.vehIds) do
          local s2 = R.race.states[id]
          if s2 and not s2.complete and not R.eliminated[id] then remaining = remaining + 1 end
        end
        if remaining == 0 then finishRace() end
      end
    end
    R.hudTimer = R.hudTimer + dtReal
    if R.hudTimer > M.HUD_RATE then R.hudTimer = 0 pushHud() end
  end
end

---------------------------------------------------------------------------
-- leaving
---------------------------------------------------------------------------
local function cleanupVehicles()
  for id in pairs(R.ai) do
    local v = veh(id)
    if v then v:delete() end
  end
end

-- restart the same race (same grid, car keeps the damage from before the race)
function M.restart()
  if not R then return end
  local cfg = R.cfg
  AI().stop()
  cleanupVehicles()
  R = nil
  SES().reloadPlayerCar(function() M.start(cfg) end)
end

function M.abort(reason)
  if not R then return end
  AI().stop()
  cleanupVehicles()
  local wasRacing = R.phase == 'racing' or R.phase == 'cooldown' or R.phase == 'formation'
  R = nil
  hud('TurismoRacePhase', { phase = 'idle' })
  if wasRacing and reason ~= 'restart' then
    SES().capturePlayerCar(function() end)
  end
end

-- after the results screen
function M.close()
  if not R then return end
  cleanupVehicles()
  R = nil
  hud('TurismoRacePhase', { phase = 'idle' })
  SES().returnToHub()
end

return M
