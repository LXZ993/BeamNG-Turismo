-- Plays a short career in the mock and dumps every UI handler result for the browser preview.
local H = dofile('tools/test/mock.lua')
H.boot{ root = os.getenv('PWD') .. '/mod', fixture = 'tools/test/fixture_vehicles.json', overlay = os.getenv('PWD') .. '/tools/test/fixture_root' }
extensions.load('turismo_core')
local C = extensions.turismo_core
extensions.turismo_vehicleDb.rebuild()
local function call(a, args) local ok, d = C.call(a, args) if not ok then error(a .. ': ' .. tostring(d)) end return d end
local out = { slotsEmpty = call('getSlots') }
call('newProfile', { slot = 1, name = 'Alex', difficulty = 'normal', progressionMode = 'menu', damageMode = 'realistic' })
local offers = call('usedOffers')
local pick
for _, o in ipairs(offers) do if o.key:find('covet') or o.key:find('200bx') then pick = o break end end
call('buy', { kind = 'used', id = (pick or offers[1]).id })
local g = call('garage')
call('setActiveCar', { carId = g[1].id })
call('cafeComplete', { bookId = 'h01' })
-- some licence results
local L = extensions.turismo_licenses
for i, t in ipairs(extensions.turismo_data.license('L1').tests) do
  local tg = L.targetsFor(t)
  if i <= 8 then L.recordResult(t.id, (i % 3 == 0) and tg.silver * 0.99 or tg.gold * 0.99) end
end
extensions.turismo_profile.grantTicket(2, 'Test')
extensions.turismo_garage.addCar('sunburst/sport_RS', { source = 'Preis' })
local car = extensions.turismo_garage.get(g[1].id)
car.partConditions = { engine = { integrityValue = 1, odometer = 1.6e8 }, bumper_F = { integrityValue = 0, odometer = 1.6e8, visualValue = 0.4 }, door_L = { integrityValue = 0.8, integrityState = {}, odometer = 1.6e8, visualValue = 0.7 } }
extensions.turismo_garage.updateSummary(car)
for _, a in ipairs({ 'state', 'getSlots', 'garage', 'dealerRegions', 'usedOffers', 'legendOffers', 'licenses', 'trainings', 'events', 'cafe', 'tickets', 'levels', 'tracks', 'diagnostics' }) do
  out[a] = call(a, {})
end
out.services = call('services', { carId = g[1].id })
out.conversions = call('conversions', { carId = g[1].id })
out.showroom = {}
for _, r in ipairs(out.dealerRegions) do for _, b in ipairs(r.brands) do out.showroom[b.name] = call('showroom', { brand = b.name }) end end
out.carDetails = call('carDetails', { carId = g[1].id })
local f = io.open('tools/ui-preview/mockdata.js', 'w')
f:write('window.TURISMO_MOCK = ' .. H.json.encode(out) .. ';\n')
f:close()
print('mock data written')
