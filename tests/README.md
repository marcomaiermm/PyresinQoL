# Test architecture

Run commands from the repository root:

```sh
sh tests/run.sh                         # All Lua scenarios, with all variants
sh tests/run.sh unit                    # Pure configuration and registry logic
sh tests/run.sh integration             # Game API doubles and module interactions
sh tests/run.sh actionbars              # Both layers for one domain
python3 tests/tooling/lua-runner.py      # Discovery, selectors and failure aggregation
python3 tests/ui-runner.py               # Docker/preview command contracts, mocked Docker
bash tests/package.sh                   # Package integrity and rejection cases
bash tests/run-ui.sh 1280x720 3440x1440   # Native FrameXML interactions, selected viewports
bash tests/run-ui.sh                    # Matrix plus error, order and locale/scale contracts
bash tests/run-ui.sh --contracts        # Dedicated native expected-failure probes
bash tests/run-ui.sh --isolation        # Same-process forward/reverse flow repetition
bash tests/run-ui.sh --locale-scale     # Addon German labels with UIParent scale 1.25
```

`run.sh` accepts one selector: `all`, `unit`, `integration`, `core`, `actionbars`,
`castbar`, `dungeonmaps`, `editmode`, `unitframes`, `experience`, `quests` or `tooltips`. Unknown
selectors fail with exit code 2. Any failed Lua scenario makes the run fail, but
remaining selected scenarios still run and the final summary lists every failure.
Discovery failure aborts before any scenario runs, even if another layer was readable.
The runner discovers every `.lua` file under `unit/` and `integration/`; put
fixtures in `support/` so they cannot be mistaken for tests. It launches a fresh
LuaJIT process for every file and every variant to isolate globals, hooks and frames.

## Layers and ownership

| Layer | Responsibility | Examples and boundaries |
| --- | --- | --- |
| `unit/<domain>/` | Inputs, return values and plain state without simulated frames | Action-bar condition grammar, saved-value validation, module registration/startup/reload state |
| `integration/<domain>/` | Addon behavior through frame, event and native API doubles | Rendering data, settings callbacks, state transitions, restricted-value sinks, module coexistence |
| `ui/` | Actual Blizzard controls and FrameXML in the pinned WoW simulator | Open windows, click controls, seed world state, advance UI ticks, inspect displayed results and errors |
| `tooling/` | Development and release tool contracts | Immutable Docker images, cleanup, failures, package manifests and archive integrity |
| `support/` | Explicit domain fixtures | Cast-bar native transition/frame doubles shared by cast-bar and Edit Mode checks |

Single-module tests that simulate frame methods are integration tests. Their strict
restricted-value and ownership doubles remain useful alongside simulator flows:
the simulator does not reproduce every native protection or taint rule. Keep each
domain's doubles narrow; do not grow a second general-purpose WoW implementation.

## Scenario matrix

