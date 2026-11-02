-- Turismo Karriere - condition
-- Persistent vehicle damage & wear between sessions, using BeamNG's own
-- partCondition system (the same one the official career uses):
--   capture: core_vehicleBridge.requestValue(veh, cb, 'getPartConditions')
--   apply:   core_vehicleBridge.executeAction(veh, 'initPartConditions', conds, odo, 1, 1)
-- partCondition also creates a "reset" snapshot on init, so pressing the
-- vehicle reset key restores the damaged state from session start instead of
-- repairing the car for free.
--
-- The pure functions (summarize / repair*) work on the conditions table:
--   [partId] = { odometer = m, integrityValue = 0..1, visualValue = 0..1,
--                integrityState = {...}|nil, visualState = {...}|nil }

local M = {}

local function U() return extensions.turismo_util end

M.OIL_INTERVAL_KM = 6000
M.ENGINE_WEAR_START_KM = 30000   -- matches combustionEngine wear curve start (30 000 km)
M.ENGINE_WEAR_FULL_KM = 300000

local function isEnginePart(partId)
  local u = U()
  local p = u.lower(partId)
  if p:find('mount', 1, true) or p:find('cover', 1, true) or p:find('intake', 1, true) then return false end
  return p:find('engine', 1, true) ~= nil
end
M.isEnginePart = isEnginePart

-- pure: condition overview for UI, pricing and LI penalties
function M.summarize(pc, car)
  local s = {
    parts = 0, brokenParts = 0, damagedParts = 0,
    avgIntegrity = 1, minVisual = 1, odometerKm = 0, engineKm = 0,
    damage = 0, engineWear = 0, oilAge = 0, brokenList = {},
  }
  if type(pc) ~= 'table' then
    if car then
      s.odometerKm = (car.mileageKm or 0)
      s.engineKm = (car.engineKm or car.mileageKm or 0)
    end
  else
    local sumI = 0
    for partId, c in pairs(pc) do
      if type(c) == 'table' then
        s.parts = s.parts + 1
        local iv = tonumber(c.integrityValue) or 1
        sumI = sumI + iv
        if iv <= 0 then
          s.brokenParts = s.brokenParts + 1
          if #s.brokenList < 12 then s.brokenList[#s.brokenList + 1] = partId end
        elseif iv < 0.999 or c.integrityState ~= nil then
          s.damagedParts = s.damagedParts + 1
        end
        local vv = tonumber(c.visualValue) or 1
        if vv < s.minVisual then s.minVisual = vv end
        local odo = (tonumber(c.odometer) or 0) / 1000
        if odo > s.odometerKm then s.odometerKm = odo end
        if isEnginePart(partId) and odo > s.engineKm then s.engineKm = odo end
      end
    end
    if s.parts > 0 then s.avgIntegrity = sumI / s.parts end
    if s.engineKm == 0 then s.engineKm = s.odometerKm end
  end
  -- damage 0..1: broken parts weigh heavily, deformed parts a little
  s.damage = U().clamp(s.brokenParts * 0.08 + s.damagedParts * 0.015 + (1 - s.avgIntegrity) * 2, 0, 1)
  s.engineWear = U().remap(s.engineKm, M.ENGINE_WEAR_START_KM, M.ENGINE_WEAR_FULL_KM, 0, 1)
  local oilKm = car and (car.oilKm or 0) or 0
  s.oilAge = U().remap(oilKm, M.OIL_INTERVAL_KM * 0.5, M.OIL_INTERVAL_KM * 1.5, 0, 1)
  return s
end

-- pure: price estimate of a repair, based on the car's new price
function M.repairQuote(summary, carPrice, kind)
  carPrice = math.max(5000, carPrice or 20000)
  local per = 120 + carPrice * 0.012
  local cost = 0
  if kind == 'quick' then
    cost = summary.brokenParts * per
  elseif kind == 'full' then
    cost = summary.brokenParts * per + summary.damagedParts * per * 0.25 + (1 - summary.avgIntegrity) * carPrice * 0.3
  elseif kind == 'engine' then
    cost = 800 + carPrice * 0.08 * U().clamp(summary.engineKm / 100000, 0.3, 1.5)
  elseif kind == 'paint' then
    cost = 400 + carPrice * 0.04
  end
  return math.floor(cost / 10 + 0.5) * 10
end

