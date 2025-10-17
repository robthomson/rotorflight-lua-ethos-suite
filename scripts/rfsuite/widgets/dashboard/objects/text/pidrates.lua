--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

function render.invalidate(box) box._cfg = nil end

function render.dirty(box)
    if box._lastDisplayValue == nil then
        box._lastDisplayValue = box._currentDisplayValue
        return true
    end
    if box._lastDisplayValue ~= box._currentDisplayValue then
        box._lastDisplayValue = box._currentDisplayValue
        return true
    end
    return false
end

local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0
    local cfg = box._cfg
    if (not cfg) or (cfg._theme_version ~= theme_version) or (cfg._param_version ~= param_version) then
        cfg = {}
        cfg._theme_version = theme_version
        cfg._param_version = param_version

        cfg.object = getParam(box, "object")
        if cfg.object == "pid" then
            cfg.source = "pid_profile"
        elseif cfg.object == "rates" then
            cfg.source = "rate_profile"
        else
            cfg.source = nil
        end

        cfg.title = getParam(box, "title")
        cfg.titlepos = getParam(box, "titlepos")
        cfg.titlealign = getParam(box, "titlealign")
        cfg.titlefont = getParam(box, "titlefont")
        cfg.titlespacing = getParam(box, "titlespacing")
        cfg.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.titlepadding = getParam(box, "titlepadding")
        cfg.titlepaddingleft = getParam(box, "titlepaddingleft")
        cfg.titlepaddingright = getParam(box, "titlepaddingright")
        cfg.titlepaddingtop = getParam(box, "titlepaddingtop")
        cfg.titlepaddingbottom = getParam(box, "titlepaddingbottom")

        cfg.font = getParam(box, "font") or FONT_L
        cfg.valuealign = getParam(box, "valuealign")
        cfg.defaultTextColor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        cfg.fillcolor = utils.resolveThemeColor("fillcolor", getParam(box, "fillcolor"))
        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")

        cfg.rowalign = getParam(box, "rowalign")
        cfg.rowpadding = getParam(box, "rowpadding")
        cfg.rowpaddingleft = getParam(box, "rowpaddingleft")
        cfg.rowpaddingright = getParam(box, "rowpaddingright")
        cfg.rowpaddingtop = getParam(box, "rowpaddingtop")
        cfg.rowpaddingbottom = getParam(box, "rowpaddingbottom")
        cfg.rowspacing = getParam(box, "rowspacing")
        cfg.rowfont = getParam(box, "rowfont")
        cfg.highlightlarger = getParam(box, "highlightlarger")
        cfg.profilecount = math.max(1, math.min(6, tonumber(getParam(box, "profilecount")) or 6))

        cfg.novalue = getParam(box, "novalue") or "-"
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.fontList = (utils.getFontListsForResolution().value_default) or {}

        box._cfg = cfg
    end
    return box._cfg
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local telemetry = rfsuite.tasks.telemetry
    local value
    if telemetry and cfg.source then value = select(1, telemetry.getSensor(cfg.source)) end
    if value == nil then value = getParam(box, "value") end

    local displayValue
    if value == nil then

        local maxDots = 3
        box._dotCount = ((box._dotCount or 0) + 1) % (maxDots + 1)
        displayValue = string.rep(".", box._dotCount)
        if displayValue == "" then displayValue = "." end
    else
        displayValue = utils.transformValue(value, box)
    end

    local index = tonumber(displayValue)
    if index == nil or index < 1 or index > 6 then if value ~= nil then displayValue = cfg.novalue end end

    local dynColor = utils.resolveThresholdColor(value, box, "textcolor", "textcolor") or cfg.defaultTextColor

    box._currentDisplayValue = displayValue
    box._dynamicTextColor = dynColor
    box._isLoadingDots = (value == nil)
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, nil, nil, c.font, c.valuealign, box._dynamicTextColor or c.defaultTextColor, c.valuepadding,
        c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, c.bgcolor)

    local fontList = c.fontList or {}
    local baseFont = _G[c.rowfont] or _G[c.font] or FONT_L

    local baseIndex
    for i, f in ipairs(fontList) do
        if f == baseFont then
            baseIndex = i;
            break
        end
    end
    local largerFont = baseFont
    if c.highlightlarger and baseIndex and baseIndex < #fontList then largerFont = fontList[baseIndex + 1] end

    lcd.font(baseFont)
    local _, baseHeight = lcd.getTextSize("8")

    local rowpadding = c.rowpadding or 0
    local padLeft = c.rowpaddingleft or rowpadding
    local padRight = c.rowpaddingright or rowpadding
    local padTop = c.rowpaddingtop or rowpadding
    local padBottom = c.rowpaddingbottom or rowpadding

    local rowY = y + padTop
    if c.title then rowY = y + h - baseHeight - padBottom end

    local totalWidth = w - padLeft - padRight
    local count = c.profilecount or 6
    local spacing = c.rowspacing or (totalWidth / count)
    local align = c.rowalign or "center"

    local totalContentWidth = spacing * count
    local startX
    if align == "left" then
        startX = x + padLeft
    elseif align == "right" then
        startX = x + w - padRight - totalContentWidth
    else
        startX = x + padLeft + (totalWidth - totalContentWidth) / 2
    end

    local activeIndex = tonumber(box._currentDisplayValue)

    for i = 1, count do
        local cx = startX + (i - 1) * spacing
        local text = tostring(i)
        local isActive = (activeIndex ~= nil) and (activeIndex == i)
        local currentFont = (isActive and c.highlightlarger and largerFont) or baseFont

        lcd.font(currentFont)
        local tw, th = lcd.getTextSize(text)
        local yOffset = (isActive and c.highlightlarger and largerFont ~= baseFont) and (baseHeight - th) / 2 or 0

        if isActive then
            lcd.color(c.fillcolor or c.defaultTextColor or WHITE)
        else
            lcd.color(c.defaultTextColor or WHITE)
        end

        lcd.drawText(cx + (spacing - tw) / 2, rowY + yOffset, text)
    end
end

return render

