-- Turismo Karriere - IMGUI fallback hub
-- A plain but complete menu drawn with BeamNG's ImGui bindings. It is used
-- when the CEF app is not shown (e.g. UI layout without the app, or for
-- debugging) and talks to exactly the same handlers as the CEF UI.
-- Toggle: Tastenbelegung "Turismo: Notfall-Menü" or console
--   extensions.turismo_imguiHub.toggle()

local M = {}

local visible = false
local im -- ui_imgui, resolved lazily
local ffi = rawget(_G, 'ffi') or (pcall(require, 'ffi') and require('ffi'))

local cache = {}       -- action -> {t, data}
local lastMessage = nil
local nameBuf, openPtr
local selectedHall = nil

local function X(name) return extensions['turismo_' .. name] end
local function U() return extensions.turismo_util end

function M.toggle() visible = not visible end
function M.show(v) visible = v and true or false end
function M.isVisible() return visible end

-- cached handler call, refreshed every `ttl` seconds or on demand
local function get(action, args, ttl)
  local key = action .. tostring(args and (args.carId or args.brand) or '')
  local c = cache[key]
  local now = os.clock()
  if c and (now - c.t) < (ttl or 2) then return c.data end
  local ok, data = X('core').call(action, args)
  cache[key] = { t = now, data = ok and data or nil }
  if not ok then lastMessage = tostring(data) end
  return cache[key].data
end

local function run(action, args)
  local ok, data = X('core').call(action, args)
  cache = {}
  lastMessage = ok and ('OK: ' .. action) or ('Fehler: ' .. tostring(data))
  return ok, data
end

local function money(v) return U().formatMoney(v or 0) end
local function fmtTime(v) return v and U().formatTime(v) or '--' end

local function medalColor(m)
  if m == 'gold' then return im.ImVec4(1, 0.82, 0.2, 1) end
  if m == 'silver' then return im.ImVec4(0.8, 0.85, 0.9, 1) end
  if m == 'bronze' then return im.ImVec4(0.8, 0.5, 0.25, 1) end
  return im.ImVec4(0.5, 0.5, 0.5, 1)
end

