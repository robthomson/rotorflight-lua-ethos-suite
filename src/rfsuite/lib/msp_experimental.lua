-- MSP_EXPERIMENTAL helper (cmd 158 read / 159 write).

if package.loaded["rfsuite.lib.msp_experimental"] then
  return package.loaded["rfsuite.lib.msp_experimental"]
end

local READ_COMMAND = 158
local WRITE_COMMAND = 159

local SIMULATOR_RESPONSE = {
  255, 10, 60, 200, 20, 255, 6, 10,
  20, 40, 255, 6, 10, 20, 20, 20,
}

local msp_experimental = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  SIMULATOR_RESPONSE = SIMULATOR_RESPONSE,
}

local function copyBytes(buf)
  local values = {}
  for i = 1, math.min(#(buf or {}), 16) do
    values[i] = tonumber(buf[i]) or 0
  end
  return values
end

function msp_experimental.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      if onData then onData(copyBytes(buf)) end
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_experimental.buildWriteMessage(values, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = copyBytes(values),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_experimental"] = msp_experimental
return msp_experimental
