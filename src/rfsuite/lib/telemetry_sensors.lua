-- Look up a telemetry sensor's live value by logical name + transport
-- protocol, trying a short list of candidate appIds in order (some
-- ESCs/FCs/firmware versions broadcast the same logical value on a
-- different appId). Stateless -- no module-level state, just a lookup
-- table and pure functions -- the same category of neutral utility as
-- lib/mspcodec.lua.
--
-- Candidate appIds copied from rotorflight-lua-ethos-suite's
-- tasks/scheduler/telemetry/sources/{sport,crsf}.lua, trimmed to only the
-- sensors this rebuild currently needs (voltage, consumption, the
-- firmware-mirrored smartfuel channel, PID/rate/battery profile index,
-- and arm-status flags -- see lib/smartfuel_calc.lua and
-- tasks/session.lua). Add more entries here as more of the original's
-- ~30-sensor table is actually needed; don't port the rest speculatively.
--
-- Self-caught bug: `smartfuel` originally pointed at appId 0x5FE1 for both
-- protocols -- that's actually lib/diy_sensor.lua's own SMARTFUEL_APP_ID,
-- the address the *app itself* fabricates a sensor at when running the
-- local fallback (tasks/session.lua's smartfuelMode == 0 branch), not
-- where the FC's own firmware-computed value is broadcast. Looking that
-- appId up here to decide whether to mirror the firmware is circular --
-- nothing ever broadcasts there natively, so it always resolved to nil and
-- silently disabled fuel% (and the DIY sensor, which only gets created in
-- the *other* branch) whenever smartfuelMode > 0. Corrected to the real
-- firmware-mirror addresses from that same original's own
-- tasks/scheduler/sensors/lib/smartfuelfbl.lua (`mirror_sources`): 0x0600
-- for S.Port, 0x1014 for CRSF. (The original also has a `smartconsumption`
-- channel at the same appId as `consumption` -- not ported here since
-- nothing in this rebuild queries it yet; add it back if that changes.)
-- NOTE: still not independently verified live against real hardware.

local CANDIDATES = {
  sport = {
    voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0210},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0211},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0218},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x021A},
    },
    consumption = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250},
    },
    current = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0208},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201},
    },
    link = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0xF101, subId = 0},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0xF010, subId = 0},
    },
    rpm = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0500},
    },
    temp_esc = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0418},
    },
    temp_mcu = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0400},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401},
    },
    bec_voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0901},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0219},
    },
    throttle_percent = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5440},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x51A4},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5269},
    },
    smartfuel = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1},
    },
    -- Native S.Port broadcasts if the FC sends them directly, but in
    -- practice these are the same appIds lib/frsky_sensors.lua labels from
    -- TELEMETRY_CONFIG's slot assignment -- see tasks/session.lua's
    -- profile-change tracking.
    pid_profile = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5130},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5471},
    },
    rate_profile = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5131},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5472},
    },
    battery_profile = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5133},
    },
    governor = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5125},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5450},
    },
    adj_f = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5110},
    },
    adj_v = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5111},
    },
    -- Arm-status flags -- see tasks/session.lua's own updateArmedState()
    -- for how the raw value maps to a plain isArmed boolean.
    armflags = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5122},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5462},
    },
  },
  crsf = {
    voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1011},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1041},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1051},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1080},
    },
    consumption = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013},
    },
    current = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x104A},
    },
    rpm = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C0},
    },
    temp_esc = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A0},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1047},
    },
    temp_mcu = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A3},
    },
    bec_voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1081},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1049},
    },
    throttle_percent = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1035},
    },
    smartfuel = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1},
    },
    -- Same appIds tasks/elrs_sensors.lua's DIY sensors use (SIDs 0x1211/
    -- 0x1212/0x1214) -- this resolves to that same sensor once it exists.
    pid_profile = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1211},
    },
    rate_profile = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1212},
    },
    battery_profile = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1214},
    },
    governor = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1205},
    },
    adj_f = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1221},
    },
    adj_v = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1222},
    },
    armflags = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1202},
    },
  },
}

-- Cache resolved `source` objects per protocol/name so repeated calls
-- (once per wakeup) don't re-scan candidates every time.
local resolvedCache = {}
local missRetryAt = {}
local MISS_RETRY_INTERVAL = 5.0

local telemetry_sensors = {}

function telemetry_sensors.getSource(protocol, name)
  local byProtocol = resolvedCache[protocol]
  if not byProtocol then
    byProtocol = {}
    resolvedCache[protocol] = byProtocol
  end

  -- Only a *successful* resolution is cached. A sensor that hasn't started
  -- broadcasting yet (common for consumption/smartfuel right after
  -- connect) must keep being retried, not be written off forever.
  local source = byProtocol[name]
  if not source then
    local byProtocolMiss = missRetryAt[protocol]
    local now = os.clock()
    if byProtocolMiss and byProtocolMiss[name] and now < byProtocolMiss[name] then
      return nil
    end

    local candidates = CANDIDATES[protocol] and CANDIDATES[protocol][name]
    if not candidates then return nil end
    for i = 1, #candidates do
      local candidate = system.getSource(candidates[i])
      if candidate then
        source = candidate
        byProtocol[name] = source
        if byProtocolMiss then byProtocolMiss[name] = nil end
        break
      end
    end
    if not source then
      if not byProtocolMiss then
        byProtocolMiss = {}
        missRetryAt[protocol] = byProtocolMiss
      end
      byProtocolMiss[name] = now + MISS_RETRY_INTERVAL
      return nil
    end
  end

  if source.state and source:state() == false then return nil end
  return source
end

function telemetry_sensors.getValue(protocol, name)
  local source = telemetry_sensors.getSource(protocol, name)
  if not source then return nil end
  return source:value()
end

function telemetry_sensors.reset()
  resolvedCache = {}
  missRetryAt = {}
end

return telemetry_sensors
