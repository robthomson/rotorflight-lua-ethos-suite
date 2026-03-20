--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({showProgress = true})
local flightState = (rfsuite.shared and rfsuite.shared.flight) or assert(loadfile("shared/flight.lua"))()
local appRuntime = (rfsuite.shared and rfsuite.shared.app) or assert(loadfile("shared/app/runtime.lua"))()

local state = appRuntime.profileGovernorFlagsState
if not state then
    state = {
        activateWakeup = false,
        lastGovEnabled = nil,
        lastAdcVoltage = nil
    }
    appRuntime.profileGovernorFlagsState = state
end

local FIELD_FALLBACK_PRECOMP = 1
local FIELD_PID_SPOOLUP = 2
local FIELD_VOLTAGE_COMP = 3
local FIELD_DYN_MIN_THROTTLE = 4


local apidata = {
    api = {
        {id = 1, name = "GOVERNOR_PROFILE", enableDeltaCache = false, rebuildOnWrite = true},
    },    
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.profile_governor.fallback_precomp)@", mspapi = 1, apikey = "governor_flags->fallback_precomp", type = 1},
            {t = "@i18n(app.modules.profile_governor.pid_spoolup)@", mspapi = 1, apikey = "governor_flags->pid_spoolup", type = 1}, 
            {t = "@i18n(app.modules.profile_governor.voltage_comp)@", mspapi = 1, apikey = "governor_flags->voltage_comp", type = 1}, 
            {t = "@i18n(app.modules.profile_governor.dyn_min_throttle)@", mspapi = 1, apikey = "governor_flags->dyn_min_throttle", type = 1},
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    state.activateWakeup = true
end

local function setNavEnabled(id, enabled)
    local navFields = rfsuite.app and rfsuite.app.formNavigationFields
    local nav = navFields and navFields[id]
    if nav and nav.enable then nav:enable(enabled) end
end

local function setFieldEnabled(index, enabled)
    local fields = rfsuite.app and rfsuite.app.formFields
    local field = fields and fields[index]
    if field and field.enable then field:enable(enabled) end
end

local function canSave()
    local governorMode = flightState.getGovernorMode()
    local govEnabled = (governorMode ~= nil and governorMode ~= 0)
    if not govEnabled then return false end
    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    if pref == false or pref == "false" then return true end
    return rfsuite.app.pageDirty == true
end

local function wakeup()
    local governorMode
    local govEnabled
    local adcVoltage

    -- we are compromised if we don't have governor mode known
    governorMode = flightState.getGovernorMode()
    if governorMode == nil then
        pageRuntime.openMenuContext()
        return
    end

    local mspQueue = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
    if state.activateWakeup ~= true or not (mspQueue and mspQueue.isProcessed and mspQueue:isProcessed()) then
        return
    end

    local activeProfile = rfsuite.session and rfsuite.session.activeProfile
    if activeProfile ~= nil then
        local baseTitle = rfsuite.app.lastTitle or (rfsuite.app.Page and rfsuite.app.Page.title) or ""
        rfsuite.app.ui.setHeaderTitle(baseTitle .. " #" .. activeProfile, nil, rfsuite.app.Page and rfsuite.app.Page.navButtons)
    end

    -- Enable/disable fields based on firmware/session state.
    govEnabled = (governorMode ~= 0)
    adcVoltage = (rfsuite.session.batteryConfig ~= nil and rfsuite.session.batteryConfig.voltageMeterSource == 1)

    if state.lastGovEnabled ~= govEnabled then
        setNavEnabled("save", canSave())
        setNavEnabled("reload", govEnabled)
        state.lastGovEnabled = govEnabled
    end

    if not govEnabled then
        setFieldEnabled(FIELD_FALLBACK_PRECOMP, false)
        setFieldEnabled(FIELD_PID_SPOOLUP, false)
        setFieldEnabled(FIELD_VOLTAGE_COMP, false)
        setFieldEnabled(FIELD_DYN_MIN_THROTTLE, false)
        state.lastAdcVoltage = adcVoltage
        return
    end

    if state.lastGovEnabled ~= govEnabled or state.lastAdcVoltage ~= adcVoltage then
        setFieldEnabled(FIELD_FALLBACK_PRECOMP, true)
        setFieldEnabled(FIELD_PID_SPOOLUP, true)
        setFieldEnabled(FIELD_DYN_MIN_THROTTLE, true)
        setFieldEnabled(FIELD_VOLTAGE_COMP, adcVoltage)
        state.lastAdcVoltage = adcVoltage
    end
end

local function event(widget, category, value, x, y)
    return navHandlers.event(widget, category, value)
end

local function onNavMenu()
    return navHandlers.onNavMenu()
end

local function close()
    state.activateWakeup = false
    state.lastGovEnabled = nil
    state.lastAdcVoltage = nil
end

return {apidata = apidata, title = "@i18n(app.modules.profile_governor.name)@", reboot = false, event = event, onNavMenu = onNavMenu, refreshOnProfileChange = true, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, canSave = canSave, close = close, API = {}}
