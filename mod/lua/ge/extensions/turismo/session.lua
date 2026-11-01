-- Turismo Karriere - session
-- Level loading, spawning the player's garage car (with persistent damage),
-- rental cars for licence tests, mileage tracking and the return to the hub.
--
-- Transform convention used everywhere in the mod ("startPosition style"):
--   { pos = vec3 (front centre of the car), rot = quat (forward = +Y) }
-- exactly like gameplay/race/startPosition. Vehicles are spawned with the
-- same flip the game uses: vehRot = quatFromEuler(0,0,pi) * rot.

local M = {}

local function U() return extensions.turismo_util end
local function S() return extensions.turismo_save end
local function G() return extensions.turismo_garage end
local function COND() return extensions.turismo_condition end
local function P() return extensions.turismo_profile end

local pendingLevel = nil      -- {level, cb}
local levelReady = false
local levelSpawn = nil        -- {pos, dir} of the level's default spawn
local playerVehId = nil
local playerCarId = nil
local lastPlayerTransform = nil
local rentals = {}
local distance = { last = nil, acc = 0, offroadAcc = 0 }
local deferred = {}           -- {t, fn}

local function veh(id) return id and getObjectByID and getObjectByID(id) or nil end
local function toast(msg, kind) if extensions.hook then extensions.hook('onTurismoToast', msg, kind or 'info') end end

