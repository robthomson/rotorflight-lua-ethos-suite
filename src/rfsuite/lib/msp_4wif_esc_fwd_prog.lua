-- 4-way-interface ESC forward-programming target select (MSP 244).

if package.loaded["rfsuite.lib.msp_4wif_esc_fwd_prog"] then
  return package.loaded["rfsuite.lib.msp_4wif_esc_fwd_prog"]
end

local WRITE_COMMAND = 244
local DEFAULT_MAX_RETRIES = 2

local msp_4wif_esc_fwd_prog = {}

function msp_4wif_esc_fwd_prog.buildWriteMessage(target, onWritten, onError, opts)
  opts = opts or {}
  return {
    command = WRITE_COMMAND,
    payload = {target or 0},
    isWrite = true,
    processReply = function() if onWritten then onWritten() end end,
    errorHandler = onError,
    simulatorResponse = {},
    maxRetries = opts.maxRetries or DEFAULT_MAX_RETRIES,
  }
end

package.loaded["rfsuite.lib.msp_4wif_esc_fwd_prog"] = msp_4wif_esc_fwd_prog
return msp_4wif_esc_fwd_prog
