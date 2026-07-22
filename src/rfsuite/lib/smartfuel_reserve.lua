-- Remaps a raw 0-100% fuel estimate so it reads 0% at the flight
-- controller's configured "consumption warning" threshold rather than at
-- absolute-empty voltage/capacity. Stateless.
--
-- Shared by lib/smartfuel_calc.lua (the local estimator's final step) and
-- tasks/session.lua (when mirroring the FC's own computed value) -- both
-- need the exact same remap regardless of which one produced the raw
-- percent.
--
-- Matches rotorflight-lua-ethos-suite's
-- tasks/scheduler/sensors/lib/smartfuelreserve.lua.

local math_floor = math.floor
local math_min = math.min
local math_max = math.max

local smartfuel_reserve = {}

function smartfuel_reserve.applyPercent(percent, warningPercent)
  local fuel = math_min(100, math_max(0, percent or 0))
  local warning = math_min(99, math_max(0, warningPercent or 0))
  if warning > 0 then
    fuel = (fuel - warning) * 100 / (100 - warning)
  end
  return math_floor(math_min(100, math_max(0, fuel)) + 0.5)
end

return smartfuel_reserve
