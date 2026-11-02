-- Turismo Karriere - util
-- Pure Lua helpers (no BeamNG API use) so they can be unit-tested outside the game.

local M = {}

M.LOG_TAG = 'turismo'

function M.log(level, msg, ...)
  local text = select('#', ...) > 0 and string.format(msg, ...) or tostring(msg)
  -- eigenes Log (settings/turismo/logs/turismo.log), siehe logger.lua
  local L = rawget(_G, 'extensions') and extensions.turismo_logger
  if L and L.log then
    L.log(level, M.LOG_TAG, text)
  elseif log then
    log(level, M.LOG_TAG, text)
  else
    print('[' .. level .. '] ' .. M.LOG_TAG .. ': ' .. text)
  end
end

function M.clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function M.lerp(a, b, t) return a + (b - a) * t end

-- maps v from [a0,a1] to [b0,b1], clamped
function M.remap(v, a0, a1, b0, b1)
  if a1 == a0 then return b0 end
  local t = M.clamp((v - a0) / (a1 - a0), 0, 1)
  return b0 + (b1 - b0) * t
end

function M.round(v, step)
  step = step or 1
  return math.floor(v / step + 0.5) * step
end

function M.deepcopy(o, seen)
  if type(o) ~= 'table' then return o end
  seen = seen or {}
  if seen[o] then return seen[o] end
  local r = {}
  seen[o] = r
  for k, v in pairs(o) do r[M.deepcopy(k, seen)] = M.deepcopy(v, seen) end
  return r
end

-- fills missing keys of t from defaults (recursively for tables); returns t
function M.applyDefaults(t, defaults)
  for k, v in pairs(defaults) do
    if t[k] == nil then
      t[k] = M.deepcopy(v)
    elseif type(v) == 'table' and type(t[k]) == 'table' and not M.isArray(v) then
      M.applyDefaults(t[k], v)
    end
  end
  return t
end

function M.isArray(t)
  if type(t) ~= 'table' then return false end
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  for i = 1, n do if t[i] == nil then return false end end
  return true
end

function M.count(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

function M.keys(t)
  local r = {}
  for k in pairs(t or {}) do r[#r + 1] = k end
  table.sort(r, function(a, b) return tostring(a) < tostring(b) end)
  return r
end

function M.indexBy(list, field)
  local r = {}
  for _, v in ipairs(list or {}) do
    if v[field] ~= nil then r[v[field]] = v end
  end
  return r
end

function M.contains(list, value)
  for _, v in ipairs(list or {}) do if v == value then return true end end
  return false
end

function M.filter(list, fn)
  local r = {}
  for _, v in ipairs(list or {}) do if fn(v) then r[#r + 1] = v end end
  return r
end

function M.map(list, fn)
  local r = {}
  for i, v in ipairs(list or {}) do r[i] = fn(v, i) end
  return r
end

function M.sum(list, fn)
  local s = 0
  for _, v in ipairs(list or {}) do s = s + (fn and fn(v) or v) end
  return s
end

function M.lower(s) return string.lower(tostring(s or '')) end

function M.trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

-- case-insensitive substring test
function M.icontains(haystack, needle)
  if not haystack or not needle then return false end
  return string.find(M.lower(haystack), M.lower(needle), 1, true) ~= nil
end

---------------------------------------------------------------------------
-- deterministic RNG (Park-Miller), so market rotations/AI grids are
-- reproducible per day and per save (no math.random state leaks)
---------------------------------------------------------------------------
local Rng = {}
Rng.__index = Rng

function M.rng(seed)
  local s = math.floor(math.abs(tonumber(seed) or 1)) % 2147483647
  if s == 0 then s = 1 end
  return setmetatable({ s = s }, Rng)
end

function Rng:next()
  self.s = (self.s * 16807) % 2147483647
  return self.s / 2147483647
end

function Rng:range(a, b) return a + (b - a) * self:next() end

function Rng:int(a, b) return math.floor(a + (b - a + 1) * self:next()) end

function Rng:pick(list)
  if not list or #list == 0 then return nil end
  return list[self:int(1, #list)]
end

-- approximately normal distributed value (mean 0, sd 1)
function Rng:gauss()
  local s = 0
  for _ = 1, 6 do s = s + self:next() end
  return (s - 3) / math.sqrt(0.5)
end

function Rng:shuffle(list)
  for i = #list, 2, -1 do
    local j = self:int(1, i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

function M.hashString(str)
  local h = 5381
  str = tostring(str or '')
  for i = 1, #str do
    h = (h * 33 + string.byte(str, i)) % 2147483647
  end
  return h
end

---------------------------------------------------------------------------
-- formatting (German locale)
---------------------------------------------------------------------------
function M.formatMoney(v)
  v = math.floor((tonumber(v) or 0) + 0.5)
  local neg = v < 0
  local s = tostring(math.abs(v))
  local out = s:reverse():gsub('(%d%d%d)', '%1.'):reverse()
  if out:sub(1, 1) == '.' then out = out:sub(2) end
  return (neg and '-' or '') .. out .. ' Cr.'
end

function M.formatTime(seconds)
  if not seconds or seconds ~= seconds or seconds == math.huge then return '--:--.---' end
  local m = math.floor(seconds / 60)
  local s = seconds - m * 60
  return string.format('%d:%06.3f', m, s)
end

function M.formatDistanceKm(meters)
  return string.format('%.1f km', (meters or 0) / 1000)
end

-- unique-ish id: prefix + counter persisted by caller
function M.makeId(prefix, counter)
  return string.format('%s_%05d', prefix, counter)
end

-- splits "model/config" or "model:config"
function M.splitCarKey(key)
  if not key then return nil, nil end
  local m, c = string.match(key, '^([^/:]+)[/:](.+)$')
  if m then return m, c end
  return key, nil
end

-- grid slots of a gameplay/race path: start positions without the recovery
-- points (race files list both in startPositions, group = 'recovery'); the
-- path's defaultStartPosition comes first
function M.startSlots(path)
  local out, def = {}, nil
  local sps = path and path.startPositions
  for _, sp in ipairs(sps and sps.sorted or {}) do
    if sp.group ~= 'recovery' and not (sp.name or ''):find('Recovery', 1, true) then
      if path.defaultStartPosition and sp.id == path.defaultStartPosition then def = sp
      else out[#out + 1] = sp end
    end
  end
  if def then table.insert(out, 1, def) end
  return out
end

return M
