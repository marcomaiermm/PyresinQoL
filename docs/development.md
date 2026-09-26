# Development

## Checks and packaging

Use LuaJIT, Bash 4.3+, Git, curl, zip and unzip. Ubuntu setup:

```sh
sudo apt-get install luajit curl git zip unzip
sh tests/run.sh
bash tests/package.sh
bash tools/package.sh
```

The Lua runner covers language variants and all Edit Mode / Performance activation
combinations. Tests mock game APIs; they cannot certify visuals, taint or combat safety.
Optional upstream check: `luajit tests/experience.lua en /path/to/forever-ui-source`.

The build downloads a pinned BigWigs Packager into ignored `.release/`, packages
with `.pkgmeta`, and verifies `dist/PyresinQoL-X.Y.Z.zip` against the working tree.
It never uploads. The ZIP includes the TOC, license, runtime folders, `Media/` and
the consumer-facing `CHANGELOG.md`; docs, source artwork, tests and tooling stay out.
The packager uses this Markdown file as the CurseForge changelog instead of commit logs.

## Releases

GitHub Actions uses the BigWigs action directly, followed by the shell package audit.
PRs and pushes to `main` run **Tests and package** and retain an installable ZIP.
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

Require the **Tests and package** status check on `main`. Repository administration
access is needed to configure this; local tests alone do not enable branch protection.

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
and extend module expectations and relevant regression tests. New top-level Lua tests
are discovered automatically. Keep `PyresinQoLDB`, existing saved keys, frame names
and `/pqol` stable. General migrations belong in `Core/Database.lua`;
native-settings migrations stay with their feature. Prefer events and bounded
updates; preserve the existing quest cache and disabled-module behavior.

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
`luajit tests/threatmeter.lua /path/to/Blizzard_DamageMeter/DamageMeterEntry.lua`.
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
Run `luajit tests/nameplate-combopoints.lua`; in game, check two enemies, a finisher,
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
