<p align="center">
  <img src="docs/branding/logo.png" alt="PyresinQoL logo" width="160" height="160">
</p>

# PyresinQoL

Quality-of-life options for WoW Forever 1.60.1 (Interface 16001).

Install in `Interface/AddOns/PyresinQoL/`, with `PyresinQoL.toc` directly inside.
Settings use `PyresinQoLDB` in the account's `SavedVariables/PyresinQoL.lua`.
When upgrading from a previous addon name, close the game, copy its saved-variable
file to this new filename and rename the top-level table to `PyresinQoLDB`.
Keep the original file as a backup. Restart the client after renaming the addon.

Open the standalone settings window with **`/pqol`**, or use
**Settings → AddOns → PyresinQoL → Open PyresinQoL**. The window uses the native WoW
frame and category styling also used by DragonflightUI, with collapsible groups:

- **General:** Modules, Game Menu and Edit Mode.
- **Unit Frames:** General status text, Player Frame, Target Frame and Nameplates.
- **Misc:** FPS & Latency, Experience Bar, Quests and Tooltips.

Toggle entire modules under **General → Modules**. Disabled pages are gray;
`*` marks pending module changes. Drag the title bar to move the window;
Escape or either Close button closes it. The window scales down for smaller screens.

Use **Reload UI** to apply module switches (unavailable in combat). Disabled
modules install no hooks, event listeners or display frames after reload.
Individual settings and positions are preserved, and disabled modules' options
are locked until re-enabled and reloaded. Existing installations keep all modules
enabled. Edit Mode and FPS & Latency can run independently.
Shared Blizzard settings already changed by the addon, such as status text,
threat CVars and aura caster names, remain saved as game preferences.

**Defaults** resets the current page's options; on the Modules page it
re-enables all modules without resetting their individual options or positions.
Run `luajit tests/modules.lua` and `luajit tests/menu.lua` for module lifecycle
and menu checks; use `luajit tests/menu.lua de` for German labels.
Visual layout still needs an in-game check after `/reload`.

In **PyresinQoL → Misc → Tooltips**, toggle live `current / maximum`
HP on the unit tooltip's health bar, the rank beside the guild name, and cursor
anchoring for signs and other world objects. Unit, item and spell tooltips keep
their normal positions. All three options are enabled by default.
Run `luajit tests/tooltip.lua` for regression checks.

In **PyresinQoL → Unit Frames → General**, choose the shared Blizzard
status text: None, Percent, Both or Numeric Value.
This controls HP and resource text for player, target and other native unit frames.
Player Frame and Target Frame pages provide independent class-color toggles and nine
HP/resource text positions. Positions apply to Percent and Numeric Value;
Both keeps Blizzard's left/right split. NPC targets retain their native color.
Hovering a player or target HP/resource bar shows its current / maximum values;
leaving it restores the selected display. Blizzard's native tooltips remain available.
Class coloring preserves Blizzard's texture. Previous custom player text formats
migrate once to the shared setting (HP takes precedence).
Run `luajit tests/unitframes.lua` and `luajit tests/menu.lua` for regression checks.

Player **Show druid mana while shapeshifted** is enabled by default. A small blue
bar below the player resource bar shows current / maximum mana in Cat and Bear
Form, while the main bar keeps energy or rage. Normally it hides in caster form and vehicles,
follows the player frame, and updates on resource events without polling.
Restricted mana values pass directly to the engine without Lua calculations.
Run `luajit tests/druidmana.lua`; verify placement and combat shapeshifting in-game.
The temporary all-class test mode has been removed; saved preview flags no longer
enable it. Pet positioning remains unchanged.

Target **Show threat percentage** is enabled by default and uses Blizzard's
colored numeric indicator above the frame, including threat lead while tanking.
Blizzard handles updates, visibility and positioning. Enabling sets the global
`threatShowNumeric` option and `threatWarning` to always, also affecting focus
numbers and threat warnings outside groups. Disabling hides the numbers and
leaves threat warnings enabled. Check live threat display in combat after `/reload`.

