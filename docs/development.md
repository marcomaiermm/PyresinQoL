# Development

## Local installation with GNU Stow

Keep the Git checkout outside WoW and link its runtime files into the game with
GNU Stow. Create a Git-ignored `.stowrc` in the repository root:

```text
--dir=..
--target="/path/to/World of Warcraft/_classic_beta_/Interface/AddOns/PyresinQoL"
--ignore='^(\..*|docs|tests|tools|dist|README\.md)$'
```

Set `--target` to your local addon directory and create it before running Stow.
Run these commands from the repository root:

```sh
stow --simulate --verbose --restow PyresinQoL
stow --restow PyresinQoL
```

Back up and move aside an existing regular installation first; Stow refuses
conflicting files. Do not use `--adopt`, which would move installed files into
the source checkout. Hidden files and development directories are ignored;
Stow's default ignore list also excludes README and LICENSE files. Changes in
linked Lua files are immediately available after `/reload`; restow when adding
or removing top-level files. Restart WoW for newly installed addons or changed
textures. Exclude this development installation from addon-manager updates:
writes through its symlinks would modify the source checkout. To remove the
links, run `stow --delete PyresinQoL`. Releases remain normal ZIPs.

## Checks and packaging

Use LuaJIT, Bash 4.3+, Python 3, Git, curl, zip and unzip. Ubuntu setup:

```sh
sudo apt-get install luajit python3 curl git zip unzip
sh tests/run.sh
python3 tests/tooling/lua-runner.py
python3 tests/ui-runner.py
bash tests/package.sh
bash tools/package.sh
```

The Lua runner discovers `tests/unit/` and `tests/integration/`, prints each scenario
and reports all failures before exiting. Pure validation/registry cases live in
`unit/`; tests using mocked frames, hooks and events live in `integration/`, grouped
by domain. Each file and language/startup variant runs in a fresh LuaJIT process.
The runner checks discovery separately, so an unreadable/missing layer cannot
silently produce a passing partial suite. The Python runner contract exercises this
failure as well as selectors, empty selection and continued execution after failure.
Use `sh tests/run.sh unit`, `sh tests/run.sh integration`, or a domain such as
`sh tests/run.sh actionbars` for focused checks. The default runs every Lua scenario,
including language variants and all Edit Mode / Performance activation combinations.
`tests/tooling/` owns the shell/Python checks; the commands above remain compatible.
See [test architecture and scenario ownership](../tests/README.md) and the
[test error map](test-error-map.md) for coverage, retained regressions and limitations.
Mocked game APIs cannot certify visuals, taint or combat safety.
Optional upstream check: `luajit tests/integration/experience/experience.lua en /path/to/forever-ui-source`.

The build downloads a pinned BigWigs Packager into ignored `.release/`, packages
with `.pkgmeta`, and verifies `dist/PyresinQoL-X.Y.Z.zip` against the working tree.
It never uploads. The ZIP includes the TOC, license, runtime folders, `Media/` and
the consumer-facing `CHANGELOG.md`; docs, source artwork, tests and tooling stay out.
The packager uses this Markdown file as the CurseForge changelog instead of commit logs.

### Forever UI integration tests

