--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local connectionState = (rfsuite.shared and rfsuite.shared.connection) or assert(loadfile("shared/connection.lua"))()

local fcversion = {}

local mspCallMade = false
local API_NAME = "FC_VERSION"

local function clearApiEntry()
    local api = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if api and type(api.clearEntry) == "function" then
        api.clearEntry(API_NAME)
    end
end

function fcversion.wakeup()

    if connectionState.getApiVersion() == nil then return end
    if connectionState.getMspBusy() then return end

    if mspCallMade == false then

        mspCallMade = true

        local API = rfsuite.tasks.msp.api.load(API_NAME)
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        API.setCompleteHandler(function(self, buf)
            connectionState.setFcVersion(API.readVersion())
            connectionState.setRfVersion(API.readRfVersion())
            if connectionState.getFcVersion() then 
                rfsuite.utils.log("FC version: " .. connectionState.getFcVersion(), "info") 
                rfsuite.utils.log("FC version: " .. connectionState.getFcVersion(), "connect")
            end    
            clearApiEntry()
        end)
        API.setErrorHandler(function() clearApiEntry() end)
        API.setUUID("22a683cb-dj0e-439f-8d04-04687c9360fu")
        API.read()
    end
end

function fcversion.reset()
    clearApiEntry()
    connectionState.setFcVersion(nil)
    connectionState.setRfVersion(nil)
    mspCallMade = false
end

function fcversion.isComplete() if connectionState.getFcVersion() ~= nil then return true end end

return fcversion
