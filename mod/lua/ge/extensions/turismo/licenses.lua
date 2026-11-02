-- Turismo Karriere - licenses ("Lizenzzentrum")
-- Five licence grades, each made of several driving tests with gold/silver/bronze
-- targets. A licence is granted when every test has at least bronze.
-- First-time medals pay out; all-gold on a licence awards a bonus car.

local M = {}

local function U() return extensions.turismo_util end
local function S() return extensions.turismo_save end
local function D() return extensions.turismo_data end
local function P() return extensions.turismo_profile end

M.MEDALS = { 'gold', 'silver', 'bronze' }
M.MEDAL_RANK = { gold = 3, silver = 2, bronze = 1, none = 0 }
M.MEDAL_NAMES = { gold = 'Gold', silver = 'Silber', bronze = 'Bronze', none = 'Keine' }

M.defaults = {
  owned = {},        -- licenseId -> day obtained
  results = {},      -- testId -> {medal, best, attempts}
  calibration = {},  -- testId -> reference time from demo run (for 'auto' targets)
  routeEstimate = {}, -- testId -> reference time computed on the real road (first start)
  allGoldRewarded = {},
}

local function ls() return S().get().licenses end

function M.has(id)
  if not id then return true end
  return ls().owned[id] ~= nil
end

function M.list() return D().get('licenses') or {} end

-- Which car is used for a test: fixed rental key, rental chosen by criteria
-- (deterministic per test, so it stays the same), or the player's own car.
function M.testCar(test)
  local c = test.car or {}
  local vdb = extensions.turismo_vehicleDb
  if c.key and vdb.get(c.key) then return vdb.get(c.key), true end
  if c.criteria then
    local pool = vdb.find(c.criteria)
    table.sort(pool, function(a, b) return a.key < b.key end)
    if #pool > 0 then return pool[(U().hashString(test.id) % #pool) + 1], true end
  end
  if c.rental == false then
    local car = extensions.turismo_garage and extensions.turismo_garage.active()
    return car and vdb.get(car.key) or nil, false
  end
  -- last resort: cheapest street car on the install
  local pool = vdb.find({ categories = { 'street' }, liMax = 380 })
  table.sort(pool, function(a, b) return a.key < b.key end)
  return pool[1], true
end

-- Medal targets. Modes:
--   explicit : { gold = s, silver = s, bronze = s }
--   estimate : reference time computed from course geometry and the test car's
--              power/weight/grip (turismo_tests.estimateCourseTime) or, for
--              track tests, the lap time model; factors per medal
--   auto     : reference = AI demo run (calibration), estimate until calibrated
-- A calibration from a demo run always wins when present.
function M.targetsFor(test)
  local t = test.targets or { mode = 'estimate' }
  if t.gold and t.mode ~= 'estimate' and t.mode ~= 'auto' then return t end
  local ref = ls() and ls().calibration[test.id]
  local source = 'demo'
  if not ref and ls() and ls().routeEstimate then
    ref = ls().routeEstimate[test.id]
    source = 'route'
  end
  if not ref then
    local info = M.testCar(test)
    if info then
      local ok, est = pcall(extensions.turismo_tests.estimateTime, test, info)
      if ok then ref = est source = 'estimate' end
    end
  end
  if not ref then return { mode = t.mode or 'estimate' } end
  if test.scoring == 'score' then
    return { gold = ref * (t.gold or 1.0), silver = ref * (t.silver or 0.8), bronze = ref * (t.bronze or 0.6), source = source }
  end
  return {
    gold = ref * (t.goldFactor or 1.03),
    silver = ref * (t.silverFactor or 1.08),
    bronze = ref * (t.bronzeFactor or 1.16),
    source = source,
  }
end

-- pure-ish: medal for a time (lower is better) or score (higher is better)
function M.medalFor(test, value)
  if value == nil then return 'none' end
  local t = M.targetsFor(test)
  local higherBetter = test.scoring == 'score'
  for _, m in ipairs(M.MEDALS) do
    local target = t[m]
    if target then
      if higherBetter and value >= target then return m end
      if not higherBetter and value <= target then return m end
    end
  end
  return 'none'
end

-- can the player take this licence?
function M.isAvailable(lic)
  if lic.requires and not M.has(lic.requires) then
    local r = D().license(lic.requires)
    return false, 'Benötigt ' .. (r and r.name or ('Lizenz ' .. lic.requires))
  end
  if extensions.turismo_progression and not extensions.turismo_progression.isUnlocked('license_' .. lic.id) then
    return false, 'Noch nicht freigeschaltet'
  end
  return true
end

function M.progress(lic)
  local done, gold = 0, 0
  for _, t in ipairs(lic.tests or {}) do
    local r = ls().results[t.id]
    if r and M.MEDAL_RANK[r.medal] and M.MEDAL_RANK[r.medal] > 0 then done = done + 1 end
    if r and r.medal == 'gold' then gold = gold + 1 end
  end
  return done, gold, #(lic.tests or {})
end

