--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local CRAFT_SINGLETON_KEY = "rfsuite.shared.craft"

if package.loaded[CRAFT_SINGLETON_KEY] then
    return package.loaded[CRAFT_SINGLETON_KEY]
end

local craft = {
    name = nil,
    originalModelName = nil
}

function craft.getName()
    return craft.name
end

function craft.setName(value)
    craft.name = value
    return craft.name
end

function craft.getOriginalModelName()
    return craft.originalModelName
end

function craft.setOriginalModelName(value)
    craft.originalModelName = value
    return craft.originalModelName
end

function craft.reset()
    craft.name = nil
    craft.originalModelName = nil
    return craft
end

package.loaded[CRAFT_SINGLETON_KEY] = craft

return craft
