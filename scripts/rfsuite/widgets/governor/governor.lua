--[[
set crsf_flight_mode_reuse = GOV_ADJFUNC
]] --
local rf2gov = {}

rf2gov.refresh = true
rf2gov.environment = system.getVersion()
rf2gov.oldsensors = {"govmode"}
rf2gov.wakeupSchedulerUI = os.clock()

local governorMap = {}
governorMap[0] = "OFF"
governorMap[1] = "IDLE"
governorMap[2] = "SPOOLUP"
governorMap[3] = "RECOVERY"
governorMap[4] = "ACTIVE"
governorMap[5] = "THR-OFF"
governorMap[6] = "LOST-HS"
governorMap[7] = "AUTOROT"
governorMap[8] = "BAILOUT"
governorMap[100] = "DISABLED"
governorMap[101] = "DISARMED"

local sensors

function rf2gov.sensorMakeNumber(x)
    if x == nil or x == "" then x = 0 end

    x = string.gsub(x, "%D+", "")
    x = tonumber(x)
    if x == nil or x == "" then x = 0 end

    return x
end

function rf2gov.create(widget)
    return
end

function rf2gov.paint(widget)

    local w, h = lcd.getWindowSize()

    lcd.font(FONT_XXL)

    if rfsuite.bg.active() then
        str = sensors.govmode
    else
        str = "BG TASK DISABLED"
    end
    tsizeW, tsizeH = lcd.getTextSize(str)

    offsetY = 5

    posX = w / 2 - tsizeW / 2
    posY = h / 2 - tsizeH / 2 + offsetY

    lcd.drawText(posX, posY, str)

end

function rf2gov.getSensors()

    if rfsuite.bg.active() == false then return end

    if rf2gov.environment.simulation == true then
        govmode = "DISABLED"
    else

        govSOURCE = rfsuite.bg.telemetry.getSensorSource("governor")

        if rfsuite.bg.telemetry.getSensorProtocol() == 'lcrsf' then
            if govSOURCE ~= nil then govmode = govSOURCE:stringValue() end
        else

            if govSOURCE ~= nil then
                govId = govSOURCE:value()

                if governorMap[govId] == nil then
                    govmode = "UNKNOWN"
                else
                    govmode = governorMap[govId]
                end

            else
                govmode = ""
            end

        end

    end

    if rf2gov.oldsensors.govmode ~= govmode then rf2gov.refresh = true end

    ret = {govmode = govmode}
    rf2gov.oldsensors = ret

    return ret
end

-- MAIN WAKEUP FUNCTION. THIS SIMPLY FARMS OUT AT DIFFERING SCHEDULES TO SUB FUNCTIONS
function rf2gov.wakeup(widget)

    local schedulerUI
    if lcd.isVisible() then
        schedulerUI = 0.25
    else
        schedulerUI = 1
    end

    -- keep cpu load down by running UI at reduced interval
    local now = os.clock()
    if (now - rf2gov.wakeupSchedulerUI) >= schedulerUI then
        rf2gov.wakeupSchedulerUI = now
        rf2gov.wakeupUI()
    end

end

function rf2gov.wakeupUI(widget)
    rf2gov.refresh = false
    sensors = rf2gov.getSensors()

    if rf2gov.refresh == true then lcd.invalidate() end

    return
end

return rf2gov
