-- Compatibility shim: canonical shared loader lives in shared/msp/api.lua.
return assert(loadfile("SCRIPTS:/" .. require("rfsuite").config.baseDir .. "/shared/msp/api.lua"))()
