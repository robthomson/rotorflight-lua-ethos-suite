--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local TOOLBOX_SINGLETON_KEY = "rfsuite.shared.toolbox"

if package.loaded[TOOLBOX_SINGLETON_KEY] then
    return package.loaded[TOOLBOX_SINGLETON_KEY]
end

local toolbox = {
    activeCount = 0,
    snapshot = {}
}

function toolbox.acquire()
    toolbox.activeCount = (toolbox.activeCount or 0) + 1
    return toolbox.snapshot
end

function toolbox.release()
    local snapshot = toolbox.snapshot
    local key

    toolbox.activeCount = math.max(0, (toolbox.activeCount or 0) - 1)
    if toolbox.activeCount > 0 then
        return snapshot
    end

    for key in pairs(snapshot) do
        snapshot[key] = nil
    end
    return snapshot
end

function toolbox.isActive()
    return (toolbox.activeCount or 0) > 0
end

function toolbox.getSnapshot()
    return toolbox.snapshot
end

function toolbox.get(key, default)
    local value = toolbox.snapshot[key]
    if value == nil then
        return default
    end
    return value
end

function toolbox.set(key, value)
    toolbox.snapshot[key] = value
    return value
end

function toolbox.clear()
    local snapshot = toolbox.snapshot
    local key
    for key in pairs(snapshot) do
        snapshot[key] = nil
    end
    return snapshot
end

package.loaded[TOOLBOX_SINGLETON_KEY] = toolbox

return toolbox
