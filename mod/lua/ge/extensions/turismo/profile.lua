-- Turismo Karriere - profile
-- Money, calendar (days advance with every race/test, like a racing calendar),
-- driving statistics, "Sammlerstufe" (collector level from owned car value),
-- daily distance goal ("Tagesetappe") and reward tickets ("Bonuslose").

local M = {}

local function U() return extensions.turismo_util end
local function S() return extensions.turismo_save end
local function D() return extensions.turismo_data end

M.defaults = {
  economy = {
    money = 15000,
    totalEarned = 0,
    totalSpent = 0,
    transactions = {}, -- last 50
  },
  calendar = {
    day = 1,
    dailyKm = 0,        -- km driven today (resets when a day passes)
    dailyGoalDone = false,
  },
  stats = {
    racesStarted = 0, racesWon = 0, podiums = 0, poles = 0,
    km = 0, maxSpeed = 0, crashes = 0, testsGold = 0,
    bestLaps = {},      -- trackId -> {time, car}
  },
  rewards = {
    tickets = {},       -- array of {id, tier, source, day}
    ticketCounter = 0,
  },
  collector = {
    level = 1,
    points = 0,
  },
}

local function st() return S().get() end

function M.money() return st() and st().economy.money or 0 end

function M.canAfford(amount) return M.money() >= amount end

local function addTransaction(amount, reason, category)
  local e = st().economy
  table.insert(e.transactions, 1, { day = st().calendar.day, amount = amount, reason = reason, category = category })
  while #e.transactions > 50 do table.remove(e.transactions) end
end

function M.earn(amount, reason, category)
  amount = math.floor(amount + 0.5)
  if amount <= 0 then return end
  local e = st().economy
  e.money = e.money + amount
  e.totalEarned = e.totalEarned + amount
  addTransaction(amount, reason, category or 'income')
  S().markDirty()
  if extensions.hook then extensions.hook('onTurismoMoneyChanged', e.money, amount, reason) end
end

-- returns true on success
function M.spend(amount, reason, category)
  amount = math.floor(amount + 0.5)
  if amount < 0 then return false end
  local e = st().economy
  if e.money < amount then return false end
  e.money = e.money - amount
  e.totalSpent = e.totalSpent + amount
  addTransaction(-amount, reason, category or 'expense')
  S().markDirty()
  if extensions.hook then extensions.hook('onTurismoMoneyChanged', e.money, -amount, reason) end
  return true
end

function M.day() return st() and st().calendar.day or 1 end

-- a race, test or long drive consumes a day
function M.advanceDay(n)
  n = n or 1
  local c = st().calendar
  local old = c.day
  c.day = c.day + n
  c.dailyKm = 0
  c.dailyGoalDone = false
  S().markDirty()
  if extensions.hook then extensions.hook('onTurismoDayAdvanced', c.day, old) end
end

-- called by the session with driven distance (meters) of the player car
function M.addDistance(meters)
  if not st() or meters <= 0 then return end
  local km = meters / 1000
  local c = st().calendar
  st().stats.km = st().stats.km + km
  c.dailyKm = c.dailyKm + km
  local goal = (D().economy().dailyGoalKm or 42)
  if not c.dailyGoalDone and c.dailyKm >= goal then
    c.dailyGoalDone = true
    M.grantTicket(1, 'Tagesetappe')
    if extensions.hook then extensions.hook('onTurismoToast', 'Tagesetappe geschafft! Du erhältst ein Bonuslos.', 'reward') end
  end
  S().markDirty()
end

---------------------------------------------------------------------------
-- reward tickets: tier 1..5 (stars). Opening draws from a weighted table.
---------------------------------------------------------------------------
function M.grantTicket(tier, source)
  local r = st().rewards
  r.ticketCounter = r.ticketCounter + 1
  table.insert(r.tickets, { id = 'T' .. r.ticketCounter, tier = tier or 1, source = source, day = M.day() })
  S().markDirty()
end

