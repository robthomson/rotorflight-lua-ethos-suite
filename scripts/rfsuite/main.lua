--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = {session = {}}
package.loaded.rfsuite = rfsuite

local _ENV = setmetatable({rfsuite = rfsuite}, {__index = _G, __newindex = function(_, k) print("attempt to create global '" .. tostring(k) .. "'", 2) end})

if not FONT_M then FONT_M = FONT_STD end

local config = {
    toolName = "Rotorflight",
    icon = lcd.loadMask("app/gfx/icon.png"),
    icon_logtool = lcd.loadMask("app/gfx/icon_logtool.png"),
    icon_unsupported = lcd.loadMask("app/gfx/unsupported.png"),
    version = {major = 2, minor = 3, revision = 0, suffix = "20251010"},
    ethosVersion = {1, 6, 2},
    supportedMspApiVersion = {"12.07", "12.08", "12.09"},
    baseDir = "rfsuite",
    preferences = "rfsuite.user",
    defaultRateProfile = 4,
    watchdogParam = 10
}

config.ethosVersionString = string.format("ETHOS < V%d.%d.%d", table.unpack(config.ethosVersion))

rfsuite.config = config

local performance = {cpuload = 0, freeram = 0, mainStackKB = 0, ramKB = 0, luaRamKB = 0, luaBitmapsRamKB = 0}

rfsuite.performance = performance

rfsuite.ini = assert(loadfile("lib/ini.lua", "t", _ENV))(config)

local userpref_defaults = {
    general = {iconsize = 2, syncname = false, gimbalsupression = 0.85, txbatt_type = 0},
    localizations = {temperature_unit = 0, altitude_unit = 0},
    dashboard = {theme_preflight = "system/default", theme_inflight = "system/default", theme_postflight = "system/default"},
    events = {armflags = true, voltage = true, governor = true, pid_profile = true, rate_profile = true, esc_temp = false, escalertvalue = 90, smartfuel = true, smartfuelcallout = 0, smartfuelrepeats = 1, smartfuelhaptic = false, adj_v = false, adj_f = false},
    switches = {},
    developer = {compile = true, devtools = false, logtofile = false, loglevel = "off", logmsp = false, logobjprof = false, logmspQueue = false, memstats = false, taskprofiler = false, mspexpbytes = 8, apiversion = 2, overlaystats = false, overlaygrid = false, overlaystatsadmin = false},
    timer = {timeraudioenable = false, elapsedalertmode = 0, prealerton = false, postalerton = false, prealertinterval = 10, prealertperiod = 30, postalertinterval = 10, postalertperiod = 30},
    menulastselected = {}
}

local prefs_dir = "SCRIPTS:/" .. rfsuite.config.preferences
os.mkdir(prefs_dir)
local userpref_file = prefs_dir .. "/preferences.ini"

local master_ini = rfsuite.ini.load_ini_file(userpref_file) or {}
local updated_ini = rfsuite.ini.merge_ini_tables(master_ini, userpref_defaults)
rfsuite.preferences = updated_ini

if not rfsuite.ini.ini_tables_equal(master_ini, updated_ini) then rfsuite.ini.save_ini_file(userpref_file, updated_ini) end

rfsuite.config.bgTaskName = rfsuite.config.toolName .. " [Background]"
rfsuite.config.bgTaskKey = "rf2bg"

rfsuite.utils = assert(loadfile("lib/utils.lua"))(rfsuite.config)

rfsuite.app = assert(loadfile("app/app.lua"))(rfsuite.config)

rfsuite.tasks = assert(loadfile("tasks/tasks.lua"))(rfsuite.config)

rfsuite.flightmode = {current = "preflight"}
rfsuite.utils.session()

rfsuite.simevent = {telemetry_state = true}

function rfsuite.version()
    local v = rfsuite.config.version
    return {version = string.format("%d.%d.%d-%s", v.major, v.minor, v.revision, v.suffix), major = v.major, minor = v.minor, revision = v.revision, suffix = v.suffix}
end

