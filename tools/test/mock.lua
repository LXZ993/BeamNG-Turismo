-- Offline BeamNG mock for running Turismo logic under LuaJIT.
-- Usage: local H = dofile('tools/test/mock.lua'); H.boot{ root = '...' }
local H = {}
local J = dofile((H.dir or 'tools/test/') .. 'json.lua')
H.json = J

------------------------------------------------------------------ vec3 / quat
local V = {}
V.__index = V
function vec3(x, y, z)
  if type(x) == 'table' then return setmetatable({ x = x.x or x[1] or 0, y = x.y or x[2] or 0, z = x.z or x[3] or 0 }, V) end
  return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V)
end
V.__add = function(a, b) return vec3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__unm = function(a) return vec3(-a.x, -a.y, -a.z) end
V.__mul = function(a, b)
  if type(a) == 'number' then return vec3(b.x * a, b.y * a, b.z * a) end
  if type(b) == 'number' then return vec3(a.x * b, a.y * b, a.z * b) end
  return vec3(a.x * b.x, a.y * b.y, a.z * b.z)
end
V.__div = function(a, b) return vec3(a.x / b, a.y / b, a.z / b) end
V.__tostring = function(a) return string.format('vec3(%.2f,%.2f,%.2f)', a.x, a.y, a.z) end
function V:length() return math.sqrt(self.x ^ 2 + self.y ^ 2 + self.z ^ 2) end
function V:squaredLength() return self.x ^ 2 + self.y ^ 2 + self.z ^ 2 end
function V:normalized() local l = self:length() if l < 1e-12 then return vec3(0, 0, 0) end return self / l end
function V:normalize() local n = self:normalized() self.x, self.y, self.z = n.x, n.y, n.z return self end
function V:dot(b) return self.x * b.x + self.y * b.y + self.z * b.z end
function V:cross(b) return vec3(self.y * b.z - self.z * b.y, self.z * b.x - self.x * b.z, self.x * b.y - self.y * b.x) end
function V:distance(b) return (self - b):length() end
function V:squaredDistance(b) return (self - b):squaredLength() end
function V:set(x, y, z) if type(x) == 'table' then x, y, z = x.x, x.y, x.z end self.x, self.y, self.z = x, y, z return self end
function V:toTable() return { self.x, self.y, self.z } end

local Q = {}
Q.__index = Q
function quat(x, y, z, w)
  if type(x) == 'table' then return setmetatable({ x = x.x or x[1], y = x.y or x[2], z = x.z or x[3], w = x.w or x[4] }, Q) end
  return setmetatable({ x = x or 0, y = y or 0, z = z or 0, w = w or 1 }, Q)
end
Q.__mul = function(a, b)
  if getmetatable(b) == V then
    -- rotate vector
    local qv = vec3(a.x, a.y, a.z)
    local t = qv:cross(b) * 2
    return b + t * a.w + qv:cross(t)
  end
  return quat(
    a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
    a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
    a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
    a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z)
end
function Q:inversed() return quat(-self.x, -self.y, -self.z, self.w) end
function Q:toTable() return { self.x, self.y, self.z, self.w } end

local function quatFromMatrix(r, f, u) -- columns: x=right, y=forward, z=up
  local m00, m11, m22 = r.x, f.y, u.z
  local tr = m00 + m11 + m22
  local x, y, z, w
  if tr > 0 then
    local s = math.sqrt(tr + 1) * 2
    w = 0.25 * s; x = (f.z - u.y) / s; y = (u.x - r.z) / s; z = (r.y - f.x) / s
  elseif m00 > m11 and m00 > m22 then
    local s = math.sqrt(1 + m00 - m11 - m22) * 2
    w = (f.z - u.y) / s; x = 0.25 * s; y = (f.x + r.y) / s; z = (u.x + r.z) / s
  elseif m11 > m22 then
    local s = math.sqrt(1 + m11 - m00 - m22) * 2
    w = (u.x - r.z) / s; x = (f.x + r.y) / s; y = 0.25 * s; z = (u.y + f.z) / s
  else
    local s = math.sqrt(1 + m22 - m00 - m11) * 2
    w = (r.y - f.x) / s; x = (u.x + r.z) / s; y = (u.y + f.z) / s; z = 0.25 * s
  end
  return quat(x, y, z, w)
end

function quatFromDir(dir, up)
  up = up or vec3(0, 0, 1)
  local f = dir:normalized()
  local r = f:cross(up):normalized()
  local u = r:cross(f)
  return quatFromMatrix(r, f, u)
end

function quatFromEuler(x, y, z)
  local cx, sx = math.cos(x / 2), math.sin(x / 2)
  local cy, sy = math.cos(y / 2), math.sin(y / 2)
  local cz, sz = math.cos(z / 2), math.sin(z / 2)
  return quat(sx * cy * cz - cx * sy * sz, cx * sy * cz + sx * cy * sz, cx * cy * sz - sx * sy * cz, cx * cy * cz + sx * sy * sz)
end

