-- Picks the active MSP transport once, at background-task init.
--
-- Matches rotorflight-lua-ethos's approach (RF2/protocols.lua): presence of
-- an ELRS RSSI telemetry source means CRSF, otherwise fall back to S.Port.
-- No dynamic re-selection at runtime yet -- if that's needed later
-- (telemetry type changing mid-session), it belongs here, still gated
-- behind a single call the background task makes at a known point.
--
-- Returns the transport module *and* a protocol name ("sport"|"crsf"), the
-- latter needed by lib/telemetry_sensors.lua to pick the right per-protocol
-- appId candidates for plain telemetry sensors (voltage, consumption, the
-- firmware-mirrored smartfuel channels, etc).

local function select()
  if system.getSource("Rx RSSI1") ~= nil then
    return assert(loadfile("tasks/msp/transport_crsf.lua"))(), "crsf"
  end
  return assert(loadfile("tasks/msp/transport_sport.lua"))(), "sport"
end

return {select = select}
