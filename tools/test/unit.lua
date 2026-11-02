-- Unit tests for the pure game logic (run from the project root: luajit tools/test/unit.lua)
local H = dofile('tools/test/mock.lua')
H.boot{ root = os.getenv('PWD') .. '/mod', fixture = 'tools/test/fixture_vehicles.json', overlay = os.getenv('PWD') .. '/tools/test/fixture_root' }
extensions.load('turismo_core')
local C = extensions.turismo_core
local VDB, R = extensions.turismo_vehicleDb, extensions.turismo_rating
VDB.rebuild()
local function call(a, args)
  local ok, d = C.call(a, args)
  if not ok then error(a .. ': ' .. tostring(d), 2) end
  return d
end
call('newProfile', { slot = 2, name = 'Test', difficulty = 'normal', progressionMode = 'menu', damageMode = 'realistic' })

print('== rating')
local function li(key) return VDB.get(key).rating.li end
H.test('LI ordering is plausible', function()
  H.truthy(li('piccolina/base') < li('covet/base_M'), 'piccolina < covet')
  H.truthy(li('covet/base_M') < li('covet/sport_M'), 'covet < covet sport')
  H.truthy(li('covet/sport_M') < li('sbr/base'), 'covet sport < sbr')
  H.truthy(li('sbr/base') < li('etkc/kc8'), 'sbr < kc8')
  H.truthy(li('etkc/kc8') < li('scintilla/base'), 'kc8 < scintilla')
  H.truthy(li('us_semi/base') < 300, 'semi is slow: ' .. li('us_semi/base'))
end)
H.test('LI range 100..1000 and classes', function()
  for _, info in ipairs(VDB.all()) do
    local r = info.rating
    H.truthy(r.li >= 100 and r.li <= 1000, info.key .. ' li ' .. r.li)
    H.truthy(r.class, info.key .. ' class')
  end
  local c = R.classOf(li('scintilla/base'))
  H.eq(type(c) == 'table' and (c.id or c.class) or c, VDB.get('scintilla/base').rating.class)
end)
H.test('categories', function()
  H.eq(VDB.get('us_semi/base').rating.category, 'truck')
  H.eq(VDB.get('sunburst/rally').rating.category, 'rally')
  H.eq(VDB.get('200bx/drift').rating.category, 'drift')
  H.eq(VDB.get('pickup/crawler').rating.category, 'offroad')
end)
H.test('effective LI drops with wear', function()
  local base = 500
  local worn = R.effectiveLI(base, { engineWear = 1, damage = 0.5, oilAge = 1 })
  H.truthy(worn < base, 'worn ' .. worn)
  H.eq(R.effectiveLI(base, { engineWear = 0, damage = 0, oilAge = 0 }), base)
end)

