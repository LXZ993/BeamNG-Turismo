-- Turismo Karriere - drag ("Drag-Wochenende")
-- Format: qualifying passes (best ET seeds the ladder) -> elimination ladder of
-- 8 (quarter-final, semi-final, final). Each of your rounds is a real side-by-side
-- run against an AI car (vehicle extension turismoDragAi); the other pairings
-- are simulated with the classic power-to-weight ET formula.
-- Tree: sportsman (3 ambers 0.5 s apart) or pro tree (all ambers, 0.4 s).
-- Bracket racing ("Dial-in"): handicap start from the dial-in difference;
-- breaking out (running quicker than your dial) loses the round.
-- Timing: reaction, 60 ft, 330 ft, 1/8 mile, 1000 ft, 1/4 mile, trap speed.

local M = {}

local function U() return extensions.turismo_util end
local function SES() return extensions.turismo_session end
local function P() return extensions.turismo_profile end
local function VDB() return extensions.turismo_vehicleDb end
local function AI() return extensions.turismo_aiDirector end

local DR = nil

M.SPLITS = { { id = 'ft60', m = 18.29, label = '60 ft' }, { id = 'ft330', m = 100.58, label = '330 ft' },
             { id = 'eighth', m = 201.17, label = '1/8 Meile' }, { id = 'ft1000', m = 304.8, label = '1000 ft' },
             { id = 'quarter', m = 402.34, label = '1/4 Meile' } }

local function hud(name, data) if guihooks then guihooks.trigger(name, data) end end
local function toast(msg, kind) if extensions.hook then extensions.hook('onTurismoToast', msg, kind or 'info') end end
local function veh(id) return id and getObjectByID and getObjectByID(id) or nil end

function M.isActive() return DR ~= nil end

---------------------------------------------------------------------------
-- pure models
---------------------------------------------------------------------------
-- quarter-mile ET and trap speed (km/h) from power (PS) and weight (kg)
function M.estimateQuarter(hp, kg, drivetrain)
  local lb = (kg or 1400) * 2.2046 + 180 -- + driver
  hp = math.max(30, hp or 100)
  local et = 5.825 * (lb / hp) ^ (1 / 3)
  local mph = 234 * (hp / lb) ^ (1 / 3)
  -- traction: RWD/FWD with big power lose time off the line
  local d = U().lower(drivetrain)
  local pw = hp / (kg / 1000)
  if d ~= 'awd' and d ~= '4wd' then et = et + U().remap(pw, 150, 450, 0, 0.6) end
  return et, mph * 1.609
end

function M.estimateET(info, distanceM, skill)
  local et = M.estimateQuarter(info.power_hp, info.weight_kg, info.drivetrain)
  if distanceM and distanceM < 300 then et = et * 0.64 end
  return et * (1 + (1 - (skill or 0.6)) * 0.03)
end

-- reaction time (s) for a driver profile, rng for variance; may red-light
function M.simReaction(p, rng)
  local base = 0.5 - 0.35 * (p.skill or 0.5) + (rng:next() - 0.5) * 0.12 * (1 - (p.consistency or 0.5))
  return base
end

---------------------------------------------------------------------------
-- strip geometry
---------------------------------------------------------------------------
local function findStrip(level, file)
  if file and FS:fileExists(file) then return file end
  local dir = '/levels/' .. level .. '/dragstrips/'
  local files = FS:findFiles(dir, '*.dragData.json', -1, true, false) or {}
  if not files[1] then files = FS:findFiles(dir, '*.strip.json', -1, true, false) or {} end
  return files[1]
end

local function tv(t)
  if type(t) ~= 'table' then return nil end
  local x, y, z = t.x or t[1], t.y or t[2], t.z or t[3]
  if not (x and y and z) then return nil end
  return vec3(x, y, z)
end

local function wpPos(wp)
  local tf = type(wp) == 'table' and wp.transform
  return tf and (tv(tf.position) or tv(tf.pos)) or nil
end