-- pure: returns a repaired copy of the conditions table
-- kind: 'quick' (broken parts only), 'full' (all integrity incl. deformation),
--       'engine' (engine odometer reset), 'paint' (visual reset)
function M.repaired(pc, kind)
  if type(pc) ~= 'table' then return pc end
  local out = U().deepcopy(pc)
  for partId, c in pairs(out) do
    if type(c) == 'table' then
      if kind == 'quick' then
        if (tonumber(c.integrityValue) or 1) <= 0 then
          c.integrityValue = 1
          c.integrityState = nil
        end
      elseif kind == 'full' then
        c.integrityValue = 1
        c.integrityState = nil
      elseif kind == 'engine' then
        if isEnginePart(partId) then
          c.odometer = 0
          c.integrityValue = 1
          c.integrityState = nil
        end
      elseif kind == 'paint' then
        c.visualValue = 1
        if type(c.visualState) == 'table' and type(c.visualState.paint) == 'table' and c.visualState.paint.originalPaints then
          c.visualState = { paint = { originalPaints = c.visualState.paint.originalPaints } }
        else
          c.visualState = nil
        end
      end
    end
  end
  return out
end

---------------------------------------------------------------------------
-- game bridge
---------------------------------------------------------------------------
local function bridge() return core_vehicleBridge end

-- capture current conditions of a spawned vehicle into the garage car
function M.capture(vehId, car, callback)
  local veh = getObjectByID and getObjectByID(vehId)
  if not veh or not bridge() then
    if callback then callback(false) end
    return
  end
  local ok, err = pcall(bridge().requestValue, veh, function(res)
    local conds = res and res.result
    if type(conds) == 'table' and next(conds) then
      car.partConditions = conds
      local sum = M.summarize(conds, car)
      car.mileageKm = math.max(car.mileageKm or 0, sum.odometerKm)
      car.summary = sum
      if extensions.turismo_save then extensions.turismo_save.markDirty() end
      if callback then callback(true, sum) end
    else
      U().log('W', 'condition: vehicle %s returned no part conditions', tostring(vehId))
      if callback then callback(false) end
    end
  end, 'getPartConditions')
  if not ok then
    U().log('E', 'condition: capture failed: %s', tostring(err))
    if callback then callback(false) end
  end
end

-- apply stored conditions right after spawning (before driving)
function M.apply(vehId, car, damageMode)
  local veh = getObjectByID and getObjectByID(vehId)
  if not veh or not bridge() then return false end
  local conds = car.partConditions
  if damageMode == 'off' then conds = nil end
  if damageMode == 'mechanical' and conds then
    -- keep wear/broken mechanicals but drop body deformation & paint damage
    conds = U().deepcopy(conds)
    for _, c in pairs(conds) do
      if type(c) == 'table' and type(c.integrityState) == 'table' then c.integrityState.jbeam = nil end
      if type(c) == 'table' then c.visualState = nil c.visualValue = 1 end
    end
  end
  local odoMeters = (car.mileageKm or 0) * 1000
  -- engine overhauled before the first capture: the fallback odometer drives the
  -- physics wear model, so use the engine's own kilometres
  if not conds and car.engineKm then odoMeters = math.min(odoMeters, car.engineKm * 1000) end
  if damageMode == 'off' then odoMeters = 0 end
  -- first spawn of a used car: no captured conditions yet -> worn fallback values
  local fbI, fbV = 1, 1
  if not conds and car.usedFallback and damageMode ~= 'off' then
    fbI = car.usedFallback.integrity or 1
    fbV = car.usedFallback.visual or 1
  end
  local ok, err = pcall(bridge().executeAction, veh, 'initPartConditions', conds or {}, odoMeters, fbI, fbV)
  if not ok then
    U().log('E', 'condition: apply failed: %s', tostring(err))
    return false
  end
  M.applyOilEffect(veh, car)
  return true
end

-- old oil -> slightly higher engine friction (via vehicle Lua, guarded)
function M.applyOilEffect(veh, car)
  local s = M.summarize(car.partConditions, car)
  if s.oilAge <= 0 then return end
  local mult = 1 + s.oilAge * 0.12
  local cmd = string.format([[
    local e = powertrain and powertrain.getDevice and powertrain.getDevice('mainEngine')
    if e and e.wearFrictionCoef then e.wearFrictionCoef = e.wearFrictionCoef * %f end
  ]], mult)
  pcall(function() veh:queueLuaCommand(cmd) end)
end

return M
