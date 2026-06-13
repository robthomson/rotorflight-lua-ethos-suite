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
local actions = {}
local contexts = {}
local contextOwners = {}
local nextId = 0
local nextContextId = 0

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

function bus.registerAction(name, fn)
    if type(name) ~= "string" or name == "" or type(fn) ~= "function" then return false end
    actions[name] = fn
    return true
end

function bus.createContext(data, owner)
    if type(data) ~= "table" then return nil end

    nextContextId = nextContextId + 1
    contexts[nextContextId] = data
    contextOwners[nextContextId] = owner
    return nextContextId
end

function bus.getContext(id)
    if id == nil then return nil end
    return contexts[id]
end

function bus.releaseContext(id)
    if id == nil then return false end
    if contexts[id] == nil then return false end

    contexts[id] = nil
    contextOwners[id] = nil
    return true
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

    for id, registeredOwner in pairs(contextOwners) do
        if registeredOwner == owner then
            contexts[id] = nil
            contextOwners[id] = nil
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

function bus.dispatchAction(name, contextId, ...)
    local fn = actions[name]
    if fn == nil then return false, "missing_action" end

    local context = contexts[contextId]
    if context == nil then return false, "missing_context" end

    return pcall(fn, context, ...)
end

function bus.reset()
    wipe(handlers)
    wipe(owners)
    wipe(contexts)
    wipe(contextOwners)
    nextId = 0
    nextContextId = 0
end

function bus.count()
    local n = 0
    for _ in pairs(handlers) do
        n = n + 1
    end
    return n
end

function bus.contextCount()
    local n = 0
    for _ in pairs(contexts) do
        n = n + 1
    end
    return n
end

return bus
