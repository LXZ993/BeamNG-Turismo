-- Turismo Karriere - data
-- Loads the content definitions shipped in /data/turismo/*.json.
-- Players and modders can add content by dropping extra files named
--   /data/turismo/<kind>_<anything>.json  (e.g. events_myseries.json)
-- which are merged into the base lists (same id = override).

local M = {}

local function U() return extensions.turismo_util end

M.KINDS = { 'economy', 'licenses', 'trainings', 'events', 'cafe', 'drivers', 'teams', 'dealers', 'tracks', 'venues', 'music' }
M.DIR = '/data/turismo/'

local db = {}

local function readFile(p)
  if jsonReadFile then return jsonReadFile(p) end
  return nil
end

local function listFiles(kind)
  local files = {}
  if FS and FS.findFiles then
    for _, f in ipairs(FS:findFiles(M.DIR, kind .. '*.json', 0, true, false) or {}) do
      files[#files + 1] = f
    end
    table.sort(files) -- base file "<kind>.json" sorts before "<kind>_x.json"
  else
    files[1] = M.DIR .. kind .. '.json'
  end
  return files
end

-- merges list-shaped content by id; object-shaped content by key
local function merge(base, add)
  if not base then return U().deepcopy(add) end
  if U().isArray(add) and U().isArray(base) then
    local index = {}
    for i, v in ipairs(base) do if type(v) == 'table' and v.id then index[v.id] = i end end
    for _, v in ipairs(add) do
      if type(v) == 'table' and v.id and index[v.id] then
        base[index[v.id]] = v
      else
        base[#base + 1] = v
      end
    end
    return base
  end
  for k, v in pairs(add) do base[k] = v end
  return base
end

function M.reload()
  db = {}
  for _, kind in ipairs(M.KINDS) do
    for _, f in ipairs(listFiles(kind)) do
      local name = f:match('([^/]+)%.json$') or ''
      -- only accept "<kind>.json" and "<kind>_*.json"
      if name == kind or name:sub(1, #kind + 1) == kind .. '_' then
        local content = readFile(f)
        if content then
          local payload = content.items or content
          db[kind] = merge(db[kind], payload)
        else
          U().log('E', 'data: could not read %s', f)
        end
      end
    end
  end
  M.buildIndexes()
  U().log('I', 'data: loaded %d events, %d licenses, %d café books, %d drivers',
    #(db.events or {}), #(db.licenses or {}), #(db.cafe or {}), #(db.drivers or {}))
end

-- test hook
function M.set(kind, content)
  db[kind] = content
  M.buildIndexes()
end

function M.buildIndexes()
  db._eventsById = {}
  for _, series in ipairs(db.events or {}) do
    db._eventsById[series.id] = series
    for i, race in ipairs(series.races or {}) do
      race.index = i
      race.seriesId = series.id
    end
  end
  db._licensesById = U().indexBy(db.licenses or {}, 'id')
  db._testsById = {}
  for _, lic in ipairs(db.licenses or {}) do
    for i, t in ipairs(lic.tests or {}) do
      t.licenseId = lic.id
      t.index = i
      db._testsById[t.id] = t
    end
  end
  for _, tr in ipairs(db.trainings or {}) do
    db._testsById[tr.id] = tr
  end
  db._cafeById = U().indexBy(db.cafe or {}, 'id')
  db._driversById = U().indexBy(db.drivers or {}, 'id')
end

function M.get(kind) return db[kind] end
function M.economy() return db.economy or {} end
function M.series(id) return db._eventsById and db._eventsById[id] end
function M.license(id) return db._licensesById and db._licensesById[id] end
function M.test(id) return db._testsById and db._testsById[id] end
function M.cafeBook(id) return db._cafeById and db._cafeById[id] end
function M.driver(id) return db._driversById and db._driversById[id] end

-- validation report: references to unknown ids, missing tracks etc.
function M.validate()
  local problems = {}
  local function p(msg, ...) problems[#problems + 1] = string.format(msg, ...) end
  for _, s in ipairs(db.events or {}) do
    if s.requires and s.requires.license and not M.license(s.requires.license) then
      p('Serie %s verlangt unbekannte Lizenz %s', s.id, s.requires.license)
    end
    if not s.races or #s.races == 0 then p('Serie %s hat keine Rennen', s.id) end
    local noTrack = { drag = true, derby = true, crawl = true }
    for _, r in ipairs(s.races or {}) do
      local typ = r.type or s.type
      if not r.track and not noTrack[typ] then p('Rennen %s/%d hat keine Strecke', s.id, r.index or 0) end
    end
  end
  for _, b in ipairs(db.cafe or {}) do
    for _, step in ipairs(b.steps or {}) do
      if step.license and not M.license(step.license) then
        p('Café-Heft %s verweist auf unbekannte Lizenz %s', b.id, step.license)
      end
      if step.test and not M.test(step.test) then
        p('Café-Heft %s verweist auf unbekannten Test %s', b.id, step.test)
      end
      if step.series and not M.series(step.series) then
        p('Café-Heft %s verweist auf unbekannte Serie %s', b.id, step.series)
      end
    end
  end
  return problems
end

return M
