-- minimal JSON decoder/encoder for the offline test harness
local J = {}

local function skip(s, i)
  local _, e = s:find('^[ \n\r\t]*', i)
  return e + 1
end

local decodeValue

local function decodeString(s, i)
  local out, j = {}, i + 1
  while true do
    local c = s:sub(j, j)
    if c == '"' then return table.concat(out), j + 1 end
    if c == '\\' then
      local n = s:sub(j + 1, j + 1)
      local map = { b = '\b', f = '\f', n = '\n', r = '\r', t = '\t', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }
      if n == 'u' then
        local code = tonumber(s:sub(j + 2, j + 5), 16)
        if code < 0x80 then out[#out + 1] = string.char(code)
        elseif code < 0x800 then out[#out + 1] = string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)
        else out[#out + 1] = string.char(0xE0 + math.floor(code / 4096), 0x80 + math.floor(code / 64) % 64, 0x80 + code % 64) end
        j = j + 6
      else
        out[#out + 1] = map[n] or n
        j = j + 2
      end
    else
      out[#out + 1] = c
      j = j + 1
    end
  end
end

function decodeValue(s, i)
  i = skip(s, i)
  local c = s:sub(i, i)
  if c == '{' then
    local obj = {}
    i = skip(s, i + 1)
    if s:sub(i, i) == '}' then return obj, i + 1 end
    while true do
      local k
      k, i = decodeString(s, skip(s, i))
      i = skip(s, i)
      assert(s:sub(i, i) == ':', 'expected : at ' .. i)
      local v
      v, i = decodeValue(s, i + 1)
      obj[k] = v
      i = skip(s, i)
      local d = s:sub(i, i)
      if d == '}' then return obj, i + 1 end
      assert(d == ',', 'expected , at ' .. i)
      i = i + 1
    end
  elseif c == '[' then
    local arr = {}
    i = skip(s, i + 1)
    if s:sub(i, i) == ']' then return arr, i + 1 end
    while true do
      local v
      v, i = decodeValue(s, i)
      arr[#arr + 1] = v
      i = skip(s, i)
      local d = s:sub(i, i)
      if d == ']' then return arr, i + 1 end
      assert(d == ',', 'expected , at ' .. i)
      i = i + 1
    end
  elseif c == '"' then
    return decodeString(s, i)
  elseif s:sub(i, i + 3) == 'true' then return true, i + 4
  elseif s:sub(i, i + 4) == 'false' then return false, i + 5
  elseif s:sub(i, i + 3) == 'null' then return nil, i + 4
  else
    local num = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', i)
    assert(num and #num > 0, 'bad json at ' .. i .. ': ' .. s:sub(i, i + 20))
    return tonumber(num), i + #num
  end
end

function J.decode(s) return (decodeValue(s, 1)) end

local function isArray(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n == #t
end

function J.encode(v)
  local t = type(v)
  if t == 'table' then
    local parts = {}
    if isArray(v) and (#v > 0 or next(v) == nil) then
      for _, x in ipairs(v) do parts[#parts + 1] = J.encode(x) end
      return '[' .. table.concat(parts, ',') .. ']'
    end
    for k, x in pairs(v) do parts[#parts + 1] = string.format('%q', tostring(k)) .. ':' .. J.encode(x) end
    return '{' .. table.concat(parts, ',') .. '}'
  elseif t == 'string' then return string.format('%q', v)
  elseif t == 'nil' then return 'null'
  else return tostring(v) end
end

return J
