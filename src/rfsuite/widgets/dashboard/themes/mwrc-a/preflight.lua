--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local tonumber = tonumber
local math = math
local math_sin = math.sin

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()

-- Pre-cached Render Colors for Zero-Lag Performance
local rc = {
    strobeBright = lcd.RGB(255, 30, 30),
    strobeDark = lcd.RGB(60, 0, 0),
    amber = lcd.RGB(255, 170, 0),
    red = lcd.RGB(255, 0, 60),
    cyan = lcd.RGB(0, 240, 255),
    green = lcd.RGB(57, 255, 20),
    dim = lcd.RGB(30, 45, 60),
    bg = lcd.RGB(5, 8, 14),           
    panel = lcd.RGB(12, 18, 28),
    white = lcd.RGB(230, 240, 255)
}

-- Force Cyberpunk Neon Palette
local colorMode = {
    bgcolor = rc.bg,           
    tbbgcolor = rc.panel,       
    headerbgcolor = "transparent",     
    titlecolor = rc.cyan,     
    textcolor = rc.white,    
    fillcolor = rc.green,      
    fillwarncolor = rc.amber,  
    fillcritcolor = rc.red,   
    accentcolor = rc.cyan,    
    rssifillbgcolor = rc.cyan,
    fillbgcolor = rc.dim      
}

local theme_section = "system/mwrc"

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 2500, bec_min = 6.5, bec_warn = 8.0, bec_max = 10.0, esctemp_warn = 110, esctemp_max = 150}

local function getThemeValue(key)
    if key == "tx_min" or key == "tx_warn" or key == "tx_max" then
        if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
            local val = rfsuite.preferences.general[key]
            if val ~= nil then return tonumber(val) end
        end
    end

    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local val = rfsuite.session.modelPreferences[theme_section][key]
        val = tonumber(val)
        if val ~= nil then return val end
    end
    return THEME_DEFAULTS[key]
end

local function getThemeOptionKey(W)
    return utils.getDashboardThemeOptionKey(W)
end