print('== vehicleDb')
H.test('criteria matching', function()
  local fwd = VDB.find({ drivetrains = { 'FWD' }, liMax = 450 })
  for _, i in ipairs(fwd) do H.eq(i.drivetrain, 'FWD') H.truthy(i.rating.li <= 450) end
  H.truthy(#fwd >= 4, 'fwd count ' .. #fwd)
  H.eq(#VDB.find({ brands = { 'Civetta' } }), 3)
  H.truthy(#VDB.find({ regions = { 'japan' } }) >= 8)
  H.truthy(VDB.describeCriteria({ liMax = 400, drivetrains = { 'RWD' } }):find('400'), 'description')
end)
H.test('pick is deterministic', function()
  local a = VDB.pick({ categories = { 'street' } }, 42)
  local b = VDB.pick({ categories = { 'street' } }, 42)
  H.eq(a.key, b.key)
end)

print('== condition')
local COND = extensions.turismo_condition
local pc = {
  engine = { integrityValue = 1, odometer = 150000 * 1000, visualValue = 1 },
  bumper_F = { integrityValue = 0, odometer = 150000 * 1000, visualValue = 0.4 },
  door_L = { integrityValue = 0.7, integrityState = { x = 1 }, odometer = 150000 * 1000, visualValue = 0.8 },
  hood = { integrityValue = 1, odometer = 150000 * 1000, visualValue = 1 },
}
H.test('summarize', function()
  local s = COND.summarize(pc, { oilKm = 0 })
  H.eq(s.brokenParts, 1) H.eq(s.damagedParts, 1)
  H.near(s.odometerKm, 150000, 1)
  H.truthy(s.damage > 0 and s.damage < 1)
  H.near(s.minVisual, 0.4, 1e-9)
end)
H.test('repair kinds', function()
  local q = COND.repaired(pc, 'quick')
  H.eq(q.bumper_F.integrityValue, 1) H.eq(q.door_L.integrityValue, 0.7)
  local f = COND.repaired(pc, 'full')
  H.eq(f.door_L.integrityValue, 1) H.eq(f.door_L.integrityState, nil)
  H.eq(pc.door_L.integrityValue, 0.7, 'original untouched')
  local e = COND.repaired(pc, 'engine')
  H.eq(e.engine.odometer, 0) H.eq(e.hood.odometer, 150000 * 1000)
  local p = COND.repaired(pc, 'paint')
  H.eq(p.bumper_F.visualValue, 1)
end)
H.test('repair quotes scale', function()
  local s = COND.summarize(pc, {})
  local cheap = COND.repairQuote(s, 10000, 'full')
  local dear = COND.repairQuote(s, 200000, 'full')
  H.truthy(dear > cheap * 3, cheap .. ' vs ' .. dear)
  H.eq(COND.repairQuote(COND.summarize({}, {}), 20000, 'quick'), 0)
end)

print('== licenses')
local LIC, D = extensions.turismo_licenses, extensions.turismo_data
H.test('every licence test has a car and targets', function()
  for _, lic in ipairs(D.get('licenses')) do
    for _, t in ipairs(lic.tests) do
      if not (t.car and t.car.rental == false) then
        H.truthy(LIC.testCar(t), 'car for ' .. t.id)
        local tg = LIC.targetsFor(t)
        H.truthy(tg.gold and tg.silver and tg.bronze, 'targets ' .. t.id)
        if t.scoring == 'score' then H.truthy(tg.gold > tg.silver and tg.silver > tg.bronze, 'order ' .. t.id)
        else H.truthy(tg.gold < tg.silver and tg.silver < tg.bronze, 'order ' .. t.id) end
        H.truthy(tg.gold > 3 and tg.gold < 900, t.id .. ' gold ' .. tg.gold)
      end
    end
  end
end)
H.test('medals and licence grant', function()
  local lic = D.license('L1')
  local paid0 = extensions.turismo_save.get().economy.money
  for _, t in ipairs(lic.tests) do
    local tg = LIC.targetsFor(t)
    local v = t.scoring == 'score' and tg.gold * 1.01 or tg.gold * 0.99
    local r = LIC.recordResult(t.id, v, false)
    H.eq(r.medal, 'gold', t.id)
  end
  H.truthy(LIC.has('L1'), 'L1 granted')
  H.truthy(extensions.turismo_save.get().economy.money > paid0, 'paid')
  -- a slower result never downgrades
  local t = lic.tests[1]
  local r = LIC.recordResult(t.id, LIC.targetsFor(t).bronze * 0.999, false)
  H.eq(r.medal, 'bronze') H.eq(r.reward, 0)
  H.eq(extensions.turismo_save.get().licenses.results[t.id].medal, 'gold')
end)

print('== tests geometry & estimator')
local T = extensions.turismo_tests
H.test('segmentsCross', function()
  H.truthy(T.segmentsCross(vec3(0, -1, 0), vec3(0, 1, 0), vec3(-1, 0, 0), vec3(1, 0, 0)))
  H.truthy(not T.segmentsCross(vec3(0, 1, 0), vec3(0, 2, 0), vec3(-1, 0, 0), vec3(1, 0, 0)))
end)
H.test('toWorld/toLocal roundtrip', function()
  local f = vec3(1, 1, 0):normalized()
  local anchor = { pos = vec3(100, 50, 3), fwd = { x = f.x, y = f.y }, right = { x = f.y, y = -f.x } }
  local w = T.toWorld(anchor, 3, 20)
  local lx, ly = T.toLocal(anchor, w.x, w.y)
  H.near(lx, 3, 1e-6) H.near(ly, 20, 1e-6)
end)
H.test('faster car estimates faster course time', function()
  local test = D.test('L1-03')
  local slow = T.estimateCourseTime(test, VDB.get('piccolina/base'))
  local fast = T.estimateCourseTime(test, VDB.get('sbr/base'))
  H.truthy(fast < slow, fast .. ' < ' .. slow)
end)

print('== drag')
local DR = extensions.turismo_drag
H.test('quarter mile estimates', function()
  local et, trap = DR.estimateQuarter(300, 1400, 'RWD')
  H.truthy(et > 12.5 and et < 15, 'et ' .. et)
  H.truthy(trap > 160 and trap < 190, 'trap ' .. trap)
  local et2 = DR.estimateQuarter(800, 1500, 'RWD')
  H.truthy(et2 < et and et2 > 9, 'et2 ' .. et2)
  local etAwd = DR.estimateQuarter(800, 1500, 'AWD')
  H.truthy(etAwd < et2, 'awd launches better')
end)

print('== AI')
local AI = extensions.turismo_aiDirector
H.test('skill tiers map to monotonic parameters', function()
  local prev
  for _, tier in ipairs({ 'rookie', 'amateur', 'pro', 'expert', 'legend' }) do
    local p = AI.resolveProfile({ tier = tier, style = 'smooth' }, 'normal')
    local aggr, params = AI.parametersFor(p)
    local par = { aggression = aggr, params = params }
    if prev then
      H.truthy(p.skill > prev.skill, tier .. ' skill')
      H.truthy(par.aggression >= prev.par.aggression, tier .. ' aggression')
    end
    prev = { skill = p.skill, par = par }
  end
end)
H.test('difficulty shifts skill', function()
  local e = AI.resolveProfile({ tier = 'pro' }, 'easy').skill
  local h = AI.resolveProfile({ tier = 'pro' }, 'hard').skill
  H.truthy(e < h)
end)
H.test('lap time model', function()
  local slow = AI.referenceLapTime(3000, 300)
  local fast = AI.referenceLapTime(3000, 800)
  H.truthy(fast < slow)
  local rng = extensions.turismo_util.rng(1)
  local rookie = AI.simulatedLapTime({ tier = 'rookie' }, 3000, 500, 1, rng, 'normal')
  local legend = AI.simulatedLapTime({ tier = 'legend' }, 3000, 500, 1, rng, 'normal')
  H.truthy(legend < rookie)
end)

print('== modes')
local MO = extensions.turismo_modes
H.test('drift scoring rewards angle and speed', function()
  local a = MO.driftStep(10, 15, 1, 1)
  local b = MO.driftStep(35, 25, 1, 1)
  H.truthy(b > a, a .. ' < ' .. b)
  H.eq(MO.driftStep(2, 30, 1, 1), 0, 'no points below min angle')
end)

print('== events & café')
local EV, G = extensions.turismo_events, extensions.turismo_garage
H.test('field generation respects size and LI window', function()
  local s = D.series('sonntagspokal')
  local field = EV.generateField(s, 7, 300)
  H.eq(#field, s.field.size)
  for _, f in ipairs(field) do H.truthy(f.carKey and f.driver, 'entry') end
end)
H.test('race result: prize, trophy, repeat third, championship points', function()
  local car = G.addCar('covet/base_M', { source = 'test' })
  G.setActive(car.id)
  local s = D.series('sonntagspokal')
  local m0 = extensions.turismo_save.get().economy.money
  local res = { list = { { pos = 1, isPlayer = true, name = 'Ich' }, { pos = 2, name = 'KI', driverId = 'd1' } }, cleanRace = true }
  local out = EV.onRaceFinished(s, 1, res, car.id)
  H.eq(out.position, 1)
  H.eq(out.money, s.rewards.positions[1])
  local m1 = extensions.turismo_save.get().economy.money
  H.truthy(m1 > m0)
  local out2 = EV.onRaceFinished(s, 1, res, car.id)
  H.eq(out2.money, math.floor(s.rewards.positions[1] / 3))
  -- championship
  local champ
  for _, x in ipairs(D.get('events')) do if x.championship then champ = x break end end
  H.truthy(champ, 'a championship exists')
  for i = 1, #champ.races do EV.onRaceFinished(champ, i, res, car.id) end
  local st = extensions.turismo_save.get().events.series[champ.id]
  H.truthy(st.season == 2 or st.done or st.won, 'season wrapped')
end)
H.test('café book 1 completes after buying a car', function()
  local snap = call('cafe')
  local cur = snap.books[1]
  H.eq(cur.status, 'active')
  local r = call('cafeComplete', { bookId = cur.id })
  H.truthy(r, 'completed')
  local snap2 = call('cafe')
  H.eq(snap2.books[1].status, 'done')
  H.eq(snap2.books[2].status, 'active', 'next book starts automatically')
  H.truthy(call('cafeAccept', { bookId = snap2.books[2].id }))
end)
H.test('trophies survive save/load', function()
  extensions.turismo_save.save()
  extensions.turismo_save.load(2)
  local halls = call('events')
  local found
  for _, h in ipairs(halls) do for _, s in ipairs(h.series) do if s.id == 'sonntagspokal' then found = s end end end
  H.eq(found.races[1].trophy, 1)
end)

print('== dealer & services')
H.test('repair flow charges and repairs', function()
  local car = G.addCar('sunburst/base_M', { source = 'test' })
  car.partConditions = pc
  local before = extensions.turismo_save.get().economy.money
  local ok, err = extensions.turismo_services.perform(car.id, 'fullRepair')
  H.truthy(ok, err)
  H.truthy(extensions.turismo_save.get().economy.money < before)
  H.eq(COND.summarize(car.partConditions, car).brokenParts, 0)
  local ok2 = extensions.turismo_services.perform(car.id, 'fullRepair')
  H.eq(ok2, false, 'nothing to repair any more')
end)
H.test('used offers are stable within a rotation window', function()
  local a = extensions.turismo_dealer.usedOffers()
  local b = extensions.turismo_dealer.usedOffers()
  H.eq(#a, #b) H.eq(a[1].id, b[1].id)
end)

H.section = H.section or function(n) print('== ' .. n) end
print('== 0.40 engine interface')
H.test('startSlots drops recovery points and puts the default first', function()
  local function sp(id, name, group, order) return { id = id, name = name, group = group, sortOrder = order } end
  local path = { defaultStartPosition = 3, startPositions = { sorted = {
    sp(1, 'Recovery 1', 'recovery', 1), sp(2, 'Grid 2', 'start', 2), sp(3, 'Grid 1', 'start', 3), sp(4, 'Old Recovery', nil, 4) } } }
  local s = extensions.turismo_util.startSlots(path)
  H.eq(#s, 2) H.eq(s[1].id, 3) H.eq(s[2].id, 2)
end)
H.test('script AI commands start at the car and resend aggression', function()
  local cmd = extensions.turismo_aiDirector.driveCommand({ script = { { x = 1, y = 2, z = 3 } }, aggression = 0.8, avoidCars = 'on', routeSpeed = 20 })
  H.truthy(cmd:find('obj:getFrontPosition()', 1, true))
  H.truthy(cmd:find('ai.setAggression(0.800)', 1, true))
  H.truthy(cmd:find('ai.setSpeedMode("limit")', 1, true))
  H.truthy(loadstring(cmd), 'command compiles')
  local nav = extensions.turismo_aiDirector.driveCommand({ wpTargetList = { 'a', 'b' }, aggression = 0.8 })
  H.truthy(nav:find('^ai.driveUsingPath%('))
end)

H.test('drag strips: 0.40 modular format and legacy format', function()
  local D = extensions.turismo_drag
  local a = D._readLanes('/levels/dragtest/dragstrips/main.dragData.json')
  H.eq(#a, 2) H.eq(a[1].stage.x, 0) H.eq(a[2].stage.x, 4)
  H.truthy(math.abs(a[1].length - 402.34) < 0.01)
  local b = D._readLanes('/levels/dragtest/legacy.dragData.json')
  H.eq(#b, 2) H.truthy(math.abs(b[2].length - 201.17) < 0.01)
end)

H.test('main menu entry: startCareer opens hub and registers pause button', function()
  local reg
  extensions.ui_pause_actions = { registerModButton = function(b) reg = b return { success = true } end }
  extensions.turismo_core.startCareer()
  H.eq(extensions.turismo_core.isHubVisible(), true)
  H.eq(reg and reg.tabId, 'mods')
  H.truthy(reg.componentName:find('turismo_karriere/PauseCard.vue', 1, true))
  extensions.turismo_core.setHubVisible(false)
  extensions.ui_pause_actions = nil
end)

print(string.format('== %d ok, %d failed', H.passed, H.failed))
for _, l in ipairs(H.logs) do if l:sub(1, 1) == 'E' then print('  log ' .. l) end end
os.exit(H.failed == 0 and 0 or 1)
