-- Turismo Karriere - garage
-- Owned cars. A car keeps its own mileage, part conditions (damage/wear),
-- oil age, cleanliness, race history and purchase data.

local M = {}

local function U() return extensions.turismo_util end
local function S() return extensions.turismo_save end
local function VDB() return extensions.turismo_vehicleDb end
local function COND() return extensions.turismo_condition end
local function P() return extensions.turismo_profile end

M.MAX_CARS = 300

M.defaults = {
  cars = {},          -- id -> car
  counter = 0,
  activeCarId = nil,
}

local function g() return S().get().garage end

function M.cars() return g().cars end

function M.get(id) return id and g().cars[id] or nil end

function M.active() return M.get(g().activeCarId) end

function M.setActive(id)
  if not g().cars[id] then return false end
  g().activeCarId = id
  S().markDirty()
  return true
end

function M.count() return U().count(g().cars) end

-- creates a car entry from a vehicle key ("model/config")
-- opts: source, price (paid), mileageKm, partConditions, condition overrides, oilKm, cleanliness
function M.addCar(key, opts)
  opts = opts or {}
  if M.count() >= M.MAX_CARS then return nil, 'Garage voll' end
  local info = VDB().get(key)
  if not info then return nil, 'Unbekanntes Fahrzeug: ' .. tostring(key) end
  local gs = g()
  gs.counter = gs.counter + 1
  local id = U().makeId('car', gs.counter)
  local car = {
    id = id,
    key = info.key,
    model = info.model,
    config = info.config,
    name = info.name,
    brand = info.brand,
    region = info.region,
    rating = U().deepcopy(info.rating),
    newPrice = info.price,
    paid = opts.price or 0,
    source = opts.source or 'Händler',
    acquiredDay = P().day(),
    mileageKm = opts.mileageKm or 0,
    engineKm = opts.engineKm,
    oilKm = opts.oilKm or 0,
    cleanliness = opts.cleanliness or 100,
    partConditions = opts.partConditions,
    races = 0, wins = 0,
    history = {},
    nickname = nil,
    favorite = false,
  }
  car.summary = COND().summarize(car.partConditions, car)
  gs.cars[id] = car
  if not gs.activeCarId then gs.activeCarId = id end
  P().addCollectorPoints(math.max(opts.price or 0, info.price * 0.5))
  S().markDirty()
  if extensions.hook then extensions.hook('onTurismoCarAdded', car) end
  return car
end

function M.removeCar(id)
  local gs = g()
  if not gs.cars[id] then return false end
  gs.cars[id] = nil
  if gs.activeCarId == id then gs.activeCarId = next(gs.cars) end
  S().markDirty()
  return true
end

-- pure: market value of an owned car
function M.valueOf(car)
  local sum = car.summary or COND().summarize(car.partConditions, car)
  local base = car.newPrice or 10000
  local mileageFactor = U().remap(sum.odometerKm, 0, 250000, 1.0, 0.35)
  local damageFactor = 1 - sum.damage * 0.5
  local cleanFactor = 0.95 + (car.cleanliness or 100) / 100 * 0.05
  local winBonus = 1 + math.min(car.wins or 0, 20) * 0.005 -- small "race history" bonus
  return math.floor(base * 0.72 * mileageFactor * damageFactor * cleanFactor * winBonus / 50 + 0.5) * 50
end

function M.sellCar(id)
  local car = M.get(id)
  if not car then return nil, 'Fahrzeug nicht gefunden' end
  if M.count() <= 1 then return nil, 'Du kannst dein letztes Fahrzeug nicht verkaufen.' end
  local value = M.valueOf(car)
  M.removeCar(id)
  P().earn(value, 'Verkauf: ' .. car.name, 'car')
  return value
end

-- current LI including wear and damage
function M.effectiveLI(car)
  local sum = car.summary or COND().summarize(car.partConditions, car)
  return extensions.turismo_rating.effectiveLI(car.rating.li, sum)
end

function M.updateSummary(car)
  car.summary = COND().summarize(car.partConditions, car)
  return car.summary
end

-- distance driven in a session (meters) -> mileage, oil, cleanliness
function M.addDistance(car, meters, offroadFraction)
  if not car or meters <= 0 then return end
  local km = meters / 1000
  car.mileageKm = (car.mileageKm or 0) + km
  car.oilKm = (car.oilKm or 0) + km
  local dirt = km * (0.15 + (offroadFraction or 0) * 2.5)
  car.cleanliness = U().clamp((car.cleanliness or 100) - dirt, 0, 100)
  S().markDirty()
end

function M.recordRace(car, entry)
  car.races = (car.races or 0) + 1
  if entry.position == 1 then car.wins = (car.wins or 0) + 1 end
  table.insert(car.history, 1, entry)
  while #car.history > 30 do table.remove(car.history) end
  S().markDirty()
end

-- UI snapshot (light, no partConditions)
function M.snapshot(car)
  if not car then return nil end
  local sum = car.summary or COND().summarize(car.partConditions, car)
  return {
    id = car.id, key = car.key, name = car.nickname or car.name, realName = car.name,
    brand = car.brand, region = car.region, rating = car.rating,
    effectiveLI = M.effectiveLI(car),
    mileageKm = math.floor(car.mileageKm or 0),
    oilKm = math.floor(car.oilKm or 0),
    cleanliness = math.floor(car.cleanliness or 100),
    damage = sum.damage, brokenParts = sum.brokenParts, damagedParts = sum.damagedParts,
    engineWear = sum.engineWear, oilAge = sum.oilAge,
    value = M.valueOf(car), races = car.races or 0, wins = car.wins or 0,
    favorite = car.favorite, source = car.source,
    active = (g().activeCarId == car.id),
    preview = VDB().get(car.key) and VDB().get(car.key).preview or nil,
  }
end

function M.list()
  local res = {}
  for _, car in pairs(g().cars) do res[#res + 1] = M.snapshot(car) end
  table.sort(res, function(a, b)
    if a.favorite ~= b.favorite then return a.favorite end
    if a.brand == b.brand then return a.name < b.name end
    return a.brand < b.brand
  end)
  return res
end

function M.onExtensionLoaded()
  S().registerDefaults('garage', M.defaults)
end

return M
