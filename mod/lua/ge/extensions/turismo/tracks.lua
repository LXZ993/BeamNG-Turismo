-- Turismo Karriere - tracks
-- Track registry. Sources:
--   1) every "*.race.json" shipped with the game or mods (time trials, missions,
--      race editor files) - discovered automatically;
--   2) curated metadata in data/turismo/tracks.json (nicer names, surface, tags,
--      default laps, grid size) keyed by the race file path or by a pattern;
--   3) user tracks recorded with the in-game Streckenrekorder
--      (saved to settings/turismo/tracks/<level>/<name>.race.json).
-- Events reference tracks by id; an id can also be a "track tag" selector like
-- "@circuit:hirochi_raceway" which resolves to the best match on the install.

local M = {}

local function U() return extensions.turismo_util end
local function D() return extensions.turismo_data end

M.USER_DIR = 'settings/turismo/tracks/'

local registry = nil   -- id -> track
local list = nil

local function levelFromPath(p)
  return p:match('^/?levels/([^/]+)/') or p:match('/missions/([^/]+)/') or p:match('tracks/([^/]+)/')
end

local function idFromPath(p)
  local s = p:gsub('^/', ''):gsub('%.race%.json$', ''):gsub('[^%w]+', '_')
  return U().lower(s)
end

local function readJson(p) return jsonReadFile and jsonReadFile(p) or nil end