---------------------------------------------------------------------------
-- tabs
---------------------------------------------------------------------------
local function tabProfile()
  local S = X('save')
  if S.isLoaded() then
    local st = X('core').snapshotState()
    im.Text(string.format('Fahrer: %s   Tag %d   %s', st.meta.playerName or '?', st.day or 1, money(st.money)))
    im.Text(string.format('Sammlerstufe %d   Fahrzeuge: %d   Tickets: %d', st.collector.level or 0, st.carCount or 0, st.tickets or 0))
    im.Text('Lizenzen: ' .. (#st.licenses > 0 and table.concat(st.licenses, ', ') or 'keine'))
    if st.activeCar then im.Text('Aktives Auto: ' .. (st.activeCar.name or '?') .. '  LI ' .. tostring(st.activeCar.effectiveLI or '?')) end
    if st.cafe then im.Text(string.format('Café-Heft: %s (%d/%d)', st.cafe.name, st.cafe.done, st.cafe.total)) end
    im.Text(string.format('Tagesziel: %.1f / %d km', st.dailyKm or 0, st.dailyGoal or 42))
    if im.Button('Speichern') then run('save') end
    im.Separator()
  end
  im.Text('Spielstände')
  local slots = get('getSlots', nil, 5) or {}
  for _, sl in ipairs(slots) do
    im.Text(string.format('Platz %d: %s', sl.slot, sl.exists and ((sl.playerName or '?') .. ' - ' .. money(sl.money) .. ', Tag ' .. tostring(sl.day)) or 'leer'))
    im.SameLine()
    if sl.exists then
      if im.Button('Laden##' .. sl.slot) then run('loadProfile', { slot = sl.slot }) end
    else
      if im.Button('Neu##' .. sl.slot) then
        local name = ffi and nameBuf and ffi.string(nameBuf) or 'Fahrer'
        run('newProfile', { slot = sl.slot, name = name ~= '' and name or 'Fahrer', difficulty = 'normal', progressionMode = 'menu', damageMode = 'realistic' })
      end
    end
  end
  if nameBuf then im.InputText('Name für neuen Spielstand', nameBuf, 32) end
end

local function tabGarage()
  local cars = get('garage') or {}
  if #cars == 0 then im.Text('Noch keine Fahrzeuge. Besuche einen Händler.') return end
  for _, c in ipairs(cars) do
    local label = string.format('%s%s  LI %s  %s km  Schaden %d%%  Wert %s', c.active and '> ' or '', c.nickname or c.name or c.key,
      tostring(c.effectiveLI or (c.rating and c.rating.li) or '?'), string.format('%.0f', c.mileageKm or 0),
      math.floor((c.damage or 0) * 100), money(c.value))
    im.Text(label)
    im.SameLine()
    if not c.active and im.Button('Fahren##' .. c.id) then run('setActiveCar', { carId = c.id }) end
    im.SameLine()
    if im.Button('Verkaufen##' .. c.id) then run('sellCar', { carId = c.id }) end
  end
end

local function tabWorkshop()
  local svc = get('services')
  if not svc then im.Text('Kein aktives Fahrzeug.') return end
  im.Text((svc.car.name or '?') .. '  -  Kilometerstand ' .. string.format('%.0f', svc.car.mileageKm or 0) .. ' km')
  local s = svc.summary or {}
  im.Text(string.format('Defekte Teile: %d   Beschädigt: %d   Motorverschleiß: %d%%   Öl: %d%%',
    s.brokenParts or 0, s.damagedParts or 0, math.floor((s.engineWear or 0) * 100), math.floor((s.oilAge or 0) * 100)))
  im.Separator()
  for _, q in ipairs(svc.quotes or {}) do
    im.Text(string.format('%-28s %s', q.name or q.id, money(q.price)))
    im.SameLine()
    if q.available ~= false and im.Button('Ausführen##' .. q.id) then run('service', { carId = svc.car.id, service = q.id }) end
  end
end

local function tabDealer()
  if im.CollapsingHeader1('Gebrauchtwagen') then
    for _, o in ipairs(get('usedOffers', nil, 10) or {}) do
      im.Text(string.format('%s  LI %s  %s km  %s', o.name, tostring(o.li), string.format('%.0f', o.mileageKm or 0), money(o.price)))
      im.SameLine()
      if im.Button('Kaufen##u' .. o.id) then run('buy', { kind = 'used', id = o.id }) end
    end
  end
  if im.CollapsingHeader1('Neuwagen') then
    for _, r in ipairs(get('dealerRegions', nil, 30) or {}) do
      for _, b in ipairs(r.brands or {}) do
        if im.TreeNode1(r.name .. ' / ' .. (b.name or b) .. '##' .. tostring(b.name or b)) then
          for _, o in ipairs(get('showroom', { brand = b.name or b }, 30) or {}) do
            im.Text(string.format('%s  LI %s  %s', o.name, tostring(o.li), money(o.price)))
            im.SameLine()
            if im.Button('Kaufen##n' .. o.key) then run('buy', { kind = 'new', id = o.key }) end
          end
          im.TreePop()
        end
      end
    end
  end
  if im.CollapsingHeader1('Legenden') then
    for _, o in ipairs(get('legendOffers', nil, 10) or {}) do
      im.Text(string.format('%s  %s', o.name, money(o.price)))
      im.SameLine()
      if im.Button('Kaufen##l' .. o.id) then run('buy', { kind = 'legend', id = o.id }) end
    end
  end
end

local function tabLicenses()
  for _, lic in ipairs(get('licenses') or {}) do
    local head = string.format('%s  %s (%d/%d, Gold %d)%s', lic.short or lic.id, lic.name, lic.done, lic.total, lic.gold, lic.owned and '  [erhalten]' or '')
    if im.CollapsingHeader1(head .. '##' .. lic.id) then
      if not lic.available then im.TextColored(im.ImVec4(1, 0.5, 0.4, 1), lic.reason or 'gesperrt') end
      for _, t in ipairs(lic.tests or {}) do
        im.TextColored(medalColor(t.medal), string.format('%s  %s  Bestzeit %s', t.medal ~= 'none' and t.medal or '-', t.name, t.scoring == 'score' and tostring(t.best or '--') or fmtTime(t.best)))
        if lic.available then
          im.SameLine()
          if im.Button('Start##' .. t.id) then run('startTest', { testId = t.id }) end
          im.SameLine()
          if im.Button('Demo##' .. t.id) then run('startTest', { testId = t.id, demo = true }) end
        end
      end
    end
  end
  if im.CollapsingHeader1('Trainings') then
    for _, t in ipairs(get('trainings') or {}) do
      im.TextColored(medalColor(t.medal), t.name)
      im.SameLine()
      if im.Button('Start##' .. t.id) then run('startTest', { testId = t.id }) end
    end
  end
end

local function tabEvents()
  local halls = get('events') or {}
  for _, h in ipairs(halls) do
    if im.Selectable1(h.name .. ' (' .. #h.series .. ')', selectedHall == h.id) then selectedHall = h.id end
  end
  im.Separator()
  for _, h in ipairs(halls) do
    if h.id == selectedHall then
      for _, s in ipairs(h.series) do
        if im.CollapsingHeader1(string.format('%s  [%s]%s##%s', s.name, s.type or 'circuit', s.won and '  *' or '', s.id)) then
          im.TextWrapped(s.desc or '')
          im.Text('Bedingung: ' .. (s.requirement or 'keine'))
          if not s.available then im.TextColored(im.ImVec4(1, 0.5, 0.4, 1), s.reason or 'gesperrt') end
          for _, r in ipairs(s.races or {}) do
            im.Text(string.format('  %d. %s - %s%s', r.idx, r.name or 'Rennen', r.track, r.trophy and ('  (P' .. tostring(r.trophy) .. ')') or ''))
            if s.available and #s.eligibleCars > 0 then
              im.SameLine()
              if im.Button('Start##' .. s.id .. r.idx) then run('startRace', { seriesId = s.id, raceIndex = r.idx }) end
            end
          end
          if s.available and #s.eligibleCars == 0 then im.TextColored(im.ImVec4(1, 0.7, 0.3, 1), 'Kein passendes Auto in der Garage.') end
        end
      end
    end
  end
end

local function tabCafe()
  local c = get('cafe') or {}
  im.Text(string.format('Abgeschlossene Hefte: %d', c.completedCount or 0))
  for _, b in ipairs(c.books or {}) do
    if b.status == 'active' or b.status == 'next' then
      im.Separator()
      im.Text(string.format('Heft %d: %s%s', b.number, b.name, b.status == 'next' and '  (neu)' or ''))
      im.TextWrapped(b.intro or '')
      for _, st in ipairs(b.steps or {}) do
        im.Text(string.format('%s %s (%s/%s)', st.done and '[x]' or '[ ]', st.label or '?', tostring(st.have), tostring(st.need)))
        if st.hint and not st.done then im.SameLine() im.TextColored(im.ImVec4(0.6, 0.6, 0.6, 1), st.hint) end
      end
      if b.status == 'next' and im.Button('Heft annehmen##' .. b.id) then run('cafeAccept', { bookId = b.id }) end
      if b.status == 'active' and b.done == b.total and im.Button('Heft abschließen##' .. b.id) then run('cafeComplete', { bookId = b.id }) end
    elseif b.status == 'done' then
      im.TextColored(im.ImVec4(0.5, 0.8, 0.5, 1), string.format('Heft %d: %s (erledigt)', b.number, b.name))
    end
  end
end

local function tabWorld()
  if im.Button('Freie Fahrt (Heimatkarte)') then run('freeDrive', {}) end
  for _, l in ipairs(get('levels', nil, 30) or {}) do
    im.Text(string.format('%s (%d Strecken)', l.level, l.tracks))
    im.SameLine()
    if im.Button('Fahren##' .. l.level) then run('freeDrive', { level = l.level }) end
  end
  im.Separator()
  im.Text('Streckenrekorder')
  local rs = get('recorderState', nil, 0.5)
  if rs then
    im.Text(string.format('Aufnahme: %s  Checkpoints %d  Startplätze %d', rs.name or '?', rs.cps or 0, rs.grid or 0))
    if im.Button('Checkpoint hier') then run('recorderCheckpoint', {}) end
    im.SameLine()
    if im.Button('Startplatz hier') then run('recorderGrid', {}) end
    im.SameLine()
    if im.Button('Speichern##rec') then run('recorderSave', {}) end
    im.SameLine()
    if im.Button('Abbrechen##rec') then run('recorderCancel', {}) end
  else
    if im.Button('Rundkurs aufnehmen') then run('recorderStart', { name = 'Eigene Strecke', closed = true }) end
    im.SameLine()
    if im.Button('Sprint aufnehmen') then run('recorderStart', { name = 'Eigener Sprint', closed = false }) end
  end
  im.Separator()
  if im.Button('Testgelände-Anker hier setzen') then run('calibrateVenue', { venueId = 'testgelaende' }) end
end

local function tabDiag()
  if im.Button('Neu einlesen (Autos, Strecken, Inhalte)') then run('rescan') end
  local d = get('diagnostics', nil, 10)
  if not d then return end
  im.Text(string.format('Version %s   Autos %d   Marken %d   Strecken %d   Karte %s', d.version, d.cars, d.brands, d.tracks, tostring(d.level)))
  im.Text('Datenprobleme: ' .. #d.problems)
  for _, p in ipairs(d.problems) do im.TextWrapped('  ' .. p) end
  im.Text('Nicht gefundene Strecken: ' .. #d.missingTracks)
  for _, p in ipairs(d.missingTracks) do im.TextWrapped('  ' .. p) end
end

local function activityBar()
  local a, n = X('core').activeActivity()
  if not a then return end
  im.TextColored(im.ImVec4(0.4, 0.9, 1, 1), 'Laufend: ' .. n)
  im.SameLine()
  if im.Button('Neustart') then run('raceRestart') end
  im.SameLine()
  if im.Button('Abbrechen') then run('raceAbort') end
  im.SameLine()
  if im.Button('Schließen') then run('raceClose') end
  im.Separator()
end

---------------------------------------------------------------------------
local TABS = {
  { 'Profil', tabProfile, false }, { 'Garage', tabGarage, true }, { 'Werkstatt', tabWorkshop, true },
  { 'Händler', tabDealer, true }, { 'Lizenzen', tabLicenses, true }, { 'Rennen', tabEvents, true },
  { 'Café', tabCafe, true }, { 'Welt', tabWorld, true }, { 'Diagnose', tabDiag, false },
}

function M.draw(dt)
  if not visible then return end
  im = im or rawget(_G, 'ui_imgui')
  if not im then return end
  if not openPtr then
    openPtr = im.BoolPtr(true)
    if ffi then nameBuf = im.ArrayChar(32, 'Fahrer') end
  end
  openPtr[0] = true
  im.SetNextWindowSize(im.ImVec2(760, 560), im.Cond_FirstUseEver)
  if im.Begin('Turismo Karriere (Notfall-Menü)', openPtr) then
    activityBar()
    if lastMessage then im.TextColored(im.ImVec4(0.9, 0.9, 0.5, 1), lastMessage) end
    if im.BeginTabBar('turismoTabs') then
      local loaded = X('save').isLoaded()
      for _, t in ipairs(TABS) do
        if (loaded or not t[3]) and im.BeginTabItem(t[1]) then
          local ok, err = pcall(t[2])
          if not ok then im.TextColored(im.ImVec4(1, 0.3, 0.3, 1), 'Fehler: ' .. tostring(err)) end
          im.EndTabItem()
        end
      end
      im.EndTabBar()
    end
  end
  im.End()
  if not openPtr[0] then visible = false end
end

return M
