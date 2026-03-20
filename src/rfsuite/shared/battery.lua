--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local BATTERY_SINGLETON_KEY = "rfsuite.shared.battery"

if package.loaded[BATTERY_SINGLETON_KEY] then
    return package.loaded[BATTERY_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local FIELD_KEYS = {
    "voltageMeterSource",
    "batteryCapacity",
    "batteryCellCount",
    "vbatwarningcellvoltage",
    "vbatmincellvoltage",
    "vbatmaxcellvoltage",
    "vbatfullcellvoltage",
    "lvcPercentage",
    "consumptionWarningPercentage"
}

local battery = {
    loaded = false,
    config = {
        profiles = {}
    }
}

local function clearProfiles(profiles)
    for k in pairs(profiles) do
        profiles[k] = nil
    end
end

local function ensureConfig()
    if battery.loaded ~= true then
        battery.loaded = true
    end
    return battery.config
end

function battery.get()
    return battery.loaded and battery.config or nil
end

function battery.hasConfig()
    return battery.loaded == true
end

function battery.getProfiles()
    local config = battery.get()
    return config and config.profiles or nil
end

function battery.getProfile(index)
    local profiles = battery.getProfiles()
    return profiles and profiles[index] or nil
end

function battery.getField(key)
    local config = battery.get()
    return config and config[key] or nil
end

function battery.setField(key, value)
    local config = ensureConfig()
    if key == "profiles" and type(value) == "table" then
        clearProfiles(config.profiles)
        for profileIndex, profileValue in pairs(value) do
            config.profiles[profileIndex] = profileValue
        end
    else
        config[key] = value
    end
    return value
end

function battery.setProfile(index, value)
    local config = ensureConfig()
    config.profiles[index] = value
    return value
end

function battery.setAll(values, profiles)
    local config = ensureConfig()

    for i = 1, #FIELD_KEYS do
        local key = FIELD_KEYS[i]
        if type(values) == "table" then
            config[key] = values[key]
        else
            config[key] = nil
        end
    end

    clearProfiles(config.profiles)
    if type(profiles) == "table" then
        for profileIndex, profileValue in pairs(profiles) do
            config.profiles[profileIndex] = profileValue
        end
    end

    return config
end

function battery.reset()
    local config = battery.config
    for i = 1, #FIELD_KEYS do
        config[FIELD_KEYS[i]] = nil
    end
    clearProfiles(config.profiles)
    battery.loaded = false
    return battery
end

package.loaded[BATTERY_SINGLETON_KEY] = battery

return battery
