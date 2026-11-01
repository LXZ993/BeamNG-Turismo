-- Turismo Karriere - aiDirector
-- Smarter race AI on top of BeamNG's racing AI (ai.lua, "race" mode).
--
-- Layer 1 (static, per driver): a driver profile (skill, consistency, racecraft,
--   aggression, style, reaction) is mapped onto the AI's own tuning parameters:
--   aggression, edgeDist (track usage), turnForceCoef (racing-line curvature),
--   awarenessForceCoef (car avoidance), staticFrictionCoefMult (braking points),
--   lookAheadKv, plus setRacing(true) and avoidCars.
-- Layer 2 (live, 4 Hz): a race director modulates every AI car's aggression
--   based on the situation: attack mode behind a slower car, defending, pressure
--   from a car close behind, mistakes (overcooked corner / lift), consistency
--   noise, damage limp mode, being lapped (blue flag), fatigue in long races,
--   optional catch-up ("Windschatten-Ausgleich") and formation lap pace.
-- All of it uses public vehicle-Lua functions (ai.setAggression, ai.setParameters,
-- ai.setSpeed/ai.setSpeedMode, ai.setAvoidCars, ai.setRecoverOnCrash).

local M = {}

local function U() return extensions.turismo_util end
local function D() return extensions.turismo_data end

M.TICK = 0.25

-- difficulty presets (profile setting) shift all drivers
M.difficulty = {
  easy     = { skill = -0.18, aggr = -0.08, mistakes = 1.6, label = 'Leicht' },
  normal   = { skill = 0.0,   aggr = 0.0,   mistakes = 1.0, label = 'Normal' },
  hard     = { skill = 0.08,  aggr = 0.03,  mistakes = 0.7, label = 'Schwer' },
  pro      = { skill = 0.15,  aggr = 0.06,  mistakes = 0.45, label = 'Profi' },
}

-- tier defaults when a driver entry lacks explicit stats
M.tiers = {
  rookie  = { skill = 0.35, consistency = 0.40, racecraft = 0.30, aggression = 0.40, reaction = 0.55 },
  amateur = { skill = 0.55, consistency = 0.55, racecraft = 0.50, aggression = 0.50, reaction = 0.45 },
  pro     = { skill = 0.75, consistency = 0.72, racecraft = 0.70, aggression = 0.60, reaction = 0.35 },
  expert  = { skill = 0.88, consistency = 0.85, racecraft = 0.82, aggression = 0.65, reaction = 0.28 },
  legend  = { skill = 0.97, consistency = 0.93, racecraft = 0.92, aggression = 0.70, reaction = 0.22 },
}

-- style modifiers
M.styles = {
  smooth      = { aggr = -0.01, mistakes = 0.8, attack = 0.7, defend = 0.8 },
  aggressive  = { aggr = 0.03,  mistakes = 1.3, attack = 1.4, defend = 1.1 },
  defensive   = { aggr = 0.0,   mistakes = 0.9, attack = 0.8, defend = 1.5 },
  latebraker  = { aggr = 0.02,  mistakes = 1.15, attack = 1.2, defend = 1.0, friction = 0.015 },
  wet         = { aggr = 0.0,   mistakes = 1.0, attack = 1.0, defend = 1.0 },
}

---------------------------------------------------------------------------
-- profile -> parameters (pure)
---------------------------------------------------------------------------
function M.resolveProfile(driver, difficultyId)
  local u = U()
  local tier = M.tiers[driver.tier or 'amateur'] or M.tiers.amateur
  local p = {}
  for k, v in pairs(tier) do p[k] = driver[k] ~= nil and driver[k] or v end
  p.style = driver.style or 'smooth'
  p.name = driver.name
  local diff = M.difficulty[difficultyId or 'normal'] or M.difficulty.normal
  p.skill = u.clamp(p.skill + diff.skill, 0.05, 1.0)
  p.mistakeMult = diff.mistakes * ((M.styles[p.style] or M.styles.smooth).mistakes or 1)
  p.aggrOffset = diff.aggr + ((M.styles[p.style] or M.styles.smooth).aggr or 0)
  return p
