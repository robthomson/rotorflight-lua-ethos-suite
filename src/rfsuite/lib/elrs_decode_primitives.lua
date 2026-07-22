-- Stateless byte-unpacking primitives for ELRS/CRSF custom telemetry
-- (frame type 0x88) payloads. Pure functions only -- same category of
-- neutral utility as lib/mspcodec.lua -- so any subsystem may load this
-- without it becoming shared state.
--
-- Each `dec(data, pos)` reads its value(s) starting at 1-indexed `pos` in
-- the plain byte array `data` and returns `value, nextPos` (or
-- `valueA, valueB, nextPos` for `decU12U12`/`decS12S12`, which unpack two
-- 12-bit values from 3 bytes) -- it must always advance `pos`, or
-- tasks/elrs_sensors.lua's parser has no way to stay aligned with the rest
-- of the frame.
--
-- Transcribed from rotorflight-lua-ethos-suite's
-- tasks/scheduler/sensors/elrs.lua (`decU8`/`decS16`/etc. local functions
-- there); the aggregate decoders that publish multiple child sensors from
-- one frame (control/attitude/accel/latlong/adjustment/cells) live in
-- tasks/elrs_sensors.lua instead, since they need a `publish(...)` callback
-- into that stateful module -- they can't be pure.

local elrs_decode = {}

function elrs_decode.decNil(_, pos) return nil, pos end

function elrs_decode.decU8(data, pos) return data[pos], pos + 1 end

function elrs_decode.decS8(data, pos)
  local val, ptr = elrs_decode.decU8(data, pos)
  return val < 0x80 and val or val - 0x100, ptr
end

function elrs_decode.decU16(data, pos) return (data[pos] << 8) | data[pos + 1], pos + 2 end

function elrs_decode.decS16(data, pos)
  local val, ptr = elrs_decode.decU16(data, pos)
  return val < 0x8000 and val or val - 0x10000, ptr
end

-- Two 12-bit values packed into 3 bytes (used for the "Ctrl" aggregate's
-- 4 stick channels -- see tasks/elrs_sensors.lua's decControl).
function elrs_decode.decU12U12(data, pos)
  local a = ((data[pos] & 0x0F) << 8) | data[pos + 1]
  local b = ((data[pos] & 0xF0) << 4) | data[pos + 2]
  return a, b, pos + 3
end

function elrs_decode.decS12S12(data, pos)
  local a, b, ptr = elrs_decode.decU12U12(data, pos)
  return a < 0x0800 and a or a - 0x1000, b < 0x0800 and b or b - 0x1000, ptr
end

function elrs_decode.decU24(data, pos) return (data[pos] << 16) | (data[pos + 1] << 8) | data[pos + 2], pos + 3 end

function elrs_decode.decS24(data, pos)
  local val, ptr = elrs_decode.decU24(data, pos)
  return val < 0x800000 and val or val - 0x1000000, ptr
end

function elrs_decode.decU32(data, pos)
  return (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3], pos + 4
end

function elrs_decode.decS32(data, pos)
  local val, ptr = elrs_decode.decU32(data, pos)
  return val < 0x80000000 and val or val - 0x100000000, ptr
end

-- Cell-voltage byte -> 2.0-2.55V range remap used by the standard CRSF
-- cell-voltage encoding (0 = no cell present).
function elrs_decode.decCellV(data, pos)
  local val, ptr = elrs_decode.decU8(data, pos)
  return val > 0 and val + 200 or 0, ptr
end

return elrs_decode