| Domain | Local coverage | Mandatory variants / real UI coverage |
| --- | --- | --- |
| Core / settings | TOC loading, deferred module activation, malformed SavedVariables recovery, migration, navigation, defaults, callbacks, profile snapshots, layout bindings and composed active-cast/drag/editor transitions | Settings: English, German, disabled options, all modules disabled. Profiles: English and German. Native pending-reload markers/control locking, profile lifecycle, cancellation and linked-profile synchronization through specialization events |
| Action bars | Grammar and saved values; public/secret color precedence; paging invalidation; native restoration; secure visibility; controller/combat guards; per-bar Edit Mode state | Edit Mode: English, German, late Blizzard loading. Native bar selection, visibility rules and macro editing in `ui/actionbars.lua` |
| Cast bar | Configuration, textures, models, layout and Edit Mode controls in five isolated files | `tests/castbar.lua` remains a compatibility launcher, including the optional native source argument. Native customization, stale-editor/reset, preview and live cast/interrupt/channel/restart flows in `ui/castbar.lua` and `ui/castbar-runtime.lua`; native protection and full transition combinations remain local/manual |
| Dungeon maps | Instance/subzone floor matching, exact 18-instance catalog and 50 map views, plus deliberate Sunken Temple/UBRS gaps without unverified coordinate projection | Native `M` binding and `WorldMapFrame` embedding, initial MapCanvas fit, floor controls, flat `World > Dungeon` fallback navigation, right-click/World-menu round trips, transitions, gap handling, pin/coordinate/area-label suppression and restoration in `ui/dungeonmaps.lua`; no mocked coordinates are treated as live-client calibration |
| Edit Mode / performance | Physical-pixel movement, snapping, placement, idle work, FPS/latency polling, visibility and restoration | Real addon module combinations: both enabled, editor only, performance only, neither. Native FPS/MS visibility and display height in `ui/performance.lua`; movement stays local |
| Unit frames | Health text/class colors, druid mana, player auras, target debuffs/threat, nameplate threat/combo points, threat meter | Native player class-color restoration, visible target text opacity, seeded player-aura layout and target-threat Always/Off dropdown in `ui/unitframes.lua`, `ui/auras.lua` and `ui/threat.lua`; druid mana, target debuffs, nameplates and threat-meter behavior currently stay local/manual |
| Experience | Formats, tooltip ownership, quest preview boundaries, resize, coalescing and invalidation | English and German; both native bars' text/visibility checkbox and percent-format dropdown in `ui/experience.lua`; quest reward/overflow cases stay local because the pinned simulator cannot seed meaningful quest rewards |
| Quests | Difficulty levels/colors, both dialogs, wrapping, row reuse and live level changes | Native gossip quest-row level decoration and live toggle in `ui/quests.lua`; full NPC dialog paths are blocked by simulator gaps listed in the error map |
| Tooltips | Restricted HP, ranks/factions, metadata, target changes, anchors, live refresh limits | English and German; native tooltip health text/configured height and visible fixed-screen anchor in `ui/tooltips.lua`; visible status-bar rendering is a simulator gap, metadata/target cases stay local |
| Tooling | Image immutability, cached builds, rejected tags/images, failure propagation and temporary resource cleanup; archive/source consistency | Python UI-command checks and Bash package checks remain separate from simulator assertions |

The restructuring retains all 24 original leaf Lua suites and their 11 additional
language/startup variants, then adds two pure suites and two profile recovery/
composition suites: **40 isolated Lua processes**.
Cast-bar's old top-level launcher delegates to its five leaf suites and is not
counted a second time. Scenario counts refer to processes, not individual asserts.
The UI runner discovers `ui/*.lua`; its scenario count is reported separately for
each resolution. Every configured resolution runs all UI scenarios, including the
native aura regression. Startup-error and exec-probe sentinels are also checked.

The standard UI command also runs three bounded infrastructure lanes once at
1280×720, outside the ten-resolution matrix. `--matrix [sizes...]` selects only the
ordinary matrix for debugging. `--contracts` requires delayed timer/OnUpdate errors,
cleanup errors and callbacks scheduled during cleanup to fail their named tests,
then checks the previous error handler and following native flows still work. These
intentional failures run in a separate process and are never counted as passing
product scenarios.

`--isolation` runs the complete Profiles, profile-transition, Cast Bar and aura
files forward and then in reverse in one simulator. Between passes it compares
SavedVariables, player aura IDs, active layout, error-handler identity and native
window/menu/popup closure against the baseline. Fresh processes would hide these
leaks, so both passes deliberately share the native frame pools and globals.

`--locale-scale` loads only the dedicated variant file and helpers. A temporary
overlay prepends a fixture to the original localization file and
supplies `GetLocale() == "deDE"` before addon localization loads, then the runner
sets `UIParent` scale to 1.25 before opening settings. Blizzard's strings have
already loaded in enUS; this verifies German **addon** labels and scaled native
controls, not a fully German client. The fixture records and asserts that distinction.

