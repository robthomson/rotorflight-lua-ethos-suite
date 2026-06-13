--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = core
end

local osClock = os.clock
local sin = math.sin
local floor = math.floor

local function writeS32(v)
    if v < 0 then v = v + 0x100000000 end
    return {
        v % 256,
        floor(v / 256) % 256,
        floor(v / 65536) % 256,
        floor(v / 16777216) % 256
    }
end

local function simulatorResponse()
    return writeS32(floor(120 + sin(osClock() * 1.5) * 30))
end

return core.createReadOnlyAPI({
    name = "SONAR",
    readCmd = 58,
    fields = {
        "sonar", "S32"
    },
    simulatorResponseRead = simulatorResponse
})
