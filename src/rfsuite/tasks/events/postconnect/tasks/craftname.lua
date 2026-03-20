--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local connectionState = (rfsuite.shared and rfsuite.shared.connection) or assert(loadfile("shared/connection.lua"))()
local craftState = (rfsuite.shared and rfsuite.shared.craft) or assert(loadfile("shared/craft.lua"))()

local craftname = {}

local mspCallMade = false
local API_NAME = "NAME"

local function clearApiEntry()
    local api = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if api and type(api.clearEntry) == "function" then
        api.clearEntry(API_NAME)
    end
end

function craftname.wakeup()

    if connectionState.getApiVersion() == nil then return end

    if connectionState.getMspBusy() then return end

    if (craftState.getName() == nil) and (mspCallMade == false) then
        mspCallMade = true
        local API = rfsuite.tasks.msp.api.load(API_NAME)
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        API.setCompleteHandler(function(self, buf)
            local craftName = craftState.setName(API.readValue("name"))
            if rfsuite.preferences.general.syncname == true and model.name and craftName ~= nil then
                if not craftState.getOriginalModelName() then
                    craftState.setOriginalModelName(model.name())
                end
                rfsuite.utils.log("Setting model name to: " .. craftName, "info")
                model.name(craftName)
                lcd.invalidate()
            end
            if craftName and craftName ~= "" then
                rfsuite.utils.log("Craft name: " .. craftName, "info")
                rfsuite.utils.log("Craft name: " .. craftName, "connect")
            else
                craftState.setName(model.name())
            end
            clearApiEntry()
        end)
        API.setErrorHandler(function() clearApiEntry() end)
        API.setUUID("37163617-1486-4886-8b81-6a1dd6d7edd1")
        API.read()
    end

end

function craftname.reset()
    clearApiEntry()
    craftState.setName(nil)
    mspCallMade = false
end

function craftname.isComplete() if craftState.getName() ~= nil then return true end end

return craftname