Native target flows seed data with `A_Admin.SetTarget` and explicitly dispatch
`PLAYER_TARGET_CHANGED`: the pinned admin implementation does not send that event.
Quest decoration uses the native pooled-row template and its real `Setup` method
with public quest data. It does not claim full NPC dialog coverage. Other pinned
API omissions and the narrower resulting checks are recorded in the error map.

## Tables and deliberate deduplication

Tables use named inputs and explicit expected results; they do not calculate an
oracle by repeating production code. Action-bar color precedence, XP formats and
public threat fallback cases now use tables. Stateful paging, combat, caching,
recycling and native restoration sequences remain sequential because their history
is the behavior being tested. Existing cast-bar geometry/validation and profile
name tables remain intact.

Only these redundant checks were removed or relocated:

| Previous check | Retained owner / reason |
| --- | --- |
| Action-bar condition assertions embedded in `modules.lua` | `unit/actionbars/config.lua` keeps the original normalization/rejection/saved-value cases and adds named malformed-input and boundary cases |
| Generic unknown/duplicate module registration and initializer ordering in `modules.lua` | `unit/core/modules.lua` owns the same contracts plus a startup/reload state table; `integration/core/startup.lua` retains actual file loading, TOC ordering, disabled-module API guards and migrations |
| Performance's repeated positive drag-stop/save and standalone drag-stop/save sequence | `integration/editmode/integration.lua` checks the saved position and a reconstructed runtime with both real modules and with Performance alone; `performance.lua` retains callback notifications, drag denial outside Edit Mode/in combat, stop-on-combat/disable, layout, polling and profile restore/stop operations |
| Native Profiles control-presence smoke check | `ui/profiles.lua` now uses those controls to validate, copy, rename, link and delete actual profiles, including canceled operations |
| Native Performance direct-setting smoke check | `ui/performance.lua` now clicks visible checkboxes and checks caption visibility, display height, hidden state and re-enabling |

No locale/startup mode, secret-value guard or native ownership assertion was
removed. Package rejection tests and UI command failure probes remain intact.

The aura timer boundary regression additionally models a 12px font with a 15px
line, checks both growth directions and outside/inside/hidden timer positions,
and rejects measuring native timer text. Its native counterpart seeds two buffs
and uses the actual zero-gap wrapped-row rectangles; see AURA-001 in the error map.

## Current verification

- All 40 isolated Lua scenarios, 9 runner contracts and 22 UI-command contracts pass.
- Package integrity, source consistency and the 0.1.6 manifest audit pass.
- Native Dungeon Maps verification passes **62/62** at 1280×720 for the corrected
  flat fallback hierarchy and World-menu return route. CI runs the same suite
  across ten resolutions, with the latest result recorded by the PR checks. The
  pinned simulator resolves dirty layouts before async OnUpdate callbacks, so the
  initial MapCanvas viewport is checked without a corrective test-side zoom.
- That suite includes Sunken Temple and Upper/unknown Blackrock Spire fallback
  rejection plus native home/right-click, saved-floor, original-backing, tooltip
  ownership and backing-map interaction isolation coverage.
- The unaffected auxiliary same-process lane passed **20/20** with both state
  checks clean; German addon labels at scale 1.25 passed **5/5**.
- The preceding startup/exec sentinels were rejected. The separate callback/cleanup
  contract detected exactly four intentional failures and verified recovery.

CI allows five minutes for the PR UI job, including image preparation and runner
variation; other PR budgets remain unchanged. Counts describe the scenarios above,
not full native-client parity; see the [error map](../docs/test-error-map.md) for boundaries.

## Adding or diagnosing a regression

Choose the smallest layer that reproduces the failure. Use a table for independent
input/output cases and a named interaction flow for stateful behavior. UI flows
must restore their scenario state, wait for actual UI ticks and check captured Lua
errors. A passing mock must not be used to dismiss a failing native flow.

Direct execution still supports each suite's optional upstream source argument;
see its first-line command or [development documentation](../docs/development.md).
Add confirmed failures to [the error map](../docs/test-error-map.md), including
reproduction, expected/observed behavior, cause, regression and current status.
Record fixture failures and simulator limitations separately from addon defects.
