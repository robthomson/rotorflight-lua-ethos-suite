--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local ACTIVELOOK_SINGLETON_KEY = "rfsuite.shared.activelook"

if package.loaded[ACTIVELOOK_SINGLETON_KEY] then
    return package.loaded[ACTIVELOOK_SINGLETON_KEY]
end

local activelook = {
    revision = 0
}

function activelook.markDirty()
    activelook.revision = (activelook.revision or 0) + 1
    return activelook.revision
end

function activelook.getRevision()
    return activelook.revision or 0
end

function activelook.reset()
    activelook.revision = 0
    return activelook.revision
end

package.loaded[ACTIVELOOK_SINGLETON_KEY] = activelook

return activelook
