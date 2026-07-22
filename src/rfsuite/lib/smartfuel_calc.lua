-- Stateful local battery-fuel estimator: sigmoid discharge curve + slew-rate
-- limiting + monotonic clamp, matching the shape of
-- rotorflight-lua-ethos-suite's tasks/scheduler/sensors/lib/smartfuellocal.lua.
--
-- Used only as a fallback when the FC's own SMARTFUEL_CONFIG mode is 0 (the
-- FC isn't computing/broadcasting fuel itself) -- see tasks/session.lua,
-- which mirrors the FC's own value directly whenever mode > 0.
--
-- Deliberately simplified relative to the original:
--   - No sag compensation (needs live RC stick input; this rebuild doesn't
--     read RC channels yet). Voltage sag under load will show as a
--     slightly lower estimate rather than being compensated out.
--   - No arm-state-gated slew activation or flight-mode-based mid-session
--     battery-swap detection (this rebuild doesn't track arm state yet).
--     Slew limiting is always active from the first sample, and the
--     estimator is reset wholesale whenever tasks/session.lua detects a
--     fresh connection, rather than on a live voltage-jump heuristic.
--   - No voltage-stability sampling window before seeding the initial
--     estimate -- the first sample seeds it directly.
--   - Always blends in a consumption sensor when present (matching the
--     original's COMBINED mode); pure voltage-only otherwise. No separate
--     user-selectable VOLTAGE/CURRENT/COMBINED preference.
--
-- Each instance owns its own state (create with SmartFuel.new()); nothing
-- here is a module-level global.

local math_min = math.min
local math_max = math.max
local math_exp = math.exp
local os_clock = os.clock

local smartfuel_reserve = assert(loadfile("lib/smartfuel_reserve.lua"))()

local SmartFuel = {}
SmartFuel.__index = SmartFuel

local DEFAULT_VOLTAGE_FALL_PER_SECOND = 0.01 -- V/s
local DEFAULT_CHARGE_DROP_PER_SECOND = 0.005 -- fraction/s

function SmartFuel.new()
  return setmetatable({
    chargeLevel = 0.0,
    initialChargeLevel = 0.0,
    lastCellVoltage = 0.0,
    initialConsumption = nil,
    lastTimestamp = nil,
  }, SmartFuel)
end

function SmartFuel:reset()
  self.chargeLevel = 0.0
  self.initialChargeLevel = 0.0
  self.lastCellVoltage = 0.0
  self.initialConsumption = nil
  self.lastTimestamp = nil
end

-- Only permits the value to fall at maxDrop per call; rises are instant.
local function slewDownLimit(current, target, maxDrop)
  if target < current then
    return math_max(target, current - maxDrop)
  end
  return target
end

-- Sigmoid mapping cellVoltage -> 0.0-1.0 charge fraction, scaled into a
-- fixed 3.0-4.2V reference range regardless of the pack's actual min/full
-- voltages (matches the firmware's own curve shape).
local function chargeLevelFromVoltage(cellVoltage, minV, fullV)
  if cellVoltage >= fullV then return 1.0 end
  if cellVoltage <= minV then return 0.0 end
  local scaledV = 3.0 + (cellVoltage - minV) / (fullV - minV) * 1.2
  scaledV = math_max(3.0, math_min(4.2, scaledV))
  return math_max(0.0, math_min(1.0, 1.0 / (1.0 + math_exp(-12.0 * (scaledV - 3.7)))))
end

-- inputs: {
--   voltage, consumption,          -- live telemetry (consumption optional)
--   cellCount, minV, fullV, packCapacity, warningPercent, -- from BATTERY_CONFIG
--   voltageFallPerSecond, chargeDropPerSecond,            -- from SMARTFUEL_CONFIG
-- }
-- Returns a 0-100 percent, or nil if there isn't enough information yet.
function SmartFuel:update(inputs)
  local voltage = inputs.voltage
  local cellCount = inputs.cellCount
  local packCapacity = inputs.packCapacity

  if not voltage or voltage < 2 or not cellCount or cellCount == 0
    or not packCapacity or packCapacity < 10
    or not inputs.minV or not inputs.fullV or inputs.fullV <= inputs.minV then
    return nil
  end

  local now = os_clock()
  local dt = (self.lastTimestamp and now > self.lastTimestamp) and (now - self.lastTimestamp) or 0

  local cellVoltage = voltage / cellCount
  if self.lastCellVoltage > 0 then
    cellVoltage = slewDownLimit(
      self.lastCellVoltage, cellVoltage,
      (inputs.voltageFallPerSecond or DEFAULT_VOLTAGE_FALL_PER_SECOND) * dt
    )
  end
  self.lastCellVoltage = cellVoltage

  local estimation = chargeLevelFromVoltage(cellVoltage, inputs.minV, inputs.fullV)

  if self.initialChargeLevel == 0 then
    self.chargeLevel = estimation
    self.initialChargeLevel = estimation
  end
  if self.initialConsumption == nil and inputs.consumption ~= nil then
    self.initialConsumption = inputs.consumption
  end
  estimation = math_min(self.initialChargeLevel, estimation)

  local nextChargeLevel = slewDownLimit(
    self.chargeLevel, estimation,
    (inputs.chargeDropPerSecond or DEFAULT_CHARGE_DROP_PER_SECOND) * dt
  )

  if inputs.consumption ~= nil and self.initialConsumption ~= nil then
    local used = inputs.consumption - self.initialConsumption
    local currentEstimate = self.initialChargeLevel - used / packCapacity
    nextChargeLevel = math_min(nextChargeLevel, currentEstimate)
  end

  -- Monotonic: fuel is never allowed to rise except via reset().
  nextChargeLevel = math_min(nextChargeLevel, self.chargeLevel)
  self.chargeLevel = math_max(0.0, math_min(nextChargeLevel, self.initialChargeLevel))
  self.lastTimestamp = now

  return smartfuel_reserve.applyPercent(math_min(1.0, self.chargeLevel) * 100, inputs.warningPercent)
end

return SmartFuel
