--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local connectionState = (rfsuite.shared and rfsuite.shared.connection) or assert(loadfile("shared/connection.lua"))()
local lifecycleState = (rfsuite.shared and rfsuite.shared.lifecycle) or assert(loadfile("shared/lifecycle.lua"))()

local clocksync = {}
local API_NAME = "RTC"

local function clearApiEntry()
    local api = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if api and type(api.clearEntry) == "function" then
        api.clearEntry(API_NAME)
    end
end

function clocksync.wakeup()

    if connectionState.getApiVersion() == nil then return end

    if connectionState.getMspBusy() then return end

    if lifecycleState.getClockSet() == nil then

        local API = rfsuite.tasks.msp.api.load(API_NAME, 1)
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        API.setCompleteHandler(function(self, buf)
            lifecycleState.setClockSet(true)
            rfsuite.utils.log("Sync clock: " .. os.date("%c"), "info")
            rfsuite.utils.log("Sync clock: " .. os.date("%c"), "connect")
            clearApiEntry()
        end)
        API.setErrorHandler(function() clearApiEntry() end)
        API.setUUID("eaeb0028-219b-4cec-9f57-3c7f74dd49ac")
        API.setValue("seconds", os.time())
        API.setValue("milliseconds", 0)
        API.write()
    end

end

function clocksync.reset()
    clearApiEntry()
    lifecycleState.setClockSet(nil)
end

function clocksync.isComplete() if lifecycleState.getClockSet() ~= nil then return true end end

return clocksync
