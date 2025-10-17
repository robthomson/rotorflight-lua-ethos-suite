--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local armingDisableFlagsToString = rfsuite.utils.armingDisableFlagsToString

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
        cfg.font = getParam(box, "font")
        cfg.valuealign = getParam(box, "valuealign")
        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.novalue = getParam(box, "novalue") or "-"
        cfg.unit = nil
        cfg.defaultTextColor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        box._cfg = cfg
    end
    return box._cfg
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local telemetry = rfsuite.tasks.telemetry
    local value = telemetry and telemetry.getSensor("armflags")
    local disableflags = telemetry and telemetry.getSensor("armdisableflags")

    local displayValue
    local showReason = false

    if disableflags ~= nil and armingDisableFlagsToString then
        disableflags = math.floor(disableflags)
        local reason = armingDisableFlagsToString(disableflags)
        if reason and reason ~= "OK" then
            displayValue = reason
            showReason = true
        end
    end

    if not showReason then
        if value ~= nil then
            if value == 1 or value == 3 then
                displayValue = "@i18n(ARMED)@"
            else
                displayValue = "@i18n(DISARMED)@"
            end
        end
    end

    if displayValue == nil and value == nil and disableflags == nil then
        local maxDots = 3
        box._dotCount = ((box._dotCount or 0) + 1) % (maxDots + 1)
        displayValue = string.rep(".", box._dotCount)
        if displayValue == "" then displayValue = "." end
    elseif displayValue == nil then
        displayValue = cfg.novalue
    end

    box._dynamicTextColor = utils.resolveThresholdColor(displayValue, box, "textcolor", "textcolor") or cfg.defaultTextColor

    box._currentDisplayValue = displayValue
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}
    local textColor = box._dynamicTextColor or c.defaultTextColor

    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, box._currentDisplayValue, c.unit, c.font, c.valuealign, textColor, c.valuepadding,
        c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, c.bgcolor)
end

render.scheduler = 0.5

return render
