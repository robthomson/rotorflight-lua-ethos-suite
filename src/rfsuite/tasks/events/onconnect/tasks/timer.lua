--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local sharedTimer = (rfsuite.shared and rfsuite.shared.timer) or assert(loadfile("shared/timer.lua"))()
local connectionState = (rfsuite.shared and rfsuite.shared.connection) or assert(loadfile("shared/connection.lua"))()

local timer = {}

local runOnce = false

function timer.wakeup()

    if connectionState.getApiVersion() == nil then return end

    if connectionState.getMspBusy() then return end

    sharedTimer.reset(0)
    runOnce = true

end

function timer.reset() runOnce = false end

function timer.isComplete() return runOnce end

return timer