local function unsupported_tool()
    return {
        name = rfsuite.config.toolName,
        icon = rfsuite.config.icon_unsupported,
        create = function() end,
        wakeup = function() lcd.invalidate() end,
        paint = function()
            local w, h = lcd.getWindowSize()
            lcd.color(lcd.RGB(255, 255, 255, 1))
            lcd.font(FONT_M)
            local msg = rfsuite.config.ethosVersionString
            local tw, th = lcd.getTextSize(msg)
            lcd.drawText((w - tw) / 2, (h - th) / 2, msg)
        end,
        close = function() end
    }
end

local function unsupported_i18n()
    return {
        name = rfsuite.config.toolName,
        icon = rfsuite.config.icon_unsupported,
        create = function() end,
        wakeup = function() lcd.invalidate() end,
        paint = function()
            local w, h = lcd.getWindowSize()
            lcd.color(lcd.RGB(255, 255, 255, 1))
            lcd.font(FONT_M)
            local msg = "i18n not compiled - download a release version"
            local tw, th = lcd.getTextSize(msg)
            lcd.drawText((w - tw) / 2, (h - th) / 2, msg)
        end,
        close = function() end
    }
end

local function register_main_tool() system.registerSystemTool({event = rfsuite.app.event, name = rfsuite.config.toolName, icon = rfsuite.config.icon, create = rfsuite.app.create, wakeup = rfsuite.app.wakeup, paint = rfsuite.app.paint, close = rfsuite.app.close}) end

local function register_bg_task() system.registerTask({name = rfsuite.config.bgTaskName, key = rfsuite.config.bgTaskKey, wakeup = rfsuite.tasks.wakeup, event = rfsuite.tasks.event, init = rfsuite.tasks.init, read = rfsuite.tasks.read, write = rfsuite.tasks.write}) end

local function load_widget_cache(cachePath)
    local loadf, loadErr = loadfile(cachePath)
    if not loadf then
        rfsuite.utils.log("[cache] loadfile failed: " .. tostring(loadErr), "info")
        return nil
    end
    local ok, cached = pcall(loadf)
    if not ok then
        rfsuite.utils.log("[cache] execution failed: " .. tostring(cached), "info")
        return nil
    end
    if type(cached) ~= "table" then
        rfsuite.utils.log("[cache] unexpected content; rebuilding", "info")
        return nil
    end
    rfsuite.utils.log("[cache] Loaded widget list from cache", "info")
    return cached
end

local function build_widget_cache(widgetList, cacheFile)
    rfsuite.utils.createCacheFile(widgetList, cacheFile, true)
    rfsuite.utils.log("[cache] Created new widgets cache file", "info")
end

local function register_widgets(widgetList)
    rfsuite.widgets = {}
    local dupCount = {}

    for _, v in ipairs(widgetList) do
        if v.script then
            local path = "widgets/" .. v.folder .. "/" .. v.script
            local scriptModule = assert(loadfile(path))(config)

            local base = v.varname or v.script:gsub("%.lua$", "")
            if rfsuite.widgets[base] then
                dupCount[base] = (dupCount[base] or 0) + 1
                base = string.format("%s_dup%02d", base, dupCount[base])
            end
            rfsuite.widgets[base] = scriptModule

            system.registerWidget({
                name = v.name,
                key = v.key,
                event = scriptModule.event,
                create = scriptModule.create,
                paint = scriptModule.paint,
                wakeup = scriptModule.wakeup,
                build = scriptModule.build,
                close = scriptModule.close,
                configure = scriptModule.configure,
                read = scriptModule.read,
                write = scriptModule.write,
                persistent = scriptModule.persistent or false,
                menu = scriptModule.menu,
                title = scriptModule.title
            })
        end
    end
end

local function init()
    local cfg = rfsuite.config

    if not rfsuite.utils.ethosVersionAtLeast() then
        system.registerSystemTool(unsupported_tool())
        return
    end

    local isCompiledCheck = "@i18n(iscompiledcheck)@"
    if isCompiledCheck ~= "true" then
        system.registerSystemTool(unsupported_i18n())
    else
        register_main_tool()
    end

    register_bg_task()

    local cacheFile = "widgets.lua"
    local cachePath = "cache/" .. cacheFile
    local widgetList = load_widget_cache(cachePath)

    if not widgetList then
        widgetList = rfsuite.utils.findWidgets()
        build_widget_cache(widgetList, cacheFile)
    end

    register_widgets(widgetList)
end

return {init = init}
