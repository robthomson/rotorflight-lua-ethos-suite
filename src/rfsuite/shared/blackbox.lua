--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local BLACKBOX_SINGLETON_KEY = "rfsuite.shared.blackbox"

if package.loaded[BLACKBOX_SINGLETON_KEY] then
    return package.loaded[BLACKBOX_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local blackbox = {
    flags = nil,
    totalSize = nil,
    usedSize = nil
}

function blackbox.getFlags()
    return blackbox.flags
end

function blackbox.getTotalSize()
    return blackbox.totalSize
end

function blackbox.getUsedSize()
    return blackbox.usedSize
end

function blackbox.setFlags(value)
    blackbox.flags = value
    return value
end

function blackbox.setTotalSize(value)
    blackbox.totalSize = value
    return value
end

function blackbox.setUsedSize(value)
    blackbox.usedSize = value
    return value
end

function blackbox.setSummary(flags, totalSize, usedSize)
    blackbox.flags = flags
    blackbox.totalSize = totalSize
    blackbox.usedSize = usedSize
    return blackbox
end

function blackbox.reset()
    blackbox.flags = nil
    blackbox.totalSize = nil
    blackbox.usedSize = nil
    return blackbox
end

package.loaded[BLACKBOX_SINGLETON_KEY] = blackbox

return blackbox
