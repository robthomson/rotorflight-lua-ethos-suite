-- Shared paced progress dialog for fake MSP/page loaders.

if package.loaded["rfsuite.app.progress_dialog"] then
  return package.loaded["rfsuite.app.progress_dialog"]
end

local progress_dialog = {}

progress_dialog.SPEED = {
  DEFAULT = 1.0,
  FAST = 2.0,
  SLOW = 0.75,
  VSLOW = 0.5,
}

local DEFAULT_RATE = 0.25
local DEFAULT_CAP = 96
local DEFAULT_FINISH_RATE = 0.05
local DEFAULT_FINISH_STEP = 5
local DEFAULT_FINISH_FLOOR = 90

local function clamp(value, minValue, maxValue)
  value = tonumber(value) or minValue
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

local function nextPacedValue(value, speed, cap)
  if value < 45 then
    value = value + (2.0 * speed)
  elseif value < 75 then
    value = value + (1.0 * speed)
  else
    value = value + (0.35 * speed)
  end
  return clamp(value, 0, cap)
end

function progress_dialog.open(opts)
  opts = opts or {}
  if not (form and form.openProgressDialog) then return nil end

  local wrapper = {
    handle = nil,
    valueNow = 0,
    lastAt = 0,
    rate = opts.rate or DEFAULT_RATE,
    speed = opts.speed or progress_dialog.SPEED.DEFAULT,
    cap = opts.cap or DEFAULT_CAP,
    finishRate = opts.finishRate or DEFAULT_FINISH_RATE,
    finishStep = opts.finishStep or DEFAULT_FINISH_STEP,
    finishFloor = opts.finishFloor or DEFAULT_FINISH_FLOOR,
    finishing = false,
    closed = false,
  }

  local function setHandleValue(handle, value)
    pcall(function() handle:value(math.floor(value)) end)
  end

  local function startFinish(self)
    if self.closed or not self.handle then return end
    self.finishing = true
    if self.valueNow < self.finishFloor then
      self.valueNow = self.finishFloor
      setHandleValue(self.handle, self.valueNow)
    end
  end

  function wrapper:wakeup()
    if self.closed or not self.handle then return end
    local now = os.clock()
    local rate = self.finishing and self.finishRate or self.rate
    if self.lastAt > 0 and (now - self.lastAt) < rate then return end
    self.lastAt = now
    if self.finishing then
      self.valueNow = clamp(self.valueNow + self.finishStep, 0, 100)
      setHandleValue(self.handle, self.valueNow)
      if self.valueNow >= 100 then
        self:close(true)
      end
      return
    end
    self.valueNow = nextPacedValue(self.valueNow, self.speed, self.cap)
    setHandleValue(self.handle, self.valueNow)
  end

  function wrapper:value(value)
    if self.closed or not self.handle then return end
    if tonumber(value) and tonumber(value) >= 100 then
      startFinish(self)
      return
    end
    self.valueNow = clamp(value, 0, 100)
    setHandleValue(self.handle, self.valueNow)
  end

  function wrapper:message(message)
    if self.closed or not self.handle or not self.handle.message then return end
    pcall(function() self.handle:message(message) end)
  end

  function wrapper:closeAllowed(allowed)
    if self.closed or not self.handle or not self.handle.closeAllowed then return end
    pcall(function() self.handle:closeAllowed(allowed) end)
  end

  function wrapper:close(force)
    if self.closed then return end
    if not force and self.handle and self.valueNow < 100 then
      startFinish(self)
      return
    end
    self.closed = true
    local h = self.handle
    self.handle = nil
    if h and h.close then pcall(function() h:close() end) end
  end

  local handle
  handle = form.openProgressDialog({
    title = opts.title,
    message = opts.message,
    close = opts.close or function() end,
    wakeup = function()
      if opts.wakeup then opts.wakeup(wrapper) end
      wrapper:wakeup()
    end,
  })
  if not handle then return nil end

  wrapper.handle = handle
  wrapper:value(0)
  wrapper:closeAllowed(false)
  return wrapper
end

package.loaded["rfsuite.app.progress_dialog"] = progress_dialog
return progress_dialog
