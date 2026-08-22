# Dashboard flight-mode stuck-on-postflight fix — dev notes

**Status: implemented, UNTESTED.** No Lua interpreter or scriptable
simulator driver was available in the session that wrote this, so
everything below is code-review-verified only, not execution-verified.
Pick up testing here on whatever machine has the Ethos simulator/radio
available.

## The bug

Reported symptom: after landing (dashboard on `"postflight"`), rearming
and spooling back up restarts the flight timer correctly, but the
dashboard theme stays stuck showing `"postflight"` instead of switching
back to `"inflight"`. Most noticeable with **governor off**, using
throttle level to detect "spooled up".

## Root cause (confirmed via git history)

`widgets/dashboard/flightmode.lua`'s `inFlight()` decides "are we
flying" as: `isArmed AND (governor active OR throttle > 35%)`.

The **"Total rewrite" (#2256)** replaced the pre-rewrite throttle
signal with a different one, and dropped two state-machine rules in the
same file. Compare:

- **Pre-rewrite** (`git show 5069ec32^:src/rfsuite/tasks/scheduler/events/tasks/flightmode.lua`):
  throttle came from `rfsuite.session.rx.values.throttle` — the
  **radio's own throttle channel**, read locally via
  `system.getSource({category = CATEGORY_CHANNEL, member = <RX_MAP
  throttle index>})`. Always current, independent of the aircraft.
  It also had:
  ```lua
  -- reset the instant a fresh arm is detected
  if armed and not lastArmed then hasBeenInFlight = false; return "preflight" end
  ...
  -- hold inflight while still armed, ignoring a momentary throttle/governor blip
  -- comment: "avoids transient sensor/telemetry gaps flipping to
  -- postflight mid-flight"
  if armed and hasBeenInFlight then return "inflight" end
  ```
- **Post-rewrite** (current `widgets/dashboard/flightmode.lua`, before
  this fix): throttle came from `widget.throttlePercent` →
  `session.throttlePercent` → FC/ESC **telemetry sensor**
  (`throttle_percent`, `tasks/session.lua`). Neither of the two rules
  above existed — any tick where the spool-up check read false fell
  straight through to `"postflight"`, even while still armed.

`lib/msp_handshake.lua` says outright why the RX-channel read didn't
survive the rewrite:

> "Deliberately excludes rxmap ... which depend on rx-channel-consuming
> features ... this lite rebuild doesn't have yet"

So it wasn't a deliberate redesign — the RX_MAP/channel-reading
machinery just hadn't been ported back in, and FC telemetry was subbed
in as a stand-in. That's a materially different signal, especially with
governor off, and losing the "hold while armed" rule made it worse: a
momentary gap (telemetry lag, brief low-throttle moment) bounces the
dashboard to `"postflight"` mid-flight or right after a rearm, and
recovering from there depends on that same signal crossing the
threshold again.

## What this fix does

1. **New**: `lib/msp_rx_map.lua` — reads `MSP_RX_MAP` (cmd 64, standard
   MultiWii-lineage command, not Rotorflight-specific), decoding the
   8-byte channel map (aileron/elevator/rudder/collective/throttle/aux1-3).
   Modeled on the existing `lib/msp_sensor_alignment.lua` pattern.
2. **`tasks/session.lua`**: fetches RX_MAP once per connect (same gated
   `if not session.rxMap then ... end` pattern as the other
   `runHandshake()` reads), stores `session.rxMap`, publishes it in the
   snapshot, clears it on disconnect.
3. **`widgets/dashboard.lua`**: threads `snapshot.rxMap` through to
   `widget.rxMap`, same as every other snapshot field.
4. **`widgets/dashboard/flightmode.lua`**:
   - `resolveThrottleChannelValue(widget)`: resolves (and caches, on
     the widget) `system.getSource({category = CATEGORY_CHANNEL,
     member = widget.rxMap.throttle})`, matching the pre-rewrite call
     shape and the **same threshold (35)**, unchanged, on the theory
     that reusing a value that's already known to have worked is safer
     than re-deriving a new one from docs alone.
   - `inFlight()` prefers that channel value; falls back to
     `widget.throttlePercent` (today's mechanism) only if RX_MAP hasn't
     resolved yet — so this can't regress below where things stand
     today even if RX_MAP fails for some reason.
   - `Tracker:update()` restores the reset-on-rearm and
     hold-inflight-while-armed rules from the pre-rewrite
     `determineMode()`.

## What's verified vs. not

**Verified (static/manual review only):**
- Every new field name (`rxMap`, `_throttleChannelMember`,
  `_throttleChannelSource`) traced by hand across all four files, no
  mismatches found.
- MSP command number (64), field byte order, and the
  `CATEGORY_CHANNEL`/`system.getSource` call shape all matched exactly
  against both the pre-rewrite code and the current
  `app/pages/modes.lua` (which already does the identical channel read
  for AUX-channel auto-detect).

**NOT verified — needs a real test pass:**
- No Lua interpreter was available to even syntax-check these files.
- No way to launch the Ethos simulator from that session — it's gated
  behind a VS Code extension command (`${command:ethos.start}` in
  `.vscode/tasks.json`), no headless/scriptable entry point.
- **Biggest open risk**: the raw channel value's *scale*. The old code
  compared `source:value()` directly against `35` with zero
  conversion — this fix does exactly the same, on the assumption that
  matching old behavior byte-for-byte is safer than guessing a new
  threshold. If Ethos's default channel-value scale has changed since
  the pre-rewrite code was written (or differs from assumptions), `35`
  may need retuning. `app/pages/modes.lua`'s `channelRawToUs()` handles
  *two* different raw scales defensively (`-1200..1200` and
  `700..2300`) — this fix does not; if the channel value doesn't behave
  as expected, that's the first place to look.
- Whether `MSP_RX_MAP` (cmd 64) is answered identically across all
  supported FC/API versions — untested against real firmware.

## How to test

1. Simulator or radio — connect, open the dashboard widget.
2. Watch console output for anything from `msp_rx_map`, `rxMap`, or
   `flightmode.lua` — a crash there means the RX_MAP decode or the
   channel-source resolution broke something.
3. Arm, raise throttle past the old threshold, confirm `"inflight"`.
4. Lower throttle without disarming (simulate a momentary blip) —
   dashboard should **stay** `"inflight"` (this is the
   hold-while-armed fix; previously it may have flipped to
   `"postflight"`).
5. Disarm — confirm `"postflight"`.
6. **The actual bug repro**: rearm, raise throttle past threshold again
   — dashboard should return to `"inflight"`. Repeat with **governor
   off** specifically, since that's what the original report called out.
7. If the dashboard doesn't respond as expected, first suspect the
   channel-value scale (see "Biggest open risk" above) — add a debug
   print of `resolveThrottleChannelValue(widget)`'s raw return value
   next to the stick position to see what range it's actually reporting.

## wfsuite (wingflight-lua-ethos-suite) port

Same branch name, same fix, ported into
`C:\Github\wingflight-lua-ethos-suite` (same session). Structurally
wfsuite's `tasks/session.lua`/`widgets/dashboard.lua` mirror
rotorflight's closely enough that the same edits applied cleanly at the
equivalent anchor points (wfsuite has no `governorConfig` MSP fetch —
no such firmware concept for fixed-wing — but `governorState` still
exists as a dead/always-nil field, so `isGovernorActive()` is a
harmless no-op there and `inFlight()` always falls through to the
throttle check, which is correct for a plane anyway).

**Left as a known follow-up, not attempted here**: wfsuite may want its
own, differently-tuned `inFlight()` eventually — e.g. airspeed-based
rather than throttle-based flight detection, since "throttle above X%"
is a much weaker signal for a glider or a plane on a long descent than
for a helicopter. The current port is a same-mechanism-for-now parity
fix, not a wfsuite-specific redesign. See `flightmode.lua`'s own header
comment there.

## Git references

- Pre-rewrite flight-mode task:
  `git show 5069ec32^:src/rfsuite/tasks/scheduler/events/tasks/flightmode.lua`
- Pre-rewrite RX-channel population:
  `simulators/X18_EU@nightly26/scripts/rfsuite/tasks/scheduler/events/tasks/rxmap.lua`
  (legacy simulator copy still in the working tree)
- Pre-rewrite RX_MAP MSP command definition:
  `simulators/X18_EU@nightly26/scripts/rfsuite/tasks/scheduler/msp/api/RX_MAP.lua`
- The rewrite PR: #2256 ("RFSuite - Total rewrite"), commit `5069ec32`