-- records a finished attempt; returns {medal, improved, reward, licenseGranted}
function M.recordResult(testId, value, failed)
  local test = D().test(testId)
  if not test then return nil end
  local st = ls()
  local r = st.results[testId] or { medal = 'none', attempts = 0 }
  r.attempts = r.attempts + 1
  local out = { medal = 'none', improved = false, reward = 0 }
  if not failed and value then
    local medal = M.medalFor(test, value)
    out.medal = medal
    local higherBetter = test.scoring == 'score'
    if r.best == nil or (higherBetter and value > r.best) or (not higherBetter and value < r.best) then
      r.best = value
      out.newBest = true
    end
    if M.MEDAL_RANK[medal] > M.MEDAL_RANK[r.medal or 'none'] then
      -- pay the difference between old and new medal reward
      local rewards = test.rewards or D().economy().testRewards or { bronze = 1000, silver = 2000, gold = 4000 }
      local old = rewards[r.medal] or 0
      local new = rewards[medal] or 0
      out.reward = math.max(0, new - old)
      r.medal = medal
      out.improved = true
      if out.reward > 0 then P().earn(out.reward, 'Lizenztest ' .. (test.name or testId), 'license') end
      if medal == 'gold' then S().get().stats.testsGold = (S().get().stats.testsGold or 0) + 1 end
    end
  end
  st.results[testId] = r

  -- licence completion
  if test.licenseId then
    local lic = D().license(test.licenseId)
    local done, gold, total = M.progress(lic)
    if done == total and not st.owned[lic.id] then
      st.owned[lic.id] = P().day()
      out.licenseGranted = lic.id
      if extensions.hook then
        extensions.hook('onTurismoLicenseGranted', lic.id)
        extensions.hook('onTurismoToast', 'Glückwunsch! Du hast die Lizenz "' .. lic.name .. '" erhalten.', 'license')
      end
    end
    if gold == total and not st.allGoldRewarded[lic.id] and lic.allGoldReward then
      st.allGoldRewarded[lic.id] = true
      local info = extensions.turismo_vehicleDb.pick(lic.allGoldReward, U().hashString(lic.id))
      if info then
        extensions.turismo_garage.addCar(info.key, { source = 'Lizenz ' .. lic.name .. ' (alles Gold)' })
        out.giftCar = info.name
      end
    end
  end
  S().markDirty()
  return out
end

function M.setCalibration(testId, time)
  ls().calibration[testId] = time
  U().log('I', 'licenses: %s calibrated by demo run: %.2f s', tostring(testId), time)
  S().markDirty()
end

function M.setRouteEstimate(testId, time)
  local st = ls()
  st.routeEstimate = st.routeEstimate or {}
  st.routeEstimate[testId] = time
  U().log('I', 'licenses: %s reference time on the road: %.2f s', tostring(testId), time)
  S().markDirty()
end

-- everything the briefing screen shows for one test (licence or driving school)
function M.testInfo(t)
  local r = ls().results[t.id] or {}
  local info = {
    id = t.id, name = t.name, desc = t.desc, goal = t.goal, tip = t.tip, place = t.place, type = t.type,
    category = t.category, school = t.school,
    medal = r.medal or 'none', best = r.best, attempts = r.attempts or 0,
    targets = M.targetsFor(t), scoring = t.scoring or 'time',
    carName = (M.testCar(t) or {}).name, ownCar = t.car and t.car.rental == false,
    rolling = t.start and t.start.kind == 'rolling' or nil,
    rewards = t.rewards or D().economy().testRewards,
  }
  if t.type == 'path' and extensions.turismo_courses then
    local c = extensions.turismo_courses.resolve(t.race)
    if c then
      local gates = extensions.turismo_tests.pathGates(t, c)
      local n = 0
      for _, g in ipairs(gates) do if g.kind ~= 'stop' then n = n + 1 end end
      local parts = { string.format('%d Tore', n) }
      if t.laps then parts[#parts + 1] = t.laps == 1 and '1 Runde' or (t.laps .. ' Runden') end
      if t.finish == 'stop' then parts[#parts + 1] = 'Anhalten in der Zone' end
      for k, rule in pairs(t.speed or {}) do
        if rule.min then parts[#parts + 1] = string.format('Tor %s mit mind. %d km/h', k, rule.min) end
        if rule.max then parts[#parts + 1] = string.format('Tor %s mit höchstens %d km/h', k, rule.max) end
      end
      info.info = table.concat(parts, ', ')
    else
      info.missing = true
    end
  end
  return info
end

function M.snapshot()
  local res = {}
  for _, lic in ipairs(M.list()) do
    local avail, why = M.isAvailable(lic)
    local done, gold, total = M.progress(lic)
    local tests = {}
    for _, t in ipairs(lic.tests or {}) do tests[#tests + 1] = M.testInfo(t) end
    res[#res + 1] = {
      id = lic.id, name = lic.name, short = lic.short, desc = lic.desc, color = lic.color,
      owned = M.has(lic.id), available = avail, reason = why,
      done = done, gold = gold, total = total, tests = tests,
    }
  end
  return res
end

function M.onExtensionLoaded()
  S().registerDefaults('licenses', M.defaults)
end

return M
