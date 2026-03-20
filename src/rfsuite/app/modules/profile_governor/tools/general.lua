--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({showProgress = true})
local flightState = (rfsuite.shared and rfsuite.shared.flight) or assert(loadfile("shared/flight.lua"))()
local appRuntime = (rfsuite.shared and rfsuite.shared.app) or assert(loadfile("shared/app/runtime.lua"))()

local state = appRuntime.profileGovernorGeneralState
if not state then
    state = {
        activateWakeup = false,
        governorDisabled = false,
        txPrecompCurve = nil
    }
    appRuntime.profileGovernorGeneralState = state
end

local FIELD_F_GAIN = 9
local FIELD_YAW_WEIGHT = 10
local FIELD_CYCLIC_WEIGHT = 11
local FIELD_COLLECTIVE_WEIGHT = 12
local apidata

local function getApiEntryName(entry)
    if type(entry) == "table" then return entry.name end
    return entry
end

local function getGovernorMode()
    return flightState.getGovernorMode()
end

local function getGovernorFlags()
    local api = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    local apiName = getApiEntryName(apidata and apidata.api and apidata.api[1]) or "GOVERNOR_PROFILE"
    local governorProfile = api and api.getPageApiValues and api.getPageApiValues(apiName, "GOVERNOR_PROFILE")
    if governorProfile and governorProfile.governor_flags ~= nil then
        return tonumber(governorProfile.governor_flags) or governorProfile.governor_flags
    end
    return nil
end

local function setFieldEnabled(index, enabled)
    local field = rfsuite.app and rfsuite.app.formFields and rfsuite.app.formFields[index]
    if field and field.enable then
        field:enable(enabled)
    end
end

local function applyTxPrecompState(isEnabled)
    if state.txPrecompCurve == isEnabled then return end
    state.txPrecompCurve = isEnabled
    setFieldEnabled(FIELD_F_GAIN, not isEnabled)
    setFieldEnabled(FIELD_YAW_WEIGHT, not isEnabled)
    setFieldEnabled(FIELD_CYCLIC_WEIGHT, not isEnabled)
    setFieldEnabled(FIELD_COLLECTIVE_WEIGHT, not isEnabled)
end

local function applyGovernorDisabledState(governorMode)
    local isDisabled = (governorMode == 0)
    local navigation = rfsuite.app and rfsuite.app.formNavigationFields

    if state.governorDisabled == isDisabled then return end
    state.governorDisabled = isDisabled
    if not navigation then return end

    if navigation.save and navigation.save.enable then
        navigation.save:enable(not isDisabled)
    end
    if navigation.reload and navigation.reload.enable then
        navigation.reload:enable(not isDisabled)
    end
end

local function decodeGovernorFlags(flags)
    local governor_flags_bitmap = {{field = "fc_throttle_curve"}, {field = "tx_precomp_curve"}, {field = "fallback_precomp"}, {field = "voltage_comp"}, {field = "pid_spoolup"}, {field = "hs_adjustment"}, {field = "dyn_min_throttle"}, {field = "autorotation"}, {field = "suspend"}, {field = "bypass"}}

    local decoded = {}
    for bitIndex, info in ipairs(governor_flags_bitmap) do
        local mask = 2 ^ (bitIndex - 1)
        decoded[info.field] = (flags & mask) ~= 0
    end
    return decoded
end

apidata = {
    api = {
        {id = 1, name = "GOVERNOR_PROFILE", enableDeltaCache = false, rebuildOnWrite = true},
    },    
    formdata = {
        labels = {
            {t = "@i18n(app.modules.profile_governor.gains)@", label = 1, inline_size = 8.15}, 
            {t = "@i18n(app.modules.profile_governor.precomp)@", label = 2, inline_size = 8.15}, 
        },
        fields = {
            {t = "@i18n(app.modules.profile_governor.full_headspeed)@", mspapi = 1, apikey = "governor_headspeed", enablefunction = function() return (getGovernorMode() or -1) >= 2 end}, {t = "@i18n(app.modules.profile_governor.min_throttle)@", mspapi = 1, apikey = "governor_min_throttle", enablefunction = function() return (getGovernorMode() or -1) >= 2 end},
            {t = "@i18n(app.modules.profile_governor.max_throttle)@", mspapi = 1, apikey = "governor_max_throttle", enablefunction = function() return (getGovernorMode() or -1) >= 1 end}, {t = "@i18n(app.modules.profile_governor.fallback_drop)@", mspapi = 1, apikey = "governor_fallback_drop", enablefunction = function() return (getGovernorMode() or -1) >= 1 end},
            {t = "@i18n(app.modules.profile_governor.gain)@", mspapi = 1, apikey = "governor_gain", enablefunction = function() return (getGovernorMode() or -1) >= 2 end}, {t = "@i18n(app.modules.profile_governor.p)@", inline = 4, label = 1, mspapi = 1, apikey = "governor_p_gain", enablefunction = function() return (getGovernorMode() or -1) >= 2 end},
            {t = "@i18n(app.modules.profile_governor.i)@", inline = 3, label = 1, mspapi = 1, apikey = "governor_i_gain", enablefunction = function() return (getGovernorMode() or -1) >= 2 end}, {t = "@i18n(app.modules.profile_governor.d)@", inline = 2, label = 1, mspapi = 1, apikey = "governor_d_gain", enablefunction = function() return (getGovernorMode() or -1) >= 2 end},
            {t = "@i18n(app.modules.profile_governor.f)@", inline = 1, label = 1, mspapi = 1, apikey = "governor_f_gain", enablefunction = function() return (getGovernorMode() or -1) >= 2 end}, {t = "@i18n(app.modules.profile_governor.yaw)@", inline = 3, label = 2, mspapi = 1, apikey = "governor_yaw_weight", enablefunction = function() return (getGovernorMode() or -1) >= 2 end},
            {t = "@i18n(app.modules.profile_governor.cyc)@", inline = 2, label = 2, mspapi = 1, apikey = "governor_cyclic_weight", enablefunction = function() return (getGovernorMode() or -1) >= 2 end}, {t = "@i18n(app.modules.profile_governor.col)@", inline = 1, label = 2, mspapi = 1, apikey = "governor_collective_weight", enablefunction = function() return (getGovernorMode() or -1) >= 2 end},
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    state.activateWakeup = true
end

local function wakeup()
    local governorMode

     -- we are compromised if we don't have governor mode known
    governorMode = getGovernorMode()
    if governorMode == nil then
        pageRuntime.openMenuContext()
        return
    end   

    if state.activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        local activeProfile = flightState.getActiveProfile and flightState.getActiveProfile()
        if activeProfile ~= nil then
            local baseTitle = rfsuite.app.lastTitle or (rfsuite.app.Page and rfsuite.app.Page.title) or ""
            rfsuite.app.ui.setHeaderTitle(baseTitle .. " #" .. activeProfile, nil, rfsuite.app.Page and rfsuite.app.Page.navButtons)
        end
        applyGovernorDisabledState(governorMode)

        local flags = getGovernorFlags()
        if flags == nil then return end
        local decodedFlags = decodeGovernorFlags(flags)
        applyTxPrecompState(decodedFlags["tx_precomp_curve"] == true)
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
    state.governorDisabled = false
    state.txPrecompCurve = nil
end

return {apidata = apidata, title = "@i18n(app.modules.profile_governor.name)@", reboot = false, event = event, onNavMenu = onNavMenu, refreshOnProfileChange = true, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, close = close, API = {}}
