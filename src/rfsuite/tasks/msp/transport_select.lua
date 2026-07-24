-- Picks the active MSP transport at background-task init, and lets
-- tasks/background.lua cheaply re-check afterwards (a model with a
-- different receiver protocol can get selected on the radio without the
-- background task itself ever reloading -- system.registerTask's `init`
-- runs once for the task's whole lifetime, not per model switch).
--
-- Matches rotorflight-lua-ethos's approach (RF2/protocols.lua): presence of
-- an ELRS RSSI telemetry source means CRSF, otherwise fall back to S.Port.
--
-- Split into detect() (just the system.getSource() check -- cheap enough to
-- poll on an interval) and load() (the actual loadfile() of the transport
-- module -- only worth paying for when detect()'s answer has actually
-- changed) so a recheck loop doesn't have to throw away and reconstruct a
-- perfectly good transport instance every time it merely confirms nothing
-- changed. select() is both, for the one-time init call.
--
-- The returned protocol name ("sport"|"crsf") is also what
-- lib/telemetry_sensors.lua uses to pick the right per-protocol appId
-- candidates for plain telemetry sensors (voltage, consumption, the
-- firmware-mirrored smartfuel channels, etc).

local function detect()
  if system.getSource("Rx RSSI1") ~= nil then return "crsf" end
  return "sport"
end

local function load(protocol)
  if protocol == "crsf" then
    return assert(loadfile("tasks/msp/transport_crsf.lua"))()
  end
  return assert(loadfile("tasks/msp/transport_sport.lua"))()
end

local function select()
  local protocol = detect()
  return load(protocol), protocol
end

return {select = select, detect = detect, load = load}
