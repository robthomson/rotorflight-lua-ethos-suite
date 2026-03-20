--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local LIFECYCLE_SINGLETON_KEY = "rfsuite.shared.lifecycle"

if package.loaded[LIFECYCLE_SINGLETON_KEY] then
    return package.loaded[LIFECYCLE_SINGLETON_KEY]
end

local lifecycle = {
    clockSet = nil,
    resetSensors = false,
    resetMSPSensors = false,
    mspProtocolVersion = 1
}

function lifecycle.reset()
    lifecycle.clockSet = nil
    lifecycle.resetSensors = false
    lifecycle.resetMSPSensors = false
    lifecycle.mspProtocolVersion = 1
    return lifecycle
end

function lifecycle.getClockSet()
    return lifecycle.clockSet
end

function lifecycle.setClockSet(value)
    lifecycle.clockSet = value
    return value
end

function lifecycle.getResetSensors()
    return lifecycle.resetSensors == true
end

function lifecycle.setResetSensors(value)
    lifecycle.resetSensors = (value == true)
    return lifecycle.resetSensors
end

function lifecycle.getResetMSPSensors()
    return lifecycle.resetMSPSensors == true
end

function lifecycle.setResetMSPSensors(value)
    lifecycle.resetMSPSensors = (value == true)
    return lifecycle.resetMSPSensors
end

function lifecycle.getMspProtocolVersion()
    return lifecycle.mspProtocolVersion
end

function lifecycle.setMspProtocolVersion(value)
    lifecycle.mspProtocolVersion = tonumber(value) or 1
    return lifecycle.mspProtocolVersion
end

package.loaded[LIFECYCLE_SINGLETON_KEY] = lifecycle

return lifecycle
