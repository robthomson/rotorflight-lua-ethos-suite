--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local type = type

local ACTION_PWM_BULK_REPLY = "servo.pwm.bulk.reply"
local ACTION_PWM_INDEX_REPLY = "servo.pwm.index.reply"
local ACTION_PWM_INDEX_ERROR = "servo.pwm.index.error"
local ACTION_BUS_INDEX_REPLY = "servo.bus.index.reply"

local SIM_PWM_BULK = {4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 0, 0, 120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0}
local SIM_INDEXED = {220, 5, 232, 3, 208, 7, 232, 3, 232, 3, 100, 0, 0, 0, 0, 0}

local function helper()
    local tasks = rfsuite.tasks
    local msp = tasks and tasks.msp
    return msp and msp.mspHelper
end

local function applyFlags(config)
    if config.flags == 1 or config.flags == 3 then
        config.reverse = 1
    else
        config.reverse = 0
    end

    if config.flags == 2 or config.flags == 3 then
        config.geometry = 1
    else
        config.geometry = 0
    end
end

local function readConfig(buf, h, config)
    config.mid = h.readU16(buf)
    config.min = h.readS16(buf)
    config.max = h.readS16(buf)
    config.scaleNeg = h.readU16(buf)
    config.scalePos = h.readU16(buf)
    config.rate = h.readU16(buf)
    config.speed = h.readU16(buf)
    config.flags = h.readU16(buf)
    applyFlags(config)
end

local function complete(context)
    context.loaded = true
    context.enableWakeup = true

    local app = rfsuite.app
    local triggers = app and app.triggers
    if triggers then
        triggers.isReady = true
        triggers.closeProgressLoader = true
    end
    if app and app.ui and app.ui.setPageDirty then
        app.ui.setPageDirty(false)
    end
end

local function ensureServoCount(context)
    if context.servoCount == nil then
        context.servoCount = (rfsuite.session and rfsuite.session.servoCount) or (context.servoTable and #context.servoTable) or 0
    end
    if rfsuite.session then
        rfsuite.session.servoCount = context.servoCount
    end
end

local function indexedReply(context, msg, buf)
    local h = helper()
    if not h then return false, "msp_helper_missing" end

    buf.offset = 1
    ensureServoCount(context)

    local servoIndex = context.servoIndex
    local configs = context.configs
    local servoTable = context.servoTable
    if not (configs and servoTable and servoIndex ~= nil) then return false, "missing_context_data" end

    local config = configs[servoIndex] or {}
    local row = servoTable[servoIndex + 1]
    config.name = row and row.title or config.name
    readConfig(buf, h, config)
    configs[servoIndex] = config

    complete(context)
    return true
end

local function pwmBulkReply(context, msg, buf)
    local h = helper()
    if not h then return false, "msp_helper_missing" end

    buf.offset = 1
    local servoCount = h.readU8(buf)
    context.servoCount = servoCount
    if rfsuite.session then
        rfsuite.session.servoCount = servoCount
    end

    local configs = context.configs
    local servoTable = context.servoTable
    if not (configs and servoTable) then return false, "missing_context_data" end

    if rfsuite.utils and rfsuite.utils.log then
        rfsuite.utils.log("Servo count " .. tostring(servoCount), "info")
    end

    for i = 0, servoCount - 1 do
        local config = configs[i] or {}
        local row = servoTable[i + 1]
        config.name = row and row.title or config.name
        readConfig(buf, h, config)
        configs[i] = config
    end

    complete(context)
    return true
end

local function pwmIndexError(context)
    local queue = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
    if not queue then return false, "queue_missing" end

    local bus = rfsuite.tasks.msp.bus
    local owner = context.owner
    local contextId = bus and bus.createContext and bus.createContext(context, owner)
    if not contextId then return false, "context_failed" end

    local message = {
        command = 120,
        uuid = "servo.cfg.bulk",
        _busOwner = owner,
        _busContext = contextId,
        _releaseBusContext = true,
        _replyAction = ACTION_PWM_BULK_REPLY,
        simulatorResponse = SIM_PWM_BULK
    }

    local ok, reason = queue:addPage(message)
    if not ok and bus and bus.releaseContext then
        bus.releaseContext(contextId)
    end
    return ok, reason
end

local function register(bus)
    if not (bus and bus.registerAction) then return false end
    bus.registerAction(ACTION_PWM_BULK_REPLY, pwmBulkReply)
    bus.registerAction(ACTION_PWM_INDEX_REPLY, indexedReply)
    bus.registerAction(ACTION_PWM_INDEX_ERROR, pwmIndexError)
    bus.registerAction(ACTION_BUS_INDEX_REPLY, indexedReply)
    return true
end

return {
    register = register,
    actions = {
        pwmBulkReply = ACTION_PWM_BULK_REPLY,
        pwmIndexReply = ACTION_PWM_INDEX_REPLY,
        pwmIndexError = ACTION_PWM_INDEX_ERROR,
        busIndexReply = ACTION_BUS_INDEX_REPLY
    },
    simulatorResponses = {
        pwmBulk = SIM_PWM_BULK,
        indexed = SIM_INDEXED
    }
}
