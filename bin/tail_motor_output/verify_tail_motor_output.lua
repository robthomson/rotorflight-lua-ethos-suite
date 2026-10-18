-- Behaviour check for lib/msp_tail_motor_output.lua: MSP2_TAIL_MOTOR_OUTPUT
-- (cmd 0x5F14, rotorflight-firmware API 12.10) and the Tail Torque Assist
-- writes that follow a change between a servo tail and a motor tail.
--
-- Run it:
--     lua5.4 bin/tail_motor_output/verify_tail_motor_output.lua
--     lua5.4 bin/tail_motor_output/verify_tail_motor_output.lua --self-test
--
-- What it drives: the real module with the real lib/bus.lua, lib/msp_status.lua,
-- lib/msp_select_profile.lua and lib/msp_governor_profile.lua. Every MSP request
-- the module publishes is recorded, and the harness answers it the way the
-- firmware would, through the message's own processReply / errorHandler. So
-- "it asked the FC to move the pin" is a fact about the payload that went out.
--
-- Wire layout, from rotorflight-firmware src/main/msp/msp.c (MSP2_TAIL_MOTOR_OUTPUT)
-- and src/main/flight/servos.h:
--   request U8 action: 0 read, 1 pin to SERVO 4, 2 pin to MOTOR 2
--   reply   U8 output (0 SERVO, 1 MOTOR, 2 BOTH, 3 NONE), U8 result (0 OK, 1..6 refused)
--
-- --self-test re-runs the move checks against a copy of the module that never
-- asks for a move (action stays 0), and requires them to fail: a check that
-- cannot fail proves nothing.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local MODULE_SRC = SUITE .. "/lib/msp_tail_motor_output.lua"

local SELF_TEST = arg and arg[1] == "--self-test"

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then f:close() return name end
  return SUITE .. "/" .. name
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then path = resolvePath(path) end
  if env ~= nil then return realLoadfile(path, mode, env)
  elseif mode ~= nil then return realLoadfile(path, mode)
  else return realLoadfile(path) end
end

