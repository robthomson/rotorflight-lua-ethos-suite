--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local RX_SINGLETON_KEY = "rfsuite.shared.rx"

if package.loaded[RX_SINGLETON_KEY] then
    return package.loaded[RX_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local rx = {
    data = {
        map = {},
        values = {}
    }
}

local function clearTable(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

local function syncSession()
    local session = rfsuite and rfsuite.session
    if not session then return end
    session.rx = rx.data
end

function rx.get()
    return rx.data
end

function rx.getMap()
    return rx.data.map
end

function rx.getValues()
    return rx.data.values
end

function rx.setMapValue(key, value)
    rx.data.map[key] = value
    syncSession()
    return value
end

function rx.setValue(key, value)
    rx.data.values[key] = value
    syncSession()
    return value
end

function rx.clearMap()
    clearTable(rx.data.map)
    syncSession()
    return rx.data.map
end

function rx.clearValues()
    clearTable(rx.data.values)
    syncSession()
    return rx.data.values
end

function rx.reset()
    clearTable(rx.data.map)
    clearTable(rx.data.values)
    syncSession()
    return rx
end

syncSession()
package.loaded[RX_SINGLETON_KEY] = rx

return rx
