--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local craftname = {}
local sharedToolbox = (rfsuite.shared and rfsuite.shared.toolbox) or assert(loadfile("shared/toolbox.lua"))()
local craftState = (rfsuite.shared and rfsuite.shared.craft) or assert(loadfile("shared/craft.lua"))()

function craftname.wakeup()
    sharedToolbox.set("craftname", craftState.getName() or model.name())
end

return craftname
