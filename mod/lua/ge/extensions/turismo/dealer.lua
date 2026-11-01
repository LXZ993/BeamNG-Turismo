-- Turismo Karriere - dealer
-- 1) Neuwagen-Zentrum: brand showrooms grouped by region (every installed brand).
-- 2) Gebrauchtwagenmarkt: rotating offers with mileage and wear, changes every few days.
-- 3) Klassiker-Galerie: rare older cars at collector prices, slow rotation, can sell out.

local M = {}

local function U() return extensions.turismo_util end
local function S() return extensions.turismo_save end
local function D() return extensions.turismo_data end
local function VDB() return extensions.turismo_vehicleDb end
local function G() return extensions.turismo_garage end
local function P() return extensions.turismo_profile end
local function LIC() return extensions.turismo_licenses end

M.defaults = {
  soldOut = {},       -- offerId -> true (legend/used offers are unique)
  seedSalt = 0,       -- set once per profile
}

local function eco() return D().economy() end

local function dealerState() return S().get().dealer end

local function profileSeed()
  local ds = dealerState()
  if ds.seedSalt == 0 then
    ds.seedSalt = (S().get().meta.created or 12345) % 100000 + 1
    S().markDirty()
  end
  return ds.seedSalt
end

---------------------------------------------------------------------------
-- purchase restrictions: high performance cars need licenses, like a real
-- racing career (configurable in economy.json -> purchaseLicenseByLI)
---------------------------------------------------------------------------
function M.requiredLicense(info)
  local rules = eco().purchaseLicenseByLI or {
    { liMin = 800, license = 'L4' },
    { liMin = 650, license = 'L3' },
  }
  local cat = info.rating and info.rating.category
  for _, r in ipairs(rules) do
    if info.rating.li >= r.liMin then return r.license end
  end
  if cat == 'gt' or cat == 'proto' then return 'L3' end
  if cat == 'touring' or cat == 'rally' then return 'L2' end
  return nil
end

local function licenseOk(info)
  local req = M.requiredLicense(info)
  if not req then return true, nil end
  return LIC().has(req), req
end

---------------------------------------------------------------------------
-- new cars
---------------------------------------------------------------------------
function M.regions()
  local regions = {}
  local byRegion = {}
  for _, b in ipairs(VDB().brands()) do
    local r = b.region or 'other'
    if not byRegion[r] then
      byRegion[r] = { id = r, name = VDB().regionNames[r] or r, brands = {} }
      table.insert(regions, byRegion[r])
    end
    table.insert(byRegion[r].brands, b)
  end
  local order = { japan = 1, europe = 2, america = 3, asia = 4, oceania = 5, other = 9 }
  table.sort(regions, function(a, b) return (order[a.id] or 8) < (order[b.id] or 8) end)
  return regions
end

local function offerFromInfo(info, price, extra)
  local ok, req = licenseOk(info)
  local o = {
    key = info.key, name = info.name, brand = info.brand, configName = info.configName,
    rating = info.rating, price = price, preview = info.preview,
    power = info.power_hp, weight = info.weight_kg, drivetrain = info.drivetrain,
    year = info.yearMin, country = info.country,
    licenseRequired = req, licenseOk = ok,
  }
  for k, v in pairs(extra or {}) do o[k] = v end
  o.id = o.offerId or o.key
  o.li = info.rating and info.rating.li
  o.class = info.rating and info.rating.class
  o.category = info.rating and info.rating.category
  return o
end

