# PyresinQoL Changelog

## Unreleased

### Added
- **Flight Timer** (Misc): shows the remaining flight time on a route bar with your portrait, the start, the destination and the stops on the way
- Gets more accurate with every flight and accounts for Frequent Flier
- Follows an early landing and keeps running after a `/reload`
- Long place names scroll so you can read them in full
- Move it in Edit Mode; click it there to choose the bar style, player marker, flags, stops, zone names, time display, width and scale
- **Flyout Bar** (Action Bars): a bar of up to 12 buttons, each opening its own menu of spells, items, toys, mounts and macros; the menus work in combat
- Drag spells, items, toys, mounts and macros onto a button or into its menu, or click it while holding one
- Bind keys to its buttons under Key Bindings → AddOns or with Quick Keybind Mode
- Right-click a button to give its menu a name and an icon; the question mark uses the first entry's icon
- On bars with several rows, an open menu hides the buttons behind it
- Move it in Edit Mode; click it there to set icons, rows, orientation, size, padding, icons per menu and when the bar is visible
## 0.1.9

### Added
- Pixel-perfect Edit Mode replaces Blizzard's coarse size sliders (swing timers, raid/party frames, damage meter, Personal Resource Display bar heights) and all direct width/height sliders (also the chat frame) with identical-looking sliders that step by one unit and show their value. While dragging, width/height snap to the snap target's size (respecting Edit Mode's Snap toggle), also in the cast bar's own width/height sliders. **Match width** copies the target's width in one click for every frame with a whole-unit width: swing timers, damage meter, raid/party frames, chat frame and the player cast bar when **Customize cast bar** is on. Frames sized only in percent steps (e.g. action bars) keep Blizzard's steps and instead show their measured width in screen pixels. Sizes and snapping compare the frames' visible Edit Mode selections, like Blizzard's magnetism, so padded frames such as the player frame match their visible art. Changes go through Blizzard's own settings, so Save/Revert work as usual.

### Fixed
- Disabling a module with layout-linked profiles no longer loops on a reload prompt while the module stays enabled. Startup now keeps the last active profile and applies the Edit Mode layout's profile once layouts are available at login.

## 0.1.8

### Added

- Search all `/pqol` settings pages by localized option names and help text using Blizzard's native search field. Results keep their page/section context, can be edited directly, and link back to the original page; disabled modules remain locked.
- Add opt-in **Quests → Show quest item sparkles**, included in addon profiles, to keep quest objects sparkling after graphics changes. This can also highlight quest givers and disables normal and raid outlines. Switching off restores High outlines once; a dialog after closing `/pqol` reminds you that removing sparkles requires a full game restart, not `/reload`. Re-enabling before closing cancels the reminder. CVar updates are coalesced, unchanged values are not rewritten, and combat changes wait until combat ends.

### Changed

- Rework settings and profile page layouts to fit the custom window and keep translated controls readable.

### Fixed

- Avoid duplicate settings-list rebuilds when selecting a page from search results or the sidebar.
- Report failed sparkle CVar writes and allow incomplete off transitions to be retried without resetting graphics for already-disabled profiles.

## 0.1.7

### Added

- Add 50 illustrated map views across 18 original Vanilla dungeon complexes directly to Blizzard's world map, with native zoom, pan, floor selection, a `World > Dungeon` breadcrumb and a return route in the native World menu. Sunken Temple and original Upper Blackrock Spire remain documented gaps instead of using schematic Atlas or incorrect wing maps. New WoW Forever dungeons are outside this module's scope. Maps without a WoW Forever coordinate calibration report that the player position is unavailable.

### Fixed

- Prevent player aura layout errors when native anchor counts become restricted during combat or resurrection.
- Prevent player aura timers from overlapping the next icon row when row spacing is zero.
- Recover from malformed saved profile data while preserving valid settings and profiles.
- Prevent stale cast-bar color and dropdown controls from undoing a reset or changing a newly selected profile.
- Keep cast-bar settings inside the screen at enlarged UI scales.

## 0.1.6

### Added
- Add opt-in **Action Bars** settings for native icon and hotkey state colors, font sizes and compact bindings. Each action bar's Edit Mode dialog has its own **PyresinQoL → Visibility** section for opacity, mouseover and macro-condition rules. Visibility rules pause automatically in controller UI mode and resume afterward.
- Configure player buff/debuff grouping, sorting, growth, rows, spacing and timers in **Unit Frames → Buffs & Debuffs**. Customize target aura sizes, larger own auras, row widths and spacing, including debuff timers.
- QoL settings and addon positions now follow Blizzard Edit Mode layouts automatically. New layouts copy current settings; existing settings are preserved. Manage profiles in the standalone **Profiles** tab at the bottom of `/pqol`. Multiple profiles can share a layout, with a separate choice per character. Profile actions never change Blizzard layouts or add Edit Mode controls. Automatic switches apply settings live; changed module choices offer a reload after leaving Edit Mode. Manual switches reload the UI.
- Customize tooltip cursor or fixed-screen anchors, combat behavior and spell placement. Show spell/item/icon IDs, maximum item stack sizes and unit targets, and choose custom or quality/class/reaction-based border and background colors.

### Fixed
- Reapply action-bar hide rules after leaving Edit Mode even when their macro condition has not changed.
- Keep the cooldown shortcut visible and clickable inside the game menu below Options while isolating it from the native button pool and layout traversal. Suspend it in controller mode to prevent blocked controller interaction when opening Blizzard settings.
- Keep the native popup registry untainted when registering action-bar settings, preventing blocked Escape actions such as `SpellStopCasting()`.
- Player aura settings no longer invoke Blizzard's aura rendering from addon code, avoiding its restricted stack-count comparison. Correct custom spacing at non-default icon scales and preserve vertical private aura footprints.

## 0.1.5

- Choose Off, Automatic (Blizzard), In combat or Always for target and focus threat percentages. Existing enabled/disabled settings keep their behavior; the new visibility modes keep the number visible after taking aggro and distinguish missing data from 0%.

## 0.1.4

- Add opt-in player cast-bar customization in Blizzard Edit Mode, with Appearance, Layout and Details tabs, conditional controls and a shared preview.
- Choose native profession textures with smooth forward animation loops and an Animated toggle, or ten styles with native model effects, reference colors and backgrounds. The scrollable texture selector previews each style, including model effects.
- Customize original/class/custom colors, dimensions, compact layout, fonts, spell-name and cast-time placement, spark, background and latency zone. Choose Blizzard, Thin, Inset or None borders with color, opacity and thickness controls, plus integrated or external icons with adjustable exterior spacing.
- Keep profession artwork scaled by bar height and clipped to cast progress. Interrupted/failed profession textures retain their pattern with red shading unless disabled under Details; model styles always restore Blizzard's interruption artwork.
- Preserve Blizzard's cast engine, position, scale and cast-time visibility. Icon changes keep the bar's total size and text layout stable; Edit Mode bounds include icons, borders and external text. Reset restores native presentation without changing the Blizzard layout, and old border visibility settings migrate automatically.

## 0.1.3

- Increase right-side nameplate threat spacing so the level badge does not cover the percentage, including in the settings preview.
- Fix nameplate threat errors when Blizzard restricts threat values during combat. Restricted percentages use the permitted native formatting without a cap; freely readable values still cap at **999%+**, and 0% stays hidden.

## 0.1.2

- Nameplate threat percentages now display **999%+** at 1000% and above, keeping large threat leads compact. Lower percentages retain their existing display, and 0% stays hidden.

## 0.1.1

- Rogues and druids can now see combo points below each enemy nameplate. Toggle the display in `/pqol` or Blizzard's nameplate settings.
- New **Status Text** options let you hide health, resource and state text separately for your pet, target, target of target and focus, including on mouseover. Names and bars stay visible.
- The addon's shared status-text format selector has been removed. Use Blizzard's settings to choose your preferred text format.
- **Threat** is now available in the damage meter's display dropdown. Select another display to return to the normal meter.

## 0.1.0

Initial release for **WoW Forever 1.60.1**.

- Customize unit frames with class-colored health bars, adjustable text positions, druid mana in Cat and Bear Form, and target debuff timers.
- Keep track of threat with nameplate percentages and a threat view in the damage meter.
- See experience details, an XP preview for completed quests, and quest levels.
- Position your interface more precisely with Edit Mode snapping and fine adjustments.
- Add health values and guild ranks to tooltips, and show world-object tooltips at your cursor.
- Display FPS and latency, and open the cooldown manager from the game menu.
- Choose the features you want through `/pqol`, with English and German settings.
