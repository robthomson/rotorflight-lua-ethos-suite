-- Physical Back/Close key detection, shared by app/menu_container.lua and
-- any page (e.g. app/pages/pids.lua) that wants the hardware key to
-- behave exactly like its on-screen "Back" button.
--
-- Two separate things are being matched here, found by reading two
-- different parts of the original suite rather than just one:
--
-- 1. category == EVT_CLOSE (value 0 or KEY_DOWN_BREAK), matching
--    rotorflight-lua-ethos-suite's app/lib/page_runtime.lua's own
--    shouldHandleClose() exactly -- this is what a touch/software back
--    gesture (or a radio whose EXIT key happens to be routed through
--    EVT_CLOSE) delivers to a system tool's event().
--
-- 2. category == EVT_KEY with value KEY_EXIT_BREAK, KEY_RTN_BREAK, or
--    KEY_DOWN_BREAK -- a genuinely different code path, missing here
--    until a live report that a non-touch radio's physical EXIT button
--    did nothing (fell through to Ethos's own default of just exiting
--    the tool outright, rather than this app popping one level like its
--    on-screen Menu button does). Confirmed as real and necessary via
--    two independent original-suite sources, not guessed at: the
--    canonical ETHOS-Feedback-Community `tool-servo/main.lua` example
--    listens for exactly `category == EVT_KEY and value ==
--    KEY_EXIT_BREAK` in a system tool's own event(); and
--    rotorflight-lua-ethos-suite's widgets/dashboard/lib/debug_log_panel.lua
--    treats KEY_DOWN_BREAK, KEY_RTN_BREAK, and KEY_EXIT_BREAK as
--    interchangeable "dismiss" triggers in the same `if` -- different
--    radio models/key layouts apparently report their physical EXIT
--    button as one or another of these three, so all three need
--    checking, not just one guessed value.
--
-- Never a long Enter-hold either way (which means something else
-- entirely on Ethos radios -- long-press-save, see app/page_runtime.lua).
--
-- Stateless -- pure function, no module-level state -- safe to load from
-- as many files as need it. Self-caches via package.loaded (same
-- mechanism lib/bus.lua uses) rather than re-parsing/re-executing this
-- chunk on every single page open -- every page reloads app/page_runtime.lua
-- fresh, which in turn loadfile()s this file, so without caching this ran
-- again on every navigation for zero benefit (nothing here depends on
-- per-page state). One of several such caches added after a live memory
-- investigation confirmed (by checking whether rotorflight-lua-ethos-suite
-- shows the same symptom, and it does) that the *bulk* of this rebuild's
-- observed RAM growth is an Ethos platform trait -- something the `form`
-- widget system itself retains per created button/field, outside Lua's
-- own GC reachability, which no script-side change can eliminate -- but
-- redundant reloading of stateless shared modules like this one is a
-- separate, real, avoidable cost this rebuild's own code controls. See
-- AGENTS.md's "Memory stats printing" section for the full trace.

if package.loaded["rfsuite.app.close_key"] then
  return package.loaded["rfsuite.app.close_key"]
end

local function shouldHandleClose(category, value)
  if value == KEY_ENTER_LONG then return false end
  if category == EVT_CLOSE then
    return value == 0 or value == KEY_DOWN_BREAK
  end
  if category == EVT_KEY then
    return value == KEY_EXIT_BREAK or value == KEY_RTN_BREAK or value == KEY_DOWN_BREAK
  end
  return false
end

local close_key = {shouldHandleClose = shouldHandleClose}
package.loaded["rfsuite.app.close_key"] = close_key
return close_key
