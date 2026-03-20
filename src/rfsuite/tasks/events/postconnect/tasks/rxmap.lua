--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local connectionState = (rfsuite.shared and rfsuite.shared.connection) or assert(loadfile("shared/connection.lua"))()

local rxmap = {}

local mspCallMade = false
local API_NAME = "RX_MAP"
local RX_CHANNEL_KEYS = {"aileron", "elevator", "rudder", "collective", "throttle", "aux1", "aux2", "aux3"}

local function clearApiEntry()
    local api = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if api and type(api.clearEntry) == "function" then
        api.clearEntry(API_NAME)
    end
end

local function getRxMap()
    local session = rfsuite.session
    local rx = session and session.rx
    if not rx then return nil end
    rx.map = rx.map or {}
    return rx.map
end

local function clearTableInPlace(tbl)
    local key
    if type(tbl) ~= "table" then return end
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

function rxmap.wakeup()

    if connectionState.getApiVersion() == nil then return end

    if connectionState.getMspBusy() then return end

    if not rfsuite.utils.rxmapReady() and mspCallMade == false then
        mspCallMade = true
        local API = rfsuite.tasks.msp.api.load(API_NAME)
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        API.setCompleteHandler(function(self, buf)

            local aileron = API.readValue("aileron")
            local elevator = API.readValue("elevator")
            local rudder = API.readValue("rudder")
            local collective = API.readValue("collective")
            local throttle = API.readValue("throttle")
            local aux1 = API.readValue("aux1")
            local aux2 = API.readValue("aux2")
            local aux3 = API.readValue("aux3")
            local rxMap = getRxMap()

            if rxMap then
                rxMap.aileron = aileron
                rxMap.elevator = elevator
                rxMap.rudder = rudder
                rxMap.collective = collective
                rxMap.throttle = throttle
                rxMap.aux1 = aux1
                rxMap.aux2 = aux2
                rxMap.aux3 = aux3
            end

            rfsuite.utils.log("RX Map: Aileron: " .. aileron .. ", Elevator: " .. elevator .. ", Rudder: " .. rudder .. ", Collective: " .. collective .. ", Throttle: " .. throttle .. ", Aux1: " .. aux1 .. ", Aux2: " .. aux2 .. ", Aux3: " .. aux3, "info")
            rfsuite.utils.log("RX Map: Ail: " .. aileron .. ", Elev: " .. elevator .. ", Rud: " .. rudder .. ", Col: " .. collective .. ", Thr: " .. throttle , "connect")

            clearApiEntry()
        end)
        API.setErrorHandler(function() clearApiEntry() end)
        API.setUUID("b3e5c8a4-5f3e-4e2c-9f7d-2e7a1c4b8f21")
        API.read()
    end

end

function rxmap.reset()
    local session = rfsuite.session
    local rx = session and session.rx

    clearApiEntry()
    if rx and rx.map then
        for _, key in ipairs(RX_CHANNEL_KEYS) do
            rx.map[key] = nil
        end
    end
    if rx and rx.values then
        clearTableInPlace(rx.values)
    end
    mspCallMade = false
end

function rxmap.isComplete() return rfsuite.utils.rxmapReady() end

return rxmap
