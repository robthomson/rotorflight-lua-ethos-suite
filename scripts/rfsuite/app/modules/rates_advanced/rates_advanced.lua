
local activateWakeup = false
local currentProfileChecked = false
local extraMsgOnSave = nil
local originalRateTable = nil
local resetRates = false
local doFullReload = false

if rfsuite.RateTable == nil then rfsuite.RateTable = rfsuite.preferences.defaultRateProfile end

local mspapi = {
    api = {
        [1] = 'RC_TUNING',
    },
    formdata = {
        labels = {
            {t = "Roll dynamics",       label = 1, inline_size = 14.6},
            {t = "Pitch dynamics",      label = 2, inline_size = 14.6},
            {t = "Yaw dynamics",        label = 3, inline_size = 14.6},
            {t = "Collective dynamics", label = 4, inline_size = 14.6}
        },
        fields = {
            {t = "Rates Type",                        mspapi = 1, apikey = "rates_type", type = 1, ratetype = 1, postEdit = function(self) self.flagRateChange(self, true) end},
            {t = "Time",       inline = 2, label = 1, mspapi = 1, apikey = "response_time_1"},
            {t = "Accel",      inline = 1, label = 1, mspapi = 1, apikey = "accel_limit_1"},
            {t = "Time",       inline = 2, label = 2, mspapi = 1, apikey = "response_time_2"},
            {t = "Accel",      inline = 1, label = 2, mspapi = 1, apikey = "accel_limit_2"},
            {t = "Time",       inline = 2, label = 3, mspapi = 1, apikey = "response_time_3"},
            {t = "Accel",      inline = 1, label = 3, mspapi = 1, apikey = "accel_limit_3"},
            {t = "Time",       inline = 2, label = 4, mspapi = 1, apikey = "response_time_4"},
            {t = "Accel",      inline = 1, label = 4, mspapi = 1, apikey = "accel_limit_4"},
        }
    }                 
}

local function preSave(self)
    if resetRates == true then
        rfsuite.utils.log("Resetting rates to defaults","info")

        -- selected id
        local table_id = rfsuite.app.Page.fields[1].value

        -- load the respective rate table
        local tables = {}
        tables[0] = "app/modules/rates/ratetables/none.lua"
        tables[1] = "app/modules/rates/ratetables/betaflight.lua"
        tables[2] = "app/modules/rates/ratetables/raceflight.lua"
        tables[3] = "app/modules/rates/ratetables/kiss.lua"
        tables[4] = "app/modules/rates/ratetables/actual.lua"
        tables[5] = "app/modules/rates/ratetables/quick.lua"
        
        local mytable = assert(loadfile(tables[table_id]))()

        rfsuite.utils.log("Using defaults from table " .. tables[table_id], "info")

        -- pull all the values to the fields table as not created because not rendered!
        for _, y in pairs(mytable.formdata.fields) do
            if y.default then
                local found = false
        

                -- Check if an entry with the same apikey exists
                for i, v in ipairs(rfsuite.app.Page.fields) do
                    if v.apikey == y.apikey then
                        -- Update existing entry
                        rfsuite.app.Page.fields[i] = y
                        found = true
                        break
                    end
                end
        
                -- If no match was found, insert as a new entry and set value to default
                if not found then
                    table.insert(rfsuite.app.Page.fields, y)
                end
            end
        end

        -- save all the values
        for i,v in ipairs(rfsuite.app.Page.fields) do

                if v.apikey == "rates_type" then
                    v.value = table_id
                else 

                    local default = v.default or 0

                    default = default * rfsuite.utils.decimalInc(v.decimals)
                    if v.mult ~= nil then default = math.floor(default * v.mult) end
                    if v.scale ~= nil then default = math.floor(default / v.scale) end
                    
                    rfsuite.utils.log("Saving default value for " .. v.apikey .. " as " .. default, "info")
                    rfsuite.utils.saveFieldValue(v, default)
                    rfsuite.app.saveValue(i)
                end    
        end    
            
    end
 
end    

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()
    if activateWakeup and not currentProfileChecked and rfsuite.bg.msp.mspQueue:isProcessed() then
        -- update active profile
        -- the check happens in postLoad          
        if rfsuite.session.activeRateProfile then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeRateProfile)
            currentProfileChecked = true
        end

        -- set this after all data has loaded
        if not originalRateTable then
            originalRateTable = rfsuite.app.Page.fields[1].value
        end

        -- reload the page
        if doFullReload == true then
            rfsuite.utils.log("Reloading full after rate type change","info")
            rfsuite.app.triggers.reloadFull = true
            doFullReload = false
        end    
    end
end

-- enable and disable fields if rate type changes
local function flagRateChange(self)
    if rfsuite.app.Page.fields[1].value == originalRateTable then
        self.extraMsgOnSave = nil
        rfsuite.app.ui.enableAllFields()
        resetRates = false
    else
        self.extraMsgOnSave = "Rate type changed. Values will be reset to defaults."
        resetRates = true
        rfsuite.app.ui.disableAllFields()
        rfsuite.app.formFields[1]:enable(true)
    end
end

local function postEepromWrite(self)
        -- trigger full reload after writting eeprom - needed as we are changing the rate type
        if resetRates == true then
            doFullReload = true
        end
        
end

return {
    mspapi = mspapi,
    title = "Rates",
    reboot = false,
    eepromWrite = true,
    refreshOnRateChange = true,
    rTableName = rTableName,
    flagRateChange = flagRateChange,
    postLoad = postLoad,
    wakeup = wakeup,
    preSave = preSave,
    postEepromWrite = postEepromWrite,
    extraMsgOnSave = extraMsgOnSave,
    API = {},
}
