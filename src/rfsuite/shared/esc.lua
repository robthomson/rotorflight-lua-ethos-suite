--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local ESC_SINGLETON_KEY = "rfsuite.shared.esc"

if package.loaded[ESC_SINGLETON_KEY] then
    return package.loaded[ESC_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local esc = {
    details = nil,
    buffer = nil,
    fourWay = {
        motorCount = nil,
        target = nil,
        selected = nil,
        set = nil,
        setComplete = nil,
        skipEntrySwitchOnce = nil
    }
}

local function clearTable(tbl)
    if type(tbl) ~= "table" then return end
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

function esc.getDetails()
    return esc.details
end

function esc.setDetails(value)
    esc.details = value
    return value
end

function esc.getBuffer()
    return esc.buffer
end

function esc.setBuffer(value)
    esc.buffer = value
    return value
end

function esc.clearReadCache()
    clearTable(esc.details)
    clearTable(esc.buffer)
    esc.details = nil
    esc.buffer = nil
    return esc
end

function esc.get4WayMotorCount()
    return esc.fourWay.motorCount
end

function esc.set4WayMotorCount(value)
    esc.fourWay.motorCount = value
    return value
end

function esc.get4WayTarget()
    return esc.fourWay.target
end

function esc.set4WayTarget(value)
    esc.fourWay.target = value
    return value
end

function esc.get4WaySelected()
    return esc.fourWay.selected
end

function esc.set4WaySelected(value)
    esc.fourWay.selected = value
    return value
end

function esc.get4WaySet()
    return esc.fourWay.set
end

function esc.set4WaySet(value)
    esc.fourWay.set = value
    return value
end

function esc.get4WaySetComplete()
    return esc.fourWay.setComplete
end

function esc.set4WaySetComplete(value)
    esc.fourWay.setComplete = value
    return value
end

function esc.get4WaySkipEntrySwitchOnce()
    return esc.fourWay.skipEntrySwitchOnce
end

function esc.set4WaySkipEntrySwitchOnce(value)
    esc.fourWay.skipEntrySwitchOnce = value
    return value
end

function esc.reset()
    esc.clearReadCache()
    esc.fourWay.motorCount = nil
    esc.fourWay.target = nil
    esc.fourWay.selected = nil
    esc.fourWay.set = nil
    esc.fourWay.setComplete = nil
    esc.fourWay.skipEntrySwitchOnce = nil
    return esc
end

package.loaded[ESC_SINGLETON_KEY] = esc

return esc
