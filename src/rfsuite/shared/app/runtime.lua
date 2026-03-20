--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local APP_RUNTIME_SINGLETON_KEY = "rfsuite.shared.app.runtime"

if package.loaded[APP_RUNTIME_SINGLETON_KEY] then
    return package.loaded[APP_RUNTIME_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local runtime = {
    progressDialog = nil,
    lastPage = nil,
    telemetryStaticCache = nil,
    mixerTrimsState = nil,
    mixerLegacyTailState = nil,
    governorGeneralState = nil,
    profileGovernorGeneralState = nil,
    profileGovernorFlagsState = nil,
    servoTableLast = nil,
    ratesActiveTable = nil,
    escToolKeepSessionOnce = false,
    showBatteryTypeStartup = nil,
    showConfirmationDialog = nil,
    dashboardBatteryDialogShown = false
}

local function prefBool(value, default)
    if value == nil then return default end
    if value == true or value == "true" or value == 1 or value == "1" then return true end
    if value == false or value == "false" or value == 0 or value == "0" then return false end
    return default
end

function runtime.reset()
    local prefs = rfsuite.preferences and rfsuite.preferences.general or {}
    runtime.progressDialog = nil
    runtime.lastPage = nil
    runtime.telemetryStaticCache = nil
    runtime.mixerTrimsState = nil
    runtime.mixerLegacyTailState = nil
    runtime.governorGeneralState = nil
    runtime.profileGovernorGeneralState = nil
    runtime.profileGovernorFlagsState = nil
    runtime.servoTableLast = nil
    runtime.ratesActiveTable = nil
    runtime.escToolKeepSessionOnce = false
    runtime.showBatteryTypeStartup = prefBool(prefs.show_battery_profile_startup, true)
    runtime.showConfirmationDialog = prefBool(prefs.show_confirmation_dialog, false)
    runtime.dashboardBatteryDialogShown = false
    return runtime
end

package.loaded[APP_RUNTIME_SINGLETON_KEY] = runtime

return runtime
