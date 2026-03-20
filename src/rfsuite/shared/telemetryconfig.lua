--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local TELEMETRY_CONFIG_SINGLETON_KEY = "rfsuite.shared.telemetryconfig"

if package.loaded[TELEMETRY_CONFIG_SINGLETON_KEY] then
    return package.loaded[TELEMETRY_CONFIG_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local telemetryConfig = {
    loaded = false,
    slots = {}
}

local function clearSlots(target)
    for i = #target, 1, -1 do
        target[i] = nil
    end
end

local function syncSession()
    local session = rfsuite and rfsuite.session
    if not session then return end
    session.telemetryConfig = telemetryConfig.loaded and telemetryConfig.slots or nil
end

function telemetryConfig.get()
    return telemetryConfig.loaded and telemetryConfig.slots or nil
end

function telemetryConfig.hasConfig()
    return telemetryConfig.loaded == true
end

function telemetryConfig.replace(values)
    local target = telemetryConfig.slots
    telemetryConfig.loaded = true
    clearSlots(target)
    for i = 1, #(values or {}) do
        target[i] = values[i]
    end
    syncSession()
    return target
end

function telemetryConfig.reset()
    telemetryConfig.loaded = false
    clearSlots(telemetryConfig.slots)
    syncSession()
    return telemetryConfig
end

syncSession()
package.loaded[TELEMETRY_CONFIG_SINGLETON_KEY] = telemetryConfig

return telemetryConfig
