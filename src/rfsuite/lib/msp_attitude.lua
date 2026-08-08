-- Message-builder for MSP_ATTITUDE (cmd 108), used by the Alignment
-- page's live 3D attitude preview.

if package.loaded["rfsuite.lib.msp_attitude"] then
  return package.loaded["rfsuite.lib.msp_attitude"]
end

local mspcodec = assert(loadfile("lib/mspcodec.lua"))()

local READ_COMMAND = 108

local msp_attitude = {
  READ_COMMAND = READ_COMMAND,
}

local function buildSimulatorResponse()
  local t = os.clock()
  local roll = math.floor((25.0 * math.sin(t * 1.25) * 10.0) + 0.5)
  local pitch = math.floor((18.0 * math.sin((t * 0.90) + 0.9) * 10.0) + 0.5)
  local yaw = math.floor((90.0 * math.sin((t * 0.42) + 0.2)) + 0.5)
  local payload = {}
  mspcodec.writeS16(payload, roll)
  mspcodec.writeS16(payload, pitch)
  mspcodec.writeS16(payload, yaw)
  return payload
end

function msp_attitude.decode(buf)
  buf.offset = 1
  return {
    roll = mspcodec.readS16(buf),
    pitch = mspcodec.readS16(buf),
    yaw = mspcodec.readS16(buf),
  }
end

function msp_attitude.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_attitude.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = buildSimulatorResponse(),
    retryDelay = -0.6,
    maxRetries = 1,
  }
end

package.loaded["rfsuite.lib.msp_attitude"] = msp_attitude
return msp_attitude
