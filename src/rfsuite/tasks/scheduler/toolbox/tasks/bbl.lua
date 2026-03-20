--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local bbl = {}
local string_format = string.format
local sharedToolbox = (rfsuite.shared and rfsuite.shared.toolbox) or assert(loadfile("shared/toolbox.lua"))()
local blackboxState = (rfsuite.shared and rfsuite.shared.blackbox) or assert(loadfile("shared/blackbox.lua"))()

function bbl.wakeup()
    local totalSize = blackboxState.getTotalSize()
    local usedSize = blackboxState.getUsedSize()

    local displayValue
    local percentUsed
    if totalSize and usedSize then
        local usedMB = usedSize / (1024 * 1024)
        local totalMB = totalSize / (1024 * 1024)
        percentUsed = totalSize > 0 and (usedSize / totalSize) * 100 or 0

        local decimals = 1
        local transformedUsed = usedMB
        local transformedTotal = totalMB
        displayValue = string_format("%." .. decimals .. "f/%." .. decimals .. "f %s", transformedUsed, transformedTotal, "@i18n(app.modules.fblstatus.megabyte)@")
    else
        displayValue = "-"
        percentUsed = nil
    end

    sharedToolbox.set("bbl", displayValue)

end

return bbl