-- BeamNG 0.40 drag data comes in two shapes:
--  * modular: <x>.dragData.json { stripId = '<y>.strip.json' } and the strip file
--    with lanes[].waypoints = array of { type = 'stage'|'endLine'|..., transform = { position } }
--  * legacy: strip.lanes[].waypoints = { stage = { transform = { pos } }, endLine = ... }
-- (same rules as gameplay/drag/saveSystem.loadDragStripData, without its scenetree side effects)
local function readLanes(file)
  local data = jsonReadFile(file)
  if not data then return nil end
  local rawLanes
  if data.stripId then
    local strip = FS:fileExists(data.stripId) and jsonReadFile(data.stripId) or nil
    rawLanes = strip and strip.lanes
  elseif data.strip and data.strip.lanes then
    rawLanes = data.strip.lanes
  elseif data.lanes then -- a .strip.json picked directly
    rawLanes = data.lanes
  end
  if type(rawLanes) ~= 'table' then return nil end
  table.sort(rawLanes, function(a, b) return (a.laneOrder or 0) < (b.laneOrder or 0) end)
  local lanes = {}
  for _, lane in ipairs(rawLanes) do
    local wps = {}
    for k, wp in pairs(lane.waypoints or {}) do
      local typ = type(k) == 'string' and k or (type(wp) == 'table' and wp.type)
      if typ then wps[typ] = wp end
    end
    local stage, finish = wpPos(wps.stage), wpPos(wps.endLine)
    if stage and finish then
      lanes[#lanes + 1] = { stage = stage, finish = finish, dir = (finish - stage):normalized(), length = (finish - stage):length() }
    end
  end
  return lanes
end
M._readLanes = readLanes

-- synthetic lanes for levels without drag data: straight from the level spawn
local function syntheticLanes(distance)
  local anchor = SES().venueAnchor({ id = 'dragstrip_' .. (SES().currentLevel() or 'x') })
  if not anchor then return nil end
  local s = vec3(anchor.pos.x, anchor.pos.y, anchor.pos.z)
  local fwd = vec3(anchor.fwd.x, anchor.fwd.y, 0)
  local right = vec3(anchor.right.x, anchor.right.y, 0)
  return {
    { stage = s - right * 2.5, finish = s - right * 2.5 + fwd * distance, dir = fwd, length = distance },
    { stage = s + right * 2.5, finish = s + right * 2.5 + fwd * distance, dir = fwd, length = distance },
  }
end

local function stageObject(lane)
  DR.pathObj = DR.pathObj or require('/lua/ge/extensions/gameplay/race/path')('drag')
  local sp = DR.pathObj.startPositions:create('lane')
  sp:set(lane.stage, quatFromDir(lane.dir, vec3(0, 0, 1)))
  return sp
end

---------------------------------------------------------------------------
-- setup
---------------------------------------------------------------------------
-- cfg: { title, level, stripFile, distance (402.34|201.17), tree ('sportsman'|'pro'),
--        bracket (bool), qualifyingRuns, field, playerCarId, difficulty, eventRef, onFinish }
function M.start(cfg)
  if DR then M.abort() end
  DR = { cfg = cfg, phase = 'loading', time = 0, runs = {}, round = 0, hudTimer = 0 }
  SES().loadLevel(cfg.level, function()
    local file = findStrip(cfg.level, cfg.stripFile)
    local lanes = file and readLanes(file) or syntheticLanes(cfg.distance or 402.34)
    if not lanes or not lanes[1] or not lanes[2] then
      toast('Keine Dragstrip-Daten auf diesem Level gefunden.', 'error')
      DR = nil
      return
    end
    DR.lanes = lanes
    DR.distance = math.min(cfg.distance or 402.34, lanes[1].length)
    DR.sp = { stageObject(lanes[1]), stageObject(lanes[2]) }
    SES().spawnPlayerCar(cfg.playerCarId, { startPosition = DR.sp[1] }, function(id)
      DR.playerId = id
      DR.qualiLeft = cfg.qualifyingRuns or 2
      M._prepareRun(nil)
    end)
  end)
  return true
end

-- opponent: field entry or nil for a solo qualifying pass
function M._prepareRun(opponent)
  local cfg = DR.cfg
  DR.phase = 'staging'
  DR.opponent = opponent
  DR.sp[1]:moveResetVehicleTo(DR.playerId, false, false)
  local pv = veh(DR.playerId)
  if pv then pv:queueLuaCommand('controller.setFreeze(0)') end
  if DR.oppId then local v = veh(DR.oppId) if v then v:delete() end DR.oppId = nil end
  if opponent then
    local model, config = U().splitCarKey(opponent.carKey)
    local lane = DR.lanes[2]
    local v = core_vehicles.spawnNewVehicle(model, { config = 'vehicles/' .. model .. '/' .. (config or 'base') .. '.pc',
      pos = lane.stage - lane.dir * 2.5 + vec3(0, 0, 0.5), rot = quatFromEuler(0, 0, math.pi) * quatFromDir(lane.dir, vec3(0, 0, 1)),
      autoEnterVehicle = false })
    DR.oppId = v:getID()
    SES().defer(1.2, function()
      if not DR then return end
      DR.sp[2]:moveResetVehicleTo(DR.oppId, false, true)
      local p = AI().resolveProfile(opponent.driver, cfg.difficulty)
      DR.oppProfile = p
      local target = lane.finish + lane.dir * 400
      local ov = veh(DR.oppId)
      if ov then
        ov:queueLuaCommand('extensions.load("turismoDragAi")')
        ov:queueLuaCommand('turismoDragAi.setup(' .. serialize({
          target = { x = target.x, y = target.y, z = target.z },
          launchThrottle = 0.55 + 0.4 * p.skill, slipLimit = 0.08 + 0.1 * (1 - p.skill), reaction = 0.05,
        }) .. ')')
        ov:queueLuaCommand('turismoDragAi.stage()')
      end
    end)
  end
  -- dial-in for bracket racing
  if cfg.bracket then
    DR.dialPlayer = DR.dialPlayer or (DR.bestET and (DR.bestET + 0.05)) or 15
    DR.dialOpp = opponent and opponent.dial or nil
  end
  hud('TurismoDragPhase', { phase = 'staging', round = DR.round, opponent = opponent and opponent.driver.name,
    qualifying = opponent == nil, dial = DR.dialPlayer, oppDial = DR.dialOpp, bracket = cfg.bracket, title = cfg.title,
    roundName = opponent == nil and ('Qualifying ' .. ((cfg.qualifyingRuns or 2) - (DR.qualiLeft or 1) + 1)) or
      ((DR.ladder and #DR.ladder <= 2) and 'Finale' or (DR.ladder and #DR.ladder <= 4) and 'Halbfinale' or 'Viertelfinale') })
  DR.stageTimer = 2.5
end

-- tree sequence: ambers then green; lane offsets for bracket handicap
local function treeStart()
  local cfg = DR.cfg
  DR.phase = 'tree'
  DR.treeTime = 0
  local amber = cfg.tree == 'pro' and 0.4 or 1.5
  DR.greenAt = { amber, amber }
  if cfg.bracket and DR.dialOpp and DR.dialPlayer then
    -- slower dial gets the green earlier
    local diff = DR.dialPlayer - DR.dialOpp
    if diff > 0 then DR.greenAt[2] = amber + diff else DR.greenAt[1] = amber - diff end
  end
  DR.state = {}
  for lane, id in ipairs({ DR.playerId, DR.oppId }) do
    if id then
      DR.state[lane] = { id = id, start = nil, splits = {}, origin = DR.lanes[lane].stage, dir = DR.lanes[lane].dir, foul = false, done = false }
    end
  end
  hud('TurismoDragTree', { phase = 'ambers', tree = cfg.tree or 'sportsman', greenAt = DR.greenAt[1] })
end

local function laneDistance(st, pos)
  return (pos - st.origin):dot(st.dir)
end

local function finishRun()
  DR.phase = 'runDone'
  local res = { lanes = {} }
  for lane, st in pairs(DR.state) do
    local et = st.splits.quarter or st.splits[DR.distance < 300 and 'eighth' or 'quarter']
    res.lanes[lane] = { reaction = st.reaction, et = st.et, trap = st.trap, splits = st.splits, foul = st.foul }
  end
  DR.lastRun = res
  local me, opp = res.lanes[1], res.lanes[2]
  if me.et and (not DR.bestET or me.et < DR.bestET) and not me.foul then DR.bestET = me.et end
  local playerWins
  if opp then
    if me.foul ~= opp.foul then playerWins = opp.foul
    elseif DR.cfg.bracket then
      local mBreak = me.et and me.et < DR.dialPlayer
      local oBreak = opp.et and opp.et < (DR.dialOpp or 0)
      if mBreak ~= oBreak then playerWins = oBreak
      else
        local mTotal = (me.reaction or 9) + ((me.et or 99) - DR.dialPlayer)
        local oTotal = (opp.reaction or 9) + ((opp.et or 99) - (DR.dialOpp or 0))
        playerWins = mTotal < oTotal
      end
    else
      local mTotal = (me.reaction or 9) + (me.et or 99)
      local oTotal = (opp.reaction or 9) + (opp.et or 99)
      playerWins = mTotal < oTotal
    end
  end
  res.playerWins = playerWins
  hud('TurismoDragResult', res)
  table.insert(DR.runs, res)
  DR.nextAt = DR.time + 6
end

-- after a run: next qualifying pass, next round, or the end
local function advance()
  local cfg = DR.cfg
  if DR.qualiLeft and DR.qualiLeft > 0 then
    DR.qualiLeft = DR.qualiLeft - 1
    if DR.qualiLeft > 0 then return M._prepareRun(nil) end
    M._buildLadder()
  else
    local won = DR.lastRun.playerWins
    if not won then return M._finishEvent(false) end
    if #DR.ladder <= 2 then return M._finishEvent(true) end
    M._simulateOthers()
  end
  local opp = M._nextOpponent()
  if not opp then return M._finishEvent(true) end
  DR.round = DR.round + 1
  M._prepareRun(opp)
end

---------------------------------------------------------------------------
-- ladder
---------------------------------------------------------------------------
function M._buildLadder()
  local cfg = DR.cfg
  local rng = U().rng(U().hashString(cfg.eventRef or 'drag') + P().day())
  local entries = { { isPlayer = true, et = DR.bestET or 99, name = 'Du' } }
  for _, f in ipairs(cfg.field) do
    local info = VDB().get(f.carKey)
    local p = AI().resolveProfile(f.driver, cfg.difficulty)
    local et = info and M.estimateET(info, DR.distance, p.skill) or 16
    f.simET = et * (1 + rng:gauss() * 0.01)
    f.dial = f.simET + 0.05
    entries[#entries + 1] = { field = f, et = f.simET, name = f.driver.name }
  end
  table.sort(entries, function(a, b) return a.et < b.et end)
  while #entries > 8 do table.remove(entries) end
  -- seeding 1v8, 2v7, ...
  local ladder = {}
  local n = #entries
  for i = 1, math.floor(n / 2) do
    ladder[#ladder + 1] = { entries[i], entries[n + 1 - i] }
  end
  DR.ladder = ladder
  DR.seeds = entries
  DR.eliminated = {}
  hud('TurismoDragLadder', { seeds = U().map(entries, function(e) return { name = e.name, et = e.et, isPlayer = e.isPlayer } end) })
end

function M._nextOpponent()
  for _, pair in ipairs(DR.ladder) do
    if pair[1].isPlayer then return pair[2].field end
    if pair[2].isPlayer then return pair[1].field end
  end
  return nil
end

-- simulates the other pairings of the round and builds the next round
function M._simulateOthers()
  local rng = U().rng(U().hashString(DR.cfg.eventRef or 'x') + DR.round * 13)
  local winners = {}
  for _, pair in ipairs(DR.ladder) do
    local a, b = pair[1], pair[2]
    local w
    if a.isPlayer or b.isPlayer then
      w = a.isPlayer and a or b
      DR.eliminated[#DR.eliminated + 1] = a.isPlayer and b or a
    else
      local ta = a.et + 0.4 + rng:gauss() * 0.06
      local tb = b.et + 0.4 + rng:gauss() * 0.06
      w = ta <= tb and a or b
      DR.eliminated[#DR.eliminated + 1] = ta <= tb and b or a
    end
    winners[#winners + 1] = w
  end
  local nextLadder = {}
  for i = 1, #winners, 2 do
    if winners[i + 1] then nextLadder[#nextLadder + 1] = { winners[i], winners[i + 1] } end
  end
  DR.ladder = nextLadder
end

function M._finishEvent(playerWon)
  local cfg = DR.cfg
  local roundsTotal = math.ceil(math.log(#(DR.seeds or { 1, 2 })) / math.log(2))
  local pos
  if playerWon then pos = 1
  else
    -- lost in round r (1 = first round): finals loser 2nd, semis 3rd, quarters 5th
    local remaining = #DR.ladder * 2
    pos = remaining > 0 and (remaining / 2 + 1) or 2
    if DR.round == roundsTotal then pos = 2 end
  end
  local list = { { pos = pos, name = extensions.turismo_save.get().meta.playerName or 'Du', isPlayer = true, bestET = DR.bestET } }
  if DR.oppId then local v = veh(DR.oppId) if v then v:delete() end DR.oppId = nil end
  DR.phase = 'results'
  SES().capturePlayerCar(function()
    local results = { list = list, mode = 'drag', runs = DR.runs, bestET = DR.bestET, position = pos, cleanRace = true }
    results.rewards = cfg.onFinish and cfg.onFinish(results) or {}
    hud('TurismoRaceResults', results)
  end)
end

---------------------------------------------------------------------------
-- update
---------------------------------------------------------------------------
function M.update(dtReal, dtSim)
  if not DR then return end
  local dt = dtSim or dtReal
  DR.time = DR.time + dt
  if DR.phase == 'staging' then
    DR.stageTimer = DR.stageTimer - dtReal
    if DR.stageTimer <= 0 then treeStart() end
  elseif DR.phase == 'tree' or DR.phase == 'running' then
    DR.treeTime = DR.treeTime + dt
    local allDone = true
    for lane, st in pairs(DR.state) do
      local v = veh(st.id)
      if v then
        local pos = v:getPosition()
        local d = laneDistance(st, pos)
        local greenAt = DR.greenAt[lane]
        if not st.greenSeen and DR.treeTime >= greenAt then
          st.greenSeen = true
          if lane == 1 then hud('TurismoDragTree', { phase = 'green' }) if extensions.turismo_audio then extensions.turismo_audio.play('race_go') end end
          if lane == 2 then
            local rng = U().rng(os.time() + DR.round)
            local react = M.simReaction(DR.oppProfile or {}, rng)
            -- 2% red-light chance for nervous drivers
            if rng:next() < 0.02 * (1 - (DR.oppProfile and DR.oppProfile.consistency or 0.5)) then react = -0.05 end
            if react < 0 then st.foul = true react = 0.02 end
            v:queueLuaCommand(string.format('turismoDragAi.go(%.3f)', react))
          end
        end
        -- start of the run: leaves the stage beam (0.3 m rollout)
        if not st.start and d > 0.3 then
          st.start = DR.treeTime
          st.reaction = DR.treeTime - greenAt
          if st.reaction < 0 and lane == 1 then
            st.foul = true
            if lane == 1 then hud('TurismoDragTree', { phase = 'red' }) toast('Fehlstart! Rotes Licht.', 'error') end
          end
        end
        if st.start and not st.done then
          for _, sp in ipairs(M.SPLITS) do
            if sp.m <= DR.distance + 0.01 and not st.splits[sp.id] and d >= sp.m then
              st.splits[sp.id] = DR.treeTime - st.start
            end
          end
          if d >= DR.distance then
            st.done = true
            st.et = DR.treeTime - st.start
            st.trap = v:getVelocity():length() * 3.6
            if lane == 2 then v:queueLuaCommand('turismoDragAi.finish()') end
          end
        end
        if not st.done then allDone = false end
      end
    end
    if DR.phase == 'tree' then
      for _, st in pairs(DR.state) do if st.start then DR.phase = 'running' end end
    end
    if allDone or DR.treeTime > 40 then finishRun() end
    DR.hudTimer = DR.hudTimer + dtReal
    if DR.hudTimer > 0.05 and DR.state[1] then
      DR.hudTimer = 0
      local st = DR.state[1]
      local v = veh(st.id)
      hud('TurismoDragHud', { time = st.start and (DR.treeTime - st.start) or 0, reaction = st.reaction,
        speed = v and v:getVelocity():length() * 3.6 or 0, splits = st.splits, done = st.done,
        oppSplits = DR.state[2] and DR.state[2].splits })
    end
  elseif DR.phase == 'runDone' then
    if DR.time >= DR.nextAt then advance() end
  end
end

-- UI: bracket dial-in before a round
function M.setDial(v) if DR then DR.dialPlayer = tonumber(v) or DR.dialPlayer end end

function M.abort()
  if not DR then return end
  if DR.oppId then local v = veh(DR.oppId) if v then v:delete() end end
  DR = nil
  hud('TurismoDragPhase', { phase = 'idle' })
end

function M.close()
  M.abort()
  SES().returnToHub()
end

return M
