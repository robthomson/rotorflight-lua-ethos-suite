-- CRSF/ELRS MSP transport.
--
-- Adapted from rotorflight-lua-ethos-suite's tasks/scheduler/msp/crsf.lua.
-- CRSF distinguishes MSP reads from writes at the link-layer frame type
-- (0x7A request vs 0x7C write), unlike S.Port -- hence the `isWrite` flag
-- threaded through from tasks/msp/common.lua's mspSendRequest().
--
-- Private to the background task subsystem -- nothing outside tasks/msp/
-- should load this file directly.

local transport = {}

local CRSF_ADDRESS_BETAFLIGHT = 0xC8
local CRSF_ADDRESS_RADIO_TRANSMITTER = 0xEA
local CRSF_FRAMETYPE_MSP_REQ = 0x7A
local CRSF_FRAMETYPE_MSP_RESP = 0x7B
local CRSF_FRAMETYPE_MSP_WRITE = 0x7C
local CRSF_FRAMETYPE_CUSTOM_TELEM = 0x88

local sensor

local function getSensor()
  if not sensor then sensor = crsf.getSensor() end
  return sensor
end

local payloadOut = {}

function transport.mspSend(payload, isWrite)
  local s = getSensor()
  if not s then return nil end

  payloadOut[1] = CRSF_ADDRESS_BETAFLIGHT
  payloadOut[2] = CRSF_ADDRESS_RADIO_TRANSMITTER
  for i = 1, #payload do payloadOut[i + 2] = payload[i] end
  for j = #payload + 3, #payloadOut do payloadOut[j] = nil end

  local frameType = isWrite and CRSF_FRAMETYPE_MSP_WRITE or CRSF_FRAMETYPE_MSP_REQ
  return s:pushFrame(frameType, payloadOut)
end

local rxBuf = {}

function transport.mspPoll()
  local s = getSensor()
  if not s then return nil end

  local cmd, data = s:popFrame(CRSF_FRAMETYPE_MSP_RESP)
  if not cmd then return nil end
  if data[1] ~= CRSF_ADDRESS_RADIO_TRANSMITTER or data[2] ~= CRSF_ADDRESS_BETAFLIGHT then
    return nil
  end

  for i = 1, #rxBuf do rxBuf[i] = nil end
  for i = 3, #data do rxBuf[i - 2] = data[i] end
  return rxBuf
end

transport.maxTxBufferSize = 8
transport.maxRxBufferSize = 58

-- ELRS/CRSF custom-telemetry frame (0x88), used by
-- lib/elrs_sensor_table.lua's SID-keyed sensor data -- see
-- tasks/elrs_sensors.lua. Shares the same sensor object as mspPoll() above
-- (getSensor() is memoized), never a second crsf.getSensor() call.
-- Returns (command, data) straight from Ethos's popFrame -- command is
-- falsy when nothing is queued.
function transport.popCustomTelemetryFrame()
  local s = getSensor()
  if not s then return nil end
  return s:popFrame(CRSF_FRAMETYPE_CUSTOM_TELEM)
end

return transport
