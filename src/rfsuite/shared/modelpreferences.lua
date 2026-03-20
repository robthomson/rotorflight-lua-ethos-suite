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

function modelPreferences.get()
    return modelPreferences.values
end

function modelPreferences.getFile()
    return modelPreferences.file
end

function modelPreferences.set(values)
    modelPreferences.values = values
    return modelPreferences.values
end

function modelPreferences.setFile(path)
    modelPreferences.file = path
    return modelPreferences.file
end

function modelPreferences.setAll(values, path)
    modelPreferences.values = values
    modelPreferences.file = path
    return modelPreferences.values, modelPreferences.file
end

function modelPreferences.reset()
    modelPreferences.values = nil
    modelPreferences.file = nil
    return modelPreferences
end

package.loaded[MODEL_PREFERENCES_SINGLETON_KEY] = modelPreferences

return modelPreferences
