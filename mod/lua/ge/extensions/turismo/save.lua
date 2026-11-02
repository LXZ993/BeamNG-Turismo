-- Turismo Karriere - save
-- One JSON file per profile slot in the user folder:
--   <userfolder>/settings/turismo/profile_<slot>.json (+ .bak rotation)
-- Every feature module owns a sub-table of the state and registers its
-- defaults via M.registerDefaults(name, table) so old saves are migrated
-- automatically when new fields appear.

local M = {}

local function U() return extensions.turismo_util end

M.SAVE_VERSION = 1
M.SAVE_DIR = 'settings/turismo/'
M.MAX_SLOTS = 3

local state = nil
local slot = nil
local dirty = false
local autosaveTimer = 0
local defaults = {}

function M.registerDefaults(name, tbl)
  defaults[name] = tbl
  if state then
    state[name] = state[name] or {}
    U().applyDefaults(state[name], tbl)
  end
end

local function path(s) return M.SAVE_DIR .. 'profile_' .. tostring(s) .. '.json' end

local function readJson(p)
  if jsonReadFile then return jsonReadFile(p) end
  return nil
end

local function writeJson(p, data)
  if jsonWriteFile then return jsonWriteFile(p, data, true) end
  return false
end

local function migrate(s)
  s.meta = s.meta or {}
  local v = s.meta.version or 0
  -- future migrations go here: if v < 2 then ... end
  s.meta.version = M.SAVE_VERSION
  for name, d in pairs(defaults) do
    s[name] = s[name] or {}
    U().applyDefaults(s[name], d)
  end
  return s, v
end

function M.newProfile(s, playerName, options)
  options = options or {}
  local now = os.time()
  state = {
    meta = {
      version = M.SAVE_VERSION,
      created = now,
      playerName = playerName or 'Fahrer',
      aiRating = 0.3, -- automatic opponent strength (turismo_aiDirector.autoDifficulty)
      progressionMode = options.progressionMode or 'menu', -- 'menu' (Café-Hefte) | 'classic' (frei, nur Lizenzen)
      damageMode = options.damageMode or 'realistic',      -- 'realistic' | 'mechanical' | 'off'
    },
  }
  slot = s or 1
  migrate(state)
  dirty = true
  M.save()
  if extensions.hook then extensions.hook('onTurismoProfileLoaded', state, true) end
  return state
end

function M.load(s)
  local data = readJson(path(s))
  if not data then
    U().log('W', 'save: no profile in slot %s', tostring(s))
    return nil
  end
  local oldVersion
  state, oldVersion = migrate(data)
  slot = s
  dirty = false
  U().log('I', 'save: loaded slot %s (v%s)', tostring(s), tostring(oldVersion))
  if extensions.hook then extensions.hook('onTurismoProfileLoaded', state, false) end
  return state
end

function M.save()
  if not state or not slot then return false end
  state.meta.saved = os.time()
  -- simple 1-step backup rotation
  local old = readJson(path(slot))
  if old then writeJson(path(slot) .. '.bak', old) end
  local ok = writeJson(path(slot), state)
  dirty = false
  autosaveTimer = 0
  return ok
end

function M.markDirty() dirty = true end

function M.get() return state end
function M.slot() return slot end
function M.isLoaded() return state ~= nil end

function M.unload()
  if dirty then M.save() end
  state, slot = nil, nil
end

-- list of slots with summary for the title screen
function M.listSlots()
  local res = {}
  for s = 1, M.MAX_SLOTS do
    local data = readJson(path(s))
    if data and data.meta then
      table.insert(res, {
        slot = s,
        exists = true,
        playerName = data.meta.playerName,
        saved = data.meta.saved,
        money = data.economy and data.economy.money or 0,
        day = data.calendar and data.calendar.day or 1,
        cars = data.garage and U().count(data.garage.cars) or 0,
        progress = data.cafe and data.cafe.completedCount or 0,
      })
    else
      table.insert(res, { slot = s, exists = false })
    end
  end
  return res
end

function M.deleteSlot(s)
  if FS and FS.removeFile then
    FS:removeFile(path(s))
    FS:removeFile(path(s) .. '.bak')
  end
  if slot == s then state, slot = nil, nil end
end

-- autosave every 60s of real time when dirty
function M.update(dtReal)
  if not state then return end
  autosaveTimer = autosaveTimer + (dtReal or 0)
  if dirty and autosaveTimer > 60 then M.save() end
end

-- tests
function M._setState(s, sl) state, slot = migrate(s), sl or 1 end

return M
