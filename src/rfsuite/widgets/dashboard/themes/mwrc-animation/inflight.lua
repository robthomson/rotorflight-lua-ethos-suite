--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local tonumber = tonumber
local floor = math.floor
local format = string.format
local min = math.min
local max = math.max
local math_sin = math.sin

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()

-- Pre-cached Render Colors to Prevent GC Lag
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

local THEME_DEFAULTS = {throttle_max = 100, rpm_min = 0, rpm_max = 2500, bec_min = 6.5, bec_warn = 8.0, bec_max = 12.0, esctemp_warn = 110, esctemp_max = 150}

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

local function drawVerticalBatteryBar(x, y, w, h, percent, fillbgcolor, fillcolor, accentcolor, frameThickness, cappaddingtop)
    fillcolor = fillcolor or colorMode.fillcolor
    fillbgcolor = fillbgcolor or colorMode.fillbgcolor
    accentcolor = accentcolor or colorMode.accentcolor

    cappaddingtop = cappaddingtop or 0
    local capH = min(max(4, floor(h * 0.05)), floor(h * 0.15))
    local capW = max(4, floor(w * 0.45))
    local capX = x + floor((w - capW) / 2)
    local capY = y + cappaddingtop

    lcd.color(accentcolor)
    lcd.drawFilledRectangle(capX, capY, capW, capH)

    local bodyY = capY + capH + 4
    local bodyH = (y + h) - bodyY

    local segments = 10
    local gap = 3
    local segH = floor((bodyH - (gap * (segments - 1))) / segments)

    local activeSegs = floor((percent or 0) * segments + 0.5)
    local curY = bodyY + bodyH - segH

    local isCrit = (fillcolor == colorMode.fillcritcolor)
    local activeFillColor = getStrobeColor(fillcolor, isCrit) or fillcolor

    for i = 1, segments do
        if i <= activeSegs then
            lcd.color(activeFillColor)
            lcd.drawFilledRectangle(x, curY, w, segH)
        else
            lcd.color(rc.dim)
            lcd.drawRectangle(x, curY, w, segH, 1)
        end
        curY = curY - segH - gap
    end

    lcd.color(accentcolor)
    lcd.drawLine(x - 4, bodyY, x + 2, bodyY)
    lcd.drawLine(x - 4, bodyY, x - 4, bodyY + 6)
    lcd.drawLine(x + w + 4, bodyY + bodyH, x + w - 2, bodyY + bodyH)
    lcd.drawLine(x + w + 4, bodyY + bodyH, x + w + 4, bodyY + bodyH - 6)

    local midY = bodyY + floor(bodyH / 2)
    lcd.color(fillbgcolor)
    lcd.drawFilledRectangle(x - 2, midY, w + 4, 2)
end

local function drawCyberBracket(x, y, w, h, style)
    x = x + (style.insetleft or style.inset or 0)
    y = y + (style.insettop or style.inset or 0)
    w = w - (style.insetleft or style.inset or 0) - (style.insetright or style.inset or 0)
    h = h - (style.insettop or style.inset or 0) - (style.insetbottom or style.inset or 0)

    local thickness = style.borderwidth or 2
    local bLen = math.min(16, floor(w * 0.2))
    local chamfer = math.min(6, floor(h * 0.15))

    lcd.color(style.bordercolor or colorMode.accentcolor)
    
    for i = 0, thickness - 1 do
        lcd.drawLine(x + bLen, y + i, x + chamfer, y + i)
        lcd.drawLine(x + chamfer, y + i, x + i, y + chamfer)
        lcd.drawLine(x + i, y + chamfer, x + i, y + bLen)

        lcd.drawLine(x + w - bLen, y + i, x + w - chamfer, y + i)
        lcd.drawLine(x + w - chamfer, y + i, x + w - i, y + chamfer)
        lcd.drawLine(x + w - i, y + chamfer, x + w - i, y + bLen)

        lcd.drawLine(x + bLen, y + h - i, x + chamfer, y + h - i)
        lcd.drawLine(x + chamfer, y + h - i, x + i, y + h - chamfer)
        lcd.drawLine(x + i, y + h - chamfer, x + i, y + h - bLen)

        lcd.drawLine(x + w - bLen, y + h - i, x + w - chamfer, y + h - i)
        lcd.drawLine(x + w - chamfer, y + h - i, x + w - i, y + h - chamfer)
        lcd.drawLine(x + w - i, y + h - chamfer, x + w - i, y + h - bLen)
    end