**Unit Frames → Nameplates → Show threat percentage** is enabled by default.
It shows a larger, outlined percentage without a background or border
beside each enemy health bar. **Threat display position** selects Right (default),
Left, Above or Below in both `/pqol` and the game's **Options → Nameplates**.
Changes apply immediately to visible nameplates and the preview. The addon uses
fixed native anchors, with no collision polling or measurements of restricted frames.
The extra Blizzard options stay visible but are grayed out while the Unit Frames
module is disabled, including after reloading.
The number uses Blizzard's threat status
colors (gray, yellow, orange, red); restricted or unavailable states remain neutral.
With the assigned **Tank** group role, secure aggro is green, insecure aggro blue,
rising threat yellow, and low/unknown threat white. Role changes recolor existing
labels and the preview immediately; players without an assigned Tank role use
the normal colors.
The value is your raw threat
relative to the current tank, or Blizzard's threat lead percentage while tanking,
matching the values used by the target indicator. It works independently of that
indicator. With Unit Frames enabled, the same checkbox also appears under the
game's **Options → Nameplates**, whose preview shows a sample **125%** in green for tanks and red otherwise.
Turning the setting off clears both live numbers and the preview immediately.
Percentages use whole numbers rounded down; values below 1% leave no text or percent
sign, including restricted values and the tank lead. Blizzard's native
`C_StringUtil.TruncateWhenZero` and `WrapString` handle this without Lua comparisons
of secret numbers.
Threat events update the labels; pooled nameplates reuse them without retaining
the previous enemy's values. Restricted numbers and the tanking boolean pass
directly to native text formatting and alpha selection.
Run `luajit tests/nameplates.lua`; verify positioning, preview and combat in-game
after `/reload`. This targets the native Forever nameplates.

Target **Debuff duration and caster** adds a debuff row after the native buffs,
with Blizzard's native cooldown countdown numbers, using aura display timing.
Caster names use Blizzard's native aura tooltip line;
no separate name label is drawn above the icon. The addon enables the global
`tooltipShowAuraCasterNames` option at login, also applying to other aura tooltips
and remaining enabled when the custom debuff row is turned off.
The row follows the target's native aura area with a 3-pixel gap, including when
auras are above the frame. Castbar and target-of-target offsets do not move the row.
Blizzard retains castbar positioning.
The native spell tooltip remains available. **Timers only for my debuffs** is
enabled by default (including your pet/vehicle); disable it for other casters' timers.
Other debuffs remain visible. Own debuffs come first, with up to 16 own and 16
other debuffs. Disable the feature to restore the native debuff row.
The client manages durations, permanent auras, caster names and aura updates through
its custom aura container API, without addon reads of restricted aura data.
Run `luajit tests/targetdebuffs.lua`; hover rendering and combat need an in-game check.

With Unit Frames enabled, the Blizzard Damage Meter type dropdown also offers
**Threat** for group members against your current hostile target. Deaths and the
other Blizzard views remain available. Threat uses a separate, temporary mode;
after a reload the last native view is restored. Old invalid type `20561` is
reset to Damage Done in saved settings and loaded windows.

The type menu opens at the cursor, independently of the meter's restricted
geometry. Threat bars show scaled aggro percentages (100% at the aggro threshold).
They use Blizzard's visual base template on addon-owned rows: original textures,
fonts, class icons, numbered names and the selected bar style. Restricted data
never enters Blizzard's source-entry initializer. Native window methods and menu
selection predicates are not replaced or hooked; threat events and a separate
0.2-second update keep the overlay in sync. Scroll with the mouse wheel;
minimizing and edit mode follow the meter window.
Public threat values are sorted; restricted values retain group order and are
passed directly to native display functions. Run `luajit tests/threatmeter.lua`.
To exercise Blizzard's actual style mixins, pass the path to its
`Blizzard_DamageMeter/DamageMeterEntry.lua` as the first argument.
After `/reload`, check the dropdown, Threat/Deaths switching, target changes and
additional windows both outside and during combat; mocks cannot certify taint safety.

