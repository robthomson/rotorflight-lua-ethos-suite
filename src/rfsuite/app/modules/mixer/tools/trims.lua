--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local appRuntime = (rfsuite.shared and rfsuite.shared.app) or assert(loadfile("shared/app/runtime.lua"))()

local state = appRuntime and appRuntime.mixerTrimsState or nil
if not state then
    state = {
        triggerOverride = false,
        inOverride = false,
        preserveTailMode = false,
        clearToSend = true,
        lastChangeTime = os.clock(),
        tailMode = nil,
        trims = {},
        lastTrims = {}
    }
    if appRuntime then
        appRuntime.mixerTrimsState = state
    end
end

local function resetPageState()
    local key

    state.triggerOverride = false
    state.inOverride = false
    state.preserveTailMode = false
    state.clearToSend = true
    state.lastChangeTime = os.clock()
    state.tailMode = nil

    for key in pairs(state.trims) do
        state.trims[key] = nil
    end
    for key in pairs(state.lastTrims) do
        state.lastTrims[key] = nil
    end
end

local function getTailMode()
    return tonumber(state.tailMode)
end

local function isYawTailMode()
    return getTailMode() == 0
end

local function isMotorTailMode()
    local tailMode = getTailMode()
    return tailMode == 1 or tailMode == 2
end

local function getPageField(index)
    local page = rfsuite.app and rfsuite.app.Page
    local apidata = page and page.apidata
    local formdata = apidata and apidata.formdata
    local field = formdata and formdata.fields and formdata.fields[index]
    return field
end

local function getPageFieldValue(index)
    local field = getPageField(index)
    return field and field.value or nil
end

local function trackTrimChange(self, key, value, queueProcessed)
    local now = os.clock()
    local settleTime = 0.85

    state.trims[key] = value
    if ((now - state.lastChangeTime) < settleTime) or queueProcessed ~= true or state.clearToSend ~= true then
        return
    end

    if value ~= state.lastTrims[key] then
        state.lastTrims[key] = value
        state.lastChangeTime = now
        rfsuite.utils.log("save trim", "debug")
        self.saveData(self)
    end
end

local function captureTrimState()
    state.trims.roll = getPageFieldValue(1)
    state.trims.pitch = getPageFieldValue(2)
    state.trims.collective = getPageFieldValue(3)
    state.lastTrims.roll = state.trims.roll
    state.lastTrims.pitch = state.trims.pitch
    state.lastTrims.collective = state.trims.collective

    if isMotorTailMode() then
        state.trims.idleThrottle = getPageFieldValue(4)
        state.lastTrims.idleThrottle = state.trims.idleThrottle
        state.trims.yaw = nil
        state.lastTrims.yaw = nil
    elseif isYawTailMode() then
        state.trims.yaw = getPageFieldValue(4)
        state.lastTrims.yaw = state.trims.yaw
        state.trims.idleThrottle = nil
        state.lastTrims.idleThrottle = nil
    else
        state.trims.yaw = nil
        state.trims.idleThrottle = nil
        state.lastTrims.yaw = nil
        state.lastTrims.idleThrottle = nil
    end
end

local function queueDirect(message, uuid)
    if message and uuid and message.uuid == nil then message.uuid = uuid end
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local apidata = {
    api = {[1] = "MIXER_CONFIG"},
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.trim.roll_trim)@",         mspapi = 1, apikey = "swash_trim_0", },
            {t = "@i18n(app.modules.trim.pitch_trim)@",        mspapi = 1, apikey = "swash_trim_1"},
            {t = "@i18n(app.modules.trim.collective_trim)@",    mspapi = 1, apikey = "swash_trim_2"},
            {t = "@i18n(app.modules.trim.yaw_trim)@",          mspapi = 1, apikey = "tail_center_trim", enablefunction = isYawTailMode},
        }
    }
}

local function saveData()
    state.clearToSend = true
    rfsuite.app.triggers.triggerSaveNoProgress = true
end

