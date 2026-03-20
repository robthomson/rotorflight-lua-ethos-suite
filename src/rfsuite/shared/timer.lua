--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local TIMER_SINGLETON_KEY = "rfsuite.shared.timer"

if package.loaded[TIMER_SINGLETON_KEY] then
    return package.loaded[TIMER_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local tonumber = tonumber

local timerState = {
    data = {
        start = nil,
        live = nil,
        lifetime = nil,
        session = 0,
        baseLifetime = 0
    },
    flightCounted = false
}

local function syncSession()
    if not (rfsuite and rfsuite.session) then return end
    rfsuite.session.timer = timerState.data
    rfsuite.session.flightCounted = timerState.flightCounted
end

function timerState.get()
    syncSession()
    return timerState.data
end

function timerState.reset(baseLifetime)
    local data = timerState.data
    data.start = nil
    data.live = 0
    data.lifetime = tonumber(baseLifetime) or 0
    data.session = 0
    data.baseLifetime = tonumber(baseLifetime) or 0
    timerState.flightCounted = false
    syncSession()
    return data
end

function timerState.getFlightCounted()
    return timerState.flightCounted == true
end

function timerState.setFlightCounted(value)
    timerState.flightCounted = (value == true)
    syncSession()
    return timerState.flightCounted
end

package.loaded[TIMER_SINGLETON_KEY] = timerState

return timerState
