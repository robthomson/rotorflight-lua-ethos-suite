--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — [https://www.gnu.org/licenses/gpl-3.0.en.html](https://www.gnu.org/licenses/gpl-3.0.en.html)
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local max = math.max
local tonumber = tonumber

local utils = rfsuite.widgets.dashboard.utils
local maxVoltageToCellVoltage = utils.maxVoltageToCellVoltage

local headeropts = utils.getHeaderOptions()

-- Pre-cached Render Colors for Zero-Lag Performance
local rc = {
    bg = lcd.RGB(5, 8, 14),           
    panel = lcd.RGB(12, 18, 28),
    cyan = lcd.RGB(0, 240, 255),
    amber = lcd.RGB(255, 170, 0),
    red = lcd.RGB(255, 0, 60),
    green = lcd.RGB(57, 255, 20),
    white = lcd.RGB(230, 240, 255),
    dim = lcd.RGB(30, 45, 60)
}

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

local pageBgColor = colorMode.bgcolor
local panelBgColor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor

local theme_section = "system/mwrc"

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 2500, bec_min = 6.5, bec_warn = 8.0, bec_max = 12.0, esctemp_warn = 110, esctemp_max = 150}

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
    ls_full = {font = "FONT_XL", valuefont = "FONT_L", titlefont = "FONT_STD", titlepaddingtop = 5, thickness = 24, tilefont = "FONT_XXL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 7, gaugepaddingbottom = 13},
    ls_std  = {font = "FONT_L", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 18, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 10},
    ms_full = {font = "FONT_L", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 16, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 9},
    ms_std  = {font = "FONT_S", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 0, thickness = 12, tilefont = "FONT_L", tiletitlespacing = 3, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 7},
    ss_full = {font = "FONT_L", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 16, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 9},
    ss_std  = {font = "FONT_S", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 0, thickness = 12, tilefont = "FONT_L", tiletitlespacing = 3, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 7}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local last_txbatt_type = nil

local layout = {cols = 12, rows = 12, padding = 0, bgcolor = colorMode.bgcolor}
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
                    
                    lcd.color(colorMode.accentcolor)
                    lcd.drawText(x + 5, y + 4, t1)
                    lcd.color(lcd.RGB(255, 170, 0)) 
                    lcd.drawText(x + 5 + tw1, y + 4, t2)
                    lcd.color(colorMode.textcolor)
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
-- FULL SCREEN WIPE FIX: Obliterates the Inflight screen to stop bleed-through
-- =========================================================================
local function paintCyberBackground(x, y, w, h, box, cache)
    local W, H = lcd.getWindowSize()
    lcd.color(colorMode.bgcolor)
    lcd.drawFilledRectangle(0, 0, W, H)
    
    lcd.color(rc.dim)
    lcd.drawLine(x + 2, y + 2, x + 14, y + 2)
    lcd.drawLine(x + 2, y + 2, x + 2, y + 14)
    lcd.drawLine(x + w - 2, y + 2, x + w - 14, y + 2)
    lcd.drawLine(x + w - 2, y + 2, x + w - 2, y + 14)
    lcd.drawLine(x + 2, y + h - 2, x + 14, y + h - 2)
    lcd.drawLine(x + 2, y + h - 2, x + 2, y + h - 14)
    lcd.drawLine(x + w - 2, y + h - 2, x + w - 14, y + h - 2)
    lcd.drawLine(x + w - 2, y + h - 2, x + w - 2, y + h - 14)
end

local function buildBoxes(W)
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.ls_full

    local gaugeTileBg = {
        backfillcolor = colorMode.bgcolor,
        fillcolor = colorMode.bgcolor,
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        borderwidth = 5,
        roundradius = 8,
        inset = 8,
        contentpadding = 1
    }

    return {
        {
            col = 1, row = 1, colspan = 12, rowspan = 12,
            type = "func", subtype = "func",
            wakeup = function() return {} end,
            paint = paintCyberBackground
        },
        {col = 1, row = 10, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "altitude", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 5, row = 10, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "watts", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 5, row = 7, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "current", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 1, row = 4, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "rpm", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 1, row = 7, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "link", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 9, row = 4, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "smartconsumption", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 5, row = 4, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "smartfuel", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 9, row = 10, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "voltage", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 9, row = 7, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "temp_esc", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        
        {
            col = 5, row = 1, colspan = 4, rowspan = 3,
            type = "time",
            subtype = "flight",
            title = "Flight Time",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.tilefont,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingtop = opts.tilevaluepaddingtop,
            valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor
        },
        {
            col = 9, row = 1, colspan = 4, rowspan = 3,
            type = "time",
            subtype = "total",
            title = "Total Flight Time",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.tilefont,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingtop = opts.tilevaluepaddingtop,
            valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor
        },
        {
            col = 1, row = 1, colspan = 4, rowspan = 3,
            type = "time",
            subtype = "count",
            title = "Flights",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.tilefont,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingtop = opts.tilevaluepaddingtop,
            valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            transform = "floor"
        },
        
        {
            col = 1, row = 10, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "altitude",
            stattype = "max",
            title = "Max Altitude",
            unit = "ft",
            min = 0,
            max = 450,
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor"
        },
        {
            col = 5, row = 10, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "watts",
            stattype = "max",
            title = "Max Watts",
            unit = "W",
            min = 0,
            max = 10000,
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor"
        },
        {
            col = 5, row = 7, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "current",
            stattype = "max",
            title = "Max Amps",
            unit = "A",
            min = 0,
            max = 300,
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor"
        },
        {
            col = 1, row = 4, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "rpm",
            stattype = "max",
            title = "Max Rpm",
            unit = "rpm",
            min = 0,
            max = 5500,
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor"
        },
        {
            col = 1, row = 7, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "link",
            stattype = "min",
            title = "Vfr Min",
            unit = "%",
            min = 0,
            max = 100,
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = 10, fillcolor = colorMode.fillcritcolor},
                {value = 45, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}
            },
            transform = "floor"
        },
        {
            col = 9, row = 4, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "smartconsumption",
            stattype = "max",
            title = "Consumed mAh",
            unit = "mAh",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            min = 0,
            max = 5000,
            thresholds = {
                {value = 2250, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)},
                {value = 4000, fillcolor = colorMode.fillcritcolor}
            },
            transform = "floor"
        },
        {
            col = 5, row = 4, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "smartfuel",
            stattype = "min",
            title = "Battery Remaining",
            unit = "%",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            min = 0,
            max = 100,
            thresholds = {
                {value = 25, fillcolor = colorMode.fillcritcolor},
                {value = 45, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}
            },
            transform = "floor"
        },
        {
            col = 9, row = 10, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "voltage",
            stattype = "min",
            title = "Volts per cell",
            unit = "V",
            min = 3.2,
            max = 4.35,
            gaugevalue = "display",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = 3.70, fillcolor = colorMode.fillcritcolor},
                {value = 3.85, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}
            },
            transform = function(v) return maxVoltageToCellVoltage(v) end,
            decimals = 2
        },
        {
            col = 9, row = 7, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "temp_esc",
            stattype = "max",
            title = "ESC Max Temp",
            unit = "°F",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            min = 0,
            max = getThemeValue("esctemp_max"),
            thresholds = {
                {value = getThemeValue("esctemp_warn"), fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)},
                {value = getThemeValue("esctemp_max"), fillcolor = colorMode.fillcritcolor}
            },
            transform = "floor"
        }
    }
end

local function boxes()
    local W = lcd.getWindowSize()
    if boxes_cache == nil or lastScreenW ~= W then
        boxes_cache = buildBoxes(W)
        lastScreenW = W
    end
    return boxes_cache
end

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, screenBorderStyle = screenBorderStyle, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.5}}