end

function M.parametersFor(p, opts)
  local u = U()
  opts = opts or {}
  local style = M.styles[p.style] or M.styles.smooth
  local skill = p.skill
  local baseAggr = u.clamp(0.62 + 0.40 * skill + (p.aggrOffset or 0), 0.45, 1.08)
  if opts.surface == 'dirt' or opts.surface == 'snow' then baseAggr = baseAggr - 0.04 end
  if opts.wet then baseAggr = baseAggr - 0.06 * (1 - (p.wetSkill or skill)) end
  local params = {
    edgeDist = u.clamp(1.4 - 1.4 * skill, 0, 1.4),
    turnForceCoef = u.clamp(0.6 + 3.4 * (skill ^ 1.5), 0.3, 4.5),
    awarenessForceCoef = u.clamp(0.06 + 0.32 * (p.racecraft or 0.5), 0.02, 0.45),
    staticFrictionCoefMult = u.clamp(0.86 + 0.10 * skill + (style.friction or 0), 0.8, 0.985),
    lookAheadKv = u.clamp(0.52 + 0.12 * skill, 0.45, 0.7),
  }
  if opts.surface == 'dirt' or opts.surface == 'snow' then params.driveStyle = 'offRoad' end
  return baseAggr, params
end

---------------------------------------------------------------------------
-- runtime
---------------------------------------------------------------------------
local racers = {}      -- vehId -> state
local session = nil    -- {opts}

local function veh(id) return getObjectByID and getObjectByID(id) end

local function send(id, cmd)
  local v = veh(id)
  if v then v:queueLuaCommand(cmd) end
end

local function setAggr(r, a)
  a = U().clamp(a, 0.3, 1.15)
  if not r.sentAggr or math.abs(r.sentAggr - a) > 0.008 then
    r.sentAggr = a
    send(r.id, string.format('ai.setAggression(%.3f)', a))
  end
end

-- opts: { difficulty, surface, wet, catchUp ('off'|'light'|'classic'), laps, length }
function M.begin(opts)
  racers = {}
  session = { opts = opts or {}, time = 0, tick = 0, rng = U().rng((opts and opts.seed) or os.time()) }
end

function M.stop()
  for id in pairs(racers) do send(id, 'ai.setMode("stop")') end
  racers = {}
  session = nil
end

-- registers an AI car; aiPath/script handed over by the race module
function M.addRacer(vehId, driver, drive)
  if not session then M.begin({}) end
  local p = M.resolveProfile(driver, session.opts.difficulty)
  local baseAggr, params = M.parametersFor(p, session.opts)
  racers[vehId] = {
    id = vehId, driver = driver, p = p, baseAggr = baseAggr, params = params,
    drive = drive, aggr = baseAggr, mode = 'grid',
    effects = {},            -- active temporary modifiers {kind, delta, t}
    noise = 0, noiseTimer = 0,
    stuckTime = 0, lastPos = nil, damage0 = nil,
    startDelay = 0.15 + (p.reaction or 0.4) * 0.6 * (0.6 + session.rng:next() * 0.8),
  }
  return racers[vehId]
end

function M.racer(id) return racers[id] end
function M.removeRacer(id) racers[id] = nil end
function M.now() return session and session.time or 0 end
function M.racers() return racers end

-- pushes static parameters and path; vehicle stays frozen until release()
function M.prepare(vehId)
  local r = racers[vehId]
  if not r then return end
  send(vehId, 'ai.setParameters(' .. serialize(r.params) .. ')')
  send(vehId, 'ai.setRacing(true)')
  send(vehId, 'ai.setAvoidCars("on")')
  if r.params.driveStyle then send(vehId, 'ai.setParameters({driveStyle = "offRoad"})') end
  pcall(send, vehId, 'if ai.setRecoverOnCrash then ai.setRecoverOnCrash(true) end')
