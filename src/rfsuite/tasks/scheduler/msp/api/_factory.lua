-- Compatibility shim: canonical factory lives in shared/msp/api/factory.lua.
return assert(loadfile("SCRIPTS:/" .. require("rfsuite").config.baseDir .. "/shared/msp/api/factory.lua"))()
