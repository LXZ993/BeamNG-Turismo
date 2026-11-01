-- Turismo Karriere - cafe ("Boxenstopp-Café" / Menühefte)
-- A guided career path: the café owner hands out numbered booklets with tasks
-- (own certain cars, win trophies, earn licences, drive tests). Completing a
-- booklet pays a reward, tells a short story about the cars and unlocks new
-- parts of the world (dealers, halls, licences, tuning ...).
-- In "classic" progression mode the booklets are optional side goals.

local M = {}

local function U() return extensions.turismo_util end
local function S() return extensions.turismo_save end
local function D() return extensions.turismo_data end
local function VDB() return extensions.turismo_vehicleDb end
local function G() return extensions.turismo_garage end
local function P() return extensions.turismo_profile end
local function LIC() return extensions.turismo_licenses end

M.defaults = {
  current = nil,      -- active book id
  completed = {},     -- bookId -> day
  completedCount = 0,
  unlocked = {},      -- feature key -> true
  seenIntro = {},
}

local function cs() return S().get().cafe end

function M.books() return D().get('cafe') or {} end

local function bookIndex(id)
  for i, b in ipairs(M.books()) do if b.id == id then return i end end
  return nil
end

-- first book that is not completed and whose prerequisites are done
function M.nextBook()
  for _, b in ipairs(M.books()) do
    if not cs().completed[b.id] then
      local ok = true
      for _, req in ipairs(b.after or {}) do
        if not cs().completed[req] then ok = false break end
      end
      if b.collectorLevel and P().collectorLevel() < b.collectorLevel then ok = false end
      if ok then return b end
    end
  end
  return nil
end

---------------------------------------------------------------------------
-- step evaluation (pure-ish: reads garage/licence/event state)
---------------------------------------------------------------------------
function M.stepProgress(step)
  local t = step.type
  if t == 'own' then
    local keys, n = {}, 0
    for _, car in pairs(G().cars()) do
      local info = VDB().get(car.key)
      if info and VDB().matches(info, step.criteria) and not keys[car.key] then
        keys[car.key] = true
        n = n + 1
      end
    end
    return math.min(n, step.count or 1), step.count or 1
  elseif t == 'trophy' then
    local st = S().get().events.series[step.series] or {}
    local best = 99
    if step.race then
      best = st.trophies and st.trophies[step.race] or 99
    else
      for _, pos in pairs(st.trophies or {}) do if pos < best then best = pos end end
      if step.allRaces then
        local s = D().series(step.series)
        local cnt = 0
        for i = 1, #(s and s.races or {}) do
          if st.trophies and st.trophies[i] and st.trophies[i] <= (step.position or 3) then cnt = cnt + 1 end
        end
        return cnt, #(s and s.races or {})
      end
    end
    return (best <= (step.position or 3)) and 1 or 0, 1
  elseif t == 'championship' then
    local st = S().get().events.series[step.series] or {}
    return (st.done and (not step.win or st.won)) and 1 or 0, 1
  elseif t == 'license' then
    return LIC().has(step.license) and 1 or 0, 1
  elseif t == 'test' then
    local r = S().get().licenses.results[step.test]
    local rank = r and LIC().MEDAL_RANK[r.medal] or 0
    return rank >= (LIC().MEDAL_RANK[step.medal or 'bronze'] or 1) and 1 or 0, 1
  elseif t == 'money' then
    return math.min(P().money(), step.amount), step.amount
  elseif t == 'km' then
    return math.floor(math.min(S().get().stats.km or 0, step.km)), step.km
  elseif t == 'collector' then
    return math.min(P().collectorLevel(), step.level), step.level
  end
  return 0, 1
end

function M.bookProgress(book)
  local done, total = 0, 0
  local steps = {}
  for i, step in ipairs(book.steps or {}) do
    local have, need = M.stepProgress(step)
    total = total + 1
    if have >= need then done = done + 1 end
    steps[i] = { label = step.label, have = have, need = need, done = have >= need, hint = step.hint }
  end
  return done, total, steps
end

---------------------------------------------------------------------------
-- completion
---------------------------------------------------------------------------
function M.tryComplete(bookId)
  local book = D().cafeBook(bookId)
  if not book or cs().completed[book.id] then return nil end
  local done, total = M.bookProgress(book)
  if done < total then return nil, 'Noch nicht alle Aufgaben erfüllt.' end
  cs().completed[book.id] = P().day()
  cs().completedCount = (cs().completedCount or 0) + 1
  local reward = { book = book.name, unlocks = {} }
  local r = book.reward or {}
  if r.money then P().earn(r.money, 'Café: ' .. book.name, 'cafe') reward.money = r.money end
  if r.ticket then P().grantTicket(r.ticket, 'Café') reward.ticket = r.ticket end
  if r.car then
    local info = type(r.car) == 'string' and VDB().get(r.car) or VDB().pick(r.car, U().hashString(book.id))
    if info then
      G().addCar(info.key, { source = 'Café: ' .. book.name })
      reward.car = info.name
    end
  end
  for _, key in ipairs(book.unlocks or {}) do
    cs().unlocked[key] = true
    reward.unlocks[#reward.unlocks + 1] = key
  end
  if cs().current == book.id then cs().current = nil end
  local nxt = M.nextBook()
  if nxt then cs().current = nxt.id end
  S().markDirty()
  if extensions.hook then
    extensions.hook('onTurismoToast', 'Menüheft "' .. book.name .. '" abgeschlossen!', 'cafe')
    extensions.hook('onTurismoCafeComplete', book.id, reward)
  end
  return reward
end

function M.accept(bookId)
  local nb = M.nextBook()
  if not nb or nb.id ~= bookId then return false end
  cs().current = bookId
  cs().seenIntro[bookId] = true
  S().markDirty()
  return true
end

-- checks the active book after relevant career events (auto-detect "ready")
local function check()
  if not S().isLoaded() then return end
  local cur = cs().current and D().cafeBook(cs().current)
  if not cur then return end
  local done, total = M.bookProgress(cur)
  if done == total and cs().readyNotified ~= cur.id then
    cs().readyNotified = cur.id
    if extensions.hook then
      extensions.hook('onTurismoToast', 'Menüheft erfüllt! Bring es im Café vorbei.', 'cafe')
    end
  end
end

function M.onTurismoCarAdded() check() end
function M.onTurismoRaceResult() check() end
function M.onTurismoLicenseGranted() check() end

function M.isUnlocked(key) return cs().unlocked[key] == true end

function M.snapshot()
  local res = { books = {}, current = cs().current, completedCount = cs().completedCount or 0 }
  local nb = M.nextBook()
  for i, b in ipairs(M.books()) do
    local status = cs().completed[b.id] and 'done' or (b.id == cs().current and 'active' or ((nb and nb.id == b.id) and 'next' or 'locked'))
    local entry = { id = b.id, number = i, name = b.name, status = status, chapter = b.chapter }
    if status ~= 'locked' then
      local done, total, steps = M.bookProgress(b)
      entry.intro, entry.outro, entry.steps, entry.done, entry.total = b.intro, b.outro, steps, done, total
      entry.reward = b.reward
      entry.unlocks = b.unlockNames or b.unlocks
    end
    res.books[#res.books + 1] = entry
  end
  return res
end

function M.onExtensionLoaded()
  S().registerDefaults('cafe', M.defaults)
end

function M.onTurismoProfileLoaded(state, isNew)
  if isNew or not state.cafe.current then
    local nb = M.nextBook()
    if nb then state.cafe.current = nb.id end
  end
end

return M
