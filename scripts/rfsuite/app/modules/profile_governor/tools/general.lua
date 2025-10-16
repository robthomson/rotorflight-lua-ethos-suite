
local rfsuite = require("rfsuite") 

local activateWakeup = false
local governorDisabledMsg = false


-- Field index constants (must match order in apidata->formdata->fields)
local FIELD_FULL_HEADSPEED       = 1
local FIELD_MIN_THROTTLE         = 2
local FIELD_MAX_THROTTLE         = 3
local FIELD_FALLBACK_DROP        = 4
local FIELD_GAIN                 = 5
local FIELD_P_GAIN               = 6
local FIELD_I_GAIN               = 7
local FIELD_D_GAIN               = 8
local FIELD_F_GAIN               = 9
local FIELD_YAW_WEIGHT           = 10
local FIELD_CYCLIC_WEIGHT        = 11
local FIELD_COLLECTIVE_WEIGHT    = 12
local FIELD_TTA_GAIN             = 13
local FIELD_TTA_LIMIT            = 14

-- decode bit flags into a table of {field = true/false}
local function decodeGovernorFlags(flags)
    local governor_flags_bitmap = {
        { field = "fc_throttle_curve" },   -- bit 0
        { field = "tx_precomp_curve" },    -- bit 1
        { field = "fallback_precomp" },    -- bit 2
        { field = "voltage_comp" },        -- bit 3
        { field = "pid_spoolup" },         -- bit 4
        { field = "hs_adjustment" },       -- bit 5
        { field = "dyn_min_throttle" },    -- bit 6
        { field = "autorotation" },        -- bit 7
        { field = "suspend" },             -- bit 8
        { field = "bypass" },              -- bit 9
    }

    local decoded = {}
    for bitIndex, info in ipairs(governor_flags_bitmap) do
        local mask = 2 ^ (bitIndex - 1)
        decoded[info.field] = (flags & mask) ~= 0
    end
    return decoded
end

local apidata = {
        api = {
            [1] = 'GOVERNOR_PROFILE',
        },
        formdata = {
            labels = {
                {t = "@i18n(app.modules.profile_governor.gains)@",                label = 1, inline_size = 8.15},
                {t = "@i18n(app.modules.profile_governor.precomp)@",              label = 2, inline_size = 8.15},
                {t = "@i18n(app.modules.profile_governor.tail_torque_assist)@",   label = 3, inline_size = 8.15},
            },
            fields = {
                {t = "@i18n(app.modules.profile_governor.full_headspeed)@",          mspapi = 1, apikey = "governor_headspeed", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},   
                {t = "@i18n(app.modules.profile_governor.min_throttle)@",            mspapi = 1, apikey = "governor_min_throttle", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.max_throttle)@",            mspapi = 1, apikey = "governor_max_throttle", enablefunction = function() return (rfsuite.session.governorMode >=1 ) end},
                {t = "@i18n(app.modules.profile_governor.fallback_drop)@",           mspapi = 1, apikey = "governor_fallback_drop", enablefunction = function() return (rfsuite.session.governorMode >=1 ) end},
                {t = "@i18n(app.modules.profile_governor.gain)@",                    mspapi = 1, apikey = "governor_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.p)@",                       inline = 4, label = 1, mspapi = 1, apikey = "governor_p_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.i)@",                       inline = 3, label = 1, mspapi = 1, apikey = "governor_i_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.d)@",                       inline = 2, label = 1, mspapi = 1, apikey = "governor_d_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.f)@",                       inline = 1, label = 1, mspapi = 1, apikey = "governor_f_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.yaw)@",                     inline = 3, label = 2, mspapi = 1, apikey = "governor_yaw_weight", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.cyc)@",                     inline = 2, label = 2, mspapi = 1, apikey = "governor_cyclic_weight", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.col)@",                     inline = 1, label = 2, mspapi = 1, apikey = "governor_collective_weight", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.tta_gain)@",                inline = 2, label = 3, mspapi = 1, apikey = "governor_tta_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.tta_limit)@",               inline = 1, label = 3, mspapi = 1, apikey = "governor_tta_limit", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
            }
        }
    }


local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()

    if activateWakeup == true  and rfsuite.tasks.msp.mspQueue:isProcessed() then

        -- update active profile
        -- the check happens in postLoad          
        if rfsuite.session.activeProfile ~= nil then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " / " .. "@i18n(app.modules.governor.menu_general)@" .. " #" .. rfsuite.session.activeProfile)
        end

        if rfsuite.session.governorMode == 0 then
            if governorDisabledMsg == false then
                governorDisabledMsg = true

                -- disable save button
                rfsuite.app.formNavigationFields['save']:enable(false)
                -- disable reload button
                rfsuite.app.formNavigationFields['reload']:enable(false)
                -- add field to formFields
                rfsuite.app.formLines[#rfsuite.app.formLines + 1] = form.addLine("@i18n(app.modules.profile_governor.disabled_message)@")

            end
        end

        local flags = rfsuite.app.Page.apidata.values['GOVERNOR_PROFILE'].governor_flags
        local decodedFlags = decodeGovernorFlags(flags)
 
        if decodedFlags["tx_precomp_curve"] then  
            rfsuite.app.formFields[FIELD_F_GAIN]:enable(false)
            rfsuite.app.formFields[FIELD_YAW_WEIGHT]:enable(false)
            rfsuite.app.formFields[FIELD_CYCLIC_WEIGHT]:enable(false)
            rfsuite.app.formFields[FIELD_COLLECTIVE_WEIGHT]:enable(false)

        else
            rfsuite.app.formFields[FIELD_F_GAIN]:enable(true)
            rfsuite.app.formFields[FIELD_YAW_WEIGHT]:enable(true)
            rfsuite.app.formFields[FIELD_CYCLIC_WEIGHT]:enable(true)
            rfsuite.app.formFields[FIELD_COLLECTIVE_WEIGHT]:enable(true)
        end


    end

end

local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(pidx, title, "profile_governor/governor.lua")  
        return true
    end
end


local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(pidx, title, "profile_governor/governor.lua")  
    return true
end

return {
    apidata = apidata,
    title = "@i18n(app.modules.profile_governor.name)@",
    reboot = false,
    event = event,
    onNavMenu = onNavMenu,
    refreshOnProfileChange = true,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
