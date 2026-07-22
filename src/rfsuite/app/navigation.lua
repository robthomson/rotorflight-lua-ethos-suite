-- Return-context stack for the system tool's internal menu navigation.
--
-- Mirrors rotorflight-lua-ethos-suite's app/lib/navigation.lua, trimmed to
-- just push/pop/clear -- this rebuild's menu is far flatter (no
-- section/home-screen resolution, no per-menu "defaultSection" fallback),
-- so a plain LIFO stack of "which screen was I on before drilling down"
-- is the whole primitive needed for correct Back behaviour at any depth.
--
-- Owned by app/tool.lua, which creates ONE instance via
-- navigation.new() and threads it through app/menu_container.lua and any
-- page's open() call -- nothing else should loadfile() a second instance
-- (same class of bug as tasks/msp/queue.lua's note on shared instances,
-- though here it would just mean two independent stacks going out of
-- sync rather than a hard crash).
--
-- A stack entry is `nil` to mean "the root menu" (any other value is a
-- menuId string identifying a submenu in app/menu_container.lua's `menus`
-- table). pop() therefore returns *two* values -- (hadFrame, screen) --
-- rather than using a bare `nil` return to mean "nothing to pop": a
-- popped root frame and an empty stack would otherwise both read back as
-- `nil`, and a caller (app/menu_container.lua) genuinely needs to tell
-- those apart to know whether to re-open the root menu or exit the tool.

local navigation = {}

function navigation.new()
  local stack = {}
  local count = 0

  local function push(screen)
    count = count + 1
    stack[count] = screen
  end

  local function pop()
    if count == 0 then return false, nil end
    local screen = stack[count]
    stack[count] = nil
    count = count - 1
    return true, screen
  end

  local function clear()
    stack = {}
    count = 0
  end

  return {push = push, pop = pop, clear = clear}
end

return navigation
