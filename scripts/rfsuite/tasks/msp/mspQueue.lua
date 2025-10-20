--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MspQueueController = {}
MspQueueController.__index = MspQueueController

local lastQueueCount = 0

local function newQueue() return {first = 1, last = 0, data = {}} end

local function qpush(q, v)
    q.last = q.last + 1
    q.data[q.last] = v
end

local function qpop(q)
    if q.first > q.last then return nil end
    local v = q.data[q.first]
    q.data[q.first] = nil
    q.first = q.first + 1
    return v
end

local function qcount(q) return q.last - q.first + 1 end

local function cloneArray(src)
    local dst = {}
    for i = 1, #src do dst[i] = src[i] end
    return setmetatable(dst, getmetatable(src))
end

local function shallowClone(src)
    local dst = {}
    for k, v in pairs(src) do dst[k] = v end
    return setmetatable(dst, getmetatable(src))
end

local function cloneMessage(msg)
    local out = {}
    for k, v in pairs(msg) do
        if k == "payload" and type(v) == "table" then
            out[k] = cloneArray(v)
        elseif k == "simulatorResponse" then
            out[k] = v
        elseif type(v) == "table" then
            out[k] = shallowClone(v)
        else
            out[k] = v
        end
    end
    return setmetatable(out, getmetatable(msg))
end

local function LOG_ENABLED_MSP() return rfsuite and rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.logmsp end

local function LOG_ENABLED_MSP_QUEUE() return rfsuite and rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.logmspQueue end

function MspQueueController.new(opts)
    opts = opts or {}
    local self = setmetatable({}, MspQueueController)

    self.queue = newQueue()
    self.currentMessage = nil
    self.currentMessageStartTime = nil

    self.lastTimeCommandSent = nil
    self.retryCount = 0
    self.maxRetries = opts.maxRetries or 3
    self.timeout = opts.timeout or 2.0

    self.uuid = nil

    self.loopInterval = opts.loopInterval or 0
    self._nextProcessAt = 0

    self.copyOnAdd = opts.copyOnAdd == true

    self.mspBusyStart = nil

    return self
end

function MspQueueController:queueCount() return qcount(self.queue) end

function MspQueueController:isProcessed() return (self.currentMessage == nil) and (self:queueCount() == 0) end

