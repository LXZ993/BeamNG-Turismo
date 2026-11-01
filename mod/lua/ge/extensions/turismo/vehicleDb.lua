-- Turismo Karriere - vehicleDb
-- Reads every installed vehicle configuration (vanilla + mods) from core_vehicles,
-- normalizes the info fields and rates each config. Everything else in the mod
-- refers to cars by "model/config" keys or by criteria tables, so modded cars
-- automatically show up in dealers, events and café books.

local M = {}

local function U() return extensions.turismo_util end
local function R() return extensions.turismo_rating end

local cache = nil         -- key -> entry
local cacheList = nil     -- array of entries, sorted by brand/name

-- Vehicle types that can be raced / owned
local ALLOWED_TYPES = { car = true, truck = true }

-- Brand -> origin region used for dealership halls when the config has no "Country"
M.brandRegion = {
  ['Ibishu'] = 'japan', ['Hirochi'] = 'japan', ['Wentward'] = 'europe',
  ['ETK'] = 'europe', ['Civetta'] = 'europe', ['Autobello'] = 'europe', ['Cherrier'] = 'europe',
  ['Soliad'] = 'europe', ['SBR'] = 'japan',
  ['Gavril'] = 'america', ['Bruckell'] = 'america', ['Burnside'] = 'america', ['Dinsmore'] = 'america',
}

M.countryRegion = {
  ['japan'] = 'japan', ['germany'] = 'europe', ['italy'] = 'europe', ['france'] = 'europe',
  ['united kingdom'] = 'europe', ['uk'] = 'europe', ['poland'] = 'europe', ['sweden'] = 'europe',
  ['czech republic'] = 'europe', ['spain'] = 'europe', ['austria'] = 'europe', ['netherlands'] = 'europe',
  ['united states'] = 'america', ['usa'] = 'america', ['canada'] = 'america', ['mexico'] = 'america',
  ['south korea'] = 'asia', ['china'] = 'asia', ['australia'] = 'oceania', ['brazil'] = 'america',
}

M.regionNames = {
  japan = 'Japan', europe = 'Europa', america = 'Amerika', asia = 'Asien', oceania = 'Ozeanien', other = 'Sonstige',
}

-- reads a field directly or from the aggregates table (BeamNG stores filter data there)
local function field(cfg, name)
  local v = cfg[name]
  if v ~= nil and v ~= '' then return v end
  local agg = cfg.aggregates and cfg.aggregates[name]
  if type(agg) == 'table' then
    if agg.min ~= nil then return agg.min end
    for k in pairs(agg) do return k end
  end
  return nil
end

local function num(v)
  if type(v) == 'number' then return v end
  if type(v) == 'string' then return tonumber((v:gsub('[^%d%.%-]', ''))) end
  if type(v) == 'table' then return tonumber(v.min or v[1]) end
  return nil
end

-- pure: converts a BeamNG config table into our normalized info
function M.normalize(cfg, model)
  local u = U()
  local years = cfg.Years or (model and model.Years)
  local yearMin, yearMax
  if type(years) == 'table' then
    yearMin, yearMax = num(years.min), num(years.max)
  else
    yearMin = num(years)
  end
  if not yearMin then
    yearMin = num(field(cfg, 'Years'))
  end

  local power = num(field(cfg, 'Power'))
  if power and power > 3000 then power = power / 735.5 end -- defensive: Watts -> PS
  local topSpeed = num(field(cfg, 'Top Speed'))
  if topSpeed and topSpeed < 150 then topSpeed = topSpeed * 3.6 end -- m/s -> km/h

  local brand = field(cfg, 'Brand') or (model and model.Brand) or 'Unbekannt'
  local country = field(cfg, 'Country') or (model and model.Country)
  local region = 'other'
  if country and M.countryRegion[u.lower(country)] then
    region = M.countryRegion[u.lower(country)]
  elseif M.brandRegion[brand] then
    region = M.brandRegion[brand]
  end

  local modelKey = cfg.model_key or (model and model.key) or '?'
  local configKey = cfg.key or 'base'
  local info = {
    key = modelKey .. '/' .. configKey,
    model = modelKey,
    config = configKey,
    configPath = 'vehicles/' .. modelKey .. '/' .. configKey .. '.pc',
    name = cfg.Name or (modelKey .. ' ' .. configKey),
    modelName = model and model.Name or nil,
    configName = cfg.Configuration or configKey,
    brand = brand,
    country = country,
    region = region,
    type = field(cfg, 'Type') or 'Car',
    configType = field(cfg, 'Config Type'),
    bodyStyle = field(cfg, 'Body Style'),
    drivetrain = field(cfg, 'Drivetrain'),
    transmission = field(cfg, 'Transmission'),
    fuelType = field(cfg, 'Fuel Type'),
    induction = field(cfg, 'Induction Type'),
    performanceClass = field(cfg, 'Performance Class'),
    power_hp = power,
    torque_nm = num(field(cfg, 'Torque')),
    weight_kg = num(field(cfg, 'Weight')),
    topSpeed_kmh = topSpeed,
    accel0100 = num(field(cfg, '0-100 km/h')),
    offroadScore = num(field(cfg, 'Off-Road Score')),
    value = num(field(cfg, 'Value')),
    yearMin = yearMin,
    yearMax = yearMax,
    preview = cfg.preview,
    source = field(cfg, 'Source'),
  }
  info.rating = R().rate(info)
  info.price = M.newPrice(info)
  return info
