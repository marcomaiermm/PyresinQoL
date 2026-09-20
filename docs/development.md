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
Optional upstream checks: `luajit tests/experience.lua en /path/to/forever-ui-source`
and `luajit tests/threatmeter.lua /path/to/Blizzard_DamageMeter/DamageMeterEntry.lua`.

The build downloads a pinned BigWigs Packager into ignored `.release/`, packages
with `.pkgmeta`, and verifies `dist/PyresinQoL-X.Y.Z.zip` against the working tree.
It never uploads. The ZIP includes the TOC, license, runtime folders, `Media/` and
generated changelog; docs, source artwork, tests and tooling stay out.
Commit changes before building release candidates so the generated changelog matches.

## Releases

GitHub Actions uses the BigWigs action directly, followed by the shell package audit.
PRs and pushes to `main` run **Tests and package** and retain an installable ZIP.
The same checks run on release tags. Actions and the local packager are pinned;
update the packager revision in the local build script and both workflows together.

1. Update `## Version:` in the TOC to `X.Y.Z`, commit and merge the change.
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
