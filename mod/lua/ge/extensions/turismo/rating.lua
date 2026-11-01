-- Turismo Karriere - rating
-- "Leistungsindex" (LI, 100..1000): a single performance number per car,
-- plus performance class (E..X), category (Straße, Sport, Rennwagen, ...) and era.
-- Pure Lua: input is a normalized vehicle info table (see turismo_vehicleDb.normalize).

local M = {}

local function U() return extensions.turismo_util end

M.classes = {
  { id = 'E', min = 0,   max = 299,  name = 'Klasse E', color = '#8a9bb0' },
  { id = 'D', min = 300, max = 399,  name = 'Klasse D', color = '#6fbf73' },
  { id = 'C', min = 400, max = 499,  name = 'Klasse C', color = '#4fa3e0' },
  { id = 'B', min = 500, max = 599,  name = 'Klasse B', color = '#b07de8' },
  { id = 'A', min = 600, max = 699,  name = 'Klasse A', color = '#e8a33d' },
  { id = 'S', min = 700, max = 799,  name = 'Klasse S', color = '#e85d3d' },
  { id = 'X', min = 800, max = 1000, name = 'Klasse X', color = '#e0e0e0' },
}

M.categories = {
  street  = 'Straßenwagen',
  sport   = 'Sportwagen',
  touring = 'Tourenwagen (Renn-Umbau)',
  gt      = 'GT-Rennwagen',
  proto   = 'Prototyp / Formel',
  rally   = 'Rallye',
  offroad = 'Gelände',
  drift   = 'Drift',
  truck   = 'Nutzfahrzeug',
  classic = 'Klassiker',
}

-- tyre grip guess by category (BeamNG has no explicit tyre tier in the info file)
M.tyreFactor = {
  street = 1.00, classic = 0.97, truck = 0.92, offroad = 0.95,
  sport = 1.04, drift = 1.02, rally = 1.03, touring = 1.10, gt = 1.15, proto = 1.22,
}

local RACE_WORDS  = { 'race', 'racing', 'track', 'gt3', 'gtr', 'gt-r', 'cup', 'time attack', 'club', 'hillclimb', 'circuit' }
local PROTO_WORDS = { 'proto', 'formula', 'lmp', 'open wheel', 'single seater' }
local RALLY_WORDS = { 'rally', 'rallye', 'gravel', 'tarmac rally', 'group b', 'stage' }
local DRIFT_WORDS = { 'drift' }
local OFFROAD_WORDS = { 'offroad', 'off-road', 'crawler', 'baja', 'trophy', 'prerunner', 'lifted', 'desert' }
local SPORT_BODY = { 'coupe', 'roadster', 'convertible', 'cabrio', 'sports', 'supercar', 'hypercar' }
local TRUCK_BODY = { 'truck', 'van', 'bus', 'pickup', 'semi', 'box', 'utility' }

local function anyWord(text, words)
  local u = U()
  for _, w in ipairs(words) do
    if u.icontains(text, w) then return true end
  end
  return false
end

function M.classify(info)
  local text = table.concat({ info.configName or '', info.configType or '', info.name or '' }, ' ')
  local body = info.bodyStyle or ''
  if anyWord(text, PROTO_WORDS) or anyWord(body, PROTO_WORDS) then return 'proto' end
  if anyWord(text, RALLY_WORDS) then return 'rally' end
  if anyWord(text, DRIFT_WORDS) then return 'drift' end
  if anyWord(text, OFFROAD_WORDS) or (info.offroadScore or 0) >= 60 then return 'offroad' end
  if anyWord(text, RACE_WORDS) then
    if (info.power_hp or 0) >= 450 then return 'gt' end
    return 'touring'
  end
  if info.type and U().icontains(info.type, 'truck') then return 'truck' end
  if anyWord(body, TRUCK_BODY) then return 'truck' end
  local year = info.yearMin or 2000
  if year < 1975 then return 'classic' end
  local pw = (info.power_hp or 0) / math.max(0.4, (info.weight_kg or 1400) / 1000)
  if anyWord(body, SPORT_BODY) or pw >= 180 then return 'sport' end
  return 'street'
end

function M.eraOf(info)
  local y = info.yearMin
  if not y then return 'unknown', 'Unbekannt' end
  if y < 1970 then return 'sixties', 'Vor 1970' end
  if y < 1980 then return 'seventies', '70er' end
  if y < 1990 then return 'eighties', '80er' end
  if y < 2000 then return 'nineties', '90er' end
  if y < 2010 then return 'noughties', '2000er' end
  return 'modern', 'Modern'
end

-- Core formula. Calibrated so that:
--   ~ 75 PS / 1000 kg economy car   -> ~ 300
--   ~ 300 PS / 1350 kg sports car   -> ~ 520
--   ~ 550 PS / 1250 kg GT racer     -> ~ 720 (with race tyres/aero)
--   ~ 800 PS / 700 kg prototype     -> ~ 950
function M.computeLI(info, categoryOverride)
  local u = U()
  local category = categoryOverride or info.category or M.classify(info)
  local hp = math.max(10, info.power_hp or 100)
  local kg = math.max(300, info.weight_kg or 1400)
  local pw = hp / (kg / 1000) -- PS per tonne

  local base = 100 + 235 * math.log(1 + pw / 60)

  -- acceleration data, when available, keeps the number honest for odd cars
  if info.accel0100 and info.accel0100 > 1.5 and info.accel0100 < 40 then
    local accelScore = u.remap(info.accel0100, 16, 2.4, 220, 760)
    base = base * 0.7 + accelScore * 0.3
  end

  -- drivetrain: AWD helps traction with lots of power, FWD hurts with lots of power
  local dt = u.lower(info.drivetrain)
  if dt == 'awd' or dt == '4wd' then
    base = base + u.remap(pw, 100, 400, 4, 22)
  elseif dt == 'fwd' then
    base = base - u.remap(pw, 120, 300, 0, 18)
  end

  base = base * (M.tyreFactor[category] or 1)

  -- aero downforce guess for race categories
  if category == 'gt' then base = base + 35 elseif category == 'proto' then base = base + 70 end

  -- top speed (km/h) small bonus/penalty
  if info.topSpeed_kmh and info.topSpeed_kmh > 50 then
    base = base + u.remap(info.topSpeed_kmh, 140, 340, -10, 25)
  end

  -- heavy, tall vehicles corner worse
  if category == 'truck' then base = base - 40 end
  if category == 'offroad' then base = base - 15 end

  return math.floor(u.clamp(base, 100, 1000) + 0.5)
end

function M.classOf(li)
  for _, c in ipairs(M.classes) do
    if li >= c.min and li <= c.max then return c end
  end
  return M.classes[#M.classes]
end

-- full rating record stored with each car
function M.rate(info)
  local category = M.classify(info)
  local li = M.computeLI(info, category)
  local cls = M.classOf(li)
  local era, eraName = M.eraOf(info)
  return {
    li = li,
    class = cls.id,
    className = cls.name,
    category = category,
    categoryName = M.categories[category] or category,
    era = era,
    eraName = eraName,
  }
end

-- Applies wear/condition to the nominal LI (worn engine, broken parts, old oil).
-- condition: { engineWear = 0..1, damage = 0..1, oilAge = 0..1 }
function M.effectiveLI(li, condition)
  if not condition then return li end
  local u = U()
  local penalty = 0
  penalty = penalty + (condition.engineWear or 0) * 25
  penalty = penalty + (condition.oilAge or 0) * 8
  penalty = penalty + (condition.damage or 0) * 60
  return math.floor(u.clamp(li - penalty, 100, 1000) + 0.5)
end

return M
