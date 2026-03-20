--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local flightState = (rfsuite.shared and rfsuite.shared.flight) or assert(loadfile("shared/flight.lua"))()
local connectionState = (rfsuite.shared and rfsuite.shared.connection) or assert(loadfile("shared/connection.lua"))()

local prevConnectedState = nil
local initTime = os.clock()
local focused = false
local requestPending = false

return {
    onOpenPost = function()
        initTime = os.clock()
        focused = false
        requestPending = false
    end,
    onWakeup = function()
        if os.clock() - initTime < 0.25 then return end

        if flightState.getGovernorMode() == nil then
            if rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers then
                if requestPending then return end
                requestPending = true
                rfsuite.tasks.msp.helpers.governorMode(function(governorMode)
                    requestPending = false
                    rfsuite.utils.log("Received governor mode: " .. tostring(governorMode), "info")
                end)
            end
            return
        end

        local enabled = flightState.getGovernorMode() ~= 0
        if rfsuite.app.formFields then
            for i, v in pairs(rfsuite.app.formFields) do
                if v and v.enable then v:enable(enabled) end
            end
        end

        if enabled and not focused then
            focused = true
            local idx = tonumber(rfsuite.preferences.menulastselected["profile_governor"]) or 1
            local btn = rfsuite.app.formFields and rfsuite.app.formFields[idx] or nil
            if btn and btn.focus then btn:focus() end
        end

        rfsuite.app.triggers.closeProgressLoader = true

        local currState = connectionState.getConnected() and connectionState.getMcuId() and true or false
        if currState ~= prevConnectedState then
            if not currState and rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields["menu"] then
                rfsuite.app.formNavigationFields["menu"]:focus()
            end
            prevConnectedState = currState
        end
    end
}
