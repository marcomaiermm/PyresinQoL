<p align="center">
  <img src="docs/branding/logo.png" alt="PyresinQoL logo" width="160" height="160">
</p>

# PyresinQoL

Quality-of-life improvements for the native **WoW Forever 1.60.1** interface.

## Features

- **Unit frames & threat:** class colors, health/resource text, druid mana, debuff timers, threat displays and combo points per enemy nameplate.
- **Buffs & debuffs:** own-aura grouping, sorting, growth directions, row limits, spacing and timer presentation; target aura sizes and row widths.
- **Tooltips:** health values, guild ranks and cursor anchoring for world objects.
- **XP & quests:** experience text, completed-quest XP preview, quest levels and persistent sparkles on lootable quest items.
- **Flight timer:** remaining flight time with a route bar, your portrait riding it and the stops on the way for flight master flights; movable and customizable in Edit Mode.
- **Dungeon maps:** 50 illustrated map views across 18 original Vanilla dungeon complexes, embedded in Blizzard's world map with native zoom, pan and floor controls. Sunken Temple and original Upper Blackrock Spire are documented gaps; new WoW Forever dungeons are outside this module's scope. Player positions stay hidden until a matching WoW Forever coordinate source is verified.
- **Edit Mode:** precise positioning and snapping.
- **Addon profiles:** QoL settings automatically follow your Blizzard Edit Mode layout; manage profiles in `/pqol`.
- **Player cast bar:** native textures, four border styles, integrated or external icons, and a complete preview directly in Edit Mode.
- **Convenience:** FPS/latency display and a cooldown-manager shortcut.

## Install

1. Download the addon ZIP from [Releases](https://github.com/marcomaiermm/PyresinQoL/releases).
2. Extract it and copy the `PyresinQoL` folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Restart WoW and enable **PyresinQoL** in the AddOns list.

`PyresinQoL.toc` must sit directly inside the addon folder.
Upgrading from the old addon name? See [settings migration](docs/development.md#settings-migration).

## Use

Open **`/pqol`**, select the modules you want, and use **Reload UI** to apply
module changes. Individual settings and positions are preserved.
Use the search box to find options across all pages by name or help text. Edit
matching controls directly, or click a result's heading to open its page; clear
the search (or press Escape while typing) to return to the previously selected page.

Inside an original Vanilla party dungeon, press **M** to open its illustrated map.
It opens inside Blizzard's standard world-map frame; use the floor selector for
another level. Its name appears in Blizzard's breadcrumb: right-click the map to
return to the native World map, then choose the dungeon from the World button's
dropdown to go back without closing **M**. When Forever
already supplies a usable native dungeon map, the addon leaves it untouched. The
illustrated fallback does not guess coordinates: it reports that the player
position is unavailable until that art has a verified Forever calibration. New
WoW Forever dungeons, including newly added locations, are not included.
The addon does not include verified Blizzard-drawn artwork matching original
Sunken Temple or Upper Blackrock Spire, so those areas deliberately show
Blizzard's ordinary world map instead of an Atlas overview or an incorrect Lower
Blackrock Spire floor. Lower
Blackrock Spire appears only when its English subzone identifies a retained map;
unknown or localized unmatched shared subzones remain on the native map. Scarlet
Monastery and Dire Maul wings share their complex entry. Raids are outside this
module's scope.

### Quest item sparkles

Under **Quests**, **Show quest item sparkles** is off by default; existing saved
choices are preserved. Enabling keeps quest objects sparkling after graphics-preset
changes by disabling normal and raid outlines. It can also highlight quest givers;
the effect cannot be restricted to lootable world objects through this option.
Changes during combat wait until combat ends.

Turning the checkbox off stops enforcement, sets the loot effect to `0` and all
four outline modes to High (`2`). Enabling works immediately; turning the effect
off requires a **full game restart**, not `/reload`. After a successful reset, a
reminder dialog appears when you close `/pqol`. Re-enabling before closing cancels
it; already-disabled profiles do not prompt or reset your graphics. Failed writes
are reported and incomplete resets can be retried. These graphics CVars are client-wide and persist
in `WTF/Config.wtf`, even after disabling the Quests module or the addon.

If the addon is already disabled, restore the settings manually, then restart:

```text
/console outlineModeShowLootEffectWhenDisabled 0
/console graphicsOutlineMode 2
/console OutlineEngineMode 2
/console raidGraphicsOutlineMode 2
/console RAIDOutlineEngineMode 2
```

### Profiles and customization

QoL settings automatically switch with your Blizzard Edit Mode layout. The first
layout keeps your existing settings; new layouts start with a copy of the current
settings. Changes are saved in the associated profile. Edit Mode uses its normal
layout selector.

Use the **Profiles** tab at the bottom of the `/pqol` sidebar to choose, create,
rename or delete profiles. Its **Edit Mode Layout** field links the selected
profile to a layout for the current character. Several profiles can share a
layout; each character remembers the last profile chosen for it. Profile actions
never change the Blizzard layout. A manual profile choice assigns it to the
current layout.
Automatic switches apply options and addon positions directly. Changed module
choices require a UI reload, offered after leaving Edit Mode. Manual profile
switches reload immediately; save or revert pending Blizzard layout changes first.
The active profile and Default cannot be deleted.

For cast-bar customization, open **Unit Frames → Player**, enable **Cast Bar
Customization**, then choose **Configure in Edit Mode**. Use **Appearance**,
**Layout** and **Details** to adjust the preview. **Animated** toggles profession
texture animation; model styles always animate. Blizzard controls position, scale
and **Show Cast Time**. Reset restores native presentation without changing your
Blizzard layout.

Open **Unit Frames → Buffs & Debuffs** to enable custom arrangements independently
for player buffs and debuffs. Choose own auras first/last, separate rows, sort by
order/name/remaining time, growth directions, icon sizes, row limits and spacing.
Duration text position, font and spacing, cooldown swipe and icon countdowns are
independent options. Blizzard Edit Mode retains position and scale.
Under **Unit Frames → Target**, choose regular/own icon sizes, row width (including
target-of-target) and spacing for buffs and debuffs. Restricted target icon sizes
apply once aura data becomes accessible again, normally after combat.

[Report an issue](https://github.com/marcomaiermm/PyresinQoL/issues) ·
[Developer guide](docs/development.md) · [MIT License](LICENSE)
