-- Tiny cooperative scheduler for background-task subtasks.

if package.loaded["rfsuite.tasks.scheduler"] then
  return package.loaded["rfsuite.tasks.scheduler"]
end

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
  return setmetatable({tasks = {}}, Scheduler)
end

function Scheduler:add(name, interval, wakeup)
  self.tasks[#self.tasks + 1] = {
    name = name,
    interval = interval or 0,
    wakeup = wakeup,
    nextRun = 0,
  }
end

function Scheduler:clear()
  for i = #self.tasks, 1, -1 do
    self.tasks[i] = nil
  end
end

function Scheduler:wakeup()
  local now = os.clock()
  for i = 1, #self.tasks do
    local task = self.tasks[i]
    if now >= task.nextRun then
      task.nextRun = now + task.interval
      local ok, err = pcall(task.wakeup, now)
      if not ok then
        print("[scheduler] " .. tostring(task.name) .. " failed: " .. tostring(err))
      end
    end
  end
end

local scheduler = {new = Scheduler.new}
package.loaded["rfsuite.tasks.scheduler"] = scheduler
return scheduler
