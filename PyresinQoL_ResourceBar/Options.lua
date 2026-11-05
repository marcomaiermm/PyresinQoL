local ns = PyresinQoL
local L = ns.L

-- Every resource bar's options, for the settings page (Settings.lua) and the Edit Mode dialogs
-- (EditMode.lua) alike, in the format of PyresinQoL's ns.CreateEditModeOptionsDialog: sections are named,
-- colors saved as "AARRGGBB". Each key starts with its bar's id, as in healthBarWidth. classes limits an
-- option to those classes.
local module = ns.GetModule("resourceBar")
local MANA_CLASSES = { PALADIN = true, HUNTER = true, PRIEST = true, SHAMAN = true, MAGE = true, WARLOCK = true,
    DRUID = true }

local function BarOptions(id, defaults, extra)
    local options = {
        { key = "Visibility", label = L.resourceBarVisibility, default = defaults.visibility,
            section = L.resourceBarSectionVisibility, choices = {
            { "always", L.resourceBarAlways }, { "combat", L.resourceBarInCombat }, { "target", L.resourceBarWithTarget },
            { "targetOrCombat", L.resourceBarTargetOrCombat }, { "hidden", L.resourceBarHidden } } },
        { key = "HideMounted", label = L.resourceBarHideMounted, default = false },
        { key = "Width", label = L.resourceBarWidth, default = 200, section = L.resourceBarSectionSize, min = 20,
            max = 600, format = "%d px" },
        { key = "Height", label = L.resourceBarHeight, default = defaults.height or 14, min = 2, max = 60, format = "%d px" },
        { key = "Fill", label = L.resourceBarFill, default = "right", choices = {
            { "right", L.resourceBarFillRight }, { "left", L.resourceBarFillLeft }, { "up", L.resourceBarFillUp },
            { "down", L.resourceBarFillDown } } },
        { key = "Smooth", label = L.resourceBarSmooth, default = true },
        { key = "Texture", label = L.resourceBarTexture, default = "blizzard", section = L.resourceBarSectionStyle, choices = {
            { "blizzard", L.resourceBarTextureBlizzard }, { "flat", L.resourceBarTextureFlat } } },
        { key = "Color", label = defaults.colorLabel or L.resourceBarColor, default = "default", choices = {
            { "default", L.resourceBarColorDefault }, { "class", L.resourceBarColorClass },
            { "custom", L.resourceBarColorCustom } }, classes = defaults.colorClasses },
        { key = "CustomColor", label = L.resourceBarCustomColor, default = defaults.color, color = true,
            parent = "Color", parentValue = "custom", classes = defaults.colorClasses },
        { key = "Background", label = L.resourceBarBackground, default = "80000000", color = true },
        { key = "Border", label = L.resourceBarBorder, default = "thin", choices = {
            { "none", L.resourceBarBorderNone }, { "thin", L.resourceBarBorderThin }, { "thick", L.resourceBarBorderThick } } },
    }
    if defaults.segmented then -- points fill whole segments: nothing to smooth
        for index, option in ipairs(options) do
            if option.key == "Smooth" then table.remove(options, index); break end
        end
    else
        table.insert(options, { key = "Text", label = L.resourceBarText, default = true, section = L.resourceBarSectionText })
        table.insert(options, { key = "TextFormat", label = L.resourceBarTextFormat, default = "current", parent = "Text",
            choices = { { "current", L.resourceBarTextCurrent }, { "currentMax", L.resourceBarTextCurrentMax },
                { "percent", L.resourceBarTextPercent }, { "both", L.resourceBarTextBoth } } })
        table.insert(options, { key = "TextSize", label = L.resourceBarTextSize, default = 12, min = 6, max = 24, format = "%d",
            parent = "Text" })
        table.insert(options, { key = "TextAlign", label = L.resourceBarTextAlign, default = "center", parent = "Text",
            choices = { { "left", L.resourceBarAlignLeft }, { "center", L.resourceBarAlignCenter },
                { "right", L.resourceBarAlignRight } } })
    end
    for index, option in ipairs(extra or {}) do
        if index == 1 then option.section = L.resourceBarSectionOther end
        table.insert(options, option)
    end
    for _, option in ipairs(options) do
        option.key = id .. option.key
        if option.parent then option.parent = id .. option.parent end
    end
    return options
end

-- Startup order, with each bar's default spot below the character.
module.resourceBars = {
    { id = "healthBar", name = L.healthBar, y = -100, options = BarOptions("healthBar",
        { visibility = "hidden", color = "FF00FF00" },
        { { key = "Absorbs", label = L.resourceBarAbsorbs, default = false } }) },
    { id = "powerBar", name = L.powerBar, y = -120, options = BarOptions("powerBar",
        { visibility = "always", color = "FF0000FF", colorLabel = L.resourceBarManaColor, colorClasses = MANA_CLASSES },
        { { key = "HidePersonal", label = L.resourceBarHidePersonal, default = true },
            { key = "LifeTap", label = L.resourceBarLifeTap, tooltip = L.resourceBarLifeTapHelp, default = false,
                classes = { WARLOCK = true } } }) },
    { id = "comboPointsBar", name = L.comboPointsBar, y = -140, options = BarOptions("comboPointsBar",
        { visibility = "always", color = "FFFFF569", height = 10, segmented = true }) },
}

local defaults = {}
for _, bar in ipairs(module.resourceBars) do
    for _, option in ipairs(bar.options) do defaults[option.key] = option.default end
end

-- The options for this character's class, which the settings pages and Edit Mode dialogs show. The others
-- keep their saved values for the profile's other characters.
local _, class = UnitClass("player")
for _, bar in ipairs(module.resourceBars) do
    bar.playerOptions = {}
    for _, option in ipairs(bar.options) do
        if not option.classes or option.classes[class] then table.insert(bar.playerOptions, option) end
    end
end

-- A saved value, or its default; also for profiles saved before an option existed.
function module.GetResourceBarOption(key)
    local value = PyresinQoLDB[key]
    if value == nil then return defaults[key] end
    return value
end

function module.FormatResourceBarOption(option, value)
    return option.format:format(math.floor(value + 0.5))
end
