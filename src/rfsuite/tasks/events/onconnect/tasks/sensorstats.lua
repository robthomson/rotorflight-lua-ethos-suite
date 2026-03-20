--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local connectionState = (rfsuite.shared and rfsuite.shared.connection) or assert(loadfile("shared/connection.lua"))()

local sensorstats = {}

local runOnce = false

function sensorstats.wakeup()

    if connectionState.getApiVersion() == nil then return end

    if connectionState.getMspBusy() then return end

    if rfsuite.tasks.telemetry then
        rfsuite.tasks.telemetry.sensorStats = {}
        runOnce = true
    end
end

function sensorstats.reset() runOnce = false end

function sensorstats.isComplete() return runOnce end

return sensorstats
