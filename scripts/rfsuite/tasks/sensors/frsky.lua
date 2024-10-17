--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]]--
--
local arg = {...}
local config = arg[1]
local compile = arg[2]

local frsky = {}

-- create
local createSensorList = {}
createSensorList[0x5450] = {name = "Governor", unit = UNIT_RAW}
createSensorList[0x5110] = {name = "Adj. Source", unit = UNIT_RAW}
createSensorList[0x5111] = {name = "Adj. Value", unit = UNIT_RAW}
createSensorList[0x5460] = {name = "Model ID", unit = UNIT_RAW}
createSensorList[0x5471] = {name = "PID Profile", unit = UNIT_RAW}
createSensorList[0x5472] = {name = "Rate Profile", unit = UNIT_RAW}
createSensorList[0x5440] = {name = "Throttle %", unit = UNIT_RAW}
createSensorList[0x5250] = {name = "Consumption", unit = UNIT_MILLIAMPERE_HOUR}
createSensorList[0x5462] = {name = "Arm Status", unit = UNIT_RAW}

-- drop
local dropSensorList = {}
dropSensorList[0x0400] = {name = "Temp1", unit = UNIT_RAW}

-- rename
local renameSensorList = {}
renameSensorList[0x0500] = {name = "Head Speed", onlyifname = "RPM"}
renameSensorList[0x0501] = {name = "Tail Speed", onlyifname = "RPM"}

frsky.createSensorCache = {}
frsky.dropSensorCache = {}
frsky.renameSensorCache = {}

local function createSensor(physId, primId, appId, frameValue)

    -- check for custom sensors and create them if they dont exist
    if createSensorList[appId] ~= nil then

        local v = createSensorList[appId]

        if frsky.createSensorCache[appId] == nil then

            frsky.createSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky.createSensorCache[appId] == nil then

                print("Creating sensor: " .. v.name)

                frsky.createSensorCache[appId] = model.createSensor()
                frsky.createSensorCache[appId]:name(v.name)
                frsky.createSensorCache[appId]:appId(appId)
                frsky.createSensorCache[appId]:physId(physId)

                frsky.createSensorCache[appId]:minimum(min or -2147483647)
                frsky.createSensorCache[appId]:maximum(max or 2147483647)
                if v.unit ~= nil then
                    frsky.createSensorCache[appId]:unit(v.unit)
                    frsky.createSensorCache[appId]:protocolUnit(v.unit)
                end
                if v.minimum ~= nil then frsky.createSensorCache[appId]:minimum(v.minimum) end
                if v.maximum ~= nil then frsky.createSensorCache[appId]:maximum(v.maximum) end

            end

        end
    end

end

local function dropSensor(physId, primId, appId, frameValue)

    -- check for custom sensors and create them if they dont exist
    if dropSensorList[appId] ~= nil then
        local v = dropSensorList[appId]

        if frsky.dropSensorCache[appId] == nil then
            frsky.dropSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky.dropSensorCache[appId] ~= nil then
                print("Drop sensor: " .. v.name)
                frsky.dropSensorCache[appId]:drop()
            end

        end

    end

end

local function renameSensor(physId, primId, appId, frameValue)

    -- check for custom sensors and create them if they dont exist
    if renameSensorList[appId] ~= nil then
        local v = renameSensorList[appId]

        if frsky.renameSensorCache[appId] == nil then
            frsky.renameSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})


            if frsky.renameSensorCache[appId] ~= nil then
                if frsky.renameSensorCache[appId]:name() == v.onlyifname then      
                    print("Rename sensor: " .. v.name)
                    frsky.renameSensorCache[appId]:name(v.name)
                end
            end

        end

    end

end

local function telemetryPop()
    -- Pops a received SPORT packet from the queue. Please note that only packets using a data ID within 0x5000 to 0x50FF (frame ID == 0x10), as well as packets with a frame ID equal 0x32 (regardless of the data ID) will be passed to the LUA telemetry receive queue.
    local frame = rfsuite.bg.msp.sensor:popFrame()
    if frame == nil then return false end

    if not frame.physId or not frame.primId then return end

    createSensor(frame:physId(), frame:primId(), frame:appId(), frame:value())
    dropSensor(frame:physId(), frame:primId(), frame:appId(), frame:value())
    renameSensor(frame:physId(), frame:primId(), frame:appId(), frame:value())
    return true
end

function frsky.wakeup()

    -- flush sensor list if we kill the sensors
    if not rfsuite.bg.telemetry.active() or not rfsuite.rssiSensor then
        frsky.createSensorCache = {}
        frsky.renameSensorCache = {}
        frsky.dropSensorCache = {}
    end

    -- if gui or queue is busy.. do not do this!
    if rfsuite.bg and rfsuite.bg.telemetry and rfsuite.bg.telemetry.active() and rfsuite.rssiSensor then
        if rfsuite.app.guiIsRunning == false and rfsuite.bg.msp.mspQueue:isProcessed() then while telemetryPop() do end end
    end

end

return frsky
