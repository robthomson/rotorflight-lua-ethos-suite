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

local function rotate(px, py, cx, cy, angle)
    local s = math.sin(angle)
    local c = math.cos(angle)
    px, py = px - cx, py - cy
    local xnew = px * c - py * s
    local ynew = px * s + py * c
    return xnew + cx, ynew + cy
end

local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0
    local cfg = box._cfg
    if (not cfg) or (cfg._theme_version ~= theme_version) or (cfg._param_version ~= param_version) then
        cfg = {}
        cfg._theme_version = theme_version
        cfg._param_version = param_version

        cfg.ppd = getParam(box, "pixelsperdeg") or 2.0
        cfg.dMin = getParam(box, "dynamicscalemin") or 1.05
        cfg.dMax = getParam(box, "dynamicscalemax") or ((getParam(box, "dynamicscalemin") or 1.05) + 0.9)

        cfg.showarc = getParam(box, "showarc") ~= false
        cfg.showladder = getParam(box, "showladder") ~= false
        cfg.showcompass = getParam(box, "showcompass") ~= false
        cfg.showaltitude = getParam(box, "showaltitude") ~= false
        cfg.showgroundspeed = getParam(box, "showgroundspeed") ~= false

        cfg.arccolor = resolveThemeColor("arccolor", getParam(box, "arccolor") or lcd.RGB(255, 255, 255))
        cfg.laddercolor = resolveThemeColor("laddercolor", getParam(box, "laddercolor") or lcd.RGB(255, 255, 255))
        cfg.compasscolor = resolveThemeColor("compasscolor", getParam(box, "compasscolor") or lcd.RGB(255, 255, 255))
        cfg.crosshaircolor = resolveThemeColor("crosshaircolor", getParam(box, "crosshaircolor") or lcd.RGB(255, 255, 255))
        cfg.altitudecolor = resolveThemeColor("altitudecolor", getParam(box, "altitudecolor") or lcd.RGB(255, 255, 255))
        cfg.groundspeedcolor = resolveThemeColor("groundspeedcolor", getParam(box, "groundspeedcolor") or lcd.RGB(255, 255, 255))

        cfg.altitudemin = getParam(box, "altitudemin") or 0
        cfg.altitudemax = getParam(box, "altitudemax") or 200
        cfg.groundspeedmin = getParam(box, "groundspeedmin") or 0
        cfg.groundspeedmax = getParam(box, "groundspeedmax") or 100

        box._cfg = cfg
    end
    return box._cfg
end

function render.dirty(box)
    local d = box._dyn
    if not d then return false end
    local l = box._last
    if not l or d.pitch ~= l.pitch or d.roll ~= l.roll or d.yaw ~= l.yaw or d.altitude ~= l.altitude or d.groundspeed ~= l.groundspeed then
        box._last = {pitch = d.pitch, roll = d.roll, yaw = d.yaw, altitude = d.altitude, groundspeed = d.groundspeed}
        return true
    end
    return false
end

function render.wakeup(box)
    ensureCfg(box)

    local telemetry = rfsuite.tasks.telemetry
    if not telemetry then return end
    local getSensor = telemetry.getSensor

    local pitch = getSensor("attpitch") or 0
    local roll = getSensor("attroll") or 0
    local yaw = getSensor("attyaw") or 0
    local altitude = getSensor("altitude") or 20
    local groundspeed = getSensor("groundspeed") or 20

    box._dyn = {pitch = pitch, roll = roll, yaw = yaw, altitude = altitude, groundspeed = groundspeed}
end

