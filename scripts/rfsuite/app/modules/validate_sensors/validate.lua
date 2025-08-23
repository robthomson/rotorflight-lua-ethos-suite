local fields = {}
local labels = {}
local i18n = rfsuite.i18n.get
local enableWakeup = false

local w, h = lcd.getWindowSize()
local buttonW = 100
local buttonWs = buttonW - (buttonW * 20) / 100
local x = w - 15

local displayPos = {x = x - buttonW - buttonWs - 5 - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 100, h = rfsuite.app.radio.navbuttonHeight}

local invalidSensors = rfsuite.tasks.telemetry.validateSensors()

local repairSensors = false

local progressLoader
local progressLoaderCounter = 0
local doDiscoverNotify = false


local function sortSensorListByName(sensorList)
    table.sort(sensorList, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    return sensorList
end

local sensorList = sortSensorListByName(rfsuite.tasks.telemetry.listSensors())

local function openPage(pidx, title, script)
    enableWakeup = false
    rfsuite.app.triggers.closeProgressLoader = true

    form.clear()

    -- track page
    rfsuite.app.lastIdx   = pidx   -- was idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript= script

    rfsuite.app.ui.fieldHeader(rfsuite.i18n.get("app.modules.validate_sensors.name"))

    -- fresh tables so lookups are never stale/nil
    rfsuite.app.formLineCnt = 0
    rfsuite.app.formFields  = {}
    rfsuite.app.formLines   = {}

    local posText = { x = x - 5 - buttonW - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 200, h = rfsuite.app.radio.navbuttonHeight }
    for i, v in ipairs(sensorList or {}) do
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine(v.name)
        rfsuite.app.formFields[v.key] = form.addStaticText(rfsuite.app.formLines[rfsuite.app.formLineCnt], posText, "-")
    end

    enableWakeup = true
end

function sensorKeyExists(searchKey, sensorTable)
    for _, sensor in pairs(sensorTable) do if sensor['key'] == searchKey then return true end end
    return false
end

local function postLoad(self)
    rfsuite.utils.log("postLoad","debug")
end

local function postRead(self)
    rfsuite.utils.log("postRead","debug")
end


local function rebootFC()

    local RAPI = rfsuite.tasks.msp.api.load("REBOOT")
    RAPI.setUUID("123e4567-e89b-12d3-a456-426614174000")
    RAPI.setCompleteHandler(function(self)
        rfsuite.utils.log("Rebooting FC","info")

        rfsuite.utils.onReboot()

    end)
    RAPI.write()
    
end

local function applySettings()
    local EAPI = rfsuite.tasks.msp.api.load("EEPROM_WRITE")
    EAPI.setUUID("550e8400-e29b-41d4-a716-446655440000")
    EAPI.setCompleteHandler(function(self)
        rfsuite.utils.log("Writing to EEPROM","info")
        rebootFC()
    end)
    EAPI.write()

end


local function runRepair(data)

    local sensorList = rfsuite.tasks.telemetry.listSensors()
    local newSensorList = {}

    -- Grab list of required sensors
    local count = 1
    for _, v in pairs(sensorList) do
        local sensor_id = v['set_telemetry_sensors']
        if sensor_id ~= nil and not newSensorList[sensor_id] then
            newSensorList[sensor_id] = true
            count = count + 1
        end    
    end   

    -- Include currently supplied sensors (excluding zeros)
    for i, v in pairs(data['parsed']) do
        if string.match(i, "^telem_sensor_slot_%d+$") and v ~= 0 then
            local sensor_id = v
            if sensor_id ~= nil and not newSensorList[sensor_id] then
                newSensorList[sensor_id] = true
                count = count + 1
            end    
        end    
    end       


    local WRITEAPI = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
    WRITEAPI.setUUID("123e4567-e89b-12d3-a456-426614174000")
    WRITEAPI.setCompleteHandler(function(self, buf)
        applySettings()
    end)

    local buffer = data['buffer']  -- Existing buffer
    local sensorIndex = 13  -- Start at byte 13 (1-based indexing)

    -- Convert newSensorList keys to an array (since Lua tables are not ordered)
    local sortedSensorIds = {}
    for sensor_id, _ in pairs(newSensorList) do
        table.insert(sortedSensorIds, sensor_id)
    end

    -- Sort sensor IDs to ensure consistency
    table.sort(sortedSensorIds)

    -- Insert new sensors into buffer
    for _, sensor_id in ipairs(sortedSensorIds) do
        if sensorIndex <= 52 then  -- 13 bytes + 40 sensor slots = 53 max (1-based)
            buffer[sensorIndex] = sensor_id
            sensorIndex = sensorIndex + 1
        else
            break  -- Stop if buffer limit is reached
        end
    end

    -- Fill remaining slots with zeros
    for i = sensorIndex, 52 do
        buffer[i] = 0
    end

    -- Send updated buffer
    WRITEAPI.write(buffer)

end


local function wakeup()

    -- prevent wakeup running until after initialised
    if enableWakeup == false then return end

    if doDiscoverNotify == true then

        doDiscoverNotify = false

        local buttons = {{
            label = rfsuite.i18n.get("app.btn_ok"),
            action = function()
                return true
            end
        }}
    
        if rfsuite.utils.ethosVersionAtLeast({1,6,3}) then
            rfsuite.utils.log("Starting discover sensors", "info")
            rfsuite.tasks.msp.sensorTlm:discover()
        else    
            form.openDialog({
                width = nil,
                title =  rfsuite.i18n.get("app.modules.validate_sensors.name"),
                message = rfsuite.i18n.get("app.modules.validate_sensors.msg_repair_fin"),
                buttons = buttons,
                wakeup = function()
                end,
                paint = function()
                end,
                options = TEXT_LEFT
            })
        end
    end


    -- check for updates
    invalidSensors = rfsuite.tasks.telemetry.validateSensors()

    for i, v in ipairs(sensorList) do
        -- Guard: field may not exist during the first few wakeups
        local field = rfsuite.app.formFields and rfsuite.app.formFields[v.key]
        if field then
            if sensorKeyExists(v.key, invalidSensors) then
                if v.mandatory == true then
                    field:value(rfsuite.i18n.get("app.modules.validate_sensors.invalid"))
                    field:color(ORANGE)
                else
                    field:value(rfsuite.i18n.get("app.modules.validate_sensors.invalid"))
                    field:color(RED)
                end
            else
                field:value(rfsuite.i18n.get("app.modules.validate_sensors.ok"))
                field:color(GREEN)
            end
        end
    end

  -- run process to repair all sensors
  if repairSensors == true then

        -- show the progress dialog
        progressLoader = form.openProgressDialog(rfsuite.i18n.get("app.msg_saving"), rfsuite.i18n.get("app.msg_saving_to_fbl"))
        progressLoader:closeAllowed(false)
        progressLoaderCounter = 0

        API = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
        API.setUUID("550e8400-e29b-41d4-a716-446655440000")
        API.setCompleteHandler(function(self, buf)
            local data = API.data()
            if data['parsed'] then
                runRepair(data)
            end
        end)
        API.read()
        repairSensors = false
    end  

    -- enable/disable the tool button
    if rfsuite.session and rfsuite.session.apiVersion and rfsuite.utils.apiVersionCompare("<", "12.08") then
        rfsuite.app.formNavigationFields['tool']:enable(false)
    else
        rfsuite.app.formNavigationFields['tool']:enable(true)
    end

    if progressLoader then
        if progressLoaderCounter < 100 then
            progressLoaderCounter = progressLoaderCounter + 5
            progressLoader:value(progressLoaderCounter)
        else    
            progressLoader:close()    
            progressLoader = nil

            -- notify user to do a discover sensors
            doDiscoverNotify = true

        end    
    end    

end

local function onToolMenu(self)

    local buttons = {{
        label = rfsuite.i18n.get("app.btn_ok"),
        action = function()

            -- we push this to the background task to do its job
            repairSensors = true
            writePayload = nil
            return true
        end
    }, {
        label = rfsuite.i18n.get("app.btn_cancel"),
        action = function()
            return true
        end
    }}

    form.openDialog({
        width = nil,
        title =  rfsuite.i18n.get("app.modules.validate_sensors.name"),
        message = rfsuite.i18n.get("app.modules.validate_sensors.msg_repair"),
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

end


return {
    reboot = false,
    eepromWrite = false,
    minBytes = 0,
    wakeup = wakeup,
    refreshswitch = false,
    simulatorResponse = {},
    postLoad = postLoad,
    postRead = postRead,
    openPage = openPage,
    onToolMenu = onToolMenu,
    navButtons = {
        menu = true,
        save = false,
        reload = false,
        tool = true,
        help = true
    },
    API = {},
}