function M.showroom(brand)
  local res = {}
  for _, info in ipairs(VDB().all()) do
    if info.brand == brand then
      res[#res + 1] = offerFromInfo(info, info.price, { kind = 'new' })
    end
  end
  table.sort(res, function(a, b) return a.price < b.price end)
  return res
end

---------------------------------------------------------------------------
-- used cars: deterministic per rotation window
---------------------------------------------------------------------------
-- pure: used price model
-- BeamNG's "Value" already is a market value for the car's era, so used
-- prices are not depreciated by age again: mileage, wear and a little haggling
-- room decide the price.
function M.usedPrice(marketPrice, ageYears, mileageKm, wear, jitter)
  local u = U()
  local kmF = u.remap(mileageKm, 0, 240000, 1.0, 0.55)
  local wearF = 1 - (wear or 0) * 0.3
  local j = jitter or 1
  return math.max(500, math.floor(marketPrice * kmF * wearF * j / 50 + 0.5) * 50)
end

function M.usedOffers(day)
  day = day or P().day()
  local rot = eco().usedRotationDays or 3
  local window = math.floor((day - 1) / rot)
  local rng = U().rng(profileSeed() * 7 + window * 104729)
  local pool = VDB().find({ excludeCategories = { 'proto' }, liMax = 760 })
  rng:shuffle(pool)
  local count = math.min(#pool, eco().usedOfferCount or 20)
  local res = {}
  local currentYear = eco().currentYear or 2025
  for i = 1, count do
    local info = pool[i]
    local id = string.format('U%d_%s', window, info.key)
    if not dealerState().soldOut[id] then
      local ageYears = math.max(1, currentYear - (info.yearMax or info.yearMin or currentYear - 5) + rng:int(0, 6))
      local mileage = math.floor(U().clamp(math.min(ageYears, 22) * rng:range(4000, 12500), 4000, 240000) / 100) * 100
      local wear = U().clamp(mileage / 320000 + rng:range(-0.05, 0.12), 0, 0.75)
      local price = M.usedPrice(info.price, ageYears, mileage, wear, rng:range(0.88, 1.12))
      res[#res + 1] = offerFromInfo(info, price, {
        kind = 'used', offerId = id, mileageKm = mileage, wear = wear,
        ageYears = ageYears,
        daysLeft = rot - ((day - 1) % rot),
        integrity = U().round(1 - wear * 0.25, 0.01), -- applied as fallback part integrity on first spawn
        visual = U().round(1 - wear * 0.6, 0.01),
      })
    end
  end
  table.sort(res, function(a, b) return a.price < b.price end)
  return res
end

---------------------------------------------------------------------------
-- legends: older cars, long rotation, collector pricing, sell out when bought
---------------------------------------------------------------------------
function M.legendOffers(day)
  day = day or P().day()
  local rot = eco().legendRotationDays or 7
  local window = math.floor((day - 1) / rot)
  local rng = U().rng(profileSeed() * 13 + window * 7919)
  local pool = VDB().find({ yearMax = eco().legendYearMax or 1995 })
  rng:shuffle(pool)
  local res = {}
  for i = 1, math.min(#pool, eco().legendOfferCount or 8) do
    local info = pool[i]
    local id = string.format('L%d_%s', window, info.key)
    local mult = 1.4 + rng:next() * 1.6 + (info.rating.li / 1000)
    res[#res + 1] = offerFromInfo(info, math.floor(info.price * mult / 100 + 0.5) * 100, {
      kind = 'legend', offerId = id, mileageKm = math.floor(rng:range(20000, 120000) / 100) * 100,
      wear = 0.1, integrity = 0.97, visual = 0.9,
      soldOut = dealerState().soldOut[id] == true,
      daysLeft = rot - ((day - 1) % rot),
      collectorLevel = eco().legendCollectorLevel or 4,
    })
  end
  return res
end

---------------------------------------------------------------------------
-- buying
---------------------------------------------------------------------------
local function findOffer(kind, keyOrId)
  if kind == 'new' then
    local info = VDB().get(keyOrId)
    return info and offerFromInfo(info, info.price, { kind = 'new' })
  end
  local list = kind == 'used' and M.usedOffers() or M.legendOffers()
  for _, o in ipairs(list) do
    if o.offerId == keyOrId then return o end
  end
  return nil
end

function M.buy(kind, keyOrId)
  if extensions.turismo_progression and not extensions.turismo_progression.isUnlocked('dealer_' .. kind) then
    return nil, 'Dieser Händler ist noch nicht freigeschaltet.'
  end
  local o = findOffer(kind, keyOrId)
  if not o then return nil, 'Angebot nicht mehr verfügbar.' end
  if o.soldOut then return nil, 'Bereits verkauft.' end
  if not o.licenseOk then
    return nil, 'Für dieses Fahrzeug brauchst du die Lizenz ' .. tostring(o.licenseRequired) .. '.'
  end
  if o.collectorLevel and P().collectorLevel() < o.collectorLevel then
    return nil, 'Benötigt Sammlerstufe ' .. o.collectorLevel .. '.'
  end
  if not P().canAfford(o.price) then return nil, 'Nicht genug Credits.' end
  P().spend(o.price, 'Kauf: ' .. o.name, 'car')
  local car, err = G().addCar(o.key, {
    source = kind == 'new' and 'Neuwagen' or (kind == 'used' and 'Gebrauchtwagen' or 'Klassiker-Galerie'),
    price = o.price,
    mileageKm = o.mileageKm or 0,
    oilKm = kind == 'used' and math.floor((o.mileageKm or 0) % 7000) or 0,
    cleanliness = kind == 'used' and math.floor(40 + (1 - (o.wear or 0)) * 50) or 100,
  })
  if not car then
    P().earn(o.price, 'Erstattung', 'refund')
    return nil, err
  end
  if o.integrity or o.visual then
    car.usedFallback = { integrity = o.integrity or 1, visual = o.visual or 1 }
  end
  if o.offerId then dealerState().soldOut[o.offerId] = true end
  S().markDirty()
  return car
end

function M.onExtensionLoaded()
  S().registerDefaults('dealer', M.defaults)
end

return M
