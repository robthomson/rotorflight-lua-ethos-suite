-- Message-builder for MSP_EEPROM_WRITE (cmd 250) -- persists whatever
-- config the flight controller currently holds in RAM to flash. Stateless,
-- generic (not PID-specific); any page that writes FC config over MSP can
-- use this to follow up with a flash commit.

local WRITE_COMMAND = 250

local msp_eeprom = {
  WRITE_COMMAND = WRITE_COMMAND,
}

-- Builds a ready-to-publish message for lib/bus.lua's "msp.request" topic.
-- `onWritten()` (optional) is called once the FC acknowledges the write;
-- `onError(reason)` (optional) on failure.
function msp_eeprom.buildWriteMessage(onWritten, onError)
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

return msp_eeprom
