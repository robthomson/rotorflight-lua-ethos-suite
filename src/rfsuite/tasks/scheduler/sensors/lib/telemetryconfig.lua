--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local connectionState = (rfsuite.shared and rfsuite.shared.connection) or assert(loadfile("shared/connection.lua"))()

local telemetryconfig = {}
local tonumber = tonumber
local tostring = tostring
local table_concat = table.concat
local log = rfsuite.utils.log

local mspCallMade = false

local function replaceTelemetryConfig(values)
    local session = rfsuite.session
    local target
    local i

    if not session then return end

    target = session.telemetryConfig
    if type(target) ~= "table" then
        target = {}
        session.telemetryConfig = target
    end

    for i = #target, 1, -1 do
        target[i] = nil
    end
    for i = 1, #(values or {}) do
        target[i] = values[i]
    end
end

function telemetryconfig.wakeup()

    if connectionState.getApiVersion() == nil then return end
    if connectionState.getMspBusy() then return end
    if rfsuite.tasks.msp.mspQueue:isProcessed() == false then return end

    if (rfsuite.session.telemetryConfig == nil) and (mspCallMade == false) then
        mspCallMade = true
        local API = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local data = API.data().parsed

            local slots = {}
            for i = 1, 40 do
                local key = "telem_sensor_slot_" .. i
                slots[i] = tonumber(data[key]) or 0
            end

            replaceTelemetryConfig(slots)

            local parts = {}
            for i, v in ipairs(slots) do 
                if v ~= 0 then 
                    parts[#parts + 1] = tostring(v) 
                end 
            end
            local slotsStr = table_concat(parts, ",")

            if log then 
                log("Updated telemetry sensors: " .. slotsStr, "info") 
                log("Updated telemetry sensors: " .. tostring(#parts) .. " of " .. tostring(#slots), "connect")
            end    
        end)
        API.setErrorHandler(function(self, err)
            log("Failed to read telemetry config via MSP: " .. err, "info")
            mspCallMade = false
        end)
        API.setUUID("38163617-1496-4886-8b81-6a1dd6d7ed81")
        API.setTimeout(3000)
        API.read()
    end

end

function telemetryconfig.reset()

    rfsuite.session.telemetryConfig = nil
    mspCallMade = false
end

function telemetryconfig.isComplete() 
    if rfsuite.session.telemetryConfig ~= nil then 
        return true 
    end 
end

return telemetryconfig
