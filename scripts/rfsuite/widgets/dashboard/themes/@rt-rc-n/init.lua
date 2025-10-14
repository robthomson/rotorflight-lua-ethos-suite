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
]] --
 local rfsuite = require("rfsuite")
  
-- Theme initialization table
local init = {
    name = "@RT-RC Nitro",                 -- Theme name
    preflight = "preflight.lua",     -- Script to run before takeoff
    inflight = "inflight.lua",       -- Script to run during flight
    postflight = "postflight.lua",   -- Script to run after landing
    configure   = "configure.lua",   -- Script to run for settings
    standalone = false,              -- If true, theme handles all rendering itself
}

return init