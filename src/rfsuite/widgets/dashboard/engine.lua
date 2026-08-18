-- Thin compatibility shim -- widgets/dashboard/engine.lua.
--
-- See widgets/dashboard/context.lua's own header for the full rationale --
-- same shim pattern, kept at this relative path because
-- widgets/dashboard.lua's own ensureDashboardEngine() still does
-- requireModule("widgets/dashboard/engine.lua"). Nothing else references
-- this path directly (unlike context.lua, no theme file loads engine.lua of
-- its own accord), but the pattern is kept identical for consistency.

if package.loaded["rfsuite.dashboard.engine"] then
  return package.loaded["rfsuite.dashboard.engine"]
end

local engine = assert(loadfile("SCRIPTS:/dashboard/widgets/dashboard/engine.lua"))()
package.loaded["rfsuite.dashboard.engine"] = engine
return engine
