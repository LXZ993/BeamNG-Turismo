-- Turismo Karriere - services ("Werkstatt & Pflege")
-- Car wash, oil change, quick/full repair, engine overhaul, paint refresh,
-- and "Umbau" (conversion to another factory configuration of the same model,
-- the BeamNG equivalent of buying tuning parts).

local M = {}

local function U() return extensions.turismo_util end
local function S() return extensions.turismo_save end
local function G() return extensions.turismo_garage end
local function P() return extensions.turismo_profile end
local function COND() return extensions.turismo_condition end
local function VDB() return extensions.turismo_vehicleDb end

local function sizeFactor(car)
  local info = VDB().get(car.key)
  local kg = info and info.weight_kg or 1400
  return U().clamp(kg / 1400, 0.6, 3)
end

-- pure-ish: price list for one car
function M.quotes(car)
  local sum = G().updateSummary(car)
  local price = car.newPrice or 20000
  local q = {
    wash = { price = math.floor(50 * sizeFactor(car) / 10 + 0.5) * 10, available = (car.cleanliness or 100) < 100,
             label = 'Autowäsche', desc = 'Gründliche Handwäsche. Ein sauberes Auto erzielt beim Verkauf einen besseren Preis.' },
    oil = { price = math.floor((40 + price * 0.002) / 10 + 0.5) * 10, available = (car.oilKm or 0) > 300,
            label = 'Ölwechsel', desc = 'Frisches Öl senkt die Motorreibung. Altes Öl kostet spürbar Leistung.' },
    quickRepair = { price = COND().repairQuote(sum, price, 'quick'), available = sum.brokenParts > 0,
                    label = 'Schnellreparatur', desc = 'Tauscht defekte Teile aus. Verformungen an der Karosserie bleiben.' },
    fullRepair = { price = COND().repairQuote(sum, price, 'full'), available = sum.brokenParts > 0 or sum.damagedParts > 0,
                   label = 'Komplettreparatur', desc = 'Richtbank, Teiletausch und Vermessung: das Auto wird wieder wie neu.' },
    engine = { price = COND().repairQuote(sum, price, 'engine'), available = sum.engineKm > 5000,
               label = 'Motorüberholung', desc = 'Kompletter Motor-Neuaufbau. Setzt den Motorverschleiß zurück.' },
    paint = { price = COND().repairQuote(sum, price, 'paint'), available = sum.minVisual < 0.98,
              label = 'Lackaufbereitung', desc = 'Politur und Lackausbesserung für einen Neuwagen-Glanz.' },
  }
  return q, sum
end

local function charge(car, q, reason)
  if not q.available then return false, 'Diese Leistung ist für dieses Fahrzeug gerade nicht nötig.' end
  if not P().spend(q.price, reason .. ': ' .. car.name, 'service') then
    return false, 'Nicht genug Credits.'
  end
  return true
end

function M.perform(carId, service)
  local car = G().get(carId)
  if not car then return false, 'Fahrzeug nicht gefunden' end
  local q = M.quotes(car)
  local item = q[service]
  if not item then return false, 'Unbekannte Leistung' end
  local ok, err = charge(car, item, item.label)
  if not ok then return false, err end

  if service == 'wash' then
    car.cleanliness = 100
  elseif service == 'oil' then
    car.oilKm = 0
  elseif service == 'quickRepair' then
    car.partConditions = COND().repaired(car.partConditions, 'quick')
  elseif service == 'fullRepair' then
    car.partConditions = COND().repaired(car.partConditions, 'full')
  elseif service == 'engine' then
    car.partConditions = COND().repaired(car.partConditions, 'engine')
    car.engineKm = 0
  elseif service == 'paint' then
    car.partConditions = COND().repaired(car.partConditions, 'paint')
  end
  G().updateSummary(car)
  S().markDirty()
  if extensions.hook then extensions.hook('onTurismoServiceDone', car, service) end
  -- if the car is currently spawned, re-apply its new state
  if extensions.turismo_session then extensions.turismo_session.onCarServiced(car) end
  return true, item.price
end

---------------------------------------------------------------------------
-- "Umbau": factory configurations of the same model, as upgrade stages
---------------------------------------------------------------------------
function M.conversions(car)
  local res = {}
  local current = VDB().get(car.key)
  for _, info in ipairs(VDB().all()) do
    if info.model == car.model and info.key ~= car.key then
      local diff = info.price - (current and current.price or car.newPrice or 0)
      local cost = math.max(800, math.floor((diff * 0.7 + 1500) / 50 + 0.5) * 50)
      res[#res + 1] = {
        key = info.key, name = info.name, configName = info.configName,
        rating = info.rating, price = cost,
        liDelta = info.rating.li - car.rating.li,
      }
    end
  end
  table.sort(res, function(a, b) return a.rating.li < b.rating.li end)
  return res
end

function M.convert(carId, targetKey)
  local car = G().get(carId)
  if not car then return false, 'Fahrzeug nicht gefunden' end
  local offer
  for _, c in ipairs(M.conversions(car)) do if c.key == targetKey then offer = c break end end
  if not offer then return false, 'Umbau nicht möglich' end
  if not P().spend(offer.price, 'Umbau: ' .. car.name .. ' -> ' .. offer.configName, 'tuning') then
    return false, 'Nicht genug Credits.'
  end
  local info = VDB().get(targetKey)
  car.key, car.config = info.key, info.config
  car.name = info.name
  car.rating = U().deepcopy(info.rating)
  car.newPrice = info.price
  -- parts that no longer exist are dropped by partCondition (fresh fallback);
  -- broken parts carry over where the part path is identical.
  G().updateSummary(car)
  S().markDirty()
  if extensions.turismo_session then extensions.turismo_session.onCarServiced(car, true) end
  return true, offer.price
end

return M
