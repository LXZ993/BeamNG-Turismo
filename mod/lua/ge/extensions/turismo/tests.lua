-- Turismo Karriere - tests
-- Runtime for licence tests and training challenges.
--
-- Course tests ("gates", "stop") are procedural: the course is defined in local
-- metres (x = right, y = forward) relative to a venue anchor, so they work on any
-- big flat area. Gates are drawn with the debug drawer (always available);
-- the anchor is the level's spawn point or a position the player calibrated.
-- Track tests ("track") use a real race file: one flying or standing lap.
--
-- Judging: order of gates, missed gates, speed gates, stop box, collisions
-- (damage delta), time limit. Optional demo run: the AI drives the course
-- (also used to auto-calibrate medal times for tests with targets.mode = 'auto').

local M = {}

local function U() return extensions.turismo_util end
local function D() return extensions.turismo_data end
local function SES() return extensions.turismo_session end
local function LIC() return extensions.turismo_licenses end

local T = nil -- running test

M.COLLISION_DAMAGE = 250
M.STOP_SPEED = 0.35

local function hud(name, data) if guihooks then guihooks.trigger(name, data) end end
local function veh(id) return id and getObjectByID and getObjectByID(id) or nil end

function M.isActive() return T ~= nil end

---------------------------------------------------------------------------
-- geometry (pure; vectors as tables {x,y,z} so it is testable)
---------------------------------------------------------------------------
-- 2D segment intersection test, returns true if p1->p2 crosses q1->q2
function M.segmentsCross(p1, p2, q1, q2)
  local function orient(a, b, c) return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) end
  local d1, d2 = orient(q1, q2, p1), orient(q1, q2, p2)
  local d3, d4 = orient(p1, p2, q1), orient(p1, p2, q2)
  return ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0))
end

-- local course point -> world (anchor = {pos={x,y,z}, fwd={x,y}, right={x,y}})
function M.toWorld(anchor, lx, ly)
  return {
    x = anchor.pos.x + anchor.right.x * lx + anchor.fwd.x * ly,
    y = anchor.pos.y + anchor.right.y * lx + anchor.fwd.y * ly,
    z = anchor.pos.z,
  }
end

-- world -> local (inverse of toWorld, 2D)
function M.toLocal(anchor, wx, wy)
  local dx, dy = wx - anchor.pos.x, wy - anchor.pos.y
  return dx * anchor.right.x + dy * anchor.right.y, dx * anchor.fwd.x + dy * anchor.fwd.y
end

-- builds world gate segments from course definition
function M.buildCourse(def, anchor)
  local gates = {}
  for i, g in ipairs(def.course or {}) do
    local w = (g.w or 6) / 2
    local heading = math.rad(g.heading or 0) -- gate rotation relative to forward
    local rx, ry = math.cos(heading), -math.sin(heading) -- local right axis of the gate
    local gate = {
      idx = i, kind = g.kind or 'gate', def = g,
      a = M.toWorld(anchor, g.x - rx * w, g.y - ry * w),
      b = M.toWorld(anchor, g.x + rx * w, g.y + ry * w),
      c = M.toWorld(anchor, g.x, g.y),
      lx = g.x, ly = g.y,
    }
    if gate.kind == 'stop' then
      gate.len = g.len or 6
      gate.w = g.w or 4
    end
    gates[#gates + 1] = gate
  end
  return gates
end

-- is a local point inside a stop box gate
function M.inStopBox(gate, lx, ly)
  return math.abs(lx - gate.lx) <= gate.w / 2 and ly >= gate.ly and ly <= gate.ly + gate.len
end

---------------------------------------------------------------------------
-- reference time estimation (pure): point-mass simulation along the course
-- polyline with curvature speed limits, power-limited acceleration, drag and
-- braking. Used for medal targets until a demo run calibrates the test.
---------------------------------------------------------------------------
local G_ACC = 9.81

local function radius3(a, b, c)
  local ab = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
  local bc = math.sqrt((c.x - b.x) ^ 2 + (c.y - b.y) ^ 2)
  local ca = math.sqrt((a.x - c.x) ^ 2 + (a.y - c.y) ^ 2)
  local area2 = math.abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))
  if area2 < 1e-6 then return math.huge end
  return ab * bc * ca / (2 * area2)