end

local function rightStackWakeup(box, telemetry)
    local c = box._cache or {}
    local session = rfsuite.session
    local telemetryActive = session and session.telemetryState and session.isConnected
    
    if telemetryActive and session.timer then
        c._flightSeconds = session.timer.live or 0
    elseif c._flightSeconds == nil then
        c._flightSeconds = 0
    end
    
    if c._flightSeconds > 0 then
        c.flightTime = format("%02d:%02d", floor(c._flightSeconds / 60), floor(c._flightSeconds % 60))
    else
        c.flightTime = "00:00"
    end

    local getSensor = telemetry and telemetry.getSensor
    local fuelRaw = getSensor and getSensor("smartfuel")
    if fuelRaw ~= nil then
        if fuelRaw == 0 and (c._lastFuelRaw or 0) > 5 then
            fuelRaw = c._lastFuelRaw
        else
            c._lastFuelRaw = fuelRaw
        end
        
        c.fuelPercent = max(0, min(1, fuelRaw / 100))
        c._fuelHasValue = true
    elseif not c._fuelHasValue then
        c.fuelPercent = 0
    end
    
    c.fuelFillColor = rc.green
    if c.fuelPercent <= 0.25 then c.fuelFillColor = rc.red
    elseif c.fuelPercent <= 0.50 then c.fuelFillColor = rc.amber end

    local govRaw = getSensor and getSensor("governor")
    c.isArmed = false
    if govRaw ~= nil then
        if govRaw > 0 and govRaw < 5 then c.isArmed = true end
        c.governorText = rfsuite.utils.getGovernorState(govRaw)
    else
        c.governorText = utils.getPulsingDots(box, "_govDots")
    end
    c.governorColor = utils.resolveThresholdColor(c.governorText, box, "textcolor", "textcolor", box.rs_govthresholds)

    return c
end

local function rightStackPaint(x, y, w, h, box, c)
    c = c or {}
    
    box.rs_bgstyle.bordercolor = c.isArmed and rc.cyan or rc.amber
    drawCyberBracket(x, y, w, h, box.rs_bgstyle)

    local rowH = h / 10

    utils.box(x, y + box.rs_flightoffsety, w, rowH * 2,
        "FLIGHT TIME", "bottom", "center", box.rs_flighttitlefont, box.rs_flighttitlespacing, box.rs_titlecolor,
        nil, nil, nil, nil, box.rs_flighttitlepaddingbottom,
        c.flightTime, nil, box.rs_flightfont, "center", box.rs_textcolor,
        nil, nil, nil, box.rs_flightvaluepaddingtop, box.rs_flightvaluepaddingbottom,
        nil)

    local fuelY = y + rowH * 2
    local fuelH = floor(rowH * 5.5 + 0.5)

    local safeFuelColor = c.fuelFillColor or colorMode.fillcolor
    drawVerticalBatteryBar(x + box.rs_fuelgaugepaddingleft, fuelY + box.rs_fuelgaugepaddingtop, w - box.rs_fuelgaugepaddingleft, fuelH - box.rs_fuelgaugepaddingtop, c.fuelPercent or 0, box.rs_fuelfillbgcolor, safeFuelColor, box.rs_fuelaccentcolor, box.rs_fuelframethickness, box.rs_fuelcappaddingtop)

    local govY = fuelY + fuelH
    local govH = (y + h) - govY
    local govBgH = govH - 8
    local govBgY = govY + box.rs_govbgoffsety
    
    box.rs_govbgstyle.bordercolor = box.rs_bgstyle.bordercolor
    drawCyberBracket(x, govBgY, w, govBgH, box.rs_govbgstyle)

    utils.box(x, govY + box.rs_govoffsety, w, govBgH,
        "GOVERNOR", "bottom", "center", box.rs_govfont, box.rs_govtitlespacing, box.rs_titlecolor,
        nil, nil, nil, nil, box.rs_govtitlepaddingbottom,
        c.governorText, nil, box.rs_govfont, "center", c.governorColor,
        nil, nil, nil, nil, box.rs_govvaluepaddingbottom,
        nil)