-- quick classification without building the full race path
local function inspectRaceFile(p)
  local data = readJson(p)
  if not data or not data.pathnodes then return nil end
  local nodes = data.pathnodes
  local starts = data.startPositions or {}
  local length = 0
  for i = 2, #nodes do
    local a, b = nodes[i - 1].pos, nodes[i].pos
    if a and b then
      local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
      length = length + math.sqrt(dx * dx + dy * dy + dz * dz)
    end
  end
  -- closed if a segment points back to the first node
  local closed = false
  local firstOld = nodes[1] and nodes[1].oldId
  for _, s in ipairs(data.segments or {}) do
    if firstOld and s.to == firstOld then closed = true break end
  end
  if closed and #nodes >= 2 then
    local a, b = nodes[#nodes].pos, nodes[1].pos
    if a and b then
      local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
      length = length + math.sqrt(dx * dx + dy * dy + dz * dz)
    end
  end
  return {
    name = data.name, description = data.description,
    nodes = #nodes, grid = #starts, closed = closed, lengthM = length,
    defaultLaps = data.defaultLaps or 1,
  }
end

local function guessSurface(level, name)
  local u = U()
  local t = u.lower((level or '') .. ' ' .. (name or ''))
  if t:find('dirt') or t:find('gravel') or t:find('rally') or t:find('utah') or t:find('johnson') or t:find('offroad') then return 'dirt' end
  if t:find('snow') or t:find('ice') then return 'snow' end
  return 'tarmac'
end

function M.rebuild()
  registry, list = {}, {}
  local files = {}
  if FS and FS.findFiles then
    for _, f in ipairs(FS:findFiles('/levels/', '*.race.json', -1, true, false) or {}) do files[#files + 1] = { f, 'game' } end
    for _, f in ipairs(FS:findFiles('/gameplay/missions/', '*.race.json', -1, true, false) or {}) do files[#files + 1] = { f, 'mission' } end
    for _, f in ipairs(FS:findFiles(M.USER_DIR, '*.race.json', -1, true, false) or {}) do files[#files + 1] = { f, 'user' } end
  end
  local curated = D().get('tracks') or {}
  local curatedByFile, curatedPatterns = {}, {}
  for _, c in ipairs(curated) do
    if c.file then curatedByFile[U().lower(c.file)] = c end
    if c.match then curatedPatterns[#curatedPatterns + 1] = c end
  end

  local seen = {}
  for _, entry in ipairs(files) do
    local f, source = entry[1], entry[2]
    local key = U().lower(f)
    if not seen[key] then
      seen[key] = true
      local info = inspectRaceFile(f)
      if info and info.nodes >= 2 then
        local level = levelFromPath(f) or 'unknown'
        local t = {
          id = idFromPath(f), file = f, level = level, source = source,
          name = (info.name and info.name ~= '' and info.name ~= 'New Race') and info.name or f:match('([^/]+)%.race%.json$'),
          description = info.description,
          closed = info.closed, lengthM = info.lengthM, grid = info.grid, nodes = info.nodes,
          defaultLaps = info.defaultLaps, surface = guessSurface(level, f), tags = {},
        }
        local c = curatedByFile[key]
        if not c then
          for _, cp in ipairs(curatedPatterns) do
            if U().icontains(f, cp.match) then c = cp break end
          end
        end
        if c then
          for k, v in pairs(c) do if k ~= 'file' and k ~= 'match' then t[k] = v end end
        end
        t.tags = t.tags or {}
        table.insert(t.tags, t.closed and 'circuit' or 'sprint')
        table.insert(t.tags, t.surface)
        table.insert(t.tags, level)
        registry[t.id] = t
        list[#list + 1] = t
      end
    end
  end
  table.sort(list, function(a, b)
    if a.level == b.level then return a.name < b.name end
    return a.level < b.level
  end)
  U().log('I', 'tracks: %d race tracks discovered', #list)
end

-- test hook
function M.setTracks(tlist)
  registry, list = {}, {}
  for _, t in ipairs(tlist) do registry[t.id] = t list[#list + 1] = t end
end

function M.all()
  if not list then M.rebuild() end
  return list
end

-- Resolve an id or selector:
--   "exact_id"
--   "@circuit:hirochi_raceway" -> any closed track on that level (longest first)
--   "@sprint:dirt"             -> any point-to-point dirt track
--   "@any:west_coast_usa"
-- seed makes the choice deterministic per event.
function M.resolve(ref, seed)
  if not ref then return nil end
  if type(ref) == 'table' then -- list of alternatives, first match wins
    for _, r in ipairs(ref) do
      local t = M.resolve(r, seed)
      if t then return t end
    end
    return nil
  end
  M.all()
  if registry[ref] then return registry[ref] end
  if ref:find('.race.json', 1, true) then -- exact race file (licence tests)
    local id = idFromPath(ref)
    if registry[id] then return registry[id] end
    local want = U().lower(ref:gsub('^/', ''))
    for _, t in ipairs(list) do
      if U().lower(t.file:gsub('^/', '')) == want then return t end
    end
    return nil
  end
  local kind, filterTag = ref:match('^@(%w+):?(.*)$')
  if not kind then return nil end
  local candidates = {}
  for _, t in ipairs(list) do
    local okKind = kind == 'any' or U().contains(t.tags, kind)
    local okTag = filterTag == '' or U().contains(t.tags, filterTag) or t.level == filterTag
    if okKind and okTag then candidates[#candidates + 1] = t end
  end
  if #candidates == 0 then return nil end
  table.sort(candidates, function(a, b) return (a.lengthM or 0) > (b.lengthM or 0) end)
  if seed then return U().rng(seed):pick(candidates) end
  return candidates[1]
end

function M.get(id) M.all() return registry[id] end

function M.byLevel()
  local res, idx = {}, {}
  for _, t in ipairs(M.all()) do
    if not idx[t.level] then
      idx[t.level] = { level = t.level, tracks = {} }
      res[#res + 1] = idx[t.level]
    end
    table.insert(idx[t.level].tracks, t)
  end
  return res
end

-- level path for freeroam loading
function M.levelPath(level)
  if core_levels and core_levels.getLevelByName then
    local ok, lvl = pcall(core_levels.getLevelByName, level)
    if ok and lvl then return lvl end
  end
  return '/levels/' .. level .. '/main.level.json'
end

---------------------------------------------------------------------------
-- Streckenrekorder: drive the course, press "Checkpoint" at every corner exit;
-- park on each grid slot and press "Startplatz". Saves a race.json the game's
-- own race system can load.
---------------------------------------------------------------------------
local rec = nil

function M.recorderStart(name, closed)
  rec = { name = name or ('Strecke ' .. os.date('%H%M')), closed = closed ~= false, cps = {}, grid = {} }
  return true
end

function M.recorderAddCheckpoint(radius)
  if not rec then return false end
  local veh = getPlayerVehicle and getPlayerVehicle(0)
  if not veh then return false end
  local pos = veh:getPosition()
  local dir = veh:getDirectionVector()
  rec.cps[#rec.cps + 1] = { pos = { pos.x, pos.y, pos.z }, normal = { dir.x, dir.y, dir.z }, radius = radius or 8 }
  return #rec.cps
end

function M.recorderAddGridSlot()
  if not rec then return false end
  local veh = getPlayerVehicle and getPlayerVehicle(0)
  if not veh then return false end
  -- same convention as gameplay/race/startPosition:setToVehicle (front centre, forward/up)
  local bb = veh:getSpawnWorldOOBB()
  local fl, fr = vec3(bb:getPoint(0)), vec3(bb:getPoint(3))
  local bl, flU = vec3(bb:getPoint(4)), vec3(bb:getPoint(1))
  rec.grid[#rec.grid + 1] = {
    pos = fl / 2 + fr / 2,
    rot = quatFromDir((fl - bl):normalized(), (flU - bl):normalized()),
  }
  return #rec.grid
end

function M.recorderState() return rec and { name = rec.name, cps = #rec.cps, grid = #rec.grid, closed = rec.closed } or nil end

function M.recorderCancel() rec = nil end

function M.recorderSave()
  if not rec or #rec.cps < 3 then return false, 'Mindestens 3 Checkpoints nötig.' end
  local level = getCurrentLevelIdentifier and getCurrentLevelIdentifier() or 'unknown'
  local path = require('/lua/ge/extensions/gameplay/race/path')(rec.name)
  path.name = rec.name
  path.description = 'Mit dem Turismo-Streckenrekorder erstellt.'
  path.defaultLaps = rec.closed and 3 or 1
  local ids = {}
  for i, cp in ipairs(rec.cps) do
    local pn = path.pathnodes:create('CP ' .. i)
    pn:setManual(vec3(cp.pos[1], cp.pos[2], cp.pos[3]), cp.radius, vec3(cp.normal[1], cp.normal[2], cp.normal[3]))
    ids[i] = pn.id
  end
  local order = U().deepcopy(ids)
  if rec.closed then order[#order + 1] = ids[1] end
  for i = 1, #order - 1 do
    local seg = path.segments:create('Seg ' .. i)
    seg:setFrom(order[i])
    seg:setTo(order[i + 1])
  end
  for i, g in ipairs(rec.grid) do
    local sp = path.startPositions:create('Grid ' .. i)
    sp:set(vec3(g.pos), g.rot)
  end
  local fileName = rec.name:gsub('[^%w%-_ ]', ''):gsub(' ', '_')
  local file = M.USER_DIR .. level .. '/' .. fileName .. '.race.json'
  local ok = jsonWriteFile(file, path:onSerialize(), true)
  rec = nil
  M.rebuild()
  return ok, file
end

return M