Run `bash tests/run-ui.sh` with Docker on Linux. The first run builds a headless
[wow-ui-sim](https://github.com/Osso/wow-ui-sim) image with `client-wowforever`;
subsequent runs reuse Docker's build cache. It fetches the simulator and Blizzard
FrameXML from immutable revisions in `tests/ui/Dockerfile`. The UI source is
Forever **1.60.1.69913**, interface **16001**, matching the simulator profile.
Update these revisions together when adopting a newer client build.
The pinned simulator needs `tests/ui/simulator.patch` to canonicalize file and
addon-root paths before its Forever module-boundary check; otherwise local addon
and TestFramework Lua files are silently skipped. Remove that loader hunk when upstream
fixes this path comparison. The startup assertion catches skipped addon loading.
The same patch makes `run-tests` reject recorded startup errors and failed
`--exec-lua` probes, allowing one fresh simulator per test resolution.
It also makes `screenshot` reject startup, probe and post-probe update errors
before rendering, so the screenshot matrix needs one process per size too.
The patch also restores the original `loadstring_untainted` compiler after the
simulator's environment cleanup, before Forever loads `RestrictedExecution.lua`.
It leaves state-attribute dispatch to the native handler when one is installed,
preventing a second execution through the simulator's raw-frame fallback. The XML
loader also needs the scroll-range and scroll-offset scripts from native scroll
templates. These fixes let tests exercise Blizzard's snippets and scroll controls.
The UI fixture supplies the omitted
`LOSS_OF_CONTROL_ACTIVE_INDEX = 1` from the pinned Forever API documentation,
which the native Edit Mode exit path needs. Neither workaround changes addon code.
The runner also uses a passing fixture to verify that both startup and probe
errors produce nonzero exits before starting the regular matrix.

Every run uses the resolution matrix in `tests/ui/resolutions.txt`, starting a
fresh simulator at each size before the addon loads:

| Display | Resolution |
| --- | --- |
| HD / 720p | 1280×720 |
| Common laptop | 1366×768 |
| Full HD / 1080p | 1920×1080 |
| 16:10 desktop | 1920×1200 |
| QHD / 1440p | 2560×1440 |
| UHD / 4K | 3840×2160 |
| Ultrawide Full HD | 2560×1080 |
| Ultrawide QHD | 3440×1440 |
| Ultrawide 1600p | 3840×1600 |
| Super ultrawide, 32:9 | 5120×1440 |

For a quicker local check, pass one or more sizes, for example
`bash tests/run-ui.sh 1280x720 3440x1440`. All interaction tests run at every
selected size. They also verify the requested viewport, centered settings window,
navigation, headers, visible setting rows and controls against their layout
bounds, using effective scale when comparing coordinates. This catches clipping
and misplaced controls independently of screenshots.

The addon is mounted read-only and runs without network access or saved variables.
The patched `run-tests` rejects startup errors, then runs `tests/ui/*.lua` against
the native Blizzard frames and controls in that same process. Each interaction flow waits for actual
UI ticks and checks its own Lua errors before closing the window. Each flow
retains its error handler for two more ticks after cleanup, then restores the
previous handler before reporting completion. Every resettable
page checks a visible checkbox's setting binding, changes its value, then clicks
Defaults and verifies both the saved value and the rendered checkbox. Profiles
uses native dialogs for validation, copy, rename, layout assignment, deletion and
cancellation. Modules verifies pending-reload markers and locked controls;
Performance clicks the FPS/latency checkboxes and checks captions, height and visibility.
Cast Bar exercises appearance/layout/details controls, live dimensions, preview
content and reset. Action Bars checks the settings launcher, the separate Edit
Mode section for all eight bars, checkbox and opacity-stepper changes, per-bar
saved values, reopening, scrolling to the macro dialog, invalid macro input, and
switching between action bars, cast bar and player frame. It checks that native
settings, addon controls and native buttons stay inside the dialog without
overlapping. A rule configured through the UI must keep the bar visible for the
Edit Mode preview, hide it afterward, and restore it when customization is disabled.
Additional domain flows check native player class-color restoration, visible target
text opacity, target-threat Always/Off selection, XP-bar visibility/format controls,
wrapped timed buffs, reusable quest-row decoration, game-menu shortcut geometry,
tooltip health content and a visible fixed anchor. Target flows seed native data
and dispatch `PLAYER_TARGET_CHANGED`; the pinned admin setter omits the event.
Quest rows use Blizzard's actual pooled-row template and `Setup` method.
These are bounded scenarios: complete NPC dialogs, cooldown-viewer opening and
visible tooltip health-bar rendering have reproduced simulator gaps documented
in the [error map](test-error-map.md). Quest reward/overflow previews also stay local:
the pinned simulator reports no turn-in-ready quests and zero quest XP. Mocked
domain coverage remains in Lua, with native in-game checks for these boundaries.
The standard command additionally runs dedicated error-injection, deterministic
repeat/order and addon-German/scale-1.25 lanes once at 1280×720. Use
`bash tests/run-ui.sh --contracts`, `--isolation` or `--locale-scale` to debug one
lane, and `--matrix [sizes...]` for the ordinary matrix only. Intentional-error probes
must produce exactly their four named failures, restore the error handler and leave
following native flows usable. The isolation lane runs complete representative
files forward and reversed in one simulator and compares saved/native state.
The German fixture runs before addon localization; native Blizzard strings remain
enUS, an explicit boundary of this lane rather than German-client certification.
The shared `00-helpers.lua` loads first and captures errors across actual UI ticks;
the controls, callbacks and state-driver implementation come from Blizzard's UI.
Scroll destinations use measured content and viewport heights: the pinned
simulator's range query does not subtract an anchor-derived viewport height.
Rectangle comparisons include the renderer's scroll translation, which its
`GetRect` omits. These flows run out of combat: the simulator does not model
inherited frame protection sufficiently for native restricted execution in combat.
Combat and controller transitions remain covered by the Lua suite and require
the in-game checks below.
The nested test mount
keeps the existing mocked LuaJIT tests out of the simulator's test discovery.
New simulator tests belong in `tests/ui/`; neither test suite ships in the addon.
CI saves build and test output as the `forever-ui-log` artifact, including failures.
The independent **UI preview** workflow renders each matrix size and saves the
images and render log as `forever-ui-preview`. It runs for PRs, pushes to `main`
and release tags with its own job budget. CI and the reusable release
checks have no dependency on it, so render failures or timeouts do not affect
required assertions or publishing. Do not require **Forever UI preview (optional)**
in branch protection. No screenshot comparison gates releases.
CI does not mount a game install, so Blizzard art is incomplete in its screenshots.
This headless build checks UI behavior, not screenshot appearance or native-client
taint/combat guarantees. Visual release checks still require the game client.

### Develop the UI outside WoW

Start the interactive Forever preview from this checkout on a Linux desktop:

```sh
bash tools/ui.sh preview
```

This builds the separate `dev` target with the same pinned simulator, patch and
FrameXML as CI, starts a local window and opens `/pqol`. Wayland is preferred;
X11 uses the existing display socket and `XAUTHORITY` when present. The renderer
includes software Vulkan, so a GPU device mount is not required. The first build
also compiles the GUI; subsequent starts reuse the build cache. Each checkout
has its own container. Addon files are mounted read-only, so local edits are
available immediately without rebuilding the image.

The test runner, preview and rendering commands capture their build's immutable
image ID with `--iidfile` and use that ID for every container start. Both matrices
build once and retain the same image for all sizes, even if another checkout
replaces the shared convenience tags while they run.

CI caches each final simulator image and its immutable ID, keyed by runner OS,
architecture, Docker target, Dockerfile and simulator patches. Addon code and test
changes are mounted into the restored image and do not trigger Rust compilation.
Outside PR checks, a cache miss builds once per target and saves the image before the assertions,
so failed addon tests can also reuse the build. The GUI target compiles directly
instead of first building a headless binary. Required tests and optional rendering
keep their independent workflows and time budgets. Only the final images are
cached, avoiding Cargo's much larger intermediate build trees.
Both runners accept `WOW_UI_IMAGE=sha256:...` to use a loaded immutable image;
mutable tags are rejected. Normal local commands continue to build using Docker's
layer cache. Changing the Dockerfile or either simulator patch invalidates CI's
image cache.

The PR UI job has a **five-minute timeout**; other PR jobs retain their
**three-minute timeout**. The cached full UI run measured 156.257 seconds locally,
so its budget also allows image preparation and runner variation. PR checks restore existing simulator
images and never compile Rust; a missing image fails promptly with preparation
instructions. `main` and release checks can build on cache misses. The independent
**UI simulator images** workflow refreshes the default-branch caches daily so
normal feature branches can reuse them. It has a separate 30-minute build budget.
For a Dockerfile, patch or simulator revision change, prepare its images before
rerunning the PR checks:

```sh
gh workflow run ui-images.yml --ref main -f source-ref=feat/my-feature
```

The workflow runs on `main` and checks out the requested source, making its exact
image keys available to PRs through GitHub's default-branch cache. The UI matrix
uses ten fresh test processes, two startup/exec probes, one callback/cleanup
rejection contract, one same-process isolation run and one locale/scale run.
Rendering uses ten processes, rather than running an additional preflight for every size.

The simulated UI canvas defaults to **1920×1080**. Select another size with
`WOW_UI_RESOLUTION=3440x1440 bash tools/ui.sh preview`.
`tests/ui/viewport.patch` sets the simulation size before addon loading and fixes
the interactive canvas independently of the desktop window and simulator tools;
smaller windows scroll the canvas instead of changing the addon's layout. The
live screenshot command captures the preview's configured viewport.

Use a second terminal while the preview is running:

```sh
bash tools/ui.sh reload                  # Reread changed Lua/XML and reopen /pqol
bash tools/ui.sh inspect                 # Visible settings subtree and computed layout
bash tools/ui.sh screenshot              # Save dist/ui/preview.webp
bash tools/ui.sh lua 'A_Admin.SetPlayerHealth(50000, 100000)'
bash tools/ui.sh lua 'A_Admin.SetInCombat(true)'
bash tools/ui.sh logs                    # Startup and callback errors
bash tools/ui.sh stop
```

For an offscreen image without a desktop or running preview, use
`bash tools/ui.sh render`. It checks Lua errors and saves
`dist/ui/render-1920x1080.webp`. Select another size with `WOW_UI_RESOLUTION`,
or use `bash tools/ui.sh render-matrix` for all ten sizes. Each viewport is set
before loading the addon, and the corresponding image has those same dimensions.
This uses the GUI-capable image's software Vulkan renderer, without opening a
window or mounting a display/GPU. `WOW_UI_WOW_PATH` also enables local assets for
this command. Headless CI assertions still use `bash tests/run-ui.sh`; render
output is a debugging artifact, not a pixel-comparison gate. An asset-backed CI
render also needs provisioned, fixed game assets; the Gethe Lua/XML sources alone
do not supply the textures.

`reload` restarts the simulator process and resets its unsaved state. In this
pinned version, the upstream `ReloadUI()` and `Ctrl+R` only replay events; they do
not reread addon source files. Reapply a scenario with `lua` after restarting.
The [simulator Admin API](https://github.com/Osso/wow-ui-sim/tree/6a1d81b1c5a1f9771a1b1a7aec6c1361753b3d3f/docs/admin-api)
can seed health, targets, auras, casting and combat. Keep these calls in development
scripts and tests: `A_Admin` does not exist in WoW.

The pinned FrameXML checkout contains Lua/XML, not Blizzard's textures and fonts.
Without local game assets, text and controls remain available but Blizzard art
can be missing. Use `bash tools/ui.sh preview --debug-borders` to show frame and
control bounds while inspecting layout. For asset-backed preview, point at a
compatible Forever install root containing `Data/` and the launcher build/product
metadata, or its `_classic_beta_` client folder:

```sh
WOW_UI_WOW_PATH='/path/to/World of Warcraft' bash tools/ui.sh preview
```

The install is mounted read-only; its SavedVariables and other addons are not
loaded. Docker volumes retain the local asset index and extracted textures across
`preview` and `stop`; the first asset-backed start builds the index. Runtime
networking is disabled. Matching local assets are needed for
faithful art; this preview does not establish native-client rendering parity.

For each UI change: reproduce the state in the preview, edit and reload, inspect
or capture the result, then add the corresponding behavior to `tests/ui/` and run
`bash tests/run-ui.sh`. CI runs those tests in the headless target. Complete the
in-game checks below before releasing changes involving visuals, taint or combat.

## Releases

GitHub Actions uses the BigWigs action directly, followed by the shell package audit.
PRs and pushes to `main` run **Tests and package** and **Forever UI (Docker)**,
and retain an installable ZIP.
The same checks run on release tags. Actions and the local packager are pinned;
update the packager revision in the local build script and both workflows together.

1. Update `## Version:` in the TOC to `X.Y.Z` and rename the `Unreleased` heading in
   `CHANGELOG.md` to that version. Keep entries short, in English, and focused on
   player-visible changes; list the newest version first. The full file is sent to
   CurseForge. Commit and merge the change.
2. Run `bash tools/package.sh vX.Y.Z` and complete the in-game checklist below.
3. Tag that tested commit and push the tag:

```sh
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

Tags must exactly match the TOC version; prerelease suffixes are not supported.
After checks pass, the workflow extracts the validated ZIP, lets BigWigs repack
that directory and upload it to CurseForge, then creates a GitHub release with
the resulting ZIP and generated release notes. Existing GitHub releases are rejected.
CurseForge moderation can delay public availability after an accepted upload.

GitHub configuration: `CF_API_KEY` is a repository secret; `CF_PROJECT_ID` is a
repository variable (currently `1704247`; a secret with that name also works).
Only the publication job receives upload credentials. `GITHUB_TOKEN` handles
GitHub releases. Wago is not configured.

Uploads to two services are not atomic. If CurseForge succeeds but GitHub fails,
do not rerun the whole publication job: inspect the existing CurseForge file,
download the checked ZIP from the run artifact and finish GitHub with
`gh release create vX.Y.Z PyresinQoL-X.Y.Z.zip --verify-tag --generate-notes`.
Do not replace published assets or move release tags; fixes get a new version.

Require the **Tests and package** and **Forever UI (Docker)** status checks on `main`.
Repository administration access is needed to configure this; local tests alone
do not enable branch protection.

### In-game release checklist

- Install the ZIP into a clean addon folder; confirm AddOns icon and `/pqol` open.
- Check an existing installation with saved settings and positions, then `/reload`.
- Enable/disable modules and reload; disabled features stay inactive.
- Exercise affected features outside and during combat, including target changes,
  threat/nameplates, debuffs and druid forms when relevant; watch for Lua/taint errors.
- Check layout and logo placement; record client build and results in the PR.

## Module conventions

`Core/Modules.lua` declares ordered module metadata and settings pages. Runtime
files only register initializers with `ns.RegisterModule`; frames, hooks and events
are created inside the enabled module's initializer. Settings use
`ns.RegisterModuleSettings` and the shared controls. Export feature callbacks on
the module object; cross-module callbacks can be absent when a module is disabled.

To add a feature, register its metadata, runtime and settings, add files to the TOC,
and extend module expectations and relevant regression tests. New Lua tests under
`tests/unit/<domain>/` and `tests/integration/<domain>/` are discovered automatically;
keep fixtures in `tests/support/`. Keep `PyresinQoLDB`, existing saved keys, frame names
and `/pqol` stable. General migrations belong in `Core/Database.lua`;
native-settings migrations stay with their feature. Prefer events and bounded
updates; preserve the existing quest cache and disabled-module behavior.

### Game-menu shortcut

The cooldown shortcut appears inside the game menu immediately below Options.
It is an addon-owned button under `UIParent`, anchored to the native Options button.
It must not be a child of `GameMenuFrame`, enter its automatic layout traversal,
acquire buttons from its pool or call its layout methods. Native
layout traversal of addon children can taint subsequent controller binding changes
and block `SetPreferredGamepadInteractTarget()` when Options closes the menu.

A secure post-hook on the completed native layout reserves one visual row by
adjusting frame anchors and menu height. Original anchors and height are kept in
addon-owned state and restored before each setting update. A fresh native layout
discards the previous snapshot. Native button callbacks and layout indices remain
unchanged; repeated updates cannot accumulate extra spacing. The shortcut inherits
the menu's effective scale and uses a label that fits the native button width.
Its `FULLSCREEN_DIALOG` strata keeps it clickable above the menu's `DIALOG` frame.
Matching the menu's strata with a higher frame level still let `GameMenuFrame`
receive the mouse focus in-game; moving the shortcut to the higher strata restored
clicks. Frame-engine stubs cannot reproduce this input ordering.

The shortcut hides with the menu and while controller UI mode is active, then
returns with the saved setting when mouse/keyboard mode resumes. Its click handler
also checks controller mode and combat before opening the cooldown settings.

`tests/integration/core/settings.lua` checks the ownership boundary, menu lifecycle, native callbacks,
combat, scale, repeated layout passes and controller transitions. The optional Elune check
`elune tools/check-gamepad-menu-taint.lua /path/to/Interface/AddOns` loads native
layout, menu and gamepad binding/action-bar code with frame-engine stubs. It
reproduced the blocked call with the former child button and passes after isolation;
it does not replace an in-game check. Pass `transition` as the second argument to
also exercise mouse/keyboard layout followed by controller mode. After `/reload`,
open Options from Escape in both input modes. Check the shortcut's row inside the
menu, its hover highlight and click, its return after controller mode, and unchanged
spacing after repeated opens.

### Native action bars

Action-bar customization is opt-in and decorates Blizzard's existing action-bar
buttons. In `/pqol → Action Bars`, the global controls can color native icons or hotkeys for
out-of-range, missing-resource and unusable states, choose ARGB colors, set hotkey,
macro-name and count font sizes, and use compact binding text. A size of **0** keeps
the native font size.
In Edit Mode, selecting any of the eight standard bars opens a separate
**PyresinQoL - Visibility** section below its native settings. Enable the feature,
hide for combat, stealth or form state, set normal and combat opacity, show on
mouseover, or enter a validated custom macro condition with `show`/`hide` results.
Defaults leave the native appearance and visibility unchanged.

`Modules/ActionBars/EditMode.lua` owns the extra controls and follows the cast-bar
dialog extension: a post-hook attaches a separate section without adding native
setting IDs or acquiring native setting frames. A single section follows the selected
bar and hides for other systems, including when the cast-bar section takes over.
It also installs when Blizzard's Edit Mode addon loads later. Controls keep their
existing saved keys and registered settings, so defaults and automatic profile
refresh still work. Edits save immediately; Blizzard's Revert Changes button manages
only its native settings. The macro dialog captures the bar it was opened for.
`tests/integration/actionbars/editmode.lua` covers selection, per-bar isolation, delayed loading,
combat guards and coexistence with the real cast-bar extension using frame stubs.

Visibility and opacity use secure state drivers on addon-owned handler frames that
reference Blizzard's existing bars. Visibility uses the custom `barvisibility` state:
the reserved `visibility` state shows or hides the registered handler directly and
never invokes its state snippet. Native visibility drivers remain in place, and
the handler only restores a bar it hid itself; action execution remains client-owned.
Protected setting changes made during combat are deferred until combat ends. When
WoW's controller UI mode is active, action-bar visibility rules are suspended and the
saved configuration is restored when the mode ends. Connecting a controller alone
does not activate this mode. LuaJIT tests can check configuration and mocked callbacks,
but only the live client can
verify visual output, protected ownership, taint and combat behavior.

Run `luajit tests/integration/actionbars/behavior.lua` and `sh tests/run.sh`. To run the visibility
scenarios through the client's native state driver, pass its source directory:
`luajit tests/integration/actionbars/behavior.lua /path/to/Interface/AddOns`. Macro results and frame-engine
methods are still stubbed. In game, check every bar's
combat, stealth, form, custom-condition, opacity and mouseover transitions, then
enter and leave controller UI mode and confirm the native bars resume their saved
rules.

Action-bar dialog registration adds only its own entry to `StaticPopupDialogs`.
Never reassign that Blizzard global, even to the same table: doing so taints its
reference, and later native popup/ESC registration can carry that taint into
`SpellStopCasting()`. `tests/integration/core/settings.lua` rejects global writes from the action-bar
settings builder. The optional native dispatch regression runs with
[Elune](https://github.com/Meorawr/elune):
`elune tools/check-escape-taint.lua /path/to/Interface/AddOns` (use the built Lua
executable as `elune`). It loads the native ESC, Game and HelpFrame code and checks
secure execution after addon registration; it does not replace an in-client test.

### Native player cast bar

`Modules/CastBar` belongs to the existing Unit Frames module. `Config.lua` owns
only `PyresinQoLDB.castBarCustomization` (off by default) and `PyresinQoLDB.castBar`
presentation overrides. `Textures.lua` discovers available native profession art;
`Models.lua` supplies ten visual presets and clipped Blizzard model effects.
`Presentation.lua` shares icon geometry, text placement and border rendering between
the live bar and static settings samples. `Native.lua` securely post-hooks the existing
`PlayerCastingBarFrame`; `EditMode.lua`
adds Appearance, Layout and Details tabs with native controls to its settings
dialog. No replacement cast frame, event handler, casting engine, or native Edit
Mode setting is registered.

Forever already owns **Bar Size** (scale), **Lock to Player Frame**, position,
anchors, and **Show Cast Time**. The addon does not save copies of these settings;
the integrated icon's temporary fill offset preserves their logical position.
Custom width/height and font size use an **Automatic** sentinel instead of persisting
native dimensions. Native look changes refresh the relevant restoration baseline.
The Player addon page contains only enable/configure/reset actions for this feature.
Addon settings save immediately and independently of Blizzard's layout Save/Revert.
The cast-bar reset preserves the enable switch; Player-page Defaults also disables
the feature. Both restore native presentation without resetting Blizzard's layout.

Source of truth: Forever **1.60.1.69913**,
[`CastingBarFrame.lua`](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua),
[`EditModeDialogs.lua`](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_EditMode/Shared/EditModeDialogs.lua),
and [`ProfessionsRankBar.lua`](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRankBar.lua)
/ its adjacent XML. Profession kit names come from `Enum.Profession`, as in
`Professions.GetAtlasKitSpecifier`. Only requested profession atlases returned by
`C_Texture.GetAtlasInfo` with usable metadata are exposed; missing styles are not
substituted with a fabricated profession or a generic blue bar.

These assets are flipbooks, not drop-in StatusBar fills. The registry records their
row count (two columns, 34-pixel cell height) and first cell for static samples.
The saved `animated` option defaults to true. The **Animated** checkbox below the
Edit Mode texture selector disables flipbook playback and keeps its first cell
visible; model styles remain animated and show a checked, disabled checkbox.
Blizzard default has no custom flipbook and shows an unchecked, disabled checkbox.
During casts/channels, one native `FlipBook` plays forward with ordinary `BLEND`.
Known source files use the prepared loops in `Media/CastBar`: their final 300 ms
are blended into the beginning offline, in premultiplied RGBA, then converted back
to straight alpha. The wrap therefore traverses adjacent source frames. Color and
coverage are interpolated together before the game composites a single layer;
there are no runtime opacity fades, overlapping passes, or frame buffers.
The original frame rate is retained. Removing the overlap shortens a typical
60-frame/two-second animation to 51 frames/1.7 seconds. The native rank-bar speed
also determines the durations for Enchanting's 74 and Jewelcrafting's 44 frames.
The 16 included BC3/BLP textures cover all 13 professions and the three Forever
variants, at 512×32 pixels per frame (about 16 MiB total). They use two columns and
32 rows, with only the generated frame count played. Source file ID and row count
must match; unfamiliar client artwork falls back to a single native two-second
flipbook. Static previews, Animated off, and interruption still use the original
client artwork.

`Media/CastBar/sources.json` records the source build, file IDs, exact atlas bounds
and SHA-256 checksums. To regenerate, extract these BLPs from the recorded client
as `pyresin-atlas-<fileDataID>.blp`, then run
`python3 tools/build-profession-loops.py --source-dir /path/to/extracted/files`.
The build tool uses numpy, Pillow and ImageMagick; the addon has no new runtime
dependency. Without `--source-dir`, it runs the RGBA regression check. Generation
also decodes the shipped BC3 blocks and checks their color/coverage against the
uncompressed result. Blizzard's source artwork retains its original ownership.

Profession artwork uses Blizzard's displayed Fill size (441×18 UI units), scaled
by bar height / 18 and anchored on the left. Bar width never enlarges the artwork.
The native mask reveals its left portion; bars wider than the scaled artwork show
only their background beyond its right edge. Static and menu samples use the same
scale and stop at the first cell's edge. This also applies to resized loop files.
The stationary texture shares the native fill mask and selected tint. Animation
changes UVs; progress changes only the mask. Both remain engine-owned, with no Lua
arithmetic on restricted cast values or per-frame updates. One animation group is
reused; `GetTime() % duration` preserves phase through refreshes and consecutive
casts. Hide stops playback; showing the next cast resumes it. Clear, reset,
disable, and native fallback clear animation eligibility. Tests cover the original
RGBA composition reference, forward sequence, wrap, runtime lifecycle, native
fallback, and Animated controls. Final visual acceptance still requires the client.
The original fill is hidden while custom art is active and restored for native
fallbacks, reset and disable. No second StatusBar is created.
The texture menu shows each cell as a swatch, prefixes profession entries
with `Professions:`, and scrolls within 420 units. The closed selector uses one
flat frame around the name and padded swatch instead of stretching a one-line atlas.
The fixed-progress sample above the tabs previews the complete configured bar.

Model presets use the colors and built-in model IDs/transforms from
[the reference collection](https://wago.io/xeJOxehA8):
[Astral](https://wago.io/mNJRj47pM/1.0.4), [Celestial](https://wago.io/e7OWqrrSx),
[Ember](https://wago.io/rG6nr7nWU), [Fel](https://wago.io/YWaNciV4v),
[Flux](https://wago.io/vrADoIkLX), [Galaxy](https://wago.io/Uos2_REtN),
[Nebula](https://wago.io/9dTTb_PrA), [Sage](https://wago.io/WvUzCLRuc),
[Sunset](https://wago.io/YvE6OQvhQ), and [Void](https://wago.io/5xziQvVrN).
No imported aura code, triggers or actions execute. At most two PlayerModels per
bar/swatch are shown, with separate reused frames for legacy and custom-camera transforms.
Poses follow the reference's active API: legacy models use `SetPosition(z, x, y)`
and `SetFacing(rotation)`; inactive transform fields are ignored. No additional
model-space rotation or translation correction is applied.
Each model loads on `OnShow`, when its entire parent chain is visible, and reapplies
its pose on `OnModelLoaded`. Caching a file ID is insufficient after hiding: spell
models may retain the ID without restoring their rendered state. Native cast
progress, unchanged refreshes and unrelated settings changes do not reload models.
The harness models parent visibility and this hide/show lifecycle, including a delayed load resetting the model transform.
Model viewports follow the reference's `bar_model_stretch`: Astral, Celestial,
Ember, the first Flux model, Galaxy, the second Nebula model, Sage and Sunset
anchor to the native progress texture, so their position and dimensions change
with cast/channel progress. Other models retain a full-bar viewport. Integrated
icons are excluded from both viewports.
Their containers flatten render layers. Foreground models clip to current native
progress, including channeling; the reference's background layers in Astral, Fel
and Nebula clip to the full bar, so particles also appear over the unfilled area.
Zero/restricted clip dimensions hide only that clip's models. Native anchors
update the geometry without progress arithmetic or per-tick model reloads.
Native foreground regions and their masks temporarily sit above the models;
original parents and selection levels return on fallback/reset/disable.
Model presets replace the native background with the same base texture as the fill,
tinted with the reference background color (not the foreground gradient): dark blue
for Nebula, dark green for Fel, and black for the other presets. Automatic opacity
uses each reference's alpha; an explicit background opacity overrides it. The full
settings preview uses the same painter. A separate background region preserves all
of Blizzard's original background art and anchors for fallback/reset/disable.
Model styles always restore Blizzard's interrupted/failed artwork, regardless of
the saved custom-interruption preference, and hide their base fill and particles.

Texture dropdown swatches, including the closed selector, show the same clipped
models as the live bar. Menu resetters hide effects before pooled buttons are
reused; ordinary textures never create models. The full layout sample above the
tabs remains static and shows only the base texture/gradient.
Live art, swatches and the full preview share one color application path. Uniform
`SetVertexColor` replaces gradient corner colors, so it must precede any preset
gradient. Class/custom tint intentionally replaces the original palette; neither
live rendering nor the full preview overwrites Original with white afterward.
Live particles and menu previews require in-game visual acceptance; mock tests
verify configuration, clipping anchors and reuse, not particle rendering.
The references use a 280 × 28 bar with an icon. A thin native bar still has
a different viewport aspect ratio from the reference. Selecting a texture never
changes the user's bar dimensions. If another installed addon registers `DGround` or
`Gradient` with LibSharedMedia, its exact base texture is used without honoring a
global media override. Otherwise the preset uses native solid art (DGround's base
brightness is retained); third-party image files and WeakAuras are not required.
Fel's missing `Gradient` media uses a native horizontal brightness ramp from 35%
to 100%, a visual approximation of the reference. It preserves class/custom
tints, and partial previews sample the same ramp rather than compressing it.
An installed `Gradient` texture takes precedence and is not shaded a second time.
Model poses, foreground/background attachment and stretch behavior follow the
references. Different bar dimensions and fallback media can still change the
appearance compared with the WeakAura screenshots.

Integrated icons reserve a square of bar height plus a one-unit divider inside
the configured total width: 240 × 22 gives a 217-unit native fill. The native
StatusBar remains the sole cast engine; texture, spark mask and latency all use
its reduced fill area. Exterior icons keep the native fill width and use a
0–12-unit gap. Automatic preserves the existing native/Compact behavior.
Selection anchors and clamp offsets cover the icon and decorative overhang,
feeding Blizzard's existing snapping code.
The native fill receives an anchor-dependent inset so changing icon placement
keeps the outer bar's position, width, height and scale stable. Edit Mode stores
the logical outer anchor, excluding this inset, so dragging and reloading do not
accumulate offsets. Icon choices preserve the selected Native/Compact text layout.

Border settings are `borderStyle`, `borderColorMode`, `borderColor`,
`borderOpacity` and `borderSize`; exterior spacing is `iconGap`. Thin and Inset
use solid native texture edges outside the fill, with fixed physical-pixel strokes.
Tinting the Blizzard border desaturates its original art; Original restores its
captured color and saturation. The native interruptibility shield remains separate.
Legacy `showBorder` migrates to `native`/`none`, unless an explicit style exists.
Reset/disable restore native sizes, anchors, tint, text wrapping and selection bounds.

The optional Compact layout places the native spell name and time inside the bar,
uses a 240 × 22 default with a left icon and 12-pixel Blizzard fonts, and suppresses
the lower text-box decoration. Explicit dimensions, font and icon choices win.
Native anchors, text alignment, fonts and spark height return on reset/disable.
The live bar and full preview apply the same captured native text baseline before
custom placement; native look changes refresh only the fields Blizzard changes.
The dialog reveals color pickers, border thickness, exterior spacing and latency opacity only when relevant, reserves
space above each slider for its value. Details switches between spell-name and
cast-time controls: independent `namePosition`/`timePosition`, `nameAlignment`/
`timeAlignment`, and `nameSpacing`/`timeSpacing` (Automatic is -1; explicit 0–24).
Automatic follows Native/Compact; positions include inside/above/below, with
left/right exterior positions also available for time. Spacing is horizontal
padding inside, or the gap from the bar outside. Font size remains shared.
Native Show Cast Time owns visibility; hidden time controls explain that setting.
Text rectangles never read or measure spell/time content. Time reserves a fixed
slot and names use the remaining contiguous space; if none remains, the name is
transparent until space returns. Icons are excluded, and selection bounds include
external text. The preview uses the same geometry. Addon overrides still save immediately; Blizzard's Revert applies to
Blizzard's own layout settings.
Original color keeps native profession pixels untinted. Interrupted/failed custom
textures are desaturated with a dark-to-bright red gradient and a narrow, fading
upper highlight made from a solid native texture. Both use the same native fill
mask; the highlight stays below text and never enters an integrated icon slot.
There is no additional pattern, animation, shader program or per-tick work.
The next cast resets the gradient; native fallbacks, reset and disable hide the
highlight with the custom fill. Blizzard still owns the message,
progress and animations. `customInterruptTexture` defaults to true; the Details
checkbox is visible only for non-default textures without models. Model styles
always use Blizzard's interrupted/failed art. False immediately restores native
interrupted/failed art without changing the regular casting texture, persists
across reload, and resets to true. Default interrupted art stays native, as does
uninterruptible art unless explicitly tinted. Restricted state falls back to
native art; restricted progress is passed through by native mask geometry. The optional
latency zone uses reported **world network latency**, not per-cast send timestamps.

Run `sh tests/run.sh`. `tests/castbar.lua` runs configuration/persistence, textures,
models, layout and Edit Mode scenarios in separate Lua processes using
`tests/support/castbar.lua`; each scenario can also run directly.
To exercise the actual pinned native transition methods,
download the linked `CastingBarFrame.lua` and run
`luajit tests/castbar.lua /path/to/CastingBarFrame.lua`.
The harness covers cast/channel/interrupt/failure/uninterruptible transitions,
delays, stationary masked artwork during ordinary/reverse progress, interruption tint, color modes, icon sizing, font/text,
spark/border/background, latency, reset/disable, native look changes, reconstructed
saved-variable sessions, legacy migration, all six icon layouts, minimum/maximum
dimensions, text collisions/placement/spacing, border scale/opacity, selection restoration, UI controls and picker
cancellation. Frame rendering is
mocked: these checks do **not** certify in-client visuals, secret-value enforcement,
taint, combat safety, or an actual reload/relog.

Before release, check those behaviors in Forever with short/long casts, each
available profession texture, both attached/detached native looks, different UI
scales and dimensions, Edit Mode entry/exit and switching to another system.
Check texture clipping at partial progress, native fonts and decorative tints,
then disable/reset during a cast, `/reload`, relog, and verify saved settings.
Watch for Lua/taint errors both in and out of combat.

### Player and target aura layouts

`PlayerAuras.lua` post-hooks the native player buff/debuff button and grid updates.
The optional layouts only reposition existing buttons; native aura assignment,
tooltips, cancellation, weapon enchants, consolidation and Edit Mode remain active.
Separate saved `buff*`/`debuff*` settings control ownership groups, index/name/time
sorting, direction, rows, icon size, spacing and timer presentation. Position and
scale remain native. Restricted sort fields use a stable fallback. Private boss
aura anchors retain their native contents, horizontal 30×40 or vertical 60×30
footprint, and reserved space beyond row limits. Button offsets use unscaled
coordinates because native button scale already applies; owner bounds scale once.
Settings callbacks apply presentation directly and never invoke native aura
rendering, which compares restricted stack counts. Native grid post-hooks capture
geometry so disabling restores it without calling Blizzard's data refresh.
Outside timers reserve actual font line height, measured with a hidden addon-owned
constant sample, plus the configured timer gap. They never read native timer text
or its rendered height. This prevents adjacent wrapped rows from overlapping when
a font's line height exceeds its configured size, even with zero row spacing.
Disabling also restores icon art, duration fonts and mouse access.

`TargetDebuffs.lua` applies target sizes, spacing and widths through the native
container's public setters, and applies matching geometry to its custom debuff
groups. Custom button sizes are updated only when every allocated button reports
public access through `CanBeAccessedInContext`; combat exit and world entry retry
deferred changes. New buttons use the last applied group sizes. Timer-group
switches and container positioning remain available while buttons are restricted.
Native castbars never depend on the custom container's restricted geometry.

These methods were checked against Forever **1.60.1.69913**
([player aura source](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua),
[target container](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_UnitFrame/Shared/TargetFrameAuraContainer.lua),
[custom container](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua)).
Run `luajit tests/integration/unitframes/playerauras.lua`, `luajit tests/integration/unitframes/targetdebuffs.lua` and
`sh tests/run.sh`. To exercise native grid restoration, run
`luajit tests/integration/unitframes/playerauras.lua /path/to/BuffFrame.lua` with the pinned source above.
Mock checks do not certify rendering, access restrictions or taint safety. In game,
check both layouts, ownership/reverse sorting, row limits, private boss auras,
weapon enchants, collapsed/consolidated buffs, UI scales, Edit Mode examples,
target-of-target, mirrored target auras, combat changes, defaults and `/reload`.

### Target and focus threat visibility

`targetThreat` is now a string: `off`, `auto`, `combat` or `always`. Database
initialization maps the old false value to `off` and true/missing values to `auto`;
saved string modes survive reloads. The dropdown defaults to `auto`, preserving
Blizzard's native numeric indicator and its visibility rules.

`TargetThreat.lua` uses independent regions in `combat` and `always`, anchored to
the existing numeric indicators when auras are below the frame. With mirrored
auras, the addon badge moves to the right of the target/focus frame, since Blizzard
reserves overhead clearance only for a shown native indicator. A secure post-hook
on aura configuration updates only the addon badge when mirroring changes; native
aura placement and indicator geometry remain untouched. Dimensions, border, background and font match
Forever 1.60.1.69913's
[`TargetFrame.xml`](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.xml).
These modes disable the native numbers through `threatShowNumeric`; they do not
call, replace or hook the native threat formatter or aura placement. `off` preserves
the warning CVar. All enabled modes retain the existing `threatWarning = 3` behavior.

The new modes show percentages for living, attackable targets and focus units.
Combat visibility follows player combat lockdown. A publicly readable positive
lead is selected while tanking; otherwise the raw percentage remains visible,
including 0%. Missing percentages show an em dash, or 100% when tanking is known.
Secret percentages go directly to `SetFormattedText`, secret tanking booleans to
`SetAlphaFromBoolean`; secret threat states use a neutral color. Restricted lead
values cannot be tested for zero, so these modes retain the raw percentage instead
of risking a blank display or a restricted-value comparison. Nameplates are unchanged.
Health events are registered only for target/focus and refresh the affected display.
Faction events refresh target/focus individually or both when the player changes
faction; unrelated units are ignored. Layout changes do not query threat values.

Run `luajit tests/integration/unitframes/targetthreat.lua` and `sh tests/run.sh`. In game, check all modes,
combat entry/exit, aggro takeover, target/focus changes, death, friendly units,
small focus frames, mirrored aura layouts and Edit Mode. Offline checks do not
certify layout or taint safety.

### Damage-meter Threat display

Unit Frames adds **Threat** to Blizzard's damage-meter type dropdown through
`Menu.ModifyMenu("MENU_DAMAGE_METER_WINDOW_TRACKED_TYPE", ...)`. Its Focused Rage
icon sits left of the label, desaturated while inactive and colored while active.
Selecting Threat overlays the meter's bars and changes its heading to **Threat**.
Selecting any native type, including the already selected one, exits the overlay
and leaves Blizzard's new heading in place. There is no separate header button.

The native heading's previous text is retained while Threat is displayed and
restored temporarily in Edit Mode. The type dropdown is anchored directly to the
header, and the native timer is placed after the title, before the segment button.
The popup's native `menuAnchor` stays untouched. This keeps menu geometry from
depending on the secret timer text; changing only the Threat row is insufficient
because Blizzard measures the native category rows too.
All threat state and rows belong to the addon. Never write native meter types or
window data, replace the popup's menu anchor or dimensions, hide source details,
replace native methods, or call native refresh from the extension. The Threat menu entry uses a
fixed-size XML button through `CreateTemplate`; its initializer changes only the
label, icon saturation and click handler. Do not add compositor attachments:
their automatic sizing performs unnecessary region measurements. The native menu
owns the final row widths and placement.

The existing 0.2-second poll discovers new windows, updates native styling, and
exits Threat if the native type changes elsewhere. Minimized windows hide the
overlay through their container. Restricted threat values go only to display sinks.

Run `sh tests/run.sh`. The threat test covers menu selection, same-type return,
icon state, heading restoration, native-state preservation, restricted values,
scrolling, Edit Mode, and new windows. Optional native row style check:
`luajit tests/integration/unitframes/threatmeter.lua /path/to/Blizzard_DamageMeter/DamageMeterEntry.lua`.
Offline tests do not certify WoW's frame-layout/taint behavior. After `/reload`,
select Damage Done, enter combat, attack an NPC until meter rows appear, then open
the type dropdown. Check switching to Threat and back, repeat menu opening, and
source details during combat.
If an old saved meter type is invalid, select **Damage Done**
in Blizzard's menu and reload.

### Per-unit status text

The Status Text page independently hides pet, target, target-of-target and focus
health/resource text, including native hover text and Dead/Unconscious labels.
Defaults leave all text unchanged. The addon adds no hover overlay or bar-script
hooks. Only font opacity is changed and restored; no status-text CVars, formatter
calls or native visibility flags are modified.

The Forever 1.60.1.69913 target-of-target template has no numeric text; its toggle
covers the existing state labels. Frame paths were checked against the pinned
[Blizzard source](https://github.com/Gethe/wow-ui-source/tree/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_UnitFrame).
Run `sh tests/run.sh`. In game, check each toggle, mouseover, target/focus changes,
pet dismissal/resummoning, native text formats and combat; mocked tests cannot
certify taint safety. Reload after updating from the removed global text selector.

### Nameplate combo points

For rogues and druids, each native nameplate queries `GetComboPoints("player", unit)`
on power and target changes. No target history is cached: independent enemy counts
depend on what the client returns. Native status bars render the point textures and
accept secret counts without Lua comparisons; zero leaves the row visually empty.
The layout retains the last public maximum (initially five) while it is restricted.
The display is below the cast bar and has a live toggle in both `/pqol` and Blizzard's
nameplate options. The native preview uses three sample points.

API and lifecycle were checked against Forever 1.60.1.69913
([UI source](https://github.com/Gethe/wow-ui-source/tree/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e)).
Run `luajit tests/integration/unitframes/nameplate-combopoints.lua`; in game, check two enemies, a finisher,
target switching, recycled plates, druid forms and combat restrictions.

### Native nameplate preview selector (withdrawn)

Manual preview selection is not loaded. Client reports showed that calling the
native preview methods from an addon taints the preview's pooled UnitFrame:
`CompactUnitFrame_UpdateHealPrediction` fails on secret health values after a
settings change, and switching contexts can fail inside `GridLayoutUtil` on secret
aura dimensions. Wrapping the native type callbacks in `securecallfunction` did
not fix this; it is a taint containment boundary, not an elevation of addon code.
The earlier LuaJIT tests checked dispatch only and did not reproduce WoW taint.

The inspected Midnight 12.1.0.69875
[`Nameplates.lua`](https://github.com/Gethe/wow-ui-source/blob/78282522143e25c3540583734fd192c3d69be910/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Nameplates.lua)
uses `NamePlatePreviewTemplate.NamePlate`, registered under
`NamePlateConstants.PREVIEW_UNIT_TOKEN`. Its four contexts are the combinations
of `IsPlayer()` and `IsFriend()`. Aura/simplified setting callbacks reach
`SetExplicitValues`; no public preview-selection API or exposed secure delegate
was found. `CreateSecureDelegate` is removed before addon loading by Blizzard's
`Blizzard_EnvironmentCleanup/EnvironmentCleanup.lua`.

Further invocation-path investigation (2026-09-20):

- The aura setting initializers expose native `OnShow` callbacks for enemy NPC,
  enemy player and friendly player. Their local `TogglePreviewNamePlate*` helpers
  still call the same preview methods; copying these callbacks into an addon menu
  is not a secure dispatch boundary (`Blizzard_Menu/Menu.lua`, `SecureCallResponder`).
- Friendly NPC is selected by `ToggleSimplifiedType(FriendlyNpc)`. Its native
  settings caller first writes `nameplateSimplifiedTypes`; reusing that caller
  would change gameplay settings. Minion and minus-mob variants also exist in
  `ToggleSimplifiedType`, despite sharing the Enemy NPC preview label.
- Secure handlers cannot call the preview methods with secure execution:
  `Blizzard_RestrictedAddOnEnvironment/RestrictedFrames.lua:CallMethod_inner`
  explicitly calls `forceinsecure()` before invoking the method. The documented
  `C_NamePlate`/`C_NamePlateManager` APIs expose no preview-type setter.
- An offline experiment using [Elune](https://github.com/Meorawr/elune) loaded the
  pinned native `Nameplates.lua` and observed execution at `UnitFrame:SetExplicitValues`.
  The native baseline was secure; both addon `securecallfunction` dispatch and a
  native callback copied into an addon responder field were insecure. Elune's
  scripted taint conformance tests passed. This checks those Lua dispatch paths,
  not Midnight secret values or the engine's timer/frame-script dispatch; it is
  not an in-client safety certification for an alternative implementation.

The relevant preview mixin and grid-layout source also match Forever 1.60.1.69913
([source](https://github.com/Gethe/wow-ui-source/tree/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e));
the observed failure is not explained by using a pre-Midnight preview implementation.
No supported addon-initiated route satisfying all preview modes without settings
writes has been established. User testing confirmed no further errors after a
fresh reload with the selector removed; the other nameplate extensions remain enabled.

Do not reinstate the selector based only on mocked tests, add wrappers around the
failing native layout functions, or edit pooled frame fields. It requires a
supported entry point and in-client confirmation that choosing every context and
subsequently changing native settings leaves health prediction and aura layout
untainted. Blizzard's automatic preview selection is left intact. After installing
this mitigation, `/reload` discards frames tainted by the previous implementation.

## Settings migration

Addon profiles keep the current settings at the existing `PyresinQoLDB` keys.
`profileStore` contains the active name, inactive snapshots, per-character
`characterBindings` (layout → last chosen profile), per-character `profileLayouts`
(profile → assigned layout) and a pending manual switch.
Legacy flat `layoutBindings` migrate to the current character without resetting
settings. Profile rename/delete updates references for every character.
On first use, existing settings become **Default** without changing their values.
The live root is authoritative for the active profile; snapshots are deep copies,
excluding `profileStore`. A manual switch records its target and reloads. Startup
captures the outgoing profile, including logout writes, applies the target, then
runs existing migrations and initializes modules/settings.

`C_EditMode.GetLayouts()` returns saved layouts without presets; `activeLayout`
includes preset indices. Use `Enum.EditModePresetLayoutsMeta.NumValues` for the
offset. Bind presets by index, account layouts by type/name and character layouts
by GUID/type/name. Names, rather than list positions, survive deletions. A single
rename between consecutive observations of the same character in the current
runtime carries its binding forward. The first observation after login/reload or
a character change only establishes a baseline; discard legacy saved catalogs,
which may have missed deletions and creations while that character was offline.
Capture the catalog synchronously on every native update so a delete/add burst
cannot look like a rename, then defer
applying profiles until the next frame. Specialization, login and combat-exit events
also synchronize; combat defers application. Read fresh API data rather than the
event payload, which Blizzard mutates when inserting preset layouts.

The first layout binds to the existing profile. New layouts copy current settings;
manual create/select rebinds the current layout. Several profiles may share a
layout; each character remembers its own choice, including account layouts and
presets. Explicit assignment in **Profiles → Edit Mode Layout** changes the link
without selecting or saving a Blizzard layout. Same-layout events refresh the
page without overriding that assignment. Automatic switches preserve the
root and module table identities retained by native settings, restore all values,
run migrations, and use `SettingMixin:NotifyUpdate()` to refresh controls/callbacks.
Stop an FPS/latency drag before saving its outgoing profile, and restore the incoming
position after callbacks. Modules still need a fresh runtime when enabled/disabled;
the normal reload footer remains available and a reload prompt waits until Edit
Mode closes. Profiles remain account-wide; character-layout bindings include their
owner. Profile operations never write native layout data or add Edit Mode controls.

The **Profiles** page sits outside category groups at the bottom of the sidebar;
there is no header dropdown. It has separate profile selection, layout assignment,
create/rename and inactive-profile deletion controls. Page defaults are hidden.

Run `luajit tests/integration/core/profiles.lua` and `sh tests/run.sh`. In Forever, verify the `/pqol`
Profiles tab, German labels, create/rename/delete, manual assignments and automatic
layout switching with different module choices, cast-bar overrides and FPS/latency
positions. Check presets, layout renames/deletions, character layouts on two
characters, multiple profiles sharing a layout, separate character choices for
account layouts/presets, `/reload`, relog and specialization changes. Confirm combat defers
automatic application, unsaved Blizzard changes block manual switches, and reload
prompts wait until Edit Mode closes. Mock tests cannot certify in-client layout,
taint or combat safety.

When moving from the old addon name, close WoW and back up the account's
`WTF/Account/<account>/SavedVariables/` directory. Copy the old addon's `.lua`
file to `PyresinQoL.lua` and rename its top-level table to `PyresinQoLDB`.
Keep the original backup, disable/remove the old addon folder, then restart WoW.

## Branding

`docs/branding/logo.png` is the 400 × 400 project logo, displayed at 160 × 160
in the README. `Media/AddonIcon.tga` is the 128 × 128 uncompressed RGBA game icon.
Original artwork is retained under `docs/branding/source/`. Rebuild with ImageMagick:

```sh
magick docs/branding/source/logo.png -crop 1076x1137+89+52 +repage -filter Lanczos -resize 384x384 -gravity center -background none -extent 400x400 -strip PNG32:docs/branding/logo.png
magick docs/branding/source/addon-icon.png -crop 1029x1179+126+29 +repage -filter Lanczos -resize 124x124 -gravity center -background none -extent 128x128 -strip -type TrueColorAlpha -depth 8 -compress None Media/AddonIcon.tga
```

Restart WoW after texture changes and check AddOns, the settings launcher and `/pqol`.
The CurseForge project avatar is uploaded separately from the in-game icon.
