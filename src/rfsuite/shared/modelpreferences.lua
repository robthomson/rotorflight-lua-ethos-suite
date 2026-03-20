--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local MODEL_PREFERENCES_SINGLETON_KEY = "rfsuite.shared.modelpreferences"

if package.loaded[MODEL_PREFERENCES_SINGLETON_KEY] then
    return package.loaded[MODEL_PREFERENCES_SINGLETON_KEY]
end

local rfsuite = require("rfsuite")

local modelPreferences = {
    values = nil,
    file = nil
}

local function syncSession()
    local session = rfsuite and rfsuite.session
    if not session then return end
    session.modelPreferences = modelPreferences.values
    session.modelPreferencesFile = modelPreferences.file
end

local function hydrateFromSession()
    local session = rfsuite and rfsuite.session
    if not session then return end
    if modelPreferences.values == nil then
        modelPreferences.values = session.modelPreferences
    end
    if modelPreferences.file == nil then
        modelPreferences.file = session.modelPreferencesFile
    end
end

function modelPreferences.get()
    hydrateFromSession()
    return modelPreferences.values
end

function modelPreferences.getFile()
    hydrateFromSession()
    return modelPreferences.file
end

function modelPreferences.set(values)
    modelPreferences.values = values
    syncSession()
    return modelPreferences.values
end

function modelPreferences.setFile(path)
    modelPreferences.file = path
    syncSession()
    return modelPreferences.file
end

function modelPreferences.setAll(values, path)
    modelPreferences.values = values
    modelPreferences.file = path
    syncSession()
    return modelPreferences.values, modelPreferences.file
end

function modelPreferences.reset()
    modelPreferences.values = nil
    modelPreferences.file = nil
    syncSession()
    return modelPreferences
end

syncSession()
package.loaded[MODEL_PREFERENCES_SINGLETON_KEY] = modelPreferences

return modelPreferences
