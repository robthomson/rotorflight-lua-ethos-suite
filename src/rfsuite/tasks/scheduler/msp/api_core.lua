--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

-- Compatibility shim: canonical core moved to shared/msp/api/core.lua.
return assert(loadfile("SCRIPTS:/" .. require("rfsuite").config.baseDir .. "/shared/msp/api/core.lua"))()
