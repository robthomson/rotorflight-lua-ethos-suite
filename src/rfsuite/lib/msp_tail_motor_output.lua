-- MSP2_TAIL_MOTOR_OUTPUT (cmd 0x5F14, rotorflight-firmware src/main/msp/msp.c,
-- API 12.10): the tail pin drives either the tail servo (SERVO 4) or a tail
-- motor (MOTOR 2). Many boards come with it on SERVO 4, so a motorised tail
-- needs it moved, which used to take `resource SERVO 4 NONE` and
-- `resource MOTOR 2 <pin>` in the CLI.
--
-- Request: U8 action -- 0 read, 1 pin to SERVO 4, 2 pin to MOTOR 2.
-- Reply:   U8 output (OUTPUT below), U8 result (RESULT below).
-- A move is unsaved on the FC: the page's EEPROM write and reboot apply it.
--
-- Used as a page_runtime source by app/pages/mixer_tail.lua. An FC without
-- the command answers with an error; the read turns that into
-- {supported = false} instead of failing the page, since every other field
-- on the page still works.
--
-- The write also sets Tail Torque Assist (governor_tta_gain) on every PID
-- profile when the kind of tail changed: gain 100 for a motor, 0 for a servo,
-- like the Configurator's Mixer tab. TTA is per profile, so each one is
-- selected in turn and the active one selected again at the end.
--
-- Self-caches via package.loaded (same mechanism lib/bus.lua uses).
if package.loaded["rfsuite.lib.msp_tail_motor_output"] then
  return package.loaded["rfsuite.lib.msp_tail_motor_output"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")
local bus = requireModule("lib/bus.lua")
local status = requireModule("lib/msp_status.lua")
local selectProfile = requireModule("lib/msp_select_profile.lua")
local governorProfile = requireModule("lib/msp_governor_profile.lua")

local COMMAND = 0x5F14

local ACTION_READ = 0
local ACTION_TO_SERVO = 1
local ACTION_TO_MOTOR = 2

-- tailOutput_e and tailOutputResult_e, flight/servos.h.
local OUTPUT = {SERVO = 0, MOTOR = 1, BOTH = 2, NONE = 3}
local RESULT = {OK = 0, CUSTOM = 1, NO_MAIN_MOTOR = 2, NO_TIMER = 3, TIMER_SHARED = 4, INVALID = 5, NO_DMA = 6}

local TTA_GAIN_MOTOR = 100
local TTA_GAIN_OFF = 0

local msp_tail_motor_output = {
  COMMAND = COMMAND,
  OUTPUT = OUTPUT,
  RESULT = RESULT,
}

-- Whether the pin is where the tail mode needs it. BOTH (MOTOR 2 on a pin
-- of its own) suits either.
function msp_tail_motor_output.matches(output, motorised)
  if output == OUTPUT.BOTH then return true end
  if motorised then return output == OUTPUT.MOTOR end
  return output == OUTPUT.SERVO
end

-- Whether saving would move the pin: only between SERVO 4 and MOTOR 2. NONE
-- and BOTH are left to the Remap FC tab.
function msp_tail_motor_output.movable(values, motorised)
  if not values or not values.supported then return false end
  local output = values.output
  if output ~= OUTPUT.SERVO and output ~= OUTPUT.MOTOR then return false end
  return not msp_tail_motor_output.matches(output, motorised)
end

-- mspcodec reads a missing byte as 0, which is OUTPUT.SERVO: a short reply
-- is no answer at all, not a pin on SERVO 4.
local REPLY_LENGTH = 2

local function decode(buf)
  if type(buf) ~= "table" or #buf < REPLY_LENGTH then return nil, nil end
  return mspcodec.readU8(buf), mspcodec.readU8(buf)
end

local function buildMessage(action, onReply, onError)
  local payload = {}
  mspcodec.writeU8(payload, action)
  return {
    command = COMMAND,
    payload = payload,
    isWrite = action ~= ACTION_READ,
    processReply = function(_, buf)
      onReply(decode(buf))
    end,
    errorHandler = onError,
    -- The simulator's FC has the tail pin on SERVO 4 and moves it as asked.
    simulatorResponse = {action == ACTION_TO_MOTOR and OUTPUT.MOTOR or OUTPUT.SERVO, RESULT.OK},
  }
end

function msp_tail_motor_output.buildReadMessage(onData, onError)
  return buildMessage(ACTION_READ, function(output, result)
    onData({supported = output ~= nil, output = output, result = result})
  end, function()
    -- No such command on this firmware: not a failed page read.
    onData({supported = false})
  end)
end

-- Writes `gain` to governor_tta_gain on every PID profile, then selects the
-- profile that was active again. Unsaved; the page's EEPROM write follows.
local function setTtaAllProfiles(gain, onDone, onError)
  bus.publish("msp.request", status.buildReadMessage(function(s)
    local active = s.current_pid_profile_index or 0
    local count = s.pid_profile_count or 6
    local step

    local function restore()
      bus.publish("msp.request", selectProfile.buildWriteMessage(active, onDone, onError))
    end

    -- A step that fails midway would leave the FC on whichever profile the
    -- loop had selected, and a later save from any page would store that.
    -- Select the active profile again first, then report the reason.
    local function fail(reason)
      local function report() onError(reason) end
      bus.publish("msp.request", selectProfile.buildWriteMessage(active, report, report))
    end

    step = function(profile)
      if profile >= count then
        restore()
        return
      end
      bus.publish("msp.request", selectProfile.buildWriteMessage(profile, function()
        bus.publish("msp.request", governorProfile.buildReadMessage(function(g)
          if g.governor_tta_gain == gain then
            step(profile + 1)
            return
          end
          g.governor_tta_gain = gain
          local message = governorProfile.buildWriteMessage(g, function() step(profile + 1) end, fail)
          if not message then
            fail("incomplete governor profile")
            return
          end
          bus.publish("msp.request", message)
        end, fail))
      end, fail))
    end

    step(0)
  end, onError))
end

-- `values` is this source's data, filled in by the page's beforeSave:
--   values.motorised   -- the tail mode being saved is a motor tail
--   values.setTta      -- the kind of tail changed, so TTA follows it
-- After the write, values.output holds the FC's answer, values.moved is true
-- when the pin actually moved (the page then reboots) and values.refused is
-- the RESULT of a move the FC refused.
-- A refused move does not fail the save: the tail mode and everything else
-- still go to EEPROM, and the page shows why the pin stayed.
function msp_tail_motor_output.buildWriteMessage(values, onWritten, onError)
  values = values or {}
  values.moved = false
  local motorised = values.motorised == true
  local action = ACTION_READ
  if msp_tail_motor_output.movable(values, motorised) then
    action = motorised and ACTION_TO_MOTOR or ACTION_TO_SERVO
  end

  local function afterPin()
    if values.setTta == nil then
      onWritten()
      return
    end
    setTtaAllProfiles(values.setTta and TTA_GAIN_MOTOR or TTA_GAIN_OFF, onWritten, onError)
  end

  if not values.supported then
    -- No command to send. A write must still hand the queue a message, so
    -- the step opens with a harmless MSP_STATUS read.
    return status.buildReadMessage(afterPin, onError)
  end

  values.refused = nil
  return buildMessage(action, function(output, result)
    if action ~= ACTION_READ then
      values.moved = result == RESULT.OK
      if result ~= RESULT.OK then values.refused = result end
    end
    values.output = output
    afterPin()
  end, onError)
end

package.loaded["rfsuite.lib.msp_tail_motor_output"] = msp_tail_motor_output
return msp_tail_motor_output
