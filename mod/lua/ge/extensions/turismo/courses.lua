-- Turismo Karriere - courses
-- Licence tests and driving school use real BeamNG courses: the checkpoints
-- ("pathnodes") of the game's own race files. Examples on 0.40:
--   ETK-Fahrerzentrum (level driver_training): 13 training courses
--     /gameplay/missions/driver_training/campaigns/<nr>-<name>/race.race.json
--   Hirochi Raceway, Automation Test Track, Italien: time trial / race circuits
-- This module reads such a file, puts the checkpoints in driving order and
-- builds sections (from checkpoint A to B), sectors and laps from them.
-- Pure Lua on plain tables {x,y,z}, unit testable.

local M = {}

local function U() return extensions.turismo_util end

local function v2len(x, y) return math.sqrt(x * x + y * y) end

-- race file data -> { nodes = {{x,y,z,r,nx,ny}}, closed, starts = {{pos,rot}}, defaultStart }
function M.fromData(data, file)
  local list = data and data.pathnodes
  if type(list) ~= 'table' or #list < 2 then return nil end
  local byOld = {}
  for i, n in ipairs(list) do byOld[n.oldId or i] = n end
  local nextOf = {}
  for _, s in ipairs(data.segments or {}) do
    if s.from and s.to and nextOf[s.from] == nil then nextOf[s.from] = s.to end
  end
  local order = {}
  local id = data.startNode
  if not (id and byOld[id]) then id = list[1].oldId or 1 end
  if next(nextOf) then
    local seen = {}
    while id and byOld[id] and not seen[id] do
      seen[id] = true
      order[#order + 1] = byOld[id]
      id = nextOf[id]
    end
  end
  if #order < 2 then order = list end
  local nodes = {}
  for _, n in ipairs(order) do
    local p = n.pos
    if p then
      local nn = n.normal
      nodes[#nodes + 1] = { x = p[1], y = p[2], z = p[3] or 0, r = math.max(n.radius or 5, 1.5),
        nx = nn and nn[1] or nil, ny = nn and nn[2] or nil }
    end
  end
  if #nodes < 2 then return nil end
  -- travel direction at each checkpoint (towards the next one)
  local closed = data.classification and data.classification.closed
  if closed == nil then
    local first = order[1].oldId
    for _, s in ipairs(data.segments or {}) do if s.to == first then closed = true end end
  end
  closed = closed == true
  for i, n in ipairs(nodes) do
    local a = nodes[i - 1] or (closed and nodes[#nodes]) or n
    local b = nodes[i + 1] or (closed and nodes[1]) or n
    local dx, dy = b.x - a.x, b.y - a.y
    local l = v2len(dx, dy)
    if l < 1e-6 then dx, dy, l = 0, 1, 1 end
    n.fx, n.fy = dx / l, dy / l
    n.dist = i > 1 and v2len(n.x - nodes[i - 1].x, n.y - nodes[i - 1].y) or 0
  end
  local starts = {}
  local defaultStart
  for _, sp in ipairs(data.startPositions or {}) do
    local nm = U and U() and U().lower(sp.name or '') or (sp.name or ''):lower()
    if sp.pos and sp.group ~= 'recovery' and not nm:find('recovery', 1, true) then
      starts[#starts + 1] = { pos = { x = sp.pos[1], y = sp.pos[2], z = sp.pos[3] }, rot = sp.rot, name = sp.name, id = sp.oldId }
      if data.defaultStartPosition and sp.oldId == data.defaultStartPosition then defaultStart = #starts end
    end
  end
  local length = 0
  for i = 2, #nodes do length = length + nodes[i].dist end
  if closed then length = length + v2len(nodes[1].x - nodes[#nodes].x, nodes[1].y - nodes[#nodes].y) end
  return { file = file, name = data.name, nodes = nodes, closed = closed, starts = starts,
    defaultStart = defaultStart or (starts[1] and 1 or nil), length = length }
end

local cache = {}
function M.load(file)
  if not file then return nil end
  if cache[file] ~= nil then return cache[file] or nil end
  local data = jsonReadFile and jsonReadFile(file)
  local c = data and M.fromData(data, file)
  cache[file] = c or false
  if not c and U() then U().log('W', 'courses: no usable checkpoints in %s', tostring(file)) end
  return c
end
function M.clearCache() cache = {} end

-- first existing file of a list of candidates (string or list)
function M.resolve(files)
  if type(files) == 'string' then files = { files } end
  for _, f in ipairs(files or {}) do
    local c = M.load(f)
    if c then return c end
  end
  return nil
end

-- heading change at checkpoint i (degrees, + = left)
function M.turnAt(course, i)
  local n = course.nodes
  local a, p, b = n[i - 1], n[i], n[i + 1]
  if course.closed then a = a or n[#n] b = b or n[1] end
  if not (a and b and p) then return 0 end
  local h1 = math.atan2(p.y - a.y, p.x - a.x)
  local h2 = math.atan2(b.y - p.y, b.x - p.x)
  local d = h2 - h1
  while d > math.pi do d = d - 2 * math.pi end
  while d < -math.pi do d = d + 2 * math.pi end
  return math.deg(d)
end

-- gate list for a section. sel = { from, to, laps, sector, of }
-- returns gates (copies with idx) in driving order. For laps on a closed
-- course the gates go round 'laps' times and end at checkpoint 1.
function M.section(course, sel)
  sel = sel or {}
  local n = #course.nodes
  local from, to = math.max(1, math.min(n, sel.from or 1)), math.max(1, math.min(n, sel.to or n))
  if sel.sector and sel.of then
    local per = n / sel.of
    from = math.floor((sel.sector - 1) * per) + 1
    to = math.floor(sel.sector * per) + 1
    if to > n then to = course.closed and 1 or n end
  end
  local gates = {}
  local function add(i, lap)
    local src = course.nodes[i]
    local g = {}
    for k, v in pairs(src) do g[k] = v end
    g.node, g.lap = i, lap
    gates[#gates + 1] = g
  end
  if sel.laps and course.closed then
    for lap = 1, sel.laps do
      for i = (lap == 1 and 2 or 2), n do add(i, lap) end
      add(1, lap)
    end
    return gates, 1, 1
  end
  local i = from
  local guard = 0
  while true do
    add(i, 1)
    if i == to then break end
    i = i + 1
    if i > n then
      if not course.closed then break end
      i = 1
    end
    guard = guard + 1
    if guard > n + 1 then break end
  end
  return gates, from, to
end

-- start pose: standing start on the first gate looking to the second,
-- rolling start 'back' metres before the first gate.
-- returns pos {x,y,z}, dir {x,y}
function M.startPose(gates, kind, back)
  local g1, g2 = gates[1], gates[2] or gates[1]
  local dx, dy = g2.x - g1.x, g2.y - g1.y
  local l = v2len(dx, dy)
  if l < 1e-6 then dx, dy, l = g1.fx or 0, g1.fy or 1, 1 end
  dx, dy = dx / l, dy / l
  if kind == 'rolling' then
    back = back or 40
    return { x = g1.x - g1.fx * back, y = g1.y - g1.fy * back, z = g1.z }, { x = g1.fx, y = g1.fy }
  end
  return { x = g1.x, y = g1.y, z = g1.z }, { x = dx, y = dy }
end

-- gate line ends (perpendicular to the travel direction, width = 2 r)
function M.gateEnds(g)
  local rx, ry = g.fy, -g.fx
  return { x = g.x - rx * g.r, y = g.y - ry * g.r, z = g.z }, { x = g.x + rx * g.r, y = g.y + ry * g.r, z = g.z }
end

-- distance from point to segment a-b (2D)
function M.distToSegment(px, py, a, b)
  local ex, ey = b.x - a.x, b.y - a.y
  local l2 = ex * ex + ey * ey
  local f = l2 > 1e-9 and math.max(0, math.min(1, ((px - a.x) * ex + (py - a.y) * ey) / l2)) or 0
  return v2len(px - (a.x + ex * f), py - (a.y + ey * f))
end

-- polyline points for the time estimate (local metres not needed: the
-- estimator only uses distances and corner radii)
function M.estimatePoints(gates, standing)
  local pts = {}
  for i, g in ipairs(gates) do pts[#pts + 1] = { x = g.x, y = g.y, vmax = (i == 1 and standing) and 0 or nil } end
  return pts
end

function M.describe(course, gates)
  local len = 0
  for i = 2, #gates do len = len + v2len(gates[i].x - gates[i - 1].x, gates[i].y - gates[i - 1].y) end
  return string.format('%d Tore, etwa %.1f km', #gates, len / 1000), len
end

return M
