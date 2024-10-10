local function calibrate(callback, callbackParam)
    local message = {
        command = 205, -- MSP_ACC_CALIBRATION
        processReply = function(self, buf)
            -- rfsuite.utils.log("Accelerometer calibrated.")
            if callback then callback(callbackParam) end
        end,
        simulatorResponse = {}
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

return {calibrate = calibrate}
