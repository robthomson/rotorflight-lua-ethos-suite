-- Local flight timer state owned by the background task.

local flight_timer = {}

local state = {
  start = nil,
  live = 0,
  session = 0,
  flightCounted = false,
}

local function roundedSeconds(value)
  value = tonumber(value) or 0
  if value < 0 then value = 0 end
  return math.floor(value + 0.5)
end

local function snapshot()
  return {
    timerLive = roundedSeconds(state.live),
    timerSession = roundedSeconds(state.session),
    timerFlightCounted = state.flightCounted == true,
  }
end

local function sameSnapshot(a, b)
  return a.timerLive == b.timerLive
    and a.timerSession == b.timerSession
    and a.timerFlightCounted == b.timerFlightCounted
end

function flight_timer.reset()
  state.start = nil
  state.live = 0
  state.session = 0
  state.flightCounted = false
end

function flight_timer.update(connected, armed, now)
  local before = snapshot()
  now = tonumber(now) or os.clock()
  local event = nil

  if connected ~= true then
    flight_timer.reset()
  elseif armed == true then
    if not state.start then
      state.start = now
      state.flightCounted = false
    end
    local segment = now - state.start
    if segment < 0 then segment = 0 end
    state.live = state.session + segment
    if segment >= 25 and not state.flightCounted then
      state.flightCounted = true
      event = {flightCounted = true}
    end
  else
    if state.start then
      local segment = now - state.start
      if segment > 0 then
        state.session = state.session + segment
        event = {
          finishedSegment = roundedSeconds(segment),
          session = roundedSeconds(state.session),
        }
      end
      state.start = nil
    end
    state.live = state.session
  end

  local after = snapshot()
  return not sameSnapshot(before, after), after, event
end

function flight_timer.current()
  return snapshot()
end

return flight_timer
