-- Turismo Karriere - logger
-- Eigenes Log für die Fehlersuche bei Testern und Spielern (Aufbau wie bei Hashiriya Battle).
-- Datei: <BeamNG-Userordner>/settings/turismo/logs/turismo.log
-- Größe begrenzt: ab maxKb wird die Datei zu turismo.1.log (ältere rücken auf .2, .3 ...),
-- höchstens `files` Dateien insgesamt. Gleiche Meldungen hintereinander werden zusammengefasst,
-- sehr häufige Meldungen gedrosselt. Fehler in Hooks und UI-Aktionen werden mit Traceback und
-- Spielzustand festgehalten. "Fehlerbericht erstellen" schreibt alles in bugreport.txt.
--
-- Benutzung im Code: immer über turismo_util.log(level, fmt, ...). util leitet hierher weiter.
-- Level: D = Debug (nur mit "level": "D"), I = Info, W = Warnung, E = Fehler.

local M = {}

local logTag = 'turismo'
local beamLog = rawget(_G, 'log')

M.LOG_DIR = 'settings/turismo/logs/'
local logPath, reportPath
local function setPaths()
  logPath = M.LOG_DIR .. 'turismo.log'
  -- Dateiname immer englisch (Tester aus aller Welt schicken diese Datei)
  reportPath = M.LOG_DIR .. 'bugreport.txt'
end
setPaths()
local buildPath = '/data/turismo/build.json'

-- Standardwerte, überschreibbar in data/turismo/build.json unter "log"
local cfg = {
  level = 'I',          -- D = alles (Debug), I = normal, W = nur Warnungen und Fehler, E = nur Fehler
  maxKb = 512,          -- so groß wird eine Datei höchstens
  files = 4,            -- turismo.log + 3 ältere = höchstens ca. 2 MB
  statusMinutes = 5,    -- alle x Minuten (Echtzeit) eine Statuszeile, 0 = aus
  perMinute = 30,       -- dieselbe Meldung höchstens so oft pro Minute, danach nur gezählt
  flushSeconds = 2,     -- Puffer so oft in die Datei schreiben (Fehler sofort)
}
local levels = { D = 1, I = 2, W = 3, E = 4 }

local buffer = {}
local size = 0
local last = nil      -- { key, count, lastTime } für "wiederholt"
local rate = {}       -- Meldung -> { count, start, dropped }
local flushTimer = 0
local statusTimer = 0
local errorsSeen = {} -- erste Fehlerzeile -> Anzahl (Traceback nur beim ersten Mal)
local started = false
local useAppend = true

local function now() return os.date('%Y-%m-%d %H:%M:%S') end
local function try(f) local ok, v = pcall(f) if ok then return v end end

local function readText(path)
  if rawget(_G, 'readFile') then return try(function() return readFile(path) end) end
  local f = io.open(path, 'r')
  if not f then return nil end
  local t = f:read('*a')
  f:close()
  return t
end

local function writeText(path, text)
  if rawget(_G, 'writeFile') then return pcall(writeFile, path, text) end
  local f = io.open(path, 'w')
  if not f then return false end
  f:write(text)
  f:close()
  return true
end

local function exists(path)
  if FS and FS.fileExists then return try(function() return FS:fileExists(path) end) end
  local f = io.open(path, 'r')
  if f then f:close() return true end
  return false
end

local function fileSize(path)
  return try(function()
    local f = io.open(path, 'r')
    if not f then return 0 end
    local s = f:seek('end') or 0
    f:close()
    return s
  end) or 0
end

local function removeFile(path)
  pcall(function()
    if FS and FS.removeFile then FS:removeFile(path) else os.remove(path) end
  end)
end

local function renameFile(from, to)
  local ok = pcall(function() FS:renameFile(from, to) end)
  if not ok or not exists(to) then ok = pcall(os.rename, from, to) end
  return ok and exists(to)
end

local function rotate()
  removeFile(M.LOG_DIR .. 'turismo.' .. (cfg.files - 1) .. '.log')
  for i = cfg.files - 2, 1, -1 do
    local from = M.LOG_DIR .. 'turismo.' .. i .. '.log'
    if exists(from) then renameFile(from, M.LOG_DIR .. 'turismo.' .. (i + 1) .. '.log') end
  end
  if not renameFile(logPath, M.LOG_DIR .. 'turismo.1.log') then
    -- Umbenennen geht nicht: Datei leeren, damit sie nicht wächst
    writeText(logPath, '')
  end
  size = 0
end

function M.flush()
  if #buffer == 0 then return end
  local text = table.concat(buffer, '\n') .. '\n'
  buffer = {}
  if size + #text > cfg.maxKb * 1024 then rotate() end
  local ok = false
  if useAppend then
    ok = pcall(function()
      local f = io.open(logPath, 'a')
      if not f then error('io.open') end
      f:write(text)
      f:close()
    end)
    if not ok then useAppend = false end
  end
  if not ok then
    -- Ersatzweg: ganze Datei neu schreiben (bleibt durch maxKb begrenzt)
    writeText(logPath, (readText(logPath) or '') .. text)
  end
  size = size + #text
