--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local SERVO_SINGLETON_KEY = "rfsuite.shared.servo"

if package.loaded[SERVO_SINGLETON_KEY] then
    return package.loaded[SERVO_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local servo = {
    count = nil,
    override = nil,
    busEnabled = nil
}

local function syncSession()
    local session = rfsuite and rfsuite.session
    if not session then return end
    session.servoCount = servo.count
    session.servoOverride = servo.override
    session.servoBusEnabled = servo.busEnabled
end

function servo.getCount()
    return servo.count
end

function servo.setCount(value)
    servo.count = value
    syncSession()
    return value
end

function servo.getOverride()
    return servo.override
end

function servo.setOverride(value)
    servo.override = value
    syncSession()
    return value
end

function servo.getBusEnabled()
    return servo.busEnabled
end

function servo.setBusEnabled(value)
    servo.busEnabled = value
    syncSession()
    return value
end

function servo.reset()
    servo.count = nil
    servo.override = nil
    servo.busEnabled = nil
    syncSession()
    return servo
end

syncSession()
package.loaded[SERVO_SINGLETON_KEY] = servo

return servo
