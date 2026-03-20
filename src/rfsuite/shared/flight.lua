--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local FLIGHT_SINGLETON_KEY = "rfsuite.shared.flight"

if package.loaded[FLIGHT_SINGLETON_KEY] then
    return package.loaded[FLIGHT_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local math_floor = math.floor
local tonumber = tonumber

local flight = {
    governorMode = nil,
    tailMode = nil,
    swashMode = nil
}

local function normalize(value)
    value = tonumber(value)
    if value == nil then return nil end
    return math_floor(value)
end

local function syncSession(key, value)
    if rfsuite and rfsuite.session then
        rfsuite.session[key] = value
    end
end

function flight.getGovernorMode()
    if flight.governorMode == nil and rfsuite and rfsuite.session then
        flight.governorMode = normalize(rfsuite.session.governorMode)
    end
    return flight.governorMode
end

function flight.setGovernorMode(value)
    value = normalize(value)
    flight.governorMode = value
    syncSession("governorMode", value)
    return value
end

function flight.getTailMode()
    if flight.tailMode == nil and rfsuite and rfsuite.session then
        flight.tailMode = normalize(rfsuite.session.tailMode)
    end
    return flight.tailMode
end

function flight.getSwashMode()
    if flight.swashMode == nil and rfsuite and rfsuite.session then
        flight.swashMode = normalize(rfsuite.session.swashMode)
    end
    return flight.swashMode
end

function flight.setMixerConfig(tailMode, swashMode)
    local normalizedTail = normalize(tailMode)
    local normalizedSwash = normalize(swashMode)

    if tailMode ~= nil then
        flight.tailMode = normalizedTail
        syncSession("tailMode", normalizedTail)
    end

    if swashMode ~= nil then
        flight.swashMode = normalizedSwash
        syncSession("swashMode", normalizedSwash)
    end

    return flight.tailMode, flight.swashMode
end

function flight.reset()
    flight.governorMode = nil
    flight.tailMode = nil
    flight.swashMode = nil
    syncSession("governorMode", nil)
    syncSession("tailMode", nil)
    syncSession("swashMode", nil)
    return flight
end

package.loaded[FLIGHT_SINGLETON_KEY] = flight

return flight
