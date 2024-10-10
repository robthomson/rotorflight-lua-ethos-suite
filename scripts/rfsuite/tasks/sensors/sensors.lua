--
local arg = {...}
local config = arg[1]
local compile = arg[2]

local sensors = {}

sensors.elrs = assert(compile.loadScript(config.suiteDir .. "tasks/sensors/elrs.lua"))(config, compile)
sensors.frsky = assert(compile.loadScript(config.suiteDir .. "tasks/sensors/frsky.lua"))(config, compile)

function sensors.wakeup()

    -- we cant do anything if bg task not running
    if not rfsuite.bg.active() then return end

    if rfsuite.bg.msp.protocol.mspProtocol == "crsf" and config.enternalElrsSensors == true then sensors.elrs.wakeup() end

    if rfsuite.bg.msp.protocol.mspProtocol == "smartPort" and config.internalSportSensors == true then sensors.frsky.wakeup() end

end

return sensors
