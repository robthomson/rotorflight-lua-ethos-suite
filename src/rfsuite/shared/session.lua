--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local SESSION_SINGLETON_KEY = "rfsuite.shared.session"

if package.loaded[SESSION_SINGLETON_KEY] then
    return package.loaded[SESSION_SINGLETON_KEY]
end

local function deepCopy(value)
    local out
    local key
    local item

    if type(value) ~= "table" then
        return value
    end

    out = {}
    for key, item in pairs(value) do
        out[key] = deepCopy(item)
    end
    return out
end

local methods = {}

local session = {
    _data = {},
    _watchers = {}
}

function methods:set(key, value)
    local old = self._data[key]
    local watchers
    local i

    if old == value then
        return value
    end

    self._data[key] = value
    watchers = self._watchers[key]
    if watchers then
        for i = 1, #watchers do
            pcall(watchers[i], old, value)
        end
    end

    return value
end

function methods:get(key, default)
    local value = self._data[key]
    if value == nil then
        return default
    end
    return value
end

function methods:setMultiple(values)
    local key
    for key, value in pairs(values or {}) do
        self:set(key, value)
    end
end

function methods:clearKeys(keys)
    local i
    for i = 1, #(keys or {}) do
        self:set(keys[i], nil)
    end
end

function methods:watch(key, callback)
    local list
    if type(callback) ~= "function" then
        return
    end

    list = self._watchers[key]
    if not list then
        list = {}
        self._watchers[key] = list
    end
    list[#list + 1] = callback
end

function methods:unwatch(key, callback)
    local list = self._watchers[key]
    local i

    if not list then
        return
    end

    for i = #list, 1, -1 do
        if list[i] == callback then
            table.remove(list, i)
        end
    end
end

function methods:reset(defaults)
    local data = self._data
    local key

    for key in pairs(data) do
        data[key] = nil
    end

    for key, value in pairs(defaults or {}) do
        data[key] = deepCopy(value)
    end

    return self
end

function methods:clear()
    return self:reset(nil)
end

function methods:dump()
    return deepCopy(self._data)
end

local mt = {
    __index = function(self, key)
        local method = methods[key]
        if method ~= nil then
            return method
        end
        return self._data[key]
    end,
    __newindex = function(self, key, value)
        methods.set(self, key, value)
    end,
    __pairs = function(self)
        return next, self._data, nil
    end
}

session = setmetatable(session, mt)

package.loaded[SESSION_SINGLETON_KEY] = session

return session
