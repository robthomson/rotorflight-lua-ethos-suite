-- CRSF/ELRS candidate appIds for lib/telemetry_sensors.lua -- what
-- tasks/elrs_sensors.lua decodes off CRSF's custom-telemetry frames and
-- creates DIY sensors for. Split into its own file (rather than a sub-table
-- of one big CANDIDATES literal) so lib/telemetry_sensors.lua can
-- loadfile() only the protocol actually in use for this session instead of
-- constructing all three protocols' tables regardless -- see that file's
-- own header.

return {
  altitude = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10B2},
  },
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
  -- Why-can't-arm bitmask (see lib/msp_status.lua's own arming_disable_flags
  -- and widgets/dashboard/context.lua's armingDisableFlagsToString()) --
  -- broadcast at the appId right after armflags's own.
  armdisableflags = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1203},
  },
  -- subId=2 is the dedicated Link Quality field on firmware that broadcasts
  -- this suite's newer CRSF telemetry frame; subIdStart/subIdEnd is the
  -- plain-fallback range for older firmware without that marker (a raw
  -- antenna RSSI, not a true 0-100 LQ%). Matches the pre-extraction
  -- widgets/dashboard/context.lua's own LIVE_SENSOR_CANDIDATES table
  -- exactly (removed when the shared `dashboard` package's context.lua was
  -- extracted). `vfr` mirrors `rssi` one-for-one, same as that removed
  -- table did.
  rssi = {
    {crsfId = 0x14, subId = 2},
    {crsfId = 0x14, subIdStart = 0, subIdEnd = 1},
  },
  vfr = {
    {crsfId = 0x14, subId = 2},
    {crsfId = 0x14, subIdStart = 0, subIdEnd = 1},
  },
  -- "link" (session.linkQuality, the rt-rc/rt-rc-n themes' own "LQ" box)
  -- had no CRSF entry at all until now -- a pre-existing gap, not something
  -- the rssi/vfr addition above introduced: S.Port's own candidate table
  -- (see telemetry_sensors_sport.lua) already had one, CRSF's didn't, so
  -- linkQuality silently stayed nil for every CRSF/ELRS pilot. Unlike
  -- rssi/vfr above, "link" does NOT try subId=2 (the dedicated LQ field)
  -- first -- matches the pre-extraction widgets/dashboard/context.lua's own
  -- LIVE_SENSOR_CANDIDATES table exactly, subIdStart/subIdEnd range first,
  -- falling back to a plain named-sensor lookup ("Rx RSSI1", a string
  -- candidate -- system.getSource() accepts either shape, same as this
  -- module's own getSource() loop already assumes).
  link = {
    {crsfId = 0x14, subIdStart = 0, subIdEnd = 1},
    "Rx RSSI1",
  },
}