end

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
    ls_full = {font = "FONT_XXL", advfont = "FONT_L", thickness = 24, maxfont = "FONT_L", tilefont = "FONT_XXL", govfont = "FONT_STD", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},
    ls_std = {font = "FONT_XL", advfont = "FONT_STD", thickness = 20, maxfont = "FONT_STD", tilefont = "FONT_XL", govfont = "FONT_STD", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},
    ms_full = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 14, maxfont = "FONT_S", tilefont = "FONT_XL", govfont = "FONT_STD", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},
    ms_std = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 12, maxfont = "FONT_S", tilefont = "FONT_L", govfont = "FONT_S", tiletitlespacing = 3, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0},
    ss_full = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 17, maxfont = "FONT_S", tilefont = "FONT_XL", govfont = "FONT_STD", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},
    ss_std = {font = "FONT_XL", advfont = "FONT_STD", thickness = 15, maxfont = "FONT_S", tilefont = "FONT_L", govfont = "FONT_S", tiletitlespacing = 3, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

local pageBgColor = colorMode.bgcolor
local layout = {cols = 12, rows = 10, padding = 0, bgcolor = pageBgColor}

local screenBorderStyle = {
    enabled = false,
    bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
    borderwidth = 5,
    inset = 0
}

local header_layout = utils.standardHeaderLayout(headeropts)
local topbarShiftY = 4
if header_layout and header_layout.height then
    header_layout.height = header_layout.height + topbarShiftY
end

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

local function buildBoxes(W)
    local optionKey = getThemeOptionKey(W)
    local opts = themeOptions[optionKey] or themeOptions.ms_std
    local compactWindow = optionKey == nil or optionKey == "ls_std" or optionKey == "ms_std" or optionKey == "ss_std"
    local arcTitleFont = compactWindow and "FONT_S" or "FONT_STD"
    local arcMaxFont = compactWindow and opts.maxfont or "FONT_L"
    local governorFont = compactWindow and "FONT_S" or opts.govfont
    local governorTitleSpacing = compactWindow and 5 or opts.tiletitlespacing
    local governorTitlePaddingBottom = compactWindow and 0 or 3
    local governorValuePaddingBottom = compactWindow and 0 or -5

    local governorDisarmedTileBg = {
        bordercolor = rc.red,
        borderwidth = 2,
        roundradius = 6,
        inset = 4,
        insettop = 4,
        insetbottom = 0,
        insetleft = -9,
        insetright = -5,
        contentpadding = 1
    }

    local arcGroupTileBg = {
        bordercolor = rc.cyan,
        borderwidth = 2,
        roundradius = 6,
        inset = 4,
        insettop = 11,
        insetleft = 24,
        insetright = -8,
        insetbottom = 8,
        contentpadding = 1
    }

    local rightStackTileBg = {
        bordercolor = rc.cyan,
        borderwidth = 2,
        roundradius = 6,
        inset = 4,
        insettop = 11,
        insetleft = -9,
        insetright = -5,
        insetbottom = 8,
        contentpadding = 1
    }

    return {
        {
            col = 1, row = 1, colspan = 12, rowspan = 10,
            type = "func", subtype = "func",
            wakeup = function() return {} end,
            paint = paintCyberBackground
        },
        {
            -- CONTEXT AWARE LEFT BRACKET
            col = 1, row = 1, colspan = 9, rowspan = 10, offsetx = 0,
            type = "func", subtype = "func",
            wakeup = function(box, telemetry)
                local c = box._cache or {}
                c.isArmed = false
                if telemetry and telemetry.getSensor then
                    local gov = telemetry.getSensor("governor")
                    if gov ~= nil then
                        if gov > 0 and gov < 5 then c.isArmed = true end
                    end
                end
                box._cache = c
                return c
            end,
            paint = function(x, y, w, h, box, cache)
                local style = arcGroupTileBg
                style.bordercolor = (cache and cache.isArmed) and rc.cyan or rc.amber
                drawCyberBracket(x, y, w, h, style)
            end
        },
        {
            col = 11, row = 1, colspan = 2, rowspan = 10,
            offsetx = -30, offsety = 0,
            type = "func", subtype = "func", wakeupinterval = 0.5,
            wakeup = rightStackWakeup, paint = rightStackPaint,
            rs_bgstyle = rightStackTileBg, rs_govbgstyle = governorDisarmedTileBg,
            rs_titlecolor = colorMode.titlecolor, rs_textcolor = colorMode.textcolor, fillcolor = colorMode.fillcolor,
            rs_flightoffsety = 10, rs_flighttitlefont = "FONT_S", rs_flighttitlespacing = opts.tiletitlespacing, rs_flighttitlepaddingbottom = 6, rs_flightfont = opts.tilefont, rs_flightvaluepaddingtop = opts.tilevaluepaddingtop, rs_flightvaluepaddingbottom = opts.tilevaluepaddingbottom,
            rs_fuelbgcolor = "transparent", rs_fuelfillbgcolor = rc.dim, rs_fuelaccentcolor = colorMode.accentcolor, rs_fuelgaugepaddingleft = -4, rs_fuelgaugepaddingtop = -16, rs_fuelcappaddingtop = 22, rs_fuelframethickness = 3, rs_fuelfont = "FONT_XXL", rs_fuelvaluepaddingleft = 13, rs_fuelvaluepaddingtop = 6, rs_fuelvaluepaddingbottom = -40,
            rs_fuelthresholds = {{value = 25, fillcolor = rc.red}, {value = 50, fillcolor = rc.amber}},
            rs_overlayfont = "FONT_STD", rs_voltageoffsety = 8, rs_celloffsety = 34, rs_consumedoffsety = 60,
            rs_govbgoffsety = 0, rs_govoffsety = -3, rs_govfont = governorFont, rs_govtitlespacing = governorTitleSpacing, rs_govtitlepaddingbottom = governorTitlePaddingBottom, rs_govvaluepaddingbottom = governorValuePaddingBottom,
            rs_govthresholds = {
                {value = "DISARMED", textcolor = rc.green}, {value = "OFF", textcolor = rc.amber}, {value = "IDLE", textcolor = rc.amber}, {value = "SPOOLUP", textcolor = rc.red}, {value = "RECOVERY", textcolor = rc.amber}, {value = "ACTIVE", textcolor = rc.red}, {value = "@i18n(widgets.governor.THR-OFF)@", textcolor = rc.green}
            }
        },
        {
            -- SPREAD GAUGE 1: HEADSPEED
            col = 7, row = 2, colspan = 4, rowspan = 7,
            offsetx = -15, offsety = 10, 
            type = "func", subtype = "func", wakeup = wakeAesGauge, paint = paintAesGauge,
            source = "rpm", arcmax = true,
            title = "HEADSPEED", titlepos = "bottom", titlefont = arcTitleFont,
            min = 0, max = getThemeValue("rpm_max"), thickness = math.max(3, math.floor(opts.thickness * 0.4)), 
            font = "FONT_XL", maxfont = arcMaxFont,
            thresholds = {{value = getThemeValue("rpm_min"), fillcolor = rc.cyan}, {value = getThemeValue("rpm_max"), fillcolor = rc.green}, {value = 10000, fillcolor = rc.red}}
        },
        {
            -- SPREAD GAUGE 2: THROTTLE (Dropped exactly 20px lower to clear Headspeed)
            col = 4, row = 6, colspan = 3, rowspan = 5,
            offsetx = 5, offsety = 15, 
            type = "func", subtype = "func", wakeup = wakeAesGauge, paint = paintAesGauge,
            source = "throttle_percent", arcmax = true,
            title = "THROTTLE", titlepos = "bottom", titlefont = arcTitleFont,
            min = 0, max = getThemeValue("throttle_max"), thickness = math.max(3, math.floor(opts.thickness * 0.3)), 
            font = "FONT_XL", maxfont = arcMaxFont,
            thresholds = {{value = 70, fillcolor = rc.green}, {value = 85, fillcolor = rc.amber}, {value = 100, fillcolor = rc.red}}
        },
        {
            -- SPREAD GAUGE 3: ESC TEMP
            col = 1, row = 1, colspan = 4, rowspan = 5,
            offsetx = 5, offsety = 20, 
            type = "func", subtype = "func", wakeup = wakeAesGauge, paint = paintAesGauge,
            source = "temp_esc", arcmax = true,
            title = "ESC TEMP", titlepos = "bottom", titlefont = arcTitleFont,
            min = 0, max = getThemeValue("esctemp_max"), thickness = math.max(3, math.floor(opts.thickness * 0.4)), 
            font = "FONT_XL", maxfont = arcMaxFont,
            thresholds = {{value = getThemeValue("esctemp_warn"), fillcolor = rc.amber}, {value = getThemeValue("esctemp_max"), fillcolor = rc.red}, {value = 155, fillcolor = rc.red}}
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

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, screenBorderStyle = screenBorderStyle, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.8}}