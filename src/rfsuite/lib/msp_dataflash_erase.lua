-- MSP_DATAFLASH_ERASE helper (cmd 72 write).

if package.loaded["rfsuite.lib.msp_dataflash_erase"] then
  return package.loaded["rfsuite.lib.msp_dataflash_erase"]
end

local WRITE_COMMAND = 72
local msp_dataflash_erase = {WRITE_COMMAND = WRITE_COMMAND}

function msp_dataflash_erase.buildWriteMessage(onWritten, onError)
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

package.loaded["rfsuite.lib.msp_dataflash_erase"] = msp_dataflash_erase
return msp_dataflash_erase
