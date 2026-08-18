-- Thin compatibility shim -- widgets/dashboard/context.lua.
--
-- The real rendering/theme-support context now lives in the shared
-- `dashboard` package (a hard dependency -- see that repo's own
-- docs/dashboard-spec.md; this suite doesn't register a dashboard widget of
-- its own at all any more, see widgets/dashboard.lua's own header, so the
-- one hard-dependency gate that matters is that package's own widget
-- refusing to register when SCRIPTS:/dashboard is missing). This file still
-- has to exist at exactly this relative path because every theme in
-- widgets/dashboard/themes/**, plus app/pages/settings_dashboard_settings.lua,
-- do requireModule("widgets/dashboard/context.lua") -- a RELATIVE loadfile()
-- path, which Ethos resolves against THIS suite's own install root
-- regardless of which absolute-pathed file happens to be "currently
-- loading" (see docs/memory-and-module-lifecycle.md). Rewriting every one of
-- those call sites to an absolute path would have been far more invasive
-- than just leaving something at the relative path they already expect.
--
-- This file's own body only runs once per session: requireModule's own
-- generic cache derives a *different* key for this path than the explicit
-- one below, so it re-executes this file's top-level code on every distinct
-- caller's first touch (matches the original context.lua's own behavior --
-- see its old header) -- but that just means re-running the two lines below,
-- which is cheap. The one real loadfile() -- the absolute one -- only
-- happens once: it hits the shared package's own self-cache
-- (package.loaded["dashboard.widgets.dashboard.context"]) on every call
-- after the first, including the first call from a *different* suite
-- (wingflight, or the standalone `dashboard` widget) if that suite happened
-- to load it first this session. One real context.lua table in memory for
-- the whole radio, however many suites reference it -- that reuse is the
-- actual point of this extraction; see the `dashboard` repo's own
-- docs/dashboard-spec.md.
--
-- If SCRIPTS:/dashboard isn't installed, the assert() below throws -- there
-- is no guard in this suite anymore to catch that gracefully (that
-- responsibility moved entirely to the shared package's own widget, which
-- simply won't register itself). In practice this is only reachable via
-- app/pages/settings_dashboard_settings.lua (opening Settings > Dashboard >
-- Settings) or a theme file being loaded some other way -- there is no
-- rendering widget left in this suite to hit it from.

if package.loaded["rfsuite.dashboard.context"] then
  return package.loaded["rfsuite.dashboard.context"]
end

local context = assert(loadfile("SCRIPTS:/dashboard/widgets/dashboard/context.lua"))()
package.loaded["rfsuite.dashboard.context"] = context
return context