local function requireModule(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(resolvePath(name))
  if not chunk then error(err) end
  local result = chunk()
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["rfsuite.lib.require"] = requireModule

local bus = requireModule("lib/bus.lua")
local status = requireModule("lib/msp_status.lua")
local selectProfile = requireModule("lib/msp_select_profile.lua")
local governorProfile = requireModule("lib/msp_governor_profile.lua")

local COMMAND = 0x5F14

-- Loads the module fresh, optionally with its source doctored.
local function loadTailModule(patch)
  package.loaded["rfsuite.lib.msp_tail_motor_output"] = nil
  local f = assert(io.open(MODULE_SRC, "r"))
  local src = f:read("a")
  f:close()
  if patch then
    local patched, n = src:gsub(patch[1], patch[2])
    assert(n > 0, "self-test patch did not apply: " .. patch[1])
    src = patched
  end
  local chunk = assert(load(src, "@" .. MODULE_SRC))
  return chunk()
end

local checks, failures = 0, 0
local quiet = false
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then failures = failures + 1 end
  if quiet then return end
  if ok then
    print(string.format("  ok    %s", label))
  else
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

-- Every msp.request published, in order.
local published = {}
bus.subscribe("msp.request", function(message) published[#published + 1] = message end)

local function reset() for i = #published, 1, -1 do published[i] = nil end end

local function reply(message, bytes)
  local buf = {}
  for i = 1, #bytes do buf[i] = bytes[i] end
  message.processReply(message, buf)
end

local function payloadOf(message)
  return message and message.payload and table.concat(message.payload, ",") or "<none>"
end

-- A status reply with this active profile (0-based) and profile count.
local function statusBytes(active, count)
  local bytes = {}
  for i, b in ipairs(status.buildReadMessage(function() end).simulatorResponse) do bytes[i] = b end
  -- current_pid_profile_index and pid_profile_count, after 23 bytes of
  -- earlier fields (lib/msp_status.lua FIELDS): bytes 24 and 25, 1-based.
  bytes[24] = active
  bytes[25] = count
  return bytes
end

local GOV_SIM = governorProfile.buildReadMessage(function() end).simulatorResponse
local function governorBytes(ttaGain)
  local values = governorProfile.decode((function()
    local b = {}
    for i, v in ipairs(GOV_SIM) do b[i] = v end
    return b
  end)())
  values.governor_tta_gain = ttaGain
  return governorProfile.encode(values)
end

local function moveChecks(tail)
  print("read")
  do
    local got, errors = nil, 0
    local msg = tail.buildReadMessage(function(data) got = data end, function() errors = errors + 1 end)
    check("the read is MSP2_TAIL_MOTOR_OUTPUT with action 0", msg.command == COMMAND and payloadOf(msg) == "0",
      string.format("command 0x%X, payload %s", msg.command or 0, payloadOf(msg)))
    reply(msg, {tail.OUTPUT.SERVO, tail.RESULT.OK})
    check("a reply decodes to supported, pin on SERVO 4",
      got ~= nil and got.supported == true and got.output == tail.OUTPUT.SERVO and errors == 0)

    got = nil
    msg = tail.buildReadMessage(function(data) got = data end, function() errors = errors + 1 end)
    msg.errorHandler("unknown command")
    check("an FC without the command reads as unsupported, not as a failed read",
      got ~= nil and got.supported == false and errors == 0)

    got = nil
    msg = tail.buildReadMessage(function(data) got = data end, function() errors = errors + 1 end)
    reply(msg, {})
    check("an empty reply reads as unsupported, not as a pin on SERVO 4",
      got ~= nil and got.supported == false, "output " .. tostring(got and got.output))
  end

  print("motorised tail, pin on SERVO 4")
  do
    reset()
    local values = {supported = true, output = tail.OUTPUT.SERVO, motorised = true}
    local written, errors = 0, 0
    local msg = tail.buildWriteMessage(values, function() written = written + 1 end, function() errors = errors + 1 end)
    check("the write asks for the pin on MOTOR 2 (action 2)", msg.command == COMMAND and payloadOf(msg) == "2",
      "payload " .. payloadOf(msg))
    reply(msg, {tail.OUTPUT.MOTOR, tail.RESULT.OK})
    check("the move is recorded", values.moved == true and values.output == tail.OUTPUT.MOTOR and values.refused == nil)
    check("without a TTA change it finishes at once", written == 1 and errors == 0 and #published == 0,
      string.format("written %d, errors %d, published %d", written, errors, #published))
  end

  print("servo tail, pin on MOTOR 2")
  do
    local values = {supported = true, output = tail.OUTPUT.MOTOR, motorised = false}
    local msg = tail.buildWriteMessage(values, function() end, function() end)
    check("the write asks for the pin on SERVO 4 (action 1)", payloadOf(msg) == "1", "payload " .. payloadOf(msg))
  end

  print("a refused move")
  do
    local values = {supported = true, output = tail.OUTPUT.SERVO, motorised = true}
    local written, errors = 0, 0
    local msg = tail.buildWriteMessage(values, function() written = written + 1 end, function() errors = errors + 1 end)
    reply(msg, {tail.OUTPUT.SERVO, tail.RESULT.TIMER_SHARED})
    check("the refusal and its reason are recorded",
      values.moved == false and values.refused == tail.RESULT.TIMER_SHARED,
      "moved " .. tostring(values.moved) .. ", refused " .. tostring(values.refused))
    check("the save still goes on (onWritten, not onError)", written == 1 and errors == 0)
  end
end

local function stayChecks(tail)
  print("nothing to move")
  do
    for _, case in ipairs({
      {"motorised, pin on MOTOR 2", tail.OUTPUT.MOTOR, true},
      {"servo tail, pin on SERVO 4", tail.OUTPUT.SERVO, false},
      {"MOTOR 2 on a pin of its own", tail.OUTPUT.BOTH, true},
      {"no pin at all (left to Remap FC)", tail.OUTPUT.NONE, true},
    }) do
      local values = {supported = true, output = case[2], motorised = case[3]}
      local msg = tail.buildWriteMessage(values, function() end, function() end)
      check(case[1] .. ": only reads (action 0)", payloadOf(msg) == "0", "payload " .. payloadOf(msg))
    end
  end
end

local function ttaChecks(tail)
  print("TTA follows a change to a motor tail, on every profile")
  do
    reset()
    local values = {supported = true, output = tail.OUTPUT.MOTOR, motorised = true, setTta = true}
    local written, errors = 0, 0
    local msg = tail.buildWriteMessage(values, function() written = written + 1 end, function() errors = errors + 1 end)
    reply(msg, {tail.OUTPUT.MOTOR, tail.RESULT.OK})

    -- Answer each request in turn: 3 profiles, profile 1 (0-based) active,
    -- profile 2 already at the target gain.
    local selected, govWrites, guard = {}, {}, 0
    local i = 1
    while i <= #published and guard < 100 do
      guard = guard + 1
      local m = published[i]
      if m.command == status.READ_COMMAND then
        reply(m, statusBytes(1, 3))
      elseif m.command == selectProfile.WRITE_COMMAND then
        selected[#selected + 1] = m.payload[1]
        reply(m, {})
      elseif m.isWrite then
        govWrites[#govWrites + 1] = m.payload
        reply(m, {})
      else
        reply(m, governorBytes(#selected == 3 and 100 or 0))
      end
      i = i + 1
    end
    check("each profile is selected, then the active one again", table.concat(selected, ",") == "0,1,2,1",
      "selected " .. table.concat(selected, ","))
    local gains = {}
    for _, payload in ipairs(govWrites) do
      local decoded = governorProfile.decode((function()
        local b = {}
        for k, v in ipairs(payload) do b[k] = v end
        return b
      end)())
      gains[#gains + 1] = decoded.governor_tta_gain
    end
    check("TTA gain 100 is written where it differs, and only there", table.concat(gains, ",") == "100,100",
      "gains written " .. table.concat(gains, ","))
    check("the write finishes once, after the last select", written == 1 and errors == 0,
      string.format("written %d, errors %d", written, errors))
  end

  print("TTA off on a change to a servo tail, on firmware without the command")
  do
    reset()
    local values = {supported = false, motorised = false, setTta = false}
    local written = 0
    local msg = tail.buildWriteMessage(values, function() written = written + 1 end, function() end)
    check("no MSP2_TAIL_MOTOR_OUTPUT is sent", msg.command == status.READ_COMMAND, string.format("command 0x%X", msg.command))
    reply(msg, statusBytes(0, 1))
    local gains, guard, i = {}, 0, 1
    while i <= #published and guard < 50 do
      guard = guard + 1
      local m = published[i]
      if m.command == status.READ_COMMAND then
        reply(m, statusBytes(0, 1))
      elseif m.command == selectProfile.WRITE_COMMAND then
        reply(m, {})
      elseif m.isWrite then
        gains[#gains + 1] = governorProfile.decode((function()
          local b = {}
          for k, v in ipairs(m.payload) do b[k] = v end
          return b
        end)()).governor_tta_gain
        reply(m, {})
      else
        reply(m, governorBytes(100))
      end
      i = i + 1
    end
    check("TTA gain 0 is written", table.concat(gains, ",") == "0", "gains " .. table.concat(gains, ","))
    check("the write finishes", written == 1)
  end
end

local tail = loadTailModule()
moveChecks(tail)
stayChecks(tail)
ttaChecks(tail)

print(string.format("\n%d checks, %d failed", checks, failures))
local ok = failures == 0

if SELF_TEST then
  local doctored = loadTailModule({
    "action = motorised and ACTION_TO_MOTOR or ACTION_TO_SERVO",
    "action = ACTION_READ",
  })
  local before = failures
  quiet = true
  moveChecks(doctored)
  quiet = false
  local caught = failures - before
  print(string.format("self-test: a module that never moves the pin %s the move checks (%d failed)",
    caught > 0 and "fails" or "PASSES", caught))
  ok = ok and caught > 0
end

os.exit(ok and 0 or 1)
