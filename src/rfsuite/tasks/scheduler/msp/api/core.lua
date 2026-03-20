-- Compatibility shim: canonical core lives in shared/msp/api/core.lua.
return assert(loadfile("SCRIPTS:/" .. require("rfsuite").config.baseDir .. "/shared/msp/api/core.lua"))()
