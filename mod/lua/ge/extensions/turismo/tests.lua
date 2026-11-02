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
local function CO() return extensions.turismo_courses end

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

-- point-mass run along a polyline. pts = {{x, y, vmax?, vmin?}}; the first
-- point is the start (vmax = 0 for a standing start), finalStop = stop on the
-- last point
function M.estimatePolyline(pts, info, finalStop)
  local u = U()
  local cat = info.rating and info.rating.category or 'street'
  local tyre = extensions.turismo_rating and extensions.turismo_rating.tyreFactor[cat] or 1
  local mu = 0.95 * tyre
  local mass = (info.weight_kg or 1300) + 80
  local powerW = (info.power_hp or 100) * 735.5 * 0.85 -- drivetrain losses
  local dt = u.lower(info.drivetrain)
  local tractionShare = (dt == 'awd' or dt == '4wd') and 0.95 or (dt == 'fwd' and 0.6 or 0.55)
  local dragK = 0.45 -- 0.5 * rho * CdA
  if #pts < 2 then return 10 end
  if finalStop then pts[#pts].vmax = 0 end
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
  local n = #seg
  local v = {}
  -- forward pass
  local cur = pts[1].vmax == 0 and 0 or (pts[1].v0 or 0)
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
  local t, prev = 0, pts[1].v0 or 0
  for i = 1, n do
    local avg = (prev + v[i]) / 2
    t = t + seg[i].ds / math.max(avg, 0.5)
    prev = v[i]
  end
  return t + 0.25 -- human reaction at the start
end

-- def: course test definition, info: normalized vehicle info
function M.estimateCourseTime(def, info)
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
  return M.estimatePolyline(pts, info, finalStop)
end

-- path tests: checkpoints of a real course; the polyline between sparse
-- checkpoints is shorter than the road, so a road factor is added
function M.estimatePathTime(def, info)
  local course = extensions.turismo_courses.resolve(def.race)
  if not course then return nil end
  local gates = M.pathGates(def, course)
  local pts = {}
  local rolling = def.start and def.start.kind == 'rolling'
  for i, g in ipairs(gates) do
    local p = { x = g.x, y = g.y }
    if i == 1 then
      if rolling then p.v0 = (def.start.speed or 60) / 3.6 else p.vmax = 0 end
    end
    local rule = def.speed and (def.speed[tostring(i)] or def.speed[i])
    if rule and rule.max then p.vmax = rule.max / 3.6 end
    if g.kind == 'stop' then p.vmax = 0 end
    pts[#pts + 1] = p
  end
  -- checkpoints are sparse: the corner lies somewhere between them. Estimate
  -- its radius from the heading change and the distances (tighter for big turns)
  local cat = info.rating and info.rating.category or 'street'
  local mu = 0.95 * (extensions.turismo_rating and extensions.turismo_rating.tyreFactor[cat] or 1)
  for i = 2, #pts - 1 do
    local a, p, b = pts[i - 1], pts[i], pts[i + 1]
    local d1 = math.sqrt((p.x - a.x) ^ 2 + (p.y - a.y) ^ 2)
    local d2 = math.sqrt((b.x - p.x) ^ 2 + (b.y - p.y) ^ 2)
    local h1, h2 = math.atan2(p.y - a.y, p.x - a.x), math.atan2(b.y - p.y, b.x - p.x)
    local th = math.abs(((h2 - h1 + math.pi) % (2 * math.pi)) - math.pi)
    if th > 0.2 then
      local r = math.max(12, math.min(400, math.min(d1, d2) * 0.5 / math.max(math.tan(th / 2), 0.1) * 0.5))
      local vc = math.sqrt(mu * G_ACC * r)
      p.vmax = math.min(p.vmax or 1e9, vc)
    end
  end
  local t = M.estimatePolyline(pts, info, gates[#gates] and gates[#gates].kind == 'stop')
  return t * (def.roadFactor or 1.08)
end

-- on the level: real road between the checkpoints from BeamNG's road network
-- (gameplay/route), used for the guide arrows and a better time estimate
function M.buildRoute(gates)
  local ok, Route = pcall(require, '/lua/ge/extensions/gameplay/route/route')
  if not ok or not Route then return nil end
  local r = Route()
  local list = {}
  for _, g in ipairs(gates) do
    if g.kind ~= 'stop' then list[#list + 1] = vec3(g.x, g.y, g.z) end
  end
  local ok2 = pcall(function() r:setupPathMulti(list) end)
  if not ok2 or not r.path or #r.path < 2 then return nil end
  local pts = {}
  for _, p in ipairs(r.path) do
    local pos = p.pos
    if pos then pts[#pts + 1] = { x = pos.x, y = pos.y, z = pos.z } end
  end
  return pts, r.distance
end

function M.estimateRouteTime(def, info, route, gates)
  local pts = {}
  local rolling = def.start and def.start.kind == 'rolling'
  for i, p in ipairs(route) do
    pts[i] = { x = p.x, y = p.y }
  end
  if rolling then pts[1].v0 = (def.start.speed or 60) / 3.6 else pts[1].vmax = 0 end
  return M.estimatePolyline(pts, info, gates[#gates] and gates[#gates].kind == 'stop') * 1.02
end

function M.estimateTime(def, info)
  if def.type == 'path' then return M.estimatePathTime(def, info) end
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
  U().log('I', 'tests: start %s (%s)%s', tostring(def.id), tostring(def.type), opts.demo and ' Vorführung' or '')
  if def.type == 'track' then
    return M._startTrackTest()
  end
  if def.type == 'path' then
    return M._startPathTest()
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
    local sp = extensions.turismo_util.startSlots(path)[1]
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
      race.useLapTimesApp = false
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


local fail, succeed -- defined below

---------------------------------------------------------------------------
-- path tests: checkpoints of a real BeamNG course (see turismo_courses)
--   race   = race file (or list of candidates)
--   level  = level to load (default: taken from the file path)
--   from/to, sector/of, laps = which part of the course
--   start  = { kind = 'standing' | 'rolling', speed = km/h, back = m }
--   finish = 'gate' (default) | 'stop' (stop box after the last checkpoint)
--   speed  = { ["<gate nr>"] = { min = km/h, max = km/h } }
--   offTrack = metres allowed away from the line between two checkpoints
---------------------------------------------------------------------------
function M.levelOfFile(file)
  if type(file) == 'table' then file = file[1] end
  if type(file) ~= 'string' then return nil end
  return file:match('/missions/([^/]+)/') or file:match('^/?levels/([^/]+)/')
end

-- gate list for a path test (pure, also used by the time estimate)
function M.pathGates(def, course)
  local gates = CO().section(course, { from = def.from, to = def.to, sector = def.sector, of = def.of, laps = def.laps })
  local out = {}
  for i, g in ipairs(gates) do
    g.kind = 'node'
    out[#out + 1] = g
  end
  if def.finish == 'stop' then
    local last = out[#out]
    local after = def.stopAfter or 12
    local len, w = def.stopLen or 6, def.stopW or math.min(4.5, last.r * 1.2)
    out[#out + 1] = { kind = 'stop', x = last.x + last.fx * (after + len / 2), y = last.y + last.fy * (after + len / 2), z = last.z,
      fx = last.fx, fy = last.fy, r = w / 2, len = len, w = w, sx = last.x + last.fx * after, sy = last.y + last.fy * after }
  end
  return out
end

-- local coordinates of a point in a stop box (along = 0..len, lateral)
local function stopLocal(g, x, y)
  local dx, dy = x - g.sx, y - g.sy
  return dx * g.fx + dy * g.fy, dx * g.fy - dy * g.fx
end

function M.inStop(g, x, y)
  local along, lat = stopLocal(g, x, y)
  return along >= 0 and along <= g.len and math.abs(lat) <= g.w / 2
end

-- did the car pass checkpoint g between p1 and p2 (sphere like BeamNG's own
-- pathnodes, or crossing the gate line)
function M.passedNode(g, p1, p2)
  local tol = g.r + 1.0
  if CO().distToSegment(g.x, g.y, p1, p2) <= tol then return true end
  local a, b = CO().gateEnds(g)
  return M.segmentsCross(p1, p2, a, b)
end

function M._startPathTest()
  local def = T.def
  local course = CO().resolve(def.race)
  if not course then
    U().log('W', 'tests: course file missing for %s: %s', tostring(def.id), U().dump and U().dump(def.race) or tostring(def.race))
    M.abort('Diese Prüfung braucht eine Strecke, die auf deiner BeamNG-Installation fehlt.')
    return false, 'Strecke fehlt'
  end
  T.course = course
  T.path = M.pathGates(def, course)
  T.rolling = def.start and def.start.kind == 'rolling'
  -- standing start: the car stands on checkpoint 1, timing starts at "Los";
  -- rolling start: the car comes in at speed, timing starts at checkpoint 1
  T.gateIdx = T.rolling and 1 or 2
  local level = def.level or M.levelOfFile(def.race) or 'driver_training'
  SES().loadLevel(level, function()
    if not T then return end
    local pos, dir
    if def.laps and course.closed and course.starts[course.defaultStart or 1] then
      local sp = course.starts[course.defaultStart or 1]
      pos = sp.pos
      local q = sp.rot and quat(sp.rot[1], sp.rot[2], sp.rot[3], sp.rot[4])
      local f = q and (q * vec3(0, 1, 0)) or vec3(T.path[1].fx, T.path[1].fy, 0)
      dir = { x = f.x, y = f.y }
      T.gateIdx = 1
    else
      pos, dir = CO().startPose(T.path, T.rolling and 'rolling' or 'standing', def.start and def.start.back)
    end
    T.startDir = dir
    local d = vec3(dir.x, dir.y, 0):normalized()
    -- vehicleTransform puts the car's front on pos: move pos forward by half a car
    local front = vec3(pos.x, pos.y, pos.z) + d * 2.2
    local transform = { pos = vec3(front.x, front.y, front.z + 0.4), rot = quatFromDir(d, vec3(0, 0, 1)) }
    local function onSpawned(vehId)
      if not T then return end
      T.vehId = vehId
      M._fixHeading(vehId, d, front)
      local route, rdist = M.buildRoute(T.path)
      if route then
        T.route = route
        local info = LIC().testCar(def)
        if info and not T.opts.onResult then
          local ok, est = pcall(M.estimateRouteTime, def, info, route, T.path)
          if ok and est then LIC().setRouteEstimate(def.id, est) end
        end
        U().log('I', 'tests: route %d points, %.0f m', #route, rdist or 0)
      else
        U().log('W', 'tests: no road route for %s, guide uses checkpoints only', tostring(def.id))
      end
      local m = map and map.objects and map.objects[vehId]
      T.damage0 = m and m.damage or 0
      local v = veh(vehId)
      if v then v:queueLuaCommand('controller.setFreeze(1)') end
      T.phase = 'countdown'
      T.countdown = 3.5
      hud('TurismoTestPhase', { phase = 'intro', name = def.name, desc = def.goal or def.desc, tip = def.tip,
        targets = LIC().targetsFor(def), demo = T.opts.demo, place = def.place, rolling = T.rolling })
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

-- safety net: if a car stands the wrong way round, turn it (logged, so a
-- wrong rotation convention shows up in turismo.log)
function M._fixHeading(vehId, d, front)
  local v = veh(vehId)
  if not v or not v.getDirectionVector then return end
  local f = v:getDirectionVector()
  local dot = f.x * d.x + f.y * d.y
  if dot < 0 then
    U().log('W', 'tests: car faced the wrong way (dot %.2f), turning it', dot)
    local rot = quatFromDir(d, vec3(0, 0, 1))
    if spawn and spawn.safeTeleport then
      spawn.safeTeleport(v, v:getPosition(), rot, nil, nil, nil, nil, false)
    end
  end
end

local function pathTarget()
  return T.path and T.path[T.gateIdx]
end

local function pathLabel(i, g)
  if g.kind == 'stop' then return 'HIER ANHALTEN' end
  local rule = T.def.speed and (T.def.speed[tostring(i)] or T.def.speed[i])
  if i == #T.path then return 'ZIEL' end
  if rule and rule.min then return string.format('MIN. %d KM/H', rule.min) end
  if rule and rule.max then return string.format('MAX. %d KM/H', rule.max) end
  if i == 1 and T.rolling then return 'START' end
  return nil
end

-- markers: orange cones on both ends of every checkpoint, the next checkpoint
-- as a bright gate with banner, the one after it faint; green start/finish
local CONE = nil
local function drawPath()
  if not debugDrawer or not T.path then return end
  local white = ColorF(1, 1, 1, 1)
  local shadow = ColorI(0, 0, 0, 170)
  local cur = T.gateIdx
  for i, g in ipairs(T.path) do
    local ahead = i - cur
    if ahead >= -1 and ahead <= 3 then
      local col
      if i < cur then col = ColorF(0.25, 0.85, 0.35, 0.35)
      elseif i == cur then col = ColorF(1.0, 0.55, 0.05, 0.95)
      else col = ColorF(1.0, 0.55, 0.05, 0.45) end
      if g.kind == 'stop' then
        local c = {}
        for k, pt in ipairs({ { 0, -1 }, { 0, 1 }, { 1, 1 }, { 1, -1 }, { 0, -1 } }) do
          local al, la = pt[1] * g.len, pt[2] * g.w / 2
          c[k] = vec3(g.sx + g.fx * al + g.fy * la, g.sy + g.fy * al - g.fx * la, g.z + 0.05)
        end
        for k = 1, 4 do
          debugDrawer:drawSquarePrism(c[k], c[k + 1], Point2F(0.12, 0.35), Point2F(0.12, 0.35), col)
          debugDrawer:drawCylinder(c[k], c[k] + vec3(0, 0, 0.9), 0.14, col)
        end
      else
        local a, b = CO().gateEnds(g)
        local h = i == cur and 1.6 or 1.0
        local pa, pb = vec3(a.x, a.y, a.z), vec3(b.x, b.y, b.z)
        debugDrawer:drawCylinder(pa, pa + vec3(0, 0, h), 0.22, col)
        debugDrawer:drawCylinder(pb, pb + vec3(0, 0, h), 0.22, col)
        if i == cur or i == #T.path or (i == 1 and T.rolling) then
          local banner = (i == #T.path) and ColorF(1, 1, 1, 0.85) or col
          debugDrawer:drawSquarePrism(pa + vec3(0, 0, 0.04), pb + vec3(0, 0, 0.04), Point2F(0.06, 0.5), Point2F(0.06, 0.5), banner)
          debugDrawer:drawSquarePrism(pa + vec3(0, 0, h + 1.2), pb + vec3(0, 0, h + 1.2), Point2F(0.5, 0.15), Point2F(0.5, 0.15), banner)
        end
      end
      local label = i == cur and pathLabel(i, g)
      if label then
        debugDrawer:drawTextAdvanced(vec3(g.x, g.y, g.z + 3.4), label, white, true, false, shadow)
      end
    end
  end
  -- guide: orange arrows on the road for the next ~50 m (road network), or a
  -- short arrow towards the next checkpoint when there is no road data
  local g = pathTarget()
  local v = veh(T.vehId)
  if T.route and v then
    local p = v:getPosition()
    local R = T.route
    local best, bi = math.huge, T.routeIdx or 1
    for k = math.max(1, (T.routeIdx or 1) - 5), math.min(#R, (T.routeIdx or 1) + 60) do
      local d2 = (R[k].x - p.x) ^ 2 + (R[k].y - p.y) ^ 2
      if d2 < best then best, bi = d2, k end
    end
    T.routeIdx = bi
    local acc, k = 0, bi
    local col = ColorF(1.0, 0.55, 0.05, 0.5)
    while k < #R and acc < 50 do
      local a, b = R[k], R[k + 1]
      local seg = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
      if seg > 0.5 then
        local pa, pb = vec3(a.x, a.y, a.z + 0.12), vec3(b.x, b.y, b.z + 0.12)
        debugDrawer:drawSquarePrism(pa, pa + (pb - pa) * 0.6, Point2F(0.04, 0.9), Point2F(0.04, 0.05), col)
      end
      acc = acc + seg
      k = k + 1
    end
  elseif g and v then
    local p = v:getPosition()
    local to = vec3(g.x, g.y, p.z)
    local dirv = to - vec3(p.x, p.y, p.z)
    local dist = dirv:length()
    if dist > 6 then
      dirv = dirv / dist
      local a = vec3(p.x, p.y, p.z + 0.15) + dirv * 4
      local b = a + dirv * math.min(10, dist - 5)
      debugDrawer:drawSquarePrism(a, b, Point2F(0.06, 0.7), Point2F(0.06, 0.05), ColorF(1.0, 0.55, 0.05, 0.55))
    end
  end
end

-- angle of the next target relative to the car's nose (deg, + = right)
local function targetAngle(v, g)
  if not v or not g or not v.getDirectionVector then return nil end
  local p, f = v:getPosition(), v:getDirectionVector()
  local h1 = math.atan2(f.y, f.x)
  local h2 = math.atan2(g.y - p.y, g.x - p.x)
  local d = h1 - h2
  while d > math.pi do d = d - 2 * math.pi end
  while d < -math.pi do d = d + 2 * math.pi end
  return math.deg(d)
end

local function updatePath(dt)
  local v = veh(T.vehId)
  if not v then return end
  local pos = v:getPosition()
  local p2 = { x = pos.x, y = pos.y }
  local p1 = T.lastPos or p2
  T.lastPos = p2
  local speed = v:getVelocity():length()
  local kmh = speed * 3.6
  local def = T.def

  local m = map and map.objects and map.objects[T.vehId]
  if not def.ignoreDamage and m and (m.damage or 0) - T.damage0 > (def.collisionDamage or M.COLLISION_DAMAGE) then
    return fail('Kollision')
  end
  if T.lastWorld and pos:distance(T.lastWorld) > 12 then
    T.lastWorld = pos
    return fail('Fahrzeug zurückgesetzt')
  end
  T.lastWorld = pos
  if T.timing and def.timeLimit and T.time > def.timeLimit then return fail('Zeitlimit überschritten') end

  local g = pathTarget()
  if not g then return end

  if g.kind == 'stop' then
    local along = stopLocal(g, pos.x, pos.y)
    if along > g.len + 2.5 then return fail('Über die Haltezone hinaus') end
    if speed < M.STOP_SPEED and T.time > 0.5 then
      T.stillTime = (T.stillTime or 0) + dt
      if T.stillTime > 0.6 then
        if M.inStop(g, pos.x, pos.y) then return succeed(T.time) end
        if along > -20 then return fail('Außerhalb der Haltezone gestoppt') end
      end
    else
      T.stillTime = 0
    end
    return
  end

  -- leaving the course: far away from the line between the last and the next checkpoint
  local prev = T.path[T.gateIdx - 1] or T.path[1]
  local segLen = math.sqrt((g.x - prev.x) ^ 2 + (g.y - prev.y) ^ 2)
  local tol = def.offTrack or (10 + math.max(g.r, prev.r) + segLen * 0.22)
  local off = CO().distToSegment(pos.x, pos.y, prev, g)
  if T.gateIdx > 1 and off > tol then
    T.offTime = (T.offTime or 0) + dt
    T.offWarn = true
    if T.offTime > 3 then return fail('Strecke verlassen') end
  else
    T.offTime, T.offWarn = 0, false
  end

  if M.passedNode(g, p1, p2) then
    local rule = def.speed and (def.speed[tostring(T.gateIdx)] or def.speed[T.gateIdx])
    if rule and rule.min and kmh < rule.min then return fail(string.format('Zu langsam am Tor (%d statt %d km/h)', kmh, rule.min)) end
    if rule and rule.max and kmh > rule.max then return fail(string.format('Zu schnell am Tor (%d statt höchstens %d km/h)', kmh, rule.max)) end
    if T.gateIdx == 1 and T.rolling and not T.timing then
      T.timing = true
      T.time = 0
      hud('TurismoCountdown', { value = 0, green = true })
    end
    T.gateIdx = T.gateIdx + 1
    T.minDist = nil
    if extensions.turismo_audio then extensions.turismo_audio.play('gate') end
    if T.gateIdx > #T.path then return succeed(T.time) end
    return
  end
  -- missed: passed the checkpoint after the current one
  local nxt = T.path[T.gateIdx + 1]
  if nxt and nxt.kind ~= 'stop' and M.passedNode(nxt, p1, p2) then
    if def.penaltyPerGate then
      T.penalty = (T.penalty or 0) + def.penaltyPerGate
      T.gateIdx = T.gateIdx + 2
      if T.gateIdx > #T.path then return succeed(T.time) end
      return
    end
    return fail('Tor ausgelassen')
  end
  -- missed: was close, now driving away
  local dist = math.sqrt((p2.x - g.x) ^ 2 + (p2.y - g.y) ^ 2)
  T.minDist = math.min(T.minDist or math.huge, dist)
  if T.minDist < g.r + 12 and dist > T.minDist + 35 then return fail('Tor verpasst') end
end

-- demo: the AI drives along the road network through the checkpoints
local function startPathDemo()
  local v = veh(T.vehId)
  if not v then return end
  local names = {}
  if map and map.findClosestRoad then
    for _, g in ipairs(T.path) do
      local n1 = map.findClosestRoad(vec3(g.x, g.y, g.z))
      if n1 and names[#names] ~= n1 then names[#names + 1] = n1 end
    end
  end
  if #names >= 2 then
    v:queueLuaCommand('ai.driveUsingPath(' .. serialize({ wpTargetList = names, aggression = T.def.demoAggression or 0.9, avoidCars = 'off', noOfLaps = 1 }) .. ')')
    U().log('I', 'tests: demo via road network, %d waypoints', #names)
  else
    local script = {}
    for _, g in ipairs(T.path) do script[#script + 1] = { x = g.x, y = g.y, z = g.z, v = g.kind == 'stop' and 0 or nil } end
    v:queueLuaCommand(extensions.turismo_aiDirector.driveCommand({ script = script, aggression = T.def.demoAggression or 0.9, avoidCars = 'off' }))
    U().log('I', 'tests: demo via script, %d points', #script)
  end
end
M._startPathDemo = function() return startPathDemo() end

fail = function(reason)
  if not T or T.phase == 'done' then return end
  T.phase = 'done'
  T.failed = true
  T.reason = reason
  M._finish()
end

succeed = function(value)
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
    v:queueLuaCommand(extensions.turismo_aiDirector.driveCommand({ script = script, aggression = T.def.demoAggression or 0.95, avoidCars = 'off' }))
  end
end

---------------------------------------------------------------------------
-- update
---------------------------------------------------------------------------
-- course markers: tall pillars, a glowing line for the current gate, labels
-- and a guide line from the car to the next target, so it is always clear
-- where to drive
local function gateLabel(i, g)
  if g.def.label then return tostring(g.def.label) end
  if g.kind == 'stop' then return 'HIER ANHALTEN' end
  if i == #T.gates then return 'ZIEL' end
  return 'TOR ' .. i
end

local function drawCourse()
  if not debugDrawer or not T.gates then return end
  local white = ColorF(1, 1, 1, 1)
  local shadow = ColorI(0, 0, 0, 170)
  for i, g in ipairs(T.gates) do
    local col
    local current = i == T.gateIdx
    if i < T.gateIdx then col = ColorF(0.2, 0.9, 0.3, 0.45)
    elseif current then col = ColorF(1.0, 0.8, 0.1, 0.95)
    else col = ColorF(0.95, 0.95, 0.95, 0.6) end
    local h = current and 3.2 or 2.2
    if g.kind == 'stop' then
      local c1 = M.toWorld(T.anchor, g.lx - g.w / 2, g.ly)
      local c2 = M.toWorld(T.anchor, g.lx + g.w / 2, g.ly)
      local c3 = M.toWorld(T.anchor, g.lx + g.w / 2, g.ly + g.len)
      local c4 = M.toWorld(T.anchor, g.lx - g.w / 2, g.ly + g.len)
      local pts = { c1, c2, c3, c4, c1 }
      for k = 1, 4 do
        local p, q = pts[k], pts[k + 1]
        debugDrawer:drawSquarePrism(vec3(p.x, p.y, p.z + 0.03), vec3(q.x, q.y, q.z + 0.03), Point2F(0.1, 0.45), Point2F(0.1, 0.45), col)
        debugDrawer:drawCylinder(vec3(p.x, p.y, p.z), vec3(p.x, p.y, p.z + h), 0.18, col)
      end
    else
      local p, q = g.a, g.b
      debugDrawer:drawCylinder(vec3(p.x, p.y, p.z), vec3(p.x, p.y, p.z + h), current and 0.25 or 0.15, col)
      debugDrawer:drawCylinder(vec3(q.x, q.y, q.z), vec3(q.x, q.y, q.z + h), current and 0.25 or 0.15, col)
      if current or i == #T.gates then
        debugDrawer:drawSquarePrism(vec3(p.x, p.y, p.z + 0.03), vec3(q.x, q.y, q.z + 0.03), Point2F(0.1, 0.4), Point2F(0.1, 0.4), col)
        debugDrawer:drawSquarePrism(vec3(p.x, p.y, p.z + h), vec3(q.x, q.y, q.z + h), Point2F(0.25, 0.25), Point2F(0.25, 0.25), col)
      end
    end
    if current or i == #T.gates then
      debugDrawer:drawTextAdvanced(vec3(g.c.x, g.c.y, g.c.z + h + 0.8), gateLabel(i, g), white, true, false, shadow)
    end
  end
  -- guide line car -> current target
  local g = T.gates[T.gateIdx]
  local v = veh(T.vehId)
  if g and v then
    local p = v:getPosition()
    local target = g.kind == 'stop' and M.toWorld(T.anchor, g.lx, g.ly + g.len * 0.5) or g.c
    local from = vec3(p.x, p.y, p.z + 0.4)
    local to = vec3(target.x, target.y, target.z + 0.4)
    if (to - from):length() > 4 then
      debugDrawer:drawSquarePrism(from, to, Point2F(0.4, 0.06), Point2F(0.4, 0.06), ColorF(1.0, 0.8, 0.1, 0.35))
    end
  end
end

-- distance from the car to the current target (HUD)
local function targetDistance()
  local g = T.gates and T.gates[T.gateIdx]
  local v = veh(T.vehId)
  if not g or not v then return nil end
  local target = g.kind == 'stop' and M.toWorld(T.anchor, g.lx, g.ly + g.len * 0.5) or g.c
  local p = v:getPosition()
  return vec3(p.x, p.y, p.z):distance(vec3(target.x, target.y, target.z))
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
    if T.path then drawPath() end
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
      T.timing = not T.rolling
      if T.rolling and v and T.startDir then
        -- rolling start: give the car its entry speed
        local sp = ((T.def.start and T.def.start.speed) or 60) / 3.6
        if v.applyClusterVelocityScaleAdd and v.getRefNodeId then
          v:applyClusterVelocityScaleAdd(v:getRefNodeId(), 0, T.startDir.x * sp, T.startDir.y * sp, 0)
        end
      end
      if T.path and T.opts.demo then startPathDemo() end
      if T.race then T.race:startRace() end
      if T.opts.demo and T.gates then startDemo() end
      if T.opts.demo and T.race then
        local drive = { wpTargetList = T.race.aiPath, aggression = 1 }
        if v and T.race.aiPath and #T.race.aiPath > 1 then v:queueLuaCommand('ai.driveUsingPath(' .. serialize(drive) .. ')') end
      end
    end
  elseif T.phase == 'running' then
    if T.timing ~= false then T.time = T.time + dt end
    if T.path then
      drawPath()
      updatePath(dt)
    elseif T.gates then
      drawCourse()
      updateCourse(dt)
    elseif T.race then
      updateTrack(dt)
    end
    T.hudTimer = (T.hudTimer or 0) + dtReal
    if T.hudTimer > 0.1 and T.phase == 'running' then
      T.hudTimer = 0
      local v = veh(T.vehId)
      local pg = T.path and pathTarget()
      local pv = veh(T.vehId)
      hud('TurismoTestHud', {
        time = T.time, penalty = T.penalty, gate = T.gateIdx, gates = (T.gates and #T.gates) or (T.path and #T.path) or nil,
        nextLabel = (T.gates and T.gates[T.gateIdx] and gateLabel(T.gateIdx, T.gates[T.gateIdx])) or (pg and (pathLabel(T.gateIdx, pg) or ('TOR ' .. T.gateIdx))) or nil,
        nextDist = pg and pv and math.sqrt((pv:getPosition().x - pg.x) ^ 2 + (pv:getPosition().y - pg.y) ^ 2) or (T.gates and targetDistance()) or nil,
        nextAngle = pg and targetAngle(pv, pg) or nil,
        runup = T.path and T.rolling and not T.timing or nil,
        offTrack = T.offWarn or nil,
        speed = v and v:getVelocity():length() * 3.6 or 0,
        targets = LIC().targetsFor(T.def), name = T.def.name,
      })
    end
  end
end

return M
