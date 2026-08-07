-- Minimal, stateless MSP payload byte codec.
--
-- Pure functions only -- no module-level state -- so any subsystem may load
-- this without it becoming a "shared global" in the sense the rest of this
-- codebase forbids: nothing here is session/business state, it's just a
-- byte<->number codec, the same category of neutral utility as lib/bus.lua.
--
-- Arithmetic-based (no bit32/native bitwise ops) so it works unmodified
-- regardless of the Lua version's bitwise-operator support.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- every MSP codec module (lib/msp_pid_tuning.lua etc.) loadfile()s this,
-- and every one of those in turn gets reloaded fresh on every page open,
-- so without caching this ran again on every single navigation for zero
-- benefit (pure functions, nothing page-specific). Added after a live
-- memory investigation confirmed the *bulk* of this rebuild's observed
-- RAM growth is an Ethos platform trait (the `form` widget system itself
-- retaining something per created field, outside Lua's own GC
-- reachability -- confirmed by checking that rotorflight-lua-ethos-suite
-- shows the same symptom) that no script-side change can eliminate --
-- but redundant reloading of stateless shared modules like this one is a
-- separate, real, avoidable cost. See AGENTS.md's "Memory stats
-- printing" section.
if package.loaded["rfsuite.lib.mspcodec"] then
  return package.loaded["rfsuite.lib.mspcodec"]
end

local math_floor = math.floor

local mspcodec = {}

function mspcodec.readU8(buf)
  local offset = buf.offset or 1
  local value = buf[offset]
  buf.offset = offset + 1
  return value
end

function mspcodec.readS8(buf)
  local value = mspcodec.readU8(buf) or 0
  if value >= 0x80 then value = value - 0x100 end
  return value
end

function mspcodec.readU16(buf)
  local offset = buf.offset or 1
  local value = (buf[offset] or 0) + (buf[offset + 1] or 0) * 256
  buf.offset = offset + 2
  return value
end

function mspcodec.readS16(buf)
  local value = mspcodec.readU16(buf)
  if value >= 0x8000 then value = value - 0x10000 end
  return value
end

function mspcodec.readU32(buf)
  local offset = buf.offset or 1
  local value = (buf[offset] or 0)
    + (buf[offset + 1] or 0) * 256
    + (buf[offset + 2] or 0) * 65536
    + (buf[offset + 3] or 0) * 16777216
  buf.offset = offset + 4
  return value
end

function mspcodec.writeU8(buf, value)
  buf[#buf + 1] = value % 256
end

function mspcodec.writeS8(buf, value)
  if value < 0 then value = value + 0x100 end
  mspcodec.writeU8(buf, value)
end

function mspcodec.writeU16(buf, value)
  buf[#buf + 1] = value % 256
  buf[#buf + 1] = math_floor(value / 256) % 256
end

function mspcodec.writeS16(buf, value)
  if value < 0 then value = value + 0x10000 end
  mspcodec.writeU16(buf, value)
end

function mspcodec.writeU32(buf, value)
  buf[#buf + 1] = value % 256
  buf[#buf + 1] = math_floor(value / 256) % 256
  buf[#buf + 1] = math_floor(value / 65536) % 256
  buf[#buf + 1] = math_floor(value / 16777216) % 256
end

package.loaded["rfsuite.lib.mspcodec"] = mspcodec
return mspcodec
