-- Smoke test: boots all modules against the mock and walks a career start.
package.path = 'tools/test/?.lua;' .. package.path
local H = dofile('tools/test/mock.lua')
H.boot{ root = os.getenv('PWD') .. '/mod', fixture = 'tools/test/fixture_vehicles.json', overlay = os.getenv('PWD') .. '/tools/test/fixture_root' }
H.verbose = os.getenv('VERBOSE') == '1'
extensions.load('turismo_core')
local C = extensions.turismo_core
local function call(a, args)
  local ok, d = C.call(a, args)
  if not ok then error(a .. ': ' .. tostring(d), 2) end
  return d
end
local J = H.json
print('== smoke')
H.test('vehicle db indexed', function()
  extensions.turismo_vehicleDb.rebuild()
  H.truthy(#extensions.turismo_vehicleDb.all() > 20, 'cars ' .. #extensions.turismo_vehicleDb.all())
end)
H.test('data validate', function()
  local p = extensions.turismo_data.validate()
  for _, x in ipairs(p) do print('     ' .. x) end
  H.eq(#p, 0, 'problems')
end)
H.test('new profile', function()
  local st = call('newProfile', { slot = 1, name = 'Alex', difficulty = 'normal', progressionMode = 'menu', damageMode = 'realistic' })
  H.eq(st.loaded, true) H.eq(st.money, 15000)
end)
for _, a in ipairs({ 'state', 'getSlots', 'garage', 'dealerRegions', 'usedOffers', 'legendOffers', 'licenses', 'trainings', 'events', 'cafe', 'tickets', 'levels', 'tracks', 'diagnostics' }) do
  H.test('handler ' .. a, function()
    local d = call(a, {})
    if os.getenv('DUMP') == a then print(J.encode(d)) end
  end)
end
H.test('buy used + garage + services', function()
  local offers = call('usedOffers')
  H.truthy(#offers > 0, 'no used offers')
  table.sort(offers, function(a, b) return a.price < b.price end)
  local car = call('buy', { kind = 'used', id = offers[1].id })
  local g = call('garage')
  H.eq(#g, 1)
  call('setActiveCar', { carId = g[1].id })
  local svc = call('services', { carId = g[1].id })
  H.truthy(#svc.quotes > 0)
  if os.getenv('DUMP') == 'services' then print(J.encode(svc)) print(J.encode(g)) print(J.encode(offers[1])) end
end)
H.test('showroom', function()
  local r = call('dealerRegions')
  local b = r[1].brands[1]
  local list = call('showroom', { brand = b.name or b })
  H.truthy(#list > 0)
  if os.getenv('DUMP') == 'showroom' then print(J.encode(r)) print(J.encode(list[1])) end
end)
H.test('cafe accept', function()
  local c = call('cafe')
  if os.getenv('DUMP') == 'cafe2' then print(J.encode(c)) end
end)
H.test('save roundtrip', function()
  call('save')
  call('loadProfile', { slot = 1 })
  H.eq(call('state').meta.playerName, 'Alex')
end)
print(string.format('== %d ok, %d failed', H.passed, H.failed))
for _, l in ipairs(H.logs) do if l:sub(1,1) == 'E' or l:sub(1,1) == 'W' then print('  log ' .. l) end end
os.exit(H.failed == 0 and 0 or 1)
