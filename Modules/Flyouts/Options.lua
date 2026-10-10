local _, ns = ...
local L = ns.L

-- Every option, for the settings page (Settings.lua) and the Edit Mode dialog alike, with Blizzard's own
-- action bar labels and ranges; see FlightTimer/Options.lua for the fields.
local module = ns.GetModule("flyouts")
module.flyoutOptions = {
    { key = "flyoutsOrientation", label = HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION, default = "horizontal", choices = {
        { "horizontal", HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION_HORIZONTAL },
        { "vertical", HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION_VERTICAL } } },
    { key = "flyoutsRows", label = HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ROWS, default = 1, min = 1, max = 4 },
    { key = "flyoutsIcons", label = HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ICONS, default = 6, min = 1, max = 12 },
    { key = "flyoutsSlots", label = L.flyoutsSlots, default = 6, min = 1, max = 12 },
    { key = "flyoutsIconSize", label = HUD_EDIT_MODE_SETTING_ACTION_BAR_ICON_SIZE, default = 100, min = 50, max = 200,
        step = 10, format = "%d%%" },
    { key = "flyoutsPadding", label = HUD_EDIT_MODE_SETTING_ACTION_BAR_ICON_PADDING, default = 2, min = 2, max = 10 },
    { key = "flyoutsVisibility", label = HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING, default = "always", choices = {
        { "always", HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_ALWAYS },
        { "combat", HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_IN_COMBAT },
        { "outOfCombat", HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_OUT_OF_COMBAT },
        { "hidden", HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_HIDDEN } } },
}

function module.FormatFlyoutOption(option, value)
    return (option.format or "%d"):format(value)
end
