--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({defaultSection = "hardware", showProgress = true})
local flightState = (rfsuite.shared and rfsuite.shared.flight) or assert(loadfile("shared/flight.lua"))()
local appRuntime = (rfsuite.shared and rfsuite.shared.app) or assert(loadfile("shared/app/runtime.lua"))()

local state = appRuntime.governorGeneralState
if not state then
    state = {
        enableWakeup = false,
        lastGovernorMode = nil,
        fieldEnabled = {}
    }
    appRuntime.governorGeneralState = state
end

local FIELDS = {
    GOVERNOR_MODE = 1,
    GOVERNOR_THROTTLE_TYPE = 2,
    GOVERNOR_IDLE_THROTTLE = 3,
    GOVERNOR_AUTO_THROTTLE = 4,
    GOV_HANDOVER_THROTTLE = 5,
    GOV_THROTTLE_HOLD_TIMEOUT = 6,
    GOV_AUTO_TIMEOUT = 7
}

local apidata = {
    api = {[1] = "GOVERNOR_CONFIG"},
    formdata = {
        labels = {},
        fields = {
            [FIELDS.GOVERNOR_MODE] = {t = "@i18n(app.modules.governor.mode)@", mspapi = 1, apikey = "gov_mode", type = 1},
            [FIELDS.GOVERNOR_THROTTLE_TYPE] = {t = "@i18n(app.modules.governor.throttle_type)@", mspapi = 1, apikey = "gov_throttle_type", type = 1},
            [FIELDS.GOVERNOR_IDLE_THROTTLE] = {t = "@i18n(app.modules.profile_governor.idle_throttle)@", mspapi = 1, apikey = "governor_idle_throttle"},
            [FIELDS.GOVERNOR_AUTO_THROTTLE] = {t = "@i18n(app.modules.profile_governor.auto_throttle)@", mspapi = 1, apikey = "governor_auto_throttle"},
            [FIELDS.GOV_HANDOVER_THROTTLE] = {t = "@i18n(app.modules.governor.handover_throttle)@", mspapi = 1, apikey = "gov_handover_throttle"},
            [FIELDS.GOV_THROTTLE_HOLD_TIMEOUT] = {t = "@i18n(app.modules.governor.throttle_hold_timeout)@", mspapi = 1, apikey = "gov_throttle_hold_timeout"},
            [FIELDS.GOV_AUTO_TIMEOUT] = {t = "@i18n(app.modules.governor.auto_timeout)@", mspapi = 1, apikey = "gov_autorotation_timeout"}
        }
    }
}

local function getGovernorModeValue()
    local page = rfsuite.app and rfsuite.app.Page
    local apidataRef = page and page.apidata
    local formdata = apidataRef and apidataRef.formdata
    local fields = formdata and formdata.fields
    local field = fields and fields[FIELDS.GOVERNOR_MODE]
    local value = field and field.value or nil

    if value == nil then
        value = flightState.getGovernorMode()
    end

    value = tonumber(value)
    if value == nil then return nil end
    return math.floor(value)
end

local function getFormField(index)
    local formFields = rfsuite.app and rfsuite.app.formFields
    return formFields and formFields[index] or nil
end

local function setFieldEnabled(index, enabled)
    local field

    if state.fieldEnabled[index] == enabled then return end

    field = getFormField(index)
    if field and field.enable then
        field:enable(enabled)
        state.fieldEnabled[index] = enabled
    end
end

local function applyGovernorMode(governorMode)
    if governorMode == nil then return end

    flightState.setGovernorMode(governorMode)
    if state.lastGovernorMode == governorMode then return end
    state.lastGovernorMode = governorMode

    setFieldEnabled(FIELDS.GOVERNOR_THROTTLE_TYPE, governorMode >= 1)
    setFieldEnabled(FIELDS.GOVERNOR_IDLE_THROTTLE, governorMode >= 1)
    setFieldEnabled(FIELDS.GOVERNOR_AUTO_THROTTLE, governorMode >= 1)
    setFieldEnabled(FIELDS.GOV_HANDOVER_THROTTLE, governorMode >= 2)
    setFieldEnabled(FIELDS.GOV_THROTTLE_HOLD_TIMEOUT, governorMode >= 2)
    setFieldEnabled(FIELDS.GOV_AUTO_TIMEOUT, governorMode >= 2)
end

local function postLoad()
    state.enableWakeup = true
    applyGovernorMode(getGovernorModeValue())
    rfsuite.app.triggers.closeProgressLoader = true
end

local function postSave()
    local governorMode = getGovernorModeValue()
    if flightState.getGovernorMode() ~= governorMode then
        flightState.setGovernorMode(governorMode)
        rfsuite.utils.log("Governor mode: " .. tostring(governorMode), "info")
    end
end

local function wakeup()
    local governorMode

    if not state.enableWakeup then return false end

    governorMode = getGovernorModeValue()
    if governorMode == nil then
        pageRuntime.openMenuContext({defaultSection = "hardware"})
        return
    end

    applyGovernorMode(governorMode)
end

local function event(widget, category, value, x, y)
    return navHandlers.event(widget, category, value)
end

local function onNavMenu()
    return navHandlers.onNavMenu()
end

local function close()
    local key

    state.enableWakeup = false
    state.lastGovernorMode = nil
    for key in pairs(state.fieldEnabled) do
        state.fieldEnabled[key] = nil
    end
end

return {apidata = apidata, reboot = true, eepromWrite = true, postLoad = postLoad, postSave = postSave, onNavMenu = onNavMenu, event = event, wakeup = wakeup, close = close}
