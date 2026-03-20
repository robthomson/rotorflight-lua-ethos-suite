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
    swashMode = nil,
    activeProfile = nil,
    activeProfileLast = nil,
    activeRateProfile = nil,
    activeRateProfileLast = nil,
    activeBatteryType = nil,
    activeBatteryTypeLast = nil
}

local function normalize(value)
    value = tonumber(value)
    if value == nil then return nil end
    return math_floor(value)
end

function flight.getGovernorMode()
    return flight.governorMode
end

function flight.setGovernorMode(value)
    value = normalize(value)
    flight.governorMode = value
    return value
end

function flight.getTailMode()
    return flight.tailMode
end

function flight.getSwashMode()
    return flight.swashMode
end

local function trackValue(currentKey, lastKey, value)
    local normalized = normalize(value)
    flight[lastKey] = flight[currentKey]
    flight[currentKey] = normalized
    return flight[currentKey], flight[lastKey]
end

function flight.getActiveProfile()
    return flight.activeProfile
end

function flight.getActiveProfileLast()
    return flight.activeProfileLast
end

function flight.trackActiveProfile(value)
    return trackValue("activeProfile", "activeProfileLast", value)
end

function flight.getActiveRateProfile()
    return flight.activeRateProfile
end

function flight.getActiveRateProfileLast()
    return flight.activeRateProfileLast
end

function flight.trackActiveRateProfile(value)
    return trackValue("activeRateProfile", "activeRateProfileLast", value)
end

function flight.getActiveBatteryType()
    return flight.activeBatteryType
end

function flight.getActiveBatteryTypeLast()
    return flight.activeBatteryTypeLast
end

function flight.trackActiveBatteryType(value)
    return trackValue("activeBatteryType", "activeBatteryTypeLast", value)
end

function flight.setActiveBatteryType(value)
    flight.activeBatteryType = normalize(value)
    return flight.activeBatteryType
end

function flight.setMixerConfig(tailMode, swashMode)
    local normalizedTail = normalize(tailMode)
    local normalizedSwash = normalize(swashMode)

    if tailMode ~= nil then
        flight.tailMode = normalizedTail
    end

    if swashMode ~= nil then
        flight.swashMode = normalizedSwash
    end

    return flight.tailMode, flight.swashMode
end

function flight.reset()
    flight.governorMode = nil
    flight.tailMode = nil
    flight.swashMode = nil
    flight.activeProfile = nil
    flight.activeProfileLast = nil
    flight.activeRateProfile = nil
    flight.activeRateProfileLast = nil
    flight.activeBatteryType = nil
    flight.activeBatteryTypeLast = nil
    return flight
end

package.loaded[FLIGHT_SINGLETON_KEY] = flight

return flight
