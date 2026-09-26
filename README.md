<p align="center">
  <img src="docs/branding/logo.png" alt="PyresinQoL logo" width="160" height="160">
</p>

# PyresinQoL

Quality-of-life improvements for the native **WoW Forever 1.60.1** interface.

## Features

- **Unit frames & threat:** class colors, health/resource text, druid mana, debuff timers, threat displays and combo points per enemy nameplate.
- **Tooltips:** health values, guild ranks and cursor anchoring for world objects.
- **XP & quests:** experience text, completed-quest XP preview and quest levels.
- **Edit Mode:** precise positioning and snapping.
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

For cast-bar customization, open **Unit Frames → Player**, enable **Cast Bar
Customization**, then choose **Configure in Edit Mode**. Use **Appearance**,
**Layout** and **Details** to adjust the preview. **Animated** toggles profession
texture animation; model styles always animate. Blizzard controls position, scale
and **Show Cast Time**. Reset restores native presentation without changing your
Blizzard layout.

[Report an issue](https://github.com/marcomaiermm/PyresinQoL/issues) ·
[Developer guide](docs/development.md) · [MIT License](LICENSE)
