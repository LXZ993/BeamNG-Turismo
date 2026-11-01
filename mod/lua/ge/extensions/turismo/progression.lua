-- Turismo Karriere - progression
-- Central "is this part of the world open yet?" check.
--   progressionMode 'menu'    : features open through café booklets (guided, like a story)
--   progressionMode 'classic' : everything open from the start, only licences gate events
-- Keys: dealer_used, dealer_new, dealer_legend, tuning, services, license_<id>,
--       hall_<hallId>, series_<seriesId>, freeDrive, recorder

local M = {}

local function S() return extensions.turismo_save end
local function D() return extensions.turismo_data end

local function baseUnlocks()
  local eco = D().economy()
  local list = eco.baseUnlocks or { 'dealer_used', 'services', 'freeDrive', 'recorder', 'hall_einsteiger', 'license_L1' }
  local set = {}
  for _, k in ipairs(list) do set[k] = true end
  return set
end

function M.mode()
  local st = S().get()
  return st and st.meta.progressionMode or 'menu'
end

function M.isUnlocked(key, series)
  if not S().isLoaded() then return false end
  if M.mode() == 'classic' then return true end
  if baseUnlocks()[key] then return true end
  local cafe = extensions.turismo_cafe
  if cafe and cafe.isUnlocked(key) then return true end
  if series then
    if series.alwaysOpen then return true end
    local hallKey = 'hall_' .. (series.hall or '')
    if baseUnlocks()[hallKey] or (cafe and cafe.isUnlocked(hallKey)) then return true end
  end
  return false
end

-- for the hub menu tiles
function M.snapshot()
  local keys = { 'dealer_used', 'dealer_new', 'dealer_legend', 'tuning', 'services', 'freeDrive', 'recorder',
                 'hall_einsteiger', 'hall_amateur', 'hall_profi', 'hall_extrem', 'hall_langstrecke',
                 'hall_marken', 'hall_regional', 'hall_gelaende', 'hall_spezial',
                 'license_L1', 'license_L2', 'license_L3', 'license_L4', 'license_L5', 'license_R1', 'license_D1' }
  local res = {}
  for _, k in ipairs(keys) do res[k] = M.isUnlocked(k) end
  return res
end

return M