end

local function push(line, urgent)
  buffer[#buffer + 1] = line
  if urgent or #buffer > 200 then M.flush() end
end

local function closeRepeat()
  if last and last.count > 1 then
    push(string.format('%s  ... %dx wiederholt', last.lastTime, last.count))
  end
  last = nil
end

-- Hauptfunktion: wie BeamNGs log(level, tag, text), schreibt zusätzlich in turismo.log
function M.log(level, tag, text)
  level = level or 'I'
  text = tostring(text)
  if level ~= 'D' and beamLog then beamLog(level, tag or logTag, text) end
  if (levels[level] or 2) < (levels[cfg.level] or 2) then return end
  local key = level .. '|' .. text
  local t = os.time()
  -- Drosseln: gleiche Meldung zu oft pro Minute
  local r = rate[key]
  if not r or t - r.start > 60 then r = { count = 0, start = t, dropped = 0 } rate[key] = r end
  r.count = r.count + 1
  if r.count > cfg.perMinute then
    r.dropped = r.dropped + 1
    if r.dropped == 1 then push(now() .. ' ' .. level .. ' (gedrosselt, kommt sehr oft) ' .. text) end
    return
  end
  -- Zusammenfassen: gleiche Meldung direkt hintereinander
  if last and last.key == key then
    last.count = last.count + 1
    last.lastTime = now()
    return
  end
  closeRepeat()
  last = { key = key, count = 1, lastTime = now() }
  push(now() .. ' ' .. level .. ' ' .. text, level == 'E')
end

-- Spielzustand für Fehlermeldungen und Statuszeilen
function M.context()
  local parts = {}
  local function add(k, v) if v ~= nil then parts[#parts + 1] = k .. '=' .. tostring(v) end end
  local X = function(n) return extensions and extensions['turismo_' .. n] end
  add('level', try(function() return getCurrentLevelIdentifier() end))
  local S = X('save')
  local st = S and try(function() return S.get() end)
  if st then
    add('slot', try(function() return S.slot() end))
    add('tag', try(function() return st.calendar.day end))
    add('geld', try(function() return st.economy.money end))
    add('hardcore', try(function() return st.meta.hardcore end))
    add('auto', try(function()
      local G = X('garage')
      local c = G.get(G.active())
      return c and (tostring(c.model) .. ' ' .. tostring(c.config or c.name or ''))
    end))
  else
    add('spielstand', 'keiner')
  end
  add('rennen', try(function() return X('race').isActive() end))
  add('modus', try(function() return X('modes').isActive() end))
  add('drag', try(function() return X('drag').isActive() end))
  add('test', try(function() return X('tests').isActive() end))
  add('hub', try(function() return extensions.turismo_core.isHubVisible() end))
  add('veh', try(function()
    local v = getPlayerVehicle(0)
    return v and (v:getJBeamFilename() .. ' ' .. string.format('%.0f km/h', v:getVelocity():length() * 3.6))
  end))
  return table.concat(parts, ', ')
end

-- Fehler abfangen: Funktion läuft in xpcall; ein Fehler wird mit Traceback geloggt statt das Spiel zu stören.
-- Gibt bei Fehler nil, Fehlertext zurück (damit Aufrufer wie uiCall die Meldung weitergeben können).
function M.wrap(name, f)
  return function(...)
    local res = { xpcall(f, debug.traceback, ...) }
    if res[1] then return unpack(res, 2, table.maxn(res)) end
    local err = tostring(res[2])
    local first = err:match('^[^\n]*') or err
    local n = (errorsSeen[first] or 0) + 1
    errorsSeen[first] = n
    if n == 1 then
      M.log('E', logTag, 'FEHLER in ' .. name .. ': ' .. err .. '\n    Zustand: ' .. M.context())
    else
      M.log('E', logTag, 'FEHLER in ' .. name .. ' (' .. n .. '. Mal): ' .. first)
    end
    return nil, first
  end
end

-- Alle Hooks (on...) eines Moduls schützen. Nur für Module ohne eigene Rückgabewerte in Hooks.
function M.protect(modName)
  local m = extensions and extensions[modName]
  if type(m) ~= 'table' or m._turismoProtected then return end
  for k, f in pairs(m) do
    if type(f) == 'function' and k:match('^on%u') and k ~= 'onUpdate' then
      m[k] = M.wrap(modName:gsub('^turismo_', '') .. '.' .. k, f)
    end
  end
  m._turismoProtected = true
end

-- Sitzungskopf: alles, was man für die Fehlersuche wissen muss
local function modList()
  local names = {}
  pcall(function()
    for name, mod in pairs(core_modmanager.getMods() or {}) do
      if mod.active ~= false then names[#names + 1] = name end
    end
  end)
  table.sort(names)
  return names
end

function M.build()
  return (jsonReadFile and try(function() return jsonReadFile(buildPath) end)) or {}
end

local function header()
  local build = M.build()
  local lines = {
    '',
    '==================== Sitzung ' .. now() .. ' ====================',
    'Mod: Turismo Karriere ' .. tostring(build.modVersion or '?') .. (build.release and ' (Release)' or ' (Entwicklung)'),
    'BeamNG: ' .. tostring(rawget(_G, 'beamng_versiond') or rawget(_G, 'beamng_versionb') or '?')
      .. ', Sprache: ' .. tostring(try(function() return settings.getValue('userLanguage') end) or '?'),
  }
  local mods = modList()
  if #mods > 0 then lines[#lines + 1] = 'Aktive Mods (' .. #mods .. '): ' .. table.concat(mods, ', ') end
  return lines
end

-- Datencheck: kaputte JSON-Dateien und Inhaltsfehler gleich beim Start melden
function M.checkData()
  local D = extensions and extensions.turismo_data
  if D and D.KINDS then
    for _, kind in ipairs(D.KINDS) do
      local path = D.DIR .. kind .. '.json'
      if exists(path) and jsonReadFile and not try(function() return jsonReadFile(path) end) then
        M.log('E', logTag, 'Datencheck: data/turismo/' .. kind .. '.json ist kaputt (JSON-Fehler, Details in beamng.log)')
      end
    end
  end
  local problems = D and D.validate and try(function() return D.validate() end) or {}
  if #problems > 0 then
    local shown = {}
    for i = 1, math.min(#problems, 15) do shown[i] = tostring(problems[i]) end
    M.log('W', logTag, string.format('Datencheck: %d Probleme: %s%s', #problems, table.concat(shown, ' | '), #problems > 15 and ' | ...' or ''))
  end
  M.log('I', logTag, string.format('Datencheck: %d Serien, %d Lizenzen, %d Café-Hefte, %d Fahrer geprüft',
    #(D and try(function() return D.get('events') end) or {}), #(D and try(function() return D.get('licenses') end) or {}),
    #(D and try(function() return D.get('cafe') end) or {}), #(D and try(function() return D.get('drivers') end) or {})))
end

function M.start()
  if started then return end
  started = true
  setPaths()
  for k, v in pairs(M.build().log or {}) do if cfg[k] ~= nil then cfg[k] = v end end
  pcall(function() if not FS:directoryExists(M.LOG_DIR) then FS:directoryCreate(M.LOG_DIR, true) end end)
  size = fileSize(logPath)
  for _, l in ipairs(header()) do push(l) end
  M.flush()
end

-- Fehlerbericht: Kopf, Spielzustand, Spielstand und die letzten Log-Zeilen in eine Datei
local function tailLines(path, maxLines)
  local text = readText(path) or ''
  local lines = {}
  for l in text:gmatch('[^\n]*') do lines[#lines + 1] = l end
  local out = {}
  for i = math.max(1, #lines - maxLines + 1), #lines do out[#out + 1] = lines[i] end
  return out
end

function M.writeReport(note)
  closeRepeat()
  M.flush()
  local out = { 'Turismo Karriere Fehlerbericht vom ' .. now() }
  for _, l in ipairs(header()) do out[#out + 1] = l end
  out[#out + 1] = 'Zustand: ' .. M.context()
  if note and note ~= '' then out[#out + 1] = 'Notiz: ' .. tostring(note) end
  out[#out + 1] = ''
  local S = extensions and extensions.turismo_save
  local slot = S and try(function() return S.slot() end)
  out[#out + 1] = '---------- Spielstand (profile_' .. tostring(slot or '-') .. '.json) ----------'
  out[#out + 1] = slot and readText('settings/turismo/profile_' .. tostring(slot) .. '.json') or '(kein Spielstand geladen)'
  out[#out + 1] = ''
  out[#out + 1] = '---------- Log (ältere Datei, Ende) ----------'
  for _, l in ipairs(tailLines(M.LOG_DIR .. 'turismo.1.log', 300)) do out[#out + 1] = l end
  out[#out + 1] = '---------- Log (aktuell) ----------'
  for _, l in ipairs(tailLines(logPath, 1500)) do out[#out + 1] = l end
  local ok = writeText(reportPath, table.concat(out, '\n'))
  M.log(ok and 'I' or 'E', logTag, ok and ('Fehlerbericht geschrieben: ' .. reportPath) or 'Fehlerbericht konnte nicht geschrieben werden')
  return ok and reportPath or nil
end

function M.onUpdate(dtReal)
  flushTimer = flushTimer + (dtReal or 0)
  if flushTimer >= cfg.flushSeconds then
    flushTimer = 0
    if last and last.count > 1 then closeRepeat() end
    M.flush()
  end
  statusTimer = statusTimer + (dtReal or 0)
  if cfg.statusMinutes > 0 and statusTimer >= cfg.statusMinutes * 60 then
    statusTimer = 0
    M.log('I', logTag, 'Status: ' .. M.context())
  end
end

function M.onExtensionUnloaded()
  closeRepeat()
  M.log('I', logTag, 'Mod entladen')
  M.flush()
end

-- für die Tests
function M._config() return cfg end
function M._paths() return { log = logPath, report = reportPath } end
function M._reset(dir)
  M.LOG_DIR = dir or M.LOG_DIR
  started, buffer, size, last, rate, errorsSeen, useAppend = false, {}, 0, nil, {}, {}, true
  setPaths()
end

return M
