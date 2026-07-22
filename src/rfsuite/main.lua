--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html

  Entry point. This file is intentionally thin: it loads and initialises
  three completely independent subsystems and does nothing else. There is
  no shared `rfsuite` table, no `package.loaded.rfsuite` global, and this
  file never touches the internals of app/, widgets/, or tasks/.

    app/     - the system tool      (system.registerSystemTool)
    widgets/ - dashboard/ActiveLook (system.registerWidget/registerGlassesWidget)
    tasks/   - the background task  (system.registerTask)

  Each owns its own private state via closures. The only thing they are
  allowed to share is lib/bus.lua, a minimal publish/subscribe channel --
  never direct table access.

  All three subsystems register direct callbacks eagerly. This costs more
  startup RAM than lazy proxies, but avoids retained-RAM growth observed on
  device with the lazy callback layer.
]] --

-- Parsed by bin/package/build_package.py (MAIN_VERSION_RE/MAIN_SUFFIX_RE) to
-- derive the packaged manifest version; the suffix segment is rewritten
-- per-build. The literal name/shape of this table is load-bearing for that
-- regex. Keep this in sync with lib/build_info.lua's runtime-visible copy.
local version = {major = 2, minor = 3, revision = 1, suffix = ""}

local background_task = assert(loadfile("tasks/background.lua"))()
local system_tool = assert(loadfile("app/tool.lua"))()
local dashboard_widget = assert(loadfile("widgets/dashboard.lua"))()
local activelook_widget = nil

local function init()
  background_task.init()
  local systemToolHandle = system_tool.init()
  dashboard_widget.init({systemToolHandle = systemToolHandle})
  if system.registerGlassesWidget then
    activelook_widget = assert(loadfile("widgets/activelook.lua"))()
    activelook_widget.init()
  end
end

return {init = init}
