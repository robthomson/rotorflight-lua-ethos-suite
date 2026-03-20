--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local CONNECTION_SINGLETON_KEY = "rfsuite.shared.connection"

if package.loaded[CONNECTION_SINGLETON_KEY] then
    return package.loaded[CONNECTION_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local connection = {
    isConnected = false,
    telemetryState = nil,
    telemetrySensor = nil,
    telemetryModule = nil,
    telemetryType = nil,
    telemetryModuleNumber = nil,
    apiVersion = nil,
    apiVersionInvalid = nil,
    fcVersion = nil,
    rfVersion = nil,
    mcuId = nil,
    postConnectComplete = false,
    mspBusy = false,
    resetMSP = nil
}

local function syncSession()
    local session = rfsuite and rfsuite.session
    if not session then return end
    session.isConnected = connection.isConnected
    session.telemetryState = connection.telemetryState
    session.telemetrySensor = connection.telemetrySensor
    session.telemetryModule = connection.telemetryModule
    session.telemetryType = connection.telemetryType
    session.telemetryModuleNumber = connection.telemetryModuleNumber
    session.apiVersion = connection.apiVersion
    session.apiVersionInvalid = connection.apiVersionInvalid
    session.fcVersion = connection.fcVersion
    session.rfVersion = connection.rfVersion
    session.mcu_id = connection.mcuId
    session.postConnectComplete = connection.postConnectComplete
    session.mspBusy = connection.mspBusy
    session.resetMSP = connection.resetMSP
end

function connection.reset()
    connection.isConnected = false
    connection.telemetryState = nil
    connection.telemetrySensor = nil
    connection.telemetryModule = nil
    connection.telemetryType = nil
    connection.telemetryModuleNumber = nil
    connection.apiVersion = nil
    connection.apiVersionInvalid = nil
    connection.fcVersion = nil
    connection.rfVersion = nil
    connection.mcuId = nil
    connection.postConnectComplete = false
    connection.mspBusy = false
    connection.resetMSP = nil
    syncSession()
    return connection
end

function connection.getConnected()
    return connection.isConnected == true
end

function connection.setConnected(value)
    connection.isConnected = (value == true)
    syncSession()
    return connection.isConnected
end

function connection.setTelemetry(state, sensor, module, telemetryType, moduleNumber)
    connection.telemetryState = state
    connection.telemetrySensor = sensor
    connection.telemetryModule = module
    connection.telemetryType = telemetryType
    connection.telemetryModuleNumber = moduleNumber
    syncSession()
    return connection.telemetryState
end

function connection.clearTelemetry()
    connection.setTelemetry(nil, nil, nil, nil, nil)
end

function connection.isTelemetryActive()
    return connection.telemetryState == true
end

function connection.getTelemetrySensor()
    return connection.telemetrySensor
end

function connection.getTelemetryType()
    return connection.telemetryType
end

function connection.getTelemetryModuleNumber()
    return connection.telemetryModuleNumber
end

function connection.setApiVersion(value)
    connection.apiVersion = value
    syncSession()
    return connection.apiVersion
end

function connection.getApiVersion()
    return connection.apiVersion
end

function connection.setApiVersionInvalid(value)
    connection.apiVersionInvalid = value
    syncSession()
    return connection.apiVersionInvalid
end

function connection.getApiVersionInvalid()
    return connection.apiVersionInvalid
end

function connection.setFcVersion(value)
    connection.fcVersion = value
    syncSession()
    return connection.fcVersion
end

function connection.getFcVersion()
    return connection.fcVersion
end

function connection.setRfVersion(value)
    connection.rfVersion = value
    syncSession()
    return connection.rfVersion
end

function connection.getRfVersion()
    return connection.rfVersion
end

function connection.setMcuId(value)
    connection.mcuId = value
    syncSession()
    return connection.mcuId
end

function connection.getMcuId()
    return connection.mcuId
end

function connection.setPostConnectComplete(value)
    connection.postConnectComplete = (value == true)
    syncSession()
    return connection.postConnectComplete
end

function connection.getPostConnectComplete()
    return connection.postConnectComplete == true
end

function connection.setMspBusy(value)
    connection.mspBusy = (value == true)
    syncSession()
    return connection.mspBusy
end

function connection.getMspBusy()
    return connection.mspBusy == true
end

function connection.setResetMSP(value)
    connection.resetMSP = value
    syncSession()
    return connection.resetMSP
end

function connection.getResetMSP()
    return connection.resetMSP
end

syncSession()
package.loaded[CONNECTION_SINGLETON_KEY] = connection

return connection
