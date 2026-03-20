--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local BLACKBOX_CONFIG_SINGLETON_KEY = "rfsuite.shared.blackboxconfig"

if package.loaded[BLACKBOX_CONFIG_SINGLETON_KEY] then
    return package.loaded[BLACKBOX_CONFIG_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local blackboxConfig = {
    snapshot = {
        feature = nil,
        config = nil,
        media = nil,
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

local function syncSession()
    local session = rfsuite and rfsuite.session
    if not session then return end
    session.blackbox = blackboxConfig.snapshot
end

function blackboxConfig.getSnapshot()
    return blackboxConfig.snapshot
end

function blackboxConfig.setSnapshot(feature, config, media, ready)
    blackboxConfig.snapshot.feature = copyTable(feature)
    blackboxConfig.snapshot.config = copyTable(config)
    blackboxConfig.snapshot.media = copyTable(media)
    blackboxConfig.snapshot.ready = (ready == true)
    syncSession()
    return blackboxConfig.snapshot
end

function blackboxConfig.setConfig(config)
    blackboxConfig.snapshot.config = copyTable(config)
    syncSession()
    return blackboxConfig.snapshot.config
end

function blackboxConfig.setMedia(media)
    blackboxConfig.snapshot.media = copyTable(media)
    syncSession()
    return blackboxConfig.snapshot.media
end

function blackboxConfig.reset()
    blackboxConfig.snapshot.feature = nil
    blackboxConfig.snapshot.config = nil
    blackboxConfig.snapshot.media = nil
    blackboxConfig.snapshot.ready = false
    syncSession()
    return blackboxConfig
end

syncSession()
package.loaded[BLACKBOX_CONFIG_SINGLETON_KEY] = blackboxConfig

return blackboxConfig
