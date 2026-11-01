-- Turismo Karriere - audio
-- Sound effects and music are played by the Turismo UI app (HTML5 audio inside
-- BeamNG's UI, files in /ui/modules/apps/TurismoHub/audio/). Lua only sends
-- cues. If the UI is not available, a best-effort fallback plays sound effects
-- through Engine.Audio (file path playback, verify on install).

local M = {}

local function S() return extensions.turismo_save end

M.SFX_DIR = '/ui/modules/apps/TurismoHub/audio/sfx/'

-- logical cue -> file (without extension); the UI uses the same table
M.cues = {
  click = 'ui_click', hover = 'ui_hover', back = 'ui_back', confirm = 'ui_confirm', error = 'ui_error',
  open = 'ui_open', purchase = 'ui_purchase', money = 'ui_money', levelup = 'ui_levelup',
  count = 'race_count', race_go = 'race_go', race_intro = 'race_intro_sting', race_finish = 'race_finish',
  gate = 'test_gate', fail = 'test_fail', medal = 'test_medal', medal_gold = 'test_medal_gold',
  wash = 'svc_wash', repair = 'svc_repair', ticket = 'ui_ticket',
}

local uiAlive = false
function M.setUiAlive(v) uiAlive = v end

function M.play(cue)
  local file = M.cues[cue] or cue
  if guihooks then guihooks.trigger('TurismoSound', { cue = cue, file = file }) end
  local st = S() and S().get()
  if not uiAlive and st and st.settings and st.settings.luaAudioFallback and Engine and Engine.Audio then
    pcall(Engine.Audio.playOnce, 'AudioGui', M.SFX_DIR .. file .. '.ogg')
  end
end

-- context: 'title' | 'menu' | 'dealer' | 'race' | 'results' | 'license' | 'off'
function M.music(context)
  if guihooks then guihooks.trigger('TurismoMusic', { context = context }) end
end

return M
