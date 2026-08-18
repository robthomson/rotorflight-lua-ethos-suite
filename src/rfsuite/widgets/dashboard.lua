-- This suite no longer registers its own dashboard widget -- the shared
-- `dashboard` package's own standalone widget (SCRIPTS:/dashboard) is now
-- the single dashboard widget on the radio, for every suite; see that
-- repo's own docs/dashboard-spec.md. Themes stay physically in this repo
-- (widgets/dashboard/themes/**, unchanged -- see widgets/dashboard/context.lua's
-- own header for why a thin shim still lives there) and the settings UI
-- (app/pages/settings_dashboard_settings.lua) still edits them from within
-- this suite's own app -- only the actual rendering widget moved out.
--
-- This file survives only to answer the shared widget's own toolbar
-- "launch_app" action (its "Setup" icon: open this suite's own full-screen
-- app) -- the one of its four actions that needs something only this
-- file has access to: systemToolHandle, handed to init() below by
-- main.lua. "reset_flight"/"erase_blackbox"/"battery_profile" are handled
-- independently by tasks/session.lua's own "dashboard.action" subscriber
-- (see its own header) -- not repeated here.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local ethosVersion = requireModule("lib/ethos_version.lua")

local systemToolHandle = nil

local function canOpenSystemTool()
  return systemToolHandle ~= nil
    and system
    and type(system.openPage) == "function"
    and ethosVersion.atLeast({26, 1, 0})
end

bus.subscribe("dashboard.action", function(payload)
  if type(payload) ~= "table" or payload.action ~= "launch_app" then return end
  if not canOpenSystemTool() then return end
  system.openPage({system = systemToolHandle})
end)

local function init(opts)
  opts = opts or {}
  systemToolHandle = opts.systemToolHandle
end

return {init = init}