end

-- new car price: BeamNG value if present, else estimated from LI
function M.newPrice(info)
  if info.value and info.value > 500 then
    return math.floor(info.value / 100 + 0.5) * 100
  end
  local li = info.rating and info.rating.li or 300
  local est = 4000 + (li - 200) ^ 2.1 * 0.9
  return math.floor(est / 100 + 0.5) * 100
end

local function isAllowed(info)
  local t = U().lower(info.type)
  if not ALLOWED_TYPES[t] then return false end
  if not info.power_hp or not info.weight_kg then return false end
  return true
end

function M.rebuild()
  cache, cacheList = {}, {}
  if not core_vehicles then
    U().log('E', 'vehicleDb: core_vehicles not available')
    return
  end
  local ok, res = pcall(core_vehicles.getConfigList)
  if not ok or not res then
    U().log('E', 'vehicleDb: getConfigList failed: %s', tostring(res))
    return
  end
  local models = {}
  for _, cfg in pairs(res.configs or {}) do
    local mk = cfg.model_key
    if mk and models[mk] == nil then
      local okm, model = pcall(core_vehicles.getModel, mk)
      models[mk] = okm and model and (model.model or model) or false
    end
    local okn, info = pcall(M.normalize, cfg, models[mk] or nil)
    if okn and info and isAllowed(info) then
      cache[info.key] = info
      table.insert(cacheList, info)
    elseif not okn then
      U().log('W', 'vehicleDb: normalize failed for %s: %s', tostring(cfg.key), tostring(info))
    end
  end
  table.sort(cacheList, function(a, b)
    if a.brand == b.brand then return a.name < b.name end
    return a.brand < b.brand
  end)
  U().log('I', 'vehicleDb: %d raceable configs indexed', #cacheList)
end

-- test hook: inject a prepared list of normalized infos
function M.setCache(list)
  cache, cacheList = {}, {}
  for _, info in ipairs(list) do
    cache[info.key] = info
    table.insert(cacheList, info)
  end
end

function M.all()
  if not cacheList then M.rebuild() end
  return cacheList or {}
end

function M.get(key)
  if not cache then M.rebuild() end
  return cache and cache[key] or nil
end

function M.brands()
  local set, list = {}, {}
  for _, info in ipairs(M.all()) do
    if not set[info.brand] then
      set[info.brand] = { name = info.brand, region = info.region, count = 0 }
      table.insert(list, set[info.brand])
    end
    set[info.brand].count = set[info.brand].count + 1
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

---------------------------------------------------------------------------
-- Criteria matching (pure). Used by events, café books, dealers and prizes.
-- criteria fields (all optional, AND-combined; list fields are OR inside):
--   models, configs(keys "model/config"), brands, regions, countries, categories,
--   excludeCategories, classes, drivetrains, bodyStyles, liMin, liMax,
--   powerMax, powerMin, weightMin, weightMax, yearMin, yearMax, priceMax, priceMin,
--   aspiration ('NA'|'Turbo'), nameContains
---------------------------------------------------------------------------
local function inList(list, value, ci)
  if not list then return true end
  if value == nil then return false end
  local u = U()
  for _, v in ipairs(list) do
    if ci then
      if u.lower(v) == u.lower(value) then return true end
    elseif v == value then
      return true
    end
  end
  return false
end

function M.matches(info, criteria, liOverride)
  if not criteria then return true end
  if not info then return false end
  local u = U()
  local r = info.rating or {}
  local li = liOverride or r.li or 0
  if criteria.configs and not inList(criteria.configs, info.key) then return false end
  if criteria.models and not inList(criteria.models, info.model, true) then return false end
  if criteria.brands and not inList(criteria.brands, info.brand, true) then return false end
  if criteria.regions and not inList(criteria.regions, info.region) then return false end
  if criteria.countries and not inList(criteria.countries, info.country, true) then return false end
  if criteria.categories and not inList(criteria.categories, r.category) then return false end
  if criteria.excludeCategories and inList(criteria.excludeCategories, r.category) then return false end
  if criteria.classes and not inList(criteria.classes, r.class) then return false end
  if criteria.drivetrains and not inList(criteria.drivetrains, info.drivetrain, true) then return false end
  if criteria.bodyStyles and not inList(criteria.bodyStyles, info.bodyStyle, true) then return false end
  if criteria.liMin and li < criteria.liMin then return false end
  if criteria.liMax and li > criteria.liMax then return false end
  if criteria.powerMax and (info.power_hp or 0) > criteria.powerMax then return false end
  if criteria.powerMin and (info.power_hp or 0) < criteria.powerMin then return false end
  if criteria.weightMax and (info.weight_kg or 0) > criteria.weightMax then return false end
  if criteria.weightMin and (info.weight_kg or 0) < criteria.weightMin then return false end
  if criteria.yearMin and (info.yearMin or 0) < criteria.yearMin then return false end
  if criteria.yearMax and (info.yearMin or 9999) > criteria.yearMax then return false end
  if criteria.priceMax and (info.price or 0) > criteria.priceMax then return false end
  if criteria.priceMin and (info.price or 0) < criteria.priceMin then return false end
  if criteria.aspiration then
    local turbo = u.icontains(info.induction, 'turbo') or u.icontains(info.induction, 'super')
    if criteria.aspiration == 'NA' and turbo then return false end
    if criteria.aspiration == 'Turbo' and not turbo then return false end
  end
  if criteria.nameContains then
    local found = false
    for _, w in ipairs(criteria.nameContains) do
      if u.icontains(info.name, w) then found = true break end
    end
    if not found then return false end
  end
  return true
end

function M.find(criteria, limit)
  local res = {}
  for _, info in ipairs(M.all()) do
    if M.matches(info, criteria) then
      res[#res + 1] = info
      if limit and #res >= limit then break end
    end
  end
  return res
end

-- human readable summary of a criteria table, e.g. for event cards
function M.describeCriteria(c)
  if not c then return 'Alle Fahrzeuge' end
  local parts = {}
  local function list(l) return table.concat(l, ', ') end
  if c.liMax and c.liMin then parts[#parts + 1] = string.format('LI %d-%d', c.liMin, c.liMax)
  elseif c.liMax then parts[#parts + 1] = 'LI max. ' .. c.liMax
  elseif c.liMin then parts[#parts + 1] = 'LI min. ' .. c.liMin end
  if c.drivetrains then parts[#parts + 1] = list(c.drivetrains) end
  if c.brands then parts[#parts + 1] = list(c.brands) end
  if c.regions then
    local names = {}
    for _, r in ipairs(c.regions) do names[#names + 1] = M.regionNames[r] or r end
    parts[#parts + 1] = 'Herkunft: ' .. list(names)
  end
  if c.categories then
    local names = {}
    for _, cat in ipairs(c.categories) do names[#names + 1] = R().categories[cat] or cat end
    parts[#parts + 1] = list(names)
  end
  if c.classes then parts[#parts + 1] = 'Klasse ' .. list(c.classes) end
  if c.powerMax then parts[#parts + 1] = 'max. ' .. c.powerMax .. ' PS' end
  if c.weightMax then parts[#parts + 1] = 'max. ' .. c.weightMax .. ' kg' end
  if c.yearMax then parts[#parts + 1] = 'Baujahr bis ' .. c.yearMax end
  if c.yearMin then parts[#parts + 1] = 'Baujahr ab ' .. c.yearMin end
  if c.aspiration then parts[#parts + 1] = (c.aspiration == 'NA' and 'Saugmotor' or 'Turbo') end
  if c.bodyStyles then parts[#parts + 1] = list(c.bodyStyles) end
  if c.models then parts[#parts + 1] = 'Modelle: ' .. list(c.models) end
  if #parts == 0 then return 'Alle Fahrzeuge' end
  return table.concat(parts, ' · ')
end

-- deterministic pick of a car that matches criteria (for prize cars / AI grids)
function M.pick(criteria, seed, exclude)
  local u = U()
  local pool = M.find(criteria)
  if exclude then
    pool = u.filter(pool, function(i) return not exclude[i.key] end)
  end
  if #pool == 0 then return nil end
  local rng = u.rng(seed or os.time())
  return rng:pick(pool)
end

function M.onExtensionLoaded() end

-- refresh cache if mods change
function M.onModActivated() cache, cacheList = nil, nil end
function M.onModDeactivated() cache, cacheList = nil, nil end

return M