local function defer(seconds, fn) deferred[#deferred + 1] = { t = seconds, fn = fn } end
M.defer = defer

function M.currentLevel()
  return getCurrentLevelIdentifier and getCurrentLevelIdentifier() or nil
end

function M.playerVehId() return playerVehId end

function M.levelExists(level)
  if not level then return false end
  if core_levels and core_levels.getLevelByName then
    local ok, lvl = pcall(core_levels.getLevelByName, level)
    return ok and lvl ~= nil
  end
  return FS and FS:directoryExists('/levels/' .. level) or false
end
function M.playerCarId() return playerCarId end

---------------------------------------------------------------------------
-- levels
---------------------------------------------------------------------------
function M.loadLevel(level, cb)
  if not level then if cb then cb() end return end
  if M.currentLevel() == level and levelReady then
    defer(0.05, cb)
    return
  end
  -- leaving the level: store the car condition first
  if playerVehId and veh(playerVehId) then M.capturePlayerCar(function() end) end
  pendingLevel = { level = level, cb = cb }
  levelReady = false
  playerVehId = nil
  local target = extensions.turismo_tracks.levelPath(level)
  toast('Lade Strecke ...', 'loading')
  local ok, err = pcall(function()
    if freeroam_freeroam and freeroam_freeroam.startFreeroam then
      freeroam_freeroam.startFreeroam(target)
    elseif core_levels and core_levels.startLevel then
      core_levels.startLevel(type(target) == 'table' and target.misFilePath or target)
    end
  end)
  if not ok then
    U().log('E', 'session: level load failed: %s', tostring(err))
    pendingLevel = nil
    toast('Level konnte nicht geladen werden: ' .. tostring(level), 'error')
  end
end

function M.onClientStartMission()
  levelReady = false
  levelSpawn = nil
  playerVehId = nil
  rentals = {}
end

function M.onClientEndMission()
  levelReady = false
  playerVehId = nil
end

function M.onWorldReadyState(state)
  if state ~= 2 then return end
  levelReady = true
  -- remember the level's default spawn (vehicle that the level spawned for us)
  local v = getPlayerVehicle and getPlayerVehicle(0)
  if v then
    levelSpawn = { pos = v:getPosition(), dir = v:getDirectionVector() }
  end
  if pendingLevel then
    local cb = pendingLevel.cb
    pendingLevel = nil
    defer(0.5, cb)
  end
end

---------------------------------------------------------------------------
-- spawning
---------------------------------------------------------------------------
local function vehicleTransform(t)
  local fwd = t.rot * vec3(0, 1, 0)
  local pos = t.pos - fwd * 2.4 + vec3(0, 0, 0.4)
  local rot = quatFromEuler(0, 0, math.pi) * t.rot
  return pos, rot
end

local function currentTransform(v)
  local dir, up = v:getDirectionVector(), v:getDirectionVectorUp()
  return { pos = v:getPosition() + dir * 2.4, rot = quatFromDir(dir, up) }
end

local function removeVehicle(id)
  local v = veh(id)
  if v then v:delete() end
end

-- removes the level's default vehicle and old turismo vehicles
local function clearPlayerVehicles()
  if playerVehId then removeVehicle(playerVehId) playerVehId = nil end
  local v = getPlayerVehicle and getPlayerVehicle(0)
  if v then
    v:delete()
  end
end

local function spawnVehicle(model, config, transform, extraOpts)
  local pos, rot
  if transform and transform.startPosition then
    transform = { pos = transform.startPosition.pos, rot = transform.startPosition.rot }
  end
  if transform then
    pos, rot = vehicleTransform(transform)
  elseif levelSpawn then
    pos = levelSpawn.pos
    rot = quatFromEuler(0, 0, math.pi) * quatFromDir(levelSpawn.dir, vec3(0, 0, 1))
  end
  local opts = { config = 'vehicles/' .. model .. '/' .. (config or 'base') .. '.pc', autoEnterVehicle = true, pos = pos, rot = rot }
  for k, v in pairs(extraOpts or {}) do opts[k] = v end
  local ok, v = pcall(core_vehicles.spawnNewVehicle, model, opts)
  if not ok or not v then
    U().log('E', 'session: spawn failed for %s/%s: %s', tostring(model), tostring(config), tostring(v))
    return nil
  end
  return v
end

-- spawns a garage car (active car if carId nil) and applies its stored condition
function M.spawnPlayerCar(carId, transform, cb)
  local car = carId and G().get(carId) or G().active()
  if not car then
    toast('Du besitzt noch kein Fahrzeug. Besuche den Gebrauchtwagenhändler!', 'error')
    return
  end
  if not transform and playerVehId and veh(playerVehId) then
    transform = currentTransform(veh(playerVehId))
  end
  clearPlayerVehicles()
  local v = spawnVehicle(car.model, car.config, transform, { licenseText = car.plate })
  if not v then return end
  playerVehId = v:getID()
  playerCarId = car.id
  local mode = S().get().meta.damageMode or 'realistic'
  COND().apply(playerVehId, car, mode)
  distance.last = nil
  -- precise placement once the vehicle is loaded (keeps damage: repair = false)
  if transform and transform.startPosition then
    defer(0.6, function()
      if veh(playerVehId) then transform.startPosition:moveResetVehicleTo(playerVehId, false, false) end
    end)
  end
  if cb then defer(0.8, function() cb(playerVehId) end) end
  return playerVehId
end

-- respawn the same car at the same place (after repairs, conversions)
function M.respawnInPlace(cb)
  local v = veh(playerVehId)
  if not v or not playerCarId then if cb then cb() end return end
  local t = currentTransform(v)
  M.spawnPlayerCar(playerCarId, t, cb)
end

function M.onCarServiced(car, changedConfig)
  if car and car.id == playerCarId and veh(playerVehId) then
    -- partCondition can only be initialised once per spawn -> respawn
    M.respawnInPlace()
  end
end

function M.spawnRental(key, transform, cb)
  local model, config = U().splitCarKey(key)
  clearPlayerVehicles()
  local v = spawnVehicle(model, config, transform)
  if not v then return end
  local id = v:getID()
  rentals[id] = true
  playerVehId = id
  playerCarId = nil
  if transform and transform.startPosition then
    defer(0.6, function() if veh(id) then transform.startPosition:moveResetVehicleTo(id, false, true) end end)
  end
  if cb then defer(0.8, function() cb(id) end) end
  return id
end

function M.removeRental(id)
  if rentals[id] then
    removeVehicle(id)
    rentals[id] = nil
    if playerVehId == id then playerVehId = nil end
  end
end

-- reads the current part conditions of the player's garage car into the save
function M.capturePlayerCar(cb)
  local car = playerCarId and G().get(playerCarId)
  M.flushDistance()
  if not car or not veh(playerVehId) then if cb then cb(false) end return end
  if (S().get().meta.damageMode or 'realistic') == 'off' then
    if cb then cb(true) end
    return
  end
  COND().capture(playerVehId, car, function(ok, sum)
    if ok and sum and extensions.hook then extensions.hook('onTurismoCarCaptured', car, sum) end
    if cb then cb(ok, sum) end
  end)
end

function M.reloadPlayerCar(cb)
  local hardcore = S().get().meta.hardcore
  local function respawn()
    if playerVehId then removeVehicle(playerVehId) playerVehId = nil end
    if cb then defer(0.2, cb) end
  end
  if hardcore then M.capturePlayerCar(respawn) else respawn() end
end

---------------------------------------------------------------------------
-- venues (licence test areas)
---------------------------------------------------------------------------
local function anchorFrom(pos, dir)
  local d = vec3(dir.x, dir.y, 0)
  if d:length() < 0.01 then d = vec3(0, 1, 0) end
  d:normalize()
  return { pos = { x = pos.x, y = pos.y, z = pos.z }, fwd = { x = d.x, y = d.y }, right = { x = d.y, y = -d.x } }
end

function M.venueAnchor(venue)
  local saved = S().get().venues and S().get().venues[venue.id]
  if saved then return saved end
  if type(venue.anchor) == 'table' and venue.anchor.pos then
    local p, d = venue.anchor.pos, venue.anchor.dir or { 0, 1, 0 }
    return anchorFrom({ x = p[1], y = p[2], z = p[3] }, { x = d[1], y = d[2] })
  end
  if levelSpawn then
    local a = anchorFrom(levelSpawn.pos, levelSpawn.dir)
    if venue.offset then -- shift the anchor (metres right/forward)
      a.pos.x = a.pos.x + a.right.x * (venue.offset[1] or 0) + a.fwd.x * (venue.offset[2] or 0)
      a.pos.y = a.pos.y + a.right.y * (venue.offset[1] or 0) + a.fwd.y * (venue.offset[2] or 0)
    end
    return a
  end
  local v = getPlayerVehicle and getPlayerVehicle(0)
  if v then return anchorFrom(v:getPosition(), v:getDirectionVector()) end
  return nil
end

-- "Testgelände hier festlegen": current car position becomes the anchor
function M.setVenueAnchorHere(venueId)
  local v = getPlayerVehicle and getPlayerVehicle(0)
  if not v then return false end
  local st = S().get()
  st.venues = st.venues or {}
  st.venues[venueId] = anchorFrom(v:getPosition(), v:getDirectionVector())
  S().markDirty()
  return true
end

---------------------------------------------------------------------------
-- free roam ("Freie Fahrt") and hub
---------------------------------------------------------------------------
function M.freeDrive(level, carId)
  local target = level or M.currentLevel() or (S().get().settings and S().get().settings.homeLevel) or 'west_coast_usa'
  M.loadLevel(target, function()
    M.spawnPlayerCar(carId, nil, function()
      if extensions.turismo_core then extensions.turismo_core.setHubVisible(false) end
      toast('Freie Fahrt: Kilometer zählen für die Tagesetappe. Menü mit der Turismo-Taste.', 'info')
    end)
  end)
end

function M.returnToHub()
  M.capturePlayerCar(function()
    S().save()
    if extensions.turismo_core then extensions.turismo_core.setHubVisible(true) end
  end)
end

---------------------------------------------------------------------------
-- mileage
---------------------------------------------------------------------------
function M.flushDistance()
  if distance.acc > 0 then
    local car = playerCarId and G().get(playerCarId)
    if car then G().addDistance(car, distance.acc, distance.acc > 0 and distance.offroadAcc / distance.acc or 0) end
    P().addDistance(distance.acc)
    distance.acc, distance.offroadAcc = 0, 0
  end
end

local flushTimer = 0
function M.update(dtReal, dtSim)
  for i = #deferred, 1, -1 do
    local d = deferred[i]
    d.t = d.t - dtReal
    if d.t <= 0 then
      table.remove(deferred, i)
      local ok, err = pcall(d.fn)
      if not ok then U().log('E', 'session: deferred call failed: %s', tostring(err)) end
    end
  end
  if not S().isLoaded() then return end
  local v = veh(playerVehId)
  if v and (dtSim or 0) > 0 then
    local pos = v:getPosition()
    if distance.last then
      local d = pos:distance(distance.last)
      if d < 30 then -- ignore teleports/resets
        distance.acc = distance.acc + d
        -- offroad guess (2x per second): no navgraph road nearby
        distance.roadTimer = (distance.roadTimer or 0) + dtReal
        if distance.roadTimer > 0.5 and map and map.findClosestRoad then
          distance.roadTimer = 0
          local okR, _, _, dist = pcall(map.findClosestRoad, pos)
          distance.offroad = okR and dist and dist > 12 or false
        end
        if distance.offroad then distance.offroadAcc = distance.offroadAcc + d end
      end
    end
    distance.last = pos
  end
  flushTimer = flushTimer + dtReal
  if flushTimer > 10 then
    flushTimer = 0
    M.flushDistance()
  end
end

function M.onVehicleDestroyed(id)
  if id == playerVehId then playerVehId = nil end
  rentals[id] = nil
end

return M