------------------------------------------------------------------ globals
H.logs = {}
function log(level, tag, msg) H.logs[#H.logs + 1] = level .. ' ' .. tostring(msg) if H.verbose then print(level, tag, msg) end end
function dump(...) print(...) end
H.guiEvents = {}
guihooks = { trigger = function(name, data) H.guiEvents[#H.guiEvents + 1] = { name = name, data = data } end }
H.time = 0
os.clockhp = function() return H.time end

function H.readText(p) local f = io.open(p, 'r') if not f then return nil end local s = f:read('*a') f:close() return s end

local function resolve(p)
  if p:sub(1, 1) ~= '/' then p = '/' .. p end
  if p:match('^/settings/') then return H.settingsDir .. p:sub(#'/settings/' + 1) end
  if H.overlay then
    local f = io.open(H.overlay .. p, 'r')
    if f then f:close() return H.overlay .. p end
  end
  return H.root .. p
end
H.resolve = resolve

function jsonReadFile(p)
  local s = H.readText(resolve(p))
  if not s then return nil end
  local ok, res = pcall(J.decode, s)
  if not ok then print('json error in ' .. p .. ': ' .. tostring(res)) return nil end
  return res
end
function jsonWriteFile(p, data)
  local real = resolve(p)
  os.execute('mkdir -p "' .. real:match('^(.*)/[^/]*$') .. '"')
  local f = io.open(real, 'w') f:write(J.encode(data)) f:close()
  return true
end
jsonEncode, jsonDecode = J.encode, J.decode

FS = {}
function FS:fileExists(p) local f = io.open(resolve(p), 'r') if f then f:close() return true end return false end
function FS:directoryExists(p) return os.execute('test -d "' .. resolve(p) .. '"') == 0 end
function FS:removeFile(p) os.remove(resolve(p)) return true end
function FS:renameFile(a, b) os.rename(resolve(a), resolve(b)) return true end
function FS:copyFile(a, b) os.execute('cp "' .. resolve(a) .. '" "' .. resolve(b) .. '"') return true end
function FS:directoryCreate(p) os.execute('mkdir -p "' .. resolve(p) .. '"') return true end
local findIn
function FS:findFiles(dir, pattern, depth, recursive, dirs)
  local out = findIn(resolve(dir), pattern, depth)
  if H.overlay and not dir:match('^/?settings/') then
    for _, f in ipairs(findIn(H.overlay .. (dir:sub(1, 1) == '/' and dir or '/' .. dir), pattern, depth, H.overlay)) do out[#out + 1] = f end
  end
  table.sort(out)
  return out
end
function findIn(real, pattern, depth, base)
  local glob = pattern:gsub('%*', '*')
  local cmd = string.format('find "%s" %s -name "%s" -type f 2>/dev/null', real, (depth == 0) and '-maxdepth 1' or '', glob)
  local out = {}
  local pipe = io.popen(cmd)
  for line in pipe:lines() do
    local rel
    if line:sub(1, #H.settingsDir) == H.settingsDir then rel = '/settings/' .. line:sub(#H.settingsDir + 1)
    elseif base then rel = line:sub(#base + 1)
    else rel = line:sub(#H.root + 1) end
    out[#out + 1] = rel
  end
  pipe:close()
  table.sort(out)
  return out
end

------------------------------------------------------------------ extensions
extensions = { _loaded = {} }
function extensions.hook(name, ...)
  for _, ext in pairs(extensions._loaded) do
    if type(ext[name]) == 'function' then ext[name](...) end
  end
end
function extensions.load(...)
  for _, name in ipairs({ ... }) do
    if not extensions._loaded[name] then
      local file = name:match('^turismo_(.+)$')
      local path = H.root .. '/lua/ge/extensions/turismo/' .. file .. '.lua'
      local chunk = assert(loadfile(path))
      local mod = chunk()
      extensions._loaded[name] = mod
      extensions[name] = mod
      if mod.onExtensionLoaded then mod.onExtensionLoaded() end
    end
  end
end
function extensions.isExtensionLoaded(n) return extensions._loaded[n] ~= nil end
function extensions.unload(n) extensions._loaded[n] = nil extensions[n] = nil end
setExtensionUnloadMode = function() end
function extensions.setExtensionUnloadMode() end

------------------------------------------------------------------ vehicles
core_vehicles = {}
function core_vehicles.getConfigList()
  return jsonReadFile('/../tools/test/fixture_vehicles.json') or H.fixture
end
function core_vehicles.getModel(mk) return { model = { key = mk, Name = mk } } end
function getCurrentLevelIdentifier() return H.level end
Engine = { Audio = { playOnce = function() end } }

------------------------------------------------------------------ boot
function H.boot(opts)
  H.root = opts.root
  H.settingsDir = opts.settingsDir or '/tmp/turismo_test_settings/'
  H.overlay = opts.overlay
  os.execute('rm -rf "' .. H.settingsDir .. '" && mkdir -p "' .. H.settingsDir .. '"')
  H.fixture = J.decode(H.readText(opts.fixture))
  core_vehicles.getConfigList = function() return H.fixture end
  return H
end

-- tiny test framework
H.passed, H.failed = 0, 0
function H.test(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then H.passed = H.passed + 1 print('  ok   ' .. name)
  else H.failed = H.failed + 1 print('  FAIL ' .. name .. '\n       ' .. tostring(err)) end
end
function H.eq(a, b, msg) if a ~= b then error((msg or 'eq') .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a), 2) end end
function H.near(a, b, tol, msg) if math.abs(a - b) > (tol or 1e-6) then error((msg or 'near') .. ': expected ~' .. tostring(b) .. ', got ' .. tostring(a), 2) end end
function H.truthy(v, msg) if not v then error((msg or 'expected truthy'), 2) end end

return H
