--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local eraseDataflashGo = false

function render.invalidate(box) box._cfg = nil end

function render.dirty(box)
    if not rfsuite.session.telemetryState then return false end
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

local function eraseBlackboxAsk()
    local buttons = {
        {
            label = "@i18n(app.btn_ok)@",
            action = function()
                eraseDataflashGo = true;
                return true
            end
        }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }

    form.openDialog({title = "@i18n(widgets.bbl.erase_dataflash)@", message = "@i18n(widgets.bbl.erase_dataflash)@" .. "?", buttons = buttons, options = TEXT_LEFT})
end

local function eraseDataflash()
    isErase = true
    progress = form.openProgressDialog("@i18n(app.msg_saving)@", "@i18n(app.msg_saving_to_fbl)@")
    progress:value(0)
    progress:closeAllowed(false)
    progressCounter = 0

    local message = {command = 72, processReply = function() isErase = false end}
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0
    local cfg = box._cfg
    if (not cfg) or cfg._theme_version ~= theme_version or cfg._param_version ~= param_version then
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

        cfg.decimals = getParam(box, "decimals") or 1
        cfg.novalue = getParam(box, "novalue") or "-"
        cfg.unit = getParam(box, "unit")
        cfg.font = getParam(box, "font")
        cfg.valuealign = getParam(box, "valuealign")
        cfg.defaultTextColor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))

        box._cfg = cfg
    end
    return box._cfg
end

function render.wakeup(box)

    local cfg = ensureCfg(box)

    local totalSize = rfsuite.session.bblSize
    local usedSize = rfsuite.session.bblUsed

    local displayValue
    local percentUsed

    if totalSize and usedSize then
        local usedMB = usedSize / (1024 * 1024)
        local totalMB = totalSize / (1024 * 1024)
        percentUsed = totalSize > 0 and (usedSize / totalSize) * 100 or 0

        local transformedUsed = utils.transformValue(usedMB, box)
        local transformedTotal = utils.transformValue(totalMB, box)
        displayValue = string.format("%." .. cfg.decimals .. "f/%." .. cfg.decimals .. "f %s", transformedUsed, transformedTotal, "@i18n(app.modules.fblstatus.megabyte)@")
    else
        if totalSize == nil and usedSize == nil then

            local maxDots = 3
            box._dotCount = ((box._dotCount or 0) + 1) % (maxDots + 1)
            displayValue = string.rep(".", box._dotCount)
            if displayValue == "" then displayValue = "." end
        else
            displayValue = cfg.novalue
        end
        percentUsed = nil
    end

    box._isLoadingDots = type(displayValue) == "string" and displayValue:match("^%.+$") ~= nil

    box._dynamicTextColor = percentUsed ~= nil and utils.resolveThresholdColor(percentUsed, box, "textcolor", "textcolor") or cfg.defaultTextColor

    if not box.onpress then box.onpress = eraseBlackboxAsk end

    if eraseDataflashGo then
        eraseDataflashGo = false
        eraseDataflash()
    end

    if progress then
        progressCounter = (progressCounter or 0) + 20
        progress:value(progressCounter)
        if progressCounter >= 100 then
            progress:close()
            progress = nil
        end
    end

    box._currentDisplayValue = displayValue
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    local unitForPaint = box._isLoadingDots and nil or c.unit
    local textColor = box._dynamicTextColor or c.defaultTextColor

    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, box._currentDisplayValue, unitForPaint, c.font, c.valuealign, textColor, c.valuepadding,
        c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, c.bgcolor)
end

return render

