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

local function syncSession(key, value)
    if rfsuite and rfsuite.session then
        rfsuite.session[key] = value
    end
end

local function syncCurrentAndLast(currentKey, lastKey)
    syncSession(currentKey, flight[currentKey])
    syncSession(lastKey, flight[lastKey])
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

local function ensureTrackedValue(currentKey, lastKey)
    if flight[currentKey] == nil and rfsuite and rfsuite.session then
        flight[currentKey] = normalize(rfsuite.session[currentKey])
    end
    if flight[lastKey] == nil and rfsuite and rfsuite.session then
        flight[lastKey] = normalize(rfsuite.session[lastKey])
    end
end

local function trackValue(currentKey, lastKey, value)
    local normalized = normalize(value)
    ensureTrackedValue(currentKey, lastKey)
    flight[lastKey] = flight[currentKey]
    flight[currentKey] = normalized
    syncCurrentAndLast(currentKey, lastKey)
    return flight[currentKey], flight[lastKey]
end

function flight.getActiveProfile()
    ensureTrackedValue("activeProfile", "activeProfileLast")
    return flight.activeProfile
end

function flight.getActiveProfileLast()
    ensureTrackedValue("activeProfile", "activeProfileLast")
    return flight.activeProfileLast
end

function flight.trackActiveProfile(value)
    return trackValue("activeProfile", "activeProfileLast", value)
end

function flight.getActiveRateProfile()
    ensureTrackedValue("activeRateProfile", "activeRateProfileLast")
    return flight.activeRateProfile
end

function flight.getActiveRateProfileLast()
    ensureTrackedValue("activeRateProfile", "activeRateProfileLast")
    return flight.activeRateProfileLast
end

function flight.trackActiveRateProfile(value)
    return trackValue("activeRateProfile", "activeRateProfileLast", value)
end

function flight.getActiveBatteryType()
    ensureTrackedValue("activeBatteryType", "activeBatteryTypeLast")
    return flight.activeBatteryType
end

function flight.getActiveBatteryTypeLast()
    ensureTrackedValue("activeBatteryType", "activeBatteryTypeLast")
    return flight.activeBatteryTypeLast
end

function flight.trackActiveBatteryType(value)
    return trackValue("activeBatteryType", "activeBatteryTypeLast", value)
end

function flight.setActiveBatteryType(value)
    flight.activeBatteryType = normalize(value)
    syncSession("activeBatteryType", flight.activeBatteryType)
    return flight.activeBatteryType
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
    flight.activeProfile = nil
    flight.activeProfileLast = nil
    flight.activeRateProfile = nil
    flight.activeRateProfileLast = nil
    flight.activeBatteryType = nil
    flight.activeBatteryTypeLast = nil
    syncSession("governorMode", nil)
    syncSession("tailMode", nil)
    syncSession("swashMode", nil)
    syncSession("activeProfile", nil)
    syncSession("activeProfileLast", nil)
    syncSession("activeRateProfile", nil)
    syncSession("activeRateProfileLast", nil)
    syncSession("activeBatteryType", nil)
    syncSession("activeBatteryTypeLast", nil)
    return flight
end

package.loaded[FLIGHT_SINGLETON_KEY] = flight

return flight