-- pure: prize table per tier (money amounts and chance to win a car)
function M.ticketTable(tier)
  local eco = D() and D().economy() or {}
  local tables = eco.ticketPrizes or {
    { { w = 50, money = 2000 }, { w = 30, money = 5000 }, { w = 15, money = 10000 }, { w = 5, car = { liMax = 400 } } },
    { { w = 45, money = 5000 }, { w = 30, money = 10000 }, { w = 17, money = 20000 }, { w = 8, car = { liMax = 500 } } },
    { { w = 40, money = 10000 }, { w = 30, money = 25000 }, { w = 20, money = 50000 }, { w = 10, car = { liMax = 600 } } },
    { { w = 35, money = 25000 }, { w = 30, money = 60000 }, { w = 20, money = 120000 }, { w = 15, car = { liMax = 700 } } },
    { { w = 30, money = 60000 }, { w = 30, money = 150000 }, { w = 20, money = 300000 }, { w = 20, car = { liMin = 600 } } },
  }
  return tables[U().clamp(tier, 1, #tables)]
end

-- opens a ticket; returns the prize. 'rngValue' (0..1) for tests
function M.openTicket(ticketId, rngValue)
  local r = st().rewards
  local idx
  for i, t in ipairs(r.tickets) do if t.id == ticketId then idx = i break end end
  if not idx then return nil, 'Los nicht gefunden' end
  local ticket = table.remove(r.tickets, idx)
  local tbl = M.ticketTable(ticket.tier)
  local total = 0
  for _, e in ipairs(tbl) do total = total + e.w end
  local roll = (rngValue or U().rng(os.time() + M.day() * 7919 + #r.tickets):next()) * total
  local prize = tbl[#tbl]
  for _, e in ipairs(tbl) do
    roll = roll - e.w
    if roll <= 0 then prize = e break end
  end
  local result = { tier = ticket.tier, display = {} }
  if prize.money then
    M.earn(prize.money, 'Bonuslos (' .. ticket.tier .. ' Sterne)', 'reward')
    result.money = prize.money
  elseif prize.car then
    local info = extensions.turismo_vehicleDb.pick(prize.car, U().hashString(ticket.id) + M.day())
    if info then
      local car = extensions.turismo_garage.addCar(info.key, { source = 'Bonuslos', mileageKm = 0 })
      result.car = car and car.id
      result.carName = info.name
    else
      M.earn(20000, 'Bonuslos (Ersatz)', 'reward')
      result.money = 20000
    end
  end
  S().markDirty()
  return result
end

---------------------------------------------------------------------------
-- collector level: based on the summed purchase value of every car ever owned
---------------------------------------------------------------------------
function M.collectorThresholds()
  return (D() and D().economy().collectorLevels) or
    { 0, 30000, 80000, 150000, 300000, 500000, 800000, 1200000, 2000000, 3500000, 5000000, 8000000 }
end

function M.addCollectorPoints(value)
  local c = st().collector
  c.points = c.points + math.max(0, math.floor(value))
  local th = M.collectorThresholds()
  local lvl = 1
  for i, v in ipairs(th) do if c.points >= v then lvl = i end end
  if lvl > c.level then
    c.level = lvl
    if extensions.hook then
      extensions.hook('onTurismoToast', 'Sammlerstufe ' .. lvl .. ' erreicht!', 'levelup')
      extensions.hook('onTurismoCollectorLevel', lvl)
    end
  end
  S().markDirty()
end

function M.collectorLevel() return st() and st().collector.level or 1 end

function M.recordBestLap(trackId, time, carName)
  local b = st().stats.bestLaps
  if not b[trackId] or time < b[trackId].time then
    b[trackId] = { time = time, car = carName, day = M.day() }
    S().markDirty()
    return true
  end
  return false
end

function M.onExtensionLoaded()
  S().registerDefaults('economy', M.defaults.economy)
  S().registerDefaults('calendar', M.defaults.calendar)
  S().registerDefaults('stats', M.defaults.stats)
  S().registerDefaults('rewards', M.defaults.rewards)
  S().registerDefaults('collector', M.defaults.collector)
end

return M
