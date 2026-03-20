--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local STATUS_SINGLETON_KEY = "rfsuite.shared.msp.status"

if package.loaded[STATUS_SINGLETON_KEY] then
    return package.loaded[STATUS_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local os_clock = os.clock

local status = {
    message = nil,
    updatedAt = nil,
    last = nil,
    clearAt = nil,
    crcErrors = 0,
    timeouts = 0
}

function status.reset()
    status.message = nil
    status.updatedAt = nil
    status.last = nil
    status.clearAt = nil
    status.crcErrors = 0
    status.timeouts = 0
    return status
end

function status.setMessage(message)
    status.message = message
    status.updatedAt = os_clock()
    if message then
        status.last = message
        status.clearAt = nil
    end
    return message
end

function status.scheduleClear(delaySeconds)
    local delay = tonumber(delaySeconds) or 0
    if delay < 0 then delay = 0 end
    status.clearAt = os_clock() + delay
    return status.clearAt
end

function status.clearExpired(now)
    local at = status.clearAt
    local current = now or os_clock()
    if at and current >= at then
        status.message = nil
        status.clearAt = nil
        return true
    end
    return false
end

function status.incrementTimeout()
    status.timeouts = (status.timeouts or 0) + 1
    return status.timeouts
end

function status.resetTimeouts()
    status.timeouts = 0
    return status.timeouts
end

function status.incrementCrcError()
    status.crcErrors = (status.crcErrors or 0) + 1
    return status.crcErrors
end
package.loaded[STATUS_SINGLETON_KEY] = status

return status
