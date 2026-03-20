--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local APP_RUNTIME_SINGLETON_KEY = "rfsuite.shared.app.runtime"

if package.loaded[APP_RUNTIME_SINGLETON_KEY] then
    return package.loaded[APP_RUNTIME_SINGLETON_KEY]
end

local runtime = {
    progressDialog = nil,
    lastPage = nil,
    telemetryStaticCache = nil
}

function runtime.reset()
    runtime.progressDialog = nil
    runtime.lastPage = nil
    runtime.telemetryStaticCache = nil
    return runtime
end

package.loaded[APP_RUNTIME_SINGLETON_KEY] = runtime

return runtime
