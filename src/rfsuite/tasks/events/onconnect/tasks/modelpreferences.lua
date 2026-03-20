--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local connectionState = (rfsuite.shared and rfsuite.shared.connection) or assert(loadfile("shared/connection.lua"))()
local modelPreferencesState = (rfsuite.shared and rfsuite.shared.modelPreferences) or assert(loadfile("shared/modelpreferences.lua"))()

local modelpreferences = {}

local modelpref_defaults = {dashboard = {theme_preflight = "nil", theme_inflight = "nil", theme_postflight = "nil"}, general = {flightcount = 0, totalflighttime = 0, lastflighttime = 0, batterylocalcalculation = 1}, battery = {smartfuel_model_type = 0, sag_multiplier = 0.5, calc_local = 0, alert_type = 0, becalertvalue = 6.5, rxalertvalue = 7.5, flighttime = 300}}

function modelpreferences.wakeup()

    if connectionState.getApiVersion() == nil then
        modelPreferencesState.reset()
        return
    end

    if connectionState.getMspBusy() then return end

    if not connectionState.getMcuId() then
        modelPreferencesState.reset()
        return
    end

    if (modelPreferencesState.get() == nil) then

        if rfsuite.config.preferences and connectionState.getMcuId() then

            local modelpref_file = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. connectionState.getMcuId() .. ".ini"
            rfsuite.utils.log("Preferences file: " .. modelpref_file, "info")

            os.mkdir("SCRIPTS:/" .. rfsuite.config.preferences)
            os.mkdir("SCRIPTS:/" .. rfsuite.config.preferences .. "/models")

            local slave_ini = modelpref_defaults
            local master_ini = rfsuite.ini.load_ini_file(modelpref_file) or {}

            local updated_ini = rfsuite.ini.merge_ini_tables(master_ini, slave_ini)
            modelPreferencesState.setAll(updated_ini, modelpref_file)

            if not rfsuite.ini.ini_tables_equal(master_ini, slave_ini) then rfsuite.ini.save_ini_file(modelpref_file, updated_ini) end

        end
    end

end

function modelpreferences.reset()
    modelPreferencesState.reset()
end

function modelpreferences.isComplete() if modelPreferencesState.get() ~= nil then return true end end

return modelpreferences
