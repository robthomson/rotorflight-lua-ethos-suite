--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apiLoader = {}

apiLoader._fileExistsCache = apiLoader._fileExistsCache or {}

local apidir = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api/"
local api_path = apidir

local firstLoadAPI = true

local mspHelper
local utils
local callback

local function cached_file_exists(path)
    if apiLoader._fileExistsCache[path] == nil then apiLoader._fileExistsCache[path] = utils.file_exists(path) end
    return apiLoader._fileExistsCache[path]
end

local function loadAPI(apiName)

    local apiFilePath = api_path .. apiName .. ".lua"

    if firstLoadAPI then
        mspHelper = rfsuite.tasks.msp.mspHelper
        utils = rfsuite.utils
        callback = rfsuite.tasks.callback
        firstLoadAPI = false
    end

    if cached_file_exists(apiFilePath) then
        local apiModule = dofile(apiFilePath)

        if type(apiModule) == "table" and (apiModule.read or apiModule.write) then

            apiModule.__apiName = apiName

            if apiModule.read then
                local originalRead = apiModule.read
                apiModule.read = function(...) return originalRead(...) end
            end

            if apiModule.write then
                local originalWrite = apiModule.write
                apiModule.write = function(...) return originalWrite(...) end
            end

            if apiModule.setValue then
                local originalSetValue = apiModule.setValue
                apiModule.setValue = function(...) return originalSetValue(...) end
            end

            if apiModule.readValue then
                local originalReadValue = apiModule.readValue
                apiModule.readValue = function(...) return originalReadValue(...) end
            end

            utils.log("Loaded API: " .. apiName, "debug")
            return apiModule
        else
            utils.log("Error: API file '" .. apiName .. "' does not contain valid read or write functions.", "debug")
        end
    else
        utils.log("Error: API file '" .. apiFilePath .. "' not found.", "debug")
    end
end

function apiLoader.clearFileExistsCache() apiLoader._fileExistsCache = {} end

function apiLoader.load(apiName)
    local api = loadAPI(apiName)
    if api == nil then utils.log("Unable to load " .. apiName, "debug") end
    return api
end

return apiLoader