function render.paint(x, y, w, h, box)
    local c = box._cfg;
    if not c then return end
    local d = box._dyn;
    if not d then return end

    local pitch, roll, yaw = d.pitch, d.roll, d.yaw
    local ppd = c.ppd
    local cx, cy = x + w / 2, y + h / 2

    local skyColor = lcd.RGB(70, 130, 180)
    local groundColor = lcd.RGB(160, 82, 45)

    lcd.setClipping(x, y, w, h)

    lcd.color(pitch >= 0 and skyColor or groundColor)
    lcd.drawFilledRectangle(x, y, w, h)

    local horizonY = cy + pitch * ppd
    local rollRad = math.rad(roll)

    local xL, yL = rotate(cx - 3 * w, horizonY, cx, horizonY, rollRad)
    local xR, yR = rotate(cx + 3 * w, horizonY, cx, horizonY, rollRad)

    local nx, ny = -math.sin(rollRad), math.cos(rollRad)

    local overlayColor = (pitch >= 0) and groundColor or skyColor
    lcd.color(overlayColor)

    local BIG = 4 * math.max(w, h)
    local sx, sy
    if pitch >= 0 then
        sx, sy = nx * BIG, ny * BIG
    else
        sx, sy = -nx * BIG, -ny * BIG
    end

    local p1x, p1y = xL + sx, yL + sy
    local p2x, p2y = xR + sx, yR + sy
    local p3x, p3y = xR, yR
    local p4x, p4y = xL, yL

    lcd.drawFilledTriangle(p1x, p1y, p2x, p2y, p3x, p3y)
    lcd.drawFilledTriangle(p1x, p1y, p3x, p3y, p4x, p4y)

    lcd.color(c.crosshaircolor)
    lcd.drawLine(cx - 5, cy, cx + 5, cy)
    lcd.drawLine(cx, cy - 5, cx, cy + 5)
    lcd.drawCircle(cx, cy, 3)

    if c.showarc then
        lcd.color(c.arccolor)
        local arcR = w * 0.4
        for _, ang in ipairs({-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60}) do
            local rad = math.rad(ang)
            local x1 = cx + arcR * math.sin(rad)
            local y1 = y + 10 + arcR * (1 - math.cos(rad))
            local x2 = cx + (arcR - 6) * math.sin(rad)
            local y2 = y + 10 + (arcR - 6) * (1 - math.cos(rad))
            lcd.drawLine(x1, y1, x2, y2)
        end
        lcd.drawFilledTriangle(cx, y + 5, cx - 6, y + 15, cx + 6, y + 15)
    end

    if c.showladder then
        lcd.color(c.laddercolor)
        for ang = -90, 90, 10 do
            local off = (pitch - ang) * ppd
            local py = cy + off
            if py > y - 40 and py < y + h + 40 then
                local major = (ang % 20 == 0)
                local len = major and 25 or 15
                local x1, y1 = rotate(cx - len, py, cx, cy, math.rad(roll))
                local x2, y2 = rotate(cx + len, py, cx, cy, math.rad(roll))
                lcd.drawLine(x1, y1, x2, y2)
                if major then
                    local lbl = tostring(ang)
                    local lx, ly = rotate(cx - len - 10, py - 4, cx, cy, math.rad(roll))
                    local rx, ry = rotate(cx + len + 2, py - 4, cx, cy, math.rad(roll))
                    lcd.drawText(lx, ly, lbl, RIGHT)
                    lcd.drawText(rx, ry, lbl, LEFT)
                end
            end
        end
    end

    if c.showcompass then
        lcd.color(c.compasscolor)
        local heading = math.floor((yaw + 360) % 360)
        local compassY = y + h - 24
        local labels = {[0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW"}
        for ang = -90, 90, 10 do
            local hdg = (heading + ang + 360) % 360
            local px = cx + ang * ppd
            if px > x and px < x + w then
                local th = (hdg % 30 == 0) and 8 or 4
                lcd.drawLine(px, compassY, px, compassY - th)
                if hdg % 30 == 0 then lcd.drawText(px, compassY - th - 8, labels[hdg] or tostring(hdg), CENTERED + FONT_XS) end
            end
        end
        lcd.drawFilledTriangle(cx, compassY + 1, cx - 5, compassY - 7, cx + 5, compassY - 7)

        local bw, bh = 60, 14
        local bx, by = cx - bw / 2, compassY + 6
        if by + bh < y + h then
            lcd.color(lcd.RGB(0, 0, 0));
            lcd.drawFilledRectangle(bx, by, bw, bh)
            lcd.color(c.compasscolor);
            lcd.drawRectangle(bx, by, bw, bh)
            lcd.drawText(cx, by + 1, string.format("%03d° %s", heading, labels[heading - (heading % 45)] or (heading .. "°")), CENTERED + FONT_XS)
        end
    end

    if c.showaltitude then
        lcd.color(c.altitudecolor)
        local barX = x + w - 10
        local barY = y + 5
        local barH = h - 10
        local fillH = math.floor((d.altitude - c.altitudemin) / (c.altitudemax - c.altitudemin) * barH)
        fillH = math.max(0, math.min(barH, fillH))
        lcd.drawRectangle(barX, barY, 6, barH)
        lcd.drawFilledRectangle(barX, barY + barH - fillH, 6, fillH)
        lcd.font(FONT_XS)
        local label = string.format("%d m", math.floor(d.altitude))
        lcd.drawText(barX - 4, barY + barH - fillH - 6, label, RIGHT)
    end

    if c.showgroundspeed then
        lcd.color(c.groundspeedcolor)
        local barX = x + 4
        local barY = y + 5
        local barH = h - 10
        local fillH = math.floor((d.groundspeed - c.groundspeedmin) / (c.groundspeedmax - c.groundspeedmin) * barH)
        fillH = math.max(0, math.min(barH, fillH))
        lcd.drawRectangle(barX, barY, 6, barH)
        lcd.drawFilledRectangle(barX, barY + barH - fillH, 6, fillH)
        lcd.font(FONT_XS)
        local label = string.format("%d knots", math.floor(d.groundspeed))
        lcd.drawText(barX + 10, barY + barH - fillH - 6, label, LEFT)
    end

    lcd.setClipping(0, 0, lcd.getWindowSize())
end

render.scheduler = 0.01

return render
