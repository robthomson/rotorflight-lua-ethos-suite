-- Message-builder for MSP_ACC_CALIBRATION (cmd 205), a write-only
-- command with an empty payload.

if package.loaded["rfsuite.lib.msp_acc_calibration"] then
  return package.loaded["rfsuite.lib.msp_acc_calibration"]
end

local WRITE_COMMAND = 205

local msp_acc_calibration = {
  WRITE_COMMAND = WRITE_COMMAND,
}

function msp_acc_calibration.buildWriteMessage(onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = {},
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_acc_calibration"] = msp_acc_calibration
return msp_acc_calibration
