# PyresinQoL Changelog

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