local themeOptions = {
    ls_full = {font = "FONT_XXL", advfont = "FONT_STD", titlefont = "FONT_XS", arctitlefont = "FONT_STD", brfont = "FONT_XL", tilefont = "FONT_XL", govfont = "FONT_XL", smartfont = "FONT_XXL", smartvaluefont = "FONT_XL", smartadvfont = "FONT_L", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 3, flightvaluepaddingbottom = 0, thickness = 32, titlepaddingbottom = 25, valuepaddingleft = 25, valuepaddingtop = 20},
    ls_std = {font = "FONT_XL", advfont = "FONT_STD", titlefont = "FONT_XS", arctitlefont = "FONT_STD", brfont = "FONT_L", tilefont = "FONT_STD", govfont = "FONT_STD", smartfont = "FONT_XL", smartvaluefont = "FONT_L", smartadvfont = "FONT_STD", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 18, titlepaddingbottom = 18, valuepaddingleft = 55, valuepaddingtop = 5},
    ms_full = {font = "FONT_XXL", advfont = "FONT_STD", titlefont = "FONT_XS", arctitlefont = "FONT_S", brfont = "FONT_L", tilefont = "FONT_STD", govfont = "FONT_STD", smartfont = "FONT_XL", smartvaluefont = "FONT_L", smartadvfont = "FONT_STD", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 19, titlepaddingbottom = 16, valuepaddingleft = 20, valuepaddingtop = 10},
    ms_std = {font = "FONT_XL", advfont = "FONT_S", titlefont = "FONT_XS", arctitlefont = "FONT_S", brfont = "FONT_STD", tilefont = "FONT_S", govfont = "FONT_S", smartfont = "FONT_L", smartvaluefont = "FONT_STD", smartadvfont = "FONT_S", tiletitlespacing = 3, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 14, titlepaddingbottom = 10, valuepaddingleft = 20, valuepaddingtop = 10},
    ss_full = {font = "FONT_XL", advfont = "FONT_STD", titlefont = "FONT_XS", arctitlefont = "FONT_S", brfont = "FONT_XL", tilefont = "FONT_STD", govfont = "FONT_STD", smartfont = "FONT_XL", smartvaluefont = "FONT_L", smartadvfont = "FONT_STD", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 25, titlepaddingbottom = 15, valuepaddingleft = 20, valuepaddingtop = 10},
    ss_std = {font = "FONT_XL", advfont = "FONT_S", titlefont = "FONT_XS", arctitlefont = "FONT_S", brfont = "FONT_L", tilefont = "FONT_S", govfont = "FONT_S", smartfont = "FONT_L", smartvaluefont = "FONT_STD", smartadvfont = "FONT_S", tiletitlespacing = 3, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 14, titlepaddingbottom = 15, valuepaddingleft = 20, valuepaddingtop = 10}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

local layout = {cols = 7, rows = 12, padding = 0, bgcolor = colorMode.bgcolor}

local header_layout = utils.standardHeaderLayout(headeropts)
local topbarShiftY = 4
if header_layout and header_layout.height then
    header_layout.height = header_layout.height + topbarShiftY
end

-- Completely Disabled Outer Screen Border
local screenBorderStyle = {
    enabled = false,
    bordercolor = colorMode.accentcolor,
    backgroundcolor = colorMode.bgcolor,
    borderwidth = 6,
    inset = -1
}

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then txbatt_type = rfsuite.preferences.general.txbatt_type or 0 end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        local headerBgColor = "transparent" 
        for _, box in ipairs(boxes) do
            box.bgcolor = headerBgColor
            box.offsety = (box.offsety or 0) + topbarShiftY
            
            if box.type == "image" then
                box.type = "func"
                box.subtype = "func"
                box.paint = function(x, y, w, h)
                    lcd.font(FONT_L or 0)
                    local t1, t2, t3 = "ETHOS ", "// ", "ROTORFLIGHT"
                    local tw1, _ = lcd.getTextSize(t1)
                    local tw2, _ = lcd.getTextSize(t2)
                    
                    lcd.color(rc.cyan)
                    lcd.drawText(x + 5, y + 4, t1)
                    lcd.color(rc.amber) 
                    lcd.drawText(x + 5 + tw1, y + 4, t2)
                    lcd.color(rc.white)
                    lcd.drawText(x + 5 + tw1 + tw2, y + 4, t3)
                end
            end
        end
        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function getStrobeColor(baseColor, isCritical)
    if isCritical then
        if math.floor(os.clock() * 6) % 2 == 0 then
            return rc.strobeBright 
        else
            return rc.strobeDark
        end
    end
    return baseColor
end

local function wakeAesGauge(box, telemetry)
    local cache = box._cache
    if type(cache) ~= "table" or cache._mode ~= "aes_gauge" then
        cache = {
            _mode = "aes_gauge",
            source = box.source,
            lastVal = -1,
            valText = "0",
            maxVal = -9999,
            color = colorMode.fillcolor
        }
        box._cache = cache
    end

    local val = cache.value or 0
    if telemetry and telemetry.getSensor then
        local raw = telemetry.getSensor(cache.source)
        if raw ~= nil then 
            if raw == 0 and (cache.value or 0) > 5 then
                val = cache.value
            else
                val = raw 
            end
        end
    end
    cache.value = val
    
    if box.arcmax then
        cache.maxVal = math.max(cache.maxVal, val)
    end

    local activeColor = colorMode.fillcolor
    if box.thresholds then
        for _, t in ipairs(box.thresholds) do
            activeColor = t.fillcolor
            if val <= t.value then break end
        end
    end
    cache.color = activeColor

    local displayVal = math.floor(val)
    if cache.lastVal ~= displayVal then
        if box.decimals == 1 then
            cache.valText = string.format("%.1f", val)
        else
            cache.valText = tostring(displayVal)
        end
        cache.lastVal = displayVal
    end

    return cache
end

local function paintAesGauge(x, y, w, h, box, cache)
    if not cache or cache._mode ~= "aes_gauge" then return end
    x, y = utils.applyOffset(x, y, box)
    
    local val = cache.value or 0
    local minV = box.min or 0
    local maxV = box.max or 100
    local pct = math.max(0, math.min(1, (val - minV) / (maxV - minV)))
    
    local cx = x + w / 2
    local cy = y + h / 2 + 10 
    
    local rOuter = math.min(w, h) / 2 - 12
    local thickness = box.thickness or 14
    local rInner = rOuter - thickness
    
    local startAngle = 225
    local endAngle = 135
    local sweep = 270
    
    local curAngle = startAngle + (sweep * pct)
    if curAngle >= 360 then curAngle = curAngle - 360 end
    
    -- Removed the outer dashed tick-mark ring for a cleaner floating arc
    
    utils.drawArc(cx, cy, rOuter, thickness, startAngle, endAngle, colorMode.tbbgcolor)
    
    local safeColor = cache.color or colorMode.fillcolor
    local isCrit = (safeColor == colorMode.fillcritcolor)
    local activeDrawColor = getStrobeColor(safeColor, isCrit) or safeColor

    if pct > 0 then
        utils.drawArc(cx, cy, rOuter, thickness, startAngle, curAngle, activeDrawColor)
    end
    
    local radCur = math.rad(curAngle - 90)
    lcd.color(activeDrawColor)
    for offset = -1, 1 do
        local rOffset = math.rad(curAngle - 90 + offset)
        local nx = cx + math.cos(rOffset) * (rOuter + 6)
        local ny = cy + math.sin(rOffset) * (rOuter + 6)
        lcd.drawLine(cx, cy, nx, ny)
    end
    
    lcd.color(colorMode.bgcolor)
    lcd.drawFilledCircle(cx, cy, rInner - 4)
    lcd.color(activeDrawColor)
    lcd.drawFilledCircle(cx, cy, 3)
    
    local mainFontId = utils.resolveFont(box.font or "FONT_XL", nil)
    if type(mainFontId) == "number" then
        lcd.font(mainFontId)
        lcd.color(colorMode.textcolor)
        local tw, th = lcd.getTextSize(cache.valText)
        lcd.drawText(cx - tw/2, cy + 10, cache.valText)
        
        local subFontId = utils.resolveFont(box.titlefont or "FONT_S", nil)
        if type(subFontId) == "number" and box.title then
            lcd.font(subFontId)
            lcd.color(colorMode.titlecolor)
            local ttw, tth = lcd.getTextSize(box.title)
            lcd.drawText(cx - ttw/2, cy + 10 + th + 2, box.title)
        end
        
        if box.arcmax and cache.maxVal > -9999 then
            lcd.font(utils.resolveFont(box.maxfont or "FONT_S", nil))
            lcd.color(colorMode.fillwarncolor)
            local maxStr = "Max: " .. tostring(math.floor(cache.maxVal))
            local mtw, mth = lcd.getTextSize(maxStr)
            lcd.drawText(cx - mtw/2, cy - rOuter - 15, maxStr)
        end
    end
end

-- =========================================================================
-- VISUAL BOOSTER: ANIMATED CYBER OSCILLOSCOPE SINE WAVE
-- =========================================================================
local function paintCyberBackground(x, y, w, h, box, cache)
    lcd.color(colorMode.bgcolor)
    lcd.drawFilledRectangle(x, y, w, h)

    local time = os.clock()
    
    -- Reactor Pulse Math (Controls the glow intensity)
    local speed = 3.0
    local pulse = (math_sin(time * speed) + 1) / 2 

    -- Calculate pulsating Cyan glow
    local pr = math.floor(5 + (0 - 5) * pulse)
    local pg = math.floor(8 + (200 - 8) * pulse)
    local pb = math.floor(14 + (255 - 14) * pulse)
    
    -- Calculate dimmer pulse for corners and axis
    local dr = math.floor(5 + (25 - 5) * pulse)
    local dg = math.floor(8 + (45 - 8) * pulse)
    local db = math.floor(14 + (60 - 14) * pulse)

    local cy = y + h / 2

    -- Draw pulsating corner ticks to frame the screen
    lcd.color(lcd.RGB(dr, dg, db))
    lcd.drawLine(x + 2, y + 2, x + 14, y + 2)
    lcd.drawLine(x + 2, y + 2, x + 2, y + 14)
    lcd.drawLine(x + w - 2, y + 2, x + w - 14, y + 2)
    lcd.drawLine(x + w - 2, y + 2, x + w - 2, y + 14)
    lcd.drawLine(x + 2, y + h - 2, x + 14, y + h - 2)
    lcd.drawLine(x + 2, y + h - 2, x + 2, y + h - 14)
    lcd.drawLine(x + w - 2, y + h - 2, x + w - 14, y + h - 2)
    lcd.drawLine(x + w - 2, y + h - 2, x + w - 2, y + h - 14)

    -- Draw Center Dashed Axis Line (Oscilloscope Zero-Line)
    for i = x, x + w, 30 do
        lcd.drawLine(i, cy, i + 15, cy)
    end

    -- Sine Wave 1: Slow, Wide Background Wave (Dimmer)
    local amp2 = 50
    local freq2 = 0.015
    local shift2 = time * -2.5
    lcd.color(lcd.RGB(math.floor(pr * 0.3), math.floor(pg * 0.3), math.floor(pb * 0.3)))
    local px2, py2 = x, cy + math_sin((x * freq2) + shift2) * amp2
    for i = x + 4, x + w, 4 do
        local ny2 = cy + math_sin((i * freq2) + shift2) * amp2
        lcd.drawLine(px2, py2, i, ny2)
        px2, py2 = i, ny2
    end

    -- Sine Wave 2: Fast, Tight Foreground Wave (Brighter)
    local amp1 = 25
    local freq1 = 0.035
    local shift1 = time * 6.0
    lcd.color(lcd.RGB(pr, pg, pb))
    local px1, py1 = x, cy + math_sin((x * freq1) + shift1) * amp1
    for i = x + 4, x + w, 4 do
        local ny1 = cy + math.sin((i * freq1) + shift1) * amp1
        lcd.drawLine(px1, py1, i, ny1)
        px1, py1 = i, ny1
    end
end

-- =========================================================================
-- DIGITAL DATA BLOCK FUEL GAUGE FOR PREFLIGHT
-- =========================================================================
local function wakeFuelGauge(box, telemetry)
    local cache = box._cache
    if type(cache) ~= "table" or cache._mode ~= "fuelgauge" then
        cache = {
            _mode = "fuelgauge",
            source = box.source or "smartfuel",
            lastVal = -1,
            valText = "0%"
        }
        box._cache = cache
    end

    local val = cache.value or 0
    if telemetry and telemetry.getSensor then
        local raw = telemetry.getSensor(cache.source)
        if raw ~= nil then 
            if raw == 0 and (cache.value or 0) > 5 then
                val = cache.value
            else
                val = raw 
            end
        end
    end
    cache.value = val

    local displayVal = math.floor(val)
    if cache.lastVal ~= displayVal then
        cache.valText = tostring(displayVal) .. "%"
        cache.lastVal = displayVal
    end

    return cache
end

local function paintFuelGauge(x, y, w, h, box, cache)
    if not cache or cache._mode ~= "fuelgauge" then return end
    x, y = utils.applyOffset(x, y, box)

    local val = cache.value or 0
    local activeColor = colorMode.fillcolor
    if val <= 25 then activeColor = colorMode.fillcritcolor
    elseif val <= 50 then activeColor = colorMode.fillwarncolor
    end

    lcd.color(colorMode.accentcolor)
    lcd.drawRectangle(x + 2, y + 2, w - 4, h - 4, 2)

    local pad = 12
    local ix = x + 4
    local iy = y + 4
    local iw = w - 8
    local ih = h - 8

    local mainFontId = utils.resolveFont(box.font or "FONT_XXL", nil)
    if type(mainFontId) ~= "number" then mainFontId = 0 end
    
    local subFontId = utils.resolveFont("FONT_S", nil)
    if type(subFontId) ~= "number" then subFontId = 0 end

    lcd.font(mainFontId)
    lcd.color(colorMode.textcolor)
    lcd.drawText(ix + pad, iy + pad, cache.valText)

    local tw, th = lcd.getTextSize(cache.valText)

    lcd.font(subFontId)
    lcd.color(colorMode.titlecolor)
    lcd.drawText(ix + pad, iy + ih - 20, "BATTERY STATUS")

    local blocksX = ix + pad + tw + 10
    local blocksY = iy + pad + 10
    local blocksW = (ix + iw - pad) - blocksX
    local blocksH = 14
    local segments = 8
    local gap = 4
    local segW = math.floor((blocksW - (gap * (segments - 1))) / segments)
    
    local activeSegs = math.floor((val / 100) * segments + 0.5)
    local curX = blocksX
    
    local isCrit = (val <= 25)
    local activeFillColor = getStrobeColor(activeColor, isCrit) or activeColor

    for i = 1, segments do
        if i <= activeSegs then
            lcd.color(activeFillColor)
            lcd.drawFilledRectangle(curX, blocksY, segW, blocksH)
        else
            lcd.color(rc.dim)
            lcd.drawRectangle(curX, blocksY, segW, blocksH, 1)
        end
        curX = curX + segW + gap
    end
end
-- =========================================================================

local function buildBoxes(W)
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.ls_full

    return {
        {
            -- Global Cyber Background Layer
            col = 1, row = 1, colspan = 7, rowspan = 12,
            type = "func", subtype = "func",
            wakeup = function() return {} end,
            paint = paintCyberBackground
        },
        {
            col = 1, row = 1, colspan = 3, rowspan = 9,
            type = "image", subtype = "model", imagewidth = 280, imageheight = 300, imagealign = "center",
            bgcolor = "transparent"
        },
        {
            col = 4, row = 9, rowspan = 2, offsety = -15,
            type = "text", subtype = "telemetry", source = "rate_profile", title = "RATES", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, transform = "floor",
            thresholds = {{value = 1.5, textcolor = rc.cyan}, {value = 2.5, textcolor = rc.amber}, {value = 6, textcolor = rc.green}}
        },
        {
            col = 5, row = 9, rowspan = 2, offsety = -15,
            type = "text", subtype = "telemetry", source = "pid_profile", title = "PROFILE", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, transform = "floor",
            thresholds = {{value = 1.5, textcolor = rc.cyan}, {value = 2.5, textcolor = rc.amber}, {value = 6, textcolor = rc.green}}
        },
        {
            col = 6, row = 9, colspan = 2, rowspan = 2, offsetx = -5, offsety = -15,
            type = "time", subtype = "count", title = "FLIGHTS", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.flightvaluepaddingtop, valuepaddingbottom = opts.flightvaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor
        },
        {
            col = 1, row = 10, colspan = 3, rowspan = 3, offsetx = 4, offsety = -1,
            type = "func", subtype = "func", source = "smartfuel",
            wakeup = wakeFuelGauge, paint = paintFuelGauge,
            bgcolor = "transparent", font = opts.smartfont
        },
        {
            col = 4, colspan = 2, row = 1, rowspan = 7, offsetx = 2, offsety = 10,
            type = "func", subtype = "func", wakeup = wakeAesGauge, paint = paintAesGauge,
            source = "bec_voltage", title = "BEC VOLT", titlepos = "bottom", decimals = 1,
            titlepaddingbottom = opts.titlepaddingbottom, valuepaddingtop = 30, font = "FONT_XL", titlefont = opts.arctitlefont, min = getThemeValue("bec_min"), max = getThemeValue("bec_max"),
            thickness = math.max(3, math.floor(opts.thickness * 0.4)),
            thresholds = {{value = 6.5, fillcolor = rc.red}, {value = 6.9, fillcolor = rc.amber}, {value = 10.0, fillcolor = rc.green}}
        },
        {
            col = 4, row = 11, colspan = 2, rowspan = 2, offsety = -10,
            type = "text", subtype = "blackbox", title = "BLACKBOX", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom, decimals = 0,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, transform = "floor",
            thresholds = {{value = 80, textcolor = colorMode.textcolor}, {value = 90, textcolor = rc.amber}, {value = 100, textcolor = rc.red}}
        },
        {
            col = 6, colspan = 2, row = 1, rowspan = 7, offsetx = -8, offsety = 10,
            type = "func", subtype = "func", wakeup = wakeAesGauge, paint = paintAesGauge,
            source = "temp_esc", title = "ESC TEMP", titlepos = "bottom",
            font = "FONT_XL", titlefont = opts.arctitlefont, min = 0, max = getThemeValue("esctemp_max"),
            thickness = math.max(3, math.floor(opts.thickness * 0.4)),
            thresholds = {{value = getThemeValue("esctemp_warn"), fillcolor = rc.amber}, {value = getThemeValue("esctemp_max"), fillcolor = rc.red}, {value = 10000, fillcolor = rc.red}}
        },
        {
            col = 6, row = 11, colspan = 2, rowspan = 2, offsetx = -5, offsety = -10,
            type = "text", subtype = "governor", title = "GOVERNOR", titlepos = "bottom",
            font = opts.govfont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = "DISARMED", textcolor = rc.green}, {value = "OFF", textcolor = rc.amber}, {value = "IDLE", textcolor = rc.amber}, {value = "SPOOLUP", textcolor = rc.red}, {value = "RECOVERY", textcolor = rc.amber}, {value = "ACTIVE", textcolor = rc.red},
                {value = "@i18n(widgets.governor.THR-OFF)@", textcolor = rc.green}
            }
        }
    }
end

local function boxes()
    local config = rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section]
    local W = lcd.getWindowSize()
    if boxes_cache == nil or themeconfig ~= config or lastScreenW ~= W then
        boxes_cache = buildBoxes(W)
        themeconfig = config
        lastScreenW = W
    end
    return boxes_cache
end

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, screenBorderStyle = screenBorderStyle, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.5}}