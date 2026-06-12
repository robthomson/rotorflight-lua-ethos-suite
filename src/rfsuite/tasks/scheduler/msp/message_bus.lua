--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local type = type
local pairs = pairs
local pcall = pcall

local bus = {}
local handlers = {}
local owners = {}
local nextId = 0

local function wipe(tbl)
    for k in pairs(tbl) do
        tbl[k] = nil
    end
end

function bus.register(fn, owner)
    if type(fn) ~= "function" then return nil end

    nextId = nextId + 1
    handlers[nextId] = fn
    owners[nextId] = owner
    return nextId
end

function bus.release(id)
    if id == nil then return false end
    if handlers[id] == nil then return false end

    handlers[id] = nil
    owners[id] = nil
    return true
end

function bus.releaseOwner(owner)
    if owner == nil then return 0 end

    local removed = 0
    for id, registeredOwner in pairs(owners) do
        if registeredOwner == owner then
            handlers[id] = nil
            owners[id] = nil
            removed = removed + 1
        end
    end

    return removed
end

function bus.dispatch(id, ...)
    local fn = handlers[id]
    if fn == nil then return false, "missing_handler" end
    return pcall(fn, ...)
end

function bus.reset()
    wipe(handlers)
    wipe(owners)
    nextId = 0
end

function bus.count()
    local n = 0
    for _ in pairs(handlers) do
        n = n + 1
    end
    return n
end

return bus
