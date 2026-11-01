-- Turismo Karriere - vehicle-side drag racing AI
-- Loaded into an opponent car with: extensions.load("turismoDragAi")
-- GE side calls:
--   turismoDragAi.setup({target = {x,y,z}, launchThrottle = 0.75, slipLimit = 0.12, reaction = 0.45})
--   turismoDragAi.stage()   -- hold on the brake, pre-load throttle
--   turismoDragAi.go()      -- tree turned green: launch after the reaction delay
--   turismoDragAi.finish()  -- crossed the finish line: brake to a stop
--   turismoDragAi.reset()
-- Traction control: throttle is reduced when driven wheels spin faster than
-- (1 + slipLimit) x ground speed, like a driver feathering the pedal.

local M = {}

local cfg = { target = nil, launchThrottle = 0.75, slipLimit = 0.12, reaction = 0.45 }
local state = 'idle'
local timer = 0
local throttle = 0

local function inputs(t, b, pb, s)
  input.event('throttle', t, 1)
  input.event('brake', b, 1)
  input.event('parkingbrake', pb, 1)
  if s then input.event('steering', s, 1) end
end

function M.setup(c)
  for k, v in pairs(c or {}) do cfg[k] = v end
  if controller and controller.mainController and controller.mainController.setGearboxMode then
    pcall(controller.mainController.setGearboxMode, 'arcade')
  end
  if ai and ai.setMode then ai.setMode('disabled') end
end

function M.stage() state = 'staged' timer = 0 end

function M.go(reaction)
  if reaction then cfg.reaction = math.max(0, reaction) end
  state = 'reacting'
  timer = 0
end

function M.finish() if state == 'run' or state == 'reacting' then state = 'stopping' end end

function M.reset() state = 'idle' timer = 0 inputs(0, 0, 1, 0) end

function M.getState() return state end

local function steerToTarget()
  if not cfg.target then return 0 end
  local tp = vec3(cfg.target.x, cfg.target.y, 0)
  local p = obj:getPosition()
  local d = tp - vec3(p.x, p.y, 0)
  local dir = obj:getDirectionVector()
  dir = vec3(dir.x, dir.y, 0)
  if d:length() < 1 or dir:length() < 0.1 then return 0 end
  d:normalize() dir:normalize()
  local cross = dir.x * d.y - dir.y * d.x
  return math.max(-0.3, math.min(0.3, -cross * 2.5))
end

function M.updateGFX(dt)
  if state == 'idle' then return end
  timer = timer + dt
  local ev = electrics.values
  local speed = ev.airspeed or 0
  if state == 'staged' then
    -- footbrake on, throttle pre-load for the launch
    inputs(cfg.launchThrottle * 0.6, 1, 0, 0)
  elseif state == 'reacting' then
    inputs(cfg.launchThrottle * 0.6, 1, 0, 0)
    if timer >= cfg.reaction then state = 'run' timer = 0 throttle = cfg.launchThrottle end
  elseif state == 'run' then
    local wheel = ev.wheelspeed or speed
    local slip = speed > 1 and (wheel - speed) / speed or 0
    if slip > cfg.slipLimit then
      throttle = math.max(0.35, throttle - dt * 3)
    else
      throttle = math.min(1, throttle + dt * (timer < 1.5 and 1.2 or 3))
    end
    inputs(throttle, 0, 0, steerToTarget())
  elseif state == 'stopping' then
    inputs(0, 0.6, 0, steerToTarget())
    if speed < 1 then state = 'done' end
  elseif state == 'done' then
    inputs(0, 0, 1, 0)
  end
end

return M
