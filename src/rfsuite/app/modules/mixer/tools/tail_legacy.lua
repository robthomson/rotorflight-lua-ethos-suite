--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local flightState = (rfsuite.shared and rfsuite.shared.flight) or assert(loadfile("shared/flight.lua"))()
local appRuntime = (rfsuite.shared and rfsuite.shared.app) or assert(loadfile("shared/app/runtime.lua"))()

local state = appRuntime.mixerLegacyTailState
if not state then
    state = {reloadPending = false}
    appRuntime.mixerLegacyTailState = state
end

local function getTailMode()
    return flightState.getTailMode()
end

local apidata = {
    api = {
        [1] = "MIXER_CONFIG"
    },
    formdata = {
        labels = {},
        fields = {
            {
                t = "@i18n(app.modules.trim.tail_motor_idle)@",
                mspapi = 1,
                apikey = "tail_motor_idle",
                enablefunction = function()
                    local tailMode = getTailMode()
                    return tailMode ~= nil and tailMode >= 1
                end
            },
            {
                t = "@i18n(app.modules.trim.yaw_trim)@",
                mspapi = 1,
                apikey = "tail_center_trim",
                enablefunction = function()
                    return getTailMode() == 0
                end
            },
            {t = "@i18n(app.modules.mixer.swash_tta_precomp)@", api = "MIXER_CONFIG:swash_tta_precomp"}
        }
    }
}

local function resolveTailModeFromPage()
    local mixerConfig = rfsuite.app and rfsuite.app.Page and rfsuite.app.Page.values and rfsuite.app.Page.values["MIXER_CONFIG"]
    local tailMode = mixerConfig and mixerConfig["tail_rotor_mode"]
    if tailMode == nil then return false end
    flightState.setMixerConfig(tailMode, nil)
    return true
end

local function postLoad()
    if getTailMode() == nil and resolveTailModeFromPage() then
        state.reloadPending = true
        rfsuite.app.triggers.reloadFull = true
        return
    end

    state.reloadPending = false
    rfsuite.app.triggers.closeProgressLoader = true
end

local function onNavMenu()
    pageRuntime.openMenuContext()
end

local function wakeup()
    if getTailMode() == nil then
        if resolveTailModeFromPage() then
            state.reloadPending = true
            rfsuite.app.triggers.reloadFull = true
        end
        return
    end

    state.reloadPending = false
end

local function close()
    state.reloadPending = false
end

return {wakeup = wakeup, postLoad = postLoad, apidata = apidata, eepromWrite = true, reboot = true, API = {}, onNavMenu = onNavMenu, close = close}
