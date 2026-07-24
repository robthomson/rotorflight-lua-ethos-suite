-- Rotorflight background task.
--
-- Registered eagerly: a background task must be running from
-- the moment the script loads, so there is nothing to gain by deferring it
-- -- deferring a required-at-boot subsystem just delays work that has to
-- happen anyway.
--
-- This subsystem owns the message bus lifecycle, the MSP transport/queue
-- lifecycle (tasks/msp/*), and connection/battery tracking (tasks/session.lua).
-- All of that is kept private: the system tool and dashboard widget may
-- only interact with MSP by publishing a message to the "msp.request"
-- topic on lib/bus.lua (see tasks/msp/queue.lua for the message shape and
-- lib/msp_pid_tuning.lua for an example of building one), and may only
-- learn about connection/battery state via the "session.update" topic (see
-- tasks/session.lua). This module never reads or writes anything
-- belonging to the system tool or the dashboard widget.

local bus = assert(loadfile("lib/bus.lua"))()
local settingsStore = assert(loadfile("lib/settings_store.lua"))()
local mspCommon = assert(loadfile("tasks/msp/common.lua"))()
local mspTransportSelect = assert(loadfile("tasks/msp/transport_select.lua"))()
local Scheduler = assert(loadfile("tasks/scheduler.lua"))()
local telemetrySensors = assert(loadfile("lib/telemetry_sensors.lua"))()
-- mspQueue is constructed with mspCommon explicitly, and handed to
-- session.lua the same way -- see the comment atop tasks/msp/queue.lua for
-- why nothing here may loadfile() its own second copy of either.
local mspQueue = assert(loadfile("tasks/msp/queue.lua"))().new(mspCommon)
local session = assert(loadfile("tasks/session.lua"))()
local logging = assert(loadfile("tasks/logging.lua"))()
local audioEvents = assert(loadfile("tasks/audio_events.lua"))()
local audioSwitches = assert(loadfile("tasks/audio_switches.lua"))()
local scheduler = Scheduler.new()

local TASK_STATUS_INTERVAL = 0.5
local MEMORY_LOG_INTERVAL = 5

local protocol -- "sport"|"crsf", set once at init; see tasks/msp/transport_select.lua
local transport -- set once at init; passed through so session.lua can drive
                 -- protocol-specific sensor work (e.g. tasks/elrs_sensors.lua's
                 -- custom-telemetry frame pop) without a second loadfile of it
local simSensors -- tasks/sim_sensors.lua, loadfile'd (see taskInit below) only when
                  -- system.getVersion().simulation == true -- stays nil, and the
                  -- module itself is never parsed/loaded, on real hardware
local lastTaskStatusAt = nil
local lastMemoryLogAt = nil
local memoryLogsEnabled = false

local function publishTaskStatus(now)
  lastTaskStatusAt = now or os.clock()
  bus.publish("task.status", {
    running = true,
    protocol = protocol,
    updatedAt = lastTaskStatusAt,
  })
end

local function logMemoryUsage(now)
  if not memoryLogsEnabled then return end
  if lastMemoryLogAt and (now - lastMemoryLogAt) < MEMORY_LOG_INTERVAL then return end

  lastMemoryLogAt = now

  local mem = system.getMemoryUsage and system.getMemoryUsage() or {}
  print(string.format(
    "[bgtask mem] lua=%.1fKB ramAvail=%.1fKB luaRamAvail=%.1fKB bmpRamAvail=%.1fKB stackAvail=%.1fKB",
    collectgarbage("count"),
    (mem.ramAvailable or 0) / 1024,
    (mem.luaRamAvailable or 0) / 1024,
    (mem.luaBitmapsRamAvailable or 0) / 1024,
    (mem.mainStackAvailable or 0) / 1024
  ))
end

local function onSettingsUpdate(snapshot)
  memoryLogsEnabled = settingsStore.memoryLogsEnabled(snapshot)
end

local function taskInit()
  transport, protocol = mspTransportSelect.select()
  mspCommon.setTransport(transport)
  session.setTelemetrySensors(telemetrySensors)
  logging.setTelemetrySensors(telemetrySensors)
  audioSwitches.setTelemetrySensors(telemetrySensors)
  local initialSettings = settingsStore.load()
  logging.setSettings(initialSettings)
  audioEvents.setSettings(initialSettings)
  audioSwitches.setSettings(initialSettings)
  onSettingsUpdate(initialSettings)
  publishTaskStatus()
  bus.subscribe("settings.update", onSettingsUpdate)
  bus.subscribe("msp.request", function(message)
    if message and message.clearQueue then
      mspQueue:clear()
      if not message.command then return end
    end
    if message and message.sessionBatteryProfile ~= nil and type(session.setBatteryProfile) == "function" then
      local originalProcessReply = message.processReply
      local selectedProfile = message.sessionBatteryProfile
      message.processReply = function(msg, buf)
        session.setBatteryProfile(selectedProfile)
        if originalProcessReply then originalProcessReply(msg, buf) end
      end
    end
    mspQueue:add(message)
  end)
  scheduler:clear()
  lastMemoryLogAt = nil
  scheduler:add("session", 0.05, function()
    session.wakeup(mspQueue, protocol, transport, simSensors)
  end)
  scheduler:add("logging", 0.25, function()
    logging.wakeup(protocol)
  end)
  scheduler:add("audio_events", 0.25, function()
    audioEvents.wakeup()
  end)
  scheduler:add("audio_switches", 0.25, function()
    audioSwitches.wakeup(protocol)
  end)

  -- Only ever loadfile'd/scheduled here, behind this one check -- see
  -- tasks/sim_sensors.lua's own header for why it costs nothing otherwise.
  if system.getVersion().simulation == true then
    simSensors = simSensors or assert(loadfile("tasks/sim_sensors.lua"))()
    scheduler:add("sim_sensors", 2, function()
      simSensors.wakeup()
    end)
  end
end

local function taskWakeup()
  mspQueue:processQueue()
  scheduler:wakeup()
  local now = os.clock()
  logMemoryUsage(now)
  if not lastTaskStatusAt or (now - lastTaskStatusAt) >= TASK_STATUS_INTERVAL then
    publishTaskStatus(now)
  end
end

local function taskEvent()
end

local function init()
  system.registerTask({
    key = "rf2bg",
    name = "Rotorflight [Background]",
    init = taskInit,
    wakeup = taskWakeup,
    event = taskEvent,
  })
end

return {init = init}