function MspQueueController:processQueue()

    if self.loopInterval and self.loopInterval > 0 then
        local now = os.clock()
        if now < self._nextProcessAt then return end
        self._nextProcessAt = now + self.loopInterval
    end

    local mspBusyTimeout = 5.0
    self.mspBusyStart = self.mspBusyStart or os.clock()

    if LOG_ENABLED_MSP_QUEUE() then
        local count = self:queueCount()
        if count ~= lastQueueCount then
            rfsuite.utils.log("MSP Queue: " .. count .. " messages in queue", "info")
            lastQueueCount = count
        end
    end

    if self:isProcessed() then
        rfsuite.session.mspBusy = false
        self.mspBusyStart = nil
        return
    end

    if self.mspBusyStart and (os.clock() - self.mspBusyStart) > mspBusyTimeout then
        rfsuite.utils.log("MSP blocked for more than " .. mspBusyTimeout .. " seconds", "info")
        rfsuite.utils.log(" - Unblocking by setting rfsuite.session.mspBusy = false", "info")
        rfsuite.session.mspBusy = false
        self.mspBusyStart = nil
        return
    end

    rfsuite.session.mspBusy = true

    rfsuite.utils.muteSensorLostWarnings()

    if not self.currentMessage then
        self.currentMessageStartTime = os.clock()
        self.currentMessage = qpop(self.queue)
        self.retryCount = 0
    end

    local cmd, buf, err

    local lastTimeInterval = rfsuite.tasks.msp.protocol.mspIntervalOveride or 0.25
    if lastTimeInterval == nil then lastTimeInterval = 1 end

    if not system:getVersion().simulation then

        if (not self.lastTimeCommandSent) or (self.lastTimeCommandSent + lastTimeInterval < os.clock()) then
            if self.currentMessage then
                rfsuite.tasks.msp.protocol.mspWrite(self.currentMessage.command, self.currentMessage.payload or {})
                self.lastTimeCommandSent = os.clock()
                self.currentMessageStartTime = self.lastTimeCommandSent
                self.retryCount = self.retryCount + 1
                if rfsuite.app.Page and rfsuite.app.Page.mspRetry then rfsuite.app.Page.mspRetry(self) end
            end    
        end

        rfsuite.tasks.msp.common.mspProcessTxQ()
        cmd, buf, err = rfsuite.tasks.msp.common.mspPollReply()

    else

        if not self.currentMessage.simulatorResponse then
            if LOG_ENABLED_MSP() then rfsuite.utils.log("No simulator response for command " .. tostring(self.currentMessage.command), "debug") end
            self.currentMessage = nil
            self.uuid = nil
            return
        end
        cmd, buf, err = self.currentMessage.command, self.currentMessage.simulatorResponse, nil
        if cmd then
            local rwState = (self.currentMessage.payload and #self.currentMessage.payload > 0) and "WRITE" or "READ"
            if LOG_ENABLED_MSP() then rfsuite.utils.logMsp(cmd, rwState, self.currentMessage.payload or buf, err) end
        end
    end

    if self.currentMessage and (os.clock() - self.currentMessageStartTime) > (self.currentMessage.timeout or self.timeout) then
        if self.currentMessage.setErrorHandler then self.currentMessage:setErrorHandler() end
        if LOG_ENABLED_MSP() then rfsuite.utils.log("Message timeout exceeded. Flushing queue.", "debug") end
        self.currentMessage = nil
        self.uuid = nil
        return
    end

    if cmd then self.lastTimeCommandSent = nil end

    if (cmd == self.currentMessage.command and not err) or (self.currentMessage.command == 68 and self.retryCount == 2) or (self.currentMessage.command == 217 and err and self.retryCount == 2) then

        if self.currentMessage.processReply then
            self.currentMessage:processReply(buf)
            if cmd and LOG_ENABLED_MSP() then
                local rwState = (self.currentMessage.payload and #self.currentMessage.payload > 0) and "WRITE" or "READ"
                rfsuite.utils.logMsp(cmd, rwState, self.currentMessage.payload or buf, err)
            end
        end
        self.currentMessage = nil
        self.uuid = nil
        if rfsuite.app.Page and rfsuite.app.Page.mspSuccess then rfsuite.app.Page.mspSuccess() end
    elseif self.retryCount > self.maxRetries then

        self:clear()
        if self.currentMessage and self.currentMessage.setErrorHandler then self.currentMessage:setErrorHandler() end
        if rfsuite.app.Page and rfsuite.app.Page.mspTimeout then rfsuite.app.Page.mspTimeout() end
    end
end

function MspQueueController:clear()
    rfsuite.session.mspBusy = false
    self.mspBusyStart = nil

    self.queue = newQueue()
    self.currentMessage = nil
    self.uuid = nil
    rfsuite.tasks.msp.common.mspClearTxBuf()
end

function MspQueueController:add(message)
    if not rfsuite.session.telemetryState then return end
    if not message then
        if LOG_ENABLED_MSP() then rfsuite.utils.log("Unable to queue - nil message.", "debug") end
        return
    end

    if message.uuid and self.uuid == message.uuid then
        if LOG_ENABLED_MSP() then rfsuite.utils.log("Skipping duplicate message with UUID " .. message.uuid, "debug") end
        return
    end

    if message.uuid then self.uuid = message.uuid end

    local toQueue = self.copyOnAdd and cloneMessage(message) or message
    qpush(self.queue, toQueue)
    return self
end

return MspQueueController.new()
