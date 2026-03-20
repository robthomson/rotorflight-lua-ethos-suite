--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local API_SINGLETON_KEY = "rfsuite.shared.mspapi"

if package.loaded[API_SINGLETON_KEY] then
    return package.loaded[API_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local loadfile = loadfile
local table_insert = table.insert
local table_remove = table.remove
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local string_format = string.format

local utils = rfsuite.utils

local api = {}

api._fileExistsCache = {}
api._chunkCache = {}
api._chunkCacheOrder = {}
api._chunkCacheMax = 5
api._helpChunkCache = {}
api._helpChunkCacheOrder = {}
api._helpChunkCacheMax = 5
api._helpDataCache = {}
api._deltaCacheDefault = true
api._deltaCacheByApi = {}
api._ported = {}
api._store = nil
api.apidata = {}
api.retainedData = {}
api._core = nil
api._factory = nil

local defaultApiPath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/"
local defaultApiHelpPath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/apihelp/"
local defaultCorePath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/shared/msp/api/core.lua"
local defaultFactoryPath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/shared/msp/api/factory.lua"
local defaultStorePath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/shared/msp/store.lua"

local function ensureApidata()
    local d

    if not api._store then
        local storeLoader, err = loadfile(defaultStorePath)
        if storeLoader then
            api._store = storeLoader()
            rfsuite.shared = rfsuite.shared or {}
            rfsuite.shared.mspstore = api._store
        else
            utils.log("[mspstore] load failed: " .. tostring(err), "info")
        end
    end

    if api._store and api._store.getPage then
        api.apidata = api._store.getPage()
        api.retainedData = api._store.getRetained and api._store.getRetained() or api.retainedData
        return api.apidata
    end

    d = api.apidata
    d.values = d.values or {}
    d.structure = d.structure or {}
    d.receivedBytesCount = d.receivedBytesCount or {}
    d.receivedBytes = d.receivedBytes or {}
    d.positionmap = d.positionmap or {}
    d.other = d.other or {}
    d._lastReadMode = d._lastReadMode or {}
    d._lastWriteMode = d._lastWriteMode or {}
    return d
end

local function logApiIo(apiName, op, source)
    if not (utils and utils.log) then return end
    utils.log(
        string_format(
            "[msp] %s %s source=%s",
            tostring(op),
            tostring(apiName),
            tostring(source or "unknown")
        ),
        "info"
    )
end

local function normalizePath(value)
    if type(value) ~= "string" or value == "" then return nil end
    if value:sub(1, 8) == "SCRIPTS:/" then
        return value
    end
    return defaultApiPath .. value
end

local function resolvePath(apiName)
    return normalizePath(api._ported[apiName]) or (defaultApiPath .. apiName .. ".lua")
end

local function resolveHelpPath(apiName)
    if type(apiName) ~= "string" or apiName == "" then return nil end
    return defaultApiHelpPath .. apiName .. ".lua"
end

local function attachSharedApiObjects()
    local tasks = rfsuite and rfsuite.tasks
    local msp = tasks and tasks.msp

    ensureApidata()
    if msp then
        if api._core then
            msp.apicore = api._core
        end
        if api._factory then
            msp.apifactory = api._factory
        end
        msp.api = api
    end
end

local function ensureFactory()
    local factoryLoader
    local err
    local factory

    if api._factory then return api._factory end

    factoryLoader, err = loadfile(defaultFactoryPath)
    if not factoryLoader then
        utils.log("[api] factory compile failed: " .. tostring(err), "info")
        return nil
    end

    factory = factoryLoader()
    api._factory = factory
    attachSharedApiObjects()
    return factory
end

local function ensureCore()
    local coreLoader
    local err
    local core

    if api._core then return api._core end

    coreLoader, err = loadfile(defaultCorePath)
    if not coreLoader then
        utils.log("[api] core compile failed: " .. tostring(err), "info")
        return nil
    end

    core = coreLoader()
    api._core = core
    ensureFactory()
    attachSharedApiObjects()
    return core
end

local function cachedFileExists(path)
    if api._fileExistsCache[path] == nil then
        api._fileExistsCache[path] = utils.file_exists(path)
    end
    return api._fileExistsCache[path]
end

local function getChunk(apiName, path)
    local chunk = api._chunkCache[apiName]
    local i
    local loaderFn
    local err
    local oldest

    if chunk then
        for i, name in ipairs(api._chunkCacheOrder) do
            if name == apiName then
                table_remove(api._chunkCacheOrder, i)
                break
            end
        end
        table_insert(api._chunkCacheOrder, apiName)
        return chunk
    end

    loaderFn, err = loadfile(path)
    if not loaderFn then
        utils.log("[api] compile failed for " .. tostring(apiName) .. ": " .. tostring(err), "info")
        return nil
    end

    api._chunkCache[apiName] = loaderFn
    table_insert(api._chunkCacheOrder, apiName)

    if #api._chunkCacheOrder > api._chunkCacheMax then
        oldest = table_remove(api._chunkCacheOrder, 1)
        api._chunkCache[oldest] = nil
    end

    return loaderFn
end

local function getHelpChunk(apiName, path)
    local chunk = api._helpChunkCache[apiName]
    local i
    local loaderFn
    local err
    local oldest

    if chunk then
        for i, name in ipairs(api._helpChunkCacheOrder) do
            if name == apiName then
                table_remove(api._helpChunkCacheOrder, i)
                break
            end
        end
        table_insert(api._helpChunkCacheOrder, apiName)
        return chunk
    end

    loaderFn, err = loadfile(path)
    if not loaderFn then
        utils.log("[apihelp] compile failed for " .. tostring(apiName) .. ": " .. tostring(err), "info")
        return nil
    end

    api._helpChunkCache[apiName] = loaderFn
    table_insert(api._helpChunkCacheOrder, apiName)

    if #api._helpChunkCacheOrder > api._helpChunkCacheMax then
        oldest = table_remove(api._helpChunkCacheOrder, 1)
        api._helpChunkCache[oldest] = nil
    end

    return loaderFn
end

local function shouldLoadHelp(loadOpts)
    if type(loadOpts) == "table" and loadOpts.loadHelp ~= nil then
        return loadOpts.loadHelp == true
    end
    if type(loadOpts) == "boolean" then
        return loadOpts == true
    end
    return false
end

local function getHelpFields(apiName)
    local cached
    local helpPath
    local chunk
    local ok
    local helpData
    local fields

    if type(apiName) ~= "string" or apiName == "" then return nil end

    cached = api._helpDataCache[apiName]
    if cached ~= nil then
        return cached or nil
    end

    helpPath = resolveHelpPath(apiName)
    if not helpPath or not cachedFileExists(helpPath) then
        api._helpDataCache[apiName] = false
        return nil
    end

    chunk = getHelpChunk(apiName, helpPath)
    if not chunk then
        api._helpDataCache[apiName] = false
        return nil
    end

    ok, helpData = pcall(chunk)
    if not ok or type(helpData) ~= "table" then
        utils.log("[apihelp] invalid help data for " .. tostring(apiName), "info")
        api._helpDataCache[apiName] = false
        return nil
    end

    fields = type(helpData.fields) == "table" and helpData.fields or helpData
    if type(fields) ~= "table" then
        api._helpDataCache[apiName] = false
        return nil
    end

    api._helpDataCache[apiName] = fields
    return fields
end

local function injectHelpIntoStructure(apiName, structure)
    local helpFields

    if type(structure) ~= "table" then return end

    helpFields = getHelpFields(apiName)
    if type(helpFields) ~= "table" then return end

    for _, entry in ipairs(structure) do
        local fieldName
        local bitmap

        if type(entry) ~= "table" then
            goto continue
        end

        fieldName = entry.field
        if entry.help == nil and type(fieldName) == "string" then
            entry.help = helpFields[fieldName]
        end

        bitmap = entry.bitmap
        if type(bitmap) == "table" then
            for _, bit in ipairs(bitmap) do
                local bitName
                local composite

                if type(bit) == "table" then
                    bitName = bit.field
                    if bit.help == nil and type(bitName) == "string" then
                        composite = (type(fieldName) == "string") and (fieldName .. "->" .. bitName) or nil
                        bit.help = (composite and helpFields[composite]) or helpFields[bitName]
                    end
                end
            end
        end

        ::continue::
    end
end

local function validateModule(apiName, module)
    if type(module) ~= "table" then
        return nil, "module_not_table"
    end
    if not module.read and not module.write then
        return nil, "module_missing_read_write"
    end

    module.__apiName = apiName
    module.__apiSource = "shared"

    if module.read and not module.__rfWrappedRead then
        local original = module.read
        module.read = function(...)
            logApiIo(apiName, "read", "shared")
            return original(...)
        end
        module.__rfWrappedRead = true
    end

    if module.write and not module.__rfWrappedWrite then
        local original = module.write
        module.write = function(...)
            logApiIo(apiName, "write", "shared")
            return original(...)
        end
        module.__rfWrappedWrite = true
    end

    return module
end

function api.enableDeltaCache(enable)
    if enable == nil then return end
    api._deltaCacheDefault = (enable == true)
end

function api.setApiDeltaCache(apiName, enable)
    if type(apiName) ~= "string" or apiName == "" then return end
    if enable == nil then
        api._deltaCacheByApi[apiName] = nil
        return
    end
    api._deltaCacheByApi[apiName] = (enable == true)
end

function api.isDeltaCacheEnabled(apiName)
    local app
    if apiName and api._deltaCacheByApi[apiName] ~= nil then
        return api._deltaCacheByApi[apiName]
    end
    app = rfsuite and rfsuite.app
    if not (app and app.guiIsRunning) then
        return false
    end
    return api._deltaCacheDefault == true
end

function api.register(apiName, modulePath)
    if type(apiName) ~= "string" or apiName == "" then return false end
    if type(modulePath) ~= "string" or modulePath == "" then return false end
    api._ported[apiName] = modulePath
    api._chunkCache[apiName] = nil
    return true
end

function api.unregister(apiName)
    if type(apiName) ~= "string" or apiName == "" then return false end
    api._ported[apiName] = nil
    api._chunkCache[apiName] = nil
    return true
end

function api.isPorted(apiName)
    if type(apiName) ~= "string" or apiName == "" then return false end
    return cachedFileExists(resolvePath(apiName)) == true
end

function api.load(apiName, loadOpts)
    local path
    local chunk
    local apiModule
    local module
    local reason

    if type(apiName) ~= "string" or apiName == "" then
        utils.log("[api] invalid api name", "info")
        return nil
    end

    if not ensureCore() then
        utils.log("[api] core unavailable; cannot load " .. tostring(apiName), "info")
        return nil
    end

    path = resolvePath(apiName)
    if not cachedFileExists(path) then
        utils.log("[api] API file not found: " .. tostring(path), "info")
        return nil
    end

    chunk = getChunk(apiName, path)
    if not chunk then return nil end

    apiModule = chunk()
    if shouldLoadHelp(loadOpts) and type(apiModule) == "table" then
        injectHelpIntoStructure(apiName, apiModule.__rfReadStructure)
        if apiModule.__rfWriteStructure ~= apiModule.__rfReadStructure then
            injectHelpIntoStructure(apiName, apiModule.__rfWriteStructure)
        end
    end

    module, reason = validateModule(apiName, apiModule)
    if not module then
        utils.log("[api] invalid module for " .. tostring(apiName) .. ": " .. tostring(reason), "info")
        return nil
    end

    module.enableDeltaCache = function(enable) api.setApiDeltaCache(apiName, enable) end
    module.isDeltaCacheEnabled = function() return api.isDeltaCacheEnabled(apiName) end

    ensureApidata()
    attachSharedApiObjects()
    return module
end

function api.clearEntry(apiName)
    local d
    if type(apiName) ~= "string" or apiName == "" then return false end

    d = ensureApidata()
    if type(d) == "table" then
        if d.values then d.values[apiName] = nil end
        if d.structure then d.structure[apiName] = nil end
        if d.receivedBytes then d.receivedBytes[apiName] = nil end
        if d.receivedBytesCount then d.receivedBytesCount[apiName] = nil end
        if d.positionmap then d.positionmap[apiName] = nil end
        if d.other then d.other[apiName] = nil end
        if d._lastReadMode then d._lastReadMode[apiName] = nil end
        if d._lastWriteMode then d._lastWriteMode[apiName] = nil end
    end

    return true
end

function api.resetApidata()
    local d
    local k

    if api._store and api._store.resetPage then
        api._store.resetPage()
        api.apidata = api._store.getPage()
        return api.apidata
    end

    d = ensureApidata()
    if d.values then for k in pairs(d.values) do d.values[k] = nil end end
    if d.structure then for k in pairs(d.structure) do d.structure[k] = nil end end
    if d.receivedBytesCount then for k in pairs(d.receivedBytesCount) do d.receivedBytesCount[k] = nil end end
    if d.receivedBytes then for k in pairs(d.receivedBytes) do d.receivedBytes[k] = nil end end
    if d.positionmap then for k in pairs(d.positionmap) do d.positionmap[k] = nil end end
    if d.other then for k in pairs(d.other) do d.other[k] = nil end end
    if d._lastReadMode then for k in pairs(d._lastReadMode) do d._lastReadMode[k] = nil end end
    if d._lastWriteMode then for k in pairs(d._lastWriteMode) do d._lastWriteMode[k] = nil end end
    return d
end

function api.getPageData()
    return ensureApidata()
end

function api.getPageValues()
    local d = ensureApidata()
    return d and d.values or nil
end

function api.getPageStructure()
    local d = ensureApidata()
    return d and d.structure or nil
end

function api.setPageResult(apiName, data, cacheEnabled)
    local d = ensureApidata()

    if type(apiName) ~= "string" or apiName == "" or type(data) ~= "table" then
        return false
    end

    d.values[apiName] = data.parsed
    d.structure[apiName] = data.structure
    if cacheEnabled == true then
        d.receivedBytes[apiName] = data.buffer
        d.receivedBytesCount[apiName] = data.receivedBytesCount
        d.positionmap[apiName] = data.positionmap
    else
        d.receivedBytes[apiName] = nil
        d.receivedBytesCount[apiName] = nil
        d.positionmap[apiName] = nil
    end
    d.other[apiName] = data.other or {}
    return true
end

function api.releaseAppMemory()
    api.resetApidata()
    api.clearHelpCache()
    api.clearChunkCache()
    api.clearFileExistsCache()
end

function api.getFieldHelp(apiName, fieldName)
    local helpFields
    if type(apiName) ~= "string" or apiName == "" then return nil end
    if type(fieldName) ~= "string" or fieldName == "" then return nil end

    helpFields = getHelpFields(apiName)
    if not helpFields then return nil end
    return helpFields[fieldName]
end

function api.clearChunkCache()
    api._chunkCache = {}
    api._chunkCacheOrder = {}
end

function api.clearHelpCache()
    api._helpChunkCache = {}
    api._helpChunkCacheOrder = {}
    api._helpDataCache = {}
end

function api.clearFileExistsCache()
    api._fileExistsCache = {}
end

rfsuite.shared = rfsuite.shared or {}
rfsuite.shared.mspapi = api
rfsuite.mspapi = api
api.ensureApidata = ensureApidata
ensureApidata()
package.loaded[API_SINGLETON_KEY] = api

return api