In **PyresinQoL → Misc → Experience Bar**, choose `X / X`,
`X / X (N%)`, `N%`, or Blizzard's default text. Custom text can stay visible
or appear only on hover. The optional tooltip shows current, remaining and
rested XP, plus the count and XP rewards of quests ready to turn in.
All percentages refer to the XP required for one full level.
Completed quest XP also appears as a preview using the current rested/unrested
XP texture at 25% opacity after the current XP fill,
clipped at the end of the level. Toggle it with **Show completed quest XP**.

Quest rewards come directly from `GetQuestLogRewardXP(questID)` and
`C_QuestLog.ReadyForTurnIn`; no external quest database is needed.
The integration targets the two native status-bar containers in
[Forever build 1.60.1.69913](https://github.com/Gethe/wow-ui-source/tree/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e).

Run `luajit tests/experience.lua` for the XP regression check. To also use
Blizzard's actual bar mixins, pass `en /path/to/forever-ui-source`.
Appearance and live API behavior still need verification in the game after `/reload`.

## Development

The addon is organized by responsibility:

```text
Core/                  Localization, ordered module registry, database migration, bootstrap
Settings/              Shared window/navigation and control helpers
Media/                 In-game textures shipped with the addon
docs/branding/         README/CurseForge logo and original artwork (not packaged)
Modules/
  GameMenu/            Runtime and Settings.lua
  EditMode/            PixelPerfect.lua and Settings.lua
  Performance/         Runtime and Settings.lua
  Experience/          Runtime and Settings.lua
  Quests/              Runtime and Settings.lua
  UnitFrames/          UnitFrames.lua, DruidMana.lua, TargetDebuffs.lua, NameplateThreat.lua and shared Settings.lua
  Tooltips/            Runtime and Settings.lua
tests/                 Standalone LuaJIT checks and run.sh
PyresinQoL.toc          Authoritative source load list
```

Run all automated checks, including language variants and all four EditMode /
Performance activation combinations, with `sh tests/run.sh`. The runner changes
to the addon root and launches each check in a separate LuaJIT process. Individual
checks still run from the addon root, for example `luajit tests/menu.lua de`.
The tests use mocked game APIs; an in-game `/reload` check remains necessary for
visual layout, native hooks, combat restrictions and live client behavior.

### Logos and packaging

`docs/branding/logo.png` is the 400 × 400 transparent PNG for the README,
CurseForge description and project avatar. The README displays it at 160 × 160.
Upload this file separately as the CurseForge project logo; the TOC icon does not
set the website avatar. See the [CurseForge avatar requirements](https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies).

`Media/AddonIcon.tga` is the simplified in-game logo: an uncompressed 128 × 128,
32-bit TGA with alpha. The TOC uses it for Escape → AddOns; settings reuse it at
48 × 48 on the native launcher and 24 × 24 in the `/pqol` title bar.
Restart WoW after adding the texture, then check all three placements in-game.

Unmodified originals live in `docs/branding/source/`: `logo.png` was
`PyresinQoL_Logo.png`, and `addon-icon.png` was `IngameLogoAddonPyresinQoL.png`.
The exports preserve the artwork's proportions, trim empty margins and leave
a small transparent safety margin. Rebuild from the addon root with ImageMagick:

```sh
magick docs/branding/source/logo.png -crop 1076x1137+89+52 +repage -filter Lanczos -resize 384x384 -gravity center -background none -extent 400x400 -strip PNG32:docs/branding/logo.png
magick docs/branding/source/addon-icon.png -crop 1029x1179+126+29 +repage -filter Lanczos -resize 124x124 -gravity center -background none -extent 128x128 -strip -type TrueColorAlpha -depth 8 -compress None Media/AddonIcon.tga
```

The crop rectangles exclude faint stray pixels outside the visible artwork.
`.pkgmeta` keeps documentation, source artwork and tests out of CurseForge/BigWigs
release packages; `Media/` remains included. When packaging manually, include
`PyresinQoL.toc`, `Core/`, `Settings/`, `Modules/` and `Media/` inside `PyresinQoL/`.

### Module interface and startup

`Core/Modules.lua` owns the ordered module metadata. `ns.GetModule(id)` returns
the same object throughout the session and rejects unknown IDs. Each object has
`id`, `name`, `description`, its navigation `group` and ordered `pages`, its
registered initializers, its settings builder and,
after initialization, `active` (the state applied at the last reload).

- `ns.RegisterModule(id, initialize)` registers a runtime initializer receiving
  the module object. Multiple initializers run in registration order on that same
  object; UnitFrames uses this for its main behavior and target debuffs.
- Runtime files only register at load time. Frames, hooks, events and runtime
  exports are created inside the initializer, which runs only for enabled modules.
- Export feature callbacks on the module object, such as
  `module.UpdatePerformanceLayout`. Keep implementation helpers local. The shared
  namespace contains localization and core/settings entrypoints.
- `ns.RegisterModuleSettings(id, build)` registers one settings builder per module.
  It runs even when the feature is disabled. It receives `(module, context)`, where
  `context.category` is the Blizzard category, `context.pages.main` is the feature
  page and `context.controls` contains `Register`, `AddControl` and `Choices`.
  Page IDs come from the module's registry metadata; UnitFrames declares `main`,
  `player`, `target` and `nameplates`. Modules without explicit pages receive a single `main` page.
  `ns.settingsGroups` defines group labels and display order; the Modules overview
  belongs to the first group. The window derives navigation and builder contexts
  from these definitions without feature-specific routing.
- `Register(page, variable, key, valueType, name, default, callback)` preserves
  setting IDs, saved keys and defaults, and gates callbacks on both the active and
  requested module state. `AddControl(page, initializer)` applies shared layout
  and editability. `Choices(value1, label1, value2, label2)` creates a two-option
  dropdown provider. Native proxy settings remain in the owning feature builder.

The TOC loads localization, the registry, database/settings helpers, bootstrap,
runtime registrations and settings registrations. On the addon's `ADDON_LOADED`,
bootstrap prepares `PyresinQoLDB`, initializes enabled modules in registry order,
and builds settings. UnitFrames keeps its native settings registration deferred
through `SettingsRegistrar`, including the legacy status-text migration.

EditMode and Performance obtain each other's module objects during startup.
These objects always exist, but disabled modules have no runtime exports.
Performance checks the optional editor callbacks before invoking them; EditMode
checks for the optional performance display. EditMode initializes first, so it
reads the display from the shared module object when needed, rather than caching
an absent frame during startup. Module switches take effect after reload.

### Adding a feature

1. Add a stable module ID and localized metadata to the ordered registry.
2. Add its runtime and `Settings.lua` under a new `Modules/` feature directory.
   Register runtime behavior and its settings builder with that same ID.
3. Add both files to the TOC. Set the module's `group` in the registry. For subpages,
   declare an ordered `pages` list of `{ id, name }` entries there; settings builders
   receive the corresponding pages as `context.pages[id]`. No window edits are needed.
4. Add feature tests and extend the module/TOC expectations in `tests/modules.lua`.
   The runner discovers new top-level Lua tests automatically.

Preserve the `PyresinQoLDB` name, existing saved keys and defaults, public frame
names and `/pqol`. General saved-data migrations belong in `Core/Database.lua`;
feature migrations that depend on native settings stay with that feature.

### Update costs

The XP preview and tooltip share one quest summary. Quest-log and level changes
invalidate it; events within the same frame schedule one refresh. XP, rested XP,
text settings and hover changes reuse the summary. Re-enabling quest rewards
refreshes it immediately.

Tooltip health renders immediately on unit display or settings changes, then at
most ten times per second while visible. Disabled polling does no health reads or
text writes. Restricted values still pass directly to the native formatter.

Edit Mode polls geometry to follow native movement and layout reverts, but only
rewrites controls or solves panel placement when their inputs change. Placement
also tracks dialog visibility, screen bounds, scale and panel size. The automated
checks assert these work limits; they do not measure in-game CPU or FPS.
