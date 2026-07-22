-- Schema + message-builders for the MSP_NAME / MSP_SET_NAME command pair
-- (cmd 10 read / 11 write) -- the craft name shown on app/pages/
-- configuration.lua. A standard (non-Rotorflight-specific) MSP command,
-- confirmed directly against rotorflight-firmware's own wire handlers
-- (src/main/msp/msp.c):
--   MSP_NAME just writes `strlen(name)` raw bytes -- no length prefix, no
--   null terminator, no padding. The read reply's own byte count *is* the
--   name's length.
--   MSP_SET_NAME reads `min(MAX_NAME_LENGTH, dataSize)` bytes and zero-
--   fills the rest of the 16-byte on-device buffer first -- so a write
--   payload shorter than 16 bytes (e.g. an empty name, or "Pilot") is
--   exactly what clears out whatever was there before, not a partial
--   update leaving stale trailing characters.
-- MAX_NAME_LENGTH (16) confirmed from firmware's own src/main/pg/pilot.h.
--
-- Cross-checked against rotorflight-lua-ethos-suite's own
-- tasks/scheduler/msp/api/NAME.lua, which reads/writes the exact same
-- shape. This rebuild already has a *read-only* version of this exact
-- decode in lib/msp_handshake.lua (buildNameReadMessage, used once at
-- connect to populate session.craftName) -- that one predates this
-- module and stays as-is (a one-shot handshake read has no reason to
-- route through the full buildReadMessage/buildWriteMessage shape every
-- editable page uses); this module exists because
-- app/pages/configuration.lua is a real editable page and needs the
-- write half too, which lib/msp_handshake.lua was never meant to have.
--
-- Not a `{name, wireType}` FIELDS/FIELD_META codec like every other
-- module in lib/ -- a name is a single variable-length string, not a set
-- of fixed-width numeric fields, so the usual per-field loop doesn't
-- apply here.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- app/pages/configuration.lua reloads fresh via loadfile() on every
-- open, so without caching this was rebuilt on every navigation too. See
-- lib/msp_pid_tuning.lua's own comment for the full reasoning (added
-- after a live memory investigation, see AGENTS.md's "Memory stats
-- printing" section).
if package.loaded["rfsuite.lib.msp_name"] then
  return package.loaded["rfsuite.lib.msp_name"]
end

local READ_COMMAND = 10
local WRITE_COMMAND = 11
local MAX_NAME_LENGTH = 16

local msp_name = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  MAX_NAME_LENGTH = MAX_NAME_LENGTH,
}

function msp_name.decode(buf)
  local name = ""
  for i = 1, MAX_NAME_LENGTH do
    local ch = buf[i]
    if ch == nil or ch == 0 then break end
    name = name .. string.char(ch)
  end
  return {name = name}
end

function msp_name.encode(data)
  local name = (data and data.name) or ""
  if type(name) ~= "string" then name = tostring(name) end
  local payload = {}
  local length = math.min(#name, MAX_NAME_LENGTH)
  for i = 1, length do
    payload[i] = string.byte(name, i)
  end
  return payload
end

-- Builds a ready-to-publish message for lib/bus.lua's "msp.request" topic.
-- `onData(data)` is called with `{name = "..."}` once the reply arrives;
-- `onError(reason)` (optional) on failure.
function msp_name.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_name.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = {80, 105, 108, 111, 116}, -- "Pilot"
  }
end

-- Builds a ready-to-publish write message. `onWritten()` (optional) is
-- called once the FC acknowledges the write; `onError(reason)` on
-- failure. `data.name` may be shorter than MAX_NAME_LENGTH (or empty) --
-- see this file's own header comment for why that's not a partial
-- update.
function msp_name.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_name.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_name"] = msp_name
return msp_name
