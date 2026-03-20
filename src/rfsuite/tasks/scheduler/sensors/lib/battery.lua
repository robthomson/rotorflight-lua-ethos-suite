--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local connectionState = (rfsuite.shared and rfsuite.shared.connection) or assert(loadfile("shared/connection.lua"))()
local batteryState = (rfsuite.shared and rfsuite.shared.battery) or assert(loadfile("shared/battery.lua"))()

local battery = {}
local log = rfsuite.utils.log

local mspCallMade = false

function battery.wakeup()

    if connectionState.getApiVersion() == nil then return end

    if connectionState.getMspBusy() then return end
    if rfsuite.tasks.msp.mspQueue:isProcessed() == false then return end

    if (not batteryState.hasConfig()) and mspCallMade == false then
        mspCallMade = true

        local API = rfsuite.tasks.msp.api.load("BATTERY_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local batteryCapacity = API.readValue("batteryCapacity")
            local batteryCellCount = API.readValue("batteryCellCount")
            local vbatwarningcellvoltage = API.readValue("vbatwarningcellvoltage") / 100
            local vbatmincellvoltage = API.readValue("vbatmincellvoltage") / 100
            local vbatmaxcellvoltage = API.readValue("vbatmaxcellvoltage") / 100
            local vbatfullcellvoltage = API.readValue("vbatfullcellvoltage") / 100
            local lvcPercentage = API.readValue("lvcPercentage")
            local consumptionWarningPercentage = API.readValue("consumptionWarningPercentage")
            local voltageMeterSource = API.readValue("voltageMeterSource")

            local profiles = {}
            for i = 0, 5 do
                local val = API.readValue("batteryCapacity_" .. i)
                if val then
                    profiles[i] = val
                end
            end

            batteryState.setAll({
                voltageMeterSource = voltageMeterSource,
                batteryCapacity = batteryCapacity,
                batteryCellCount = batteryCellCount,
                vbatwarningcellvoltage = vbatwarningcellvoltage,
                vbatmincellvoltage = vbatmincellvoltage,
                vbatmaxcellvoltage = vbatmaxcellvoltage,
                vbatfullcellvoltage = vbatfullcellvoltage,
                lvcPercentage = lvcPercentage,
                consumptionWarningPercentage = consumptionWarningPercentage
            }, profiles)

            log("Capacity: " .. batteryCapacity .. "mAh", "info")
            log("Cell Count: " .. batteryCellCount, "info")
            log("Warning Voltage: " .. vbatwarningcellvoltage .. "V", "info")
            log("Min Voltage: " .. vbatmincellvoltage .. "V", "info")
            log("Max Voltage: " .. vbatmaxcellvoltage .. "V", "info")
            log("Full Cell Voltage: " .. vbatfullcellvoltage .. "V", "info")
            log("LVC Percentage: " .. lvcPercentage .. "%", "info")
            log("Consumption Warning Percentage: " .. consumptionWarningPercentage .. "%", "info")
            log("Battery Config Complete", "info")

            log("Capacity: " .. batteryCapacity .. "mAh", "connect")
            log("Cell Count: " .. batteryCellCount, "connect")
            log("Warning Voltage: " .. vbatwarningcellvoltage .. "V", "connect")
            log("Min Voltage: " .. vbatmincellvoltage .. "V", "connect")
            log("Max Voltage: " .. vbatmaxcellvoltage .. "V", "connect")
            log("Full Cell Voltage: " .. vbatfullcellvoltage .. "V", "connect")
            log("LVC Percentage: " .. lvcPercentage .. "%", "connect")
            log("Consumption Warning Percentage: " .. consumptionWarningPercentage .. "%", "connect")
            

        end)

        API.setErrorHandler(function(self, err)
            log("Failed to read battery config via MSP: " .. err, "info")
            mspCallMade = false
        end)

        API.setUUID("a3f9c2b4-5d7e-4e8a-9c3b-2f6d8e7a1b2d")
        API.read()
    end

end

function battery.reset()
    batteryState.reset()
    mspCallMade = false
end

function battery.isComplete() if batteryState.hasConfig() then return true end end

return battery