local function mixerOn(self)

    rfsuite.app.audio.playMixerOverideEnable = true

    for i = 1, 4 do
        local message = {command = 191, payload = {i}}

        rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 0)
        queueDirect(message, string.format("mixer.override.%d.on", i))

        if rfsuite.preferences.developer.logmsp then
            local logData = "mixerOn: {" .. rfsuite.utils.joinTableItems(message.payload, ", ") .. "}"
            rfsuite.utils.log(logData, "info")
        end

    end

    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function mixerOff(self)

    rfsuite.app.audio.playMixerOverideDisable = true

    for i = 1, 4 do
        local message = {command = 191, payload = {i}}
        rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 2501)
        queueDirect(message, string.format("mixer.override.%d.off", i))

        if rfsuite.preferences.developer.logmsp then
            local logData = "mixerOff: {" .. rfsuite.utils.joinTableItems(message.payload, ", ") .. "}"
            rfsuite.utils.log(logData, "info")
        end

    end

    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function postLoad(self)
    local mixerConfig = rfsuite.app and rfsuite.app.Page and rfsuite.app.Page.values and rfsuite.app.Page.values["MIXER_CONFIG"]
    local tailMode = mixerConfig and mixerConfig["tail_rotor_mode"]

    if tailMode == nil then
        rfsuite.app.triggers.closeProgressLoader = true
        return
    end

    if state.tailMode == nil then
        state.tailMode = math.floor(tailMode)
        state.preserveTailMode = true
        -- Field 4 is conditionally built during openPage(), so discovering
        -- tail mode requires a full page rebuild rather than a light refresh.
        rfsuite.app.triggers.reloadFull = true
        return
    end

    captureTrimState()
    state.preserveTailMode = false
    rfsuite.app.triggers.closeProgressLoader = true
end

local function wakeup(self)
    local mixerConfig
    local tailMode

    mixerConfig = rfsuite.app and rfsuite.app.Page and rfsuite.app.Page.values and rfsuite.app.Page.values["MIXER_CONFIG"]
    tailMode = mixerConfig and mixerConfig["tail_rotor_mode"]
    if state.tailMode == nil then
        if tailMode ~= nil then
            state.tailMode = math.floor(tailMode)
            state.preserveTailMode = true
            rfsuite.app.triggers.reloadFull = true
        end
        return
    end    


    if state.inOverride == true then
        local queueProcessed = rfsuite.tasks.msp.mspQueue:isProcessed()

        trackTrimChange(self, "roll", getPageFieldValue(1), queueProcessed)
        trackTrimChange(self, "pitch", getPageFieldValue(2), queueProcessed)
        trackTrimChange(self, "collective", getPageFieldValue(3), queueProcessed)

        if isMotorTailMode() then
            trackTrimChange(self, "idleThrottle", getPageFieldValue(4), queueProcessed)
        elseif isYawTailMode() then
            trackTrimChange(self, "yaw", getPageFieldValue(4), queueProcessed)
        end

    end

    if state.triggerOverride == true then
        state.triggerOverride = false

        if state.inOverride == false then

            rfsuite.app.audio.playMixerOverideEnable = true

            rfsuite.app.ui.progressDisplay("@i18n(app.modules.trim.mixer_override)@", "@i18n(app.modules.trim.mixer_override_enabling)@")

            rfsuite.app.Page.mixerOn(self)
            state.inOverride = true
        else

            rfsuite.app.audio.playMixerOverideDisable = true

            rfsuite.app.ui.progressDisplay("@i18n(app.modules.trim.mixer_override)@", "@i18n(app.modules.trim.mixer_override_disabling)@")

            rfsuite.app.Page.mixerOff(self)
            state.inOverride = false
        end
    end

end

local function onToolMenu(self)

    local buttons = {
        {
            label = "@i18n(app.btn_ok)@",
            action = function()

                state.triggerOverride = true
                return true
            end
        }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }
    local message
    local title
    if state.inOverride == false then
        title = "@i18n(app.modules.trim.enable_mixer_override)@"
        message = "@i18n(app.modules.trim.enable_mixer_message)@"
    else
        title = "@i18n(app.modules.trim.disable_mixer_override)@"
        message = "@i18n(app.modules.trim.disable_mixer_message)@"
    end

    form.openDialog({width = nil, title = title, message = message, buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

end

local function onNavMenu(self)

    if state.inOverride == true then
        rfsuite.app.audio.playMixerOverideDisable = true

        state.inOverride = false

        rfsuite.app.ui.progressDisplay("@i18n(app.modules.trim.mixer_override)@", "@i18n(app.modules.trim.mixer_override_disabling)@")

        mixerOff(self)
        rfsuite.app.triggers.closeProgressLoader = true
    end

    resetPageState()

    pageRuntime.openMenuContext()

end

local function close(self)
    if state.inOverride == true then
        mixerOff(self)
    end
    if (rfsuite.app and rfsuite.app._closing) or state.preserveTailMode ~= true then
        resetPageState()
    else
        state.preserveTailMode = false
    end
end

return {apidata = apidata, eepromWrite = true, reboot = false, mixerOff = mixerOff, mixerOn = mixerOn, postLoad = postLoad, onToolMenu = onToolMenu, onNavMenu = onNavMenu, wakeup = wakeup, saveData = saveData, close = close, navButtons = {menu = true, save = true, reload = true, tool = true, help = true}, API = {}}