end

local function drivePath(r, extra)
  local d = U().deepcopy(r.drive or {})
  d.aggression = r.aggr
  d.avoidCars = 'on'
  for k, v in pairs(extra or {}) do d[k] = v end
  send(r.id, 'ai.driveUsingPath(' .. serialize(d) .. ')')
  send(r.id, 'ai.setRacing(true)')
  send(r.id, 'ai.setParameters(' .. serialize(r.params) .. ')')
end

-- formation lap: drive the path at limited speed in grid order
function M.startFormation(speedMs)
  for _, r in pairs(racers) do
    r.mode = 'formation'
    send(r.id, 'controller.setFreeze(false)')
    drivePath(r, { routeSpeed = speedMs or 20, routeSpeedMode = 'limit' })
  end
end

-- race start: release every car after its personal reaction time
function M.release()
  for _, r in pairs(racers) do
    r.mode = 'launch'
    r.releaseAt = (session and session.time or 0) + r.startDelay
  end
end

function M.setSpeedLimit(id, speedMs)
  if speedMs then
    send(id, string.format('ai.setSpeed(%.2f) ai.setSpeedMode("limit")', speedMs))
  else
    send(id, 'ai.setSpeedMode("off")')
  end
end

local function addEffect(r, kind, delta, duration)
  for _, e in ipairs(r.effects) do
    if e.kind == kind then e.t = math.max(e.t, duration) e.delta = delta return end
  end
  r.effects[#r.effects + 1] = { kind = kind, delta = delta, t = duration }
end

-- context from the race module per tick:
-- ctx[vehId] = { pos=vec3, speed, progress (m along race), lap, place, finished,
--                damage, ahead={id,gap(m),speed}, behind={id,gap,speed},
--                isPlayerBehind, playerLapsAhead }
function M.update(dt, ctx)
  if not session then return end
  session.time = session.time + dt
  session.tick = session.tick + dt
  if session.tick < M.TICK then return end
  local step = session.tick
  session.tick = 0
  local u = U()
  local rng = session.rng
  local opts = session.opts

  -- leader & player progress for catch-up
  local leaderProg, playerProg = 0, nil
  for id, c in pairs(ctx or {}) do
    if c.progress and c.progress > leaderProg then leaderProg = c.progress end
    if c.isPlayer then playerProg = c.progress end
  end

  for id, r in pairs(racers) do
    local c = ctx and ctx[id] or {}
    if r.mode == 'launch' and session.time >= (r.releaseAt or 0) then
      r.mode = 'race'
      send(id, 'controller.setFreeze(false)')
      drivePath(r)
    end

    if r.mode == 'race' and not c.finished then
      local p = r.p
      local style = M.styles[p.style] or M.styles.smooth

      -- consistency noise (re-rolled every 3-8 s)
      r.noiseTimer = r.noiseTimer - step
      if r.noiseTimer <= 0 then
        r.noiseTimer = 3 + rng:next() * 5
        r.noise = rng:gauss() * (1 - (p.consistency or 0.6)) * 0.045
      end

      -- mistakes: per-minute probability scaled by skill, style, difficulty and pressure
      local pressure = (c.behind and c.behind.gap and c.behind.gap < 12) and 1.6 or 1
      local perMin = (1 - p.skill) * 0.55 * (p.mistakeMult or 1) * pressure
      if rng:next() < perMin * step / 60 then
        if rng:next() < 0.55 then
          addEffect(r, 'overcook', 0.14 + rng:next() * 0.08, 1.0 + rng:next() * 0.8) -- too fast into a corner
        else
          addEffect(r, 'lift', -(0.12 + rng:next() * 0.1), 1.2 + rng:next() * 1.2)   -- braking too early / lift
        end
      end

      -- attack: close behind a car -> push (overtake attempt)
      if c.ahead and c.ahead.gap and c.ahead.gap < 18 then
        local push = 0.025 * (p.aggression or 0.5) * (style.attack or 1)
        if (c.ahead.speed or 0) < (c.speed or 0) - 1 then push = push * 1.4 end
        addEffect(r, 'attack', push, 1.0)
      end
      -- defend: someone right behind -> cleaner, slightly faster exits
      if c.behind and c.behind.gap and c.behind.gap < 10 then
        addEffect(r, 'defend', 0.012 * (p.racecraft or 0.5) * (style.defend or 1), 1.0)
      end
      -- blue flag: player a lap ahead and approaching -> give way
      if c.playerLapsAhead and c.playerLapsAhead >= 1 and c.isPlayerBehind and c.behind and c.behind.gap < 40 then
        addEffect(r, 'blueflag', -0.12, 1.0)
      end
      -- damage: limp mode proportional to damage
      if c.damage and c.damage > 0.25 then
        addEffect(r, 'damage', -u.clamp(c.damage * 0.25, 0.05, 0.3), 1.0)
      end
      -- fatigue/tyre drop-off in long races (after 15 min)
      local fatigue = 0
      if session.time > 900 then
        fatigue = -u.clamp((session.time - 900) / 3600, 0, 1) * 0.04 * (1 - (p.consistency or 0.6))
      end
      -- catch-up: subtle, off by default for "authentic" races
      local catch = 0
      if opts.catchUp and opts.catchUp ~= 'off' and playerProg and c.progress then
        local gap = playerProg - c.progress -- positive: player ahead
        local k = opts.catchUp == 'classic' and 1 or 0.5
        catch = u.clamp(gap / 400, -1, 1) * 0.03 * k
      end

      -- tick down effects
      local eff = 0
      for i = #r.effects, 1, -1 do
        local e = r.effects[i]
        e.t = e.t - step
        if e.t <= 0 then table.remove(r.effects, i) else eff = eff + e.delta end
      end
      r.aggr = r.baseAggr + r.noise + eff + fatigue + catch
      setAggr(r, r.aggr)

      -- stuck detection -> AI recovery helper
      if c.speed and c.speed < 1 then r.stuckTime = r.stuckTime + step else r.stuckTime = 0 end
      if r.stuckTime > 7 then
        r.stuckTime = 0
        send(id, 'if recovery and recovery.recoverInPlace then recovery.recoverInPlace() end')
        drivePath(r)
      end
    elseif c.finished and r.mode ~= 'cooldown' then
      r.mode = 'cooldown'
      setAggr(r, 0.45)
    end
  end
end

-- debug info for the HUD/dev overlay
function M.debugInfo()
  local res = {}
  for id, r in pairs(racers) do
    local eff = {}
    for _, e in ipairs(r.effects) do eff[#eff + 1] = e.kind end
    res[#res + 1] = { id = id, name = r.p.name, aggr = r.sentAggr, mode = r.mode, effects = table.concat(eff, ',') }
  end
  return res
end

---------------------------------------------------------------------------
-- lap time model (qualifying simulation for AI, target times), self-calibrating
---------------------------------------------------------------------------
-- pure: reference lap time for a track length and LI
function M.referenceLapTime(lengthM, li, trackFactor)
  local avg = 17 + (li or 400) * 0.043 -- m/s
  return (lengthM or 3000) / avg * (trackFactor or 1)
end

function M.simulatedLapTime(driver, lengthM, li, trackFactor, rng, difficultyId)
  local p = M.resolveProfile(driver, difficultyId)
  local ref = M.referenceLapTime(lengthM, li, trackFactor)
  local slow = (1 - p.skill) * 0.07
  local spread = (1 - (p.consistency or 0.6)) * 0.012 * (rng and rng:gauss() or 0)
  return ref * (1 + slow + spread)
end

return M