end

-- def: course test definition, info: normalized vehicle info
function M.estimateCourseTime(def, info)
  local u = U()
  local cat = info.rating and info.rating.category or 'street'
  local tyre = extensions.turismo_rating.tyreFactor[cat] or 1
  local mu = 0.95 * tyre
  local mass = (info.weight_kg or 1300) + 80
  local powerW = (info.power_hp or 100) * 735.5 * 0.85 -- drivetrain losses
  local dt = u.lower(info.drivetrain)
  local tractionShare = (dt == 'awd' or dt == '4wd') and 0.95 or (dt == 'fwd' and 0.6 or 0.55)
  local dragK = 0.45 -- 0.5 * rho * CdA
  -- build points: spawn, gates (stop box -> centre with v = 0)
  local pts = {}
  local spawn = def.spawn or { x = 0, y = -8 }
  pts[#pts + 1] = { x = spawn.x, y = spawn.y, vmax = 0 }
  local finalStop = false
  for _, g in ipairs(def.course or {}) do
    if g.kind == 'stop' then
      pts[#pts + 1] = { x = g.x, y = g.y + (g.len or 6) / 2, vmax = 0 }
      finalStop = true
    else
      pts[#pts + 1] = { x = g.x, y = g.y, vmax = g.maxSpeed and g.maxSpeed / 3.6 or nil, vmin = g.minSpeed and g.minSpeed / 3.6 or nil }
    end
  end
  if #pts < 2 then return 10 end
  -- curvature limits at interior points
  for i = 2, #pts - 1 do
    local r = radius3(pts[i - 1], pts[i], pts[i + 1])
    local vc = math.sqrt(mu * G_ACC * math.min(r, 5000))
    pts[i].vmax = math.min(pts[i].vmax or 1e9, vc)
  end
  -- discretize into 1 m steps with speed caps
  local seg = {}
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    local len = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
    local n = math.max(1, math.floor(len))
    for k = 1, n do
      seg[#seg + 1] = { ds = len / n, cap = (k == n) and (b.vmax or 1e9) or 1e9 }
    end
  end
  if not finalStop then seg[#seg].cap = math.min(seg[#seg].cap, 1e9) end
  local n = #seg
  local v = {}
  -- forward pass
  local cur = 0
  for i = 1, n do
    local s = seg[i]
    local aTrac = mu * G_ACC * tractionShare
    local aPow = powerW / (mass * math.max(cur, 1.5))
    local a = math.min(aTrac, aPow) - dragK * cur * cur / mass
    cur = math.sqrt(math.max(0, cur * cur + 2 * a * s.ds))
    cur = math.min(cur, s.cap, 85)
    v[i] = cur
  end
  -- backward pass (braking)
  local bdec = mu * G_ACC * 0.95
  local nxt = v[n]
  for i = n - 1, 1, -1 do
    local lim = math.sqrt(nxt * nxt + 2 * bdec * seg[i + 1].ds)
    if v[i] > lim then v[i] = lim end
    nxt = v[i]
  end
  -- time
  local t, prev = 0, 0
  for i = 1, n do
    local avg = (prev + v[i]) / 2
    t = t + seg[i].ds / math.max(avg, 0.5)
    prev = v[i]
  end
  return t + 0.25 -- human reaction at the start
end

function M.estimateTime(def, info)
  if def.type == 'track' then
    local track = extensions.turismo_tracks.resolve(def.track, U().hashString(def.id))
    if not track then return nil end
    local tf = (extensions.turismo_save.get() and extensions.turismo_save.get().trackFactors or {})[track.id]
    local lap = extensions.turismo_aiDirector.referenceLapTime(track.lengthM, info.rating.li, tf)
    return lap * (def.laps or 1) * 0.97
  end
  return M.estimateCourseTime(def, info)
end

---------------------------------------------------------------------------
-- start / stop
---------------------------------------------------------------------------
local function venueOf(def)
  local venues = U().indexBy(D().get('venues') or {}, 'id')
  return venues[def.venue or 'testgelaende'] or { id = 'fallback', level = 'gridmap_v2', anchor = 'spawn' }
end

-- opts: { demo = bool, calibrate = bool }
-- opts: { demo, def (inline definition, e.g. crawl events), onResult(result) }
function M.start(testId, opts)
  if T then M.abort() end
  local def = (opts and opts.def) or D().test(testId)
  if not def then return false, 'Unbekannter Test' end
  opts = opts or {}
  T = { def = def, phase = 'loading', time = 0, gateIdx = 1, opts = opts, events = {}, damage0 = 0 }
  if def.type == 'track' then
    return M._startTrackTest()
  end
  local venue = venueOf(def)
  T.venue = venue
  local level = venue.level
  for _, l in ipairs({ venue.level, unpack(venue.fallbackLevels or {}) }) do
    if SES().levelExists(l) then level = l break end
  end
  SES().loadLevel(level, function()
    local anchor = SES().venueAnchor(venue)
    if not anchor then
      M.abort('Kein Startpunkt für das Testgelände gefunden.')
      return
    end
    T.anchor = anchor
    T.gates = M.buildCourse(def, anchor)
    local spawnLocal = def.spawn or { x = 0, y = -8 }
    local sp = M.toWorld(anchor, spawnLocal.x, spawnLocal.y)
    local dir = vec3(anchor.fwd.x, anchor.fwd.y, 0)
    local transform = { pos = vec3(sp.x, sp.y, sp.z + 0.3), rot = quatFromDir(dir, vec3(0, 0, 1)), raw = true }
    local function onSpawned(vehId)
      T.vehId = vehId
      local m = map and map.objects and map.objects[vehId]
      T.damage0 = m and m.damage or 0
      local v = veh(vehId)
      if v then v:queueLuaCommand('controller.setFreeze(1)') end
      T.phase = 'countdown'
      T.countdown = 3.5
      hud('TurismoTestPhase', { phase = 'intro', name = def.name, desc = def.desc, targets = LIC().targetsFor(def), demo = opts.demo })
    end
    local info, rental = LIC().testCar(def)
    if rental and info then
      T.rental = true
      SES().spawnRental(info.key, transform, onSpawned)
    else
      SES().spawnPlayerCar(nil, transform, onSpawned)
    end
  end)
  return true
end

function M._startTrackTest()
  local def = T.def
  local track = extensions.turismo_tracks.resolve(def.track, U().hashString(def.id))
  if not track then M.abort('Strecke für den Test nicht gefunden.') return false end
  T.track = track
  SES().loadLevel(track.level, function()
    local path = require('/lua/ge/extensions/gameplay/race/path')('Test')
    path:onDeserialized(jsonReadFile(track.file))
    path:autoConfig()
    T.path = path
    local sp = path.startPositions.sorted[1]
    local transform = sp and { startPosition = sp } or nil
    local function onSpawned(vehId)
      T.vehId = vehId
      if sp then sp:moveResetVehicleTo(vehId, false, T.rental == true) end
      local m = map and map.objects and map.objects[vehId]
      T.damage0 = m and m.damage or 0
      local race = require('/lua/ge/extensions/gameplay/race/race')()
      race:setPath(path)
      race.lapCount = def.laps or 1
      race.useHotlappingApp = false
      race:setVehicleIds({ vehId })
      T.race = race
      local v = veh(vehId)
      if v then v:queueLuaCommand('controller.setFreeze(1)') end
      T.phase = 'countdown'
      T.countdown = 3.5
      hud('TurismoTestPhase', { phase = 'intro', name = def.name, desc = def.desc, targets = LIC().targetsFor(def) })
    end
    local info, rental = LIC().testCar(def)
    if rental and info then
      T.rental = true
      SES().spawnRental(info.key, transform, onSpawned)
    else
      SES().spawnPlayerCar(nil, transform, onSpawned)
    end
  end)
  return true
end

local function fail(reason)
  if not T or T.phase == 'done' then return end
  T.phase = 'done'
  T.failed = true
  T.reason = reason
  M._finish()
end

local function succeed(value)
  if not T or T.phase == 'done' then return end
  T.phase = 'done'
  T.value = value
  M._finish()
end

function M._finish()
  local v = veh(T.vehId)
  if v then v:queueLuaCommand('ai.setMode("disabled")') end
  local def = T.def
  local result
  if T.opts.onResult then
    local value = T.value and (T.value + (T.penalty or 0)) or nil
    result = T.opts.onResult({ value = value, raw = T.value, penalty = T.penalty or 0, failed = T.failed, reason = T.reason }) or {}
    result.value, result.failed, result.reason, result.penalty = value, T.failed, T.reason, T.penalty
  elseif T.opts.demo then
    if not T.failed and T.value and def.targets and def.targets.mode == 'auto' then
      LIC().setCalibration(def.id, T.value)
    end
    result = { demo = true, value = T.value, failed = T.failed, reason = T.reason }
  else
    result = LIC().recordResult(def.id, T.value, T.failed) or {}
    result.value = T.value
    result.failed = T.failed
    result.reason = T.reason
    if extensions.turismo_profile then extensions.turismo_profile.advanceDay(def.dayCost or 0) end
  end
  result.name = def.name
  result.targets = LIC().targetsFor(def)
  T.result = result
  hud('TurismoTestResult', result)
  if extensions.turismo_audio then
    extensions.turismo_audio.play(T.failed and 'fail' or (result.medal == 'gold' and 'medal_gold' or 'medal'))
  end
end

function M.retry()
  if not T then return end
  local id, opts = T.def.id, T.opts
  M.abort()
  M.start(id, opts)
end

function M.abort(msg)
  if not T then return end
  local v = veh(T.vehId)
  if v then v:queueLuaCommand('ai.setMode("disabled")') end
  if T.rental and T.vehId then SES().removeRental(T.vehId) end
  T = nil
  hud('TurismoTestPhase', { phase = 'idle', message = msg })
end

function M.close()
  M.abort()
  SES().returnToHub()
end

---------------------------------------------------------------------------
-- demo drive: the AI follows the gate centres
---------------------------------------------------------------------------
local function startDemo()
  local script = {}
  local first = T.gates[1]
  for _, g in ipairs(T.gates) do
    local p = { x = g.c.x, y = g.c.y, z = g.c.z }
    if g.kind == 'stop' then
      local inner = M.toWorld(T.anchor, g.lx, g.ly + g.len * 0.5)
      p = { x = inner.x, y = inner.y, z = inner.z, v = 0 }
    elseif g.def.maxSpeed then
      p.v = g.def.maxSpeed / 3.6 * 0.95
    end
    script[#script + 1] = p
  end
  if first then
    local before = M.toWorld(T.anchor, first.lx, first.ly - 4)
    table.insert(script, 1, { x = before.x, y = before.y, z = before.z })
  end
  local v = veh(T.vehId)
  if v then
    v:queueLuaCommand('ai.driveUsingPath(' .. serialize({ script = script, aggression = T.def.demoAggression or 0.95 }) .. ')')
  end
end

---------------------------------------------------------------------------
-- update
---------------------------------------------------------------------------
local function drawCourse()
  if not debugDrawer or not T.gates then return end
  for i, g in ipairs(T.gates) do
    local col
    if i < T.gateIdx then col = ColorF(0.2, 0.9, 0.3, 0.6)
    elseif i == T.gateIdx then col = ColorF(1.0, 0.8, 0.1, 0.9)
    else col = ColorF(0.9, 0.9, 0.9, 0.5) end
    if g.kind == 'stop' then
      local c1 = M.toWorld(T.anchor, g.lx - g.w / 2, g.ly)
      local c2 = M.toWorld(T.anchor, g.lx + g.w / 2, g.ly)
      local c3 = M.toWorld(T.anchor, g.lx + g.w / 2, g.ly + g.len)
      local c4 = M.toWorld(T.anchor, g.lx - g.w / 2, g.ly + g.len)
      local pts = { c1, c2, c3, c4, c1 }
      for k = 1, 4 do
        local a, b = pts[k], pts[k + 1]
        debugDrawer:drawSquarePrism(vec3(a.x, a.y, a.z + 0.02), vec3(b.x, b.y, b.z + 0.02), Point2F(0.05, 0.3), Point2F(0.05, 0.3), col)
      end
    else
      local a, b = g.a, g.b
      debugDrawer:drawCylinder(vec3(a.x, a.y, a.z), vec3(a.x, a.y, a.z + 1.6), 0.12, col)
      debugDrawer:drawCylinder(vec3(b.x, b.y, b.z), vec3(b.x, b.y, b.z + 1.6), 0.12, col)
      if i == T.gateIdx then
        debugDrawer:drawSquarePrism(vec3(a.x, a.y, a.z + 0.02), vec3(b.x, b.y, b.z + 0.02), Point2F(0.05, 0.25), Point2F(0.05, 0.25), col)
      end
      if g.def.label then
        debugDrawer:drawTextAdvanced(vec3(g.c.x, g.c.y, g.c.z + 2.2), tostring(g.def.label), ColorF(1, 1, 1, 1), true, false, ColorI(0, 0, 0, 160))
      end
    end
  end
end

local function updateCourse(dt)
  local v = veh(T.vehId)
  if not v then return end
  local pos = v:getPosition()
  local p2 = { x = pos.x, y = pos.y }
  local p1 = T.lastPos or p2
  T.lastPos = p2
  local speed = v:getVelocity():length()
  T.maxSpeed = math.max(T.maxSpeed or 0, speed)

  -- collision check
  local m = map and map.objects and map.objects[T.vehId]
  if not T.def.ignoreDamage and m and (m.damage or 0) - T.damage0 > (T.def.collisionDamage or M.COLLISION_DAMAGE) then
    return fail('Kollision')
  end
  -- a jump of >8 m in one frame = vehicle reset/recovery -> penalty (crawl) or fail
  if T.lastWorld and pos:distance(T.lastWorld) > 8 then
    if T.def.penaltyPerReset then
      T.penalty = (T.penalty or 0) + T.def.penaltyPerReset
    else
      T.lastWorld = pos
      return fail('Fahrzeug zurückgesetzt')
    end
  end
  T.lastWorld = pos
  if T.def.timeLimit and T.time > T.def.timeLimit then return fail('Zeitlimit überschritten') end

  local g = T.gates[T.gateIdx]
  if not g then return end
  local lx, ly = M.toLocal(T.anchor, pos.x, pos.y)

  if g.kind == 'stop' then
    if ly > g.ly + g.len + 2.5 then return fail('Über die Haltezone hinaus') end
    if speed < M.STOP_SPEED and T.time > 0.5 then
      T.stillTime = (T.stillTime or 0) + dt
      if T.stillTime > 0.6 then
        if M.inStopBox(g, lx, ly) then
          return succeed(T.time)
        elseif ly > g.ly - 15 then
          return fail('Außerhalb der Haltezone gestoppt')
        end
      end
    else
      T.stillTime = 0
    end
  else
    if M.segmentsCross(p1, p2, g.a, g.b) then
      -- speed gate check
      local kmh = speed * 3.6
      if g.def.minSpeed and kmh < g.def.minSpeed then return fail(string.format('Zu langsam am Tor (%d km/h)', kmh)) end
      if g.def.maxSpeed and kmh > g.def.maxSpeed then return fail(string.format('Zu schnell am Tor (%d km/h)', kmh)) end
      T.gateIdx = T.gateIdx + 1
      if extensions.turismo_audio then extensions.turismo_audio.play('gate') end
      if T.gateIdx > #T.gates then return succeed(T.time) end
    else
      -- missed: crossed the line of the next gate, or far past this gate
      local nxt = T.gates[T.gateIdx + 1]
      if nxt and nxt.kind ~= 'stop' and M.segmentsCross(p1, p2, nxt.a, nxt.b) then
        if T.def.penaltyPerGate then
          T.penalty = (T.penalty or 0) + T.def.penaltyPerGate
          T.gateIdx = T.gateIdx + 2
          if extensions.turismo_audio then extensions.turismo_audio.play('error') end
          if T.gateIdx > #T.gates then return succeed(T.time) end
          return
        end
        return fail('Tor ausgelassen')
      end
      local dx, dy = p2.x - g.c.x, p2.y - g.c.y
      local dist = math.sqrt(dx * dx + dy * dy)
      T.minDist = math.min(T.minDist or math.huge, dist)
      if T.minDist < 25 and dist > 45 then
        if T.def.penaltyPerGate then
          T.penalty = (T.penalty or 0) + T.def.penaltyPerGate
          T.gateIdx = T.gateIdx + 1
          T.minDist = nil
          if T.gateIdx > #T.gates then return succeed(T.time) end
          return
        end
        return fail('Tor verpasst')
      end
    end
  end
end

local function updateTrack(dt)
  T.race:onUpdate(dt)
  local st = T.race.states[T.vehId]
  local m = map and map.objects and map.objects[T.vehId]
  if T.def.cleanLap and m and (m.damage or 0) - T.damage0 > (T.def.collisionDamage or M.COLLISION_DAMAGE) then
    return fail('Kollision')
  end
  if st and st.complete then
    succeed(st.endTime)
  end
end

function M.update(dtReal, dtSim)
  if not T then return end
  local dt = dtSim or dtReal
  if T.phase == 'countdown' then
    if T.gates then drawCourse() end
    T.countdown = T.countdown - dtReal
    local c = math.ceil(T.countdown)
    if c ~= T.lastCount then
      T.lastCount = c
      if c <= 3 and c >= 1 then
        hud('TurismoCountdown', { value = c })
        if extensions.turismo_audio then extensions.turismo_audio.play('count') end
      end
    end
    if T.countdown <= 0 then
      T.phase = 'running'
      T.time = 0
      hud('TurismoCountdown', { value = 0, green = true })
      if extensions.turismo_audio then extensions.turismo_audio.play('race_go') end
      local v = veh(T.vehId)
      if v then v:queueLuaCommand('controller.setFreeze(0)') end
      if T.race then T.race:startRace() end
      if T.opts.demo and T.gates then startDemo() end
      if T.opts.demo and T.race then
        local drive = { wpTargetList = T.race.aiPath, aggression = 1 }
        if v and T.race.aiPath and #T.race.aiPath > 1 then v:queueLuaCommand('ai.driveUsingPath(' .. serialize(drive) .. ')') end
      end
    end
  elseif T.phase == 'running' then
    T.time = T.time + dt
    if T.gates then
      drawCourse()
      updateCourse(dt)
    elseif T.race then
      updateTrack(dt)
    end
    T.hudTimer = (T.hudTimer or 0) + dtReal
    if T.hudTimer > 0.1 and T.phase == 'running' then
      T.hudTimer = 0
      local v = veh(T.vehId)
      hud('TurismoTestHud', {
        time = T.time, penalty = T.penalty, gate = T.gateIdx, gates = T.gates and #T.gates or nil,
        speed = v and v:getVelocity():length() * 3.6 or 0,
        targets = LIC().targetsFor(T.def), name = T.def.name,
      })
    end
  end
end

return M
