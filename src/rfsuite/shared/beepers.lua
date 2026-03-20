--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local BEEPERS_SINGLETON_KEY = "rfsuite.shared.beepers"

if package.loaded[BEEPERS_SINGLETON_KEY] then
    return package.loaded[BEEPERS_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local beepers = {
    snapshot = {
        config = nil,
        ready = false
    }
}

local function copyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = type(v) == "table" and copyTable(v) or v
    end
    return dst
end

function beepers.getSnapshot()
    return beepers.snapshot
end

function beepers.getConfig()
    return beepers.snapshot.config
end

function beepers.isReady()
    return beepers.snapshot.ready == true
end

function beepers.setSnapshot(config, ready)
    beepers.snapshot.config = copyTable(config)
    beepers.snapshot.ready = (ready == true)
    return beepers.snapshot
end

function beepers.reset()
    beepers.snapshot.config = nil
    beepers.snapshot.ready = false
    return beepers
end

package.loaded[BEEPERS_SINGLETON_KEY] = beepers

return beepers
